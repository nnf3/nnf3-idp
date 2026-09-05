#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
ENV="${ENV:?set ENV to dev or prd}"
REGION="${REGION:-asia-southeast1}"
DEPLOY="${DEPLOY:-auto}"
REPO="${REGION}-docker.pkg.dev/${PROJECT_ID}/idp-${ENV}"

if [[ -n "${IMAGE_TAG:-}" ]]; then
  TAG="${IMAGE_TAG}"
else
  TAG="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || true)"
  TAG="${TAG:-v26.2.0-r1}"
fi

# shellcheck source=gcp-use-sa.sh
source "${ROOT}/scripts/gcp-use-sa.sh"

echo "Building images with tag ${TAG} (DEPLOY=${DEPLOY})"

gcloud builds submit \
  --project "${PROJECT_ID}" \
  --config deploy/cloudbuild.yaml \
  --substitutions "_REPO=${REPO},_TAG=${TAG},_PROJECT_ID=${PROJECT_ID},_REGION=${REGION},_ENV=${ENV},_DEPLOY=${DEPLOY}" \
  .
