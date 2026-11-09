# Netory 1.0.3

- **Windows x64:** [protected installer](Windows/Netory-Setup.exe), [ZIP fallback](Windows/Netory-Windows-x64.zip), [installation instructions](Windows/README.md), [checksums](Windows/SHA256SUMS.txt).
- **Ubuntu Linux x86-64 (protected):** [installer](Linux/install.sh), [application package](Linux/Netory-1.0.3-Linux.tar.gz), [installation instructions](Linux/README.md), [checksums](Linux/SHA256SUMS.txt).

Ubuntu quick install:

Download the installer from netory.app, or use the local-archive installation below.

```bash
wget --https-only -O /tmp/netory-install-1.0.3.sh https://netory.app/downloads/1.0.3/Linux/install.sh && sudo bash /tmp/netory-install-1.0.3.sh
```

Both distributions compile Netory server/bootstrap code and verify signed integrity hashes. Ubuntu bundles portable CPython 3.13.18 and creates the `admin` account with a unique generated initial password. Windows asks you to choose administrator credentials during setup. Both preserve existing administrator passwords during updates and retain the normal Netory license requirements.

See [BUILD-INFO.md](BUILD-INFO.md) for verification results and platform-testing limits.

## Changes in 1.0.3

Cost estimate CSV export and print/PDF; paired switch and patch-panel ports in rack views; remembered client selection; safe copying of mounted assets; VLAN range consistency; bounded login request bodies and malformed-hash rejection.
