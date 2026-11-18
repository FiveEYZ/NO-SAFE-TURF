/* Local NUI only: strings are rendered with textContent, never HTML. */
let uiMode='menu',menuTab='street';
let state,config,tab='street',noticeTimer,renderedTab,renderedGang;
const $=id=>document.getElementById(id==='content'&&uiMode==='inventory'?'inventoryContent':id);
for(const id of ['menuHint','settingLabel','tagline'])if($(id))$(id).textContent=L[id];
$('inventoryTitle').textContent=L.inventoryTitle;$('inventoryHelp').textContent=L.inventoryHelp;$('inventoryClose').setAttribute('aria-label',L.closeLabel);
$('status').textContent=L.connecting;$('close').setAttribute('aria-label',L.closeLabel);
const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
async function post(route,data={}){try{await fetch(`https://${GetParentResourceName()}/${route}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});}catch{notice(L.requestFailed);}}
const act=(action,args={})=>post('action',{action,args});
function notice(text){$('toast').textContent=text;$('toast').style.display='block';clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>$('toast').style.display='none',6000);}
function button(parent,label,fn){const b=el('button',label);b.type='button';b.onclick=fn;parent.append(b);return b;}
function card(title,description,parent=$('content')){const n=el('article',undefined,'card');n.append(el('h2',title));if(description)n.append(el('p',description));parent.append(n);return n;}
function input(parent,label,type='text',value=''){const n=el('input');n.type=type;n.placeholder=label;n.setAttribute('aria-label',label);n.value=value;if(type==='number'){n.min='1';n.max='1000000';}parent.append(n);return n;}
function row(parent){const n=el('div',undefined,'row');parent.append(n);return n;}
function gps(parent,group,id){button(parent,L.go,()=>post('waypoint',{group,id}));}
function itemName(k){return state?.inventory?.catalog?.[k]?.label||L[k]||k;}
function render(){
 if(!state){$('content').replaceChildren(el('p',L.notReady));return;}
 const oldInputs=[...$('content').querySelectorAll('input')];
 const sameForm=renderedTab===tab && renderedGang===Boolean(state.gang);
 const saved=sameForm?oldInputs.map(n=>n.value):[];
 const keyed=new Map(oldInputs.filter(n=>n.nstKey).map(n=>[n.nstKey,n.value]));
 const focusKey=document.activeElement?.nstKey;
 const focused=oldInputs.indexOf(document.activeElement);const cursor=focused>=0?oldInputs[focused].selectionStart:null;
 $('menu').classList.toggle('tetrisMenu',tab==='inventory'&&Boolean(state.inventory?.grid));
 const p=state.player;const jailed=p.jailUntil>state.now;const wanted=p.wantedUntil>state.now;
 $('status').textContent=`$${p.cash} · ${p.alive===false?L.dead:jailed?L.jail:wanted?L.wanted:L[p.role]}`;
 $('season').textContent=`${L.season} ${state.season} · ${L.wipe}: ${new Date(state.nextWipe*1000).toLocaleString('en-US',{timeZone:'Europe/Stockholm'})} (Stockholm)`;
 $('content').replaceChildren();$('tabs').replaceChildren();
 Object.entries(L.tabs).filter(([id])=>id!=='inventory').forEach(([id,label])=>{const b=button($('tabs'),label,()=>{tab=id;menuTab=id;render();});b.classList.toggle('active',tab===id);});
 if(tab==='street'){
  card(L.tabs.street,L.rules);
  for(const [id,d] of Object.entries(config.robberies)){const status=state.robberies?.[id];const c=card(d.label,`${d.duration} s · ${d.reward} ${L.stolen.toLowerCase()} · ${d.police} ${L.officers}`);if(status)c.append(el('p',status.mine?`${L.progress}: ${status.progress||0} / ${d.duration} s`:`${L.cooldown}: ${Math.max(0,(status.cooldown||0)-state.now)} s`));const r=row(c);gps(r,'robberies',id);button(r,L.start,()=>act('robberyStart',{id}));button(r,L.finish,()=>act('robberyFinish',{id}));}
  let c=card(L.fencePlace);let r=row(c);const n=input(r,L.amount,'number',1);gps(r,'fence');button(r,L.fence,()=>act('fence',{amount:Number(n.value)}));
  c=card(L.shop);gps(c,'shop');for(const [item,def] of Object.entries(state.inventory?.catalog||{}))if(def.price){const r=row(c),n=input(r,L.amount,'number',def.kind==='ammo'?30:1);button(r,`${L.buy} ${def.label} · ${def.price}`,()=>act('shopBuy',{item,amount:Number(n.value)}));}for(const [item,bag] of Object.entries(state.inventory?.bags||{}))button(row(c),`${L.buy} ${itemName(item)} · ${bag.price} · ${bag.capacity/1000} kg`,()=>act('bagBuy',{item}));for(const [item,price] of Object.entries(config.prices))button(row(c),`${L.buy} ${itemName(item)} · $${price}`,()=>act('shopBuy',{item,amount:1}));
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
 if(tab==='inventory'&&state.inventory?.grid){renderGridInventory(p,state.inventory);}
 else if(tab==='inventory'){
  const inv=state.inventory||{weight:0,capacity:8000,bags:{}};
  const head=card(L.carrying,L.carryRules);
  head.append(el('div',`${(inv.weight/1000).toFixed(2)} / ${inv.capacity/1000} kg · ${L.equipped}: ${itemName(inv.bag||'pockets')}`,'stat'));
  const meter=el('progress');meter.max=inv.capacity;meter.value=inv.weight;meter.setAttribute('aria-label',L.carrying);head.append(meter);
  if(inv.bag)button(head,L.unequip,()=>act('bagEquip',{item:'none'}));
  const columns=el('div',undefined,'inventoryColumns');$('content').append(columns);
  const carried=card(L.tabs.inventory,L.inventoryRules,columns),ground=card(L.nearbyLoot,L.openNearby,columns);
  function transfer(parent,item,n,action,extra={}){
   const entry=el('div',undefined,'itemEntry');parent.append(entry);
   entry.append(el('strong',item==='cash'?`${L.cash}: $${n}`:`${itemName(item)} × ${n}`));
   const r=row(entry),quantity=input(r,L.amount,'number',1);quantity.max=String(Math.min(n,1000000));quantity.nstKey=action+':'+(extra.drop||'carried')+':'+item;
   button(r,action==='loot'?L.collect:L.drop,()=>act(action,{...extra,item,amount:Number(quantity.value)}));
   if(action==='inventoryDrop'&&item!=='cash'){
    button(r,L.store,()=>act('hideoutStore',{item,amount:Number(quantity.value)}));
    if(inv.bags[item])button(r,L.equip,()=>act('bagEquip',{item}));
    if(item==='medkit')button(r,L.use,()=>act('useItem',{item}));
   }
  }
  if(p.cash>0)transfer(carried,'cash',p.cash,'inventoryDrop');
  for(const [item,n] of Object.entries(p.items))if(n>0)transfer(carried,item,n,'inventoryDrop');
  for(const d of state.drops){
   const box=el('div',undefined,'lootContainer');ground.append(box);box.append(el('h3',`${L.nearbyLoot} #${d.id}`));
   if(!d.canOpen){box.append(el('p',L.lootLocked));continue;}
   if(p.role==='police'){button(box,L.loot,()=>act('loot',{drop:d.id}));continue;}
   if(d.cash>0)transfer(box,'cash',d.cash,'loot',{drop:d.id});
   for(const [item,n] of Object.entries(d.items||{}))if(n>0)transfer(box,item,n,'loot',{drop:d.id});
  }
  button(carried,L.respawn,()=>act('respawn'));button(carried,L.surrender,()=>act('surrender'));
 }
 if(tab==='territory'){
  card(L.tabs.territory,L.territoryRules);for(const [id,d] of Object.entries(config.territories)){const t=state.territories[id];const c=card(d.label,`${t?.owner||L.unowned}${t?.capture?' · '+(t.capture.progress||0)+' / '+config.captureSeconds+' s'+(t.capture.contested?' · '+L.contested:''):''}`);const r=row(c);gps(r,'territories',id);button(r,L.capture,()=>act('territoryStart',{id}));}
 }
 if(tab==='ranking'){const c=card(L.tabs.ranking);const table=el('table');state.leaderboard.forEach((g,i)=>{const r=el('tr');r.append(el('td',i+1),el('td',g.name),el('td',g.score));table.append(r);});c.append(table);}
 if(tab==='gang'||tab==='police'){const c=card(L.members);for(const person of state.people)c.append(el('p',`${person.id} · ${person.name}`));}
 const inputs=[...$('content').querySelectorAll('input')];inputs.forEach((n,i)=>{if(n.nstKey){if(sameForm&&keyed.has(n.nstKey))n.value=keyed.get(n.nstKey);}else if(saved[i]!==undefined)n.value=saved[i];});
 const focusTarget=focusKey?inputs.find(n=>n.nstKey===focusKey):inputs[focused];
 if(sameForm&&focused>=0&&focusTarget){focusTarget.focus();if(cursor!==null&&focusTarget.type==='text')focusTarget.setSelectionRange(cursor,cursor);}
 renderedTab=tab;renderedGang=Boolean(state.gang);
}
$('close').onclick=()=>post('close');$('inventoryClose').onclick=()=>post('close');document.addEventListener('keydown',e=>{if(e.key==='Escape'||(e.key==='Tab'&&uiMode==='inventory'&&!e.repeat)){e.preventDefault?.();post('close');}if((e.key==='r'||e.key==='R')&&gridSelection&&document.activeElement?.tagName!=='INPUT'){e.preventDefault();rotateGridSelection();}});
window.addEventListener('message',e=>{const m=e.data;if(m.type==='open'){$('hud').hidden=m.value;if(!m.value){gridDragging=false;gridSelection=null;}if(m.value){uiMode=m.mode==='inventory'?'inventory':'menu';tab=uiMode==='inventory'?'inventory':menuTab;}
$('menu').hidden=!m.value||uiMode!=='menu';$('inventoryWindow').hidden=!m.value||uiMode!=='inventory';render();}if(m.type==='notice')notice(m.text);if(m.type==='state'){state=m.value;config=m.config;if(!gridDragging)render();}});
// Tetris inventory. The server owns placements; the browser only previews requests.
let gridSelection=null,gridDragging=false,gridGrab={x:0,y:0};
function inventoryIcon(item){
 const paths={
  cash:'M5 16h54v32H5z M12 22h40v20H12z M32 24a8 8 0 1 0 0 16a8 8 0 1 0 0-16',
  pistol:'M7 17h43v13H33v8H22l-5 19H7l7-29H7z M37 20h19v7H37z',
  rifle:'M4 23h15v8H4z M19 21h28v13H19z M47 24h15v5H47z M25 34h9l-2 17h-8z M40 13h9v8h-9z',
  ammo:'M14 13l5-8l5 8v40H14z M34 21l5-8l5 8v32H34z M10 54h18 M30 54h18',
  stolen_watch:'M25 3h14v15H25z M25 46h14v15H25z M32 17a15 15 0 1 0 0 30a15 15 0 1 0 0-30 M32 23v10l7 4',
  stolen_phone:'M19 5h26v54H19z M24 12h16v35H24z M30 53h4',
  stolen_laptop:'M10 9h44v34H10z M5 49h54l-5 6H10z M16 15h32v22H16z',
  stolen_tv:'M3 10h58v38H3z M26 48v8 M38 48v8 M18 57h28',
  stolen_art:'M7 6h50v52H7z M13 12h38v40H13z M16 45l12-18l8 11l6-7l7 14 M40 18h1',
  stolen_tools:'M5 22h54v29H5z M22 22v-9h20v9 M17 22v29 M47 22v29 M27 32h10v7H27z',
  medkit:'M8 14h48v42H8z M23 14V7h18v7 M27 24h10v8h8v10h-8v8H27v-8h-8V32h8z',
  bat:'M15 56l29-47q7-7 10 0L23 59z',
  lockpick:'M15 55l18-40h20v7H38L21 58z',
  bag:'M15 17q0-10 17-10t17 10v39H15z M21 31h22v19H21z M24 7V3h16v4',
  box:'M8 16l24-9l24 9v35l-24 9l-24-9z M8 16l24 10l24-10 M32 26v34'
 };
 const key=item.startsWith('ammo_')?'ammo':item.startsWith('bag_')?'bag':item;
 const svg='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><path d="'+(paths[key]||paths.box)+'" fill="#b8b9a7" fill-opacity=".18" stroke="#d8dacb" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';
 const icon=el('img');icon.src='data:image/svg+xml,'+encodeURIComponent(svg);icon.alt='';icon.draggable=false;return icon;
}
function selectGridEntry(entry,source,revision){
 gridSelection={...entry,source,revision};render();
}
function renderGridInventory(p,inv){
 const catalog=inv.catalog||{};const grid=inv.grid;
 if(gridSelection){const source=gridSelection.source;let valid;
  if(source==='carried')valid=grid.entries.find(e=>e.id===gridSelection.id&&e.item===gridSelection.item);
  else {const d=state.drops.find(d=>d.id===source&&d.canOpen);valid=d&&((gridSelection.item==='cash'?d.cash:d.items?.[gridSelection.item])>=gridSelection.amount);}
  if(!valid)gridSelection=null;
 }
 const layout=el('div',undefined,'tetrisLayout');$('content').append(layout);
 const ground=el('article',undefined,'tetrisPanel');layout.append(ground);
 const carried=el('article',undefined,'tetrisPanel');layout.append(carried);
 const equipment=el('article',undefined,'tetrisPanel equipmentPanel');layout.append(equipment);
 function title(panel,name,meta){const h=el('div',undefined,'gridHeading');h.append(el('h2',name),el('span',meta));panel.append(h);}
 function itemTile(e,source,revision){
  const def=catalog[e.item]||{};const tile=el('button',undefined,'gridItem rarity-'+(def.rarity||'common'));tile.type='button';tile.draggable=true;
  tile.style.gridColumn=(e.x+1)+' / span '+e.w;tile.style.gridRow=(e.y+1)+' / span '+e.h;
  const label=def.label||itemName(e.item);tile.title=label+' · '+e.w+'×'+e.h+' · '+(def.rarity||'common');tile.setAttribute('aria-label',tile.title);
  const icon=inventoryIcon(e.item);if(e.rotated)icon.style.transform='rotate(90deg)';
  tile.append(icon,el('span',label,'gridItemName'),el('b',e.item==='cash'?'$'+e.amount:e.amount>1?String(e.amount):'','gridQuantity'));
  if(gridSelection?.id===e.id&&gridSelection.source===source)tile.classList.add('selected');
  tile.onclick=()=>selectGridEntry(e,source,revision);
  tile.ondragstart=event=>{
   const selected=gridSelection?.id===e.id&&gridSelection.source===source?gridSelection:{...e,source,revision};
   const rect=tile.getBoundingClientRect();
   gridGrab=selected.rotated===e.rotated?{x:Math.max(0,Math.min(e.w-1,Math.floor((event.clientX-rect.left)/rect.width*e.w))),y:Math.max(0,Math.min(e.h-1,Math.floor((event.clientY-rect.top)/rect.height*e.h)))}:{x:0,y:0};
   gridDragging=true;gridSelection=selected;event.dataTransfer.setData('text/plain',e.id);event.dataTransfer.effectAllowed='move';
  };
  tile.ondragend=()=>{gridDragging=false;gridGrab={x:0,y:0};render();};
  return tile;
 }
 function buildGrid(panel,cols,rows,entries,source,revision){
  const scroller=el('div',undefined,'gridScroll');const board=el('div',undefined,'inventoryGrid');scroller.append(board);panel.append(scroller);
  board.style.setProperty('--cols',cols);board.style.setProperty('--rows',rows);
  for(let y=0;y<rows;y++)for(let x=0;x<cols;x++){const cell=el('div',undefined,'gridCell');cell.style.gridColumn=x+1;cell.style.gridRow=y+1;board.append(cell);}
  entries.filter(e=>!e.overflow).forEach(e=>board.append(itemTile(e,source,revision)));
  if(source!=='carried')return;
  const ghost=el('div',undefined,'gridGhost');ghost.hidden=true;board.append(ghost);
  function target(event){const rect=board.getBoundingClientRect();return {x:Math.floor((event.clientX-rect.left)/(rect.width/cols))-(gridDragging?gridGrab.x:0),y:Math.floor((event.clientY-rect.top)/(rect.height/rows))-(gridDragging?gridGrab.y:0)};}
  function preview(event){
   if(!gridSelection)return null;
   const at=target(event),e=gridSelection;
   const valid=at.x>=0&&at.y>=0&&at.x+e.w<=cols&&at.y+e.h<=rows&&!entries.some(other=>!other.overflow&&!(e.source==='carried'&&other.id===e.id)&&at.x<other.x+other.w&&at.x+e.w>other.x&&at.y<other.y+other.h&&at.y+e.h>other.y);
   ghost.hidden=false;ghost.classList.toggle('invalid',!valid);ghost.style.gridColumn=(Math.max(0,at.x)+1)+' / span '+e.w;ghost.style.gridRow=(Math.max(0,at.y)+1)+' / span '+e.h;
   if(at.x+e.w>cols||at.y+e.h>rows)ghost.hidden=true;
   return valid?at:null;
  }
  function place(event){const at=preview(event);if(!at)return;if(gridSelection.source==='carried')act('inventoryMove',{entry:gridSelection.id,x:at.x,y:at.y,rotated:gridSelection.rotated,revision:gridSelection.revision});else act('loot',{drop:gridSelection.source,item:gridSelection.item,amount:gridSelection.amount,x:at.x,y:at.y,rotated:gridSelection.rotated,revision:gridSelection.revision});gridSelection=null;ghost.hidden=true;}
  board.onpointermove=preview;board.onpointerleave=()=>{ghost.hidden=true;};
  board.ondragover=event=>{event.preventDefault();preview(event);};board.ondrop=event=>{event.preventDefault();place(event);};
  board.onclick=event=>{if(event.target.classList?.contains('gridCell'))place(event);};
 }
 title(ground,L.nearbyLoot,L.gridTransferHint);
 const nearby=state.drops.filter(d=>d.canOpen);
 ground.hidden=nearby.length===0;
 for(const d of nearby){
  const label=el('div',undefined,'containerHeading');label.append(el('span',L.loot+' #'+d.id),el('span',Math.max(0,Math.ceil(((d.expiresAt||state.now)-state.now)/60))+' min'));ground.append(label);
  if(p.role==='police'){button(ground,L.loot,()=>act('loot',{drop:d.id}));continue;}
  const entries=[];const counts={...d.items,cash:d.cash||0};const cols=6;let x=0,y=0,rowHeight=1;
  for(const item of Object.keys(counts).sort()){
   const def=catalog[item]||{w:1,h:1,stack:1};let n=counts[item],i=0;
   while(n>0&&entries.length<100){const amount=Math.min(n,def.stack);if(x+def.w>cols){y+=rowHeight;x=0;rowHeight=1;}
    entries.push({id:item+':'+(++i),item,amount,x,y,w:def.w,h:def.h,rotated:0});x+=def.w;rowHeight=Math.max(rowHeight,def.h);n-=amount;
   }
  }
  buildGrid(ground,cols,Math.max(4,y+rowHeight),entries,d.id,grid.revision);
 }
 title(carried,itemName(inv.bag||'pockets'),(inv.weight/1000).toFixed(2)+' / '+inv.capacity/1000+' kg');
 buildGrid(carried,grid.cols,grid.rows,grid.entries,'carried',grid.revision);
 carried.append(el('p',L.gridInstructions,'gridHelp'));
 if(grid.overflow){const recovery=el('div',undefined,'gridOverflow');carried.append(recovery);recovery.append(el('strong',L.gridOverflow));
  for(const e of grid.entries.filter(e=>e.overflow))button(recovery,(catalog[e.item]?.label||e.item)+' × '+e.amount,()=>selectGridEntry(e,'carried',grid.revision));
  // Very large legacy stacks remain accessible even when presentation is capped.
  for(const [item,n] of Object.entries({...p.items,cash:p.cash}))if(n>0)button(recovery,L.drop+' '+(catalog[item]?.label||item),()=>act('inventoryDrop',{item,amount:Math.min(n,1000000)}));
 }
 title(equipment,L.equipment,L.gridEquipmentHint);
 for(const item of ['rifle','pistol']){const slot=el('div',undefined,'equipmentSlot');equipment.append(slot);slot.append(inventoryIcon(item),el('strong',catalog[item]?.label||itemName(item)));
  if(p.items[item]>0){button(slot,p.equippedWeapon===item?L.holster:L.equip,()=>act('weaponEquip',{item:p.equippedWeapon===item?'none':item}));const ammo=catalog[item]?.ammo;slot.append(el('small',(catalog[ammo]?.label||ammo)+' · '+(p.items[ammo]||0)));}else slot.classList.add('emptySlot');
 }
 const bagSlot=el('div',undefined,'equipmentSlot bagSlot');equipment.append(bagSlot);bagSlot.append(inventoryIcon(inv.bag||'bag_small'),el('strong',itemName(inv.bag||'pockets')));if(inv.bag)button(bagSlot,L.unequip,()=>act('bagEquip',{item:'none'}));
 const selected=gridSelection;
 if(selected){const def=catalog[selected.item]||{};const detail=el('div',undefined,'selectionDetails');equipment.append(detail);detail.append(el('h3',def.label||itemName(selected.item)),el('span',(def.rarity||'common').toUpperCase()+' · '+selected.w+'×'+selected.h,'rarityLabel rarity-'+(def.rarity||'common')));
  if(def.value)detail.append(el('p',L.baseValue+': $'+Math.floor(def.value*(config.fencePrice||75))));
  const quantity=input(detail,L.amount,'number',selected.amount);quantity.max=String(Math.min(selected.amount,1000000));quantity.nstKey='grid:'+selected.source+':'+selected.id;
  button(detail,L.rotate,()=>rotateGridSelection());
  if(selected.source==='carried'){button(detail,L.drop,()=>act('inventoryDrop',{item:selected.item,amount:Number(quantity.value)}));
   if(selected.item!=='cash')button(detail,L.store,()=>act('hideoutStore',{item:selected.item,amount:Number(quantity.value)}));
   if(def.kind==='bag')button(detail,L.equip,()=>act('bagEquip',{item:selected.item}));
   if(def.weapon)button(detail,L.equip,()=>act('weaponEquip',{item:selected.item}));
   if(selected.item==='medkit')button(detail,L.use,()=>act('useItem',{item:selected.item}));
   if(def.kind==='loot')button(detail,L.fence,()=>act('fence',{item:selected.item,amount:Number(quantity.value)}));
  }else button(detail,L.collect,()=>act('loot',{drop:selected.source,item:selected.item,amount:Number(quantity.value)}));
 }else equipment.append(el('p',L.selectItem));
 button(equipment,L.respawn,()=>act('respawn'));button(equipment,L.surrender,()=>act('surrender'));
}
function rotateGridSelection(){if(!gridSelection)return;const e=gridSelection;e.rotated=1-e.rotated;[e.w,e.h]=[e.h,e.w];render();}

