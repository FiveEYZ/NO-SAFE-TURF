'use strict';
const assert = require('node:assert/strict');
const {Schedule} = require('../resource/server/storage/schedule');

const epoch = value => Date.parse(value) / 1000;
const iso = value => new Date(value * 1000).toISOString();
const localFormat = new Intl.DateTimeFormat('en-GB', {timeZone:'Europe/Stockholm',
  weekday:'short', year:'numeric', month:'2-digit', day:'2-digit', hour:'2-digit',
  minute:'2-digit', second:'2-digit', hourCycle:'h23'});
function local(value) {
  return Object.fromEntries(localFormat.formatToParts(new Date(value * 1000))
    .filter(part => part.type !== 'literal').map(part => [part.type, part.value]));
}

const standard = new Schedule();
assert.equal(iso(standard.nextAfter(epoch('2026-01-01T00:00:00Z'))), '2026-01-04T03:00:00.000Z');
assert.equal(iso(standard.nextAfter(epoch('2026-07-01T00:00:00Z'))), '2026-07-05T02:00:00.000Z');
const gap = new Schedule(6,2,30);
assert.equal(iso(gap.nextAfter(epoch('2026-03-28T12:00:00Z'))), '2026-03-29T01:30:00.000Z');
assert.equal(local(gap.nextAfter(epoch('2026-03-28T12:00:00Z'))).hour,'03');
const fold = gap.nextAfter(epoch('2026-10-24T12:00:00Z'));
assert.equal(iso(fold),'2026-10-25T00:30:00.000Z');
assert.equal(iso(gap.nextAfter(fold)), '2026-11-01T01:30:00.000Z');
// The second occurrence must never turn one scheduled wipe into two.
assert.equal(gap.nextAfter(fold+0.5),gap.nextAfter(fold));
assert.equal(gap.nextAfter(epoch('2026-10-25T01:00:00Z')),gap.nextAfter(fold));
assert.equal(gap.nextAfter(fold-0.001),fold);
assert.equal(standard.nextAfter(epoch('2026-01-04T02:59:59.999Z')),epoch('2026-01-04T03:00:00Z'));
assert.equal(standard.nextAfter(epoch('2026-01-04T03:00:00Z')),epoch('2026-01-11T03:00:00Z'));
assert.equal(iso(new Schedule(0,0,0).nextAfter(epoch('2026-12-31T12:00:00Z'))), '2027-01-03T23:00:00.000Z');

// Traverse every weekly Sunday deadline over four calendar years. Default
// deadlines remain 04:00 locally despite the two UTC offsets each year.
let previous = epoch('2024-12-31T23:00:00Z'), count = 0, offsets = new Set();
while (true) {
  const next = standard.nextAfter(previous);
  if (next >= epoch('2029-01-01T00:00:00Z')) break;
  const parts = local(next);
  assert.equal(parts.weekday,'Sun');assert.equal(parts.hour,'04');
  assert.equal(parts.minute,'00');assert.equal(parts.second,'00');
  if (count) assert([601200,604800,608400].includes(next-previous));
  offsets.add(new Date(next*1000).getUTCHours());
  assert.equal(standard.nextAfter(next-0.01),next);
  previous=next;count++;
}
assert.equal(count,209);assert.deepEqual([...offsets].sort(),[2,3]);

// Independent EU transition-date expectations for the fixed regression years.
for (const [year, spring, autumn] of [[2025,30,26],[2026,29,25],[2027,28,31],[2028,26,29]]) {
  const springDeadline = gap.nextAfter(Date.UTC(year,2,spring-1,12)/1000);
  assert.equal(springDeadline,Date.UTC(year,2,spring,1,30)/1000);
  const autumnDeadline = gap.nextAfter(Date.UTC(year,9,autumn-1,12)/1000);
  assert.equal(autumnDeadline,Date.UTC(year,9,autumn,0,30)/1000);
  assert(gap.nextAfter(autumnDeadline)>autumnDeadline+6*86400);
}
for (let weekday=0;weekday<7;weekday++) {
  const next = new Schedule(weekday,13,17).nextAfter(epoch('2026-06-08T00:00:00Z'));
  assert.equal((new Date(next*1000).getUTCDay()+6)%7,weekday);
  assert.equal(local(next).hour,'13');assert.equal(local(next).minute,'17');
}
for (const args of [[-1],[7],[1.1],[true],[6,24],[6,-1],[6,1,60],[6,1,0.5],['6']]) {
  assert.throws(()=>new Schedule(...args),/Invalid weekly schedule/);
}
for (const timestamp of [NaN,Infinity,-1,'1000',null,1e20]) {
  assert.throws(()=>standard.nextAfter(timestamp),/Invalid schedule timestamp/);
}
console.log('schedule_spec: 209 weekly deadlines, DST gaps/folds, strict boundaries, weekdays and invalid configuration passed');
