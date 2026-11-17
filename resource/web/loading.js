'use strict';
(() => {
 const tips=['Open your gameplay menu with F6 or /nst once you arrive.','Build your reputation. Every decision leaves a mark.','Work with your crew. Stay alert when moving valuable loot.','Explore the city, learn the streets and choose your next move.'];
 let tip=0,progress=0;
 const dots=document.querySelectorAll('.ticks b');
 function showTip(){document.getElementById('tip').textContent=tips[tip];document.getElementById('tipNumber').textContent=String(tip+1).padStart(2,'0')+' / 04';dots.forEach((d,i)=>d.classList.toggle('active',i===tip));}
 showTip();const timer=setInterval(()=>{tip=(tip+1)%tips.length;showTip();},8000);
 window.addEventListener('pagehide',()=>clearInterval(timer));
 window.addEventListener('message',event=>{
  const data=event.data;
  if(!data||data.eventName!=='loadProgress'||typeof data.loadFraction!=='number'||!Number.isFinite(data.loadFraction))return;
  progress=Math.max(progress,Math.min(1,Math.max(0,data.loadFraction)));
  const value=Math.floor(progress*100);
  document.getElementById('fill').style.width=value+'%';document.getElementById('percent').textContent=value+'%';
  document.querySelector('.track').setAttribute('aria-valuenow',String(value));
  document.getElementById('phase').textContent=value===100?'FINALIZING YOUR ARRIVAL':value>65?'LOADING THE CITY':value>20?'PREPARING GAME ASSETS':'ESTABLISHING YOUR CONNECTION';
 });
})();
