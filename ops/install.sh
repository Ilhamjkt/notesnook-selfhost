#!/bin/sh
# Install firewall + backup scripts and systemd units from this repo, then generate local files.
set -e
cd "$(dirname "$0")"
install -m 755 sbin/notesnook-firewall.sh /usr/local/sbin/notesnook-firewall.sh
install -m 700 sbin/notesnook-backup.sh /usr/local/sbin/notesnook-backup.sh
install -m 644 systemd/notesnook-firewall.service systemd/notesnook-backup.service systemd/notesnook-backup.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now notesnook-firewall.service notesnook-backup.timer
sh ./gen-s3-config.sh
sh ./init-volumes.sh
echo "ops installed"
