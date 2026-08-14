# End-state for Challenge 03 — "Otto Asks for Help".
#
# Creates the JSON flag that holds the review gate's score bands, and turns it
# on in `test`. The thresholds live in LaunchDarkly rather than in server.py so
# the band can be retuned while the app is running — that's the whole point of
# the challenge.
#
# Resources:
#   * launchdarkly_feature_flag  - otto-review-thresholds (JSON, 2 variations)
#   * null_resource              - turn targeting on in `test`
#
# The gate logic itself is applied by patch-server.py, not from here.

resource "launchdarkly_feature_flag" "review_thresholds" {
  project_key = var.project_key
  key         = "otto-review-thresholds"
  name        = "Otto Review Thresholds"
  description = "Score bands for the human review gate. At or above `auto`, Otto's answer ships. Between `review` and `auto`, it's held for a human. Below `review`, it's suppressed."

  variation_type = "json"

  variations {
    name  = "Balanced"
    value = jsonencode({ auto = 0.8, review = 0.5 })
  }

  variations {
    name  = "Cautious"
    value = jsonencode({ auto = 0.95, review = 0.7 })
  }

  defaults {
    on_variation  = 0
    off_variation = 0
  }

  tags = ["instruqt", "agentcontrol-mcp"]
}

# A flag defaults to off, and an off flag serves off_variation — which is the
# same Balanced value here, so the gate still works. Turn it on anyway so the
# learner sees a live flag rather than one that only appears to work.
resource "null_resource" "enable_review_thresholds" {
  triggers = {
    flag_key = launchdarkly_feature_flag.review_thresholds.key
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -fsS -X PATCH \
        'https://app.launchdarkly.com/api/v2/flags/${var.project_key}/${launchdarkly_feature_flag.review_thresholds.key}' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
        --data-raw '{"environmentKey":"test","instructions":[{"kind":"turnFlagOn"}]}'
    EOT
  }
}
