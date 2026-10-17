#!/usr/bin/env bash
# SecureCampus - first-time setup (Linux/macOS).
# What this DOES automate: Python venv + deps for the iris AI service,
# .env scaffolding, QR code generation.
# What this CANNOT automate (see docs/LIMITATIONS.md): creating your
# Firebase project, generating firebase_options.dart, or anything that
# needs a physical phone.
set -euo pipefail
cd "$(dirname "$0")"

echo "== SecureCampus setup =="

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example - fill in your Firebase values before running."
else
  echo ".env already exists, leaving it as-is."
fi

mkdir -p secrets
echo "Put your Firebase service-account JSON at ./secrets/serviceAccountKey.json"

echo "-- iris_ai: creating Python virtual environment --"
cd iris_ai
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip >/dev/null
pip install -r requirements.txt
deactivate
cd ..

echo "-- bus_eta: creating Python virtual environment --"
cd bus_eta
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip >/dev/null
pip install -r requirements.txt
deactivate
cd ..

echo "-- overdue_checker: creating Python virtual environment --"
cd overdue_checker
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip >/dev/null
pip install -r requirements.txt
deactivate
cd ..

echo "-- functions: creating Python virtual environment (for local import checks only - deploy via firebase CLI) --"
cd functions
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip >/dev/null
pip install -r requirements.txt
deactivate
cd ..

echo "-- generating QR codes for the 5 seed library books --"
python3 -m venv .qr_venv >/dev/null 2>&1 || true
if [ -d .qr_venv ]; then
  source .qr_venv/bin/activate
  pip install qrcode[pil] pillow opencv-python-headless numpy >/dev/null
  python3 scripts/generate_qr_codes.py
  deactivate
else
  python3 scripts/generate_qr_codes.py
fi

if command -v flutter >/dev/null 2>&1; then
  echo "-- mobile: flutter pub get --"
  (cd mobile && flutter pub get)
  echo "NOTE: you still need to run 'flutterfire configure' inside mobile/ against"
  echo "      your own Firebase project before the app will build - see README."
else
  echo "Flutter SDK not found on PATH - skipping 'flutter pub get'."
  echo "Install Flutter (https://flutter.dev) then run this script again,"
  echo "or run 'flutter pub get' manually inside mobile/."
fi

echo ""
echo "Setup finished. Still required before a full demo (see README/docs/LIMITATIONS.md):"
echo "  1. Create a Firebase project, enable Auth/Firestore/RTDB/Storage/FCM."
echo "  2. Put the service-account key at ./secrets/serviceAccountKey.json and fill .env."
echo "  3. Run 'firebase deploy --only firestore:rules,storage:rules' from firebase/."
echo "  4. Run 'python scripts/seed_firebase.py' to create the 10 students/books/bus/driver."
echo "  5. Run 'flutterfire configure' inside mobile/."
echo ""
echo "Then run: ./run.sh"
