# End-state for Challenge 03 — "Otto on-brand at scale".
#
# Creates two prompt snippets (brand-voice, safety-rules) via REST and updates
# otto-born to reference them. Prompt snippets aren't yet exposed by the
# Terraform provider, so this is all null_resource + curl.
#
locals {
  brand_voice_text  = "You are Otto. You're warm, helpful, and a little playful. You keep answers short by default and you're honest when you don't know something."
  safety_rules_text = "Don't make up prices, sizes, or policies. If you don't know, say so and suggest the customer check the product page or contact support. Don't discuss topics outside of ToggleWear and the products we sell."

  refactored_prompt = <<-PROMPT
    {{snippet.brand-voice#1}}

    You work at ToggleWear, an online shop for LaunchDarkly-branded apparel. Help customers find products, answer questions about sizing and care, and guide them when they're not sure what they want.

    {{snippet.safety-rules#1}}
  PROMPT
}

resource "null_resource" "create_brand_voice_snippet" {
  triggers = { text_hash = sha256(local.brand_voice_text) }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X POST \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/prompt-snippets' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        --data-raw "$(jq -n --arg t "${local.brand_voice_text}" \
          '{key:"brand-voice", name:"Brand voice", text:$t, tags:["instruqt"]}')" \
        || echo "(snippet may already exist — continuing)"
    EOT
  }
}

resource "null_resource" "create_safety_rules_snippet" {
  triggers = { text_hash = sha256(local.safety_rules_text) }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X POST \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/prompt-snippets' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        --data-raw "$(jq -n --arg t "${local.safety_rules_text}" \
          '{key:"safety-rules", name:"Safety rules", text:$t, tags:["instruqt"]}')" \
        || echo "(snippet may already exist — continuing)"
    EOT
  }
}

resource "null_resource" "update_variation_prompt" {
  depends_on = [
    null_resource.create_brand_voice_snippet,
    null_resource.create_safety_rules_snippet,
  ]

  triggers = { prompt_hash = sha256(local.refactored_prompt) }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/variations/otto-born' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        --data-raw "$(jq -n --arg c "${trimspace(local.refactored_prompt)}" \
          '{messages: [{role: "system", content: $c}]}')"
    EOT
  }
}
