import hashlib,os,pathlib,shutil,subprocess,tempfile,tarfile
scripts=pathlib.Path(__file__).resolve().parents[1] / 'modules/client_update'
for platform in ('linux','macos'):
 if platform == 'macos' and not shutil.which('ditto'):
  print('macos: pulado (ditto indisponível)'); continue
 if platform == 'linux' and not shutil.which('sha256sum'):
  print('linux: pulado (sha256sum indisponível)'); continue
 with tempfile.TemporaryDirectory() as temp:
  root=pathlib.Path(temp); bin=root/'bin';bin.mkdir()
  (bin/'open').write_text('#!/bin/sh\nexit 0\n');(bin/'open').chmod(0o755)
  env=os.environ.copy();env['PATH']=str(bin)+':'+env['PATH']
  target=root/('Zealot Client.app' if platform=='macos' else 'installed')
  old=target/'Contents/Resources' if platform=='macos' else target
  for kind in ('things','sounds'):
   d=old/'data'/kind/'1511';d.mkdir(parents=True);(d/'preserved.dat').write_text(kind)
  (old/'data/things/9999').mkdir(parents=True);(old/'data/things/9999/old.dat').write_text('old')
  package=root/'package';new=package/('Zealot Client.app' if platform=='macos' else 'zealot-client')
  runtime=new/'Contents/Resources' if platform=='macos' else new
  (runtime/'data/things/9999').mkdir(parents=True);(runtime/'data/things/9999/new.dat').write_text('new')
  (runtime/'init.lua').write_text('new');(runtime/'modules').mkdir()
  exe=new/'Contents/MacOS/Zealot Client' if platform=='macos' else new/'zealot-client';exe.parent.mkdir(parents=True,exist_ok=True);exe.write_text('#!/bin/sh\nexit 0\n');exe.chmod(0o755)
  (new/'run-zealot-client.sh').write_text('#!/bin/sh\nexit 0\n');(new/'run-zealot-client.sh').chmod(0o755)
  archive=root/('client.zip' if platform=='macos' else 'client.tar.gz')
  if platform=='macos': subprocess.run(['ditto','-c','-k','--keepParent',str(new),str(archive)],check=True)
  else:
   with tarfile.open(archive,'w:gz') as t:t.add(new,arcname=new.name)
  digest=hashlib.sha256(archive.read_bytes()).hexdigest()
  subprocess.run(['/bin/sh',str(scripts/('apply-'+platform+'.sh')),'999999',str(archive),str(old),digest],check=True,env=env)
  assert (old/'data/things/1511/preserved.dat').read_text()=='things'
  assert (old/'data/sounds/1511/preserved.dat').read_text()=='sounds'
  assert not (old/'data/things/1520').exists()
  assert (old/'data/things/9999/new.dat').exists() and not (old/'data/things/9999/old.dat').exists()
  assert list(root.glob(target.name+'.previous.*'))
  print(platform,'dados preservados, versão do pacote respeitada e backup mantido')
