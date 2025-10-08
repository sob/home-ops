variable "VERSION" {
  // renovate: datasource=custom.mysticbbs depName=mystic-bbs versioning=loose
  default = "112a48"
}

variable "MAJOR_VERSION" {
  default = "112"
}


variable "PLATFORMS" {
  default = [
    "linux/amd64",
    "linux/arm64"
  ]
}

group "default" {
  targets = ["mysticbbs"]
}

target "mysticbbs" {
  dockerfile = "Dockerfile"
  platforms = PLATFORMS
  tags = [
    "ghcr.io/sob/mysticbbs:${VERSION}",
    "ghcr.io/sob/mysticbbs:${MAJOR_VERSION}",
    "ghcr.io/sob/mysticbbs:rolling"
  ]
  labels = {
    "org.opencontainers.image.source" = "https://github.com/seobrien/home-ops"
    "org.opencontainers.image.created" = "${timestamp()}"
    "org.opencontainers.image.title" = "Mystic BBS"
    "org.opencontainers.image.description" = "Mystic BBS running in a container with SSH access and FidoNet BinkP support"
    "org.opencontainers.image.licenses" = "MIT"
    "org.opencontainers.image.version" = "${VERSION}"
  }
}