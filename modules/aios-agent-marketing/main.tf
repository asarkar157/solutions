terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.0.20" }
  }
}

# =============================================================================
# Marketing Operations Agent Module
# =============================================================================
# AI-powered marketing agent for content ops, campaign analytics,
# social monitoring, SEO, and email marketing automation.

resource "sg_agent" "marketing_ops" {
  name        = "marketing-ops"
  persona     = file("${path.module}/personas/marketing-ops.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  hitl = {
    always_allowed = [
      "web_search",
      "note",
      "read_notes"
    ]
  }

  integrations = compact([
    lookup(var.integration_names, "slack", "") != "" ? var.integration_names.slack : null,
    lookup(var.integration_names, "google", "") != "" ? var.integration_names.google : null,
    lookup(var.integration_names, "linear", "") != "" ? var.integration_names.linear : null,
  ])
}

resource "sg_agent_budget" "marketing_ops" {
  agent_name  = sg_agent.marketing_ops.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.marketing_ops.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# --- Runbooks ---

resource "sg_runbook_sop" "content_brief_generation" {
  name        = "content-brief-generation"
  description = <<-EOT
    Generate a structured content brief for a new piece of content.

    Steps:
    1) Research the target topic using web search to identify trending angles and competitor coverage.
    2) Define target persona, funnel stage, and primary/secondary keywords.
    3) Outline content structure (H2/H3 hierarchy), recommended word count, and CTA.
    4) Identify internal linking opportunities from existing content.
    5) Draft the brief in a shared Google Doc and assign to the content writer in Linear.
  EOT
}

resource "sg_runbook_sop" "campaign_performance_report" {
  name        = "campaign-performance-report"
  description = <<-EOT
    Generate a campaign performance analysis report.

    Steps:
    1) Collect campaign metrics: impressions, clicks, CTR, conversions, and spend.
    2) Calculate key derived metrics: CPA, ROAS, and conversion rate by channel.
    3) Compare against industry benchmarks and previous campaign performance.
    4) Identify top-performing creatives and audience segments.
    5) Generate recommendations for budget reallocation and creative optimization.
    6) Post summary to the #marketing Slack channel with actionable insights.
  EOT
}

resource "sg_runbook_sop" "social_media_audit" {
  name        = "social-media-audit"
  description = <<-EOT
    Comprehensive social media presence audit.

    Steps:
    1) Review posting frequency and consistency across all active channels.
    2) Analyze engagement rates (likes, comments, shares) over the past 30 days.
    3) Identify top-performing content themes and formats.
    4) Assess audience growth trajectory and follower demographics.
    5) Monitor competitor activity and identify content gaps.
    6) Recommend content mix adjustments and optimal posting schedule.
  EOT
}

resource "sg_runbook_sop" "seo_content_audit" {
  name        = "seo-content-audit"
  description = <<-EOT
    SEO health check for website content.

    Steps:
    1) Crawl target pages for missing meta descriptions, broken links, and thin content.
    2) Analyze keyword rankings for target terms using search data.
    3) Check Core Web Vitals and page load performance.
    4) Identify cannibalization (multiple pages competing for same keywords).
    5) Prioritize fixes by potential traffic impact.
    6) Create remediation tickets in Linear for the content team.
  EOT
}

resource "sg_runbook_sop" "email_sequence_design" {
  name        = "email-sequence-design"
  description = <<-EOT
    Design and optimize an email marketing sequence.

    Steps:
    1) Define the sequence goal (nurture, onboarding, re-engagement, etc.).
    2) Map the audience segment and entry triggers.
    3) Draft email copy for each touchpoint (subject, preview, body, CTA).
    4) Specify send timing, A/B test variants, and personalization tokens.
    5) Define success metrics (open rate, click rate, conversion).
    6) Submit for compliance review (CAN-SPAM, GDPR opt-out).
  EOT
}

# --- Workflows ---

resource "sg_workflow" "content_pipeline" {
  name        = "content-pipeline"
  domain      = "marketing"
  description = "End-to-end content production pipeline: research, brief, draft review, SEO optimization, and publishing coordination."

  example_queries = [
    "Create a blog post brief about AI in DevOps",
    "Generate our weekly content calendar for next month",
    "Audit our blog for SEO issues and create fix tickets",
    "Draft social media copy for our product launch",
  ]

  stages = [
    { stage_id = "research-and-brief", description = "Research topic and generate a structured content brief.", required = true },
    { stage_id = "seo-optimization", description = "Optimize content for search with keywords, meta tags, and internal links.", required = true },
    { stage_id = "publish-and-distribute", description = "Coordinate cross-channel publishing and social promotion.", required = true },
  ]

  stage_bindings = [
    { stage_id = "research-and-brief", agent_ref = sg_agent.marketing_ops.name, runbook_refs = [sg_runbook_sop.content_brief_generation.name] },
    { stage_id = "seo-optimization", agent_ref = sg_agent.marketing_ops.name, stage_depends_on = ["research-and-brief"], runbook_refs = [sg_runbook_sop.seo_content_audit.name] },
    { stage_id = "publish-and-distribute", agent_ref = sg_agent.marketing_ops.name, stage_depends_on = ["seo-optimization"], runbook_refs = [sg_runbook_sop.social_media_audit.name] },
  ]
}

resource "sg_workflow" "campaign_analytics" {
  name        = "campaign-analytics"
  domain      = "marketing"
  description = "Campaign performance analysis with data-driven optimization recommendations."

  example_queries = [
    "How are our Q2 campaigns performing?",
    "Which ad creatives have the best ROAS?",
    "Generate a monthly marketing performance report",
    "What's our customer acquisition cost trend?",
  ]

  stages = [
    { stage_id = "collect-metrics", description = "Gather campaign data across all channels.", required = true },
    { stage_id = "analyze-and-recommend", description = "Analyze performance and generate optimization recommendations.", required = true },
  ]

  stage_bindings = [
    { stage_id = "collect-metrics", agent_ref = sg_agent.marketing_ops.name, runbook_refs = [sg_runbook_sop.campaign_performance_report.name] },
    { stage_id = "analyze-and-recommend", agent_ref = sg_agent.marketing_ops.name, stage_depends_on = ["collect-metrics"] },
  ]
}
