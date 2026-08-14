# End-state for Challenge 02 — "Otto Sounds Like Otto".
#
# Creates the custom brand-voice judge: a Config in judge mode whose prompt
# states ToggleWear's brand voice inline and grades a response against it.
#
# Resources:
#   * launchdarkly_ai_config           - otto-brand-voice-judge (mode = judge)
#   * launchdarkly_ai_config_variation - default variation, Haiku-backed,
#                                        prompt interpolates {{response}}
#   * null_resource set_..._fallthrough - turn the judge on by pointing the
#                                        test env fallthrough at default
#   * launchdarkly_metric              - otto-brand-voice-score (numeric, mean)
#   * null_resource attach_judge       - attach the judge to otto-born at 100%
#                                        sampling. No provider resource covers
#                                        judgeConfiguration, so this is REST.

locals {
  # ToggleWear's brand voice, stated inline. An earlier version of this track
  # pulled it from a `brand-voice` prompt snippet so one definition drove both
  # Otto's prompt and his grading criteria. Snippets are out of scope now, so
  # the text lives here. Keep it in sync with NARRATIVE.md.
  brand_voice_judge_prompt = <<-PROMPT
    You are evaluating whether a response from Otto, ToggleWear's shopping assistant, adheres to the brand voice we want him to use.

    The brand voice is:

    Otto is warm, helpful, and a little playful. He keeps answers short by default and he's honest when he doesn't know something.

    Score the response on a scale of 0.0 to 1.0:
    - 1.0: Strongly on-brand. Warm and a little playful, and it actually helps.
    - 0.7: Mostly on-brand with minor issues.
    - 0.4: Correct but cold. Accurate and useful, no warmth or personality.
    - 0.2: Declines to help, or is warm but unhelpful.
    - 0.0: Off-brand. Rude, off-topic, or contradicts the voice entirely.

    Judge tone, not correctness — assume the facts are right. Saying "I don't
    know" honestly is fine but is not on its own a high score; a good response
    still helps the customer get somewhere.

    Respond with ONLY a number between 0.0 and 1.0. No other text.

    Response to evaluate:
    {{response}}
  PROMPT
}

# ─── Brand-voice judge Config ──────────────────────────────────────────────

resource "launchdarkly_ai_config" "brand_voice_judge" {
  project_key = var.project_key
  key         = "otto-brand-voice-judge"
  name        = "Otto Brand Voice Judge"
  # The `$ld:ai:judge:` prefix is REQUIRED — the API rejects a bare metric name
  # with "evaluationMetricKey must start with \"$ld:ai:judge:\"". Verified
  # against a live account. This is the judge's own metric, distinct from the
  # plain otto-brand-voice-score custom metric the app emits directly.
  evaluation_metric_key = "$ld:ai:judge:otto-brand-voice-score"
  description           = "Scores Otto's responses 0.0-1.0 for adherence to ToggleWear's brand voice. Drives otto-brand-voice-score, which challenge 03's review gate reads."
  mode                  = "judge"
  tags                  = ["instruqt", "agentcontrol-mcp"]
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
        -H 'LD-API-Version: beta' \
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

# ─── Attach the judge to Otto's variation ──────────────────────────────────
#
# This is what puts the judge in otto-assistant's Judges panel with a sampling
# rate. It does NOT cause the judge to fire on its own: ldai has no Bedrock
# provider, so the app invokes the judge itself (see judge-server-paste.py).
# Attachment is the declared intent; the paste block is the mechanism.
#
# Sampling is 1.0 deliberately. Production would sample down for cost, but the
# app's judge call ignores the attached rate (it grades every response), and a
# gate that only sees a score a quarter of the time would ship the rest
# ungraded — which makes challenge 03 teach the wrong thing. Rather than have
# the declared rate disagree with the code, both are 100%.
#
# The `judges` array replaces the whole set on each call.

resource "null_resource" "attach_judge_to_otto_born" {
  depends_on = [launchdarkly_ai_config_variation.brand_voice_judge_default]

  triggers = {
    judge_key = launchdarkly_ai_config.brand_voice_judge.key
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/variations/otto-born' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        -H 'LD-API-Version: beta' \
        --data-raw '{"judgeConfiguration":{"judges":[{"judgeConfigKey":"${launchdarkly_ai_config.brand_voice_judge.key}","samplingRate":1.0}]}}'
    EOT
  }
}
