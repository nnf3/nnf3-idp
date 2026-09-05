#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
REGION="${REGION:?set REGION}"
ENV="${ENV:?set ENV}"
SYNC_CLIENTS="${SYNC_CLIENTS:-true}"

if [[ "${SYNC_CLIENTS}" == "false" ]]; then
  echo "SYNC_CLIENTS=false; skipping OAuth client sync."
  exit 0
fi

echo "Running Hydra OAuth client sync job..."
gcloud run jobs execute "hydra-sync-clients-${ENV}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --wait

echo "OAuth client sync completed."
