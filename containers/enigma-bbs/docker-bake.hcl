variable "VERSION" {
  default = "latest"
}

variable "PLATFORMS" {
  default = [
    "linux/amd64",
    "linux/arm64"
  ]
}

group "default" {
  targets = ["enigmabbs"]
}

target "enigmabbs" {
  dockerfile = "Dockerfile"
  platforms = PLATFORMS
  args = {
    ENIGMA_VERSION = VERSION
  }
  tags = [
    "ghcr.io/sob/enigma-bbs:${VERSION}",
    "ghcr.io/sob/enigma-bbs:rolling"
  ]
  labels = {
    "org.opencontainers.image.source" = "https://github.com/sob/home-ops"
    "org.opencontainers.image.created" = "${timestamp()}"
    "org.opencontainers.image.title" = "ENiGMA½ BBS (Non-Root)"
    "org.opencontainers.image.description" = "ENiGMA½ BBS running as non-root user 1000:1000"
    "org.opencontainers.image.licenses" = "MIT"
    "org.opencontainers.image.version" = "${VERSION}"
  }
}
