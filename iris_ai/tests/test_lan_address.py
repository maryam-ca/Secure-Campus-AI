"""The service publishes where it is, and a failure to do so never stops it."""
from unittest.mock import MagicMock

from app import lan_address


def test_url_uses_the_lan_ip_and_port(monkeypatch):
    monkeypatch.setattr(lan_address, "lan_ip", lambda: "192.168.1.50")
    assert lan_address.backend_url(8000) == "http://192.168.1.50:8000"


def test_no_network_gives_no_url(monkeypatch):
    monkeypatch.setattr(lan_address, "lan_ip", lambda: None)
    assert lan_address.backend_url(8000) is None
    assert lan_address.publish_backend_address(8000) is None


def test_publish_writes_config_backend(monkeypatch):
    db = MagicMock()
    monkeypatch.setattr(lan_address.firebase_client, "db", lambda: db)
    monkeypatch.setattr(lan_address, "lan_ip", lambda: "192.168.1.50")

    assert lan_address.publish_backend_address(8000) == "http://192.168.1.50:8000"

    db.collection.assert_called_with("config")
    db.collection.return_value.document.assert_called_with("backend")
    written = db.collection.return_value.document.return_value.set.call_args.args[0]
    assert written["url"] == "http://192.168.1.50:8000"


def test_publish_never_raises_when_firebase_is_unavailable(monkeypatch):
    def boom():
        raise RuntimeError("no credentials")
    monkeypatch.setattr(lan_address.firebase_client, "db", boom)
    monkeypatch.setattr(lan_address, "lan_ip", lambda: "192.168.1.50")
    assert lan_address.publish_backend_address(8000) is None
