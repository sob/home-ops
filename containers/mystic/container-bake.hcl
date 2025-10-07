variable "ROLLING_TAG" {
  default = "rolling"
}

variable "VERSION" {
  default = "latest"
}

target "mystic" {
  dockerfile = "Dockerfile"
  tags = [
    "ghcr.io/sob/mystic:${ROLLING_TAG}",
    "ghcr.io/sob/mystic:${VERSION}"
  ]
  platforms = ["linux/amd64", "linux/arm64"]
  labels = {
    "org.opencontainers.image.source" = "https://github.com/seobrien/home-ops"
    "org.opencontainers.image.created" = "${timestamp()}"
    "org.opencontainers.image.title" = "Mystic BBS"
    "org.opencontainers.image.description" = "Mystic BBS running in a container with SSH access and FidoNet BinkP support"
    "org.opencontainers.image.licenses" = "MIT"
  }
}

group "default" {
  targets = ["mystic"]
}