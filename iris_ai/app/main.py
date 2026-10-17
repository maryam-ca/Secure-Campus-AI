"""
SecureCampus backend service (Phase 1: account management).

The Flutter app talks to Firebase directly for almost everything. The one
thing a client cannot do itself is create, update or deactivate Firebase Auth
accounts, so the Admin portal calls this service for that (see admin_api.py).
Run standalone:

    uvicorn app.main:app --host 0.0.0.0 --port 8000

or via Docker (see ../Dockerfile / ../docker-compose.yml).

The iris enrollment, camera and recognition endpoints belong to Phase 2 and
live on the `phase-2` branch.
"""

from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.admin_api import router as admin_router

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("securecampus.iris_ai")

app = FastAPI(title="SecureCampus Backend Service", version="0.1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(admin_router)


@app.get("/health")
def health():
    return {"status": "ok", "service": "iris_ai"}
