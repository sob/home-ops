# Current IP Allocation Summary

## Gateway IPs
- **Cilium Gateway Internal**: 10.1.100.200 (to be replaced by Envoy Gateway)
- **Cilium Gateway External**: 10.1.100.201 (to be replaced by Envoy Gateway)
- **ingress-nginx Internal**: 10.1.100.203 (to be removed)
- **ingress-nginx External**: 10.1.100.202 (to be removed)

## Application LoadBalancer IPs
- DNS (blocky): 10.1.100.53
- Plex: 10.1.100.204
- Qbittorrent: 10.1.100.205
- Mosquitto: 10.1.100.206
- Authentik: 10.1.100.207

## Available IP Range
- **cilium-pool**: 10.1.100.220 - 10.1.100.230 (11 IPs available)

## Proposed Envoy Gateway IPs
- **Envoy Gateway Internal**: 10.1.100.220 (from cilium-pool)
- **Envoy Gateway External**: 10.1.100.221 (from cilium-pool)

## Migration Strategy
1. Deploy Envoy Gateway with new IPs (10.1.100.220, 10.1.100.221)
2. Migrate apps from Ingress/Cilium Gateway to Envoy Gateway HTTPRoute
3. Update DNS to point to new IPs (external-dns will handle this)
4. Remove Cilium Gateway API (freeing 10.1.100.200, 10.1.100.201)
5. Remove ingress-nginx (freeing 10.1.100.202, 10.1.100.203)

## Ingress Resources to Migrate (26 total)
default/bazarr, default/enigma-bbs-code, default/enigma-bbs-draw, default/homarr, 
default/jellyseerr, default/lidarr, default/prowlarr, default/qbittorrent, 
default/qui, default/radarr, default/readarr, default/sabnzbd, default/sonarr, 
default/tautulli, default/wizarr, network/echo-server, observability/blackbox-exporter, 
observability/dozzle, observability/gatus, observability/kromgo, 
observability/kube-prometheus-stack-alertmanager, observability/kube-prometheus-stack-prometheus, 
security/ak-outpost-56kbps, security/ak-outpost-external, security/ak-outpost-halfduplex, 
security/ak-outpost-internal

## Already on HTTPRoute (12 total, no migration needed)
default/jellyfin, default/overseerr, default/plex, default/romm, 
default/enigma-bbs-web, default/enigma-bbs-websocket,
flux-system/flux-webhook, network/http-to-https-redirect,
rook-ceph/ceph-dashboard, rook-ceph/ceph-objectstore-s3,
security/authentik-server-56kbps, security/authentik-server-halfduplex
