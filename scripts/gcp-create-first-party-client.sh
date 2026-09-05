#!/usr/bin/env bash
set -euo pipefail

# Cloud Run Job がプロジェクト内から hydra-admin を叩く。プロキシ不要。
# redirect は Terraform の app_origin/callback。変えるときは app_origin を apply してから再実行。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
ENV="${ENV:?set ENV to dev or prd}"
REGION="${REGION:-asia-southeast1}"

# shellcheck source=gcp-use-sa.sh
source "${ROOT}/scripts/gcp-use-sa.sh"

gcloud run jobs execute "hydra-create-client-${ENV}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --wait
