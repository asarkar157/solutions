output "cce_pack_version" {
  description = "Version string for CCE script pack baked into Ubuntu env."
  value       = local.cce_pack_version
}

output "cce_pack_tarball_b64" {
  description = "base64-encoded tar.gz of cce-common.sh, cce-scan.sh, cce-pr-delta.sh for CCE_PACK_B64 env."
  value       = filebase64(data.archive_file.cce_pack.output_path)
}

output "cce_pack_dir" {
  description = "Recommended extract directory on Ubuntu sidecar (under integration home)."
  value       = "/home/integration/.aios-cce/pack/${local.cce_pack_version}"
}
