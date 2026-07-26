#!/usr/bin/env node

import { existsSync } from 'node:fs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const allowedLicenses = new Set([
  'Apache-2.0',
  'BSD-2-Clause',
  'BSD-3-Clause',
  'MIT',
  'MPL-2.0',
]);

export function parsePubspecLock(source) {
  const packages = [];
  let inPackages = false;
  let current;

  const finishCurrent = () => {
    if (!current) return;
    if (!current.source || !current.version) {
      throw new Error(`Incomplete pub lock entry: ${current.name}.`);
    }
    packages.push(current);
    current = undefined;
  };

  for (const line of source.split(/\r?\n/u)) {
    if (line === 'packages:') {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    if (/^[^ ]/u.test(line) && line !== '') {
      finishCurrent();
      break;
    }

    const packageMatch = /^  ([A-Za-z0-9_]+):$/u.exec(line);
    if (packageMatch) {
      finishCurrent();
      current = { name: packageMatch[1] };
      continue;
    }
    if (!current) continue;

    const sourceMatch = /^    source: ([A-Za-z0-9_]+)$/u.exec(line);
    if (sourceMatch) current.source = sourceMatch[1];
    const versionMatch = /^    version: "([^"]+)"$/u.exec(line);
    if (versionMatch) current.version = versionMatch[1];
  }
  finishCurrent();

  if (packages.length === 0) {
    throw new Error('No packages found in pubspec.lock.');
  }
  return packages;
}

export function parseNpmLock(lock) {
  if (lock.lockfileVersion !== 3 || !lock.packages) {
    throw new Error('package-lock.json must use lockfileVersion 3.');
  }

  const packages = [];
  for (const [path, metadata] of Object.entries(lock.packages)) {
    const marker = 'node_modules/';
    const markerIndex = path.lastIndexOf(marker);
    if (markerIndex < 0) continue;
    const packagePath = path.slice(markerIndex + marker.length);
    const segments = packagePath.split('/');
    const name = packagePath.startsWith('@')
      ? segments.slice(0, 2).join('/')
      : segments[0];
    if (!name || typeof metadata.version !== 'string') {
      throw new Error(`Incomplete npm lock entry: ${path}.`);
    }
    packages.push({
      ecosystem: 'npm',
      license: metadata.license,
      name,
      version: metadata.version,
    });
  }
  return deduplicatePackages(packages);
}

export function classifyLicense(source) {
  const normalized = source.toLowerCase();
  if (normalized.includes('mozilla public license version 2.0')) {
    return 'MPL-2.0';
  }
  if (
    [
      'affero general public license',
      'business source license',
      'commons clause',
      'gnu general public license',
      'server side public license',
    ].some((marker) => normalized.includes(marker))
  ) {
    return undefined;
  }
  if (
    normalized.includes('apache license') &&
    normalized.includes('version 2.0')
  ) {
    return 'Apache-2.0';
  }
  if (normalized.includes('permission is hereby granted, free of charge')) {
    return 'MIT';
  }
  if (normalized.includes('redistribution and use in source and binary forms')) {
    return normalized.includes('neither the name')
      ? 'BSD-3-Clause'
      : 'BSD-2-Clause';
  }
  return undefined;
}

async function auditPubLicenses(appRoot, pubPackages) {
  const configPath = resolve(appRoot, '.dart_tool/package_config.json');
  const config = JSON.parse(await readFile(configPath, 'utf8'));
  const roots = new Map(
    config.packages.map((entry) => [
      entry.name,
      fileURLToPath(new URL(entry.rootUri, pathToFileURL(configPath))),
    ]),
  );
  const audited = [];

  for (const entry of pubPackages.filter((item) => item.source === 'hosted')) {
    const root = roots.get(entry.name);
    if (!root) throw new Error(`Pub package is not resolved: ${entry.name}.`);
    const licensePath = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING']
      .map((name) => resolve(root, name))
      .find(existsSync);
    if (!licensePath) {
      throw new Error(`Pub package has no license file: ${entry.name}.`);
    }
    const license = classifyLicense(await readFile(licensePath, 'utf8'));
    assertAllowedLicense('Pub', entry.name, license);
    audited.push({ license, name: entry.name, version: entry.version });
  }
  return audited.sort((left, right) => left.name.localeCompare(right.name));
}

function auditNpmLicenses(packages) {
  return packages
    .map((entry) => {
      assertAllowedLicense('npm', entry.name, entry.license);
      return { license: entry.license, name: entry.name, version: entry.version };
    })
    .sort((left, right) => left.name.localeCompare(right.name));
}

function assertAllowedLicense(ecosystem, name, license) {
  if (typeof license !== 'string' || !allowedLicenses.has(license)) {
    throw new Error(
      `${ecosystem} package ${name} has an unreviewed license: ${license ?? 'unknown'}.`,
    );
  }
}

function deduplicatePackages(packages) {
  const unique = new Map();
  for (const entry of packages) {
    unique.set(`${entry.ecosystem}:${entry.name}:${entry.version}`, entry);
  }
  return [...unique.values()].sort((left, right) =>
    `${left.ecosystem}:${left.name}:${left.version}`.localeCompare(
      `${right.ecosystem}:${right.name}:${right.version}`,
    ),
  );
}

async function main() {
  const repositoryRoot = resolve(import.meta.dirname, '../..');
  const appRoot = resolve(repositoryRoot, 'apps/kinflow_app');
  const argumentsList = process.argv.slice(2);
  const reportFlag = argumentsList.indexOf('--report');
  const reportPath =
    reportFlag >= 0 && argumentsList[reportFlag + 1]
      ? resolve(argumentsList[reportFlag + 1])
      : resolve(repositoryRoot, 'ci-reports/dependency-audit.json');
  const pubLock = parsePubspecLock(
    await readFile(resolve(appRoot, 'pubspec.lock'), 'utf8'),
  );
  const npmPackages = parseNpmLock(
    JSON.parse(await readFile(resolve(repositoryRoot, 'package-lock.json'), 'utf8')),
  );
  const pubLicenses = await auditPubLicenses(appRoot, pubLock);
  const npmLicenses = auditNpmLicenses(npmPackages);
  const report = {
    schemaVersion: 1,
    licenses: {
      allowed: [...allowedLicenses].sort(),
      npm: npmLicenses,
      pub: pubLicenses,
    },
  };
  await mkdir(dirname(reportPath), { recursive: true });
  await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');

  process.stdout.write(
    `Dependency license audit passed: ${pubLicenses.length} Pub and ${npmLicenses.length} npm packages.\n`,
  );
}

const entrypoint = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : '';
if (import.meta.url === entrypoint) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
