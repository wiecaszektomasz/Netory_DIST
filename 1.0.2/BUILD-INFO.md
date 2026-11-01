# Netory 1.0.2 build and validation

Built 2026-11-01 from Netory revision `4223069764d2d1f72bccf907735a4415870c5e19`, with the accompanying release-packaging changes. Previous distribution versions remain unchanged. The production application/service was not modified.

## Windows

Artifacts: protected `Windows/Netory-Setup.exe` and `Windows/Netory-Windows-x64.zip`. Bundled Windows x64 CPython 3.13.16, SQLite, WinSW 2.12.0, Visual C++ redistributable and Python wheels. Dependency versions/hashes are recorded in `Windows/Netory-Windows-x64/DEPENDENCIES.txt` and `manifest.json`.

Protection follows the previous safe release: **49 native compiled Netory modules**, sourceless migrations/initializers, minified first-party browser assets and an Ed25519-signed SHA-256 integrity manifest. No Netory Python source/generated C, customer database, production `.env` or private signing key is included in the customer application payload. This is code protection, rather than literal encryption of all runtime files or Windows Authenticode publisher signing.

Actual bundled-Windows-interpreter tests under Wine passed:

1. Payload/archive/download checksums and absence of Netory Python source.
2. Fresh/repeated setup, SQLite integrity and current schema `0054_asset_port_addresses`.
3. Upgrade from an actual original 1.0 database, preserving administrator password hash, inventory, configuration/encryption keys and licensing identity, with backup creation.
4. Native FastAPI/uvicorn HTTP routing, administrator login and authenticated reads.
5. Normal rejection of unlicensed writes.
6. Rejection of modified application assets and an invalid integrity signature, followed by successful startup after restoration.

See `Windows/validation-results.txt` and `Windows/protection-notes.md`.

**Not tested on real Windows:** wizard rendering, UAC, service registration, firewall, restart/reboot and uninstall lifecycle. Check these before customer rollout. Nmap is an additional Windows prerequisite for TCP/ICMP discovery and is not bundled.

## Protected Ubuntu Linux

Artifacts: `Linux/install.sh` and `Linux/Netory-1.0.2-Linux.tar.gz`. Targets Ubuntu 24.04/26.04 LTS **x86-64 (amd64)** with systemd. Includes portable CPython **3.13.18**, so the application does not depend on the system Python ABI. System Python is used only for installer utilities.

Like Windows, **49 Netory backend/bootstrap modules** are compiled to stripped native extensions, including licensing, authentication, API routes and database setup. Migrations/package initializers use sourceless bytecode, and first-party UI assets are minified. No readable Netory `.py`, generated C or `.pyx` source is shipped in the application/tools payload. Standard Python and third-party dependency source/notices remain upstream components.

A compiled guard verifies an Ed25519-signed SHA-256 manifest before server/bootstrap startup. This covers application/runtime files, the pinned dependency lock and public trust certificate. All Python dependencies are bundled inside the signed runtime after build-time hash-verified installation; customer data remain separate. No Python package download is needed at installation. The private integrity/license signing keys and customer configuration/database are excluded. Normal license enforcement remains active. This makes inspection/modification harder; software controlled by a machine owner cannot be made impossible to reverse engineer or patch, and migration bytecode can be decompiled.

Runtime: official Astral python-build-standalone CPython 3.13.18 Linux x86-64 install-only stripped release 20261026. Original archive SHA-256: `df15fe60d3ff55bf9dcf25824b5572756bb8816ff93865a273d3301d7066a8b7`. Exact URL and all payload hashes are in `Linux/manifest.json`; Python license/runtime provenance notices are included in the signed runtime.

The script installs prerequisites and hash-locked dependencies, root-owned code/private runtime, restricted service user, SQLite, systemd startup and Nmap/ping tools. Default HTTP port: 8000. Initial administrator: `admin`, unique generated 36-character password saved root-only. Administrator creation after an incomplete setup also uses a generated password. Updates preserve existing users/passwords, inventory, encryption keys, licensing identity and secure-cookie settings. Root-only backups precede migration; failures restore previous data/application/service.

Archive SHA-256 is embedded into the matching script. Extraction rejects traversal, links and special files, and normalizes application ownership to root. There is no source-code or system-interpreter fallback for the application.

Actual protected-package checks passed on Ubuntu 26.04.1 using bundled CPython 3.13.18:

1. Archive/download/payload hashes, no Netory Python/C/Pyx source, compiled licensing/bootstrap and upstream notices.
2. Build-time bundled-Python dependencies installed with `--only-binary=:all: --require-hashes`; runtime `pip check`.
3. Fresh/repeated bootstrap, SQLite integrity/current schema, administrator/configuration/license identity preservation.
4. Actual native uvicorn HTTP routing, administrator login, authenticated reads and rejection of unlicensed writes.
5. Rejection of modified dependency, UI, native licensing module, migration bytecode and integrity signature; restored application starts.
6. Full installer fresh setup, root-owned compiled code, credential permissions and real service-user HTTP login.
7. Repeat installer preserving inventory, administrator credentials, identity and secure-cookie setting, with backup creation.
8. Simulated service-start failure restoring previous release, inventory, identity and working HTTP service.
9. All **78 bundled ELF files** audited for glibc symbol requirements; maximum required version **2.34**, below Ubuntu 24.04's 2.39. Native compiler rejects requirements newer than 2.39. Shell/Python syntax checks passed.

Installer tests used a private mount/PID namespace with isolated `/opt`, `/var/lib`, unit directory and lock. Dependencies, native runtime, bootstrap, database and HTTP service were real; **apt/systemctl were test shims**, with startup under the restricted service user. Production services/data were unchanged.

**Outstanding:** clean Ubuntu 24.04/26.04 VM apt/systemd, reboot and firewall/reverse-proxy integration tests. The glibc audit does not replace a booted Ubuntu 24.04 test. The installer does not provision a public domain/TLS certificate or alter firewall rules. A local archive install still downloads Ubuntu apt prerequisites; Python dependencies are bundled. See `Linux/validation-results.txt` and the installation guides.

## Download publication

The wget command is prepared for `https://netory.app/downloads/1.0.2/Linux/install.sh`, alongside its matching archive. Public files have **not been published**. Automatic approval review rejected the earlier public upload of the source-based Linux payload/Windows packages without explicit destination/payload approval. The Linux payload is now protected and omits Netory Python source. Publication has not been retried; separate approval remains pending. Local installers are ready.
