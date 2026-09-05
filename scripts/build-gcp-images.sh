#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
ENV="${ENV:?set ENV to dev or prd}"
REGION="${REGION:-asia-southeast1}"
DEPLOY="${DEPLOY:-auto}"
MIGRATE="${MIGRATE:-false}"
SYNC_CLIENTS="${SYNC_CLIENTS:-false}"
REPO="${REGION}-docker.pkg.dev/${PROJECT_ID}/idp-${ENV}"

if [[ -n "${IMAGE_TAG:-}" ]]; then
  TAG="${IMAGE_TAG}"
else
  TAG="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || true)"
  TAG="${TAG:-v26.2.0-r1}"
fi

# shellcheck source=gcp-use-sa.sh
source "${ROOT}/scripts/gcp-use-sa.sh"

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
HYDRA_PUBLIC_URL="https://hydra-public-${ENV}-${PROJECT_NUMBER}.${REGION}.run.app"
UI_URL="https://idp-ui-${ENV}-${PROJECT_NUMBER}.${REGION}.run.app"
CLOUDBUILD_SA="idp-${ENV}-build@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Building images with tag ${TAG} (DEPLOY=${DEPLOY}, MIGRATE=${MIGRATE}, SYNC_CLIENTS=${SYNC_CLIENTS})"

gcloud builds submit \
  --project "${PROJECT_ID}" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${CLOUDBUILD_SA}" \
  --config deploy/cloudbuild.yaml \
  --substitutions "_REPO=${REPO},_TAG=${TAG},_PROJECT_ID=${PROJECT_ID},_REGION=${REGION},_ENV=${ENV},_HYDRA_PUBLIC_URL=${HYDRA_PUBLIC_URL},_UI_URL=${UI_URL},_DEPLOY=${DEPLOY},_MIGRATE=${MIGRATE},_SYNC_CLIENTS=${SYNC_CLIENTS}" \
  .
