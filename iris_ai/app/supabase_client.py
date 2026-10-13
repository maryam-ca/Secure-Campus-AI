"""
Supabase Storage client - used specifically for unknown-person alert
images. Moved here from Firebase Storage because Firebase Storage now
requires the Blaze (pay-as-you-go) billing plan even for free-tier
usage, and this project's owner chose to avoid needing a card on file
at all rather than rely on the free quota staying at $0. Everything
else in this project (Auth, Firestore, Realtime Database) stays on
Firebase - only these captured photos live in Supabase.
"""

from __future__ import annotations

from supabase import Client, create_client

from app.config import settings

_client: Client | None = None


class SupabaseNotConfiguredError(RuntimeError):
    pass


def get_client() -> Client:
    global _client
    if _client is not None:
        return _client
    if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_KEY:
        raise SupabaseNotConfiguredError(
            "SUPABASE_URL / SUPABASE_SERVICE_KEY are not set. See .env.example "
            "and docs/SUPABASE_STORAGE_SETUP.md."
        )
    _client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)
    return _client


def upload_image(path: str, image_bytes: bytes) -> None:
    """Uploads real JPEG bytes to the configured bucket at `path`."""
    get_client().storage.from_(settings.SUPABASE_STORAGE_BUCKET).upload(
        path, image_bytes, file_options={"content-type": "image/jpeg"}
    )


def create_signed_url(path: str, expires_in_seconds: int = 300) -> str:
    """Returns a short-lived signed URL for viewing one image."""
    result = get_client().storage.from_(settings.SUPABASE_STORAGE_BUCKET).create_signed_url(
        path, expires_in_seconds
    )
    url = result.get("signedURL") or result.get("signedUrl")
    if not url:
        raise RuntimeError(f"Supabase did not return a signed URL for '{path}'")
    return url