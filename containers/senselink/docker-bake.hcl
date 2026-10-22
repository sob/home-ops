# SenseLink (cbpowell/SenseLink) rebuilt on a current Python. Upstream's last
# release is 2.2.1 (2024-01-01) and its image is on python:3.10-slim, which is
# end of life; the code itself runs unchanged on 3.14 (see selftest.py).
variable "VERSION" {
  // renovate: datasource=github-tags depName=cbpowell/SenseLink
  default = "2.2.1"
}

variable "PLATFORMS" {
  default = [
    "linux/amd64",
    "linux/arm64"
  ]
}

group "default" {
  targets = ["senselink"]
}

target "senselink" {
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  args = {
    SENSELINK_VERSION = "${VERSION}"
  }
  tags = [
    "ghcr.io/sob/senselink:${VERSION}",
    "ghcr.io/sob/senselink:rolling"
  ]
  labels = {
    "org.opencontainers.image.source"      = "https://github.com/sob/home-ops"
    "org.opencontainers.image.created"     = "${timestamp()}"
    "org.opencontainers.image.title"       = "SenseLink"
    "org.opencontainers.image.description" = "Virtual TP-Link HS110 plugs that report MQTT power readings to a Sense monitor"
    "org.opencontainers.image.licenses"    = "MIT"
    "org.opencontainers.image.version"     = "${VERSION}"
  }
}
