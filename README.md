# 💽 MS SQL Server w/ tmpfs support

A custom image that uses `mcr.microsoft.com/mssql/server` as a base,
but adds `tmpfs` support.

Running database containers with `tmpfs` volume mounts can save a lot
of time in integration/E2E test scenarios, since volatile memory (RAM)
is way more faster to access. This image is intended to do just that.

Since `MS SQL Server 2025`, `tmpfs` is supported, but only for `tempdb`.
This might not be ideal for everybody, since some cleanup tools like
`Respawn` don't work with that.

```sh
docker pull vkotzsev/mssql-server-tmpfs:2025-latest
```

## Running

```sh
docker run -d \
  --name mssql-tmpfs \
  --tmpfs /var/opt/mssql/data:uid=10001,gid=10001,size=4G \
  --tmpfs /var/opt/mssql/log:uid=10001,gid=10001,size=1G \
  -e ACCEPT_EULA=Y \
  -e MSSQL_SA_PASSWORD=<password> \
  -p 1433:1433 \
  vkotzsev/mssql-server-tmpfs:2025-latest
```
