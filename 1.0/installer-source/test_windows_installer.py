"""Installer provisioning tests run in subprocesses without live configuration."""
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
from argon2 import PasswordHasher
from alembic.script import ScriptDirectory

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'deploy/windows/bootstrap.py'


def run_setup(data, password='installer-test-password-123'):
    return subprocess.run([sys.executable,str(SCRIPT),'setup','--app',str(ROOT),'--data',str(data)],input=json.dumps({'username':'InstallAdmin','password':password}),text=True,capture_output=True,cwd=data.parent,env={**os.environ,'PYTHONPATH':str(ROOT)},check=True)


def test_installer_creates_database_admin_and_preserves_keys_and_backups(tmp_path):
    data=tmp_path/'state';result=run_setup(data)
    assert 'installer-test-password-123' not in result.stdout+result.stderr
    database=data/'db/netory.db'
    with sqlite3.connect(database) as db:
        username,hashed,is_admin=db.execute('SELECT username,password_hash,is_admin FROM users').fetchone()
        assert username=='installadmin' and is_admin==1
        assert PasswordHasher().verify(hashed,'installer-test-password-123')
        assert db.execute('SELECT version_num FROM alembic_version').fetchone()[0]==ScriptDirectory(str(ROOT/'backend/migrations')).get_current_head()
    original=(data/'.env').read_text()
    assert 'WLAN_ENCRYPTION_KEY' in original and 'AI_ENCRYPTION_KEY' in original
    assert 'installer-test-password-123' not in original
    run_setup(data,password='different-password-456')
    assert (data/'.env').read_text()==original
    with sqlite3.connect(database) as db:
        assert db.execute('SELECT count(*) FROM users').fetchone()[0]==1
        assert db.execute('SELECT password_hash FROM users').fetchone()[0]==hashed
    backup=tmp_path/'backup'
    subprocess.run([sys.executable,str(SCRIPT),'backup','--app',str(ROOT),'--data',str(data),'--destination',str(backup)],check=True,cwd=tmp_path)
    assert (backup/'.env').read_text()==original
    with sqlite3.connect(backup/'netory.db') as db:assert db.execute('SELECT username FROM users').fetchone()[0]=='installadmin'


def test_installer_rejects_short_password(tmp_path):
    data=tmp_path/'state'
    try:run_setup(data,password='short')
    except subprocess.CalledProcessError as error:assert 'at least 14 characters' in error.stderr
    else:raise AssertionError('Short password was accepted')
    with sqlite3.connect(data/'db/netory.db') as db:assert db.execute('SELECT count(*) FROM users').fetchone()[0]==0


def test_installer_refuses_to_replace_missing_encryption_configuration(tmp_path):
    data=tmp_path/'state';run_setup(data)
    original=(data/'db/netory.db').read_bytes()
    (data/'.env').unlink()
    try:run_setup(data)
    except subprocess.CalledProcessError as error:assert 'Restore its .env file' in error.stderr
    else:raise AssertionError('Lost encryption keys were silently replaced')
    assert not (data/'.env').exists()
    assert (data/'db/netory.db').read_bytes()==original


def make_pfx(tmp_path, name='netory.test', expired=False):
    from datetime import datetime, timedelta, timezone
    from cryptography import x509
    from cryptography.x509.oid import NameOID
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives.serialization import pkcs12
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name)])
    now = datetime.now(timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(subject).issuer_name(subject)
            .public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now-timedelta(days=2))
            .not_valid_after(now+timedelta(days=-1 if expired else 30))
            .add_extension(x509.SubjectAlternativeName([x509.DNSName(name)]), critical=False)
            .sign(key, hashes.SHA256()))
    path = tmp_path / 'server.pfx'
    path.write_bytes(pkcs12.serialize_key_and_certificates(b'Netory', key, cert, None,
                    serialization.BestAvailableEncryption(b'pfx-secret-123')))
    return path


def certificate_command(data, **parameters):
    return subprocess.run([sys.executable, str(SCRIPT), 'certificate', '--app', str(ROOT), '--data', str(data)],
                          input=json.dumps(parameters), text=True, capture_output=True)


def test_pfx_import_validates_identity_and_preserves_certificate_on_failure(tmp_path):
    import ssl
    data = tmp_path / 'custom database'; data.mkdir()
    source = make_pfx(tmp_path)
    result = certificate_command(data, hostname='netory.test', certificate=str(source), certificate_password='pfx-secret-123')
    assert result.returncode == 0, result.stderr
    assert 'pfx-secret-123' not in result.stdout + result.stderr
    installed = (data / 'tls/server.pem').read_bytes()
    key = (data / 'tls/server.key').read_bytes()
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(data / 'tls/server.pem', data / 'tls/server.key')
    result = certificate_command(data, hostname='wrong.test', certificate=str(source), certificate_password='pfx-secret-123')
    assert result.returncode != 0
    assert (data / 'tls/server.pem').read_bytes() == installed
    assert (data / 'tls/server.key').read_bytes() == key
    result = certificate_command(data, hostname='netory.test')
    assert result.returncode == 0, result.stderr
    result = certificate_command(data, hostname='netory.test', certificate=str(source), certificate_password='wrong')
    assert result.returncode != 0 and 'Check its password' in result.stderr
    assert (data / 'tls/server.pem').read_bytes() == installed


def test_pfx_import_rejects_expired_certificate(tmp_path):
    source = make_pfx(tmp_path, expired=True)
    result = certificate_command(tmp_path, hostname='netory.test', certificate=str(source), certificate_password='pfx-secret-123')
    assert result.returncode != 0 and 'expired' in result.stderr
    assert not (tmp_path / 'tls/server.key').exists()


def test_https_setup_changes_cookie_security_without_replacing_encryption_keys(tmp_path):
    from dotenv import dotenv_values
    data = tmp_path / 'custom data folder'; run_setup(data)
    before = dotenv_values(data / '.env')
    result = subprocess.run([sys.executable, str(SCRIPT), 'setup', '--app', str(ROOT), '--data', str(data)],
                            input=json.dumps({'https': True}), text=True, capture_output=True,
                            cwd=tmp_path, env={**os.environ, 'PYTHONPATH': str(ROOT)})
    assert result.returncode == 0, result.stderr
    after = dotenv_values(data / '.env')
    assert after['COOKIE_SECURE'] == 'true'
    assert after['WLAN_ENCRYPTION_KEY'] == before['WLAN_ENCRYPTION_KEY']
    assert after['AI_ENCRYPTION_KEY'] == before['AI_ENCRYPTION_KEY']


def test_https_readiness_uses_installed_identity_without_system_trust_changes(tmp_path):
    import http.server
    import ssl
    import threading
    data = tmp_path / 'state'; data.mkdir()
    source = make_pfx(tmp_path)
    result = certificate_command(data, hostname='netory.test', certificate=str(source), certificate_password='pfx-secret-123')
    assert result.returncode == 0, result.stderr
    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'
        def do_GET(self):
            content = b'<html><div id="auth-root"></div></html>'
            self.send_response(200); self.send_header('Content-Length', str(len(content))); self.end_headers()
            self.wfile.write(content)
        def log_message(self, *args):
            pass
    server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(data / 'tls/server.pem', data / 'tls/server.key')
    server.socket = context.wrap_socket(server.socket, server_side=True)
    worker = threading.Thread(target=server.serve_forever, daemon=True); worker.start()
    try:
        for hostname, expected in [('netory.test', 0), ('wrong.test', 1)]:
            result = subprocess.run([sys.executable, str(SCRIPT), 'health', '--app', str(ROOT), '--data', str(data)],
                                    input=json.dumps({'port': server.server_port, 'https': True, 'hostname': hostname}),
                                    text=True, capture_output=True, timeout=10)
            assert (result.returncode != 0) == bool(expected), result.stderr
    finally:
        server.shutdown(); server.server_close(); worker.join(timeout=5)
