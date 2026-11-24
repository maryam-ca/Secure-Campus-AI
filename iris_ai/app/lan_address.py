"""Tells the app where this service is. The Admin app on a phone cannot use
"localhost" (on a phone that is the phone itself), so at start-up the service
writes its own network address to Firestore `config/backend`, and the app reads
it from there. When the PC moves to another WiFi or gets a new address, restarting
the service is enough: nothing is rebuilt and nothing is typed into the app."""

from __future__ import annotations

import logging
import socket

from firebase_admin import firestore

from app import firebase_client

log = logging.getLogger("securecampus.iris_ai")


def lan_ip() -> str | None:
    """The address this PC has on the network it reaches the internet through.
    A UDP "connect" only picks the route; no data is sent."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return None
    finally:
        sock.close()


def backend_url(port: int) -> str | None:
    ip = lan_ip()
    return f"http://{ip}:{port}" if ip else None


def publish_backend_address(port: int) -> str | None:
    """Writes the address to Firestore. Never raises: the service must still
    start without it (the app then falls back to its built-in address)."""
    url = backend_url(port)
    if url is None:
        log.warning("could not work out this PC's network address; the app will use its default")
        return None
    try:
        firebase_client.db().collection("config").document("backend").set(
            {"url": url, "updatedAt": firestore.SERVER_TIMESTAMP}
        )
    except Exception as exc:  # noqa: BLE001 - startup must not fail because of this
        log.warning("could not publish the service address: %s", exc)
        return None
    log.info("published service address %s for the app", url)
    return url
