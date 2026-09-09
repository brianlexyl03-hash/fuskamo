'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const engine=require('../services/unifiedGraphEngine');
test('v2 rewards relationship and meaningful quality',()=>{
  const now=new Date();
  const related={author_id:'a',object_type:'post',quality:80,trust:80,safety:100,engagement:100,created_at:now};
  const unknown={author_id:'b',object_type:'post',quality:80,trust:80,safety:100,engagement:100,created_at:now};
  const r=engine.scoreCandidate(related,{following:new Set(['a']),preferredRoles:[]});
  const u=engine.scoreCandidate(unknown,{following:new Set(),preferredRoles:[]});
  assert.ok(r.score>u.score);
});
test('v2 hard safety gate rejects severe risk',()=>{
  const r=engine.scoreCandidate({author_id:'a',object_type:'reel',quality:100,trust:100,safety:20,engagement:100,created_at:new Date()},{following:new Set()});
  assert.equal(r.score,-Infinity);
});
test('v2 negative signals outrank popularity',()=>{
  const r=engine.scoreCandidate({author_id:'a',object_type:'post',quality:100,trust:100,safety:100,engagement:1000,created_at:new Date()},{following:new Set(),negativeByAuthor:new Map([['a',3]])});
  assert.ok(r.score<100);
});
