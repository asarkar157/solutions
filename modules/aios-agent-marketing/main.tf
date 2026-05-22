terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.19, < 0.2.0" }
  }
}

locals {
  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_content_name      = "content-strategist${local.suffix}"
  agent_pr_name           = "pr-communications-lead${local.suffix}"
  agent_analytics_name    = "marketing-analyst${local.suffix}"
  agent_sales_enable_name = "sales-enablement-lead${local.suffix}"

  workflow_product_launch_name = "product-launch${local.suffix}"

  sop_messaging_name = "product-messaging-framework${local.suffix}"
  sop_press_name     = "press-release-distribution${local.suffix}"
  sop_social_name    = "social-media-launch-campaign${local.suffix}"
  sop_email_name     = "email-nurture-sequence${local.suffix}"
  sop_landing_name   = "landing-page-optimization${local.suffix}"
  sop_sales_kit_name = "sales-enablement-kit${local.suffix}"
  sop_analyst_name   = "analyst-briefing-prep${local.suffix}"
  sop_metrics_name   = "launch-metrics-dashboard${local.suffix}"
}

# ============================================================================
# Marketing Domain Module
# ============================================================================
# Contains marketing agents, runbook SOPs for product launch operations, and
# the product-launch workflow with its execution plan. This module demonstrates
# a non-SRE workflow where multiple personas (content, PR, analytics, sales
# enablement) collaborate through a DAG to execute a product go-to-market.

# ============================================================================
# Marketing Agents
# ============================================================================

resource "sg_agent" "marketing_content" {
  name        = "content-strategist"
  persona     = file("${path.module}/personas/marketing-content.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "marketing_pr" {
  name        = "pr-communications-lead"
  persona     = file("${path.module}/personas/marketing-pr.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "marketing_analytics" {
  name        = "marketing-analyst"
  persona     = file("${path.module}/personas/marketing-analytics.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "marketing_sales_enablement" {
  name        = "sales-enablement-lead"
  persona     = file("${path.module}/personas/marketing-sales-enablement.md")
  model_names = compact(var.model_names)
}

# ============================================================================
# Marketing Agent Budgets
# ============================================================================
# All marketing agents share Tier 3 ($10/day) — text-heavy content generation
# with moderate model usage. No shell/runtime execution keeps costs predictable.

resource "sg_agent_budget" "marketing_content" {
  agent_name  = sg_agent.marketing_content.name
  limit_usd   = 10
  period_type = "daily"
}

resource "sg_agent_budget" "marketing_pr" {
  agent_name  = sg_agent.marketing_pr.name
  limit_usd   = 10
  period_type = "daily"
}

resource "sg_agent_budget" "marketing_analytics" {
  agent_name  = sg_agent.marketing_analytics.name
  limit_usd   = 10
  period_type = "daily"
}

resource "sg_agent_budget" "marketing_sales_enablement" {
  agent_name  = sg_agent.marketing_sales_enablement.name
  limit_usd   = 10
  period_type = "daily"
}

# ============================================================================
# Marketing Policy Attachments
# ============================================================================

resource "sg_agent_policy_attachment" "marketing_content_dangerous_ops" {
  agent_name = sg_agent.marketing_content.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "marketing_pr_dangerous_ops" {
  agent_name = sg_agent.marketing_pr.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "marketing_analytics_dangerous_ops" {
  agent_name = sg_agent.marketing_analytics.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "marketing_sales_enablement_dangerous_ops" {
  agent_name = sg_agent.marketing_sales_enablement.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# ============================================================================
# Marketing Runbook SOPs
# ============================================================================

resource "sg_runbook_sop" "product_messaging_framework" {
  name        = "product-messaging-framework"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/product-messaging-framework.md", {}))
}

resource "sg_runbook_sop" "press_release_distribution" {
  name        = "press-release-distribution"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/press-release-distribution.md", {}))
}

resource "sg_runbook_sop" "social_media_launch_campaign" {
  name        = "social-media-launch-campaign"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/social-media-launch-campaign.md", {}))
}

resource "sg_runbook_sop" "email_nurture_sequence" {
  name        = "email-nurture-sequence"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/email-nurture-sequence.md", {}))
}

resource "sg_runbook_sop" "landing_page_optimization" {
  name        = "landing-page-optimization"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/landing-page-optimization.md", {}))
}

resource "sg_runbook_sop" "sales_enablement_kit" {
  name        = "sales-enablement-kit"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/sales-enablement-kit.md", {}))
}

resource "sg_runbook_sop" "analyst_briefing_prep" {
  name        = "analyst-briefing-prep"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/analyst-briefing-prep.md", {}))
}

resource "sg_runbook_sop" "launch_metrics_dashboard" {
  name        = "launch-metrics-dashboard"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/launch-metrics-dashboard.md", {}))
}

# ============================================================================
# Product Launch Workflow
# ============================================================================

resource "sg_workflow" "product_launch" {
  name        = "product-launch"
  domain      = "marketing"
  description = trimspace(templatefile("${path.module}/templates/workflow-product-launch.md", {}))
  approve     = true

  triggers = [
    { field = "campaign_type", values = ["product_launch", "feature_launch", "go_to_market"], type = "passive" },
  ]

  required_inputs = ["product_name", "launch_date"]
  optional_inputs = ["target_market", "budget", "campaign_type"]

  runbook_refs = [
    sg_runbook_sop.product_messaging_framework.name,
    sg_runbook_sop.press_release_distribution.name,
    sg_runbook_sop.social_media_launch_campaign.name,
    sg_runbook_sop.email_nurture_sequence.name,
    sg_runbook_sop.landing_page_optimization.name,
    sg_runbook_sop.sales_enablement_kit.name,
    sg_runbook_sop.analyst_briefing_prep.name,
    sg_runbook_sop.launch_metrics_dashboard.name,
  ]

  example_queries = [
    "We're launching StackGen Analytics on April 15 — kick off the GTM workflow",
    "Prepare a go-to-market plan for the new AI copilot feature",
    "Our Q2 product launch needs messaging, sales decks, and a press release",
    "Start the product launch pipeline for the enterprise tier upgrade",
    "Can you coordinate the launch campaign across content, PR, and sales?",
    "We need battle cards and landing page copy ready before the analyst briefings",
    "Set up launch-day tracking for the new developer platform release",
  ]

  stages = [
    {
      stage_id    = "market-research"
      description = "Analyse the competitive landscape, size the TAM, and define the ICP to inform product positioning"
      note        = "Output a positioning brief with top-3 competitors, pricing and feature gaps, the target ICP, and 3-5 key differentiators."
      required    = true
    },
    {
      stage_id    = "content-creation"
      description = "Draft the complete content suite: messaging framework, landing page copy with A/B variants, email nurture sequence, launch blog post, and social media assets"
      note        = "All copy must align with the positioning brief from market-research. Runs in parallel with sales-enablement."
      required    = true
    },
    {
      stage_id    = "sales-enablement"
      description = "Build the complete sales toolkit: competitive battle cards, demo script, objection handling playbook, sales deck, and pricing FAQ"
      note        = "Coordinate with product marketing on pricing tiers. Prepare analyst briefing decks. Runs in parallel with content-creation."
      required    = true
    },
    {
      stage_id    = "launch-coordination"
      description = "Execute launch-day operations: distribute the press release via newswire, activate the social media blitz, send the announcement email, and brief journalists and analysts"
      note        = "Respect the embargo timeline. Activate the employee advocacy program. Monitor embargo compliance."
      required    = true
    },
    {
      stage_id    = "post-launch-analysis"
      description = "Track and report launch KPIs: website traffic, sign-up conversion rate, MQLs generated, pipeline created, social engagement, and press coverage share-of-voice"
      note        = "Configure UTM tracking and Mixpanel funnels on launch day. Generate automated daily Slack reports for 2 weeks."
      required    = true
    },
  ]

  stage_bindings = [
    {
      stage_id     = "market-research"
      agent_ref    = sg_agent.marketing_analytics.name
      runbook_refs = [sg_runbook_sop.launch_metrics_dashboard.name]
      skill_refs   = concat(["gtm-competitive-positioning"], try(var.workflow_skill_refs["product-launch::market-research"], []))
      note         = "Analytics agent runs competitive analysis via Crayon/Klue and produces the positioning brief."
    },
    {
      stage_id         = "content-creation"
      agent_ref        = sg_agent.marketing_content.name
      stage_depends_on = ["market-research"]
      runbook_refs     = [sg_runbook_sop.product_messaging_framework.name, sg_runbook_sop.landing_page_optimization.name, sg_runbook_sop.email_nurture_sequence.name]
      skill_refs       = concat(["gtm-messaging-landing-email"], try(var.workflow_skill_refs["product-launch::content-creation"], []))
      note             = "Content agent drafts the messaging hierarchy, landing page and email copy, and social media assets."
    },
    {
      stage_id         = "sales-enablement"
      agent_ref        = sg_agent.marketing_sales_enablement.name
      stage_depends_on = ["market-research"]
      runbook_refs     = [sg_runbook_sop.sales_enablement_kit.name, sg_runbook_sop.analyst_briefing_prep.name]
      skill_refs       = concat(["gtm-sales-enablement-kit"], try(var.workflow_skill_refs["product-launch::sales-enablement"], []))
      note             = "Sales-enablement agent creates battle cards, demo scripts, objection playbooks, and analyst briefing materials."
    },
    {
      stage_id         = "launch-coordination"
      agent_ref        = sg_agent.marketing_pr.name
      stage_depends_on = ["content-creation", "sales-enablement"]
      runbook_refs     = [sg_runbook_sop.press_release_distribution.name, sg_runbook_sop.social_media_launch_campaign.name]
      skill_refs       = concat(["gtm-press-social-launch"], try(var.workflow_skill_refs["product-launch::launch-coordination"], []))
      note             = "PR agent manages the embargo schedule, distributes the press release, and coordinates the social media blitz."
    },
    {
      stage_id         = "post-launch-analysis"
      agent_ref        = sg_agent.marketing_analytics.name
      stage_depends_on = ["launch-coordination"]
      runbook_refs     = [sg_runbook_sop.launch_metrics_dashboard.name]
      skill_refs       = concat(["gtm-launch-kpi-reporting"], try(var.workflow_skill_refs["product-launch::post-launch-analysis"], []))
      note             = "Analytics agent configures the Looker dashboard, sets up Slack alerts, and generates daily and weekly reports."
    },
  ]
}
