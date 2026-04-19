FROM mcr.microsoft.com/mssql/server:2025-latest
COPY nodirect_open.c /

USER root
RUN apt-get update \
	&& apt-get install -y gcc libc6-dev --no-install-recommends\
	&& gcc -shared -fpic -o /nodirect_open.so nodirect_open.c -ldl \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN echo "/nodirect_open.so" >> /etc/ld.so.preload
