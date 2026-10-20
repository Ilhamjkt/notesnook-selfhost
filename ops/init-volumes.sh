#!/bin/sh
# Create Docker volumes that containers write to as uid 1000 and fix their ownership.
# Run once before the first `docker compose up` (safe to re-run).
set -e
for v in s3data identity_keystore identity_aspnet sync_aspnet; do
  docker volume create "notesnook_$v" >/dev/null
  docker run --rm -v "notesnook_$v:/d" --entrypoint chown chrislusf/seaweedfs:4.48 -R 1000:1000 /d
done
echo "volumes ready"
