#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
ENV="${ENV:?set ENV to dev or prd}"
REGION="${REGION:-asia-southeast1}"

# shellcheck source=gcp-use-sa.sh
source "${ROOT}/scripts/gcp-use-sa.sh"

gcloud run jobs execute "kratos-migrate-${ENV}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --wait

gcloud run jobs execute "hydra-migrate-${ENV}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --wait
