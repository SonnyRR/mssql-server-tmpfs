# 💽 MS SQL Server w/ tmpfs support

A custom image that uses `mcr.microsoft.com/mssql/server` as a base,
but adds `tmpfs` support.

Running database containers with `tmpfs` volume mounts can save a lot
of time in integration/E2E test scenarios, since volatile memory
(RAM) is way more faster to access. This image is intended to do
just that.

**This image is designed for CI/CD pipelines** - specifically for
running MS SQL Server in E2E/Integration tests via Testcontainers or
similar tools. By storing database files in `RAM` instead of on disk,
test suites execute significantly faster, translating to real-world
time savings in your CI/CD workflows.

Since MS SQL Server 2025, `tmpfs` is supported, but only for `tempdb`.
This might not be ideal for everybody, since some cleanup tools like
`Respawn` don't work with that.

```sh
docker pull vkotzsev/mssql-server-tmpfs:2025-latest
```

## 🏃‍♀️ Running

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

## 🔍 Verifying tmpfs Mounts

Once the container is running, you can verify that the data and log
directories are mounted as tmpfs:

```sh
docker exec mssql-tmpfs df -h | grep tmpfs
```

Expected output:

```sh
tmpfs           4.0G  73M  4.0G   2% /var/opt/mssql/data
tmpfs           1.0G  236K  1.0G  1% /var/opt/mssql/log
```

You can also confirm the preload hook is active:

```sh
docker exec mssql-tmpfs cat /etc/ld.so.preload
```

Expected output:

```sh
/nodirect_open.so
```

## ⚙️ How It Works

MS SQL Server opens data files with `O_DIRECT`, a flag that performs
**direct I/O** — reading and writing straight to storage, bypassing the
OS page cache. This is excellent for production workloads on SSDs/NVMe
drives, but it is **incompatible with tmpfs** mounts. When the kernel
detects `O_DIRECT` on a tmpfs filesystem, it rejects it with `EINVAL`,
and MS SQL fails to start:

```sh
Direct open file /var/opt/mssql/data/master.mdf failed with error 22
```

### 🔧 The Fix: `ld.so.preload`

Rather than patching MS SQL's source code (which would require rebuilding
the entire database engine), this image uses **`ld.so.preload`** — a
Linux mechanism that lets you interpose arbitrary shared library
functions into every process before it starts.

`nodirect_open.c` is a tiny shared library that overrides the `open()`
system call. When any process in the container calls `open()`, it goes
through our wrapper first, which **strips the `O_DIRECT` flag** before
calling the real `open()`. This allows MS SQL to operate on tmpfs
mounts without ever attempting direct I/O.

```c
int open(const char *pathname, int flags, ...)
{
    static orig_open_f_type orig_open;
    if (!orig_open)
        orig_open = dlsym(RTLD_NEXT, "open");
    return orig_open(pathname, flags & ~O_DIRECT);
}
```

### 🤔 Why This Approach?

| Approach                   | Pros                                                        | Cons                                                               |
| -------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------ |
| Source-patch MS SQL        | Clean, official                                             | Requires rebuild of entire DB engine; legally/commercially complex |
| **`ld.so.preload` (this)** | Zero MS SQL changes, ~16 lines of C, works for all versions | Slight syscall overhead (negligible vs DB workload)                |
| Bind mount workaround      | No code needed                                              | Loses tmpfs benefits (disk-backed)                                 |

The preload approach is lightweight, non-invasive, and works regardless
of which SQL Server version or CU you're running.

## 🚀 Use Cases

### 🧪 Integration/E2E Testing with Testcontainers

This image is designed to work seamlessly with
[Testcontainers](https://github.com/testcontainers/testcontainers-dotnet)
for .NET integration and end-to-end testing. By running MS SQL Server
with `tmpfs`, tests execute significantly faster since database
operations happen in-memory rather than hitting disk.

```csharp
[TestMethod]
public async Task TestWithTmpfs()
{
    var container = new MsSqlBuilder()
        .WithImage("vkotzsev/mssql-server-tmpfs:2025-latest")
        .WithTmpfs(new Dictionary<string, string>
        {
            { "/var/opt/mssql/data", "size=4G,uid=10001,gid=10001" },
            { "/var/opt/mssql/log", "size=1G,uid=10001,gid=10001" }
        })
        .WithPassword("TestPassword123!")
        .Build();

    await container.StartAsync();

    // Tests run against in-memory database - much faster!
}
```

### 🧹 C# Respawn Compatibility

[Respawn](https://github.com/jbogard/Respawn) is a smart database
cleanup library for .NET that resets your database to a clean state
between tests. However, `Respawn` doesn't work with `tempdb` because
it's designed to work with actual user databases.

Since MS SQL Server 2025 only supports `tmpfs` for `tempdb` out of the
box, this custom image enables tmpfs for the actual database files.
This allows you to:

- Use `Respawn` for intelligent test data cleanup
- Work with real databases rather than tempdb
- Benefit from RAM-speed performance while maintaining compatibility
  with cleanup tools

### ⚡ Performance Benefits

Using `tmpfs` for your MS SQL container in CI/CD pipelines provides
substantial performance gains:

| Aspect               | Disk-based                   | tmpfs (RAM)                 |
| -------------------- | ---------------------------- | --------------------------- |
| Query execution      | Baseline                     | **2-10x faster**            |
| Write operations     | Disk I/O bottleneck          | **Near-instant**            |
| Container startup    | Disk initialization required | **~Instant**                |
| Test suite execution | Minutes                      | **Seconds to minutes less** |

**Why it's faster:**

- No disk I/O overhead - all reads/writes happen in memory
- No storage initialization on container start
- Zero disk contention in parallel test execution
- Ideal for write-heavy test scenarios (inserts, updates, deletes)

This makes it particularly valuable for CI/CD pipelines where test
execution time directly impacts delivery speed.

## 📚 Learn More About tmpfs

- [Docker tmpfs mounts documentation](https://docs.docker.com/storage/tmpfs/)
- [Linux tmpfs man page](https://man7.org/linux/man-pages/man5/tmpfs.5.html)
- [Wikipedia: tmpfs](https://en.wikipedia.org/wiki/tmpfs)
