terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen" }
  }
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
  model_names = [var.model_names.gpt4o, var.model_names.claude_sonnet]
}

resource "sg_agent" "marketing_pr" {
  name        = "pr-communications-lead"
  persona     = file("${path.module}/personas/marketing-pr.md")
  model_names = [var.model_names.gpt4o, var.model_names.claude_sonnet]
}

resource "sg_agent" "marketing_analytics" {
  name        = "marketing-analyst"
  persona     = file("${path.module}/personas/marketing-analytics.md")
  model_names = [var.model_names.gpt4o, var.model_names.claude_sonnet]
}

resource "sg_agent" "marketing_sales_enablement" {
  name        = "sales-enablement-lead"
  persona     = file("${path.module}/personas/marketing-sales-enablement.md")
  model_names = [var.model_names.gpt4o, var.model_names.claude_sonnet]
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
  description = "Develop product positioning and messaging framework. Steps: 1) Conduct competitive landscape analysis using Crayon/Klue — identify top 3 competitors and their positioning, 2) Run customer interview synthesis to extract top 5 pain points and desired outcomes, 3) Draft value proposition canvas: target persona, pain points addressed, key benefits, proof points, 4) Create messaging hierarchy: tagline (< 10 words), elevator pitch (30 s), one-paragraph positioning statement, 5) Develop competitive differentiation matrix with feature-by-feature comparison, 6) Circulate draft to product, sales, and executive stakeholders for async review (48 h window), 7) Incorporate feedback and publish final messaging doc to Notion/Confluence, 8) Brief content and sales teams in a 30-min enablement session."
}

resource "sg_runbook_sop" "press_release_distribution" {
  name        = "press-release-distribution"
  description = "Draft and distribute product launch press release. Steps: 1) Draft press release following AP style — headline, dateline, lead paragraph (who/what/when/where/why), supporting quotes from CEO and customer, boilerplate, 2) Internal review cycle: product marketing (accuracy), legal (claims compliance, trademark usage), executive (quote approval) — 72 h lead time, 3) Finalize embargo date and time (coordinate with analyst briefings and social media), 4) Upload to newswire service (PR Newswire or Business Wire) with targeting: industry verticals, geographic regions, media lists, 5) Send personalized pitch emails to tier-1 journalists 48 h before embargo lift, 6) Monitor embargo compliance and field journalist questions, 7) On embargo lift: publish to company newsroom, share on corporate social channels, 8) Track coverage for 7 days: clip articles, measure share of voice, compile coverage report."
}

resource "sg_runbook_sop" "social_media_launch_campaign" {
  name        = "social-media-launch-campaign"
  description = "Coordinate multi-platform social media launch campaign. Steps: 1) Build content calendar: 2-week pre-launch teaser cadence, launch-day blitz, 1-week post-launch sustain, 2) Create platform-specific assets: LinkedIn (long-form post + carousel), X/Twitter (thread + key visual), YouTube (60 s product demo), Instagram (story sequence + reel), 3) Define hashtag strategy: branded hashtag + 3-5 industry hashtags per platform, 4) Schedule posts in Sprout Social/Hootsuite aligned with embargo lift timestamp, 5) Activate employee advocacy program: distribute pre-written posts to internal champions via Bambu/PostBeyond, 6) Launch influencer outreach: send product briefing kits to 10-15 industry voices with early access, 7) Monitor engagement in real-time on launch day: respond to comments within 30 min, escalate negative sentiment, 8) Compile 48 h post-launch social analytics: impressions, engagement rate, link clicks, follower growth."
}

resource "sg_runbook_sop" "email_nurture_sequence" {
  name        = "email-nurture-sequence"
  description = "Build and launch email nurture sequence for product announcement. Steps: 1) Define audience segments in HubSpot/Marketo: existing customers (upsell), prospects in pipeline (acceleration), cold leads (re-engagement), newsletter subscribers (awareness), 2) Write email sequence: E1 announcement (launch day), E2 feature deep-dive (day +3), E3 customer story/case study (day +7), E4 demo invitation (day +10), E5 limited-time offer (day +14), 3) A/B test subject lines for E1 and E4 (minimum 1,000 recipients per variant), 4) Configure send triggers and delays in automation workflow, 5) Set up UTM parameters for each email link, 6) Run deliverability pre-check: SPF/DKIM/DMARC validation, spam score test via Litmus/Email on Acid, 7) Launch sequence and monitor: open rate (target > 25%), click rate (target > 3%), unsubscribe rate (threshold < 0.5%), 8) Pause and adjust if unsubscribe rate exceeds threshold."
}

resource "sg_runbook_sop" "landing_page_optimization" {
  name        = "landing-page-optimization"
  description = "Create and optimize product launch landing page. Steps: 1) Design wireframe: hero with headline + subhead + CTA, feature grid (3-4 key capabilities), social proof section (logos + testimonial quote), pricing/plan comparison, FAQ accordion, bottom CTA, 2) Build page in CMS with mobile-responsive layout, 3) Set up A/B test variants: test headline, CTA copy, hero image, 4) Configure UTM parameter capture in hidden form fields, 5) Connect analytics: GA4 page_view event, Mixpanel track signup_started, HubSpot form submission, 6) Set up conversion goals in GA4 and heatmap tracking via Hotjar/FullStory, 7) Launch page at embargo lift and drive traffic from email, social, paid, 8) Review A/B test results after 500 conversions per variant — declare winner at 95% statistical significance."
}

resource "sg_runbook_sop" "sales_enablement_kit" {
  name        = "sales-enablement-kit"
  description = "Assemble sales enablement kit for product launch. Steps: 1) Create battle card: 1-page competitive comparison (our product vs top 3 competitors) with win/loss themes, pricing comparison, strengths/weaknesses, recommended talk tracks, 2) Develop demo script: 15-min guided walkthrough covering top 3 use cases, 3) Write objection handling playbook: top 10 buyer objections with recommended responses, supporting data points, and customer proof points, 4) Build sales deck: 12-slide max, 5) Create pricing FAQ: list vs street pricing, discount authority matrix, packaging differences, migration pricing, 6) Upload all materials to Highspot/Seismic/Google Drive sales enablement hub, 7) Run 45-min enablement training with sales team, 8) Schedule readiness check with sales leadership 2 weeks before launch."
}

resource "sg_runbook_sop" "analyst_briefing_prep" {
  name        = "analyst-briefing-prep"
  description = "Prepare and execute industry analyst briefings for product launch. Steps: 1) Identify target analysts: Gartner (MQ/MarketGuide authors), Forrester (Wave/Now Tech authors), IDC (MarketScape contributors), 2) Schedule briefings 3-4 weeks before public launch, 3) Prepare briefing deck: company overview, market context, product announcement with architecture diagram, competitive differentiation, customer traction metrics, roadmap highlights, 4) Rehearse presentation — target 25 min presentation + 35 min Q&A, 5) Prepare briefing guide: key messages, expected questions, topics to avoid, 6) Send pre-briefing materials 48 h before meeting under embargo, 7) Conduct briefings and take detailed notes on analyst feedback, 8) Send follow-up thank-you within 24 h, 9) Schedule inquiry calls post-launch."
}

resource "sg_runbook_sop" "launch_metrics_dashboard" {
  name        = "launch-metrics-dashboard"
  description = "Set up launch metrics tracking and reporting dashboard. Steps: 1) Define launch KPIs: website traffic, sign-ups/demo requests, MQLs generated, pipeline created ($), social engagement, press coverage, email performance, paid media efficiency, 2) Configure UTM tracking taxonomy, 3) Set up Mixpanel/GA4 conversion funnels, 4) Build Looker/Tableau dashboard, 5) Configure automated Slack alerts for #marketing-launch channel, 6) Schedule daily standup report for first 2 weeks, 7) Prepare week-1 and week-4 launch retrospective reports, 8) Archive dashboard template for reuse."
}

# ============================================================================
# Product Launch Workflow
# ============================================================================

resource "sg_workflow" "product_launch" {
  name        = "product-launch"
  domain      = "marketing"
  description = "Orchestrates a full go-to-market launch: conducts competitive research, produces messaging and content in parallel with sales enablement materials, coordinates embargo-aware press and social media distribution on launch day, and tracks post-launch KPIs across traffic, sign-ups, pipeline, and press coverage."

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
      note         = "Analytics agent runs competitive analysis via Crayon/Klue and produces the positioning brief."
    },
    {
      stage_id         = "content-creation"
      agent_ref        = sg_agent.marketing_content.name
      stage_depends_on = ["market-research"]
      runbook_refs     = [sg_runbook_sop.product_messaging_framework.name, sg_runbook_sop.landing_page_optimization.name, sg_runbook_sop.email_nurture_sequence.name]
      note             = "Content agent drafts the messaging hierarchy, landing page and email copy, and social media assets."
    },
    {
      stage_id         = "sales-enablement"
      agent_ref        = sg_agent.marketing_sales_enablement.name
      stage_depends_on = ["market-research"]
      runbook_refs     = [sg_runbook_sop.sales_enablement_kit.name, sg_runbook_sop.analyst_briefing_prep.name]
      note             = "Sales-enablement agent creates battle cards, demo scripts, objection playbooks, and analyst briefing materials."
    },
    {
      stage_id         = "launch-coordination"
      agent_ref        = sg_agent.marketing_pr.name
      stage_depends_on = ["content-creation", "sales-enablement"]
      runbook_refs     = [sg_runbook_sop.press_release_distribution.name, sg_runbook_sop.social_media_launch_campaign.name]
      note             = "PR agent manages the embargo schedule, distributes the press release, and coordinates the social media blitz."
    },
    {
      stage_id         = "post-launch-analysis"
      agent_ref        = sg_agent.marketing_analytics.name
      stage_depends_on = ["launch-coordination"]
      runbook_refs     = [sg_runbook_sop.launch_metrics_dashboard.name]
      note             = "Analytics agent configures the Looker dashboard, sets up Slack alerts, and generates daily and weekly reports."
    },
  ]
}
