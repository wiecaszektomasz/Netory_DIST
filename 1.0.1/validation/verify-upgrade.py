"""Exercise the actual archived 1.0 bootstrap and the packaged 1.0.1 upgrader on Linux."""
import os,json,sqlite3,subprocess,sys,tempfile,argparse
from pathlib import Path
from dotenv import dotenv_values
from cryptography.fernet import Fernet
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--previous-bundle',type=Path,default=Path('/var/www/Netory_DIST/1.0/Netory-Windows-x64'))
parser.add_argument('--bundle',type=Path,default=Path('/var/www/Netory_DIST/1.0.1/Netory-Windows-x64'))
args=parser.parse_args()
old=args.previous_bundle.resolve(); new=args.bundle.resolve()

def run(bundle,operation,data,parameters=None,destination=None):
 app=bundle/'payload/app'
 args=[sys.executable,str(bundle/'payload/tools/bootstrap.py'),operation,'--app',str(app),'--data',str(data)]
 if destination:args+=['--destination',str(destination)]
 result=subprocess.run(args,input=json.dumps(parameters or {}),text=True,capture_output=True,cwd=data.parent,env={**os.environ,'PYTHONPATH':str(app)})
 assert result.returncode==0,result.stderr
 return result

with tempfile.TemporaryDirectory(prefix='netory-101-upgrade-') as directory:
 fresh=Path(directory)/'Fresh Installation'; fresh.mkdir()
 run(new,'setup',fresh,{'username':'FreshAdmin','password':'fresh-installer-password-101'})
 with sqlite3.connect(fresh/'db/netory.db') as db:
  assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
  assert db.execute('SELECT version_num FROM alembic_version').fetchone()[0]=='0046_report_configurations'
  assert db.execute('SELECT username FROM users').fetchone()[0]=='freshadmin'
 assert (fresh/'licensing/installation.json').exists()
 data=Path(directory)/'Custom Netory Data'; data.mkdir()
 run(old,'setup',data,{'username':'ReleaseAdmin','password':'upgrade-test-password-101'})
 config=(data/'.env').read_bytes()
 values=dotenv_values(data/'.env'); key=values['WLAN_ENCRYPTION_KEY']
 seed=r'''
import os
from pathlib import Path
from sqlalchemy import select
from backend.db import SessionLocal
from backend.models import User,Environment,Asset,Room,RackCabinet,Vlan,NetworkDefinition,BoardNote
from cryptography.fernet import Fernet
with SessionLocal() as db:
 user=db.scalar(select(User).where(User.is_admin.is_(True)))
 db.add(Environment(id='upgrade-env',name='Existing customer',revision=7)); db.flush()
 db.add(Room(id='room',environment_id='upgrade-env',name='Existing room')); db.flush()
 db.add(RackCabinet(id='rack',environment_id='upgrade-env',name='Existing rack',capacity_u=42,room_id='room')); db.flush()
 db.add(Asset(id='switch',environment_id='upgrade-env',name='Existing switch',type='Switch',rack_id='rack',rack_enabled=True,rack_units=1,rack_start_u=1,port_count=24,port_vlans={'3':{'untaggedVlan':1,'taggedVlans':[106]}}))
 db.add(Vlan(id='v106',environment_id='upgrade-env',name='Existing VLAN',vlan_number=106))
 db.add(NetworkDefinition(id='wifi',environment_id='upgrade-env',network_type='WLAN',name='Existing WLAN',wifi_password_encrypted=Fernet(os.environ['WLAN_ENCRYPTION_KEY'].encode()).encrypt(b'preserved-wifi-secret').decode()))
 db.add(BoardNote(id='old-note',environment_id='upgrade-env',author_id=user.id,author_name=user.username,content='Existing maintenance handover'))
 db.commit()
'''
 result=subprocess.run([sys.executable,'-c',seed],cwd=data,text=True,capture_output=True,env={**os.environ,'PYTHONPATH':str(old/'payload/app'),'WLAN_ENCRYPTION_KEY':key})
 assert result.returncode==0,result.stderr
 database=data/'db/netory.db'
 with sqlite3.connect(database) as db:
  assert db.execute('SELECT version_num FROM alembic_version').fetchone()[0]=='0043_notes_board'
  admin=db.execute('SELECT id,username,password_hash FROM users').fetchone()
  secret=db.execute('SELECT wifi_password_encrypted FROM network_definitions').fetchone()[0]
 # Preserve an existing license identity even though original 1.0 did not create one.
 provision="from backend.licensing import LicenseManager; import sys; LicenseManager(sys.argv[1]).provision()"
 result=subprocess.run([sys.executable,'-c',provision,str(data/'licensing')],cwd=data.parent,text=True,capture_output=True,env={**os.environ,'PYTHONPATH':str(new/'payload/app')})
 assert result.returncode==0,result.stderr
 identity=(data/'licensing/installation.json').read_bytes()
 backup=Path(directory)/'upgrade backup'
 run(new,'backup',data,destination=backup)
 assert (backup/'.env').read_bytes()==config
 assert (backup/'licensing/installation.json').read_bytes()==identity
 run(new,'setup',data,{'username':'ignored','password':'different-password-after-upgrade'})
 assert (data/'licensing/installation.json').read_bytes()==identity
 updated=dotenv_values(data/'.env')
 for setting,value in values.items():assert updated[setting]==value,setting
 assert Fernet(updated['WLAN_ENCRYPTION_KEY'].encode()).decrypt(secret.encode())==b'preserved-wifi-secret'
 with sqlite3.connect(database) as db:
  assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
  assert db.execute('SELECT version_num FROM alembic_version').fetchone()[0]=='0046_report_configurations'
  assert db.execute('SELECT id,username,password_hash FROM users').fetchone()==admin
  assert db.execute('SELECT count(*) FROM users').fetchone()[0]==1
  assert db.execute('SELECT name,revision FROM environments').fetchone()==('Existing customer',7)
  assert db.execute('SELECT name,rack_id,room_id FROM assets').fetchone()==('Existing switch','rack',None)
  assert json.loads(db.execute('SELECT port_vlans FROM assets').fetchone()[0])['3']['taggedVlans']==[106]
  assert db.execute('SELECT content FROM board_notes').fetchone()[0]=='Existing maintenance handover'
  assert db.execute('SELECT wifi_password_encrypted FROM network_definitions').fetchone()[0]==secret
  db.execute('INSERT INTO report_configurations (user_id,environment_id,items,version) VALUES (?,?,?,?)',(admin[0],'upgrade-env',json.dumps([{'name':'Saved after upgrade','options':{'type':'assets'}}]),1));db.commit()
 with sqlite3.connect(backup/'netory.db') as db:
  assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
  assert db.execute('SELECT version_num FROM alembic_version').fetchone()[0]=='0043_notes_board'
  assert db.execute('SELECT id,username,password_hash FROM users').fetchone()==admin
 run(new,'setup',data,{'username':'ignored','password':'another-repair-password-101'})
 with sqlite3.connect(database) as db:
  assert db.execute('SELECT count(*) FROM report_configurations').fetchone()[0]==1
 print('PASS: Fresh packaged 1.0.1 installation.')
 print('PASS: Actual 1.0 archive -> packaged 1.0.1 upgrade and repeat setup.')
 print('Preserved admin credentials, custom data directory, inventory, VLAN port settings, rooms/racks, encrypted WLAN, notes, environment revision, keys and licensing identity.')
 print('Verified backup at 0043, migration to 0046, database integrity and new saved reports table.')
