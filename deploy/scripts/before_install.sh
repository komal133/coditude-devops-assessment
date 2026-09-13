#!/bin/bash
# Prepares the target directories before the new files are copied in.
set -euo pipefail
mkdir -p /opt/app/backend /opt/app/frontend /var/log/app
id appuser >/dev/null 2>&1 || useradd --system --home /opt/app appuser
exit 0
