# Netory 1.0.4 build and validation

Prepared locally on 2026-11-10 from source `fc231ac386550dffed33fe9ab0c9f45a7ed91cfa` plus the uncommitted changes listed in BUILD-INFO.json. Both runtime manifests record this revision. Private build provenance is retained separately; its patch SHA-256 is `29235d7306933f1c25a8e04850bbe3eca9e791ffc1f79f4b117e42f859416d46`. This is not represented as a clean tagged release. Customer download location: https://netory.app/downloads/1.0.4/.

## Changes

Includes the latest application source and the clock-rollback license recovery fix. A fresh signed, nonce-bound online approval clears a saved rollback block when the local clock is within the accepted authority-time tolerance and the license is valid. Offline rollback blocking remains active. Activation now uses the local clock for its local high-water mark, avoiding a false rollback when the authority clock is slightly ahead.

Windows now has visible NSIS welcome/extraction/finish pages, standard zlib compression, Netory branding and publisher/version metadata. Setup, elevation, Start menu configuration and uninstall use process-scoped RemoteSigned instead of Bypass. The existing PowerShell configuration engine, native compilation, signed runtime integrity, backups and upgrade rollback are retained. No persistent execution policy or antivirus settings are changed. Organizational Group Policy takes precedence; downloaded ZIP scripts may be blocked. See [Microsoft execution policy documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1).

## Checks performed

- 49 relevant licensing, Windows provisioning/signing, Linux TLS installer and release security source tests passed.
- All Windows installer PowerShell scripts parsed; the new NSIS wizard compiled successfully. Finished EXE metadata is Netory 1.0.4; no Authenticode signature is present.
- Windows EXE/ZIP checksums and all payload hashes passed. The actual bundled Windows interpreter under Wine passed fresh/repeated provisioning, original-1.0 upgrade, backups, account/configuration/inventory/license identity preservation, HTTP login/reads, unlicensed-write rejection and integrity/signature tamper rejection.
- Linux archive/runtime hashes, source exclusion, dependency consistency and glibc compatibility passed. Actual bundled runtime provisioning, account/configuration/license identity preservation, HTTP login/reads and unlicensed-write rejection passed. Modified dependencies, UI, compiled licensing, migrations and signature were rejected; restored runtime starts.
- Compiled licensing on both platforms passed rollback persistence offline, rejection with an incorrect clock, recovery with fresh online approval without reimport, recovery persistence after restart and activation with accepted authority clock skew. Linux regression was repeated against the extracted final archive.

See each platform's validation-results.txt and clock-recovery-validation.txt. Checks used disposable data and controlled license-authority fixtures.

## Limits

The installer remains unsigned. No antivirus scan or vendor clearance was performed; fewer detections or absence of SmartScreen/unknown-publisher warnings is not guaranteed. A real Windows wizard/UAC/service/firewall/reboot/uninstall test remains outstanding. Linux validation used the actual runtime but did not repeat a clean Ubuntu apt/systemd/reboot installation test. Prior release artifacts remain available.
