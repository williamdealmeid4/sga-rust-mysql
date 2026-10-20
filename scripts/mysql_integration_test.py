"""End-to-end checks against the isolated Rust/MySQL test environment only."""
from pathlib import Path
import sys,json,subprocess
sys.path.insert(0,str(Path(__file__).parent))
from smoke_test import Client
ROOT=Path(__file__).resolve().parents[1]
MYSQL=r'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
ARGS=[MYSQL,'--no-defaults','--protocol=TCP','-h127.0.0.1','-P3317','-uroot','--default-character-set=utf8mb4','-N','--batch','--raw']
def sql(query):
 r=subprocess.run(ARGS,input=query.encode(),capture_output=True);assert r.returncode==0,r.stderr.decode();return r.stdout.decode().strip()
info=json.loads((ROOT/'database/.validation_instance.json').read_text());assert Path(sql('SELECT @@datadir')).resolve()==Path(info['datadir']).resolve(),'Refusing to test outside isolated MySQL'
checks=[]
def check(ok,label):
 assert ok,label
 checks.append(label)
def same_db(kind,key,field,expected):
 table={'alunos':'aluno','cursos':'curso','disciplinas':'disciplina','professores':'professor','turmas':'turma','usuarios':'usuario','matriculas':'matricula'}[kind]
 pk='id_'+table
 actual=sql(f'SELECT {field} FROM sga_fbi.{table} WHERE {pk}={int(key)}')
 check(actual==str(expected),f'API -> MySQL: {kind}.{field}')
def record(client,kind,payload):return client.call('/records/'+kind,'POST',payload)
def update(client,kind,key,payload):return client.call('/records/'+kind+'/'+str(key),'PUT',payload)
def delete(client,kind,key):
 client.call('/records/'+kind+'/'+str(key),'DELETE');check(not any(v['id']==key for v in client.call('/data').get(kind,[])),f'Delete {kind} persisted')
base='http://127.0.0.1:3201';anon=Client(base);anon.call('/data',expected=401);check(True,'Anonymous denied');anon.call('/login','POST',{'login':'coordenador','senha':'incorreta'},401);check(True,'Invalid password denied')
c=Client(base);u=c.call('/login','POST',{'login':'coordenador','senha':'Fbi@2026'});check(u['perfil']=='Coordenador','Real Argon2 login');d=c.call('/data');check(len(d['alunos'])==20 and len(d['matriculas'])==35,'Seed visible through MySQL');check('senha_hash'not in json.dumps(d),'No password hashes in browser API')
s=Client(base);s.call('/login','POST',{'login':'secretario','senha':'Fbi@2026'});sd=s.call('/data');check('usuarios'not in sd and'auditoria'not in sd,'Secretary data filtered')
for path,method,body in[('/grades/1','POST',{'n1':10}),('/close','POST',{'semestre':'2026.1'}),('/records/cursos','POST',{'nome':'Proibido','carga_horaria':300,'turno':'Noturno'}),('/records/usuarios/1','PUT',{'perfil':'Secretario'}),('/records/matriculas/1','PUT',{'n1':10})]:s.denied(path,method,body);check(True,'Permission '+path)
a=record(s,'alunos',{'nome':'Teste Integrado','ra':'SQLAPI001','cpf':'10101010101','email':'sqlapi@exemplo.edu.br','nascimento':'2000-01-01','curso_id':1,'status':'Ativo'});same_db('alunos',a['id'],'nome','Teste Integrado');update(s,'alunos',a['id'],{'nome':'Teste Alterado'});same_db('alunos',a['id'],'nome','Teste Alterado')
course=record(c,'cursos',{'nome':'Curso Integração','carga_horaria':800,'turno':'Noturno'});same_db('cursos',course['id'],'nome','Curso Integração');update(c,'cursos',course['id'],{'carga_horaria':900});same_db('cursos',course['id'],'carga_horaria_total',900)
subject=record(c,'disciplinas',{'nome':'Disciplina Integrada','curso_id':course['id'],'carga_horaria':80,'periodo':1,'requisitos':[]});same_db('disciplinas',subject['id'],'nome','Disciplina Integrada');update(c,'disciplinas',subject['id'],{'nome':'Disciplina Alterada'});same_db('disciplinas',subject['id'],'nome','Disciplina Alterada')
subject2=record(c,'disciplinas',{'nome':'Disciplina Avançada','curso_id':course['id'],'carga_horaria':80,'periodo':2,'requisitos':[subject['id']]});check(sql(f"SELECT COUNT(*) FROM sga_fbi.pre_requisito WHERE id_disciplina={subject2['id']} AND id_disciplina_requisito={subject['id']}")=='1','Prerequisite persisted atomically')
prof=record(c,'professores',{'nome':'Professor Integrado','cpf':'20202020202','email':'profapi@exemplo.edu.br','titulacao':'Mestrado','admissao':'2020-01-01'});same_db('professores',prof['id'],'nome','Professor Integrado');update(c,'professores',prof['id'],{'titulacao':'Doutorado'});same_db('professores',prof['id'],'titulacao','Doutorado')
turma=record(c,'turmas',{'disciplina_id':subject['id'],'professor_id':prof['id'],'semestre':'2027.1','vagas':2,'total_aulas':80});same_db('turmas',turma['id'],'vagas',2);update(c,'turmas',turma['id'],{'vagas':3});same_db('turmas',turma['id'],'vagas',3)
update(s,'alunos',a['id'],{'curso_id':course['id']});m=record(s,'matriculas',{'aluno_id':a['id'],'turma_id':turma['id']});same_db('matriculas',m['id'],'id_aluno',a['id']);s.denied('/records/matriculas','POST',{'aluno_id':a['id'],'turma_id':turma['id']});check(True,'Duplicate enrollment denied')
c.denied('/grades/'+str(m['id']),'POST',{'n1':11});check(True,'Out-of-range grade denied');v=c.call('/grades/'+str(m['id']),'POST',{'n1':6,'n2':6,'exame':4,'faltas':0});check(v['situacao']=='Aprovado'and v['media_final']==5,'Grade and exam through API');same_db('matriculas',m['id'],'media_final','5.0000')
v=c.call('/grades/'+str(m['id']),'POST',{'n1':9,'n2':9,'exame':None,'faltas':21});check(v['situacao']=='Reprovado por Falta','Attendance overrides grade');same_db('matriculas',m['id'],'situacao','Reprovado por Falta');check(int(sql(f"SELECT COUNT(*) FROM sga_fbi.log_nota WHERE id_matricula={m['id']}"))>=7,'MySQL trigger audit persisted');c.denied('/records/matriculas/'+str(m['id']),'DELETE',None);check(True,'Graded history preserved')
# Create and remove an ungraded enrollment, proving real deletion in MySQL.
a2=record(s,'alunos',{'nome':'Teste Cancelamento','ra':'SQLAPI002','cpf':'30303030303','email':'sqlapi2@exemplo.edu.br','nascimento':'2000-01-01','curso_id':course['id'],'status':'Ativo'});m2=record(s,'matriculas',{'aluno_id':a2['id'],'turma_id':turma['id']});delete(s,'matriculas',m2['id']);delete(s,'alunos',a2['id'])
# Administrative CRUD without academic links.
temp_course=record(c,'cursos',{'nome':'Curso Para Excluir','carga_horaria':400,'turno':'Matutino'});delete(c,'cursos',temp_course['id']);temp_prof=record(c,'professores',{'nome':'Professor Para Excluir','cpf':'40404040404','email':'profdel@exemplo.edu.br','titulacao':'Mestrado','admissao':'2020-01-01'});delete(c,'professores',temp_prof['id']);temp_subject=record(c,'disciplinas',{'nome':'Disciplina Para Excluir','curso_id':course['id'],'carga_horaria':40,'periodo':1,'requisitos':[]});delete(c,'disciplinas',temp_subject['id']);temp_class=record(c,'turmas',{'disciplina_id':subject['id'],'professor_id':prof['id'],'semestre':'2027.2','vagas':30,'total_aulas':40});delete(c,'turmas',temp_class['id'])
usr=record(c,'usuarios',{'nome':'Usuário Integração','cpf':'50505050505','email':'userapi@exemplo.edu.br','login':'usuario_integracao','perfil':'Secretario','senha':'Senha Nova @2026 '});same_db('usuarios',usr['id'],'perfil','Secretario');uc=Client(base);uc.call('/login','POST',{'login':'usuario_integracao','senha':'Senha Nova @2026 '});check(True,'New Argon2 password preserves spaces');update(c,'usuarios',usr['id'],{'nome':'Usuário Alterado','perfil':'Coordenador'});same_db('usuarios',usr['id'],'nome','Usuário Alterado');check(uc.call('/me')['perfil']=='Coordenador','Role changes reflect in active session');update(c,'usuarios',usr['id'],{'senha':'OutraSenha@2026'});uc.call('/me',expected=401);check(True,'Password change invalidates sessions');uc.call('/login','POST',{'login':'usuario_integracao','senha':'OutraSenha@2026'});delete(c,'usuarios',usr['id']);uc.call('/me',expected=401);check(True,'Deleted user session invalidated')
c.denied('/close','POST',{'semestre':'2026.2'});check(True,'Pending semester cannot close');c.call('/close','POST',{'semestre':'2026.1'});same_db('turmas',2,'encerrada',1);c.denied('/grades/2','POST',{'n1':9});check(True,'Closed grades blocked')
s.denied('/records/matriculas','POST',{'aluno_id':20,'turma_id':4});s.denied('/records/matriculas','POST',{'aluno_id':a['id'],'turma_id':3});check(True,'Inactive/prerequisite restrictions');c.call('/logout','POST');c.call('/data',expected=401);check(True,'Database session logout')
report='PASS: '+str(len(checks))+' real Rust -> MySQL integration checks\n'+'\n'.join('PASS '+s for s in checks)+'\n';(ROOT/'database/RESULTADOS_INTEGRACAO.txt').write_text(report,encoding='utf-8');print(report)
