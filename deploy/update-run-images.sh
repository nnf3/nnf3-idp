#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
REGION="${REGION:?set REGION}"
ENV="${ENV:?set ENV}"
REPO="${REPO:?set REPO}"
TAG="${TAG:?set TAG}"
DEPLOY="${DEPLOY:-auto}"
# jobs: migrate 前に Job だけ更新
# services: migrate 後にサービスを更新
# all: 両方（手動用）
TARGET="${TARGET:-all}"

if [[ "${DEPLOY}" == "false" ]]; then
  echo "DEPLOY=false; skipping Cloud Run image updates."
  exit 0
fi

if [[ "${DEPLOY}" == "auto" ]]; then
  case "${TARGET}" in
    jobs)
      if ! gcloud run jobs describe "kratos-migrate-${ENV}" \
        --region="${REGION}" \
        --project="${PROJECT_ID}" \
        >/dev/null 2>&1; then
        echo "Cloud Run jobs not found; skipping job image updates (run terraform apply first)."
        exit 0
      fi
      ;;
    services)
      if ! gcloud run services describe "kratos-public-${ENV}" \
        --region="${REGION}" \
        --project="${PROJECT_ID}" \
        >/dev/null 2>&1; then
        echo "Cloud Run services not found; skipping service image updates (run terraform apply first)."
        exit 0
      fi
      ;;
    all)
      if ! gcloud run services describe "kratos-public-${ENV}" \
        --region="${REGION}" \
        --project="${PROJECT_ID}" \
        >/dev/null 2>&1; then
        echo "Cloud Run services not found; skipping deploy (run terraform apply first)."
        exit 0
      fi
      ;;
    *)
      echo "Unknown TARGET=${TARGET} (expected jobs, services, or all)" >&2
      exit 1
      ;;
  esac
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

update_jobs() {
  update_job "kratos-migrate-${ENV}" kratos
  update_job "hydra-migrate-${ENV}" hydra
  update_job "hydra-sync-clients-${ENV}" hydra
  update_job "hydra-janitor-${ENV}" hydra
}

update_services() {
  update_service "kratos-public-${ENV}" kratos
  update_service "kratos-admin-${ENV}" kratos
  update_service "hydra-public-${ENV}" hydra
  update_service "hydra-admin-${ENV}" hydra
  update_service "idp-ui-${ENV}" ui
}

case "${TARGET}" in
  jobs)
    update_jobs
    echo "Cloud Run jobs updated to tag ${TAG}."
    ;;
  services)
    update_services
    echo "Cloud Run services updated to tag ${TAG}."
    ;;
  all)
    update_jobs
    update_services
    echo "Cloud Run services and jobs updated to tag ${TAG}."
    ;;
  *)
    echo "Unknown TARGET=${TARGET} (expected jobs, services, or all)" >&2
    exit 1
    ;;
esac
