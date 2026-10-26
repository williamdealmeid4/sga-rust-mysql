// Offline UI regressions: no server process, MySQL connection, or database writes.
const {JSDOM} = require('jsdom');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const web = path.resolve(__dirname, '../web');
const html = fs.readFileSync(path.join(web, 'index.html'), 'utf8');
let checks = 0;
const check = (value, message) => { assert(value, message); checks++; };
const tick = () => new Promise(resolve => setImmediate(resolve));
async function boot({dark=false, reduced=false, blocked=false, saved=null, seen=false, playbackFailure=false}={}) {
  const dom = new JSDOM(html, {url:'http://localhost:3030', runScripts:'outside-only', pretendToBeVisual:true});
  const w = dom.window;
  w.matchMedia = query => ({matches: query.includes('reduced-motion') ? reduced : dark, addEventListener(){}});
  w.HTMLMediaElement.prototype.play = () => playbackFailure ? Promise.reject(Error('autoplay blocked')) : Promise.resolve();
  w.HTMLMediaElement.prototype.pause = () => {};
  w.HTMLMediaElement.prototype.load = () => {};
  w.HTMLDialogElement.prototype.close = function(){this.open=false};
  w.HTMLDialogElement.prototype.showModal = function(){this.open=true};
  w.scrollTo = () => {};
  if(saved) w.localStorage.setItem('sga-theme', saved);
  if(seen) w.sessionStorage.setItem('sga-intro-seen', '1');
  if(blocked) for(const storage of ['localStorage','sessionStorage']) Object.defineProperty(w, storage, {get(){throw Error('Storage disabled')}});
  w.fetch = async () => ({ok:false,status:401,json:async()=>({error:'Sessão expirada.'})});
  for(const script of ['theme.js','app.js']) w.eval(fs.readFileSync(path.join(web,script),'utf8') + (script==='app.js' ? '\nwindow.testUI={state,renderShell,navigate,showModal,api};' : ''));
  await tick();
  return dom;
}
(async()=>{
  let dom = await boot(); let w=dom.window, d=w.document;
  check(!d.querySelector('#intro').hidden, 'Intro appears on first visit');
  check(d.querySelector('#app').inert, 'Background cannot receive focus during intro');
  check(d.querySelector('#intro-video').muted, 'Video is muted');
  check(d.querySelector('#login-form'), 'API unavailable still displays login');
  d.querySelector('.intro-skip').click();
  check(d.querySelector('#intro').hidden && !d.querySelector('#app').inert, 'Skip restores interface');
  check(w.sessionStorage.getItem('sga-intro-seen')==='1','Intro remembered for current tab');
  d.querySelector('[data-action="toggle-theme"]').click();
  check(d.documentElement.dataset.theme==='dark','Theme toggle activates dark');
  check(w.localStorage.getItem('sga-theme')==='dark','Theme preference saved');
  check(d.querySelector('[data-action="toggle-theme"]').getAttribute('aria-pressed')==='true','Theme accessible state updated');
  w.eval("const {state,renderShell,navigate}=testUI;state.user={nome:'Teste',perfil:'Coordenador'};state.data={alunos:[{id:1,nome:'<img src=x onerror=alert(1)>',email:'teste@exemplo.edu',curso_id:1,status:'Ativo'}],cursos:[],turmas:[],matriculas:[]};renderShell();navigate('alunos');");
  check(!d.querySelector('#table-content img'),'Student markup escaped');
  check(d.querySelector('#table-content').textContent.includes('<img'), 'Student name displayed as text');
  check(d.querySelector('[data-action="toggle-theme"]').getAttribute('aria-pressed')==='true','Theme preserved in dashboard');
  check(!d.querySelector('[style]'), 'No inline style attributes');
  w.eval("testUI.showModal('Cadastro','', '<input value=confidencial>', '');");
  await w.eval("testUI.api('/data').catch(()=>{})");
  check(!d.querySelector('#modal').open && d.querySelector('#modal').textContent==='', 'Expired session clears modal');
  check(Object.keys(w.testUI.state.data).length===0, 'Expired session clears academic data');
  check(d.querySelector('#login-form'), 'Expired session returns to login');
  dom.window.close();
  for(const [options, theme] of [[{dark:true},'dark'],[{dark:true,saved:'light'},'light'],[{saved:'<script>'},'light'],[{blocked:true},'light']]) {
    dom=await boot(options);check(dom.window.document.documentElement.dataset.theme===theme, 'Validates preference and handles storage failure');dom.window.close();
  }
  for(const options of [{reduced:true},{seen:true},{playbackFailure:true}]) {
    dom=await boot(options);check(dom.window.document.querySelector('#intro').hidden, 'Reduced motion, repeated visit, or playback error bypasses intro');dom.window.close();
  }
  dom=await boot();await new Promise(resolve=>setTimeout(resolve,3100));
  check(dom.window.document.querySelector('#intro').hidden,'Intro closes automatically after 3 seconds');dom.window.close();
  console.log(`PASS: ${checks} offline frontend/security checks; no database accessed.`);
})().catch(error=>{console.error(error);process.exitCode=1});
