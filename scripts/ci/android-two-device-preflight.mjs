import { execFile as execFileCallback } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { promisify } from 'node:util';

import { validateAndroidAppLinkHost } from './android-public-config.mjs';

export const minimumAndroidApiLevel = 24;

const maximumAdbOutputBytes = 256 * 1024;
const adbTimeoutMilliseconds = 15_000;
const deviceSerialPattern = /^[A-Za-z0-9._:-]{1,128}$/u;
const packageNamePattern = /^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/u;
const sha256FingerprintPattern = /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/u;
const execFile = promisify(execFileCallback);

function validateDeviceSerial(value) {
  if (typeof value !== 'string' || !deviceSerialPattern.test(value)) {
    throw new Error('Android device serial is invalid.');
  }
  return value;
}

function validatePackageName(value) {
  if (typeof value !== 'string' || !packageNamePattern.test(value)) {
    throw new Error('Android package name is invalid.');
  }
  return value;
}

function validateSha256Fingerprint(value) {
  if (typeof value !== 'string' || !sha256FingerprintPattern.test(value)) {
    throw new Error('Android signing SHA-256 fingerprint is invalid.');
  }
  return value;
}

function validateInputs({
  deviceASerial,
  deviceBSerial,
  expectedHost,
  expectedPackageName,
  expectedSha256Fingerprint,
}) {
  const validatedDeviceASerial = validateDeviceSerial(deviceASerial);
  const validatedDeviceBSerial = validateDeviceSerial(deviceBSerial);
  if (validatedDeviceASerial === validatedDeviceBSerial) {
    throw new Error('Two distinct Android device serials are required.');
  }

  return Object.freeze({
    deviceASerial: validatedDeviceASerial,
    deviceBSerial: validatedDeviceBSerial,
    expectedHost: validateAndroidAppLinkHost(expectedHost),
    expectedPackageName: validatePackageName(expectedPackageName),
    expectedSha256Fingerprint: validateSha256Fingerprint(
      expectedSha256Fingerprint,
    ),
  });
}

function boundedOutput(value) {
  if (
    typeof value !== 'string' ||
    Buffer.byteLength(value, 'utf8') > maximumAdbOutputBytes
  ) {
    throw new Error('Android device check returned invalid output.');
  }
  return value;
}

export function parseAndroidAppLinks(
  output,
  {
    expectedHost,
    expectedPackageName,
    expectedSha256Fingerprint,
  },
) {
  const validatedOutput = boundedOutput(output);
  const host = validateAndroidAppLinkHost(expectedHost);
  const packageName = validatePackageName(expectedPackageName);
  const fingerprint = validateSha256Fingerprint(expectedSha256Fingerprint);
  const lines = validatedOutput.split(/\r?\n/u).map((line) => line.trim());

  if (!lines.includes(`${packageName}:`)) {
    throw new Error('Android package App Link state is unavailable.');
  }

  const signaturesLine = lines.find((line) => line.startsWith('Signatures:'));
  const signaturesMatch = signaturesLine?.match(/^Signatures:\s*\[(.*)\]$/u);
  const signatures = signaturesMatch?.[1]
    .split(',')
    .map((value) => value.trim()) ?? [];
  if (!signatures.includes(fingerprint)) {
    throw new Error('Android installed package signer does not match.');
  }

  const domainPrefix = `${host}:`;
  const domainLine = lines.find((line) => line.startsWith(domainPrefix));
  const domainState = domainLine?.slice(domainPrefix.length).trim();
  if (domainState !== 'verified') {
    throw new Error('Android App Link host is not verified.');
  }

  return Object.freeze({
    appLinkVerified: true,
    signerMatched: true,
  });
}

async function executeAdbCommand(adbBin, serial, arguments_) {
  const result = await execFile(adbBin, ['-s', serial, ...arguments_], {
    encoding: 'utf8',
    maxBuffer: maximumAdbOutputBytes,
    timeout: adbTimeoutMilliseconds,
    windowsHide: true,
  });
  return boundedOutput(result.stdout);
}

async function readDeviceCommand({ arguments_, executeAdb, label, serial }) {
  try {
    return boundedOutput(await executeAdb(serial, arguments_));
  } catch {
    throw new Error(`${label} Android device check failed.`);
  }
}

async function inspectDevice({
  executeAdb,
  expectedHost,
  expectedPackageName,
  expectedSha256Fingerprint,
  label,
  serial,
}) {
  const read = (arguments_) =>
    readDeviceCommand({ arguments_, executeAdb, label, serial });

  const state = (await read(['get-state'])).trim();
  if (state !== 'device') {
    throw new Error(`${label} is not online.`);
  }

  const bootCompleted = (
    await read(['shell', 'getprop', 'sys.boot_completed'])
  ).trim();
  if (bootCompleted !== '1') {
    throw new Error(`${label} has not completed Android boot.`);
  }

  const apiValue = (
    await read(['shell', 'getprop', 'ro.build.version.sdk'])
  ).trim();
  if (!/^\d+$/u.test(apiValue)) {
    throw new Error(`${label} Android API level is invalid.`);
  }
  const apiLevel = Number(apiValue);
  if (!Number.isSafeInteger(apiLevel) || apiLevel < minimumAndroidApiLevel) {
    throw new Error(`${label} does not meet the minimum Android API level.`);
  }

  const packagePath = await read(['shell', 'pm', 'path', expectedPackageName]);
  if (
    !packagePath
      .split(/\r?\n/u)
      .map((line) => line.trim())
      .some((line) => /^package:\/\S+$/u.test(line))
  ) {
    throw new Error(`${label} does not have the expected package installed.`);
  }

  const appLinks = parseAndroidAppLinks(
    await read(['shell', 'pm', 'get-app-links', expectedPackageName]),
    { expectedHost, expectedPackageName, expectedSha256Fingerprint },
  );

  return Object.freeze({
    apiLevel,
    appLinkVerified: appLinks.appLinkVerified,
    label,
    packageInstalled: true,
    signerMatched: appLinks.signerMatched,
  });
}

export async function runTwoDevicePreflight({
  adbBin = process.env.KINFLOW_ADB_BIN || 'adb',
  deviceASerial,
  deviceBSerial,
  executeAdb,
  expectedHost,
  expectedPackageName,
  expectedSha256Fingerprint,
}) {
  const inputs = validateInputs({
    deviceASerial,
    deviceBSerial,
    expectedHost,
    expectedPackageName,
    expectedSha256Fingerprint,
  });
  if (typeof adbBin !== 'string' || adbBin.trim() === '') {
    throw new Error('ADB executable is invalid.');
  }

  const command =
    executeAdb ??
    ((serial, arguments_) => executeAdbCommand(adbBin, serial, arguments_));
  if (typeof command !== 'function') {
    throw new Error('ADB command executor is invalid.');
  }

  const common = {
    executeAdb: command,
    expectedHost: inputs.expectedHost,
    expectedPackageName: inputs.expectedPackageName,
    expectedSha256Fingerprint: inputs.expectedSha256Fingerprint,
  };
  const deviceA = await inspectDevice({
    ...common,
    label: 'Device A',
    serial: inputs.deviceASerial,
  });
  const deviceB = await inspectDevice({
    ...common,
    label: 'Device B',
    serial: inputs.deviceBSerial,
  });

  return Object.freeze({
    devices: Object.freeze([deviceA, deviceB]),
    passed: true,
  });
}

async function main() {
  const [
    deviceASerial,
    deviceBSerial,
    expectedPackageName,
    expectedHost,
    expectedSha256Fingerprint,
    ...unexpectedArguments
  ] = process.argv.slice(2);
  if (
    !deviceASerial ||
    !deviceBSerial ||
    !expectedPackageName ||
    !expectedHost ||
    !expectedSha256Fingerprint ||
    unexpectedArguments.length > 0
  ) {
    process.stderr.write(
      'Usage: node scripts/ci/android-two-device-preflight.mjs <device-a-serial> <device-b-serial> <package> <host> <sha256>\n',
    );
    process.exitCode = 64;
    return;
  }

  try {
    const result = await runTwoDevicePreflight({
      deviceASerial,
      deviceBSerial,
      expectedHost,
      expectedPackageName,
      expectedSha256Fingerprint,
    });
    process.stdout.write('Android two-device preflight passed.\n');
    for (const device of result.devices) {
      process.stdout.write(
        `${device.label}: API ${device.apiLevel}, package installed, signer matched, App Link verified.\n`,
      );
    }
  } catch (error) {
    process.stderr.write(
      `${error instanceof Error ? error.message : 'Android two-device preflight failed.'}\n`,
    );
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
