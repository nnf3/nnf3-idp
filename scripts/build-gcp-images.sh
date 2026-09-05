#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
ENV="${ENV:?set ENV to dev or prd}"
REGION="${REGION:-asia-southeast1}"
TAG="${IMAGE_TAG:-v26.2.0-r1}"
REPO="${REGION}-docker.pkg.dev/${PROJECT_ID}/idp-${ENV}"

# shellcheck source=gcp-use-sa.sh
source "${ROOT}/scripts/gcp-use-sa.sh"

gcloud builds submit \
  --project "${PROJECT_ID}" \
  --config deploy/cloudbuild.yaml \
  --substitutions "_REPO=${REPO},_TAG=${TAG}" \
  .
