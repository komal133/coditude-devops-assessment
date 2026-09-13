#!/bin/bash
# Starts both services. systemd unit files were installed by the EC2
# user-data script, so an application release never changes the instance
# configuration.
set -euo pipefail
systemctl daemon-reload
systemctl enable --now backend.service
systemctl enable --now frontend.service
exit 0
