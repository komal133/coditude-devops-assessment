#!/bin/bash
# Stops the running release. Must succeed even on a brand-new instance,
# where the services do not exist yet.
set -u
for unit in frontend backend; do
  if systemctl list-unit-files | grep -q "^${unit}.service"; then
    systemctl stop "${unit}.service" || true
  fi
done
exit 0
