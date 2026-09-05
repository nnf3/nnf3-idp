#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CLIENT_ID="${FIRST_PARTY_CLIENT_ID:-nnf3-web}"
REDIRECT_URI="${FIRST_PARTY_REDIRECT_URI:-http://127.0.0.1:3000/callback}"
ENDPOINT="${HYDRA_ADMIN_URL:-http://127.0.0.1:4445}"

docker compose exec -T hydra \
  hydra create oauth2-client \
    --endpoint "${ENDPOINT}" \
    --id "${CLIENT_ID}" \
    --name "NNF3 Web" \
    --grant-type authorization_code,refresh_token \
    --response-type code \
    --scope openid,offline,offline_access,email,profile \
    --redirect-uri "${REDIRECT_URI}" \
    --token-endpoint-auth-method none \
    --skip-consent \
    --skip-logout-consent
