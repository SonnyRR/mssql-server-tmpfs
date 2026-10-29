FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c AS builder

COPY nodirect_open.c /
RUN apt-get update \
    && apt-get install -y gcc libc6-dev --no-install-recommends \
    && gcc -shared -fpic -o /nodirect_open.so nodirect_open.c -ldl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm /nodirect_open.c

FROM mcr.microsoft.com/mssql/server:2025-latest@sha256:245f6b1c8903edae52cb20fa31419cefcde1a49938bb8c3447099011fc871ca3

COPY --from=builder /nodirect_open.so /nodirect_open.so
USER root
RUN echo "/nodirect_open.so" >> /etc/ld.so.preload
