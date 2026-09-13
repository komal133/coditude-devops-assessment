#!/bin/bash
# Installs Python dependencies into a virtual environment and fixes ownership.
set -euo pipefail

PYTHON_BIN="$(command -v python3.11 || command -v python3)"

cd /opt/app/backend
"$PYTHON_BIN" -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install --no-cache-dir -r requirements.txt

chown -R appuser:appuser /opt/app /var/log/app
exit 0
