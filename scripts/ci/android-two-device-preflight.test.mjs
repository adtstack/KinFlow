import assert from 'node:assert/strict';
import test from 'node:test';

import {
  minimumAndroidApiLevel,
  parseAndroidAppLinks,
  runTwoDevicePreflight,
} from './android-two-device-preflight.mjs';

const deviceASerial = 'emulator-5554';
const deviceBSerial = 'emulator-5556';
const expectedHost = 'adtstack.github.io';
const expectedPackageName = 'me.newlines.kinflow.dev';
const expectedSha256Fingerprint =
  '6A:C5:22:6C:F7:1B:20:1C:99:49:E8:1F:75:14:49:AD:94:53:64:A9:46:5C:ED:0C:69:19:00:51:C5:6E:C7:D5';

function appLinksOutput({
  fingerprint = expectedSha256Fingerprint,
  host = expectedHost,
  packageName = expectedPackageName,
  state = 'verified',
} = {}) {
  return `${packageName}:
    ID: 01234567-89ab-cdef-0123-456789abcdef
    Signatures: [${fingerprint}]
    Domain verification state:
      ${host}: ${state}
`;
}

function successfulExecutor(overrides = {}) {
  const calls = [];
  const executeAdb = async (serial, arguments_) => {
    calls.push({ arguments_, serial });
    const key = arguments_.join(' ');
    const override = overrides[`${serial}:${key}`] ?? overrides[key];
    if (override instanceof Error) {
      throw override;
    }
    if (override !== undefined) {
      return override;
    }
    switch (key) {
      case 'get-state':
        return 'device\n';
      case 'shell getprop sys.boot_completed':
        return '1\n';
      case 'shell getprop ro.build.version.sdk':
        return '36\n';
      case `shell pm path ${expectedPackageName}`:
        return 'package:/data/app/example/base.apk\n';
      case `shell pm get-app-links ${expectedPackageName}`:
        return appLinksOutput();
      default:
        throw new Error('unexpected test command');
    }
  };
  return { calls, executeAdb };
}

function preflightArguments(executeAdb, overrides = {}) {
  return {
    deviceASerial,
    deviceBSerial,
    executeAdb,
    expectedHost,
    expectedPackageName,
    expectedSha256Fingerprint,
    ...overrides,
  };
}

test('parses only the exact package signer and verified host', () => {
  assert.deepEqual(
    parseAndroidAppLinks(appLinksOutput(), {
      expectedHost,
      expectedPackageName,
      expectedSha256Fingerprint,
    }),
    { appLinkVerified: true, signerMatched: true },
  );

  assert.throws(
    () =>
      parseAndroidAppLinks(appLinksOutput({ packageName: 'example.app' }), {
        expectedHost,
        expectedPackageName,
        expectedSha256Fingerprint,
      }),
    /state is unavailable/u,
  );
  assert.throws(
    () =>
      parseAndroidAppLinks(
        appLinksOutput({
          fingerprint:
            'AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA',
        }),
        { expectedHost, expectedPackageName, expectedSha256Fingerprint },
      ),
    /signer does not match/u,
  );
  assert.throws(
    () =>
      parseAndroidAppLinks(appLinksOutput({ state: 'legacy_failure' }), {
        expectedHost,
        expectedPackageName,
        expectedSha256Fingerprint,
      }),
    /host is not verified/u,
  );
});

test('checks two explicit devices and returns only redacted summaries', async () => {
  const { calls, executeAdb } = successfulExecutor();
  const result = await runTwoDevicePreflight(preflightArguments(executeAdb));

  assert.equal(result.passed, true);
  assert.deepEqual(result.devices, [
    {
      apiLevel: 36,
      appLinkVerified: true,
      label: 'Device A',
      packageInstalled: true,
      signerMatched: true,
    },
    {
      apiLevel: 36,
      appLinkVerified: true,
      label: 'Device B',
      packageInstalled: true,
      signerMatched: true,
    },
  ]);
  assert.equal(calls.length, 10);
  assert.deepEqual(calls.slice(0, 5).map(({ arguments_ }) => arguments_), [
    ['get-state'],
    ['shell', 'getprop', 'sys.boot_completed'],
    ['shell', 'getprop', 'ro.build.version.sdk'],
    ['shell', 'pm', 'path', expectedPackageName],
    ['shell', 'pm', 'get-app-links', expectedPackageName],
  ]);

  const serialized = JSON.stringify(result);
  assert.equal(serialized.includes(deviceASerial), false);
  assert.equal(serialized.includes(deviceBSerial), false);
  assert.equal(serialized.includes(expectedSha256Fingerprint), false);
});

test('rejects invalid or identical device serials before ADB execution', async () => {
  let calls = 0;
  const executeAdb = async () => {
    calls += 1;
    return '';
  };

  await assert.rejects(
    runTwoDevicePreflight(
      preflightArguments(executeAdb, { deviceBSerial: deviceASerial }),
    ),
    /distinct Android device serials/u,
  );
  await assert.rejects(
    runTwoDevicePreflight(
      preflightArguments(executeAdb, { deviceASerial: 'unsafe serial' }),
    ),
    /device serial is invalid/u,
  );
  assert.equal(calls, 0);
});

test('fails closed for offline, unbooted, old, and uninstalled devices', async () => {
  const scenarios = [
    { key: 'get-state', message: /not online/u, value: 'offline\n' },
    {
      key: 'shell getprop sys.boot_completed',
      message: /not completed Android boot/u,
      value: '0\n',
    },
    {
      key: 'shell getprop ro.build.version.sdk',
      message: /minimum Android API/u,
      value: `${minimumAndroidApiLevel - 1}\n`,
    },
    {
      key: `shell pm path ${expectedPackageName}`,
      message: /expected package installed/u,
      value: '',
    },
  ];

  for (const scenario of scenarios) {
    const { executeAdb } = successfulExecutor({
      [`${deviceASerial}:${scenario.key}`]: scenario.value,
    });
    await assert.rejects(
      runTwoDevicePreflight(preflightArguments(executeAdb)),
      scenario.message,
    );
  }
});

test('masks raw ADB failures instead of leaking subprocess output', async () => {
  const rawFailure = 'SENSITIVE_ADB_OUTPUT_CANARY_DO_NOT_EMIT';
  const { executeAdb } = successfulExecutor({
    [`${deviceASerial}:get-state`]: new Error(rawFailure),
  });

  await assert.rejects(
    runTwoDevicePreflight(preflightArguments(executeAdb)),
    (error) => {
      assert.equal(error.message, 'Device A Android device check failed.');
      assert.equal(error.message.includes(rawFailure), false);
      return true;
    },
  );
});
