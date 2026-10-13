"""
RTSP camera source handling.

The physical camera source is an iPhone 13 running an RTSP streaming app
(e.g. "RTSP & RTMP Cam - OctoStream"), publishing an RTSP stream on the
local network. This module owns connecting to that stream, reading
frames, detecting when the stream drops, and reconnecting - it does not
generate or simulate frames under any circumstance. If the RTSP URL is
unset, unreachable, or times out, callers get an explicit OFFLINE/ERROR
status, never a fabricated frame.

CAMERA_RTSP_URL is read from configuration (see app/config.py / .env) -
never hardcoded, since the URL is specific to whichever local network
and phone are being used at demo time.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from enum import Enum
from threading import Lock

import cv2
import numpy as np


class CameraStatus(str, Enum):
    ONLINE = "ONLINE"
    OFFLINE = "OFFLINE"
    NOT_CONFIGURED = "NOT_CONFIGURED"
    ERROR = "ERROR"


@dataclass
class CameraState:
    status: CameraStatus
    detail: str
    last_frame_at: float | None = None


class RtspCamera:
    """Wraps cv2.VideoCapture against an RTSP URL with reconnect handling.

    Usage:
        cam = RtspCamera(rtsp_url, name="GATE-CAM", connect_timeout_s=5)
        frame = cam.read_frame()   # np.ndarray (BGR) or None
        cam.status()               # CameraState
    """

    def __init__(self, rtsp_url: str, name: str, connect_timeout_s: float = 5.0,
                 max_reconnect_backoff_s: float = 15.0):
        self._url = rtsp_url
        self._name = name
        self._connect_timeout_s = connect_timeout_s
        self._max_backoff = max_reconnect_backoff_s
        self._cap: cv2.VideoCapture | None = None
        self._lock = Lock()
        self._state = CameraState(
            status=CameraStatus.NOT_CONFIGURED if not rtsp_url else CameraStatus.OFFLINE,
            detail="CAMERA_RTSP_URL not set" if not rtsp_url else "not yet connected",
        )
        self._last_attempt = 0.0
        self._backoff = 1.0

    def status(self) -> CameraState:
        return self._state

    def _try_connect(self) -> bool:
        if not self._url:
            self._state = CameraState(CameraStatus.NOT_CONFIGURED, "CAMERA_RTSP_URL not set")
            return False

        now = time.time()
        if now - self._last_attempt < self._backoff:
            return self._cap is not None and self._cap.isOpened()
        self._last_attempt = now

        try:
            cap = cv2.VideoCapture(self._url, cv2.CAP_FFMPEG)
            cap.set(cv2.CAP_PROP_OPEN_TIMEOUT_MSEC, int(self._connect_timeout_s * 1000))
            cap.set(cv2.CAP_PROP_READ_TIMEOUT_MSEC, int(self._connect_timeout_s * 1000))
            # Small buffer so we always read the freshest frame, not a
            # backlog of stale ones.
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

            if not cap.isOpened():
                cap.release()
                self._state = CameraState(CameraStatus.OFFLINE, f"could not open RTSP stream at {self._url}")
                self._backoff = min(self._backoff * 2, self._max_backoff)
                return False

            self._cap = cap
            self._backoff = 1.0
            self._state = CameraState(CameraStatus.ONLINE, "connected", last_frame_at=None)
            return True
        except cv2.error as exc:  # pragma: no cover - depends on real OpenCV/ffmpeg build
            self._state = CameraState(CameraStatus.ERROR, f"OpenCV error: {exc}")
            self._backoff = min(self._backoff * 2, self._max_backoff)
            return False

    def read_frame(self) -> np.ndarray | None:
        """Returns a BGR frame, or None if the camera is not available.
        Never fabricates a frame - a None here must be surfaced to the
        caller as a real camera-offline condition."""
        with self._lock:
            if self._cap is None or not self._cap.isOpened():
                if not self._try_connect():
                    return None

            assert self._cap is not None
            ok, frame = self._cap.read()
            if not ok or frame is None:
                self._state = CameraState(CameraStatus.OFFLINE, "stream read failed / dropped")
                try:
                    self._cap.release()
                except Exception:
                    pass
                self._cap = None
                return None

            self._state = CameraState(CameraStatus.ONLINE, "streaming", last_frame_at=time.time())
            return frame

    def release(self) -> None:
        with self._lock:
            if self._cap is not None:
                self._cap.release()
                self._cap = None
