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
  targets = ["arc-runner"]
}

target "arc-runner" {
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  tags = [
    "ghcr.io/sob/arc-runner:rolling"
  ]
  labels = {
    "org.opencontainers.image.source"      = "https://github.com/sob/home-ops"
    "org.opencontainers.image.created"      = "${timestamp()}"
    "org.opencontainers.image.title"        = "ARC Runner with Android SDK"
    "org.opencontainers.image.description"  = "GitHub Actions Runner Controller runner image with Android SDK"
    "org.opencontainers.image.licenses"     = "MIT"
    "org.opencontainers.image.version"      = "${VERSION}"
  }
}
