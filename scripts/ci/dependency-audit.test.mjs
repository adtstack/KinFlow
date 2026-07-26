import assert from 'node:assert/strict';
import test from 'node:test';

import {
  classifyLicense,
  parseNpmLock,
  parsePubspecLock,
} from './dependency-audit.mjs';

test('parsePubspecLock separates hosted packages from SDK packages', () => {
  const packages = parsePubspecLock(`
packages:
  alpha:
    dependency: transitive
    description:
      name: alpha
      url: "https://pub.dev"
    source: hosted
    version: "1.2.3"
  flutter:
    dependency: direct main
    description: flutter
    source: sdk
    version: "0.0.0"
sdks:
  dart: ">=3.0.0"
`);

  assert.deepEqual(packages, [
    { name: 'alpha', source: 'hosted', version: '1.2.3' },
    { name: 'flutter', source: 'sdk', version: '0.0.0' },
  ]);
});

test('parseNpmLock requires v3 and de-duplicates platform packages', () => {
  const packages = parseNpmLock({
    lockfileVersion: 3,
    packages: {
      '': {},
      'node_modules/@scope/tool': { license: 'MIT', version: '2.0.0' },
      'node_modules/plain': { license: 'Apache-2.0', version: '1.0.0' },
    },
  });
  assert.deepEqual(packages, [
    {
      ecosystem: 'npm',
      license: 'MIT',
      name: '@scope/tool',
      version: '2.0.0',
    },
    {
      ecosystem: 'npm',
      license: 'Apache-2.0',
      name: 'plain',
      version: '1.0.0',
    },
  ]);
  assert.throws(
    () => parseNpmLock({ lockfileVersion: 2, packages: {} }),
    /lockfileVersion 3/u,
  );
});

test('classifyLicense recognizes the reviewed license families', () => {
  assert.equal(
    classifyLicense('Apache License\nVersion 2.0, January 2004'),
    'Apache-2.0',
  );
  assert.equal(
    classifyLicense('Permission is hereby granted, free of charge'),
    'MIT',
  );
  assert.equal(
    classifyLicense(
      'Redistribution and use in source and binary forms. Neither the name may be used.',
    ),
    'BSD-3-Clause',
  );
  assert.equal(
    classifyLicense('Mozilla Public License Version 2.0'),
    'MPL-2.0',
  );
  assert.equal(
    classifyLicense(
      'MIT License\nPermission is hereby granted, free of charge.\nGNU General Public License',
    ),
    undefined,
  );
  assert.equal(classifyLicense('Unknown proprietary terms'), undefined);
});
