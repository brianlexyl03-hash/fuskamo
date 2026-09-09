'use strict';
/**
 * FUSKAMO local stress sandbox.
 * No network, Supabase, cloud storage, or paid services are required.
 * Exercises the pure ranking/trust engines with adversarial synthetic load.
 */
const { rankCandidates, scoreCandidate } = require('../backend/src/services/unifiedGraphEngine');
const trust = require('../backend/src/services/trustBadgeEngine');
const discovery = require('../backend/src/services/discoveryEngine');
const os = require('node:os');
const fs = require('node:fs');
const path = require('node:path');

const N = Number(process.env.FUSKAMO_STRESS_CANDIDATES || 250000);
const TRUST_N = Number(process.env.FUSKAMO_STRESS_TRUST || 250000);
const DISCOVERY_N = Number(process.env.FUSKAMO_STRESS_DISCOVERY || 100000);
const LIMIT = 100;

const now = Date.now();
const roles = ['player','scout','club','coach','fan'];
const types = ['post','reel','story','player','group'];
const countries = ['Kenya','Nigeria','Ghana','Uganda','Tanzania','South Africa'];

function timed(name, fn) {
  const start = process.hrtime.bigint();
  const before = process.memoryUsage().rss;
  const result = fn();
  const ms = Number(process.hrtime.bigint() - start) / 1e6;
  const after = process.memoryUsage().rss;
  return { name, result, ms, rssDeltaMB: (after - before) / 1024 / 1024 };
}

function makeCandidates(n) {
  const out = new Array(n);
  for (let i=0;i<n;i++) {
    out[i] = {
      id:`c${i}`, author_id:`u${i%10000}`, object_type:types[i%types.length],
      role:roles[i%roles.length], quality:(i%101), trust:(i*7)%101,
      safety: i%997===0 ? 10 : 50 + (i%51), engagement:i%5000,
      momentum:(i*13)%101, creator_affinity:(i*17)%101, category_affinity:(i*19)%101,
      created_at:new Date(now - (i%30)*86400000).toISOString()
    };
  }
  return out;
}

function makePlayers(n) {
  const out = new Array(n);
  for (let i=0;i<n;i++) out[i] = {
    id:`p${i}`, status:'approved', position:i%3===0?'Striker':'Goalkeeper', age:18+(i%18),
    country:countries[i%countries.length], foot:i%2?'right':'left', height:165+(i%40),
    profile_completeness:(i%101)/100, quality_score:(i*3%101)/100,
    fraud_score:i%997===0?0.9:(i%17)/100, views_7d:i%10000, saves_7d:i%1000,
    contacts_7d:i%300, shares_7d:i%500, created_at:new Date(now-(i%40)*86400000).toISOString(),
    featured_until:null, profile_verified:i%11===0, trust_score:i%101, achievement_count:i%20
  };
  return out;
}

const results=[];
results.push(timed('recommendation:250k-candidates', () => {
  const candidates=makeCandidates(N);
  const context={
    following:new Set(Array.from({length:1000},(_,i)=>`u${i}`)),
    preferredRoles:['player','club'], now,
    negativeByAuthor:new Map([['u3',20],['u7',80]]),
    reportPenaltyByAuthor:new Map([['u11',10]]),
    recentAuthorCounts:new Map(), recentTypeCounts:new Map()
  };
  const ranked=rankCandidates(candidates,context,LIMIT);
  if (ranked.length!==LIMIT) throw new Error(`expected ${LIMIT} results, got ${ranked.length}`);
  if (ranked.some(x=>x.candidate.safety<25)) throw new Error('safety gate leaked unsafe candidate');
  for(let i=1;i<ranked.length;i++) if(ranked[i].score>ranked[i-1].score) throw new Error('ranking not sorted');
  return ranked.length;
}));

results.push(timed(`trust:${TRUST_N}-profiles`, () => {
  let checksum=0;
  for(let i=0;i<TRUST_N;i++) {
    checksum += trust.calculateTrustScore({
      profile:{display_name:`User ${i}`,username:`user_${i}`,bio:'A legitimate football profile with enough detail for trust scoring.',avatar_url:'https://example.invalid/a',role:roles[i%roles.length]},
      likes:i%1000, verifiedEndorsements:i%9, fraudScore:(i%100)/100, roleConsistent:i%23!==0
    });
  }
  if (!Number.isFinite(checksum)) throw new Error('trust checksum invalid');
  return checksum;
}));

results.push(timed(`discovery:${DISCOVERY_N}-players`, () => {
  const scout={id:'s1',preferred_positions:['Striker'],preferred_countries:['Kenya'],age_min:18,age_max:28,preferred_foot:'right',preferred_height_min:175};
  const ranked=discovery.rankPlayers(scout,makePlayers(DISCOVERY_N));
  if (!ranked.length) throw new Error('discovery returned no eligible players');
  if (ranked.some(x=>x.player.status!=='approved' || x.player.fraud_score>0.8)) throw new Error('discovery leaked ineligible player');
  return ranked.length;
}));

results.push(timed('adversarial-score-boundaries', () => {
  const values=[-Infinity,-1,0,1,NaN,Infinity,Number.MAX_SAFE_INTEGER];
  for(const v of values){
    const r=scoreCandidate({author_id:'u',object_type:'post',role:'player',quality:v,trust:v,safety:v,engagement:v,momentum:v},{now});
    if (r.score !== -Infinity && !Number.isFinite(r.score)) throw new Error(`non-finite score for ${String(v)}`);
  }
  return values.length;
}));

const report={
  timestamp:new Date().toISOString(), node:process.version, cpus:os.cpus().length,
  config:{candidates:N,trust:TRUST_N,discovery:DISCOVERY_N}, results:results.map(r=>({name:r.name,ms:+r.ms.toFixed(2),rssDeltaMB:+r.rssDeltaMB.toFixed(2),result:r.result})),
  status:'PASS'
};
const out=path.join(__dirname,'stress-report.json');
fs.writeFileSync(out,JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
