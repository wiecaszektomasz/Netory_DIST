# Netory distributions

Installers and build records for Netory. Application source is maintained in [Netory](https://github.com/wiecaszektomasz/Netory).

## Latest: 1.0.2

- [Release overview](1.0.2/README.md)
- [Windows protected installer](1.0.2/Windows/Netory-Setup.exe) and [installation instructions](1.0.2/Windows/README.md)
- [Ubuntu installer](1.0.2/Linux/install.sh) and [installation instructions](1.0.2/Linux/README.md)
- [Build and validation record](1.0.2/BUILD-INFO.md)

Both Windows and Linux use native-compilation and signed-integrity protection. Linux bundles portable CPython 3.13.18 for Ubuntu 24.04/26.04 x86-64, without readable Netory Python source. Ubuntu installs required packages, creates a dedicated service and generates a unique initial administrator password. Existing managed installations retain accounts, inventory, encryption keys and licensing state during updates.

Earlier releases remain unchanged: [1.0](1.0/BUILD-INFO.md), [1.0.1](1.0.1/BUILD-INFO.md), [1.0.1 safe](1.0.1_safe/protection-notes.md).

Release ZIPs contain complete Windows runtimes/payloads. Extracted payload copies and private build caches are excluded from Git; manifests, dependency records, checksums and build records are retained. Download the complete ZIP for the fallback installer.
