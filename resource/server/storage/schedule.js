'use strict';

// Weekly wall-clock deadlines use ICU's IANA data, never the host's local zone.
// Monday=0. Ambiguous autumn times choose the FIRST occurrence; nonexistent
// spring times move forward by the DST gap, matching Python zoneinfo fold=0.
const ZONE = 'Europe/Stockholm';
const formatter = new Intl.DateTimeFormat('en-GB-u-ca-gregory-nu-latn', {
  timeZone: ZONE, year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23'
});

function localParts(epoch) {
  const parts = {};
  for (const part of formatter.formatToParts(new Date(epoch * 1000))) {
    if (part.type !== 'literal') parts[part.type] = Number(part.value);
  }
  return parts;
}

function wallEpoch(parts) {
  return Date.UTC(parts.year, parts.month - 1, parts.day,
    parts.hour || 0, parts.minute || 0, parts.second || 0) / 1000;
}

function resolveWallTime(parts) {
  const wall = wallEpoch(parts);
  const offsets = new Set();
  // Sampling both sides of this local date includes both transition offsets.
  for (const hours of [-36, -12, 0, 12, 36]) {
    const sample = wall + hours * 3600;
    offsets.add(wallEpoch(localParts(sample)) - sample);
  }
  const candidates = [...offsets].map(offset => {
    const epoch = wall - offset;
    return {epoch, difference: wallEpoch(localParts(epoch)) - wall};
  });
  const exact = candidates.filter(candidate => candidate.difference === 0)
    .sort((a, b) => a.epoch - b.epoch);
  if (exact.length) return exact[0].epoch;
  const afterGap = candidates.filter(candidate => candidate.difference > 0)
    .sort((a, b) => a.difference - b.difference || a.epoch - b.epoch);
  if (afterGap.length) return afterGap[0].epoch;
  throw new Error('Cannot resolve Stockholm weekly deadline');
}

class Schedule {
  constructor(weekday = 6, hour = 4, minute = 0) {
    if (!Number.isInteger(weekday) || weekday < 0 || weekday > 6 ||
        !Number.isInteger(hour) || hour < 0 || hour > 23 ||
        !Number.isInteger(minute) || minute < 0 || minute > 59) {
      throw new TypeError('Invalid weekly schedule');
    }
    this.weekday = weekday;
    this.hour = hour;
    this.minute = minute;
    this.timeZone = ZONE;
  }

  nextAfter(timestamp) {
    if (typeof timestamp !== 'number' || !Number.isFinite(timestamp) || timestamp < 0 || timestamp > 253370764799) {
      throw new TypeError('Invalid schedule timestamp');
    }
    const local = localParts(timestamp);
    const midnight = Date.UTC(local.year, local.month - 1, local.day);
    for (let offset = 0; offset < 9; offset++) {
      const date = new Date(midnight + offset * 86400000);
      if ((date.getUTCDay() + 6) % 7 !== this.weekday) continue;
      const epoch = resolveWallTime({year: date.getUTCFullYear(), month: date.getUTCMonth() + 1,
        day: date.getUTCDate(), hour: this.hour, minute: this.minute, second: 0});
      if (epoch > timestamp) return epoch;
    }
    throw new Error('Cannot calculate next wipe');
  }
}

module.exports = {Schedule};
