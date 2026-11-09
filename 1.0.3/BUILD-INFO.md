# Netory 1.0.3 build and validation

Built 2026-11-09T19:16:52.574342+00:00 from committed source `b2bd755211b98e863c6b368b43631ffb630fd15a`. Both installer manifests record this revision. Private keys, production configuration, databases, customer inventory and readable Netory Python source are excluded from customer packages.

## Included changes

Cost estimate CSV export and print/PDF; switch and patch-panel port pairs in both rack views; user-specific client selection restoration; copied assets without occupied rack placement; VLAN 1–4094 validation; bounded login bodies and malformed-password-hash rejection. Includes the existing Ubuntu direct HTTPS option.

## Validation performed

Full isolated source checks passed: backend: 901 tests passed; frontend: 192 tests passed, with no skips. Additional final frontend release checks passed. The updated generated demo passed Chromium CSV/print/PDF totals, paired cabinet and map rack ports, viewer controls and no uncaught JavaScript errors.

Windows: protected executable and ZIP fallback with bundled CPython 3.13.16. The actual bundled interpreter under Wine passed hashes/archive/source-exclusion checks, fresh/repeated provisioning, schema and account/configuration/licensing identity preservation, upgrade from original 1.0, HTTP login/reads, unlicensed write rejection and integrity/signature tamper rejection. See Windows/validation-results.txt.

Linux: protected archive and matching hash-pinned install.sh with portable CPython 3.13.18 and bundled dependencies. Native checks passed dependency consistency, all payload hashes, source exclusion, glibc compatibility, repeated provisioning, HTTP login/license behavior, identity/account preservation and rejection of changed dependencies, UI, licensing, migrations and signatures. Installer lifecycle checks passed fresh installation, generated credentials/permissions, HTTP login, repeated installation with backup and retained inventory/identity/secure-cookie settings, plus simulated service-failure rollback. These ran in private mount/PID namespaces with apt/systemctl shims. See Linux/validation-results.txt.

## Limits

Wine does not replace real Windows wizard/UAC/service/firewall/reboot/uninstall testing. Clean Ubuntu VM apt/systemd/reboot testing remains outstanding. The Windows executable is not Authenticode-signed. External discovery, Zabbix and AI services use controlled fixtures in automated tests. No claim of complete security or independent penetration testing is made.

## Publication

Customer downloads: https://netory.app/download. Versioned links: https://netory.app/downloads/1.0.3/. Previous releases remain available. Root/platform SHA256SUMS.txt cover customer release files; extracted Windows payload copies and private build workspaces remain outside the public download allowlist.
