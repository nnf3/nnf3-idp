#!/bin/sh
set -eu

ENV="${ENV:?set ENV}"
APP_ORIGIN="${APP_ORIGIN:?set APP_ORIGIN}"
CLIENTS_FILE="/etc/config/hydra/clients/${ENV}.yaml"
ADMIN="${HYDRA_ADMIN_URL:-http://127.0.0.1:8080}"

if [ ! -f "${CLIENTS_FILE}" ]; then
  echo "No OAuth client config at ${CLIENTS_FILE}; nothing to sync."
  exit 0
fi

count="$(yq '.clients | length' "${CLIENTS_FILE}")"
if [ "${count}" -eq 0 ]; then
  echo "No clients defined in ${CLIENTS_FILE}."
  exit 0
fi

substitute_origin() {
  sed "s|\${APP_ORIGIN}|${APP_ORIGIN}|g"
}

i=0
while [ "$i" -lt "${count}" ]; do
  tmp="$(mktemp)"
  yq -o=json ".clients[${i}]" "${CLIENTS_FILE}" | substitute_origin > "${tmp}"

  client_id="$(yq -r '.client_id' "${tmp}")"
  if [ -z "${client_id}" ] || [ "${client_id}" = "null" ]; then
    echo "clients[${i}] is missing client_id" >&2
    exit 1
  fi

  echo "Syncing OAuth client ${client_id}..."
  if hydra get oauth2-client "${client_id}" --endpoint "${ADMIN}" --format json >/dev/null 2>&1; then
    hydra update oauth2-client "${client_id}" --endpoint "${ADMIN}" --file "${tmp}"
  else
    hydra create oauth2-client --endpoint "${ADMIN}" --file "${tmp}"
  fi

  rm -f "${tmp}"
  i=$((i + 1))
done

echo "OAuth clients synced from ${CLIENTS_FILE}."
