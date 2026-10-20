# Installation

This goes from an empty VM to working apps on every device. Hosts used in the examples:

- Notesnook VM: `192.168.0.110`
- Nginx Proxy Manager: `192.168.0.120`
- Mail server: `192.168.0.130` (`mail.example.com`)
- Router: `192.168.0.1` (forwards 80/443 to NPM)

Replace `example.com` with your own domain.

## 1. VM

Debian 13 with at least 2 vCPUs, 4 GB RAM and 20 GB disk, and a fixed IP.

MongoDB 7 needs AVX. The default Proxmox CPU types (`kvm64`, `qemu64`) don't have it and the database will crash-loop, so set **Hardware → Processors → Type** to `host`. That change only applies after a full shutdown and start, not a reboot from inside the VM.

```sh
grep -c -w avx /proc/cpuinfo   # should be more than 0
```

## 2. OS updates

```sh
apt-get update && apt-get -y full-upgrade && apt-get -y autoremove
apt-get install -y ca-certificates curl gnupg openssl git unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
systemctl enable --now unattended-upgrades
```

Reboot if a new kernel was installed.

## 3. Docker

```sh
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

## 4. Config

```sh
git clone https://github.com/Ilhamjkt/notesnook-selfhost.git /opt/notesnook
cd /opt/notesnook
cp .env.example .env && chmod 600 .env
sed -i "s|^NOTESNOOK_API_SECRET=.*|NOTESNOOK_API_SECRET=$(openssl rand -hex 32)|" .env
sed -i "s|^MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=$(openssl rand -hex 24)|" .env
nano .env
```

In `.env`, change the domain in the `*_PUBLIC_URL` values and set the SMTP account (`SMTP_USERNAME`, `SMTP_PASSWORD`). Avoid spaces, quotes, `$`, `#` and `\` in the password because the file is read by both Docker and the shell scripts.

If your mail server isn't at `192.168.0.130`, update `extra_hosts` in `docker-compose.override.yml`. If NPM isn't at `192.168.0.120`, update `NPM_IP` in `ops/sbin/notesnook-firewall.sh`.

## 5. Start

```sh
sh ops/install.sh
docker compose pull
docker compose up -d
```

`install.sh` installs the firewall and backup services, writes `s3.json` from `.env`, and creates the Docker volumes with the right owner.

After a couple of minutes all services should be healthy:

```sh
docker compose ps
docker compose logs setup-s3 | tail -1     # bucket ready
curl -s http://localhost:5264/version      # {"version":1,"id":"notesnook-sync",...}
```

## 6. Reverse proxy

Follow [npm/README.md](../npm/README.md) to add the five proxy hosts and the DNS records. Then check from the VM:

```sh
for h in sync auth events; do
  curl -s --resolve notes-$h.example.com:443:192.168.0.120 https://notes-$h.example.com/version; echo
done
```

It should also work from outside, for example from a phone on mobile data: `https://notes-sync.example.com/version`.

## 7. Email

Notesnook requires 2FA and sends codes by email unless the user switches to an authenticator app, so email has to work at least for the first login on each device.

Create a sender account on the mail server, for example `email@example.com`, and put its password in `SMTP_PASSWORD`. Notesnook connects on port 587 with STARTTLS.

The mail server needs a publicly trusted certificate. Notesnook's mail library checks the certificate revocation list and there's no setting to turn that off, so a self-signed cert won't work. If NPM already has a wildcard cert for your domain you can reuse it on the mail server, but remember to redeploy it whenever NPM renews it.

Check from the VM:

```sh
cd /opt/notesnook
echo | openssl s_client -starttls smtp -connect 192.168.0.130:587 -servername mail.example.com 2>/dev/null \
  | grep -E "^issuer=|Verify return code"     # Verify return code: 0 (ok)

P=$(grep '^SMTP_PASSWORD=' .env | cut -d= -f2-)
U=$(grep '^SMTP_USERNAME=' .env | cut -d= -f2-)
curl -s --ssl-reqd --resolve mail.example.com:587:192.168.0.130 smtp://mail.example.com:587 \
  -u "$U:$P" -X NOOP -w "%{response_code}\n" -o /dev/null    # 250, a 535 means wrong password
```

After changing `SMTP_PASSWORD`, run `docker compose up -d identity-server notesnook-server`.

If the mail server should also deliver to Gmail and other outside domains, it needs outbound port 25 and a PTR record that matches its hostname. The Notesnook VM itself never needs port 25.

## 8. Apps

Get the apps from [notesnook.com/downloads](https://notesnook.com/downloads) or use the web app at `https://app.notesnook.com`.

1. On the login screen, open the server settings.
2. Enter the four URLs from the README, click **Test connection**, then **Save**.
3. The app reloads and the login screen shows the name of your instance.

## 9. Accounts

On the first device, sign up. Save the password and the recovery key somewhere safe. Notes are end-to-end encrypted, so without them the data can't be recovered, not even from a server backup.

Then go to **Settings → Authentication** and switch 2FA to an authenticator app. Keep the recovery codes.

On every other device, set the same server URLs and log in with the same account. Create a note and attach an image to make sure sync and attachments both work.

## 10. Lock it down

The server is reachable from the internet, so close signups once all accounts exist.

```sh
cd /opt/notesnook
sed -i 's/^DISABLE_SIGNUPS=.*/DISABLE_SIGNUPS=true/' .env
docker compose up -d
systemctl start notesnook-backup && ls /opt/notesnook-backups/
```

## Troubleshooting

**`notesnook-db` keeps restarting and the log mentions AVX.** The VM CPU type has no AVX. See step 1.

**`pull access denied for minio/mc`.** You're running the official compose without the override file.

**SeaweedFS says `permission denied` on `/data/s3`.** Run `sh ops/init-volumes.sh`.

**The app says it can't connect to the sync server.** Check that the URLs use `https://`, the DNS records point to your public IP, and ports 80/443 are forwarded to NPM.

**No 2FA email, and the identity log shows `SslHandshakeException`.** The mail server certificate isn't publicly trusted. See step 7.

**The identity log shows `535`.** The SMTP password in `.env` doesn't match the mail account.

**The identity log shows `PrivateKeyNotFoundException`.** Harmless. There's no PGP key, so the email goes out unsigned.

**The identity log shows `IDX10501 Signature validation failed`.** The signing key changed. Start the login over from the beginning.

Useful command:

```sh
docker compose logs --since 15m identity-server | grep -E "fail:|Exception"
```
