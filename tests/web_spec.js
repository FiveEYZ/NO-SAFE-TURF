'use strict';
// Logic/DOM-contract tests only. This is not Chromium/NUI rendering or accessibility QA.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const calls = [], events = {}, documentEvents = {}, nodes = {};
let document;
class Element {
  constructor(tag) { this.tagName=tag.toUpperCase(); this.children=[]; this.style={setProperty(k,v){this[k]=v;}}; this.value=''; this.selectionStart=null; this.attributes={}; this._text=''; this.classList={toggle(){},add(){},contains(){return false;}}; }
  set textContent(value) { this._text=String(value); this.children=[]; }
  get textContent() { return this._text+this.children.map(n=>n.textContent).join(''); }
  set innerHTML(_) { throw Error('Unsafe HTML sink used'); }
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children=children; this._text=''; }
  setAttribute(k,v) { this.attributes[k]=v; }
  querySelectorAll(tag) { return this.children.flatMap(n=>[...(n.tagName===tag.toUpperCase()?[n]:[]),...n.querySelectorAll(tag)]); }
  focus() { document.activeElement=this; }
  setSelectionRange(start,end) { this.selectionStart=start; this.selectionEnd=end; }
}
document={activeElement:null,getElementById(id){return nodes[id] ||= new Element('div');},createElement(tag){return new Element(tag);},addEventListener(name,fn){documentEvents[name]=fn;}};
const sandbox={document,console,GetParentResourceName:()=> 'no_safe_turf',fetch:async(url,options)=>{calls.push({url,data:JSON.parse(options.body)});return {};},setTimeout:()=>1,clearTimeout(){}};
sandbox.window=sandbox;sandbox.addEventListener=(name,fn)=>{events[name]=fn;};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync('resource/web/locale.js','utf8'),sandbox,{filename:'locale.js'});
vm.runInContext(fs.readFileSync('resource/web/app.js','utf8'),sandbox,{filename:'app.js'});
const L=sandbox.L;
const fixture={player:{cash:500,alive:true,role:'criminal',items:{stolen:6,bat:1,medkit:1},wantedUntil:0,jailUntil:0},gang:null,invites:[],people:[{id:2,name:'<img src=x onerror=evil()>'}],drops:[{id:'1'}],alerts:[{text:'<script>evil()</script>'}],territories:{davis:{owner:'Concrete',capture:{progress:50}}},hideouts:{davis:{owner:'Concrete',level:2,raid:{startsAt:1060,presence:10}}},leaderboard:[{name:'<img onerror=evil()>',score:33}],season:1,nextWipe:1800000000,now:1000,robberies:{shop:{mine:true,progress:12,cooldown:1600}}};
const config={robberies:{shop:{label:'Store robbery',duration:45,reward:6,police:0},depot:{label:'Depot robbery',duration:100,reward:16,police:1}},prices:{bat:250,medkit:120,lockpick:90},hideouts:{davis:{label:'Davis',cost:900}},territories:{davis:{label:'Davis'}},captureSeconds:180};
let activeMode='menu';const content=()=>nodes[activeMode==='inventory'?'inventoryContent':'content'];
const message=m=>{if(m.type==='open'&&m.value)activeMode=m.mode==='inventory'?'inventory':'menu';return events.message({data:m});};
const snapshot=()=>message({type:'state',value:fixture,config});
const button=(root,label)=>{const b=(root==='content'?content():nodes[root]).querySelectorAll('button').find(n=>n.textContent===label);assert(b,`Missing button: ${label}`);return b;};
const click=(root,label)=>button(root,label).onclick();
const switchTab=key=>{if(key==='inventory')return message({type:'open',value:true,mode:'inventory'});if(activeMode==='inventory')message({type:'open',value:true,mode:'menu'});return click('tabs',L.tabs[key]);};
const last=()=>calls.at(-1).data;
const input=label=>content().querySelectorAll('input').find(n=>n.attributes['aria-label']===label);

async function run(){
  message({type:'open',value:true}); assert(content().textContent.includes(L.notReady));
  snapshot(); assert(nodes.status.textContent.includes('$500'));assert(nodes.season.textContent.includes('Stockholm'));
  assert(content().textContent.includes('12 / 45 s'));
  await click('content',L.start); assert.deepEqual(last(),{action:'robberyStart',args:{id:'shop'}});
  input(L.amount).value='4'; await click('content',L.fence);assert.deepEqual(last(),{action:'fence',args:{amount:4}});
  switchTab('gang'); const name=input(L.name);name.value='Concrete';name.focus();name.setSelectionRange(3,3);
  snapshot();assert.equal(input(L.name).value,'Concrete');assert.equal(document.activeElement,input(L.name));assert.equal(input(L.name).selectionStart,3);
  await click('content',L.create);assert.deepEqual(last(),{action:'gangCreate',args:{name:'Concrete'}});
  assert(content().textContent.includes('<img src=x onerror=evil()>'));assert.equal(content().querySelectorAll('img').length,0);
  fixture.gang={name:'Concrete',bank:200,score:10,role:'leader',items:{stolen:4}};snapshot();
  input(L.target).value='2';await click('content',L.invite);assert.deepEqual(last(),{action:'gangInvite',args:{target:2}});
  input(L.amount).value='73';input(L.amount).focus();snapshot();assert.equal(input(L.amount).value,'73');assert.equal(document.activeElement,input(L.amount));
  await click('content',L.deposit);assert.deepEqual(last(),{action:'gangDeposit',args:{amount:73}});
  assert(content().textContent.includes('10 / 60 s'));
  switchTab('police');assert(content().textContent.includes('<script>evil()</script>'));assert.equal(content().querySelectorAll('script').length,0);
  input(L.target).value='2';await click('content',L.arrest);assert.deepEqual(last(),{action:'police_arrest',args:{target:2}});
  switchTab('inventory');assert(nodes.menu.hidden&&!nodes.inventoryWindow.hidden);assert(!nodes.tabs.querySelectorAll('button').some(n=>n.textContent===L.tabs.inventory));await click('content',L.use);assert.deepEqual(last(),{action:'useItem',args:{item:'medkit'}});
  fixture.inventory={weight:500,capacity:8000,bags:{bag_small:{capacity:18000,price:150}}};
  fixture.drops=[{id:'loot-a',canOpen:true,cash:150,items:{stolen:3}}];snapshot();
  await click('content',L.collect);assert.deepEqual(last(),{action:'loot',args:{drop:'loot-a',item:'cash',amount:1}});
  await click('content',L.drop);assert.deepEqual(last(),{action:'inventoryDrop',args:{item:'cash',amount:1}});
  const lootQuantity=content().querySelectorAll('input').find(n=>n.nstKey==='loot:loot-a:stolen');lootQuantity.value='3';lootQuantity.focus();
  fixture.drops[0].cash=0;snapshot();
  assert.equal(content().querySelectorAll('input').find(n=>n.nstKey==='loot:loot-a:stolen').value,'3');
  assert.equal(document.activeElement.nstKey,'loot:loot-a:stolen');
  fixture.inventory.catalog={cash:{w:1,h:1,stack:10000,label:'Cash'},stolen:{w:2,h:1,stack:1,label:'Stolen goods',kind:'loot',rarity:'common',value:1},pistol:{w:2,h:2,label:'Pistol',weapon:'WEAPON_PISTOL',ammo:'ammo_9mm'}};
  fixture.inventory.grid={cols:4,rows:4,revision:7,entries:[{id:'stolen:1',item:'stolen',amount:1,x:0,y:0,w:2,h:1,rotated:0}],overflow:0};
  fixture.drops=[];snapshot();
  const tile=content().querySelectorAll('button').find(n=>n.attributes['aria-label']==='Stolen goods · 2×1 · common');assert(tile);tile.onclick();
  await click('content',L.rotate);assert(content().textContent.includes('1×2'));
  const boards=content().querySelectorAll('div').filter(n=>n.ondrop);assert.equal(boards.length,1);
  boards[0].getBoundingClientRect=()=>({left:0,top:0,width:200,height:200});
  boards[0].ondrop({clientX:160,clientY:10,preventDefault(){}});
  assert.deepEqual(last(),{action:'inventoryMove',args:{entry:'stolen:1',x:3,y:0,rotated:1,revision:7}});
  documentEvents.keydown({key:'Tab',preventDefault(){}});assert.equal(calls.at(-1).url,'https://no_safe_turf/close');
  switchTab('territory');assert(content().textContent.includes('50 / 180 s'));await click('content',L.capture);assert.deepEqual(last(),{action:'territoryStart',args:{id:'davis'}});
  switchTab('ranking');assert(content().textContent.includes('<img onerror=evil()>'));assert.equal(content().querySelectorAll('img').length,0);
  message({type:'notice',text:'<b>Rejected</b>'});assert.equal(nodes.toast.textContent,'<b>Rejected</b>');assert.equal(nodes.toast.querySelectorAll('b').length,0);
  message({type:'open',value:false});assert.equal(nodes.menu.hidden,true);
  documentEvents.keydown({key:'Escape'});assert.equal(calls.at(-1).url,'https://no_safe_turf/close');
  sandbox.fetch=async()=>{throw Error('offline');};await click('tabs',L.tabs.street);await click('content',L.start);assert.equal(nodes.toast.textContent,L.requestFailed);
  console.log('web_spec: all six tabs, seven action payloads, snapshot input/focus/cursor, text-only untrusted strings, progress, close, request failure passed');
}
run().catch(err=>{console.error(err);process.exitCode=1;});

