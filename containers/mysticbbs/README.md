# Mystic BBS Container

A containerized Mystic BBS bulletin board system with SSH access, FidoNet support, and runtime installation for cloud-native deployments.

## Features

- **Multi-architecture support**: x86_64, ARM64, ARM32
- **Runtime Installation**: Mystic installs to persistent storage on first run
- **Automatic Upgrades**: Detects and handles version upgrades automatically
- **Hook System**: Customizable lifecycle hooks for automation
- **SSH Server**: Built-in SSH server with cryptlib support
- **Telnet Access**: Traditional BBS telnet interface
- **FidoNet/BinkP**: Mailer support for FidoNet networks
- **Security Hardened**: Runs as non-root with read-only filesystem support

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MYSTIC_PATH` | `/mystic` | Installation directory for Mystic BBS (should match persistent volume mount) |
| `TZ` | `America/Chicago` | Timezone for the container |
| `MYSTIC_NODE` | (none) | Optional node identifier for multi-node setups |

## Installation Process

### Fresh Installation

On first run, if `$MYSTIC_PATH/mis` doesn't exist, the container performs a fresh installation:

1. Executes `pre-install.sh` hook (if present)
2. Runs Mystic installer from `/usr/local/share/mystic/install`
3. Installs to `$MYSTIC_PATH` with overwrite support
4. Executes `post-install.sh` hook (if present)
5. Copies documentation files (`whatsnew.txt`, `upgrade.txt`) to installation directory

### Automatic Upgrades

The container automatically detects upgrade scenarios:

**Upgrade Detection**: If `$MYSTIC_PATH/mystic.dat` exists but `$MYSTIC_PATH/mis` doesn't, an upgrade is performed.

**Upgrade Process**:
1. Executes `pre-upgrade.sh` hook (if present)
2. Runs upgrade utility from `/usr/local/share/mystic/upgrade`
3. Preserves existing data files (user accounts, message bases, file bases, etc.)
4. Executes `post-upgrade.sh` hook (if present)
5. Updates documentation files if they differ from container versions

**Documentation Updates**: On each container start, the system compares `whatsnew.txt` and `upgrade.txt` files. If the container versions differ from installed versions, they are automatically updated.

## Hook System

The container supports lifecycle hooks for automation and customization. Hooks are executable scripts placed in `$MYSTIC_PATH/hooks/`.

### Available Hooks

| Hook | When Executed | Use Cases |
|------|---------------|-----------|
| `pre-install.sh` | Before fresh installation | Pre-configure directories, download assets |
| `post-install.sh` | After fresh installation | Configure initial settings, import data |
| `pre-upgrade.sh` | Before upgrade process | Backup configurations, prepare for changes |
| `post-upgrade.sh` | After upgrade process | Migrate settings, run database updates |
| `startup.sh` | Every container start (after install/upgrade) | Start background services, health checks |
| `shutdown.sh` | On container shutdown | Cleanup tasks, graceful service shutdown |

### Hook Example

Create a hook to backup the configuration before upgrades:

```bash
# $MYSTIC_PATH/hooks/pre-upgrade.sh
#!/bin/bash
BACKUP_DIR="$MYSTIC_PATH/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
tar -czf "$BACKUP_DIR/mystic-backup-$TIMESTAMP.tar.gz" \
    "$MYSTIC_PATH/data" \
    "$MYSTIC_PATH/*.dat" \
    "$MYSTIC_PATH/*.ini"
echo "Backup created: mystic-backup-$TIMESTAMP.tar.gz"
```

Remember to make hooks executable: `chmod +x $MYSTIC_PATH/hooks/*.sh`

## Filesystem Layout

The container follows the Filesystem Hierarchy Standard (FHS):

```
/usr/local/share/mystic/     # Mystic installer files (read-only)
├── install                  # Fresh installation executable
├── install_data.mys        # Installation data file
├── upgrade                 # Upgrade utility executable
├── whatsnew.txt           # Version changelog
└── upgrade.txt            # Upgrade documentation

/usr/local/bin/             # Symlinks for PATH access
├── mystic-install -> /usr/local/share/mystic/install
└── mystic-upgrade -> /usr/local/share/mystic/upgrade

$MYSTIC_PATH/               # Runtime installation (persistent volume)
├── mis                    # Mystic server executable
├── mystic.dat            # Main configuration file
├── data/                 # User data, message bases, file bases
├── logs/                 # Server logs
├── hooks/                # Lifecycle hook scripts
├── whatsnew.txt         # Version changelog (auto-updated)
└── upgrade.txt          # Upgrade documentation (auto-updated)
```

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
      - MYSTIC_PATH=/config  # Must match volume mount
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