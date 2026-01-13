ARG CLI_VERSION=latest
FROM lissto/cli:${CLI_VERSION}
RUN apk add --no-cache jq
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
