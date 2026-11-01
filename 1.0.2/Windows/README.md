# Netory 1.0.2 — Windows x64 installation

Supported by the existing installer: Windows 10/11 x64 and Windows Server 2019/2022/2025 with Desktop Experience, PowerShell 5.1 and administrator rights. This package includes its own CPython 3.13 runtime, Python dependencies, SQLite, WinSW service wrapper and Visual C++ runtime installer. A separate Python installation or database server is not required.

## Install

1. Download **Netory-Setup.exe** from the `Windows` directory. Optionally compare its SHA-256 with `SHA256SUMS.txt` using `Get-FileHash .\Netory-Setup.exe -Algorithm SHA256` in PowerShell.
2. Run the installer as administrator and accept the UAC prompt.
3. Choose the application/data directories and HTTP or HTTPS connection settings. Defaults keep access local to this computer; choose LAN access when other computers should connect. For HTTPS, provide your own valid certificate/PFX and hostname as requested by the wizard.
4. Set the administrator username and a password of at least **14 characters**. Windows setup does not use a shared default password.
5. Complete installation and open the address shown by setup. Netory is installed as an automatically starting Windows service.
6. Install a valid Netory license through **Manage application license** to enable writes. An unlicensed installation retains the application's normal read-only behavior.

If the executable wrapper cannot be used, extract the **entire** `Netory-Windows-x64.zip` and run `Netory-Windows-x64\Install.cmd` as administrator. Keep the extracted payload and setup files together.

Nmap is an additional prerequisite for TCP/ICMP host discovery. Install the official Windows Nmap package, ensure `nmap.exe` is on the machine PATH, and restart the Netory service. The protected package does not bundle Nmap. UDP service probes do not require Nmap. Discovery results also depend on network reachability and endpoint/firewall responses.

## Update and data

Run the 1.0.2 installer and choose **Update Netory**. Do not uninstall first. Existing accounts/passwords, inventory, encryption keys, configuration and license identity are preserved. Setup backs up the database/configuration before migration and supports rollback if installation fails.

Default locations are `%ProgramFiles%\Netory` for application files and `%ProgramData%\Netory` for data, configuration, logs, licensing and backups. Custom locations selected during setup are remembered. Back up the database **together with `.env` and licensing state**; do not move only the database or discard encryption keys.

Check the **Netory** service in `services.msc`; check the selected data directory's logs if startup fails. The service uses a restricted LocalService account. LAN access is limited by the firewall options chosen in the wizard. Change your password under account settings → **Change password**.

## Protected package and validation

This uses the same protection approach as the previous safe installer: native compiled Netory backend modules, sourceless migrations, minified UI and a signed integrity manifest checked before startup. This is code protection rather than literal encryption of every runtime file. Third-party dependencies and their notices remain present.

The integrity signature is separate from Windows publisher/Authenticode signing; the executable is not claimed to have a publisher certificate. Do not edit protected application files: integrity checks will reject modifications.

See `../BUILD-INFO.md` for actual validation results. Runtime tests under Wine do not replace a real Windows test of the wizard, UAC, service registration, firewall, reboot or uninstall behavior.
