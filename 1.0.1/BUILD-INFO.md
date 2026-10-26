# Netory Windows 1.0.1

## Artifacts

- `Netory-Setup.exe`: offline Windows x64 installer for fresh installation or an in-place 1.0 update.
- `Netory-Windows-x64.zip`: ZIP fallback; extract fully and launch `Install.cmd`.
- `SHA256SUMS.txt`: EXE and ZIP SHA-256 hashes.
- `Netory-Windows-x64/manifest.json`: version, source revision, prerequisite hashes and all 2101 packaged file hashes.
- `installer-source/`, `build.py`, `installer-changes.patch`: exact installer source and changes against the recorded application revision.
- `validation/`: repeatable Linux-side archived-1.0 upgrade and artifact checks.

Application source revision: `b701c779698a31bd8fc104469a87fce653c1d686` on branch `Test`. Application files match that revision. The source working tree includes installer/documentation changes recorded in `installer-changes.patch`; the manifest intentionally records `source_has_uncommitted_changes: true`. This package is not represented as a clean tagged release.

Release version is 1.0.1 in the bundle manifest and `version.json`; the executable file/product version is 1.0.1.0. Installed apps receives DisplayVersion 1.0.1 after a successful setup.

## Updating 1.0

1. On the existing Windows machine, run this release's `Netory-Setup.exe` as administrator.
2. Setup locates the existing service and registered application/data folders. Keep those folders; the action is **Update Netory**. Existing administrator fields remain locked.
3. Keep or adjust the existing port, private-LAN and HTTPS settings, then click **Update Netory**.
4. The service stops; setup backs up the existing SQLite database, environment/encryption configuration and licensing identity, replaces application files, applies migrations 0044–0046, and restarts the service. Backups remain in the data folder under `backups`.
5. Open Netory and confirm existing data. Do not uninstall 1.0 first or delete its data folder.

Existing passwords, encryption keys, inventory, licensing identity and custom storage locations are retained. The new release includes instance licensing; older 1.0 installations without a license may need license activation. The public trust certificate is included; no server data, credentials or private signing keys are included.

## Build

Python 3.13.16 x64 embedded runtime; WinSW 2.12.0; bundled Microsoft VC++ runtime. Exact Windows dependency versions are in `Netory-Windows-x64/DEPENDENCIES.txt`. Built using the production virtual environment and cached Windows wheels. The old 1.0 cache and release remain unchanged; updated prerequisites are in a separate cache.

```bash
cd /var/www/Netory
sudo env PIP_NO_INDEX=1 \
  PIP_FIND_LINKS=/var/www/Netory_DIST/build-support/downloads-1.0.1/wheels \
  /var/www/Netory/.venv/bin/python deploy/windows/build.py \
  --version 1.0.1 --output /var/www/Netory_DIST/new-build \
  --cache /var/www/Netory_DIST/build-support/downloads-1.0.1 \
  --makensis /var/www/Netory_DIST/build-support/nsis/usr/bin/makensis \
  --nsisdir /var/www/Netory_DIST/build-support/nsis/usr/share/nsis
```

Do not rebuild into an archived release directory. Use the preserved source plus patch to reconstruct this build input; rebuilding from a later working tree produces a later application snapshot.

## Validation

- Seven installer provisioning tests passed, covering fresh initialization, administrator/key preservation, backups, password rejection, missing encryption configuration, certificate validation/preservation and TLS readiness.
- Actual archived 1.0 bootstrap → packaged 1.0.1 bootstrap passed with synthetic inventory, a custom data path, existing admin/password, encrypted WLAN data, VLAN port settings, room/rack placement, notes and a licensing identity. Database migrated from `0043_notes_board` to `0046_report_configurations`; repeat setup retained newly saved report configurations.
- Fresh packaged 1.0.1 provisioning passed.
- All installer PowerShell scripts parsed successfully.
- All 2101 packaged hashes, ZIP CRC/contents, EXE PE/version resource, artifact SHA-256 hashes, and private-file exclusions passed.
- All 2,087 archived 1.0 hashes verified unchanged.

```bash
cd /var/www/Netory_DIST/1.0.1
sha256sum -c SHA256SUMS.txt
/var/www/Netory/.venv/bin/python validation/verify-artifacts.py
/var/www/Netory/.venv/bin/python validation/verify-upgrade.py
```

These are Linux-side package/provisioning checks. The embedded Windows runtime, GUI, UAC, service/firewall operations, rollback, and uninstall have not been executed on Windows in this session. Test the complete lifecycle on a Windows test machine before production rollout. `installer-source/Test-SetupForm.ps1` and `Test-Installation.ps1 -ExpectedVersion 1.0.1` are included. The installer is unsigned.
