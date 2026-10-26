# Netory Windows distributions

Windows x64 installer packages and build records. Application source is maintained in [Netory](https://github.com/wiecaszektomasz/Netory).

## Latest: 1.0.1

- [Netory-Setup.exe](1.0.1/Netory-Setup.exe)
- [ZIP fallback](1.0.1/Netory-Windows-x64.zip)
- [SHA-256 checksums](1.0.1/SHA256SUMS.txt)
- [Upgrade instructions and validation record](1.0.1/BUILD-INFO.md)

For an existing 1.0 installation, run the 1.0.1 installer and choose **Update Netory**. Do not uninstall first. Existing accounts, passwords, data, encryption keys and settings are preserved. Full Windows GUI/service lifecycle validation remains outstanding; see the build record.

The original [1.0 release](1.0/BUILD-INFO.md) is retained unchanged.

Release ZIPs contain the complete runtime and application payload. Extracted payload copies, build dependency caches and superseded repair snapshots are excluded from Git. Package manifests, installer sources, checksums and build records are included. Download and extract the complete ZIP to use `Install.cmd`; the extracted payload is not maintained as a separate Git copy.
