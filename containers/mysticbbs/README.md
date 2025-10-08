# Mystic BBS Container

A containerized Mystic BBS bulletin board system with SSH access and FidoNet support.

## Features

- **Multi-architecture support**: x86_64, ARM64, ARM32
- **SSH Server**: Built-in SSH server with cryptlib support
- **Telnet Access**: Traditional BBS telnet interface  
- **FidoNet/BinkP**: Mailer support for FidoNet networks
- **Cloudflare Tunnel Ready**: Pre-configured for web-based access

## Usage

### Docker Compose

```yaml
services:
  mystic-bbs:
    image: ghcr.io/seobrien/mystic:latest
    container_name: mystic-bbs
    ports:
      - "23:23"   # Telnet
      - "22:22"   # SSH
      - "24554:24554" # BinkP/Mailer
    volumes:
      - mystic-config:/config
    environment:
      - TZ=America/Chicago
    restart: unless-stopped

volumes:
  mystic-config:
```

### Kubernetes (Helm)

```yaml
# Example HelmRelease for Flux CD
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: mystic-bbs
  namespace: default
spec:
  chart:
    spec:
      chart: app-template
      version: 3.5.1
      sourceRef:
        kind: HelmRepository
        name: bjw-s
        namespace: flux-system
  values:
    controllers:
      mystic-bbs:
        containers:
          app:
            image:
              repository: ghcr.io/seobrien/mystic
              tag: latest
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities:
                drop: ["ALL"]
                add: ["NET_BIND_SERVICE"]
    service:
      app:
        controller: mystic-bbs
        ports:
          telnet:
            port: 23
          ssh:
            port: 22
          binkp:
            port: 24554
    persistence:
      config:
        size: 1Gi
        globalMounts:
          - path: /config
```

## Initial Setup

1. **First Time Setup**: Connect via telnet to configure the system:
   ```bash
   telnet localhost 23
   ```

2. **Configure SSH Server**: In Mystic configuration menu:
   - Go to System → Configuration → Servers
   - Enable SSH server on port 22
   - Configure users and access levels

3. **Configure BinkP/Mailer**: For FidoNet connectivity:
   - System → Configuration → Networks
   - Set up your FidoNet node information
   - Configure mailer settings for BinkP

## Cloudflare Tunnel Integration

The container is designed to work with Cloudflare tunnels for web-based access:

```yaml
# In cloudflared config.yaml
ingress:
  - hostname: "bbs.yourdomain.com"
    service: tcp://mystic-bbs:23
  - hostname: "ssh.yourdomain.com" 
    service: ssh://mystic-bbs:22
  - hostname: "mailer.yourdomain.com"
    service: tcp://mystic-bbs:24554
```

## Architecture Support

- **linux/amd64**: x86_64 systems
- **linux/arm64**: ARM64/aarch64 systems (Raspberry Pi 4+, Apple Silicon, etc.)
- **linux/arm/v7**: ARM32/armv7l systems (Raspberry Pi 3, etc.)

## Technical Details

- **Base Image**: Ubuntu 24.04
- **Mystic BBS Version**: A48 (112a48)
- **SSH Support**: cryptlib 3.4.5
- **User**: Runs as nobody (65534:65534)
- **Volumes**: Configuration stored in `/config`

## Building

The container is built automatically via GitHub Actions when changes are pushed to the `containers/mystic/` directory.

```bash
# Manual build
docker build -t mystic-bbs containers/mystic/

# Multi-architecture build
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t mystic-bbs containers/mystic/
```

## Troubleshooting

### SSH Not Working
- Ensure cryptlib library is loaded: `ldd /usr/lib/libcl.so`
- Check SSH server is enabled in Mystic configuration
- Verify port 22 is properly exposed

### Permission Issues
- Container runs as UID/GID 65534 (nobody)
- Ensure volume permissions allow access for this user
- Use `chown -R 65534:65534 /path/to/mystic/data` if needed

### Log Files
```bash
# View container logs
docker logs mystic-bbs

# Access Mystic logs inside container
docker exec mystic-bbs tail -f /mystic/logs/server.log
```

## Related Links

- [Mystic BBS Official Site](https://www.mysticbbs.com/)
- [Mystic BBS Wiki](http://wiki.mysticbbs.com/)
- [FidoNet Information](http://www.fidonet.org/)
- [Cryptlib Documentation](http://www.cs.auckland.ac.nz/~pgut001/cryptlib/)