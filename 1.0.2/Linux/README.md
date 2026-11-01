# Netory 1.0.2 — Ubuntu installation

Requires **x86-64 (amd64)** Ubuntu Server/Desktop **24.04 LTS or 26.04 LTS**, systemd, sudo/root, Internet access to Ubuntu repositories and netory.app, and an available TCP port (8000 by default). The protected package includes its own portable CPython 3.13.18 runtime; no separate application Python installation is required. Ubuntu 22.04 and ARM are not targets of this package. No external database is needed: SQLite is configured automatically.

## One-command installation

**Publication pending:** this HTTPS download URL becomes usable after the release files are published. Local-archive installation below is available now.

```bash
wget --https-only -O /tmp/netory-install-1.0.2.sh https://netory.app/downloads/1.0.2/Linux/install.sh && sudo bash /tmp/netory-install-1.0.2.sh
```

Open **http://SERVER-IP:8000/**. The installer prints the server URL and initial login:

- Username: **admin**
- Password: a unique, randomly generated 36-character password, printed at completion.

Retrieve it later with `sudo cat /var/lib/netory/initial-admin.txt`. This file is readable only by root. Change the password under your account settings → **Change password**, then remove the old credentials file with `sudo rm /var/lib/netory/initial-admin.txt`.

The package includes a private Python runtime and all hash-pinned Python dependencies, covered by the signed integrity manifest. The installer installs Ubuntu prerequisites, CA certificates, wget, OpenSSL, Nmap and ping utilities. It does not download Python packages at installation time. It creates a restricted `netory` service account, initializes the database/encryption keys/license identity, registers a systemd service, and starts Netory automatically at boot. It does not install or overwrite Nginx, Apache, MySQL or an existing unmanaged Netory installation.

## Options and local package

Choose a different port or administrator username:

```bash
sudo bash /tmp/netory-install-1.0.2.sh --port 8080 --admin-user netoryadmin
```

Bind only to localhost when using your own reverse proxy:

```bash
sudo bash /tmp/netory-install-1.0.2.sh --bind 127.0.0.1 --port 8000
```

Alternatively, copy `install.sh`, `Netory-1.0.2-Linux.tar.gz` and `SHA256SUMS.txt` to the same directory:

```bash
sha256sum --check SHA256SUMS.txt
sudo bash install.sh --archive "$PWD/Netory-1.0.2-Linux.tar.gz"
```

The local archive option still requires Internet access for Ubuntu apt prerequisites; Python dependencies are already included. The installer verifies the application's embedded SHA-256 before extracting it. Allow your selected TCP port in your existing firewall/security group from the intended client network; firewall rules are not changed automatically. For example, with UFW already enabled: `sudo ufw allow from YOUR-LAN-CIDR to any port 8000 proto tcp` (replace YOUR-LAN-CIDR).

## Files, service and updates

- Application and signed private Python runtime: `/opt/netory/current` (root-owned release directories).
- SQLite database: `/var/lib/netory/db/netory.db`.
- Configuration/encryption keys: `/var/lib/netory/.env` (root + service group only).
- License identity/state: `/var/lib/netory/licensing/`.
- Service: `sudo systemctl status netory` / `sudo systemctl restart netory`.
- Logs: `sudo journalctl -u netory -n 100 --no-pager`.

Re-run the installer to update an installation managed by this installer. Specify the same `--port` and `--bind` options if you customized them. Existing users/passwords, encryption keys, inventory and licensing identity are preserved. Before changing the database, the service is stopped and a root-only backup of the complete data directory and service file is saved under `/opt/netory/backups/`. An unsuccessful update restores that backup and the previous application link. Old releases/backups are retained for administrator review.

Manual installations, custom database URLs and existing unmanaged services are intentionally not converted automatically. Back up the database **together with `.env` and the licensing directory** before migrating between machines. Do not delete encryption keys or the installation identity.

## First use and HTTPS

Install a valid Netory license through **Manage application license** to enable writes. Without activation, the application retains its normal read-only behavior.

The simple setup serves HTTP on port 8000. For remote access across untrusted networks and HTTPS-only features such as saving AI API credentials, configure a trusted HTTPS reverse proxy and set `COOKIE_SECURE="true"` in `/var/lib/netory/.env`, then restart Netory. The installer does not obtain a domain name or public TLS certificate. Updates preserve the existing secure-cookie setting.


## Protected Linux edition

The backend, authentication/licensing logic and database setup helper are compiled to stripped Linux native `.so` modules. Netory Python `.py`, generated C and `.pyx` source files are excluded. Migrations and package initializers use CPython bytecode; Alembic uses sourceless migration discovery. First-party browser assets are minified without source maps.

A compiled integrity guard verifies an Ed25519 signature and SHA-256 hashes before backend/bootstrap startup. Application, bundled runtime, dependency lock and public license certificate are covered; customer data and credentials remain separate. All Python dependencies are bundled inside the signed runtime after build-time installation with the hash-pinned requirements lock. Existing Netory license enforcement remains active.

Do not edit protected application/runtime files: startup rejects modifications. Updates replace the complete signed package. Standard Python/third-party dependency sources and notices remain where required by those components; only Netory's own application code is compiled/sourceless. Native compilation and signed checks make inspection and modification harder, but a machine owner with full control can still reverse engineer or patch software. Migration bytecode can also be decompiled.

Runtime source: [Astral python-build-standalone](https://github.com/astral-sh/python-build-standalone/releases/tag/20261026), portable CPython 3.13.18 Linux x86-64. The exact upstream archive URL/hash and application hashes are recorded in `manifest.json`. See `../BUILD-INFO.md` and `validation-results.txt` for actual validation results and remaining clean-machine testing.
