# Protected Windows release build

`Netory_DIST/1.0.2/Windows` is the protected Windows distribution of version 1.0.2. It uses the same installer and upgrade/data-preservation behavior as the regular release. The regular `1.0` and `1.0.1` artifacts are not modified.

The Windows executable embeds the Netory logo at seven icon sizes (16–256 pixels). The same `deploy/windows/Netory.ico` asset is bundled for the setup window, Start menu shortcuts and Installed Apps entry. Both regular and protected builds retain this branding.

## Protection

- Netory server modules, including licensing, authentication, models, API routes and installer bootstrap logic, are compiled with Cython to stripped x64 Windows `.pyd` extensions for the bundled CPython 3.13 runtime. Netory `.py`, generated `.c`, and `.pyx` sources are not distributed.
- Migration scripts and package initializers use CPython 3.13 bytecode. Alembic runs with `sourceless = true`. Bytecode can be decompiled; native compilation protects the main application logic more strongly.
- First-party browser JavaScript and CSS are minified without source maps. Browser assets remain accessible to users, as required to run the interface.
- An Ed25519-signed manifest covers installed application files, runtime dependencies, setup scripts and version metadata. The compiled server and bootstrap verify its signature and file hashes before normal startup. Customer data, database, configuration, TLS certificates, license identity and logs remain outside this immutable set.
- Existing vendor-signed license verification remains active. This edition retains the application's existing read-only policy when no valid license is present; it does not introduce a new license entitlement or disable read-only access.

This raises the cost of inspection and modification, but cannot make client-controlled software impossible to reverse engineer or patch. Previously distributed readable releases remain readable. Python itself and third-party dependencies remain standard upstream components; their available source and legal notices are preserved. This is not a promise to hide every Python file belonging to third-party dependencies.

The integrity manifest is not Windows Authenticode signing. Code-signing the final installer with a publisher certificate is a separate release operation. Full GUI/UAC, Windows service registration, firewall and reboot behavior must be checked on a real Windows machine before customer rollout; Wine tests cover the Windows interpreter, compiled app and bootstrap, not these operating-system integrations.

## Rebuild

Start from a freshly verified regular Windows 1.0.2 extracted bundle. On the Linux builder, install MinGW x64 GCC/binutils, Wine64, Node with Terser/PostCSS, and a separate Python environment with Cython, pefile and cryptography. Download the matching CPython 3.13.16 source headers. Use the same runtime version as the input bundle.

```
python deploy/windows/build_safe.py \
  --source /tmp/netory-1.0.2-base/Netory-Windows-x64 \
  --output /var/www/Netory_DIST/1.0.2/Windows \
  --toolchain /var/www/Netory_DIST/build-support/safe-toolchain \
  --cython /var/www/Netory_DIST/build-support/safe-toolchain/venv/bin/cython \
  --makensis /var/www/Netory_DIST/build-support/nsis/usr/bin/makensis \
  --nsisdir /var/www/Netory_DIST/build-support/nsis/usr/share/nsis
```

The output must not already exist. The toolchain directory contains `Python-3.13.16`, the Wine prefix, generated C files and an automatically generated mode-0600 `integrity-signing.key`. Keep this directory private and excluded from Git and customer archives. Back up the integrity signing key securely for reproducible rebuilds. It is separate from the vendor license-signing key, which is never needed by this builder. Only the integrity public key is embedded in compiled application code.

Run validation with the production Python environment (dotenv is required by the upgrade test):

```
.venv/bin/python deploy/windows/verify_safe.py \
  --release /var/www/Netory_DIST/1.0.2/Windows \
  --legacy-bundle /var/www/Netory_DIST/1.0/Netory-Windows-x64 \
  --expected-head 0054_asset_port_addresses \
  --work /var/www/Netory_DIST/build-support/safe-toolchain/validation-1.0.2
```

The verifier checks archive/file hashes, absence of Netory Python source, fresh/repeated installation, an actual original-1.0 database upgrade, account/configuration/license-identity preservation, native HTTP routing, login, rejected unlicensed writes and rejected tampering. It uses disposable test data and does not alter the live application database.

References: [Cython compilation](https://docs.cython.org/en/latest/src/userguide/source_files_and_compilation.html), [Alembic sourceless configuration](https://alembic.sqlalchemy.org/en/latest/tutorial.html).
