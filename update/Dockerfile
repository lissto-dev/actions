FROM alpine:3.19

RUN apk add --no-cache bash curl jq

# Install Lissto CLI - version passed as build arg
ARG LISSTO_VERSION=latest
ENV LISSTO_VERSION=${LISSTO_VERSION}

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
