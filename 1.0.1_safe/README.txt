Netory 1.0.1 SAFE - Windows x64

Run Netory-Setup.exe as administrator. This is an alternative protected build
of 1.0.1, compatible with the normal installer's 1.0 -> 1.0.1 upgrade path.
Back up customer data before upgrading. Existing database, administrators,
encryption keys, license identity and configured data location are preserved.

Protection:
- Native compiled Netory server and licensing modules; no Netory Python source.
- Bytecode-only database migrations and package initializers.
- Minified browser assets without source maps.
- Signed installed-file integrity checks before server/bootstrap startup.
- Existing vendor-signed licensing policy, including unlicensed read-only mode.

Do not manually edit immutable installed program files. Changes cause integrity
verification to fail; use a freshly signed installer to update the application.
Customer data, .env, database, TLS and license state remain separately writable.

This increases reverse-engineering effort; it does not make software uncrackable.
Standard Python and third-party libraries are included with their legal notices.
Previously distributed source code remains readable. This installer has no
Windows Authenticode publisher signature.

See protection-notes.md and validation-results.txt for implementation details and
test coverage. Real Windows GUI/UAC, service, firewall and reboot checks remain
necessary before customer deployment; Wine cannot validate those integrations.
