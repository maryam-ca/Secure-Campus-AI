from __future__ import annotations

from pydantic import BaseModel


class CameraStatusResponse(BaseModel):
    name: str
    location: str
    status: str
    detail: str


class EnrollResponse(BaseModel):
    success: bool
    reason: str
    student_id: str | None = None


class RecognitionResponse(BaseModel):
    success: bool          # did the pipeline run to completion (frame captured + segmented)?
    reason: str
    mode: str               # "attendance" | "gate"
    is_known: bool = False
    student_id: str | None = None
    score: float = 0.0
    distance: float | None = None
    record_created: bool = False
    record_detail: str = ""
    unknown_alert_created: bool = False


class StreamStatusResponse(BaseModel):
    running: bool
    mode: str | None = None
    camera: CameraStatusResponse
