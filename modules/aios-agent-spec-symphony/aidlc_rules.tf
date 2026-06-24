# AI-DLC rules are fetched from awslabs/aidlc-workflows releases at apply time (not checked into git).

locals {
  aidlc_rules_version_tag = startswith(trimspace(var.aidlc_rules_version), "v") ? trimspace(var.aidlc_rules_version) : "v${trimspace(var.aidlc_rules_version)}"
  aidlc_rules_dir         = "${path.module}/.generated/aidlc-rules"
}

resource "null_resource" "aidlc_rules_fetch" {
  triggers = {
    version = local.aidlc_rules_version_tag
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/fetch-aidlc-rules.sh '${trimspace(var.aidlc_rules_version)}' '${local.aidlc_rules_dir}'"
  }
}
