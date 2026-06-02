terraform {
  required_version = ">= 1.5"
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

# Tarball of scripts/ for Ubuntu sidecar env (CCE_PACK_B64).
data "archive_file" "cce_pack" {
  type        = "tar.gz"
  source_dir  = "${path.module}/scripts"
  output_path = "${path.module}/.generated/cce-pack-${local.cce_pack_version}.tar.gz"
}

locals {
  cce_pack_version = "20260602.4"
}
