const test = require('node:test');
const assert = require('node:assert/strict');
const { rankCandidates } = require('../ranking/rankingEngine');
const { search } = require('../search/searchEngine');
const { riskScore, decision } = require('../safety/abuseEngine');
const { assign } = require('../experiments/experimentEngine');
const { createUploadPlan } = require('../media/mediaPipeline');
const { inspectContent } = require('../safety/contentSafety');

test('ranking is finite, safe and diverse', () => {
  const rows = rankCandidates(Array.from({length: 10000}, (_, i) => ({ id: String(i), authorId: String(i%5), affinity: .9, quality: .8, freshness: .7, safety: i===9 ? .1 : .9 })));
  assert.ok(rows.length <= 15); assert.ok(rows.every(x => Number.isFinite(x.score) && x.safety >= .45));
});
test('search is deterministic', () => { const a=search('moran',[{id:'1',username:'MORANGI',verified:true},{id:'2',username:'x'}]); const b=search('moran',[{id:'1',username:'MORANGI',verified:true},{id:'2',username:'x'}]); assert.deepEqual(a,b); });
test('abuse decisions escalate', () => { const s=riskScore({actionsPerMinute:200,reportsLast24h:50,duplicateContentRate:1,failedAuths:30,accountsPerDevice:20}); assert.ok(s >= .85); assert.equal(decision(s),'block'); });
test('experiment assignment is sticky', () => { const e={key:'feed-v1',enabled:true,rolloutPercent:100,variants:['control','treatment']}; assert.equal(assign(e,'user-1'),assign(e,'user-1')); });
test('media plan validates and produces pipeline', () => { const p=createUploadPlan({ownerId:'u',mimeType:'image/webp',bytes:100}); assert.equal(p.stages.length,5); });
test('content safety detects common spam', () => { const r=inspectContent({text:'FREE MONEY click here https://bit.ly/a'}); assert.equal(r.action,'review'); });
