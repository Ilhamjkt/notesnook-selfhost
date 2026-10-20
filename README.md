# notesnook-selfhost

My setup for running my own Notesnook sync server at home. Phones, laptops and desktops all sync through it. It's published on my domain through Nginx Proxy Manager, so it works from anywhere without a VPN.

It's based on the official [notesnook-sync-server](https://github.com/streetwriters/notesnook-sync-server) compose file, which is kept unchanged in `docker-compose.yml`. Everything I changed lives in `docker-compose.override.yml`.

## Network

The examples use `192.168.0.0/24`:

- `192.168.0.110` is the Debian VM running the Notesnook stack in Docker
- `192.168.0.120` is Nginx Proxy Manager, which handles HTTPS with a wildcard cert for `*.example.com`
- `192.168.0.130` is the mail server (`mail.example.com`) that sends 2FA codes
- `192.168.0.1` is the router, which forwards ports 80 and 443 to NPM

Clients connect to NPM over HTTPS (`notes-sync.example.com` and friends) and NPM forwards to the VM. The Notesnook ports on the VM only accept connections from NPM, so HTTPS through NPM is the only way in.

## Changes from the official compose

- **SeaweedFS instead of MinIO.** The MinIO images are gone from Docker Hub and quay.io, so attachments are stored in SeaweedFS (S3 compatible). The bucket is created with aws-cli instead of `minio/mc`.
- **Restart policies**, so everything comes back after a reboot.
- **Persistent identity keys.** By default the identity server keeps its token signing keys inside the container, so recreating it breaks any login in progress (`IDX10501 Signature validation failed`). They're on volumes now.
- **SMTP over the LAN.** Inside the containers `mail.example.com` points to the internal mail server.

## Quick start

You need a CPU with AVX for MongoDB 7. On Proxmox, set the CPU type to `host`.

```sh
git clone https://github.com/Ilhamjkt/notesnook-selfhost.git /opt/notesnook
cd /opt/notesnook
cp .env.example .env && chmod 600 .env
# fill in NOTESNOOK_API_SECRET, MINIO_ROOT_PASSWORD and SMTP_PASSWORD
sh ops/install.sh
docker compose up -d
```

The full walkthrough is in [docs/INSTALL.md](docs/INSTALL.md). The proxy setup is in [npm/README.md](npm/README.md).

## Client settings

In the Notesnook app, open the server settings on the login screen and enter:

- Sync server: `https://notes-sync.example.com`
- Auth server: `https://notes-auth.example.com`
- Events server: `https://notes-events.example.com`
- Monograph server: `https://notes-mono.example.com`

Plain `http://` won't work. The desktop app runs on the `https://app.notesnook.com` origin and blocks http requests as mixed content.

## Good to know

- Notesnook sends 2FA codes by email by default. Without working email you can still sign up, but you won't be able to log in on a second device. Switch to an authenticator app right after signing up.
- The mail library Notesnook uses checks certificate revocation, so the mail server needs a real certificate (Let's Encrypt is fine). Self-signed certs fail even if you trust the CA.
- The server is on the internet, so set `DISABLE_SIGNUPS=true` as soon as everyone has an account. Otherwise anyone can register.
- Backups run every night at 02:30 into `/opt/notesnook-backups` and are kept for 14 days. Copy them off the VM as well.

## Day to day

```sh
docker compose ps
docker compose logs -f identity-server
systemctl start notesnook-backup
docker compose pull && docker compose up -d
```

Restoring the database:

```sh
docker compose exec -T notesnook-db mongorestore --drop --archive --gzip \
  < /opt/notesnook-backups/<timestamp>/mongo.archive.gz
```
