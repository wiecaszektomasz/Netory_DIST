# Netory 1.0.2 refreshed installers

Refreshed 2026-11-01T21:46:09.280539+00:00 from source revision `88ef978ddab5c5e1894755f67a8046a12391a689`, including the latest tested assistant port-address fix and accompanying uncommitted Windows branding/packaging changes. The source diff SHA-256 and Windows icon SHA-256 are recorded in BUILD-INFO.json. Source changes remain in the Netory working tree; private build inputs and keys stay outside the release.

## Windows

Protected Netory-Setup.exe and ZIP fallback rebuilt with bundled Windows x64 CPython 3.13.16. The Netory logo is embedded in the executable at 16, 24, 32, 48, 64, 128 and 256 pixels, with the matching icon included for the setup window, Start menu shortcuts and Installed Apps entry. Embedded executable icon bytes were checked against the source icon.

Actual bundled Windows Python tests under Wine passed: manifest/archive/checksum validation, no Netory Python source, fresh/repeated provisioning, current schema 0054_asset_port_addresses, upgrade from original 1.0 with administrator/inventory/configuration/licensing identity preservation and backup, native HTTP login/reads, unlicensed write rejection, modified UI/signature rejection and successful restored startup. Direct compiled assistant checks verify the new port-address allowlists, MAC/IP normalization, per-port clearing and invalid-IP rejection.

PowerShell parser checks passed for both changed setup scripts. Existing source installer regressions passed (7 tests), as did assistant port-address regressions (8 tests). Full results: Windows/validation-results.txt.

## Linux

Protected Ubuntu 24.04/26.04 x86-64 archive and matching install.sh rebuilt with pinned bundled portable CPython 3.13.18. Hash-pinned dependencies remain bundled inside the signed runtime. Private signing keys, production data/configuration and readable Netory application source are excluded.

Actual archive checks passed: checksums/signed payload, bundled dependency consistency, no Netory Python/C/Pyx source, fresh/repeated provisioning, administrator/configuration/licensing identity preservation, native HTTP login/reads, unlicensed write rejection, and rejection of changed dependency/UI/licensing/migration/signature files. Direct compiled assistant regression checks passed. All bundled ELF files passed the Ubuntu 24.04 glibc compatibility audit.

Isolated installer lifecycle checks passed: fresh installation with generated credentials and restricted permissions, real service-user HTTP login, repeat installation with backup and inventory/admin/identity/secure-cookie preservation, and simulated service-start failure rollback to a working previous release. These used private mount/PID namespaces and apt/systemctl shims. Full results: Linux/validation-results.txt.

## Platform limits and publication

Real Windows wizard/UAC/service/firewall/reboot/uninstall tests and clean Ubuntu VM apt/systemd/reboot tests remain outstanding. Wine and namespace checks do not certify those integrations. The installer is not Authenticode-signed. Normal licensing remains enforced.

Publication follow-up (2026-11-01T22:07:22.104574+00:00): the verified customer installers are publicly hosted at https://netory.app/downloads/1.0.2/ and linked from https://netory.app/download. Both complete public downloads were fetched with wget and their SHA-256 hashes matched the verified local artifacts. The Linux script is the exact verified file and pins the matching archive hash. Only an explicit allowlist of customer release files was published. No production application/service change was performed. Previous local 1.0.2 artifacts remain in a private backup directory; older version directories are unchanged.
