# End-state for Challenge 01 — "Otto is born".
#
# Creates the Haiku 4.5 model config in the per-student project, the
# otto-assistant Config, its initial bland "born" variation, and sets the
# `test` environment's fallthrough variation so the SDK serves it.

resource "launchdarkly_model_config" "haiku" {
  project_key    = var.project_key
  key            = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1_0"
  name           = "anthropic.claude-haiku-4-5-20251001-v1:0"
  model_id       = "anthropic.claude-haiku-4-5-20251001-v1:0"
  model_provider = "Bedrock"
  params         = jsonencode({ temperature = 0.7, maxTokens = 512 })
  tags           = ["instruqt"]
}

resource "launchdarkly_ai_config" "otto" {
  project_key = var.project_key
  key         = "otto-assistant"
  name        = "Otto Assistant"
  description = "ToggleWear's customer-facing shopping assistant."
  mode        = "completion"
  tags        = ["instruqt", "agentcontrol-intro"]
}

locals {
  # Otto's starting prompt. Competent but cold on purpose: he knows the catalog
  # and the policies, and has been told nothing about tone. That's what gives
  # the challenge-02 judge a real voice complaint rather than a knowledge
  # complaint, and it keeps his scores in challenge-03's review band instead of
  # bottoming out. See NARRATIVE.md — do not "improve" this prompt.
  otto_born_prompt = <<-PROMPT
    You are a customer service assistant for ToggleWear, an online retailer of LaunchDarkly-branded apparel. Answer questions from customers about products and store policies. Be accurate and concise.

    Products:
    - Rocket Tee, $28. Classic crew-neck t-shirt with the LaunchDarkly rocket. Heather grey. Runs true to size.
    - Feature Flag Hoodie, $58. Pullover hoodie, embroidered flag logo. Midnight navy. Heavyweight cotton blend.
    - Dark Mode Cap, $24. Six-panel dad cap, tone-on-tone black logo. Adjustable strap, one size.
    - Ship It Mug, $16. 12oz ceramic. Dishwasher safe.
    - Toggle Socks, $14. Crew socks with a small rocket at the ankle. Sizes S/M and L/XL.
    - Release Notes Notebook, $18. A5 hardcover, dot grid, 160 pages.
    - Rollout Tote, $22. 12oz canvas with reinforced handles.
    - Feature Branch Crewneck, $52. Heavyweight crewneck sweatshirt. Sage green.

    Apparel comes in XS through 3XL unless noted. Wash cold, tumble dry low.

    Policies: free shipping over $50, otherwise $6 flat. Domestic delivery 3-5 business days, international 7-14. Returns accepted within 30 days on unworn items. Gift cards are available in $25, $50, and $100.

    If a customer asks something these notes don't cover, say you don't know and point them to the product page or support.
  PROMPT
}

resource "launchdarkly_ai_config_variation" "otto_born" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.otto.key
  key              = "otto-born"
  name             = "Otto (Born)"
  model_config_key = launchdarkly_model_config.haiku.key

  messages {
    role    = "system"
    content = trimspace(local.otto_born_prompt)
  }
}

# The Terraform provider doesn't expose Config targeting yet — use the
# semantic-patch REST endpoint to set the test environment's fallthrough.
resource "null_resource" "set_test_fallthrough" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.otto_born.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/${launchdarkly_ai_config.otto.key}/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.otto_born.variation_id}"}]}'
    EOT
  }
}
