/* Local NUI only: strings are rendered with textContent, never HTML. */
let state,config,tab='street',noticeTimer,renderedTab,renderedGang;
const $=id=>document.getElementById(id);
for(const id of ['menuHint','settingLabel','tagline'])if($(id))$(id).textContent=L[id];
$('status').textContent=L.connecting;$('close').setAttribute('aria-label',L.closeLabel);
const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
async function post(route,data={}){try{await fetch(`https://${GetParentResourceName()}/${route}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});}catch{notice(L.requestFailed);}}
const act=(action,args={})=>post('action',{action,args});
function notice(text){$('toast').textContent=text;$('toast').style.display='block';clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>$('toast').style.display='none',6000);}
function button(parent,label,fn){const b=el('button',label);b.type='button';b.onclick=fn;parent.append(b);return b;}
function card(title,description){const n=el('article',undefined,'card');n.append(el('h2',title));if(description)n.append(el('p',description));$('content').append(n);return n;}
function input(parent,label,type='text',value=''){const n=el('input');n.type=type;n.placeholder=label;n.setAttribute('aria-label',label);n.value=value;if(type==='number'){n.min='1';n.max='1000000';}parent.append(n);return n;}
function row(parent){const n=el('div',undefined,'row');parent.append(n);return n;}
function gps(parent,group,id){button(parent,L.go,()=>post('waypoint',{group,id}));}
function itemName(k){return L[k]||k;}
function render(){
 if(!state){$('content').replaceChildren(el('p',L.notReady));return;}
 const oldInputs=[...$('content').querySelectorAll('input')];
 const sameForm=renderedTab===tab && renderedGang===Boolean(state.gang);
 const saved=sameForm?oldInputs.map(n=>n.value):[];
 const focused=oldInputs.indexOf(document.activeElement);const cursor=focused>=0?oldInputs[focused].selectionStart:null;
 const p=state.player;const jailed=p.jailUntil>state.now;const wanted=p.wantedUntil>state.now;
 $('status').textContent=`$${p.cash} · ${p.alive===false?L.dead:jailed?L.jail:wanted?L.wanted:L[p.role]}`;
 $('season').textContent=`${L.season} ${state.season} · ${L.wipe}: ${new Date(state.nextWipe*1000).toLocaleString('en-US',{timeZone:'Europe/Stockholm'})} (Stockholm)`;
 $('content').replaceChildren();$('tabs').replaceChildren();
 Object.entries(L.tabs).forEach(([id,label])=>{const b=button($('tabs'),label,()=>{tab=id;render();});b.classList.toggle('active',tab===id);});
 if(tab==='street'){
  card(L.tabs.street,L.rules);
  for(const [id,d] of Object.entries(config.robberies)){const status=state.robberies?.[id];const c=card(d.label,`${d.duration} s · ${d.reward} ${L.stolen.toLowerCase()} · ${d.police} ${L.officers}`);if(status)c.append(el('p',status.mine?`${L.progress}: ${status.progress||0} / ${d.duration} s`:`${L.cooldown}: ${Math.max(0,(status.cooldown||0)-state.now)} s`));const r=row(c);gps(r,'robberies',id);button(r,L.start,()=>act('robberyStart',{id}));button(r,L.finish,()=>act('robberyFinish',{id}));}
  let c=card(L.fencePlace);let r=row(c);const n=input(r,L.amount,'number',1);gps(r,'fence');button(r,L.fence,()=>act('fence',{amount:Number(n.value)}));
  c=card(L.shop);gps(c,'shop');for(const [item,price] of Object.entries(config.prices))button(row(c),`${L.buy} ${itemName(item)} · $${price}`,()=>act('shopBuy',{item,amount:1}));
 }
 if(tab==='gang'){
  const g=state.gang;let c=card(g?g.name:L.tabs.gang,g?`${L.bank}: $${g.bank} · ${L.score}: ${g.score} · ${L.role}: ${L[g.role]}`:L.noGang);
  if(!g){const r=row(c),name=input(r,L.name);button(r,L.create,()=>act('gangCreate',{name:name.value}));for(const inv of state.invites)button(row(c),`${L.accept}: ${inv.name}`,()=>act('gangAccept',{gang:inv.id}));}
  else{
   let r=row(c);const target=input(r,L.target,'number');button(r,L.invite,()=>act('gangInvite',{target:Number(target.value)}));button(r,L.officer,()=>act('gangRole',{target:Number(target.value),role:'officer'}));button(r,L.member,()=>act('gangRole',{target:Number(target.value),role:'member'}));button(r,L.leave,()=>act('gangLeave'));
   r=row(c);const amount=input(r,L.amount,'number',100);button(r,L.deposit,()=>act('gangDeposit',{amount:Number(amount.value)}));button(r,L.withdraw,()=>act('gangWithdraw',{amount:Number(amount.value)}));button(r,L.upgrade,()=>act('hideoutUpgrade'));
   for(const [item,n] of Object.entries(g.items||{})){const rr=row(c);rr.append(el('span',`${itemName(item)}: ${n}`));button(rr,L.take,()=>act('hideoutTake',{item,amount:1}));}
  }
  for(const [id,d] of Object.entries(config.hideouts)){const h=state.hideouts[id];c=card(d.label,h?`${h.owner} · ${L.level} ${h.level}${h.raid?' · '+L.activeRaid:''}`:`$${d.cost}`);if(h?.raid)c.append(el('p',`${L.progress}: ${h.raid.presence} / 60 s · ${L.warning}: ${Math.max(0,h.raid.startsAt-state.now)} s`));const r=row(c);gps(r,'hideouts',id);button(r,L.buy,()=>act('hideoutBuy',{id}));button(r,L.raid,()=>act('raid_start',{hideout:id}));button(r,L.raidFinish,()=>act('raid_finish',{hideout:id}));}card(L.raid,L.raidRules);
 }
 if(tab==='police'){
  let c=card(L.tabs.police,L.policeRules);let r=row(c);gps(r,'policeStation');button(r,L.duty,()=>act('police_duty'));button(r,L.vehicle,()=>act('police_vehicle'));button(r,L.returnVehicle,()=>act('police_return_vehicle'));
  r=row(c);const t=input(r,L.target,'number');button(r,L.arrest,()=>act('police_arrest',{target:Number(t.value)}));button(r,L.surrender,()=>act('surrender'));
  c=card(L.alerts);for(const a of state.alerts)c.append(el('p',a.text||a.kind));
 }
 if(tab==='inventory'){
  const c=card(L.tabs.inventory,L.inventoryRules);button(c,L.respawn,()=>act('respawn'));button(c,L.surrender,()=>act('surrender'));
  for(const [item,n] of Object.entries(p.items)){if(n<=0)continue;const r=row(c);r.append(el('span',`${itemName(item)}: ${n}`));button(r,L.store,()=>act('hideoutStore',{item,amount:1}));if(item==='medkit')button(r,L.use,()=>act('useItem',{item}));}
  for(const d of state.drops)button(row(c),`${L.loot} #${d.id}`,()=>act('loot',{drop:d.id}));
 }
 if(tab==='territory'){
  card(L.tabs.territory,L.territoryRules);for(const [id,d] of Object.entries(config.territories)){const t=state.territories[id];const c=card(d.label,`${t?.owner||L.unowned}${t?.capture?' · '+(t.capture.progress||0)+' / '+config.captureSeconds+' s'+(t.capture.contested?' · '+L.contested:''):''}`);const r=row(c);gps(r,'territories',id);button(r,L.capture,()=>act('territoryStart',{id}));}
 }
 if(tab==='ranking'){const c=card(L.tabs.ranking);const table=el('table');state.leaderboard.forEach((g,i)=>{const r=el('tr');r.append(el('td',i+1),el('td',g.name),el('td',g.score));table.append(r);});c.append(table);}
 if(tab==='gang'||tab==='police'){const c=card(L.members);for(const person of state.people)c.append(el('p',`${person.id} · ${person.name}`));}
 const inputs=[...$('content').querySelectorAll('input')];inputs.forEach((n,i)=>{if(saved[i]!==undefined)n.value=saved[i];});
 if(sameForm&&focused>=0&&inputs[focused]){inputs[focused].focus();if(cursor!==null&&inputs[focused].type==='text')inputs[focused].setSelectionRange(cursor,cursor);}
 renderedTab=tab;renderedGang=Boolean(state.gang);
}
$('close').onclick=()=>post('close');document.addEventListener('keydown',e=>{if(e.key==='Escape')post('close');});
window.addEventListener('message',e=>{const m=e.data;if(m.type==='open'){$('menu').hidden=!m.value;render();}if(m.type==='notice')notice(m.text);if(m.type==='state'){state=m.value;config=m.config;render();}});
