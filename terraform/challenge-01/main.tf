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

resource "launchdarkly_ai_config_variation" "otto_born" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.otto.key
  key              = "otto-born"
  name             = "Otto (Born)"
  model_config_key = launchdarkly_model_config.haiku.key

  messages {
    role    = "system"
    content = "You are a customer service assistant for ToggleWear, an online retailer. Answer questions from customers about products and store policies. Be accurate and concise."
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
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.otto_born.variation_id}"}]}'
    EOT
  }
}
