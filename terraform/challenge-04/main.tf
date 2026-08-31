# End-state for Challenge 04 — "Trust But Verify".
#
# Lifted from the AI Configs intro workshop's Evaluate ch07 and rewired to be
# driven from the MCP server rather than the LaunchDarkly UI. See DECISIONS.md,
# "Guarded rollout added back as a fifth chapter".
#
# Resources:
#   * launchdarkly_model_config        - Amazon Nova Pro. Applied by
#                                        setup-workstation via -target BEFORE
#                                        the learner prompts, because its
#                                        `name` is load-bearing for the app.
#   * launchdarkly_ai_config_variation - otto-stiff, the deliberately off-brand
#                                        variation the rollout is going to try
#                                        and then reject.
#   * null_resource attach_judge       - grade Stiff with the same brand-voice
#                                        judge that grades Born, so the metric
#                                        is comparing like with like.
#   * null_resource fallthrough_rollout - the solve-path rollout. NOT a guarded
#                                        rollout; see the long comment on that
#                                        resource for why.
#
# What this module deliberately does NOT do: create the otto-brand-voice-score
# metric or the judge. Both come from challenge-02, and the whole point of this
# chapter is that the judge you already wrote becomes the thing that guards a
# release.

locals {
  # Deliberately, comically corporate — the opposite of the brand voice stated
  # in NARRATIVE.md and graded by challenge-02's judge. The judge should hate
  # this, and the metric should show it. Keep the contrast obvious: a subtly
  # off-brand prompt makes for a rollout that takes too long to regress inside
  # a lab's time budget.
  stiff_prompt = <<-PROMPT
    You are a customer service representative for ToggleWear.

    Assist customers with their inquiries in a professional and formal manner.
    Always greet the customer formally, provide thorough and complete
    explanations, and conclude each response with a formal sign-off. Maintain a
    corporate tone at all times. Avoid contractions, humour, and informality.
  PROMPT
}

# ─── The risky model ───────────────────────────────────────────────────────
#
# `name` matters more than it looks. server.py resolves the served model
# through BEDROCK_MODEL_IDS, keyed on the name LaunchDarkly hands back, and
# falls through to a pass-through if it misses. "amazon.nova-pro-v1:0" is
# already a row in that table; a friendly display name like "Amazon Nova Pro"
# is not, and would reach Bedrock verbatim and 400.
#
# That fragility is why setup-workstation applies this resource with -target
# before the learner prompts, rather than letting the agent pick a name.

resource "launchdarkly_model_config" "nova_pro" {
  project_key    = var.project_key
  key            = "Bedrock.amazon.nova-pro-v1_0"
  name           = "amazon.nova-pro-v1:0"
  model_id       = "amazon.nova-pro-v1:0"
  model_provider = "Bedrock"
  params         = jsonencode({ temperature = 0.7, maxTokens = 512 })
  tags           = ["instruqt"]
}

# ─── The off-brand variation ───────────────────────────────────────────────

resource "launchdarkly_ai_config_variation" "otto_stiff" {
  project_key      = var.project_key
  config_key       = "otto-assistant"
  key              = "otto-stiff"
  name             = "Otto (Stiff)"
  model_config_key = launchdarkly_model_config.nova_pro.key

  messages {
    role    = "system"
    content = trimspace(local.stiff_prompt)
  }
}

# ─── Grade Stiff with the same judge that grades Born ──────────────────────
#
# The app invokes the judge itself for every response regardless of which
# variation served, so this attachment doesn't change what gets scored. It
# makes the declared intent match the behaviour, and it's what puts Stiff's
# scores next to Born's in the Monitoring view — which is the comparison the
# guarded rollout is making.

resource "null_resource" "attach_judge_to_otto_stiff" {
  depends_on = [launchdarkly_ai_config_variation.otto_stiff]

  triggers = {
    variation_key = launchdarkly_ai_config_variation.otto_stiff.key
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/variations/otto-stiff' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        -H 'LD-API-Version: beta' \
        --data-raw '{"judgeConfiguration":{"judges":[{"judgeConfigKey":"otto-brand-voice-judge","samplingRate":1.0}]}}' \
        || echo "(judge attach failed — challenge-02 may not have been applied)"
    EOT
  }
}

# ─── Solve-path rollout ────────────────────────────────────────────────────
#
# READ THIS BEFORE "FIXING" IT.
#
# This is a plain percentage rollout, not a guarded one, and that is a known
# gap rather than an oversight.
#
# The public REST API has no instruction that starts a guarded rollout. As of
# authoring, the semantic-patch instruction list on
# PATCH /projects/{proj}/ai-configs/{key}/targeting is 21 kinds long and the
# only rollout instruction is `updateFallthroughVariationOrRollout`, which
# takes plain `rolloutWeights`. The regular flag endpoint is the same. The
# `ReleaseGuardianConfiguration` schema exists in the OpenAPI spec but is
# referenced only from the release-pipeline models, not from flag or AI Config
# targeting. Verified against app.launchdarkly.com/api/v2/openapi.json.
#
# The MCP server does expose a guarded rollout — that's what the learner drives
# in the assignment — but solve must not depend on an LLM (see CLAUDE.md), so
# it can't go through MCP to get it.
#
# The consequence: a learner who clicks Skip lands on Stiff taking 10% of
# traffic with no regression detection and no auto-rollback. That is NOT the
# end state a successful learner reaches. check-workstation is written to
# accept it anyway, because failing the operator's own escape hatch is worse.
#
# If a public guarded-rollout instruction ships, replace this resource and
# tighten the check's HAS_GUARD branch at the same time.

resource "null_resource" "fallthrough_rollout" {
  depends_on = [launchdarkly_ai_config_variation.otto_stiff]

  triggers = {
    variation_id = launchdarkly_ai_config_variation.otto_stiff.variation_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Read otto-born's id from the CONFIG endpoint, not the targeting one.
      # Targeting variations expose `_id`, `name` and `value` but NO `key`, so
      # `select(.key==...)` there always matches nothing — which made this
      # resource skip the rollout silently and left Skip unable to satisfy
      # check-workstation. The config endpoint carries both, and the semantic
      # patch below wants a variationId, which is what `_id` is.
      # Docs: launchdarkly.com/docs/api/agent-control/get-ai-config-targeting
      CONFIG=$(curl -fsS -X GET \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta')

      BORN_ID=$(printf '%s' "$CONFIG" | jq -r 'first(.variations[]? | select(.key=="otto-born") | ._id) // empty')
      STIFF_ID='${launchdarkly_ai_config_variation.otto_stiff.variation_id}'

      if [ -z "$BORN_ID" ] || [ "$BORN_ID" = "null" ]; then
        echo "(no otto-born variation — challenge-01 not applied; skipping rollout)"
        exit 0
      fi

      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/projects/${var.project_key}/ai-configs/otto-assistant/targeting' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw "$(jq -n --arg stiff "$STIFF_ID" --arg born "$BORN_ID" '
          {
            environmentKey: "test",
            instructions: [{
              kind: "updateFallthroughVariationOrRollout",
              rolloutContextKind: "user",
              rolloutWeights: { ($stiff): 10000, ($born): 90000 }
            }]
          }')"
    EOT
  }
}
