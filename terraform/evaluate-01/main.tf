# End-state for Evaluate Challenge 01 — "Otto on the Bench".
#
# Three chained REST steps via null_resource + curl. Datasets, evaluations,
# and evaluation runs aren't exposed by the Terraform provider yet.
#
#   1. create_dataset       POST /datasets + PUT uploadUrl with the JSONL bytes
#   2. create_evaluation    POST /evaluations referencing the dataset + Otto
#   3. run_evaluation       POST /evaluations/{id}/runs
#
# setup-workstation applies only step 1 (`-target=null_resource.create_dataset`)
# so the learner arrives with the dataset pre-seeded; they create + run the
# evaluation themselves in the LD UI. solve-workstation applies all three so
# Skip lands in the same end state.
#
# VERIFY: several specifics inferred from the create-dataset MCP tool
# description and the LD docs at
# https://launchdarkly.com/docs/home/agentcontrol/offline-evaluations:
#   - upload URL accepts a PUT with `Content-Type: application/x-ndjson`
#   - POST /evaluations payload shape (`configKey`, `datasetId`,
#     `variationKeys`) inferred from the create-evaluation MCP schema
#   - "acceptance criteria" (the LLM-as-a-judge rubric an evaluation
#     grades against) appears to be UI-only at authoring time; this
#     module creates an eval without criteria, which may produce a run
#     that completes without grading data. Operator confirms during
#     click-through and adjusts (likely a PATCH /evaluations/{id} with
#     criteria, or a separate sub-resource).

locals {
  dataset_path     = "${path.module}/datasets/customer-questions.jsonl"
  dataset_filename = "customer-questions.jsonl"
  dataset_format   = "jsonl"
  evaluation_name  = "Otto Born baseline"

  dataset_bytes  = file(local.dataset_path)
  dataset_size   = length(local.dataset_bytes)
  dataset_sha256 = sha256(local.dataset_bytes)

  api_base = "https://app.launchdarkly.com/api/v2"
  int_base = "https://app.launchdarkly.com/internal"
}

resource "null_resource" "create_dataset" {
  triggers = {
    sha256 = local.dataset_sha256
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      ACCOUNT_ID=$(curl -s -X GET '${local.api_base}/account' \
          -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" | jq -r '._id')
      MEMBER_EMAIL='instruqt%2B${var.project_key}@launchdarkly.com'
      MEMBER_ID=$(curl -s -X GET '${local.api_base}/members?filter=email:$MEMBER_EMAIL' \
          -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" | jq -r '.items[0]._id')
      LD_PROJECT_ID=$(curl -s -X GET '${local.api_base}/projects/$LD_PROJECT_KEY' \
          -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" | jq -r '._id')

      CREATE_RESPONSE=$(curl -fsS -X POST \
        '${local.int_base}/projects/${var.project_key}/datasets' \
        -H 'Content-Type: application/json' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H "X-Ld-Accountid: $ACCOUNT_ID" \
        -H "X-Ld-Mbrid: $MEMBER_ID" \
        -H "X-Ld-Prjid: $LD_PROJECT_ID" \
        -H 'LD-API-Version: beta' \
        --data-raw '{
          "filename": "${local.dataset_filename}",
          "format": "${local.dataset_format}",
          "size_bytes": ${local.dataset_size},
          "name": "${local.evaluation_name}"
        }')

      UPLOAD_URL=$(echo "$CREATE_RESPONSE" | jq -r '.upload.uploadUrl')

      curl -fsS -X PUT "$UPLOAD_URL" \
        -H 'Content-Type: application/x-ndjson' \
        --data-binary @${local.dataset_path}
    EOT
  }
}

# Resolve the dataset ID by listing datasets and filtering by filename.
# Sidesteps the need to thread a value between local-exec calls.
resource "null_resource" "create_evaluation" {
  depends_on = [null_resource.create_dataset]

  triggers = {
    eval_name = local.evaluation_name
    config    = "otto-assistant"
    variation = "otto-born"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      DATASET_ID=$(curl -fsS -X GET \
        '${local.api_base}/projects/${var.project_key}/datasets' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        | jq -r '.items[]? | select(.filename == "${local.dataset_filename}") | .id' \
        | head -n 1)

      if [ -z "$DATASET_ID" ]; then
        echo "Could not locate the customer-questions dataset by filename."
        exit 1
      fi

      # If an evaluation with this name already exists, skip (idempotent).
      EXISTING=$(curl -fsS -X GET \
        '${local.api_base}/projects/${var.project_key}/evaluations' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        | jq -r '.items[]? | select(.name == "${local.evaluation_name}") | .id' \
        | head -n 1)

      if [ -n "$EXISTING" ]; then
        echo "Evaluation '${local.evaluation_name}' already exists (id=$EXISTING)."
        exit 0
      fi

      curl -fsS -X POST \
        '${local.api_base}/projects/${var.project_key}/evaluations' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        -H 'LD-API-Version: beta' \
        --data-raw "$(jq -n \
          --arg n '${local.evaluation_name}' \
          --arg c 'otto-assistant' \
          --arg d "$DATASET_ID" \
          '{name: $n, configKey: $c, datasetId: $d, variationKeys: ["otto-born"]}')" \
        > /dev/null
    EOT
  }
}

resource "null_resource" "run_evaluation" {
  depends_on = [null_resource.create_evaluation]

  # Bump the trigger to force a re-run on a fresh apply.
  triggers = {
    eval_name = local.evaluation_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      EVAL_ID=$(curl -fsS -X GET \
        '${local.api_base}/projects/${var.project_key}/evaluations' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'LD-API-Version: beta' \
        | jq -r '.items[]? | select(.name == "${local.evaluation_name}") | .id' \
        | head -n 1)

      if [ -z "$EVAL_ID" ]; then
        echo "Could not locate the '${local.evaluation_name}' evaluation by name."
        exit 1
      fi

      curl -fsS -X POST \
        '${local.api_base}/projects/${var.project_key}/evaluations/$EVAL_ID/runs' \
        -H "Authorization: $LAUNCHDARKLY_ACCESS_TOKEN" \
        -H 'Content-Type: application/json' \
        -H 'LD-API-Version: beta' \
        > /dev/null
    EOT
  }
}
