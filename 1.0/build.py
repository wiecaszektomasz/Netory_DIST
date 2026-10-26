#!/usr/bin/env python3
"""Build an offline x64 Windows distribution from the production application."""
import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
if (HERE/'installer-source').exists():HERE=HERE/'installer-source'
PYTHON_VERSION = '3.13.16'
PYTHON_URL = f'https://www.python.org/ftp/python/{PYTHON_VERSION}/python-{PYTHON_VERSION}-embed-amd64.zip'
WINSW_URL = 'https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW.NET461.exe'
VC_URL = 'https://aka.ms/vc14/vc_redist.x64.exe'


def digest(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def download(url, path):
    if not path.exists():
        request = urllib.request.Request(url, headers={'User-Agent': 'Netory-Windows-builder'})
        with urllib.request.urlopen(request, timeout=120) as response, path.open('wb') as target:
            shutil.copyfileobj(response, target)
    return path


def build(output, cache, makensis=None, nsisdir=None):
    output=output.resolve();cache=cache.resolve()
    if output == ROOT or ROOT in output.parents or output in ROOT.parents:
        raise ValueError('Distribution output must be separate from application source')
    output.mkdir(parents=True,exist_ok=True);cache.mkdir(parents=True,exist_ok=True)
    bundle=output/'Netory-Windows-x64'
    if bundle.exists():shutil.rmtree(bundle)
    runtime=bundle/'payload'/'runtime';app=bundle/'payload'/'app'
    runtime.mkdir(parents=True);app.mkdir(parents=True)
    archive=download(PYTHON_URL,cache/f'python-{PYTHON_VERSION}-embed-amd64.zip')
    with zipfile.ZipFile(archive) as package:package.extractall(runtime)
    (runtime/'python313._pth').write_text('python313.zip\n.\nLib/site-packages\n../app\nimport site\n')
    requirements=(ROOT/'requirements.txt').read_text().replace('uvicorn[standard]', 'uvicorn')+'\ncolorama>=0.4,<1\ntzdata\n'
    req=cache/'requirements-windows.txt';req.write_text(requirements)
    wheels=cache/'wheels';wheels.mkdir(exist_ok=True)
    constraints=cache/'production-constraints.txt'
    constraints.write_text(''.join(f'{dist.metadata["Name"]}=={dist.version}\n' for dist in importlib.metadata.distributions() if dist.metadata.get('Name')))
    common=['--constraint',str(constraints),'--platform','win_amd64','--python-version','3.13','--implementation','cp','--abi','cp313','--only-binary=:all:']
    subprocess.run([sys.executable,'-m','pip','download',*common,'--dest',str(wheels),'-r',str(req)],check=True)
    subprocess.run([sys.executable,'-m','pip','install',*common,'--no-index','--find-links',str(wheels),'--no-compile','--target',str(runtime/'Lib'/'site-packages'),'-r',str(req)],check=True)
    # Shebang launchers generated on the build host are unnecessary; invoke Python modules.
    shutil.rmtree(runtime/'Lib'/'site-packages'/'bin',ignore_errors=True)
    for name in ['backend','frontend']:
        for source in (ROOT/name).rglob('*'):
            if source.is_symlink():raise ValueError(f'Symlink in application source: {source}')
            if not source.is_file() or '__pycache__' in source.parts:continue
            if source.suffix not in {'.py','.mako','.js','.json','.svg','.png','.jpg','.webp','.ico','.css','.woff','.woff2','.md','.txt'}:continue
            target=app/source.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
    for name in ['app.js','index.html','styles.css','requirements.txt']:
        shutil.copyfile(ROOT/name,app/name)
    ini=(ROOT/'alembic.ini').read_text().replace('script_location = backend/migrations','script_location = %(here)s/backend/migrations').replace('prepend_sys_path = .','prepend_sys_path = %(here)s')
    (app/'alembic.ini').write_text(ini)
    service=bundle/'payload'/'service';service.mkdir()
    winsw=download(WINSW_URL,cache/'WinSW-NET461-2.12.0.exe');shutil.copyfile(winsw,service/'Netory.exe')
    download('https://raw.githubusercontent.com/winsw/winsw/v2.12.0/LICENSE.txt',cache/'WinSW-LICENSE.txt')
    shutil.copyfile(cache/'WinSW-LICENSE.txt',service/'LICENSE.txt')
    prerequisites=bundle/'payload'/'prerequisites';prerequisites.mkdir()
    vcredist=download(VC_URL,cache/'vc_redist.x64.exe');shutil.copyfile(vcredist,prerequisites/'vc_redist.x64.exe')
    tools=bundle/'payload'/'tools';tools.mkdir();shutil.copyfile(HERE/'bootstrap.py',tools/'bootstrap.py')
    for name in ['Install.cmd','Uninstall.cmd','Setup.ps1','SetupForm.ps1','README.txt']:
        shutil.copyfile(HERE/name,bundle/name)
    installed=runtime/'Lib'/'site-packages'
    distributions=[]
    for path in sorted(installed.glob('*.dist-info/METADATA')):
        text=path.read_text();name=re.search(r'^Name: (.+)$',text,re.M).group(1);version=re.search(r'^Version: (.+)$',text,re.M).group(1);distributions.append(f'{name}=={version}')
    (bundle/'DEPENDENCIES.txt').write_text('\n'.join(sorted(distributions,key=str.lower))+'\n')
    for file in bundle.rglob('*'):
        if file.is_file() and (file.name=='.env' or file.suffix in {'.db','.sqlite','.sqlite3','.key'} or (file.suffix=='.pem' and file != installed/'certifi'/'cacert.pem')):raise ValueError(f'Forbidden private file: {file}')
    files={p.relative_to(bundle).as_posix():digest(p) for p in sorted(bundle.rglob('*')) if p.is_file()}
    manifest={'python':PYTHON_VERSION,'winsw':'2.12.0','architecture':'win_amd64','database':'SQLite (bundled with Python)','source_revision':subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip(),'source_has_uncommitted_changes':bool(subprocess.check_output(['git','-C',str(ROOT),'status','--porcelain'],text=True).strip()),'downloads':{PYTHON_URL:digest(archive),WINSW_URL:digest(winsw),VC_URL:digest(vcredist)},'files':files}
    (bundle/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    zip_path=output/'Netory-Windows-x64.zip'
    with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as package:
        for path in sorted(bundle.rglob('*')):
            if path.is_file():package.write(path,path.relative_to(output))
    artifacts=[zip_path]
    if makensis:
        executable=output/'Netory-Setup.exe'
        environment=os.environ.copy()
        if nsisdir:environment['NSISDIR']=str(nsisdir)
        subprocess.run([str(makensis),'-V2',f'-DBUNDLE_DIR={bundle}',f'-DOUTPUT_EXE={executable}',str(HERE/'setup.nsi')],check=True,env=environment)
        artifacts.append(executable)
    (output/'SHA256SUMS.txt').write_text(''.join(f'{digest(path)}  {path.name}\n' for path in artifacts))
    shutil.copyfile(HERE/'README.txt',output/'README.txt')
    shutil.copyfile(Path(__file__),output/'build.py')
    source=output/'installer-source';source.mkdir(exist_ok=True)
    for name in ['Setup.ps1','SetupForm.ps1','bootstrap.py','Install.cmd','Uninstall.cmd','setup.nsi','README.txt','Test-Installation.ps1','Test-SetupForm.ps1']:
        shutil.copyfile(HERE/name,source/name)
    if (ROOT/'docs'/'windows-installer.md').exists():shutil.copyfile(ROOT/'docs'/'windows-installer.md',output/'windows-installer.md')
    print('Windows distribution ready: '+str(output))
    for path in artifacts:print(f'{path.name}: {path.stat().st_size / 1024 / 1024:.1f} MB')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,help='Netory source checkout; required when running the copied builder outside the source repository')
    parser.add_argument('--output',type=Path,default=Path('/var/www/Netory_DIST'))
    parser.add_argument('--cache',type=Path,default=Path('/tmp/netory-windows-downloads'))
    parser.add_argument('--makensis',type=Path)
    parser.add_argument('--nsisdir',type=Path)
    args=parser.parse_args()
    if args.source:ROOT=args.source.resolve()
    if not (ROOT/'backend'/'main.py').is_file():parser.error('Specify the Netory source checkout with --source')
    build(args.output,args.cache,args.makensis,args.nsisdir)
