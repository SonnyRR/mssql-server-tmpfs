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
docker pull vkotzsev/mssql-server-tmpfs:2022-latest
```
