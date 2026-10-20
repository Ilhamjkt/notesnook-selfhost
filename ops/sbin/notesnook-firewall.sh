#!/bin/sh
# Allow Notesnook container ports only from the Nginx Proxy Manager host.
# Ports are matched after Docker's DNAT, i.e. container-side ports.
set -e
NPM_IP=192.168.0.120
IFACE=eth0
PORTS=5264,8264,7264,3000,9000      # sync, auth, sse, monograph(3000), s3
HOST_PORTS=5264,8264,7264,6264,9000

iptables -N DOCKER-USER 2>/dev/null || true
iptables -F DOCKER-USER
iptables -A DOCKER-USER -i $IFACE -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
iptables -A DOCKER-USER -i $IFACE -s $NPM_IP -p tcp -m multiport --dports $PORTS -j RETURN
iptables -A DOCKER-USER -i $IFACE -p tcp -m multiport --dports $PORTS -j DROP
iptables -A DOCKER-USER -j RETURN

# IPv6 is served by docker-proxy on the host itself, so filter it in INPUT.
ip6tables -N NOTESNOOK-IN 2>/dev/null || true
ip6tables -F NOTESNOOK-IN
ip6tables -C INPUT -j NOTESNOOK-IN 2>/dev/null || ip6tables -I INPUT -j NOTESNOOK-IN
ip6tables -A NOTESNOOK-IN -i $IFACE -p tcp -m multiport --dports $HOST_PORTS -j DROP
