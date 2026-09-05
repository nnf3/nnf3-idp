# Source from other scripts. Uses ENV + repo root, or GOOGLE_APPLICATION_CREDENTIALS.
#   ROOT=... ENV=dev source scripts/gcp-use-sa.sh

if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
  _env_dir=""
  if [[ -n "${ROOT:-}" && -n "${ENV:-}" ]]; then
    _env_dir="${ROOT}/infra/terraform/envs/${ENV}"
  elif [[ -f credentials.json ]]; then
    _env_dir="."
  fi
  if [[ -n "${_env_dir}" && -f "${_env_dir}/credentials.json" ]]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$(cd "${_env_dir}" && pwd)/credentials.json"
  fi
fi

if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
  echo "credentials.json がありません。envs/\$ENV/ に置くか GOOGLE_APPLICATION_CREDENTIALS を設定してください。" >&2
  return 1 2>/dev/null || exit 1
fi

export CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE="${GOOGLE_APPLICATION_CREDENTIALS}"
export CLOUDSDK_CORE_PROJECT="${PROJECT_ID:-${CLOUDSDK_CORE_PROJECT:-}}"
