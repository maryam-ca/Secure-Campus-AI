#!/usr/bin/env bash
# Starts the iris_ai service locally. Does NOT start the Flutter app -
# that needs an attached device/emulator and interactive `flutter run`
# (or your IDE's run button), which a background script can't drive.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No .env found - run ./setup.sh first."
  exit 1
fi

echo "== Starting bus_eta job in the background (logs: bus_eta.log) =="
( cd bus_eta && source .venv/bin/activate && set -a && source ../.env && set +a && python -m app.main ) > bus_eta.log 2>&1 &
BUS_ETA_PID=$!
trap "kill $BUS_ETA_PID 2>/dev/null" EXIT

echo "== Starting iris_ai service on http://localhost:${API_PORT:-8000} =="
cd iris_ai
source .venv/bin/activate
set -a; source ../.env; set +a
uvicorn app.main:app --host 0.0.0.0 --port "${API_PORT:-8000}" --reload
