"""Installer-only database/configuration tasks. Credentials arrive via stdin, never argv."""
import argparse
import json
import os
from pathlib import Path
import sqlite3
import shutil
from uuid import uuid4


def backup(data: Path, destination: Path):
    destination.mkdir(parents=True, exist_ok=True)
    database = data / 'db' / 'netory.db'
    if database.exists():
        with sqlite3.connect(str(database)) as source, sqlite3.connect(str(destination / 'netory.db')) as target:
            source.backup(target)
    licensing = data / 'licensing'
    if licensing.exists():
        from backend.licensing import LicenseManager
        with LicenseManager(licensing).locked():
            shutil.copytree(licensing, destination / 'licensing', dirs_exist_ok=True, ignore=shutil.ignore_patterns('lock', '*.tmp'))
    config = data / '.env'
    if config.exists():
        (destination / '.env').write_bytes(config.read_bytes())


def setup(app: Path, data: Path, parameters: dict):
    from cryptography.fernet import Fernet
    from dotenv import dotenv_values
    data.mkdir(parents=True, exist_ok=True)
    (data / 'db').mkdir(exist_ok=True)
    config = data / '.env'
    if (data / 'db' / 'netory.db').exists() and not config.exists():
        raise ValueError('An existing database has no encryption configuration. Restore its .env file before continuing.')
    values = dict(dotenv_values(config)) if config.exists() else {}
    database_url = 'sqlite:///' + (data / 'db' / 'netory.db').as_posix()
    if values.get('DATABASE_URL') and values['DATABASE_URL'] != database_url:
        raise ValueError('This installer manages its own SQLite database. Existing custom database configuration was preserved; contact your administrator.')
    values['DATABASE_URL'] = database_url
    values.setdefault('LICENSE_STATE_DIR', str(data / 'licensing'))
    values['COOKIE_SECURE'] = 'true' if parameters.get('https', False) else 'false'
    values.setdefault('WLAN_ENCRYPTION_KEY', Fernet.generate_key().decode())
    values.setdefault('AI_ENCRYPTION_KEY', Fernet.generate_key().decode())
    temporary = config.with_suffix('.tmp')
    temporary.write_text(''.join(f'{key}={json.dumps(str(value))}\n' for key, value in values.items() if value is not None), encoding='utf-8')
    temporary.replace(config)
    os.chdir(data)
    # Read the data directory configuration before importing any application models.
    from alembic import command
    from alembic.config import Config
    migration = Config(str(app / 'alembic.ini'))
    migration.set_main_option('script_location', str(app / 'backend' / 'migrations'))
    migration.set_main_option('prepend_sys_path', str(app))
    command.upgrade(migration, 'head')
    from backend.licensing import manager as license_manager
    if not (license_manager.directory / 'installation.json').exists():
        license_manager.provision()
    else:
        print('Existing license identity and encrypted clock state preserved.')
    from sqlalchemy import select
    from backend.db import SessionLocal
    from backend.models import User
    from backend.security import hash_password
    with SessionLocal() as db:
        if db.scalar(select(User).where(User.is_admin.is_(True))) is not None:
            print('Existing administrator accounts and passwords preserved.')
            return
        username = str(parameters.get('username', '')).strip().lower()
        password = parameters.get('password', '')
        if not username or len(username) > 120 or len(password) < 14:
            raise ValueError('Enter an administrator name and a password of at least 14 characters.')
        if db.scalar(select(User).where(User.username == username)) is not None:
            raise ValueError('This username already exists. Choose a different administrator name.')
        db.add(User(id=str(uuid4()), username=username, password_hash=hash_password(password), is_admin=True, is_active=True))
        db.commit()
    print('Database prepared and first administrator created.')


def certificate(data: Path, parameters: dict):
    """Import a PFX without retaining its password; validate identity using OpenSSL."""
    from datetime import datetime, timezone
    import ssl
    from cryptography.hazmat.primitives.serialization import pkcs12, Encoding, PrivateFormat, NoEncryption
    import ipaddress
    hostname = str(parameters.get('hostname', 'localhost')).strip()
    if not hostname or any(c in hostname for c in '/\\: \r\n\t"'):
        raise ValueError('Enter a DNS name or IPv4 address without a scheme, port or path.')
    try:
        ipaddress.ip_address(hostname)
    except ValueError:
        hostname = hostname.encode('idna').decode('ascii')
        if any(not part or len(part) > 63 or part.startswith('-') or part.endswith('-') or
               any(not (c.isalnum() or c == '-') for c in part) for part in hostname.split('.')):
            raise ValueError('Invalid certificate DNS name.')
    tls = data / 'tls'
    tls.mkdir(exist_ok=True)
    source = parameters.get('certificate')
    if source:
        password = parameters.get('certificate_password', '')
        try:
            key, cert, chain = pkcs12.load_key_and_certificates(Path(source).read_bytes(), password.encode('utf-8') if password else None)
        except ValueError:
            raise ValueError('Cannot open the PFX. Check its password and format.') from None
        if key is None or cert is None:
            raise ValueError('The PFX must include the server certificate and its private key.')
        now = datetime.now(timezone.utc)
        if not cert.not_valid_before_utc <= now <= cert.not_valid_after_utc:
            raise ValueError('The server certificate is expired or not yet valid.')
        cert_bytes = cert.public_bytes(Encoding.PEM) + b''.join(c.public_bytes(Encoding.PEM) for c in chain or [])
        key_bytes = key.private_bytes(Encoding.PEM, PrivateFormat.PKCS8, NoEncryption())
    else:
        cert_bytes = (tls / 'server.pem').read_bytes()
        key_bytes = (tls / 'server.key').read_bytes()
    # A temporary local TLS handshake verifies key matching, dates and SAN identity.
    # The installed certificate is trusted only for this setup check, never globally.
    import tempfile
    import socket
    import threading
    with tempfile.TemporaryDirectory(dir=tls) as directory:
        cert_path, key_path = Path(directory) / 'cert.pem', Path(directory) / 'key.pem'
        cert_path.write_bytes(cert_bytes); key_path.write_bytes(key_bytes)
        server = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        server.load_cert_chain(str(cert_path), str(key_path))
        client = ssl.create_default_context(cafile=str(cert_path))
        client.verify_flags |= ssl.VERIFY_X509_PARTIAL_CHAIN
        listener = socket.socket(); listener.bind(('127.0.0.1', 0)); listener.listen(1); listener.settimeout(5)
        def accept():
            try:
                connection, _ = listener.accept()
                with connection, server.wrap_socket(connection, server_side=True):
                    pass
            except (OSError, ssl.SSLError):
                pass
        worker = threading.Thread(target=accept, daemon=True); worker.start()
        try:
            with socket.create_connection(listener.getsockname(), timeout=5) as connection:
                with client.wrap_socket(connection, server_hostname=hostname):
                    pass
        finally:
            listener.close(); worker.join(timeout=6)
    (tls / 'server.pem').write_bytes(cert_bytes)
    (tls / 'server.key').write_bytes(key_bytes)
    print('HTTPS certificate validated and installed.')


def health(data: Path, parameters: dict):
    import socket
    import ssl
    port = int(parameters['port'])
    hostname = parameters.get('hostname', 'localhost')
    connection = socket.create_connection(('127.0.0.1', port), timeout=3)
    if parameters.get('https'):
        context = ssl.create_default_context(cafile=str(data / 'tls' / 'server.pem'))
        context.verify_flags |= ssl.VERIFY_X509_PARTIAL_CHAIN
        connection = context.wrap_socket(connection, server_hostname=hostname)
    with connection:
        connection.sendall(f'GET / HTTP/1.1\r\nHost: {hostname}\r\nConnection: close\r\n\r\n'.encode('ascii'))
        response = b''
        while True:
            block = connection.recv(65536)
            if not block:
                break
            response += block
            if len(response) > 4_000_000:
                break
        if not response.startswith(b'HTTP/1.1 200') or b'id="auth-root"' not in response:
            raise ValueError('Netory login page is not ready.')
    print('Netory login page is ready.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['setup', 'backup', 'certificate', 'health'])
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--data', type=Path, required=True)
    parser.add_argument('--destination', type=Path)
    args = parser.parse_args()
    if args.operation == 'backup':
        if args.destination is None:
            raise ValueError('Backup destination is required')
        backup(args.data, args.destination)
    else:
        parameters = json.load(__import__('sys').stdin)
        if args.operation == 'certificate':
            certificate(args.data.resolve(), parameters)
        elif args.operation == 'health':
            health(args.data.resolve(), parameters)
        else:
            setup(args.app.resolve(), args.data.resolve(), parameters)


if __name__ == '__main__':
    main()
