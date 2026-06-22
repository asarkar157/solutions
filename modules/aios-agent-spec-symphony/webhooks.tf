# GitHub + Linear webhook receivers.

resource "sg_webhook" "github_receiver" {
  name        = local.github_webhook_name
  target_type = "workflow"
  target_name = sg_workflow.spec_driven_feature.name
  action      = "A GitHub issue or PR was opened. Clone the repo, bootstrap SDD artifacts, implement per spec, validate, open PR, and update the tracker."
  enabled     = true
}

# Legacy: full spec-driven-feature factory from Linear (optional; prefer linear-product-spec + linear-spec-implement).
resource "sg_webhook" "linear_receiver" {
  name        = local.linear_webhook_name
  target_type = "workflow"
  target_name = sg_workflow.spec_driven_feature.name
  action      = "A Linear issue event was received. Parse payload, clone linked repo, run spec-driven factory pipeline, update Linear ticket on completion."
  enabled     = var.enable_legacy_linear_factory_webhook

  allowed_cidrs = length(var.linear_webhook_allowed_cidrs) > 0 ? var.linear_webhook_allowed_cidrs : null
}

resource "sg_webhook" "linear_product_spec_receiver" {
  count = local.create_linear_product_spec ? 1 : 0

  name        = local.linear_product_spec_webhook_name
  target_type = "workflow"
  target_name = sg_workflow.linear_product_spec[0].name
  action      = "Linear product ticket with ${var.linear_product_spec_label} label: author golden-template spec, decompose engineering subgoals, post Linear comment."
  enabled     = true

  allowed_cidrs = length(var.linear_webhook_allowed_cidrs) > 0 ? var.linear_webhook_allowed_cidrs : null
}

resource "sg_webhook" "linear_spec_implement_receiver" {
  count = local.create_linear_implement ? 1 : 0

  name        = local.linear_spec_implement_webhook_name
  target_type = "workflow"
  target_name = sg_workflow.linear_spec_implement[0].name
  action      = "Linear issue with ${var.linear_implement_label} label: fetch blessed spec comment, clone repo, Cursor implement subgoals, open PR, post Linear status."
  enabled     = true

  allowed_cidrs = length(var.linear_webhook_allowed_cidrs) > 0 ? var.linear_webhook_allowed_cidrs : null
}
