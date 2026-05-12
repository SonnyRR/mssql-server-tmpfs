FROM debian:bookworm-slim AS builder

COPY nodirect_open.c /
RUN apt-get update \
    && apt-get install -y gcc libc6-dev --no-install-recommends \
    && gcc -shared -fpic -o /nodirect_open.so nodirect_open.c -ldl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm /nodirect_open.c

FROM mcr.microsoft.com/mssql/server:2025-latest

COPY --from=builder /nodirect_open.so /nodirect_open.so
USER root
RUN echo "/nodirect_open.so" >> /etc/ld.so.preload
