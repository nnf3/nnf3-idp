#!/bin/sh
set -eu

: "${KRATOS_PUBLIC_URL:?KRATOS_PUBLIC_URL is required}"
: "${KRATOS_ADMIN_UPSTREAM:?KRATOS_ADMIN_UPSTREAM is required}"
: "${HYDRA_ADMIN_UPSTREAM:?HYDRA_ADMIN_UPSTREAM is required}"

export PORT=3000
npm run serve &
ui_pid=$!

# Cloud Run may send the first request as soon as nginx binds :8080. Wait for
# the stock UI first; otherwise nginx returns 502 and request-based CPU is
# throttled before Node can finish starting.
until wget -q -O /dev/null http://127.0.0.1:3000/health/ready; do
  if ! kill -0 "$ui_pid" 2>/dev/null; then
    wait "$ui_pid"
  fi
  sleep 0.1
done

cat >/etc/nginx/http.d/default.conf <<EOF
server {
  listen 8080;
  server_name _;

  location ~ ^/(self-service|sessions|schemas)(/|$) {
    proxy_pass ${KRATOS_PUBLIC_URL};
    proxy_set_header Host \$proxy_host;
    proxy_ssl_server_name on;
    proxy_ssl_name \$proxy_host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Host \$http_host;
    proxy_set_header Cookie \$http_cookie;
    proxy_pass_request_headers on;
  }

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host \$http_host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Host \$http_host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
}

# Only the UI process in this container can reach these routes. They let the
# stock UI call internal-only Admin services without exposing them publicly.
server {
  listen 127.0.0.1:8081;
  server_name localhost;

  location /hydra/ {
    proxy_pass ${HYDRA_ADMIN_UPSTREAM}/;
    proxy_set_header Host \$proxy_host;
    proxy_ssl_server_name on;
    proxy_ssl_name \$proxy_host;
  }

  location /kratos/ {
    proxy_pass ${KRATOS_ADMIN_UPSTREAM}/;
    proxy_set_header Host \$proxy_host;
    proxy_ssl_server_name on;
    proxy_ssl_name \$proxy_host;
  }
}
EOF

exec nginx -g "daemon off;"
