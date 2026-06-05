locals {
  aiden_server_url = (
    var.aiden_server_url != "" ? var.aiden_server_url :
    var.aiden_server_url_append_ai ? "${trimsuffix(var.aiden_mothership_url, "/")}/ai" :
    var.aiden_mothership_url
  )
  stackgen_url = var.aiden_stackgen_url != "" ? var.aiden_stackgen_url : var.aiden_mothership_url
}

resource "helm_release" "aiden_remote_runner" {
  for_each = toset(nonsensitive(keys(var.aiden_runner_tokens)))

  name             = each.key
  repository       = var.aiden_runner_chart_repository
  chart            = var.aiden_runner_chart_name
  namespace        = each.key
  create_namespace = true
  timeout          = var.aiden_runner_helm_timeout
  wait             = true

  set_sensitive {
    name  = "remote-runner.configMap.STACKGEN_RUNNER_TOKEN"
    value = var.aiden_runner_tokens[each.key]
  }

  set {
    name  = "remote-runner.configMap.STACKGEN_URL"
    value = local.stackgen_url
    type  = "string"
  }

  # Legacy key for older chart images
  set_sensitive {
    name  = "remote-runner.configMap.RUNNER_ID"
    value = var.aiden_runner_tokens[each.key]
  }

  set {
    name  = "remote-runner.configMap.SERVER_URL"
    value = local.aiden_server_url
    type  = "string"
  }

  dynamic "set" {
    for_each = var.aiden_auto_discover ? ["true"] : []
    content {
      name  = "remote-runner.configMap.AUTO_DISCOVER"
      value = set.value
      type  = "string"
    }
  }

  set {
    name  = "remote-runner.image.repository"
    value = var.aiden_runner_image_name
  }

  set {
    name  = "remote-runner.image.tag"
    value = var.aiden_runner_image_version
  }

  depends_on = [aws_eks_node_group.main]
}
