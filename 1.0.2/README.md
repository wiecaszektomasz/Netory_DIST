# Netory 1.0.2

- **Windows x64:** [protected installer](Windows/Netory-Setup.exe), [ZIP fallback](Windows/Netory-Windows-x64.zip), [installation instructions](Windows/README.md), [checksums](Windows/SHA256SUMS.txt).
- **Ubuntu Linux x86-64 (protected):** [installer](Linux/install.sh), [application package](Linux/Netory-1.0.2-Linux.tar.gz), [installation instructions](Linux/README.md), [checksums](Linux/SHA256SUMS.txt).

Ubuntu quick install:

Download the installer from netory.app, or use the local-archive installation below.

```bash
wget --https-only -O /tmp/netory-install-1.0.2.sh https://netory.app/downloads/1.0.2/Linux/install.sh && sudo bash /tmp/netory-install-1.0.2.sh
```

Both distributions compile Netory server/bootstrap code and verify signed integrity hashes. Ubuntu bundles portable CPython 3.13.18 and creates the `admin` account with a unique generated initial password. Windows asks you to choose administrator credentials during setup. Both preserve existing administrator passwords during updates and retain the normal Netory license requirements.

See [BUILD-INFO.md](BUILD-INFO.md) for verification results and platform-testing limits.
