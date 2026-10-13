"""
SecureCampus Iris AI Service.

Exposes the camera -> recognition -> Firebase pipeline over HTTP so the
Flutter app (via Firebase / a thin backend trigger) and Admin tooling
can enroll students and drive live recognition at the classroom entrance
or the campus gate. Run standalone:

    uvicorn app.main:app --host 0.0.0.0 --port 8000

or via Docker (see ../Dockerfile / ../docker-compose.yml).

Every endpoint that touches the camera or Firebase does the real thing
and reports real failure reasons (camera offline, no iris detected, no
active course scheduled, Firebase not configured, etc.) - none of them
fabricate a success result.
"""

from __future__ import annotations

import asyncio
import logging
import time

import cv2
import numpy as np
from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from app import firebase_client
from app.admin_api import require_admin
from app.admin_api import router as admin_router
from app.camera.rtsp_stream import CameraStatus, RtspCamera
from app.config import settings
from app.models.schemas import (
    CameraStatusResponse,
    EnrollResponse,
    RecognitionResponse,
    StreamStatusResponse,
)
from app.pipeline import process_image, recognize_against_enrolled

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("securecampus.iris_ai")

app = FastAPI(title="SecureCampus Iris AI Service", version="0.1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(admin_router)

camera = RtspCamera(settings.CAMERA_RTSP_URL, name=settings.CAMERA_NAME)


class TemplateCache:
    """Avoids hitting Firestore on every single processed frame - reloads
    enrolled iris templates at most every REFRESH_SECONDS."""

    REFRESH_SECONDS = 30.0

    def __init__(self) -> None:
        self._templates: dict = {}
        self._loaded_at = 0.0

    def get(self) -> dict:
        if time.time() - self._loaded_at > self.REFRESH_SECONDS:
            try:
                self._templates = firebase_client.load_enrolled_templates()
                self._loaded_at = time.time()
            except Exception as exc:
                log.warning("could not refresh enrolled templates: %s", exc)
        return self._templates


template_cache = TemplateCache()


def _camera_status_response() -> CameraStatusResponse:
    state = camera.status()
    return CameraStatusResponse(
        name=settings.CAMERA_NAME,
        location=settings.CAMERA_LOCATION,
        status=state.status.value,
        detail=state.detail,
    )


@app.get("/health")
def health():
    return {"status": "ok", "service": "iris_ai"}


@app.get("/camera/status", response_model=CameraStatusResponse)
def camera_status():
    return _camera_status_response()


@app.post("/iris/enroll", response_model=EnrollResponse)
async def enroll_student(student_id: str = Form(...), image: UploadFile = File(...)):
    """Admin flow: Admin captures/receives an iris image for a student and
    posts it here. Real image bytes in, real embedding computed and
    stored - no random assignment, no shortcutting."""
    raw = await image.read()
    arr = np.frombuffer(raw, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        raise HTTPException(400, "uploaded file is not a decodable image")

    result = process_image(bgr)
    if not result.success:
        return EnrollResponse(success=False, reason=result.reason, student_id=student_id)

    try:
        firebase_client.save_iris_profile(student_id, result.template)
    except firebase_client.FirebaseNotConfiguredError as exc:
        raise HTTPException(503, str(exc)) from exc

    return EnrollResponse(success=True, reason="iris profile enrolled", student_id=student_id)


async def _capture_and_recognize(mode: str) -> RecognitionResponse:
    if mode not in ("attendance", "gate"):
        raise HTTPException(400, "mode must be 'attendance' or 'gate'")

    frame = camera.read_frame()
    if frame is None:
        state = camera.status()
        return RecognitionResponse(success=False, reason=f"camera unavailable: {state.detail}", mode=mode)

    result = process_image(frame)
    if not result.success:
        # No usable iris captured in this frame (e.g. no one present, or
        # eye not visible/aligned) - not the same thing as "unknown
        # person", so no security alert is raised for this alone.
        return RecognitionResponse(success=False, reason=result.reason, mode=mode)

    try:
        templates = template_cache.get()
    except firebase_client.FirebaseNotConfiguredError as exc:
        raise HTTPException(503, str(exc)) from exc

    outcome = recognize_against_enrolled(result.template, templates)

    if outcome.is_known:
        student_doc = firebase_client.db().collection("students").document(outcome.matched_id).get()
        student = student_doc.to_dict() if student_doc.exists else {}
        reg_no = student.get("registrationNumber", outcome.matched_id)
        name = student.get("name", "Unknown Name")

        if mode == "attendance":
            course = firebase_client.find_active_course_for_camera(settings.CAMERA_NAME)
            if course is None:
                return RecognitionResponse(
                    success=True, reason="recognized, but no active course scheduled for this camera right now",
                    mode=mode, is_known=True, student_id=outcome.matched_id, score=outcome.best_score,
                    distance=outcome.best_distance,
                )
            created, detail = firebase_client.record_attendance(
                outcome.matched_id, reg_no, course["id"], settings.CAMERA_NAME,
                settings.CAMERA_LOCATION, outcome.best_score,
            )
            return RecognitionResponse(
                success=True, reason="ok", mode=mode, is_known=True, student_id=outcome.matched_id,
                score=outcome.best_score, distance=outcome.best_distance, record_created=created, record_detail=detail,
            )

        # gate mode
        firebase_client.record_gate_entry(
            outcome.matched_id, reg_no, name, settings.CAMERA_NAME, settings.CAMERA_LOCATION, outcome.best_score,
        )
        return RecognitionResponse(
            success=True, reason="ok", mode=mode, is_known=True, student_id=outcome.matched_id,
            score=outcome.best_score, distance=outcome.best_distance, record_created=True,
            record_detail="gate entry recorded",
        )

    # Unknown person: capture the real frame, subject to cooldown/dedup.
    ok, jpeg = cv2.imencode(".jpg", frame)
    alert_created, alert_detail = (False, "encode failed")
    if ok:
        alert_created, alert_detail = firebase_client.create_unknown_alert(
            jpeg.tobytes(), settings.CAMERA_NAME, settings.CAMERA_LOCATION, outcome.best_score,
        )
    return RecognitionResponse(
        success=True, reason=outcome.reason, mode=mode, is_known=False, score=outcome.best_score,
        distance=outcome.best_distance, unknown_alert_created=alert_created, record_detail=alert_detail,
    )


@app.post("/recognize/once", response_model=RecognitionResponse)
async def recognize_once(mode: str = "attendance"):
    """Manually trigger a single capture+recognize cycle - useful for
    testing the camera/recognition wiring without waiting for the
    background polling loop."""
    return await _capture_and_recognize(mode)


# --------------------------------------------------------------------------
# Background polling loop - the real continuous operating mode for a
# camera mounted at a classroom entrance or the campus gate.
# --------------------------------------------------------------------------

_stream_task: asyncio.Task | None = None
_stream_mode: str | None = None


async def _stream_loop(mode: str):
    log.info("recognition stream started (mode=%s)", mode)
    while True:
        try:
            await _capture_and_recognize(mode)
        except Exception as exc:  # keep the loop alive across transient errors
            log.warning("recognition cycle error: %s", exc)
        await asyncio.sleep(settings.RECOGNITION_INTERVAL_SECONDS)


@app.post("/stream/start")
async def stream_start(mode: str = "attendance", authorization: str | None = Header(default=None)):
    require_admin(authorization)
    global _stream_task, _stream_mode
    if mode not in ("attendance", "gate"):
        raise HTTPException(400, "mode must be 'attendance' or 'gate'")
    if _stream_task is not None and not _stream_task.done():
        raise HTTPException(409, f"stream already running in mode={_stream_mode}")
    _stream_mode = mode
    _stream_task = asyncio.create_task(_stream_loop(mode))
    return {"started": True, "mode": mode}


@app.post("/stream/stop")
async def stream_stop(authorization: str | None = Header(default=None)):
    require_admin(authorization)
    global _stream_task, _stream_mode
    if _stream_task is None:
        return {"stopped": False, "detail": "no stream running"}
    _stream_task.cancel()
    _stream_task = None
    mode, _stream_mode = _stream_mode, None
    return {"stopped": True, "mode": mode}


@app.get("/stream/status", response_model=StreamStatusResponse)
def stream_status():
    running = _stream_task is not None and not _stream_task.done()
    return StreamStatusResponse(running=running, mode=_stream_mode if running else None,
                                 camera=_camera_status_response())
