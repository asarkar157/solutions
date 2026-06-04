# CCE GitOps incident scope — clone at deployed SHA, map blast radius to Argo CD apps.

locals {
  sop_cce_gitops_scope = "cce-gitops-scope${local.suffix}"

  gitops_cce_enabled = var.enable_cce && trimspace(local.resolved_ubuntu_integration_name) != ""
}

resource "sg_runbook_sop" "cce_gitops_scope" {
  count   = var.enable_cce ? 1 : 0
  name    = local.sop_cce_gitops_scope
  approve = true
  description = trimspace(templatefile("${path.module}/templates/cce-gitops-scope.md.tftpl", {
    git_repo                  = var.git_repo
    argocd_app_label_selector = var.argocd_app_label_selector
  }))
}
