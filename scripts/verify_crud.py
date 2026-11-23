"""Rebuild disposable MySQL on 3317 and verify CRUD without touching MySQL80."""
from pathlib import Path
import os,json,subprocess,tempfile,time,secrets,sys,runpy
ROOT=Path(__file__).resolve().parents[1]
BIN=Path(r'C:\Program Files\MySQL\MySQL Server 8.0\bin')
args=[str(BIN/'mysql.exe'),'--no-defaults','--protocol=TCP','-h127.0.0.1','-P3317','-uroot','--default-character-set=utf8mb4','-N','--batch','--raw']
def sql(q):
 r=subprocess.run(args,input=q.encode('utf-8'),capture_output=True);assert r.returncode==0,r.stderr.decode(errors='replace');return r.stdout.decode('utf-8').strip()
import socket
with socket.socket() as sock:
 assert sock.connect_ex(('127.0.0.1',3317))!=0,'Port 3317 occupied; refusing to replace an existing instance'
datadir=Path(tempfile.mkdtemp(prefix='sga-crud-'))
subprocess.run([str(BIN/'mysqld.exe'),'--no-defaults','--initialize-insecure','--basedir='+str(BIN.parent),'--datadir='+str(datadir)],check=True,capture_output=True)
log=(datadir/'server.log').open('wb');db=subprocess.Popen([str(BIN/'mysqld.exe'),'--no-defaults','--basedir='+str(BIN.parent),'--datadir='+str(datadir),'--port=3317','--bind-address=127.0.0.1','--mysqlx=0'],stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
app=None;applog=None
try:
 for _ in range(120):
  try:
   if sql('SELECT 1')=='1':break
  except AssertionError:time.sleep(.5)
 else:raise RuntimeError('Temporary MySQL did not start')
 assert Path(sql('SELECT @@datadir')).resolve()==datadir.resolve()
 (ROOT/'database/.validation_instance.json').write_text(json.dumps({'datadir':str(datadir),'pid':db.pid,'port':3317}))
 sql((ROOT/'database/sga_fbi_completo.sql').read_text(encoding='utf-8'))
 password=secrets.token_hex(20)
 sql("CREATE USER 'sga_crud'@'localhost' IDENTIFIED BY '"+password+"' REQUIRE SSL;GRANT 'sga_fbi_aplicacao' TO 'sga_crud'@'localhost';SET DEFAULT ROLE 'sga_fbi_aplicacao' TO 'sga_crud'@'localhost';")
 env=os.environ.copy();env.update(DATABASE_URL='mysql://sga_crud:'+password+'@127.0.0.1:3317/sga_fbi',SGA_PORT='3201')
 applog=(datadir/'app.log').open('wb');app=subprocess.Popen([str(ROOT/'target/release/sga-fbi.exe')],cwd=ROOT,env=env,stdout=applog,stderr=applog,creationflags=subprocess.CREATE_NO_WINDOW)
 sys.path.insert(0,str(ROOT/'scripts'));from smoke_test import Client
 for _ in range(100):
  try:Client('http://127.0.0.1:3201').call('/me',expected=401);break
  except Exception:time.sleep(.2)
 else:raise RuntimeError('Test application did not start')
 runpy.run_path(str(ROOT/'scripts/mysql_integration_test.py'),run_name='__main__')
 c=Client('http://127.0.0.1:3201');c.call('/login','POST',{'login':'coordenador','senha':'Fbi@2026'})
 def create(k,p):return c.call('/records/'+k,'POST',p)
 def update(k,i,p):return c.call('/records/'+k+'/'+str(i),'PUT',p)
 def delete(k,i):return c.call('/records/'+k+'/'+str(i),'DELETE')
 course=create('cursos',{'nome':'CRUD completo','carga_horaria':800,'turno':'Noturno'})
 subject=create('disciplinas',{'nome':'CRUD disciplina','curso_id':course['id'],'carga_horaria':80,'periodo':1,'requisitos':[]})
 prof=create('professores',{'nome':'CRUD Professor','cpf':'60606060606','email':'crudprof@exemplo.edu','titulacao':'Mestrado','admissao':'2020-01-01'})
 student=create('alunos',{'nome':'CRUD Aluno','cpf':'70707070707','ra':'CRUD2026','email':'crud@exemplo.edu','nascimento':'2000-01-01','curso_id':course['id'],'status':'Ativo'})
 t1=create('turmas',{'disciplina_id':subject['id'],'professor_id':prof['id'],'semestre':'2028.1','vagas':30,'total_aulas':80})
 t2=create('turmas',{'disciplina_id':subject['id'],'professor_id':prof['id'],'semestre':'2028.2','vagas':30,'total_aulas':80})
 m=create('matriculas',{'aluno_id':student['id'],'turma_id':t1['id']});c.denied('/records/matriculas/'+str(m['id']),'PUT',{'aluno_id':student['id'],'turma_id':t2['id']})
 assert sql('SELECT id_turma FROM sga_fbi.matricula WHERE id_matricula='+str(m['id']))==str(t1['id'])
 charge=create('financeiro',{'aluno_id':student['id'],'descricao':'CRUD cobrança','valor':150.25,'vencimento':'2028-02-10','status':'Pendente','pagamento':''})
 assert any(x['id']==charge['id'] for x in c.call('/data')['financeiro'])
 update('financeiro',charge['id'],{'valor':175.5,'descricao':'CRUD cobrança alterada'})
 assert sql('SELECT valor FROM sga_fbi.cobranca WHERE id_cobranca='+str(charge['id']))=='175.50'
 delete('financeiro',charge['id']);assert sql('SELECT COUNT(*) FROM sga_fbi.cobranca WHERE id_cobranca='+str(charge['id']))=='0'
 delete('matriculas',m['id']);delete('alunos',student['id']);delete('turmas',t1['id']);delete('turmas',t2['id']);delete('disciplinas',subject['id']);delete('professores',prof['id']);delete('cursos',course['id'])
 inventory=sql("SELECT ROUTINE_TYPE,COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='sga_fbi' GROUP BY ROUTINE_TYPE;SELECT 'TRIGGERS',COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='sga_fbi';SELECT 'VIEWS',COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA='sga_fbi';")
 report='PASS: CRUD de alunos, cursos, disciplinas, professores, turmas, usuários e cobranças via API Rust e MySQL isolado.\nPASS: matrícula sem notas: criação, leitura e exclusão; troca de aluno/turma bloqueada pela regra vigente. Notas e frequência alteradas pelos testes de integração.\nPASS: criação, leitura, alteração e exclusão de cobrança pendente.\n'+inventory+'\n'
 (ROOT/'database/RESULTADOS_CRUD_ATUAL.txt').write_text(report,encoding='utf-8');print(report)
finally:
 if app:app.terminate();app.wait(timeout=15)
 if applog:applog.close()
 assert Path(sql('SELECT @@datadir')).resolve()==datadir.resolve()
 subprocess.run([str(BIN/'mysqladmin.exe'),'--no-defaults','--protocol=TCP','-h127.0.0.1','-P3317','-uroot','shutdown'],check=True,capture_output=True)
 db.wait(timeout=30);log.close()
 print('Temporary MySQL stopped. Production MySQL80 and its records were not modified.')
