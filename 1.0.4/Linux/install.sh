#!/usr/bin/env bash
# Netory Ubuntu installer. Download this file before running it with sudo.
set -Eeuo pipefail
umask 027
VERSION=1.0.4
ARCHIVE_SHA256='3dd78147bc16284a0459e7f071dc70470fe6275ca481d3a4e4d959492c422adf'
BASE_URL="https://netory.app/downloads/$VERSION/Linux"
ARCHIVE='' PORT=8000 BIND=0.0.0.0 ADMIN_USER=admin
TLS=0 CERT='' KEY='' PORT_SET=0
usage() {
  echo "Usage: sudo bash install.sh [--archive /path/Netory-$VERSION-Linux.tar.gz] [--port 8000] [--bind 0.0.0.0] [--admin-user admin] [--https] [--cert /path/fullchain.pem --key /path/privkey.pem]"
}
while (($#)); do
  case "$1" in
    --https) TLS=1; shift;;
    --archive|--port|--bind|--admin-user|--cert|--key)
      (($# >= 2)) || { usage; exit 2; }
      case "$1" in --archive) ARCHIVE=$2;; --port) PORT=$2; PORT_SET=1;; --bind) BIND=$2;; --admin-user) ADMIN_USER=$2;; --cert) CERT=$2; TLS=1;; --key) KEY=$2; TLS=1;; esac
      shift 2;;
    --help|-h) usage; exit 0;;
    *) usage; exit 2;;
  esac
done
[[ $EUID == 0 ]] || { echo 'Run this installer with sudo.' >&2; exit 1; }
[[ $PORT =~ ^[0-9]{1,5}$ ]] && ((10#$PORT >= 1024 && 10#$PORT <= 65535)) || { echo 'Choose a port from 1024 to 65535.' >&2; exit 2; }
[[ $ADMIN_USER =~ ^[a-z][a-z0-9_-]{0,63}$ ]] || { echo 'Invalid administrator username.' >&2; exit 2; }
[[ $BIND =~ ^[0-9.]+$ || $BIND == :: || $BIND == ::1 ]] || { echo 'Use an IPv4 address, :: or ::1 for --bind.' >&2; exit 2; }
OS_ID=$(. /etc/os-release; printf '%s' "${ID:-}")
OS_VERSION=$(. /etc/os-release; printf '%s' "${VERSION_ID:-}")
[[ $OS_ID == ubuntu ]] || { echo 'This installer supports Ubuntu systems.' >&2; exit 1; }
case "$OS_VERSION" in 24.04|26.04) ;; *) echo 'Supported Ubuntu LTS versions: 24.04 and 26.04.' >&2; exit 1;; esac
[[ $(uname -m) == x86_64 ]] || { echo 'This protected package requires Linux x86-64 (amd64).' >&2; exit 1; }
[[ -d /run/systemd/system ]] || { echo 'Boot Ubuntu with systemd before installing.' >&2; exit 1; }
exec 9>/run/lock/netory-install.lock
flock -n 9 || { echo 'Another Netory installer is running.' >&2; exit 1; }
ROOT=/opt/netory DATA=/var/lib/netory
UNIT=/etc/systemd/system/netory.service
if [[ -e $UNIT && ! -f $ROOT/.installer-managed ]]; then
  echo 'An existing unmanaged Netory service was found. It has not been changed.' >&2; exit 1
fi
if [[ ! -f $ROOT/.installer-managed && ( -e $ROOT || -e $DATA ) ]]; then
  echo 'Existing Netory directories found. Back them up and migrate them manually first.' >&2; exit 1
fi
# Retain direct HTTPS and its port when upgrading without new TLS options.
if [[ -f $DATA/tls/fullchain.pem && -f $DATA/tls/privkey.pem ]]; then
  TLS=1
  if (( ! PORT_SET )); then
    SAVED_PORT=$(sed -n 's/.* --port \([0-9][0-9]*\).*/\1/p' "$UNIT")
    [[ $SAVED_PORT =~ ^[0-9]{1,5}$ ]] && PORT=$SAVED_PORT
  fi
fi
if (( TLS )); then
  if [[ -z $CERT && -z $KEY && ! -f $DATA/tls/fullchain.pem ]]; then
    [[ -t 0 ]] || { echo 'HTTPS requires --cert and --key PEM file paths.' >&2; exit 2; }
    read -r -p 'Full certificate chain PEM file path: ' CERT
    read -r -p 'Unencrypted private key PEM file path: ' KEY
  fi
  [[ -z $CERT && -z $KEY || -n $CERT && -n $KEY ]] || { echo 'Supply both --cert and --key.' >&2; exit 2; }
  if (( ! PORT_SET )) && [[ ! -f $DATA/tls/fullchain.pem ]]; then PORT=8443; fi
fi
SCHEME=http
(( ! TLS )) || SCHEME=https
WORK=$(mktemp -d /tmp/netory-install.XXXXXXXX)
OLD='' BACKUP='' CHANGED=0 WAS_ACTIVE=0 STOPPED=0 NEW=''
cleanup() {
  result=$?
  trap - EXIT
  if (( result != 0 && CHANGED )); then
    echo 'Installation failed; restoring the previous installation.' >&2
    systemctl stop netory.service >/dev/null 2>&1 || true
    if [[ -n $BACKUP ]]; then
      rm -rf "$DATA/tls"
      cp -a "$BACKUP/data/." "$DATA/"
      cp -a "$BACKUP/netory.service" "$UNIT"
    fi
    if [[ -n $OLD ]]; then
      ln -sfn "$OLD" "$ROOT/current"
    elif [[ -z $BACKUP ]]; then
      systemctl disable netory.service >/dev/null 2>&1 || true
      rm -f "$UNIT"
      # These paths did not exist before this fresh installation.
      rm -rf "$ROOT" "$DATA"
    fi
    systemctl daemon-reload || true
    if (( WAS_ACTIVE )); then systemctl start netory.service || true; fi
  fi
  if (( result != 0 && ! CHANGED && STOPPED && WAS_ACTIVE )); then
    systemctl start netory.service || true
  fi
  rm -rf "$WORK"
  exit "$result"
}
trap cleanup EXIT
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends python3 libgcc-s1 libstdc++6 zlib1g ca-certificates wget openssl nmap iputils-ping util-linux
if (( TLS )); then
  # Stage inputs before any service/data changes. Never ask for a key password.
  install -m 0600 -- "${CERT:-$DATA/tls/fullchain.pem}" "$WORK/fullchain.pem"
  install -m 0600 -- "${KEY:-$DATA/tls/privkey.pem}" "$WORK/privkey.pem"
  python3 - "$WORK/fullchain.pem" "$WORK/privkey.pem" <<'PYTLS'
import ssl, sys
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
try:
    context.load_cert_chain(sys.argv[1], sys.argv[2], password=lambda: '')
except (OSError, ssl.SSLError):
    raise SystemExit('Invalid certificate/key pair. Use PEM files and an unencrypted matching private key.')
PYTLS
  openssl x509 -in "$WORK/fullchain.pem" -noout -checkend 0 >/dev/null || { echo 'Certificate has expired or is invalid.' >&2; exit 2; }
fi
if [[ -n $ARCHIVE ]]; then
  cp -- "$ARCHIVE" "$WORK/package.tar.gz"
else
  wget --https-only --timeout=60 --tries=3 -O "$WORK/package.tar.gz" "$BASE_URL/Netory-$VERSION-Linux.tar.gz"
fi
printf '%s  %s\n' "$ARCHIVE_SHA256" "$WORK/package.tar.gz" | sha256sum --check --status || { echo 'Package checksum verification failed.' >&2; exit 1; }
# Only regular files/directories beneath the single package root may be extracted.
python3 - "$WORK/package.tar.gz" "$WORK" <<'PY'
import pathlib, sys, tarfile
with tarfile.open(sys.argv[1]) as archive:
    for entry in archive.getmembers():
        path = pathlib.PurePosixPath(entry.name)
        if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0] != 'netory' or not (entry.isfile() or entry.isdir()):
            raise SystemExit('Unsafe package member: ' + entry.name)
    archive.extractall(sys.argv[2], filter='data') if sys.version_info >= (3, 12) else archive.extractall(sys.argv[2])
PY
id netory >/dev/null 2>&1 || useradd --system --user-group --home-dir "$DATA" --shell /usr/sbin/nologin netory
install -d -m 0755 "$ROOT" "$ROOT/releases"
NEW=$(mktemp -d "$ROOT/releases/$VERSION.XXXXXXXX")
cp -a "$WORK/netory/." "$NEW/"
# Archive ownership must never grant a client login user write access to code.
chown -R root:root "$NEW"
chmod -R a+rX "$NEW"
chmod 0755 "$NEW"
"$NEW/runtime/bin/python3.13" -m pip check
OLD=$(readlink "$ROOT/current" || true)
if systemctl is-active --quiet netory.service; then WAS_ACTIVE=1; fi
if [[ -f $ROOT/.installer-managed ]]; then
  BACKUP="$ROOT/backups/$(date -u +%Y%m%dT%H%M%SZ)-$$"
  install -d -m 0700 "$ROOT/backups" "$BACKUP"
  systemctl stop netory.service
  STOPPED=1
  cp -a "$DATA" "$BACKUP/data"
  cp -a "$UNIT" "$BACKUP/netory.service"
fi
CHANGED=1
install -d -o root -g netory -m 0750 "$DATA"
install -d -o netory -g netory -m 0750 "$DATA/db" "$DATA/licensing" "$DATA/logs"
if (( TLS )); then
  install -d -o root -g netory -m 0750 "$DATA/tls"
  install -o root -g netory -m 0640 "$WORK/fullchain.pem" "$DATA/tls/fullchain.pem"
  install -o root -g netory -m 0640 "$WORK/privkey.pem" "$DATA/tls/privkey.pem"
fi
# Passwords go through stdin; they are never included in process arguments.
HAS_ADMIN=$(python3 - "$DATA/db/netory.db" <<'PYADMIN'
import pathlib, sqlite3, sys
path = pathlib.Path(sys.argv[1])
if not path.exists():
    print('0')
else:
    with sqlite3.connect('file:' + str(path) + '?mode=ro', uri=True) as db:
        table = db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='users'").fetchone()
        print('1' if table and db.execute('SELECT 1 FROM users WHERE is_admin = 1 LIMIT 1').fetchone() else '0')
PYADMIN
)
ADMIN_PASSWORD=$(openssl rand -hex 18)
if [[ $HAS_ADMIN == 0 ]]; then
  install -m 0600 /dev/null "$DATA/initial-admin.txt"
  printf 'Username: %s\nPassword: %s\nChange this password after signing in.\n' "$ADMIN_USER" "$ADMIN_PASSWORD" > "$DATA/initial-admin.txt"
fi
export NETORY_INSTALL_TLS="$TLS"
export NETORY_INSTALL_USER="$ADMIN_USER" NETORY_INSTALL_PASSWORD="$ADMIN_PASSWORD"
"$NEW/runtime/bin/python3.13" - "$DATA/.env" <<'PY' | PYTHONPATH="$NEW/app" "$NEW/runtime/bin/python3.13" "$NEW/tools/bootstrap.pyc" setup --app "$NEW/app" --data "$DATA"
import json, os, sys
from dotenv import dotenv_values
https = os.environ.get('NETORY_INSTALL_TLS') == '1' or str(dotenv_values(sys.argv[1]).get('COOKIE_SECURE', 'false')).lower() == 'true'
print(json.dumps({'username': os.environ['NETORY_INSTALL_USER'], 'password': os.environ['NETORY_INSTALL_PASSWORD'], 'https': https}))
PY
unset NETORY_INSTALL_USER NETORY_INSTALL_PASSWORD NETORY_INSTALL_TLS ADMIN_PASSWORD
chown root:netory "$DATA/.env"
chmod 0640 "$DATA/.env"
chown -R netory:netory "$DATA/db" "$DATA/licensing" "$DATA/logs"
chmod -R u=rwX,g=rX,o= "$DATA/db" "$DATA/licensing" "$DATA/logs"
TLS_ARGS=''
if (( TLS )); then
  TLS_ARGS=" --ssl-certfile $DATA/tls/fullchain.pem --ssl-keyfile $DATA/tls/privkey.pem"
fi
cat > "$UNIT" <<UNIT
# Managed by the Netory Ubuntu installer.
[Unit]
Description=Netory inventory service
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=netory
Group=netory
WorkingDirectory=$DATA
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONDONTWRITEBYTECODE=1
ExecStart=$ROOT/current/runtime/bin/python3.13 -m uvicorn backend.main:app --app-dir $ROOT/current/app --host $BIND --port $PORT$TLS_ARGS
Restart=on-failure
RestartSec=5
UMask=0027
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$DATA/db $DATA/licensing $DATA/logs
[Install]
WantedBy=multi-user.target
UNIT
ln -sfn "$NEW" "$ROOT/current"
systemctl daemon-reload
systemctl enable --now netory.service
READY=0
for ((attempt=0; attempt<60; attempt++)); do
  if python3 - "$PORT" "$BIND" "$SCHEME" "$DATA/tls/fullchain.pem" <<'PY'
import ssl, sys, urllib.request
try:
    host = '127.0.0.1' if sys.argv[2] == '0.0.0.0' else ('[::1]' if ':' in sys.argv[2] else sys.argv[2])
    handlers = [urllib.request.ProxyHandler({})]
    if sys.argv[3] == 'https':
        context = ssl.create_default_context(cafile=sys.argv[4])
        # Probe the local bind address, not the certificate's public DNS name.
        context.check_hostname = False
        context.verify_flags |= ssl.VERIFY_X509_PARTIAL_CHAIN
        handlers.append(urllib.request.HTTPSHandler(context=context))
    opener = urllib.request.build_opener(*handlers)
    with opener.open(sys.argv[3] + '://' + host + ':' + sys.argv[1] + '/', timeout=2) as response:
        assert response.status == 200 and b'auth-root' in response.read()
except Exception:
    raise SystemExit(1)
PY
  then READY=1; break; fi
  sleep 1
done
(( READY )) || { journalctl -u netory.service -n 30 --no-pager >&2; exit 1; }
printf '%s\n' "$VERSION" > "$ROOT/.installer-managed"
CHANGED=0
IP=$(hostname -I | awk '{print $1}')
printf '\nNetory %s is ready: %s://%s:%s/\n' "$VERSION" "$SCHEME" "${IP:-localhost}" "$PORT"
if [[ -f $DATA/initial-admin.txt ]]; then cat "$DATA/initial-admin.txt"; fi
echo "Credentials file: $DATA/initial-admin.txt (root only; upgrades preserve existing accounts)."
echo 'If a firewall is enabled, allow this TCP port from your trusted network.'
[[ -z $BACKUP ]] || echo "Upgrade backup: $BACKUP"

if (( TLS )); then
  echo 'HTTPS enabled. Connect using the DNS name/IP covered by your certificate.'
  echo "Certificates: $DATA/tls (root-owned, readable by the netory service group)."
  echo 'Renew with --https --cert /path/fullchain.pem --key /path/privkey.pem and the same --bind/--port options.'
  echo 'Certificate issuance and automatic renewal are not included.'
fi
