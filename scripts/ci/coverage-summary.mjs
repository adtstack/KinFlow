#!/usr/bin/env node

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { basename, dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export function summarizeLcov(source) {
  let linesFound = 0;
  let linesHit = 0;
  let records = 0;

  for (const rawLine of source.split(/\r?\n/u)) {
    const line = rawLine.trim();
    if (line.startsWith('LF:')) {
      linesFound += parseCounter(line, 'LF');
    } else if (line.startsWith('LH:')) {
      linesHit += parseCounter(line, 'LH');
    } else if (line === 'end_of_record') {
      records += 1;
    }
  }

  if (records === 0 || linesFound === 0) {
    throw new Error('LCOV input has no measured source records.');
  }
  if (linesHit > linesFound) {
    throw new Error('LCOV hit line count exceeds found line count.');
  }

  return {
    records,
    lines: {
      found: linesFound,
      hit: linesHit,
      percentage: Number(((linesHit / linesFound) * 100).toFixed(2)),
    },
  };
}

function parseCounter(line, label) {
  const value = line.slice(label.length + 1);
  if (!/^\d+$/u.test(value)) {
    throw new Error(`LCOV ${label} counter is invalid.`);
  }
  return Number.parseInt(value, 10);
}

async function main() {
  const [inputArgument, outputArgument] = process.argv.slice(2);
  if (!inputArgument || !outputArgument) {
    throw new Error(
      'Usage: node scripts/ci/coverage-summary.mjs <lcov.info> <summary.json>',
    );
  }

  const inputPath = resolve(inputArgument);
  const outputPath = resolve(outputArgument);
  const summary = {
    schemaVersion: 1,
    source: basename(inputArgument),
    ...summarizeLcov(await readFile(inputPath, 'utf8')),
  };

  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
  process.stdout.write(
    `Coverage: ${summary.lines.hit}/${summary.lines.found} lines (${summary.lines.percentage}%).\n`,
  );
}

const entrypoint = process.argv[1]
  ? pathToFileURL(fileURLToPath(pathToFileURL(process.argv[1]))).href
  : '';
if (import.meta.url === entrypoint) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
