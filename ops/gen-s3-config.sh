#!/bin/sh
# Generate s3.json (SeaweedFS S3 credentials) from MINIO_ROOT_USER/PASSWORD in .env.
set -e
cd "$(dirname "$0")/.."
. ./.env
umask 027
printf '{"identities":[{"name":"notesnook","credentials":[{"accessKey":"%s","secretKey":"%s"}],"actions":["Admin","Read","List","Tagging","Write"]}]}\n' \
  "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" > s3.json
chown root:1000 s3.json
chmod 640 s3.json
echo "s3.json generated"
