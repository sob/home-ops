variable "VERSION" {
  default = "rolling"
}

variable "PLATFORMS" {
  default = [
    "linux/amd64",
    "linux/arm64"
  ]
}

group "default" {
  targets = ["text0wnz"]
}

target "text0wnz" {
  dockerfile = "Dockerfile"
  platforms = PLATFORMS
  tags = [
    "ghcr.io/sob/text0wnz:${VERSION}",
    "ghcr.io/sob/text0wnz:rolling"
  ]
  labels = {
    "org.opencontainers.image.source" = "https://github.com/sob/home-ops"
    "org.opencontainers.image.created" = "${timestamp()}"
    "org.opencontainers.image.title" = "text0wnz with server-side storage"
    "org.opencontainers.image.description" = "ANSI art editor with file management API for server-side storage"
    "org.opencontainers.image.licenses" = "MIT"
    "org.opencontainers.image.version" = "${VERSION}"
  }
}
