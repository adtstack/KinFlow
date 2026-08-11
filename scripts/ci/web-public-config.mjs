import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

import { validateAndroidPublicConfiguration } from './android-public-config.mjs';

const buildVersionPattern =
  /^(?<buildName>\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)\+(?<buildNumber>[1-9]\d{0,9})$/u;

export function validateWebPublicConfiguration(
  decoded,
  { expectedApplicationId, expectedEnvironment },
) {
  validateAndroidPublicConfiguration(decoded, {
    expectedApplicationId,
    expectedEnvironment,
  });

  const match = buildVersionPattern.exec(decoded.APP_VERSION);
  if (!match?.groups) {
    throw new Error(
      'Web public config APP_VERSION must contain a canonical build name and positive build number.',
    );
  }
  const buildNumber = Number.parseInt(match.groups.buildNumber, 10);
  if (!Number.isSafeInteger(buildNumber) || buildNumber > 2147483647) {
    throw new Error('Web public config APP_VERSION build number is out of range.');
  }

  return Object.freeze({
    buildName: match.groups.buildName,
    buildNumber: match.groups.buildNumber,
  });
}

export async function loadWebPublicConfiguration(path, expectations) {
  let decoded;
  try {
    decoded = JSON.parse(await readFile(path, 'utf8'));
  } catch {
    throw new Error('Web public config could not be read as JSON.');
  }
  return validateWebPublicConfiguration(decoded, expectations);
}

async function main() {
  const [path, expectedEnvironment, expectedApplicationId] =
    process.argv.slice(2);
  if (!path || !expectedEnvironment || !expectedApplicationId) {
    process.stderr.write(
      'Usage: node scripts/ci/web-public-config.mjs <config.json> <dev|prod> <application-id>\n',
    );
    process.exitCode = 64;
    return;
  }

  const configuration = await loadWebPublicConfiguration(path, {
    expectedApplicationId,
    expectedEnvironment,
  });
  process.stdout.write(
    `${configuration.buildName}\t${configuration.buildNumber}\n`,
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
