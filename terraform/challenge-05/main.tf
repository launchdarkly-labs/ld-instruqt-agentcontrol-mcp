# End-state for Challenge 05 — "Otto for everyone".
#
# Adds a premium-tier variation (Sonnet 4.6) and a targeting rule that routes
# contexts with `tier: "premium"` to it. Free-tier shoppers keep getting the
# Haiku-backed Otto from earlier challenges.
#
# Assumes Challenges 01-03 have been completed: otto-assistant exists with
# otto-born as the test fallthrough, and brand-voice + safety-rules snippets
# exist in the project.
#
# Anthropic.claude-sonnet-4-6 is a GLOBAL model config (shipped by LD), so
# unlike Haiku we don't have to create it ourselves. Must match the model
# the learner picks in the UI (the assignment specifies claude-sonnet-4-6).

locals {
  premium_prompt = <<-PROMPT
    {{snippet.brand-voice#1}}

    You work at ToggleWear and you're talking to a premium customer. Take a little more time with them. Offer thoughtful recommendations, mention complementary items when relevant, and share interesting product details (materials, care, the story behind a design). You can be a bit warmer and more conversational.

    {{snippet.safety-rules#1}}
  PROMPT
}

resource "launchdarkly_ai_config_variation" "otto_premium" {
  project_key      = var.project_key
  config_key       = "otto-assistant"
  key              = "otto-premium"
  name             = "Otto (Premium)"
  model_config_key = "Bedrock.anthropic.claude-sonnet-4-6"

  messages {
    role    = "system"
    content = trimspace(local.premium_prompt)
  }
}

# Add a targeting rule: contexts with tier=premium → otto-premium.
# Config targeting isn't yet in the Terraform provider — use semantic patch.
resource "null_resource" "add_premium_rule" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.otto_premium.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw "$(jq -n --arg vid "${launchdarkly_ai_config_variation.otto_premium.variation_id}" '
          {
            environmentKey: "test",
            instructions: [{
              kind: "addRule",
              variationId: $vid,
              clauses: [{
                contextKind: "user",
                attribute: "tier",
                op: "in",
                negate: false,
                values: ["premium"]
              }]
            }]
          }')"
    EOT
  }
}
