# Windows installer

The Windows distribution is prepared in `/var/www/Netory_DIST`:

- `Netory-Setup.exe`: single offline installer; double-click, approve UAC, choose the port and initial administrator credentials, and click Install Netory.
- `Netory-Windows-x64.zip`: extract completely, then double-click `Install.cmd` if an executable wrapper is unsuitable for your environment.
- `README.txt`: end-user installation, configuration, update and removal instructions.
- `SHA256SUMS.txt`: artifact checksums.
- `Netory-Windows-x64/manifest.json`: payload hashes, exact runtime source URLs and application revision.
- `installer-source/`: installer scripts for review and Windows smoke checks.

## Included components

The application is copied from the same backend, frontend, translations and Alembic migrations as production. No demo adapter/cap, production `.env`, live inventory, database or private key is shipped. Python 3.13.16 x64 is embedded privately with Windows binary dependencies pinned to the build environment; SQLite is included with Python. Microsoft Visual C++ Runtime is bundled and installed automatically after checking its Microsoft Authenticode signature. WinSW 2.12.0's .NET Framework wrapper uses the framework already provided by supported Windows installations. No target-machine pip download or system Python installation is needed.

Targets: Windows 10/11 x64 and Windows Server 2019/2022/2025 x64 with desktop experience, built-in Windows PowerShell 5.1 and current OS/runtime trust updates. ARM64, 32-bit Windows and headless Server Core setup are not targeted. If Microsoft runtime setup returns a reboot-required code, restart Windows before production use.

## Installed layout and behavior

Setup lets users choose separate application and database/data folders on fixed local drives. Defaults are `%ProgramFiles%\Netory` and `%ProgramData%\Netory`. The selected data folder contains the SQLite database at `db\netory.db`; database engines other than SQLite are not added by this feature. Paths are remembered in `HKLM\Software\Netory` and preserved during updates/configuration, including after uninstall. Existing storage is not migrated by Configure. Persistent configuration, encryption keys, logs, SQLite data and pre-update backups are under `%ProgramData%\Netory`; the database is `db\netory.db`. The application runs as an automatic service called `Netory` under `NT AUTHORITY\LocalService`, with restricted program read/execute access and database/log write access. Administrators and SYSTEM retain full control; the service can read encryption keys but ordinary users cannot.

Setup uses a DPI-aware, two-column settings form with separate label/input cells, keyboard tab navigation and explicit STA launchers. Fresh installations allow editing all administrator fields. On update/configuration those account fields are intentionally read-only; the form explains that existing accounts are preserved and credentials are changed inside Netory. The port and private-network setting remain editable.

Setup uses a GUI for the port (1–65535), first administrator name and matching passwords of at least 14 characters. Passwords travel to provisioning over redirected stdin as escaped JSON, never command-line arguments, setup files or logs; only an Argon2 hash is stored. Existing admin accounts/passwords and encryption keys are preserved on update. The database is initialized and upgraded automatically using Alembic.

By default Netory binds `127.0.0.1`. The private-LAN checkbox binds `0.0.0.0` and creates a firewall rule limited to Windows Private profiles and local-subnet clients. HTTPS can be enabled during installation or using Configure Netory. Select a PFX/P12 containing the private key and server certificate chain, enter its password, and supply the matching DNS name or IPv4 address. Setup validates validity dates, SAN identity and key matching before saving the certificate. Certificates are imported using [cryptography PKCS12](https://cryptography.io/en/stable/hazmat/primitives/asymmetric/serialization/#pkcs12) and served using [Uvicorn TLS settings](https://uvicorn.dev/settings/#https).

The PFX password travels only through stdin and is not retained. Exported PEM certificates and the service key live under the protected data `tls` directory. Administrators/SYSTEM have full control; LocalService has read access. Configure can replace the certificate, or retain the current one by leaving the PFX field blank. Failed configuration restores the previous certificate, service XML, database and environment. TLS sets `COOKIE_SECURE=true`; HTTP sets it to false. Clearing browser cookies may be necessary when reverting to HTTP.

The installer does not provision DNS, issue public certificates, or alter system/client trust stores. Use a CA-issued certificate trusted by clients; private CA roots must be deployed by the administrator to clients. A chain bundled in a PFX does not itself establish browser trust. The local readiness probe trusts the installed certificate only for that probe and validates its identity; remote browser trust must be checked separately. Public DNS names must resolve to the installation host. IPv6 certificate addresses are not supported in this setup UI.

Start menu shortcuts open the application, reconfigure network/HTTPS settings or replace the certificate, or uninstall. The application is also registered in Windows installed apps. Reconfiguration restarts the service. Updates stop the service, back up the database/configuration, replace program files, apply migrations and restart; failures attempt rollback of program/data/configuration. Pre-update backups remain administrator-only. Uninstall removes the service, program files, shortcuts and firewall rule while preserving data/configuration/backups.

## Building

Canonical scripts live in `deploy/windows`. Build with the application virtual environment to constrain Windows packages to the tested production package versions:

```bash
sudo /var/www/Netory/.venv/bin/python /var/www/Netory/deploy/windows/build.py \
  --output /var/www/Netory_DIST \
  --makensis /path/to/makensis \
  --nsisdir /path/to/nsis/share
```

Python.org, PyPI, Microsoft's runtime CDN and the official WinSW GitHub release are contacted only while building. Downloaded prerequisites/wheels are cached under `/tmp/netory-windows-downloads`. The builder copies public application files and dependency licenses using an allowlist, patches Alembic paths for installation under Program Files, generates integrity metadata, and builds the ZIP and NSIS self-extracting EXE. Omitting `--makensis` builds only the ZIP.

The copied `/var/www/Netory_DIST/build.py` can also be invoked with `--source /path/to/Netory`; its adjacent `installer-source` scripts are used. Review the source revision and dirty flag in the manifest before releasing a package. Installer executable signing requires a real publisher code-signing certificate and is not supplied here. The EXE is unsigned; hashes detect corruption but do not authenticate its publisher.

## Validation and limits

Linux-side checks cover fresh SQLite migrations, administrator creation/password hashing, rerun preservation of accounts/encryption keys, backup readability, short-password rejection, PowerShell parsing, generated service XML/port binding, Unicode credential transport, Windows binary dependency selection, payload hashes and compiled Windows EXE/ZIP integrity. These checks do not establish that installation, UAC, WinSW registration, firewall rules or rollback work on Windows.

The form layout repair removes the overlapping full-width labels from the original installer. Linux-side parsing/build tests do not verify mouse/keyboard interaction on Windows.

Before production distribution, test the EXE on a clean Windows VM. First run `powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File installer-source/Test-SetupForm.ps1` on an interactive desktop. This checks field input and mouse hit targets at 100%, 150% and 200% scaling, password masking, tab order and Configure-mode permissions without installing anything. Run `installer-source/Test-Installation.ps1` elevated after installation, sign in and create data, change the port, restart Windows, update using the package and confirm data preservation, simulate an occupied port, and uninstall/reinstall while checking preserved data/keys. This host has no Windows execution environment, so those lifecycle checks remain unverified.

References: [Python Windows embedding](https://docs.python.org/3.13/using/windows.html), [WinSW v2 configuration](https://github.com/winsw/winsw/blob/v2.12.0/doc/xmlConfigFile.md), [Microsoft Visual C++ runtime](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).
