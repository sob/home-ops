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
  dockerfile = "Containerfile"
  platforms = PLATFORMS
  tags = [
    "ghcr.io/sob/mysticbbs:${VERSION}",
    "ghcr.io/sob/mysticbbs:${MAJOR_VERSION}",
    "ghcr.io/sob/mysticbbs:rolling"
  ]
}