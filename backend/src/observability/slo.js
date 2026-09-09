class SLOTracker {
  constructor({ windowSize=10000 }={}) { this.windowSize=windowSize; this.samples=[]; }
  record({ok,latencyMs}) { this.samples.push({ok:Boolean(ok),latencyMs:Math.max(0,Number(latencyMs)||0)}); if(this.samples.length>this.windowSize)this.samples.shift(); }
  summary(){const n=this.samples.length;if(!n)return{count:0,availability:1,p95LatencyMs:0};const sorted=this.samples.map(x=>x.latencyMs).sort((a,b)=>a-b);return{count:n,availability:this.samples.filter(x=>x.ok).length/n,p95LatencyMs:sorted[Math.min(n-1,Math.floor(n*.95))]};}
}
module.exports={SLOTracker};
