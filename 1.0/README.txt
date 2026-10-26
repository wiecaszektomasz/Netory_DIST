NETORY FOR WINDOWS (64-bit)

QUICK START
1. Run Netory-Setup.exe and approve the Windows administrator prompt.
   Alternative: extract the ZIP completely, then double-click Install.cmd.
2. Choose separate application and database/data folders on a local fixed disk.
   Defaults: C:\Program Files\Netory and C:\ProgramData\Netory.
   Leave port 8000 or choose another unused port.
   Optional: select Use HTTPS, enter the certificate DNS name/IP, browse to a
   .pfx/.p12 certificate containing its private key and chain, and enter its password.
3. Choose the first administrator name and a password of at least 14 characters.
   You can click in every field or use Tab to move between them.
4. Click Install Netory. Setup opens Netory in your browser when ready.

No manual Python, database server, pip, .NET installation or Internet connection is
required on the target computer. A private Python runtime and SQLite database
engine are included. Microsoft Visual C++ Runtime is installed automatically;
WinSW uses the .NET Framework already included in the supported Windows versions. Existing system Python installations are not changed.

Windows 10/11 x64 or Windows Server 2019/2022/2025 x64 with desktop/PowerShell 5.1.
This package is not for 32-bit Windows, Windows ARM64 or Server Core GUI-less use.

SERVICE AND PORT
Netory is installed as an automatic Windows service named Netory. It runs as the
restricted LocalService account and restarts after an unexpected failure.
Use Start > Netory > Open Netory to launch the browser.
Use Start > Netory > Configure Netory to change the port, network access, HTTPS or server certificate.
You can also manage Netory from the Windows Services application.
During update/configuration, administrator fields are intentionally read-only.
Existing accounts are preserved; change account passwords inside Netory.
Network and HTTPS settings remain editable. Storage locations are preserved
during updates/configuration; this does not migrate an existing database.

Local-only access is the default. The optional private-network setting binds
IPv4 network interfaces and opens only the selected TCP port for Windows Private
profiles and local-subnet clients.

HTTPS AND CERTIFICATES
HTTPS is served directly by Netory; a reverse proxy is optional. Import a
CA-issued PFX/P12 containing the server private key and intermediate chain.
The DNS name/IP must match the certificate SAN and resolve to this computer.
IPv4 addresses and DNS names are supported; IPv6 certificate names are not.
The installer checks certificate dates, identity and key matching. It does not
issue public certificates, configure DNS or add certificates to Windows trust.
For a private CA, your administrator must deploy its root certificate to client
trust stores. Including a root in a PFX alone does not make browsers trust it.
Use Configure Netory to enable/disable HTTPS or replace/renew the certificate.
Leave the certificate field blank to retain the installed certificate; select a
new PFX and enter its password to replace it. Passwords are passed over stdin
and never saved. The exported service key is protected by Windows permissions:
only administrators, SYSTEM and the service can read it. Keep backups secure.
HTTPS automatically enables secure login cookies; HTTP disables that flag.
Existing secure cookies may require clearing site cookies after switching to HTTP.
The local readiness check validates against the installed certificate only;
it does not prove that remote browsers trust the issuing CA.

FILES AND BACKUPS
Default locations (custom choices appear in setup and are remembered):
Program: C:\Program Files\Netory
Data/config/keys: C:\ProgramData\Netory
Database: C:\ProgramData\Netory\db\netory.db
Logs: C:\ProgramData\Netory\logs
Automatic pre-update backups: C:\ProgramData\Netory\backups

Keep the .env encryption keys with database backups. Do not lose these keys;
stored encrypted Wi-Fi passwords and AI credentials need them. Backups contain
sensitive data and are restricted to administrators and SYSTEM.

UPDATES
Run the new Netory-Setup.exe. Setup preserves accounts, database and encryption
keys, stops the service, makes a database/config backup, installs new program
files, applies migrations, and restarts the service. If an update fails it attempts
to restore the previous program, database and configuration. Do not install over
an unrelated custom Netory deployment or change program files manually.

UNINSTALL
Use Windows installed apps > Netory, or Start > Netory > Uninstall Netory.
Uninstall removes the service, program and firewall rule. Data/config/backups stay
in the selected data folder so they can be restored or reused. Delete them manually
only when you are certain you no longer need the database and encryption keys.

TROUBLESHOOTING
Choose a different port if it is already in use. Check setup.log and service logs
in the logs subfolder of the selected data folder. Administrative rights are required for setup,
configuration and removal. If organizational PowerShell/AppLocker policy blocks
the installer, contact your administrator; setup does not change those policies.
The installer is not Authenticode-signed; only run the package supplied by your
trusted Netory administrator. SHA256SUMS.txt supports corruption checks, not a
publisher identity guarantee.

VALIDATION LIMIT
The package was built on Linux. Payload hashes, Windows wheels, installer
PowerShell syntax, migration/provisioning logic and executable packaging can be
checked there. A full Windows installation/service lifecycle test is still
required before a production rollout.
