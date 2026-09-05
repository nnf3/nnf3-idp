#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
ENV="${ENV:-dev}"
REGION="${REGION:-asia-southeast1}"
BUCKET="${TFSTATE_BUCKET:-${PROJECT_ID}-nnf3-idp-tfstate}"

# shellcheck source=gcp-use-sa.sh
source "${ROOT}/scripts/gcp-use-sa.sh"

gcloud services enable \
  storage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com \
  iam.googleapis.com \
  --project "${PROJECT_ID}"

if gcloud storage buckets describe "gs://${BUCKET}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  echo "bucket already exists: gs://${BUCKET}"
else
  gcloud storage buckets create "gs://${BUCKET}" \
    --project "${PROJECT_ID}" \
    --location "${REGION}" \
    --uniform-bucket-level-access
fi

gcloud storage buckets update "gs://${BUCKET}" --versioning --project "${PROJECT_ID}"
echo "tfstate bucket: gs://${BUCKET}"
