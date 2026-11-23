// Offline workflow checks with API responses; no production records are changed.
const {JSDOM}=require('jsdom');const fs=require('fs');const assert=require('assert/strict');
const root=require('path').resolve(__dirname,'..');
const tick=()=>new Promise(r=>setImmediate(r));
(async()=>{
const dom=new JSDOM(fs.readFileSync(root+'/web/index.html','utf8'),{url:'http://localhost:3030',runScripts:'outside-only',pretendToBeVisual:true});
const w=dom.window,d=w.document;const q=s=>d.querySelector(s);let students=0,enrollments=0,failStudent=true,failEnrollment=true;
const user={id:1,nome:'Secretário Teste',perfil:'Secretario'};
const data={alunos:[],cursos:[{id:1,nome:'Curso Teste'}],disciplinas:[{id:1,nome:'Disciplina Teste',curso_id:1,requisitos:[]}],turmas:[{id:1,disciplina_id:1,semestre:'2026.2',vagas:30,total_aulas:80,encerrada:false}],matriculas:[]};
w.matchMedia=()=>({matches:false,addEventListener(){}});w.sessionStorage.setItem('sga-intro-seen','1');w.scrollTo=()=>{};
w.HTMLDialogElement.prototype.showModal=function(){this.open=true};w.HTMLDialogElement.prototype.close=function(){this.open=false};
w.fetch=async(url,opt={})=>{
let value,ok=true;const body=opt.body?JSON.parse(opt.body):{};
if(url==='/api/me')value=user;else if(url==='/api/data')value=data;
else if(url==='/api/records/alunos'){students++;if(failStudent){failStudent=false;ok=false;value={error:'CPF já cadastrado.'}}else{value={...body,id:10};data.alunos.push(value)}}
else if(url==='/api/records/matriculas'){enrollments++;if(failEnrollment){failEnrollment=false;ok=false;value={error:'Turma sem vagas.'}}else{value={...body,id:11,situacao:'Cursando'};data.matriculas.push(value)}}
else throw Error('Unexpected API '+url);
return {ok,status:ok?200:400,json:async()=>structuredClone(value)};
};
for(const f of ['theme.js','app.js'])w.eval(fs.readFileSync(root+'/web/'+f,'utf8'));
for(let i=0;i<5;i++)await tick();
const click=s=>{assert(q(s),'Missing '+s);q(s).click()};
const set=(key,v)=>{q('[name="'+key+'"]').value=v;q('[name="'+key+'"]').dispatchEvent(new w.Event('input',{bubbles:true}))};
const submit=async()=>{q('#record-form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));for(let i=0;i<8;i++)await tick()};
const sun=q('.theme-toggle path').getAttribute('d');click('.theme-toggle');const moon=q('.theme-toggle path').getAttribute('d');assert.notEqual(sun,moon);assert.equal(d.documentElement.dataset.theme,'dark');click('.theme-toggle');assert.equal(q('.theme-toggle path').getAttribute('d'),sun);
assert(!q('#app').textContent.includes('Bom ter voc?'));
click('[data-action="new-enrollment"]');click('[data-action="enrollment-new-student"]');
assert(q('#modal-title').textContent.includes('para matrícula'));
for(const[k,v]of Object.entries({nome:'Aluno Novo',ra:'NOVO01',cpf:'12345678901',email:'novo@exemplo.edu',nascimento:'2000-01-01',curso_id:'1',status:'Ativo'}))set(k,v);
assert(q('#student-age').textContent.includes('anos'));assert(q('#record-form').checkValidity());
await submit();assert(q('#modal').open);assert(q('#form-error').textContent.includes('CPF'));assert.equal(q('[name="nome"]').value,'Aluno Novo');assert.equal(enrollments,0);
await submit();assert.equal(q('[name="aluno_id"]').value,'10');assert(q('.notice').textContent.includes('Aluno cadastrado'));assert.equal(students,2);
set('turma_id','1');await submit();assert(q('#form-error').textContent.includes('sem vagas'));assert.equal(q('[name="aluno_id"]').value,'10');assert.equal(students,2);
await submit();assert(!q('#modal').open);assert.equal(students,2);assert.equal(enrollments,2);assert.equal(data.alunos.length,1);assert.equal(data.matriculas[0].aluno_id,10);
console.log('PASS: enrollment workflow, student validation, age, preselected new student, enrollment retry without duplicate student, secretary access, sun/moon and objective homepage.');dom.window.close();
})().catch(e=>{console.error(e);process.exitCode=1});
