# End-state for Evaluate Challenge 07 — "Trust But Verify".
#
# Adds the deliberately-off-brand otto-stiff variation backed by Amazon
# Nova Pro. The guarded rollout that watches otto-brand-voice-score (the
# metric introduced by Evaluate ch03) will auto-rollback this variation
# once organic traffic + the brand-voice judge drag the metric below
# threshold.
#
# Much smaller than the legacy challenge-07 module because:
#   * The brand-voice judge already exists from ch03.
#   * otto-brand-voice-score metric already exists from ch03.
#   * otto-assistant.evaluationMetricKey is already wired to it from ch03.
#   * server.py's judge-invocation block is already in place from ch03.
#
# This module just adds the new model + risky variation. The learner
# configures the guarded rollout in the LD UI — that's the pedagogical
# centerpiece.

locals {
  stiff_prompt = "You are a customer service representative. Please assist customers with their inquiries in a professional and formal manner. Always greet the customer formally, provide thorough explanations, and conclude each response with a formal sign-off. Maintain a corporate tone at all times."
}

resource "launchdarkly_model_config" "nova_pro" {
  project_key    = var.project_key
  key            = "Amazon.nova-pro"
  name           = "Amazon Nova Pro"
  model_id       = "nova-pro"
  model_provider = "amazon"
  params         = jsonencode({ temperature = 0.7, maxTokens = 512 })
  tags           = ["instruqt"]
}

resource "launchdarkly_ai_config_variation" "otto_stiff" {
  project_key      = var.project_key
  config_key       = "otto-assistant"
  key              = "otto-stiff"
  name             = "Otto (Stiff)"
  model_config_key = launchdarkly_model_config.nova_pro.key

  messages {
    role    = "system"
    content = local.stiff_prompt
  }
}
