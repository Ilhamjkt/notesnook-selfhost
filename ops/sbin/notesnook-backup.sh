#!/bin/bash
# Daily Notesnook backup: MongoDB dump, attachment volume, and config.
set -euo pipefail
DIR=/opt/notesnook
DEST=/opt/notesnook-backups
KEEP_DAYS=14
TS=$(date +%Y%m%d-%H%M%S)
OUT=$DEST/$TS
umask 077
mkdir -p "$OUT"

docker compose -f $DIR/docker-compose.yml -f $DIR/docker-compose.override.yml --project-directory $DIR \
  exec -T notesnook-db mongodump --quiet --archive --gzip "mongodb://localhost:27017/?replicaSet=rs0" > "$OUT/mongo.archive.gz"

docker run --rm -v notesnook_s3data:/data:ro -v "$OUT":/out --entrypoint tar \
  chrislusf/seaweedfs:4.48 czf /out/s3data.tar.gz -C /data .

tar czf "$OUT/config.tar.gz" -C $DIR .env s3.json docker-compose.yml docker-compose.override.yml

find "$DEST" -mindepth 1 -maxdepth 1 -type d -mtime +$KEEP_DAYS -exec rm -rf {} +
echo "backup ok: $OUT ($(du -sh "$OUT" | cut -f1))"
