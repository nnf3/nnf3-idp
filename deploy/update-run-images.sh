#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
REGION="${REGION:?set REGION}"
ENV="${ENV:?set ENV}"
REPO="${REPO:?set REPO}"
TAG="${TAG:?set TAG}"
DEPLOY="${DEPLOY:-auto}"

if [[ "${DEPLOY}" == "false" ]]; then
  echo "DEPLOY=false; skipping Cloud Run image updates."
  exit 0
fi

if [[ "${DEPLOY}" == "auto" ]]; then
  if ! gcloud run services describe "kratos-public-${ENV}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}" \
    >/dev/null 2>&1; then
    echo "Cloud Run services not found; skipping deploy (run terraform apply first)."
    exit 0
  fi
fi

update_service() {
  local service=$1
  local image_name=$2

  echo "Updating service ${service} -> ${REPO}/${image_name}:${TAG}"
  gcloud run services update "${service}" \
    --image="${REPO}/${image_name}:${TAG}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet
}

update_job() {
  local job=$1
  local image_name=$2

  echo "Updating job ${job} -> ${REPO}/${image_name}:${TAG}"
  gcloud run jobs update "${job}" \
    --image="${REPO}/${image_name}:${TAG}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet
}

update_service "kratos-public-${ENV}" kratos
update_service "kratos-admin-${ENV}" kratos
update_service "hydra-public-${ENV}" hydra
update_service "hydra-admin-${ENV}" hydra
update_service "idp-ui-${ENV}" ui

update_job "kratos-migrate-${ENV}" kratos
update_job "hydra-migrate-${ENV}" hydra
update_job "hydra-create-client-${ENV}" hydra
update_job "hydra-janitor-${ENV}" hydra

echo "Cloud Run services and jobs updated to tag ${TAG}."
