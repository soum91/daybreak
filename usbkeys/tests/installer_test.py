"""Run the real maintainer scripts against isolated rootless command stubs."""
import os,stat,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

class InstallerTests(unittest.TestCase):
 def run_install(self,location='usr/bin',bootstrap_fail=False,load_fail=False,no_socket=False,missing=False):
  with tempfile.TemporaryDirectory(prefix='uk-inst-') as folder:
   root=Path(folder)/'jb'; tools=root/'usr/bin'; tools.mkdir(parents=True)
   runtime=root/'var/run/usbkeys'; runtime.mkdir(parents=True)
   # A stale socket from a failed or stopped service must be replaced.
   os.mknod(runtime/'control.sock',stat.S_IFSOCK|0o600)
   log=Path(folder)/'calls'
   env=dict(os.environ,UK_TEST_LOG=str(log),UK_TEST_ROOT=str(root),UK_BOOTSTRAP_FAIL=str(int(bootstrap_fail)),UK_LOAD_FAIL=str(int(load_fail)),UK_NO_SOCKET=str(int(no_socket)))
   def executable(path,text):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text(text);path.chmod(0o755)
   # Only chown needs privileges; record its intended owner instead of changing it.
   executable(tools/'chown','#!/bin/sh\necho "chown $*" >> "$UK_TEST_LOG"\n')
   executable(tools/'sleep','#!/bin/sh\nexit 0\n')
   executable(tools/'uicache','#!/bin/sh\necho "uicache $*" >> "$UK_TEST_LOG"\n')
   if not missing:
    executable(root/location/'launchctl','''#!/usr/bin/python3
import os,sys,stat
from pathlib import Path
args=sys.argv[1:]
with open(os.environ['UK_TEST_LOG'],'a') as f:f.write('launchctl '+' '.join(args)+'\\n')
if args[0]=='bootout':sys.exit(3)
if args[0]=='bootstrap' and os.environ['UK_BOOTSTRAP_FAIL']=='1':sys.exit(5)
if args[0]=='load' and os.environ['UK_LOAD_FAIL']=='1':sys.exit(5)
if args[0] in ('bootstrap','load') and os.environ['UK_NO_SOCKET']!='1':
 p=Path(os.environ['UK_TEST_ROOT'])/'var/run/usbkeys/control.sock'
 assert not p.exists(), 'stale socket was not removed'
 os.mknod(p,stat.S_IFSOCK|0o600)
''')
   script=(ROOT/'packaging/postinst').read_text().replace('/var/jb',str(root))
   result=subprocess.run(['/bin/sh','-s','configure'],input=script,text=True,capture_output=True,env=env)
   calls=log.read_text() if log.exists() else ''
   return result,calls
 def test_rootless_usr_bin_launchctl(self):
  r,c=self.run_install();self.assertEqual(r.returncode,0,r.stderr)
  self.assertIn('bootstrap system ',c);self.assertIn('uicache -p ',c)
 def test_rootless_bin_launchctl(self):
  r,c=self.run_install(location='bin');self.assertEqual(r.returncode,0,r.stderr)
  self.assertIn('bootstrap system ',c)
 def test_load_fallback(self):
  r,c=self.run_install(bootstrap_fail=True);self.assertEqual(r.returncode,0,r.stderr)
  self.assertIn('load -w ',c)
 def test_start_failure_is_reported(self):
  r,c=self.run_install(bootstrap_fail=True,load_fail=True);self.assertNotEqual(r.returncode,0)
  self.assertIn('refused to start',r.stderr);self.assertNotIn('uicache',c)
 def test_missing_tool_is_reported(self):
  r,c=self.run_install(missing=True);self.assertNotEqual(r.returncode,0)
  self.assertIn('launchctl is missing',r.stderr)
 def test_no_socket_is_reported(self):
  r,c=self.run_install(no_socket=True);self.assertNotEqual(r.returncode,0)
  self.assertIn('control socket did not appear',r.stderr)
  self.assertIn('print system/dev.usbkeys.service',c)
 def test_removal_uses_rootless_launchctl(self):
  with tempfile.TemporaryDirectory(prefix='uk-remove-') as folder:
   root=Path(folder)/'jb'; tools=root/'usr/bin';tools.mkdir(parents=True)
   tool=tools/'launchctl'; tool.write_text('#!/bin/sh\nprintf "%s\\n" "$*"\n');tool.chmod(0o755)
   script=(ROOT/'packaging/prerm').read_text().replace('/var/jb',str(root))
   r=subprocess.run(['/bin/sh','-s','upgrade'],input=script,text=True,capture_output=True)
   self.assertEqual(r.returncode,0);self.assertIn('bootout system/dev.usbkeys.service',r.stdout)

if __name__=='__main__':unittest.main(verbosity=2)
