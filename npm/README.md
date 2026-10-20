# Nginx Proxy Manager

NPM (`192.168.0.120`) is the HTTPS front for the Notesnook VM (`192.168.0.110`). The apps need `https://`, and this uses the wildcard certificate for `*.example.com` that NPM already manages.

The same settings are in [proxy-hosts.json](proxy-hosts.json), and the Advanced tab snippets are in [advanced/](advanced/).

## DNS and ports

Point `*.example.com` (or the five `notes-*` records) to your public IP, and forward ports 80 and 443 on the router to NPM.

## Proxy hosts

Add five proxy hosts. Each one forwards over `http` to `192.168.0.110` with Block Common Exploits on. Don't attach an access list; the apps need to reach these from anywhere. On the SSL tab, pick the `*.example.com` certificate and turn on Force SSL and HTTP/2.

- `notes-sync.example.com` → port 5264, websockets on, Advanced: `advanced/notes-sync.conf`
- `notes-auth.example.com` → port 8264
- `notes-events.example.com` → port 7264, websockets on, Advanced: `advanced/notes-events.conf`
- `notes-mono.example.com` → port 6264
- `notes-files.example.com` → port 9000, Advanced: `advanced/notes-files.conf`

The VM firewall only accepts these ports from `192.168.0.120`. If NPM moves, change `NPM_IP` in `ops/sbin/notesnook-firewall.sh` and run `systemctl restart notesnook-firewall`.

## Testing

From the Notesnook VM:

```sh
for h in sync auth events; do
  curl -s https://notes-$h.example.com/version; echo
done
curl -s -o /dev/null -w '%{http_code}\n' https://notes-mono.example.com/api/health   # 200
curl -s -o /dev/null -w '%{http_code}\n' https://notes-files.example.com/          # 403 is expected
```
