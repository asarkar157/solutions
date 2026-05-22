terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.19, < 0.2.0"
    }
  }
}

# Provider/github shaped secret — the shape the Ubuntu integration's
# pre_launch.sh unpacks into GIT_TOKEN / GIT_HOST / GIT_USERNAME env vars.
# Agent modules attach this secret to their internal Ubuntu integration via
# `secret_ref_ids`, which lets the SOPs run `git clone` and `gh api` against
# private repos without a token-capture step.
#
# Guild server requires `token` as the canonical metadata key for the
# Provider/github category (see internal/guild/secretrouter: required key
# "token"). The Ubuntu image's pre_launch.sh ALSO accepts the `git_host` /
# `git_username` companions and re-exports them as `GIT_HOST` /
# `GIT_USERNAME`; those are passed alongside so the launcher script has
# everything it needs without forking the image.
resource "sg_secret" "provider_github" {
  name        = "${var.name}-provider-github-vault"
  description = var.description
  category    = "Provider"
  subcategory = "github"
  metadata = {
    token        = var.github_token
    git_host     = var.git_host
    git_username = var.git_username
  }
}
