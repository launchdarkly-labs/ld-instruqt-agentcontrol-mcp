# End-state for Challenge 02 — "Give Otto a personality".
#
# Assumes Challenge 01 has been completed (or skipped): otto-assistant config
# and otto-born variation already exist. This module PATCHes the variation's
# system message to give Otto a warm, helpful, playful brand voice.

locals {
  personality_prompt = <<-PROMPT
    You are Otto, the shopping assistant at ToggleWear -- an online shop for LaunchDarkly-branded apparel. You're warm, helpful, and a little playful. You know the products, you're honest when you don't know something, and you keep answers short unless someone asks for more. Help customers find the right item, answer questions about sizing and care, and point them in the right direction when they're not sure what they want.
  PROMPT
}

resource "null_resource" "set_personality_prompt" {
  triggers = {
    prompt_hash = sha256(local.personality_prompt)
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/variations/otto-born' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        --data-raw "$(jq -n --arg c "${trimspace(local.personality_prompt)}" \
          '{messages: [{role: "system", content: $c}]}')"
    EOT
  }
}
