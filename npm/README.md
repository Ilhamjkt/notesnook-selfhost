# Nginx Proxy Manager

NPM (`192.168.0.120`) is the HTTPS front for the Notesnook VM (`192.168.0.110`). The apps need `https://`, and this uses the wildcard certificate for `*.example.com` that NPM already manages.

The same settings are in [proxy-hosts.json](proxy-hosts.json), and the Advanced tab snippets are in [advanced/](advanced/).

## Access list

Create an access list called `LAN-VPN-only` that allows `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16` and denies everything else.

Public DNS for `*.example.com` points to your public IP, so this access list is what keeps Notesnook off the internet.

## Proxy hosts

Add five proxy hosts. Each one forwards over `http` to `192.168.0.110`, with Block Common Exploits on and the `LAN-VPN-only` access list. On the SSL tab, pick the `*.example.com` certificate and turn on Force SSL and HTTP/2.

- `notes-sync.example.com` → port 5264, websockets on, Advanced: `advanced/notes-sync.conf`
- `notes-auth.example.com` → port 8264
- `notes-events.example.com` → port 7264, websockets on, Advanced: `advanced/notes-events.conf`
- `notes-mono.example.com` → port 6264
- `notes-files.example.com` → port 9000, Advanced: `advanced/notes-files.conf`

The VM firewall only accepts these ports from `192.168.0.120`. If NPM moves, change `NPM_IP` in `ops/sbin/notesnook-firewall.sh` and run `systemctl restart notesnook-firewall`.

## Local DNS

VPN and LAN clients should resolve `notes-*.example.com` to NPM's LAN address. Otherwise their requests go out through the public IP and get blocked by the access list. On MikroTik:

```
/ip dns static add regexp="^notes-.*\\.example\\.com\$" address=192.168.0.120 ttl=5m comment="notesnook"
/ip dns set allow-remote-requests=yes
/ppp profile set [find name=<vpn-profile>] dns-server=192.168.0.1
```

## Testing

From the Notesnook VM:

```sh
for h in sync auth events; do
  curl -s --resolve notes-$h.example.com:443:192.168.0.120 https://notes-$h.example.com/version; echo
done
curl -s -o /dev/null -w '%{http_code}\n' --resolve notes-mono.example.com:443:192.168.0.120 https://notes-mono.example.com/api/health   # 200
curl -s -o /dev/null -w '%{http_code}\n' --resolve notes-files.example.com:443:192.168.0.120 https://notes-files.example.com/          # 403 is expected
```
