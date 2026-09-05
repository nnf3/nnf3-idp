FROM alpine:3.20 AS tools

ARG YQ_VERSION=4.44.3
RUN apk add --no-cache wget \
  && wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
  && chmod +x /usr/local/bin/yq

FROM oryd/hydra:v26.2.0

USER root
COPY --from=tools /usr/local/bin/yq /usr/bin/yq
COPY --chown=10000:10000 config/hydra /etc/config/hydra
RUN chmod +x /etc/config/hydra/sync-clients.sh
USER 10000
