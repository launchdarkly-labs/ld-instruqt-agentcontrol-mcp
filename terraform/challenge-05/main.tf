# End-state for Challenge 05 — "Otto Knows His Audience".
#
# Module numbering follows substantive chapter, not directory order, and does
# not shift when chapters are reordered. See CLAUDE.md, "Two numbering
# schemes". This module is newer than challenge-04 but runs before it in the
# track.
#
# Adds a second Otto on a stronger model and a targeting rule that routes
# premium shoppers to it. Otto's personality is unchanged — same prompt, same
# catalog — so the only variable is the model. That keeps the chapter about
# routing, and it means the guarded rollout later is comparing models rather
# than prompts.
#
# Resources:
#   * launchdarkly_model_config        - Sonnet 4.5
#   * launchdarkly_ai_config_variation - otto-premium
#   * null_resource add_premium_rule   - tier == "premium" -> otto-premium.
#                                        The provider doesn't expose AI Config
#                                        targeting rules, so this is REST.

locals {
  # Byte-for-byte the same prompt as terraform/challenge-01's otto_born_prompt.
  # These two must stay in sync: the chapter's claim is that only the model
  # differs between the two variations, and the check asserts nothing about
  # prompt text, so a drift here would go unnoticed and quietly make the
  # premium comparison dishonest.
  #
  # If you change Otto's prompt, change it in both places. Prompt snippets are
  # the real fix for this and are out of scope — see 06-wrap-up.
  otto_prompt = <<-PROMPT
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

# `name` is load-bearing — server.py resolves Bedrock IDs through
# BEDROCK_MODEL_IDS keyed on it and passes unknown names straight through to
# Bedrock. This exact string is already a row in that table.
resource "launchdarkly_model_config" "sonnet" {
  project_key    = var.project_key
  key            = "Bedrock.anthropic.claude-sonnet-4-5-20250929-v1_0"
  name           = "anthropic.claude-sonnet-4-5-20250929-v1:0"
  model_id       = "anthropic.claude-sonnet-4-5-20250929-v1:0"
  model_provider = "Bedrock"
  params         = jsonencode({ temperature = 0.7, maxTokens = 512 })
  tags           = ["instruqt"]
}

resource "launchdarkly_ai_config_variation" "otto_premium" {
  project_key      = var.project_key
  config_key       = "otto-assistant"
  key              = "otto-premium"
  name             = "Otto (Premium)"
  model_config_key = launchdarkly_model_config.sonnet.key

  messages {
    role    = "system"
    content = trimspace(local.otto_prompt)
  }
}

# The attribute is `tier`, matching what the challenge-01 paste block puts on
# the context: Context.builder(session_id).set("tier", user_tier). A rule on
# any other spelling matches nobody and is indistinguishable from a rule that
# works, which is why the assignment calls it out and the check asserts it.
resource "null_resource" "add_premium_rule" {
  depends_on = [launchdarkly_ai_config_variation.otto_premium]

  triggers = {
    variation_id = launchdarkly_ai_config_variation.otto_premium.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{
          "environmentKey": "test",
          "instructions": [{
            "kind": "addRule",
            "description": "Premium shoppers get the stronger model",
            "variationId": "${launchdarkly_ai_config_variation.otto_premium.variation_id}",
            "clauses": [{
              "contextKind": "user",
              "attribute": "tier",
              "op": "in",
              "values": ["premium"],
              "negate": false
            }]
          }]
        }' || echo "(rule may already exist)"
    EOT
  }
}
