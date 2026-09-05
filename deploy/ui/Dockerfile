FROM oryd/kratos-selfservice-ui-node:v26.2.0

USER root
RUN apk add --no-cache nginx

COPY deploy/ui/start.sh /usr/local/bin/start-ui
RUN chmod +x /usr/local/bin/start-ui

ENTRYPOINT ["/usr/local/bin/start-ui"]
CMD []
