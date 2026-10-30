/* FUSKAMO cinematic intro + restrained spring-physics depth. */
(() => {
 const intro=document.getElementById('splash'); if(!intro)return; let finished=false;
 const enter=intro.querySelector('#enter-fuskamo'),skip=intro.querySelector('#skip-intro'); let timer,readyTimer;
 const finish=()=>{if(finished)return;finished=true;clearTimeout(timer);clearTimeout(readyTimer);intro.classList.add('opening');setTimeout(()=>intro.classList.add('cinema-out','hide'),720);setTimeout(()=>intro.remove(),1700)};
 const ready=()=>intro.classList.add('is-ready');
 window.finishCinematicIntro=finish;window.cinematicIntroReady=ready;
 enter?.addEventListener('click',finish);skip?.addEventListener('click',finish);
 window.addEventListener('keydown',e=>{if(!finished&&(e.key==='Escape'||e.key==='Enter'))finish()});
 if(window.matchMedia?.('(prefers-reduced-motion: reduce)').matches)finish();else{readyTimer=setTimeout(ready,3400);timer=setTimeout(finish,8600)}
 const stage=intro.querySelector('.cinema-stage');
 if(stage&&window.matchMedia?.('(hover: hover) and (pointer: fine)').matches&&!window.matchMedia('(prefers-reduced-motion: reduce)').matches){
  let tx=0,ty=0,x=0,y=0,vx=0,vy=0,raf=0;
  const tick=()=>{vx=(vx+(tx-x)*.055)*.76;vy=(vy+(ty-y)*.055)*.76;x+=vx;y+=vy;
   if(window.DOMMatrix)stage.style.transform=new DOMMatrix().rotateAxisAngle(1,0,0,x).rotateAxisAngle(0,1,0,y).toString();
   else stage.style.transform='perspective(1500px) rotateX('+x+'deg) rotateY('+y+'deg)';
   if(Math.abs(tx-x)+Math.abs(ty-y)+Math.abs(vx)+Math.abs(vy)>.015&&!finished)raf=requestAnimationFrame(tick);else{raf=0;stage.style.transform=''}};
  window.addEventListener('pointermove',e=>{tx=((e.clientY/innerHeight)-.5)*-3.4;ty=((e.clientX/innerWidth)-.5)*5.2;if(!raf)raf=requestAnimationFrame(tick)},{passive:true});
  window.addEventListener('blur',()=>{tx=ty=0;if(!raf)raf=requestAnimationFrame(tick)});
 }
 window.bindFuskamoDepth=(scope=document)=>{if(!window.matchMedia?.('(hover: hover) and (pointer: fine)').matches||window.matchMedia('(prefers-reduced-motion: reduce)').matches)return;
  Array.from(scope.querySelectorAll?.('.auth-scene,.card,.post-card,.group-card')||[]).slice(0,8).forEach(node=>{if(node.dataset.depthBound)return;node.dataset.depthBound='1';let ax=0,ay=0,cx=0,cy=0,dx=0,dy=0,frame=0;
   const step=()=>{dx=(dx+(ax-cx)*.07)*.78;dy=(dy+(ay-cy)*.07)*.78;cx+=dx;cy+=dy;node.style.transform='perspective(1100px) rotateX('+(-cy)+'deg) rotateY('+cx+'deg)';if(Math.abs(ax-cx)+Math.abs(ay-cy)+Math.abs(dx)+Math.abs(dy)>.025)frame=requestAnimationFrame(step);else frame=0};
   node.addEventListener('pointermove',e=>{const r=node.getBoundingClientRect();ax=((e.clientX-r.left)/r.width-.5)*2.2;ay=((e.clientY-r.top)/r.height)*-1.8;if(!frame)frame=requestAnimationFrame(step)},{passive:true});
   node.addEventListener('pointerleave',()=>{ax=ay=0;if(!frame)frame=requestAnimationFrame(step)});
  });
 };
 window.bindFuskamoDepth(document);
})();