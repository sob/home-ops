variable "VERSION" {
  default = "master"
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
    NODE_VERSION = "22"
  }
  tags = [
    "ghcr.io/sob/enigma-bbs:${VERSION}",
    "ghcr.io/sob/enigma-bbs:rolling"
  ]
  labels = {
    "org.opencontainers.image.source" = "https://github.com/sob/home-ops"
    "org.opencontainers.image.created" = "${timestamp()}"
    "org.opencontainers.image.title" = "ENiGMA½ BBS (Multi-Arch)"
    "org.opencontainers.image.description" = "ENiGMA½ BBS built from source for amd64 and arm64"
    "org.opencontainers.image.licenses" = "MIT"
    "org.opencontainers.image.version" = "${VERSION}"
  }
}
