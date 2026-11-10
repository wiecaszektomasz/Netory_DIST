# Netory 1.0.4

Includes all current application changes and automatic online recovery from
a persistent clock-rollback license block after the computer clock is corrected.

- [Windows installer](Windows/Netory-Setup.exe), [ZIP fallback](Windows/Netory-Windows-x64.zip), [instructions](Windows/README.md).
- [Ubuntu installer](Linux/install.sh), [instructions](Linux/README.md).
- [Build and validation record](BUILD-INFO.md).

Windows now shows a visible wizard, uses standard zlib compression and runs
setup/maintenance with RemoteSigned instead of Bypass. Existing data-preserving
configuration and native module protection remain. This is an unsigned release;
no claim of antivirus clearance or guaranteed absence of SmartScreen warnings
is made. Prior release artifacts remain unchanged.
