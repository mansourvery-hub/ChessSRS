(function(){
'use strict';
const $ = (s,r=document)=>r.querySelector(s);
const $$ = (s,r=document)=>Array.from(r.querySelectorAll(s));
const FILES='abcdefgh';
const root=document.documentElement;
const app=$('#app'), frame=$('#frame');

/* ---------------- state ---------------- */
const S={
  theme:'light', sound:false, step:0, phase:'prompt', due:2, filled:false, practice:false,
  scope:'Scandinavian Defense', selected:null, sheet:null, accent:'ultramarine'
};
const ACCENTS=[
  {id:'ultramarine',name:'Ultramarine',l:'#2A3FD9',d:'#8A9BFF'},
  {id:'violet',name:'Violet',l:'#6B3FD4',d:'#B7A0FF'},
  {id:'verdigris',name:'Verdigris',l:'#0B7A83',d:'#5FCBD3'},
  {id:'ochre',name:'Ochre',l:'#9A5500',d:'#F2B04D'}
];

/* ---------------- data ---------------- */
const START_POS={
  w:{a1:'R',b1:'N',c1:'B',d1:'Q',e1:'K',f1:'B',g1:'N',h1:'R',a2:'P',b2:'P',c2:'P',d2:'P',f2:'P',g2:'P',h2:'P'},
  b:{a8:'R',b8:'N',c8:'B',e8:'K',f8:'B',g8:'N',h8:'R',d5:'Q',a7:'P',b7:'P',c7:'P',e7:'P',f7:'P',g7:'P',h7:'P'}
};
const FULL_START={
  w:{a1:'R',b1:'N',c1:'B',d1:'Q',e1:'K',f1:'B',g1:'N',h1:'R',a2:'P',b2:'P',c2:'P',d2:'P',e2:'P',f2:'P',g2:'P',h2:'P'},
  b:{a8:'R',b8:'N',c8:'B',d8:'Q',e8:'K',f8:'B',g8:'N',h8:'R',a7:'P',b7:'P',c7:'P',d7:'P',e7:'P',f7:'P',g7:'P',h7:'P'}
};
const DECISIONS=[
  {from:'b1',to:'c3',san:'Nc3',history:['e4','d5','exd5','Qxd5'],
   note:'Nc3 hits the queen at once, so Black has to spend another move on it. Qa5 is the main line; Qd6 and Qd8 are also playable. Each retreat asks for a different plan, which is why all three are worth knowing.',
   reply:{from:'d5',to:'a5'}},
  {from:'d2',to:'d4',san:'d4',history:['e4','d5','exd5','Qxd5','Nc3','Qa5'],note:null}
];
const SCOPES=[
  {group:'Everywhere',items:[{name:'All repertoires',pos:457,due:100,mem:[120,140,197]}]},
  {group:'Openings',items:[
    {name:'Scandinavian Defense',pos:38,dueKey:true,mem:[14,10,14]},
    {name:'French Defense',pos:156,due:61,mem:[30,44,82]},
    {name:'White vs [French]',pos:74,due:12,mem:[28,20,26]},
    {name:'Rat Defense',pos:41,due:9,mem:[8,12,21]},
    {name:'Pirc Defense',pos:52,due:8,mem:[10,14,28]},
    {name:"Petrov's Defense",pos:66,due:8,mem:[20,22,24]}
  ]},
  {group:'Repertoires',items:[
    {name:"MansourMohamed's Study, test",pos:440,due:83,mem:[102,138,200]},
    {name:'sample_study',pos:17,due:17,mem:[17,0,0],paused:true}
  ]}
];

/* ---------------- sound (synthesised placeholders) ---------------- */
let actx=null;
function ensureAudio(){
  if(!actx){const C=window.AudioContext||window.webkitAudioContext; if(C) actx=new C();}
  if(actx&&actx.state==='suspended') actx.resume();
}
function knock(t,gain,freq){
  const n=Math.floor(actx.sampleRate*.06), buf=actx.createBuffer(1,n,actx.sampleRate), d=buf.getChannelData(0);
  for(let i=0;i<n;i++) d[i]=(Math.random()*2-1)*Math.pow(1-i/n,3);
  const src=actx.createBufferSource(); src.buffer=buf;
  const f=actx.createBiquadFilter(); f.type='lowpass'; f.frequency.value=900;
  const g=actx.createGain(); g.gain.setValueAtTime(gain,t); g.gain.exponentialRampToValueAtTime(.001,t+.06);
  src.connect(f); f.connect(g); g.connect(actx.destination); src.start(t);
  const o=actx.createOscillator(); o.type='sine'; o.frequency.setValueAtTime(freq,t); o.frequency.exponentialRampToValueAtTime(freq*.55,t+.05);
  const og=actx.createGain(); og.gain.setValueAtTime(gain*.5,t); og.gain.exponentialRampToValueAtTime(.001,t+.07);
  o.connect(og); og.connect(actx.destination); o.start(t); o.stop(t+.08);
}
function note(t,freq,gain,len){
  const o=actx.createOscillator(); o.type='sine'; o.frequency.value=freq;
  const g=actx.createGain(); g.gain.setValueAtTime(.0001,t); g.gain.exponentialRampToValueAtTime(gain,t+.02); g.gain.exponentialRampToValueAtTime(.0001,t+len);
  o.connect(g); g.connect(actx.destination); o.start(t); o.stop(t+len+.02);
}
function sound(kind){
  if(!S.sound||!actx) return; const t=actx.currentTime;
  if(kind==='move') knock(t,.32,190);
  if(kind==='wrong'){ knock(t,.2,150); knock(t+.11,.16,120); }
  if(kind==='done'){ note(t,392,.09,.5); note(t+.16,523.25,.08,.7); }
}

/* ---------------- helpers ---------------- */
const fig=k=>`<svg class="fig" viewBox="14 6 72 84" aria-hidden="true"><use href="#g${k}"/></svg>`;
const san2html=s=>('KQRBN'.includes(s[0])?fig(s[0])+s.slice(1):s);
function mkPiece(color,type){
  const d=document.createElement('div'); d.className='pc-wrap'; d.dataset.c=color; d.dataset.t=type;
  d.innerHTML=`<svg class="pc ${color}" viewBox="5 2 90 90" aria-hidden="true"><use href="#g${type}" class="halo"/><use href="#g${type}" class="line"/><use href="#g${type}" class="fill"/><use href="#d${type}" class="det"/></svg>`;
  return d;
}
const sqXY=sq=>({f:FILES.indexOf(sq[0]),row:8-parseInt(sq[1],10)});
let toastT=null;
function toast(msg){const t=$('#toast'); t.textContent=msg; t.classList.add('show'); clearTimeout(toastT); toastT=setTimeout(()=>t.classList.remove('show'),2400);}
const say=m=>{$('#live').textContent=m;};

/* ---------------- board factory ---------------- */
let boardSeq=0;
function createBoard(host,{interactive}){
  const id=++boardSeq;
  let dark='';
  for(let f=0;f<8;f++)for(let r=0;r<8;r++) if((f+r)%2===1) dark+=`M${f*10} ${r*10}h10v10h-10z`;
  const ranks=[8,7,6,5,4,3,2,1].map(n=>`<span>${n}</span>`).join('');
  const files=[...FILES].map(c=>`<span>${c}</span>`).join('');
  let inside='';
  for(let f=0;f<8;f++) inside+=`<span class="cf" style="left:${f*12.5}%;top:87.5%">${FILES[f]}</span>`;
  for(let r=0;r<8;r++) inside+=`<span class="cr" style="left:0;top:${r*12.5}%">${8-r}</span>`;
  host.innerHTML=`<div class="board-wrap">
    <div class="coords-r" aria-hidden="true">${ranks}</div>
    <div class="board${interactive?' live':''}" role="${interactive?'application':'img'}" aria-label="Chessboard">
      <svg class="bg" viewBox="0 0 80 80" preserveAspectRatio="none" aria-hidden="true">
        <defs><pattern id="hatch${id}" patternUnits="userSpaceOnUse" width=".9" height=".9" patternTransform="rotate(45)"><rect width=".1" height=".9"/></pattern></defs>
        <rect class="sq-l" width="80" height="80"/>
        <path class="sq-d" d="${dark}"/>
        <path d="${dark}" fill="url(#hatch${id})"/>
        <g class="hl"></g>
      </svg>
      <div class="pieces"></div>
      <svg class="arrow-layer" viewBox="0 0 80 80" aria-hidden="true"></svg>
      <div class="coords-in" aria-hidden="true">${inside}</div>
    </div>
    <div class="coords-f" aria-hidden="true">${files}</div>
  </div>`;
  const boardEl=$('.board',host), piecesEl=$('.pieces',host), hl=$('.hl',host), arrowSvg=$('.arrow-layer',host);
  const pat=$('pattern',host), patRect=$('pattern rect',host);
  const pieces=new Map(); let last=null, sel=null;

  const fit=()=>{
    const px=boardEl.clientWidth; if(!px) return;
    const u=80/px, gap=Math.max(4.6,Math.min(7,px/100))*u;
    pat.setAttribute('width',gap); pat.setAttribute('height',gap);
    patRect.setAttribute('width',1.1*u); patRect.setAttribute('height',gap);
  };
  new ResizeObserver(fit).observe(boardEl); fit();

  const place=(el,sq)=>{const {f,row}=sqXY(sq); el.style.transform=`translate(${f*100}%,${row*100}%)`; el.dataset.sq=sq;};
  const rect=sq=>{const {f,row}=sqXY(sq); return `<rect x="${f*10}" y="${row*10}" width="10" height="10"`;};
  function drawHL(){
    let h='';
    if(last) h+=`${rect(last[0])} class="last"/>${rect(last[1])} class="last"/>`;
    if(sel) h+=`${rect(sel)} class="sel"/>`;
    hl.innerHTML=h;
  }
  const api={
    el:boardEl,pieces,
    setPosition(pos){
      piecesEl.innerHTML=''; pieces.clear(); last=null; sel=null;
      for(const c of ['w','b']) for(const [sq,t] of Object.entries(pos[c])){
        const el=mkPiece(c,t); place(el,sq); piecesEl.appendChild(el); pieces.set(sq,el);
      }
      drawHL(); api.clearArrow();
    },
    move(from,to,{instant=false}={}){
      const el=pieces.get(from); if(!el) return;
      const cap=pieces.get(to); if(cap&&cap!==el) cap.remove();
      pieces.delete(from); pieces.set(to,el);
      if(instant){el.style.transition='none'; place(el,to); void el.offsetWidth; el.style.transition='';} else place(el,to);
      last=[from,to]; drawHL();
    },
    select(sq){sel=sq; drawHL();},
    clearArrow(){arrowSvg.innerHTML='';},
    showArrow(from,to){
      const a=sqXY(from), b=sqXY(to);
      const x1=a.f*10+5,y1=a.row*10+5,x2=b.f*10+5,y2=b.row*10+5;
      const dx=x2-x1,dy=y2-y1,len=Math.hypot(dx,dy),nx=-dy/len,ny=dx/len,bow=len*.13;
      const cx=(x1+x2)/2+nx*bow, cy=(y1+y2)/2+ny*bow;
      let tx=x2-cx,ty=y2-cy; const tl=Math.hypot(tx,ty); tx/=tl; ty/=tl;
      const tipX=x2-tx*.9,tipY=y2-ty*.9,head=3.3,hb=1.8;
      const bx=tipX-tx*head,by=tipY-ty*head;
      const p1=[bx-ty*hb,by+tx*hb],p2=[bx+ty*hb,by-tx*hb];
      arrowSvg.innerHTML=`<path class="arr" pathLength="1" d="M${x1} ${y1}Q${cx} ${cy} ${bx} ${by}"/><path class="arr-head" d="M${tipX} ${tipY}L${p1[0]} ${p1[1]}L${p2[0]} ${p2[1]}Z"/>`;
    },
    sqAt(e){
      const r=boardEl.getBoundingClientRect();
      const f=Math.floor((e.clientX-r.left)/r.width*8), row=Math.floor((e.clientY-r.top)/r.height*8);
      if(f<0||f>7||row<0||row>7) return null; return FILES[f]+(8-row);
    },
    place
  };
  return api;
}

/* ---------------- main board + interaction ---------------- */
const board=createBoard($('#boardHost'),{interactive:true});
const firstBoard=createBoard($('#firstBoardHost'),{interactive:false});
firstBoard.setPosition(FULL_START);

let drag=null;
board.el.addEventListener('pointerdown',e=>{
  if(S.phase==='note'){ continueFlow(); return; }
  if(S.phase!=='prompt'&&S.phase!=='correction') return;
  ensureAudio();
  const sq=board.sqAt(e); if(!sq) return;
  const el=board.pieces.get(sq), own=el&&el.dataset.c==='w';
  if(S.selected&&sq!==S.selected&&!own){ attempt(S.selected,sq); return; }
  if(own){
    S.selected=sq; board.select(sq);
    drag={sq,el,x:e.clientX,y:e.clientY,moved:false};
    board.el.setPointerCapture(e.pointerId);
  } else { S.selected=null; board.select(null); }
});
board.el.addEventListener('pointermove',e=>{
  if(!drag) return;
  if(!drag.moved&&Math.hypot(e.clientX-drag.x,e.clientY-drag.y)>5){drag.moved=true; drag.el.classList.add('drag');}
  if(drag.moved){
    const r=board.el.getBoundingClientRect(), s=r.width/8;
    drag.el.style.transform=`translate(${e.clientX-r.left-s/2}px,${e.clientY-r.top-s/2}px)`;
  }
});
function endDrag(e,cancel){
  if(!drag) return; const d=drag; drag=null;
  if(!d.moved) return;
  d.el.classList.remove('drag');
  const to=cancel?null:board.sqAt(e);
  if(to&&to!==d.sq) attempt(d.sq,to); else { board.place(d.el,d.sq); }
}
board.el.addEventListener('pointerup',e=>endDrag(e,false));
board.el.addEventListener('pointercancel',e=>endDrag(e,true));

function attempt(from,to){
  S.selected=null; board.select(null);
  const d=DECISIONS[S.step];
  if(from===d.from&&to===d.to){ board.move(from,to); onCorrect(); }
  else {
    const el=board.pieces.get(from); if(el) board.place(el,from);
    onWrong();
  }
}

/* ---------------- flow ---------------- */
function lineHTML(){
  const d=DECISIONS[S.step]; let h='';
  for(let i=0;i<d.history.length;i+=2){
    h+=`<span class="pair"><span class="num">${i/2+1}.</span><span class="mv">${san2html(d.history[i])}</span><span class="mv">${san2html(d.history[i+1])}</span></span> `;
  }
  h+=`<span class="pair"><span class="num">${d.history.length/2+1}.</span>`;
  h+=S.filled?`<span class="mv fill">${san2html(d.san)}</span>`:`<span class="blank"></span>`;
  h+=`</span>`;
  return h;
}
function renderSide(){
  const d=DECISIONS[S.step], ph=S.phase;
  app.dataset.phase=ph;
  $('#line').innerHTML=lineHTML();
  $('#answer').hidden=ph!=='correction';
  $('#ansMove').innerHTML=san2html(d.san);
  $('#note').hidden=!(ph==='note'&&d.note);
  $('#noteText').textContent=d.note||'';
  $('#contBtn').hidden=ph!=='note';
  $('#skipBtn').hidden=ph==='note'||ph==='quiet';
  const due=$('#due');
  if(S.practice){ due.className='due practice'; due.textContent='Practice'; }
  else { due.className='due'; due.innerHTML=`<b id="dueN">${S.due}</b> due`; }
}
function setPhase(p){ S.phase=p; renderSide(); }
function onCorrect(){
  const d=DECISIONS[S.step];
  S.filled=true; if(!S.practice) S.due=Math.max(0,S.due-1);
  board.clearArrow(); sound('move');
  say(`Correct. ${d.san}.`);
  if(d.note){ setPhase('note'); }
  else { setPhase('quiet'); setTimeout(afterQuiet,560); }
}
function afterQuiet(){
  if(S.phase!=='quiet') return;
  if(S.due===0&&!S.practice){ sound('done'); setScreen('idle'); }
  else { setPhase('prompt'); }
}
function onWrong(){
  const d=DECISIONS[S.step];
  sound('wrong'); board.showArrow(d.from,d.to);
  say(`Not this move. The repertoire move is ${d.san}.`);
  setPhase('correction');
}
function continueFlow(){
  if(S.phase!=='note') return;
  const d=DECISIONS[S.step];
  if(d.reply){ board.move(d.reply.from,d.reply.to); sound('move'); }
  S.step=Math.min(S.step+1,DECISIONS.length-1); S.filled=false;
  setPhase('prompt');
}
function skip(){
  if(S.phase==='prompt'){ onWrong(); return; }
  if(S.phase==='correction'){
    const d=DECISIONS[S.step]; board.move(d.from,d.to); onCorrect();
  }
}
function resetReview(){
  S.step=0; S.phase='prompt'; S.due=2; S.filled=false; S.selected=null; S.practice=false;
  board.setPosition(START_POS); renderSide();
  S.scope='Scandinavian Defense'; $('#scopeName').textContent=S.scope;
}

/* ---------------- screens ---------------- */
function setScreen(name){ app.dataset.screen=name; if(name==='review') renderSide(); }
function closeSheets(){
  S.sheet=null; $('#scrim').classList.remove('open');
  $('#sheetScope').classList.remove('open'); $('#sheetLib').classList.remove('open');
  $('#scopeBtn').setAttribute('aria-expanded','false');
}
function openSheet(kind){
  closeSheets(); S.sheet=kind; $('#scrim').classList.add('open');
  if(kind==='scope'){ $('#sheetScope').classList.add('open'); $('#scopeBtn').setAttribute('aria-expanded','true'); buildScope(''); $('#scopeSearch').value=''; if(matchMedia('(hover:hover)').matches) setTimeout(()=>$('#scopeSearch').focus(),60); }
  else $('#sheetLib').classList.add('open');
}
$('#scrim').addEventListener('click',closeSheets);
$('#scopeBtn').addEventListener('click',()=>S.sheet==='scope'?closeSheets():openSheet('scope'));
$('#moreBtn').addEventListener('click',()=>S.sheet==='lib'?closeSheets():openSheet('lib'));
$('#skipBtn').addEventListener('click',()=>{ensureAudio();skip();});
$('#contBtn').addEventListener('click',()=>{ensureAudio();continueFlow();});
$('#practiceBtn').addEventListener('click',()=>{resetReview(); S.practice=true; setScreen('review'); syncGo('prompt');});
$('#chooseBtn').addEventListener('click',()=>openSheet('scope'));
$('#backBtn').addEventListener('click',()=>{setScreen('review'); syncGo('prompt');});
$('#importBtn').addEventListener('click',()=>{resetReview(); setScreen('review'); syncGo('prompt'); toast('Imported 38 positions from Scandinavian.pgn');});
$$('[data-toast]').forEach(b=>b.addEventListener('click',()=>toast(b.dataset.toast)));
$$('[data-lib]').forEach(b=>b.addEventListener('click',()=>{
  const k=b.dataset.lib; closeSheets();
  if(k==='import'){ setScreen('first'); syncGo('first'); }
  else if(k==='settings'){ setScreen('settings'); syncGo('settings'); }
  else toast(`${b.dataset.msg} is shown as a placeholder in this prototype.`);
}));

/* scope list */
function memBar(m){ return `<span class="mem"><i class="m-ret" style="flex:${m[0]||0}"></i><i class="m-lrn" style="flex:${m[1]||0}"></i><i class="m-new" style="flex:${m[2]||0}"></i></span>`; }
function buildScope(q){
  q=q.trim().toLowerCase(); let html='', any=false;
  for(const g of SCOPES){
    const items=g.items.filter(i=>!q||i.name.toLowerCase().includes(q)); if(!items.length) continue; any=true;
    html+=`<div class="group-title">${g.group}</div>`;
    for(const i of items){
      const due=i.dueKey?S.due:i.due, cur=S.scope===i.name;
      html+=`<button class="row${i.paused?' paused':''}${due===0?' zero':''}" data-name="${i.name.replace(/"/g,'&quot;')}" data-due="${due}" ${cur?'aria-current="true"':''}>
        <span class="row-main"><span class="row-name">${i.name}</span><span class="row-sub">${memBar(i.mem)}<span>${i.paused?'Paused':i.pos+' positions'}</span></span></span>
        <span class="row-due"><b>${due}</b><i>due</i></span></button>`;
    }
  }
  $('#scopeList').innerHTML=any?html:`<div class="empty">Nothing matches “${q.replace(/</g,'&lt;')}”.</div>`;
}
$('#scopeSearch').addEventListener('input',e=>buildScope(e.target.value));
$('#scopeList').addEventListener('click',e=>{
  const r=e.target.closest('.row'); if(!r) return;
  S.scope=r.dataset.name; $('#scopeName').textContent=S.scope;
  if(r.dataset.name!=='Scandinavian Defense'){ S.due=+r.dataset.due; }
  else if(S.due===0) S.due=2;
  S.practice=false; renderSide(); closeSheets();
  if(app.dataset.screen!=='review') { setScreen('review'); syncGo('prompt'); }
});

/* keyboard */
document.addEventListener('keydown',e=>{
  if(e.target.matches('input,textarea')){ if(e.key==='Escape') closeSheets(); return; }
  if(e.key==='Escape'){ closeSheets(); return; }
  if(app.dataset.screen==='review'&&!S.sheet){
    if(e.key===' '||e.key==='Enter'){ if(S.phase==='note'){e.preventDefault(); ensureAudio(); continueFlow();} }
    if(e.key==='s'||e.key==='S'){ ensureAudio(); skip(); }
  }
  if(app.dataset.screen==='idle'&&(e.key==='p'||e.key==='P')) $('#practiceBtn').click();
});

/* ---------------- settings interactions ---------------- */
$$('.seg[data-seg]').forEach(seg=>{
  seg.addEventListener('click',e=>{
    const b=e.target.closest('button'); if(!b) return;
    if(b.dataset.theme){ setTheme(b.dataset.theme); return; }
    $$('button',seg).forEach(x=>x.setAttribute('aria-pressed',x===b?'true':'false'));
  });
});
$$('.tog').forEach(t=>t.addEventListener('click',()=>{
  const on=t.getAttribute('aria-checked')!=='true'; t.setAttribute('aria-checked',on);
  if(t.id==='soundTog') setSound(on);
}));

/* ---------------- page toolbar ---------------- */
function pressed(group,pred){ $$('button',group).forEach(b=>b.setAttribute('aria-pressed',pred(b)?'true':'false')); }
function syncGo(name){ pressed($('#ctl-screen'),b=>b.dataset.go===name); }
function setTheme(t){
  S.theme=t; root.dataset.theme=t;
  pressed($('#ctl-theme'),b=>b.dataset.theme===t);
  $$('.seg[data-seg="theme"] button').forEach(b=>b.setAttribute('aria-pressed',b.dataset.theme===t?'true':'false'));
  buildSwatches(); syncAccents();
}
function lumi(h){h=h.replace('#','');const c=[0,2,4].map(i=>parseInt(h.slice(i,i+2),16)/255).map(v=>v<=.03928?v/12.92:Math.pow((v+.055)/1.055,2.4));return .2126*c[0]+.7152*c[1]+.0722*c[2];}
function contrast(a,b){let x=lumi(a),y=lumi(b);if(x<y)[x,y]=[y,x];return ((x+.05)/(y+.05)).toFixed(1);}
function syncAccents(){
  const dark=root.dataset.theme==='dark';
  $$('.accents').forEach(g=>{
    if(!g.children.length) g.innerHTML=ACCENTS.map(a=>`<button class="dotbtn" data-accent="${a.id}" aria-label="${a.name}" title="${a.name}"></button>`).join('');
    $$('.dotbtn',g).forEach(b=>{const a=ACCENTS.find(x=>x.id===b.dataset.accent); b.style.setProperty('--c',dark?a.d:a.l); b.setAttribute('aria-pressed',a.id===S.accent?'true':'false');});
  });
  buildAccentSpec();
}
function setAccent(id){ S.accent=id; root.dataset.accent=id; syncAccents(); buildSwatches(); }
function buildAccentSpec(){
  $('#accentSpec').innerHTML=ACCENTS.map(a=>`<button class="acc-card" data-accent="${a.id}" aria-pressed="${a.id===S.accent}"><span class="acc-chips"><i style="background:${a.l}"></i><i style="background:${a.d}"></i></span><b>${a.name}</b><span>Light ${a.l}, ${contrast(a.l,'#F1F3F4')}:1</span><span>Dark ${a.d}, ${contrast(a.d,'#0D0F13')}:1</span></button>`).join('');
}
document.addEventListener('click',e=>{const b=e.target.closest('[data-accent]'); if(b&&(b.classList.contains('dotbtn')||b.classList.contains('acc-card'))) setAccent(b.dataset.accent);});
function setSound(on){
  S.sound=on; if(on) ensureAudio();
  pressed($('#ctl-sound'),b=>(b.dataset.sound==='on')===on);
  $('#soundTog').setAttribute('aria-checked',on);
  if(on) sound('move');
}
function setDevice(d){
  frame.dataset.device=d; frame.style.width=''; frame.style.height='';
  pressed($('#ctl-device'),b=>b.dataset.device===d);
  $('#hint').innerHTML = d==='fluid'
    ? '<b>Drag the bottom-right corner of the frame</b> to resize it. The layout reflows between the phone and desktop arrangements.'
    : '<b>Try it.</b> Play 3.&nbsp;Nc3 by dragging the knight from b1 to c3, or tap it and tap the square. Any other move shows the correction. Space continues, S skips.';
}
function go(name){
  closeSheets();
  if(name==='idle'){ resetReview(); S.due=0; renderSide(); setScreen('idle'); }
  else if(name==='first'){ setScreen('first'); }
  else if(name==='settings'){ setScreen('settings'); }
  else {
    resetReview(); setScreen('review');
    if(name==='correction'){ onWrong(); }
    if(name==='note'){ const d=DECISIONS[0]; board.move(d.from,d.to,{instant:true}); S.filled=true; S.due=1; setPhase('note'); }
    if(name==='scope'){ openSheet('scope'); }
    if(name==='library'){ openSheet('lib'); }
  }
  syncGo(name);
}
$$('#ctl-screen button').forEach(b=>b.addEventListener('click',()=>go(b.dataset.go)));
$$('#ctl-device button').forEach(b=>b.addEventListener('click',()=>setDevice(b.dataset.device)));
$$('#ctl-theme button').forEach(b=>b.addEventListener('click',()=>setTheme(b.dataset.theme)));
$$('#ctl-sound button').forEach(b=>b.addEventListener('click',()=>setSound(b.dataset.sound==='on')));

/* ---------------- specimen ---------------- */
(function pieceSpec(){
  const host=$('#pieceSpec'); const order=['K','Q','R','B','N','P'];
  ['w','b'].forEach((c,ci)=>order.forEach((t,i)=>{
    const cell=document.createElement('div'); cell.className='cell'+((i+ci)%2===1?' d':'');
    const p=mkPiece(c,t); p.style.transform='none'; cell.appendChild(p); host.appendChild(cell);
  }));
  $('#sanSpec').innerHTML=`<span class="num">1.</span><span class="mv">e4</span><span class="mv">c5</span><span class="num">2.</span><span class="mv">${fig('N')}f3</span><span class="mv">d6</span><span class="num">3.</span><span class="mv">d4</span><span class="mv">cxd4</span><span class="num">4.</span><span class="mv">${fig('N')}xd4</span><span class="mv">${fig('N')}f6</span>`;
})();
function buildSwatches(){
  const cs=getComputedStyle(root);
  const items=[['Ground','--bg'],['Raised surface','--surface'],['Ink','--ink'],['Ink, secondary','--ink2'],['Ink, quiet','--ink3'],['Accent','--accent'],['Board, paper square','--sq-l'],['Board, hatched square','--sq-d']];
  $('#swatches').innerHTML=items.map(([n,v])=>`<div class="sw-card"><div class="sw-chip" style="background:var(${v})"></div><b>${n}</b><span>${cs.getPropertyValue(v).trim().toUpperCase()}</span></div>`).join('');
}

/* ---------------- init ---------------- */
root.dataset.accent=S.accent;
if(matchMedia('(prefers-color-scheme:dark)').matches){ setTheme('dark'); } else { setTheme('light'); }
resetReview();
})();
