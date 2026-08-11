import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import test from 'node:test';

import {
  verifySupplyChainSources,
  verifyWorkflowSource,
} from './workflow-contract.mjs';

const workflowPath = resolve(import.meta.dirname, '../../.github/workflows/ci.yml');

test('repository CI workflow satisfies the trust and gate contract', async () => {
  const source = await readFile(workflowPath, 'utf8');
  const result = verifyWorkflowSource(source);
  assert.equal(result.jobCount, 6);
  assert.ok(result.actionCount >= 10);
});

test('workflow contract rejects mutable action references', async () => {
  const source = await readFile(workflowPath, 'utf8');
  const mutable = source.replace(
    'actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd',
    'actions/checkout@v6',
  );
  assert.throws(() => verifyWorkflowSource(mutable), /full-SHA action pin/u);
});

test('workflow contract rejects secret access and bypasses', async () => {
  const source = await readFile(workflowPath, 'utf8');
  const unsafe = source.replace(
    'permissions:',
    'env:\n  ACCESS_TOKEN: ${{ secrets.PRODUCTION_TOKEN }}\npermissions:',
  );
  assert.throws(() => verifyWorkflowSource(unsafe), /secret context reference/u);
  assert.throws(
    () => verifyWorkflowSource(`${source}\ncontinue-on-error: true\n`),
    /continue-on-error bypass/u,
  );
});

test('supply-chain contract requires offline scanning and safe installs', async () => {
  const sources = {
    actionlint: await readFile(resolve(import.meta.dirname, 'actionlint.sh'), 'utf8'),
    backend: await readFile(
      resolve(import.meta.dirname, 'supabase-backend.sh'),
      'utf8',
    ),
    osv: await readFile(resolve(import.meta.dirname, 'osv-offline-scan.sh'), 'utf8'),
    quality: await readFile(
      resolve(import.meta.dirname, 'flutter-quality.sh'),
      'utf8',
    ),
    workflow: await readFile(workflowPath, 'utf8'),
  };
  const result = verifySupplyChainSources(sources);
  assert.equal(result.offlineVulnerabilityScan, true);

  assert.throws(
    () =>
      verifySupplyChainSources({
        ...sources,
        osv: sources.osv.replace('  --offline \\', '  --verbosity error \\'),
      }),
    /actual scan offline mode/u,
  );
  assert.throws(
    () =>
      verifySupplyChainSources({
        ...sources,
        backend: sources.backend.replace(' --no-audit', ''),
      }),
    /safe npm install flags/u,
  );
});
