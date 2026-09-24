# The actions-runner base version doubles as the image version, so every build
# publishes a semver tag (ghcr.io/sob/arc-runner:2.337.0) that Renovate can
# follow in the runners HelmRelease. With the old "rolling" default CI only
# pushed <sha7>/rolling/sha256-<digest> tags, none of which Renovate can order,
# so the deployed pin sat on an Aug 2 image until GitHub retired its runner
# version (exit 7 -> ARC marked the scale set Outdated and deleted it).
variable "VERSION" {
  // renovate: datasource=docker depName=ghcr.io/actions/actions-runner
  default = "2.337.0"
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
  args = {
    RUNNER_VERSION = "${VERSION}"
  }
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
