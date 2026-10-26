from pathlib import Path
import hashlib,json,zipfile,struct,re
release=Path('/var/www/Netory_DIST/1.0.1'); bundle=release/'Netory-Windows-x64'
def digest(path):
 with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
m=json.loads((bundle/'manifest.json').read_text())
assert m['version']=='1.0.1'
assert json.loads((bundle/'version.json').read_text())['version']=='1.0.1'
for name,expected in m['files'].items():assert digest(bundle/name)==expected,name
for line in (release/'SHA256SUMS.txt').read_text().splitlines():
 expected,name=line.split(maxsplit=1);assert digest(release/name.strip())==expected,name
with zipfile.ZipFile(release/'Netory-Windows-x64.zip') as archive:
 assert archive.testzip() is None
 assert len(archive.namelist())==len(m['files'])+1
 for name in [*m['files'],'manifest.json']:
  assert hashlib.sha256(archive.read('Netory-Windows-x64/'+name)).hexdigest()==digest(bundle/name),name
pe=(release/'Netory-Setup.exe').read_bytes()
assert pe[:2]==b'MZ'
assert pe[struct.unpack_from('<I',pe,0x3c)[0]:][:4]==b'PE\0\0'
position=pe.find(b'\xbd\x04\xef\xfe')
assert position>=0,'Missing Windows version resource'
version=struct.unpack_from('<13I',pe,position)
assert version[2:6]==(65536,65536,65536,65536),version[2:6]
for path in bundle.rglob('*'):
 if not path.is_file():continue
 assert path.name!='.env' and path.suffix not in {'.db','.sqlite','.sqlite3','.key'},path
 if path.suffix=='.pem':assert path.relative_to(bundle).as_posix() in {'payload/app/backend/trust/license-authority.pem','payload/runtime/Lib/site-packages/certifi/cacert.pem'},path
 if path.suffix in {'.py','.js','.css','.json','.html'}:
  assert not re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----\r?\n[A-Za-z0-9+/=]{20}',path.read_bytes()),path
assert (bundle/'payload/app/backend/migrations/versions/0046_report_configurations.py').exists()
assert (bundle/'payload/app/backend/assistant_vlan_ports.py').exists()
assert (bundle/'payload/app/frontend/room-map.js').read_bytes()==Path('/var/www/Netory/frontend/room-map.js').read_bytes()
old=Path('/var/www/Netory_DIST/1.0'); archive=json.loads((old/'ARCHIVE-SHA256.json').read_text())
for name,expected in archive.items():assert digest(old/name)==expected,name
print(f'PASS: {len(m["files"])} payload hashes, ZIP CRC/content, EXE PE signature and file/product version 1.0.1.0, artifact checksums, private-file exclusion and latest application sources.')
print(f'PASS: Original 1.0 archive unchanged ({len(archive)} archived hashes).')
