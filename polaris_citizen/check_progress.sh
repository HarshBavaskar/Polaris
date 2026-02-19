#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] flutter pub get"
flutter pub get

echo "[2/3] flutter analyze"
flutter analyze

echo "[3/3] flutter test"
flutter test

echo "Progress check complete."
