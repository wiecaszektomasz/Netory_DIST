# Netory Windows installer 1.0

Archived 2026-10-21 after the user reported it working. Version 1.0 is an archive label; executable metadata has not been changed. EXE and ZIP bytes are unchanged. Preserve this folder and build future versions into a separate output directory.

## Source and contents

Application revision: `07330630d66b9aa6eed78efe4ad38314f0b86cd3`.
The build included uncommitted installer changes; this is not a clean tagged Git release.

- `Netory-Setup.exe` and `Netory-Windows-x64.zip`: offline Windows x64 packages.
- `SHA256SUMS.txt`: original artifact hashes.
- `Netory-Windows-x64/manifest.json`: all payload hashes, source revision and runtime download URLs/hashes.
- `Netory-Windows-x64/DEPENDENCIES.txt`: exact packaged dependency versions.
- `Netory-Windows-x64/payload/app`: complete packaged application snapshot.
- `installer-source/` and `build.py`: installer source, builder, Windows smoke checks and provisioning tests.
- `installer-changes.patch`: tracked installer/test/documentation changes against the application revision. The newly added SetupForm.ps1 and Test-SetupForm.ps1 are preserved in installer-source; untracked files are not in the patch.
- `BUILD.log`: successful original build output.
- `windows-installer.md`: detailed setup/development documentation.
- `ARCHIVE-SHA256.json`: archive file hashes, excluding the checksum file itself.

Runtime: Python 3.13.16 x64, WinSW 2.12.0 (.NET Framework), SQLite and bundled Microsoft VC++ runtime. Build host: Linux, application virtual environment and NSIS 3.10-2. Target: Windows x64 desktop with Windows PowerShell 5.1 in STA mode. Linux PowerShell 7.6.7 was used for parsing only.

## Persistent build support

`../build-support/downloads` preserves the Python embedding ZIP, Windows wheels, VC++ runtime, WinSW, license, generated requirements and production constraints from the working build. `../build-support/nsis` preserves the NSIS compiler and resources used on this Linux host. These replace temporary /tmp paths. NSIS still requires compatible host system libraries.

## Future builds

Never build into this 1.0 archive: the builder replaces generated artifacts.

```bash
cd /var/www/Netory
PIP_NO_INDEX=1 \
PIP_FIND_LINKS=/var/www/Netory_DIST/build-support/downloads/wheels \
.venv/bin/python deploy/windows/build.py \
  --output /var/www/Netory_DIST/next-build \
  --cache /var/www/Netory_DIST/build-support/downloads \
  --makensis /var/www/Netory_DIST/build-support/nsis/usr/bin/makensis \
  --nsisdir /var/www/Netory_DIST/build-support/nsis/usr/share/nsis
```

Use sudo only if filesystem permissions require it, keeping the explicit virtual-environment Python path. Constraints are derived from the invoking Python environment; the builder rewrites cache requirements/constraints. Use matching dependency versions for a dependency-equivalent rebuild. Offline mode needs every required wheel cached; changed dependencies require a reviewed cache refresh. Byte-identical rebuilt EXE/ZIP files are not guaranteed.

The archived builder can also run as `1.0/build.py --source /path/to/Netory` with the same remaining arguments; it uses adjacent installer-source scripts. To reconstruct the archived build input, start from the recorded application revision, apply installer-changes.patch and restore SetupForm.ps1 and Test-SetupForm.ps1 from installer-source into deploy/windows. Compare the application with the packaged snapshot. Packaged alembic.ini includes installation path adjustments.

## Validation

```bash
cd /var/www/Netory_DIST/1.0
sha256sum -c SHA256SUMS.txt
cd /var/www/Netory
.venv/bin/python -m pytest tests/test_windows_installer.py -q
```

Seven installer tests passed: database/admin/key preservation and backups, password rejection, missing encryption configuration, PFX identity/password/expiry checks, certificate preservation after failed validation, HTTPS cookies and actual TLS readiness. PowerShell syntax, HTTP/HTTPS service XML, XML path escaping, all 2,067 payload hashes, ZIP contents/CRC, PE structure and artifact hashes passed. The user subsequently reported the installer working. The Linux host did not independently validate the full Windows GUI, DPI, UAC, service/firewall, upgrade/rollback and uninstall lifecycle. Run installer-source/Test-SetupForm.ps1 and Test-Installation.ps1 on Windows for those checks.

Setup supports separate application/data folders, SQLite, port/private-LAN access, initial administrator, HTTPS PFX/P12 import and later certificate replacement through Configure. Existing folder migration and alternate database engines are not provided. DNS and client CA trust are managed separately. EXE is unsigned; hashes detect corruption, not publisher identity.
