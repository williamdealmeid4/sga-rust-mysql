"""HTTP integration tests against an isolated disposable local database."""
import http.cookiejar,json,os,socket,subprocess,tempfile,time,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
EXE=ROOT/'target/release/sga-fbi.exe'
if not EXE.exists():EXE=ROOT/'bin/sga-fbi.exe'
class Client:
 def __init__(self,base):self.base=base;self.http=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
 def call(self,path,method='GET',body=None,expected=200):
  req=urllib.request.Request(self.base+'/api'+path,data=json.dumps(body).encode()if body is not None else None,headers={'Content-Type':'application/json'},method=method)
  try:
   with self.http.open(req,timeout=10)as r:status=r.status;value=json.load(r)
  except urllib.error.HTTPError as e:status=e.code;value=json.load(e)
  assert status==expected,(path,status,value)
  return value
 def denied(self,path,method,body):
  try:self.call(path,method,body)
  except AssertionError as e:
   assert e.args[0][1]in[400,403],e
   return
  raise AssertionError('Operation should be blocked: '+path)

if __name__ == '__main__':
 print('Use mysql_integration_test.py with the isolated MySQL test instance. This module provides the HTTP Client.')
