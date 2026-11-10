# Netory 1.0.4 refreshed build and validation

Rebuilt on 2026-11-10 without incrementing the release version. Application
source: `ff84013b7bd5390cb33fadd6cd305d880ec421cf`. Demo builder fix: `89681a3f0892258efc88ddf4b94c3fa3eb47a86d`. The only intervening
changes are the demo builder and its regression test; see BUILD-INFO.json for
both packaged manifest revisions.

## Included changes

Physical port layouts, connector spacing, paired router numbering, readable rack
headings and the 56-port limit for new or changed port counts. The demo bundles
connector data as JavaScript to retain its no-network Content Security Policy.
Existing clock-rollback recovery, native compilation, signed runtime integrity,
installer backup and data-preservation behavior remain included.

## Validation

- 73 Python source tests passed: physical layouts, licensing, Windows provisioning,
  Linux TLS installation and release security.
- 69 frontend/demo tests passed; 16 demo tests passed again after the CSP fix.
- 49 physical-port browser scenarios passed across device counts, rack views,
  viewport widths and zoom settings.
- Windows archive and payload hashes, fresh/repeated setup, original-1.0 upgrade,
  account/inventory/configuration/license identity preservation, HTTP login/read,
  unlicensed-write rejection and tamper/signature rejection passed under Wine.
- Linux archive/runtime hashes, source exclusion, dependencies, glibc compatibility,
  fresh/repeated setup, account/configuration/license identity preservation,
  HTTP login/read and tamper/signature rejection passed using its bundled runtime.
- Compiled licensing on both platforms passed clock-rollback persistence offline,
  recovery with fresh online approval after clock correction, restart persistence
  and accepted authority-clock skew.

See source-tests.txt and each platform's validation-results.txt and
clock-recovery-validation.txt. Tests use disposable data, not production inventory.

## Limits

The Windows executable remains unsigned; no antivirus scan or real Windows
wizard/UAC/service/firewall/reboot/uninstall validation was performed. Linux
validation did not repeat a clean Ubuntu apt/systemd/reboot installation.

Published download location: https://netory.app/downloads/1.0.4/.
