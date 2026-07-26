import assert from 'node:assert/strict';
import test from 'node:test';

import { summarizeLcov } from './coverage-summary.mjs';

test('summarizeLcov aggregates records deterministically', () => {
  const result = summarizeLcov(`
SF:lib/one.dart
LF:3
LH:2
end_of_record
SF:lib/two.dart
LF:1
LH:1
end_of_record
`);

  assert.deepEqual(result, {
    records: 2,
    lines: { found: 4, hit: 3, percentage: 75 },
  });
});

test('summarizeLcov rejects empty and inconsistent reports', () => {
  assert.throws(() => summarizeLcov(''), /no measured source records/u);
  assert.throws(
    () => summarizeLcov('LF:1\nLH:2\nend_of_record\n'),
    /exceeds found line count/u,
  );
  assert.throws(
    () => summarizeLcov('LF:not-a-number\nLH:0\nend_of_record\n'),
    /counter is invalid/u,
  );
});
