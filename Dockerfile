FROM ubuntu:26.04@sha256:065aa8626841f16057b78b027b464cd59c4fac36c204c72dcbf48d66f5fa8a96 AS builder

COPY nodirect_open.c /
RUN apt-get update \
    && apt-get install -y gcc libc6-dev --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN gcc -shared -fpic -o /nodirect_open.so nodirect_open.c -ldl

RUN rm /nodirect_open.c

FROM mcr.microsoft.com/mssql/server:2025-latest@sha256:245f6b1c8903edae52cb20fa31419cefcde1a49938bb8c3447099011fc871ca3

COPY --from=builder /nodirect_open.so /nodirect_open.so
USER root
RUN echo "/nodirect_open.so" >> /etc/ld.so.preload
