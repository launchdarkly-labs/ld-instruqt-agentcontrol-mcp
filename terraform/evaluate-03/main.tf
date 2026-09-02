# End-state for Evaluate Challenge 03 — "Otto Sounds Like Otto".
#
# Creates the custom brand-voice judge — a Config in judge mode whose prompt
# pulls in the L1 `brand-voice` snippet. The same snippet now drives both
# Otto's prompt (in otto-assistant) AND the criteria he's graded against.
#
# Resources:
#   * launchdarkly_ai_config       - otto-brand-voice-judge (mode = judge)
#   * launchdarkly_ai_config_variation - default variation, Haiku-backed,
#                                       prompt references {{snippet.brand-voice#1}}
#                                       and {{response}}
#   * null_resource set_judge_fallthrough - turn the judge on by pointing
#                                          test env fallthrough at default
#   * launchdarkly_metric          - otto-brand-voice-score (numeric, mean)
#   * null_resource wire_evaluation_metric - PATCH otto-assistant's
#                                           evaluationMetricKey to point at
#                                           this metric. Evaluate ch07's
#                                           guarded rollout reads this.

locals {
  brand_voice_judge_prompt = <<-PROMPT
    You are evaluating whether a response from Otto, ToggleWear's shopping assistant, adheres to the brand voice we want him to use.

    The brand voice is:

    {{snippet.brand-voice#1}}

    Score the response on a scale of 0.0 to 1.0:
    - 1.0: Strongly on-brand. Warm, helpful, a little playful, honest, concise.
    - 0.7: Mostly on-brand with minor issues.
    - 0.4: Lacking warmth or has noticeable voice issues.
    - 0.0: Off-brand. Robotic, off-topic, or contradicts the voice entirely.

    Respond with ONLY a number between 0.0 and 1.0. No other text.

    Response to evaluate:
    {{response}}
  PROMPT
}

# ─── Brand-voice judge Config ──────────────────────────────────────────────

resource "launchdarkly_ai_config" "brand_voice_judge" {
  project_key           = var.project_key
  key                   = "otto-brand-voice-judge"
  name                  = "Otto Brand Voice Judge"
  evaluation_metric_key = "$ld:ai:judge:otto-brand-voice-judge"
  description           = "Scores Otto's responses 0.0-1.0 for adherence to the brand-voice snippet. Drives otto-brand-voice-score; Evaluate ch07's guarded rollout watches this."
  mode                  = "judge"
  tags                  = ["instruqt", "ai-configs-intro"]
}

resource "launchdarkly_ai_config_variation" "brand_voice_judge_default" {
  project_key      = var.project_key
  config_key       = launchdarkly_ai_config.brand_voice_judge.key
  key              = "default"
  name             = "Default"
  model_config_key = "Bedrock.anthropic.claude-haiku-4-5-20251001-v1:0"

  messages {
    role    = "system"
    content = trimspace(local.brand_voice_judge_prompt)
  }
}

resource "null_resource" "set_brand_voice_judge_fallthrough" {
  triggers = {
    variation_id = launchdarkly_ai_config_variation.brand_voice_judge_default.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/${launchdarkly_ai_config.brand_voice_judge.key}/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"updateFallthroughVariationOrRollout","variationId":"${launchdarkly_ai_config_variation.brand_voice_judge_default.variation_id}"}]}'
    EOT
  }
}

# ─── Brand-voice score metric ──────────────────────────────────────────────

resource "launchdarkly_metric" "brand_voice_score" {
  project_key           = var.project_key
  key                   = "otto-brand-voice-score"
  name                  = "Otto Brand Voice Score"
  description           = "Mean brand-voice judge score (0.0-1.0) for Otto's responses. Higher is better."
  kind                  = "custom"
  event_key             = "otto-brand-voice-score"
  is_numeric            = true
  unit                  = "score"
  unit_aggregation_type = "average"
  success_criteria      = "HigherThanBaseline"
  analysis_type         = "mean"
  randomization_units   = ["user"]
  tags                  = ["instruqt"]
}

# ─── Wire the metric onto otto-assistant ───────────────────────────────────
#
# otto-assistant was created by Build's challenge-01 module; we can't update
# it from here without `terraform import`. PATCH the evaluationMetricKey
# directly via REST.

# resource "null_resource" "wire_evaluation_metric" {
#   depends_on = [launchdarkly_metric.brand_voice_score,
#                 launchdarkly_ai_config.brand_voice_judge]

#   triggers = {
#     metric_key = launchdarkly_metric.brand_voice_score.key
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       curl -fsS -X PATCH \
#         'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-brand-voice-judge' \
#         -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
#         -H 'Content-Type: application/json' \
#         --data-raw '{"evaluationMetricKey":"otto-brand-voice-score"}'
#     EOT
#   }
# }
