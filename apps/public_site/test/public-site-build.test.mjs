import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';

const projectRoot = path.resolve(import.meta.dirname, '..');
const distRoot = path.join(projectRoot, 'dist');

const routes = Object.freeze({
  '/': 'index.html',
  '/terms': 'terms/index.html',
  '/privacy': 'privacy/index.html',
  '/support': 'support/index.html',
  '/delete-account': 'delete-account/index.html',
  '/privacy-request': 'privacy-request/index.html',
  '/404.html': '404.html',
});

async function text(relativePath) {
  return readFile(path.join(projectRoot, relativePath), 'utf8');
}

async function distText(relativePath) {
  return readFile(path.join(distRoot, relativePath), 'utf8');
}

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map(async (entry) => {
      const target = path.join(directory, entry.name);
      return entry.isDirectory() ? walk(target) : [target];
    }),
  );
  return nested.flat();
}

function anchorHrefs(html) {
  return [...html.matchAll(/<a\b[^>]*\bhref="([^"]+)"[^>]*>/giu)].map(
    (match) => match[1].replaceAll('&amp;', '&'),
  );
}

function cssHexVariable(css, name) {
  const match = css.match(new RegExp(`--${name}:\\s*(#[0-9a-f]{6})`, 'iu'));
  assert.ok(match, `missing --${name} color token`);
  return match[1];
}

function relativeLuminance(hex) {
  const channels = hex
    .slice(1)
    .match(/.{2}/gu)
    .map((channel) => Number.parseInt(channel, 16) / 255)
    .map((channel) =>
      channel <= 0.04045
        ? channel / 12.92
        : ((channel + 0.055) / 1.055) ** 2.4,
    );
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

function contrastRatio(first, second) {
  const luminances = [relativeLuminance(first), relativeLuminance(second)].sort(
    (left, right) => right - left,
  );
  return (luminances[0] + 0.05) / (luminances[1] + 0.05);
}

test('every public route is static, bilingual, accessible, and draft-safe', async () => {
  for (const [route, file] of Object.entries(routes)) {
    const html = await distText(file);
    const canonicalPath = route === '/' ? '/' : route;

    assert.match(html, /^<!DOCTYPE html><html lang="ko">/u, route);
    assert.match(html, /<meta name="description" content="[^"]+">/u, route);
    assert.match(html, /<meta name="robots" content="noindex, nofollow">/u, route);
    assert.ok(
      html.includes(`rel="canonical" href="https://example.invalid${canonicalPath}"`),
      `${route} canonical`,
    );
    assert.match(html, /<meta http-equiv="Content-Security-Policy"/u, route);
    assert.match(html, /<meta name="theme-color" content="#fcfdff">/u, route);
    assert.match(html, /default-src 'none'/u, route);
    assert.match(
      html,
      /<link rel="icon" href="\/favicon\.svg" type="image\/svg\+xml">/u,
      route,
    );
    assert.match(html, /<a class="skip-link" href="#main-content">/u, route);
    assert.match(html, /<nav class="site-nav site-nav-desktop" aria-label=/u, route);
    assert.match(html, /<details class="site-menu"><summary>메뉴 \/ Menu<\/summary>/u, route);
    assert.match(html, /<nav class="site-nav site-nav-mobile" aria-label=/u, route);
    assert.match(html, /aria-current="page"/u, route);
    assert.match(html, /<main id="main-content"[^>]*tabindex="-1">/u, route);
    assert.match(html, /<footer class="site-footer">/u, route);
    assert.match(html, /lang="ko"/u, route);
    assert.match(html, /lang="en"/u, route);
    assert.match(html, /Development draft — not an approved or published policy/u, route);
    assert.doesNotMatch(html, /<script\b|<style\b|<form\b|<iframe\b|<input\b|<textarea\b/iu, route);
    assert.doesNotMatch(html, /\son[a-z]+\s*=|\sstyle=/iu, route);
    assert.doesNotMatch(html, /target="_blank"/iu, route);
    assert.doesNotMatch(
      html,
      /<(?:script|img|iframe)\b[^>]*(?:src|href)="https?:|<link\b[^>]*rel="stylesheet"[^>]*href="https?:/iu,
      route,
    );
  }
});

test('the public favicon uses the shared KinFlow brand mark', async () => {
  const favicon = await distText('favicon.svg');

  for (const color of ['#3568DC', '#8BE0C6', '#FFFFFF', '#FFB8A8']) {
    assert.ok(favicon.includes(`fill="${color}"`), color);
  }
});

test('the public palette is bright, brand-consistent, and WCAG-readable', async () => {
  const css = await text('src/styles/global.css');
  const expectedTokens = {
    paper: '#fcfdff',
    'paper-strong': '#f5f7fc',
    ink: '#172033',
    muted: '#566176',
    brand: '#3568dc',
    'brand-strong': '#2048a8',
    'brand-soft': '#e6eeff',
    mint: '#42c7a5',
    coral: '#f47d6a',
    sunshine: '#f5c95a',
  };

  for (const [name, value] of Object.entries(expectedTokens)) {
    assert.equal(cssHexVariable(css, name).toLowerCase(), value, name);
  }

  for (const [foreground, background] of [
    ['ink', 'paper'],
    ['muted', 'paper'],
    ['brand-strong', 'brand-soft'],
    ['mint-strong', 'mint-soft'],
    ['sunshine-strong', 'sunshine-soft'],
    ['ink', 'coral-soft'],
  ]) {
    assert.ok(
      contrastRatio(
        cssHexVariable(css, foreground),
        cssHexVariable(css, background),
      ) >= 4.5,
      `${foreground} on ${background} must meet WCAG AA`,
    );
  }

  assert.ok(
    contrastRatio('#ffffff', cssHexVariable(css, 'brand')) >= 4.5,
    'white text on the primary family blue must meet WCAG AA',
  );
  assert.ok(
    contrastRatio(cssHexVariable(css, 'focus'), cssHexVariable(css, 'paper')) >=
      3,
    'focus indication must remain distinct against the page canvas',
  );
  assert.doesNotMatch(css, /#17624a|#0d4936|#bd5d3c|#f4f1e8/iu);
});

test('home keeps resource cards and bilingual documents in their labelled structure', async () => {
  const html = await distText('index.html');

  assert.match(
    html,
    /<section class="card-grid" aria-labelledby="public-resources-heading"><h2 id="public-resources-heading" class="visually-hidden">공개 안내 \/ Public resources<\/h2><article class="card">/u,
  );
  assert.equal(
    [...html.matchAll(/<article class="card">/gu)].length,
    4,
    'home must expose exactly four public resource cards',
  );
  for (const href of ['/terms', '/privacy', '/support', '/delete-account']) {
    assert.ok(html.includes(`class="card-link" href="${href}"`), href);
  }
  assert.match(html, /<div class="document-stack section-spacing">/u);
  assert.match(html, /<section id="ko" class="document-section" lang="ko"/u);
  assert.match(html, /<section id="en" class="document-section" lang="en"/u);
});

test('all static internal links resolve to a declared public route', async () => {
  const routeSet = new Set(Object.keys(routes));

  for (const [route, file] of Object.entries(routes)) {
    const html = await distText(file);
    for (const href of anchorHrefs(html)) {
      if (href.startsWith('#') || href.startsWith('mailto:')) {
        continue;
      }
      assert.ok(href.startsWith('/'), `${route} has non-local navigation ${href}`);
      const target = href.split('#', 1)[0].replace(/\/$/u, '') || '/';
      assert.ok(routeSet.has(target), `${route} links to undeclared route ${href}`);
    }
  }
});

test('deletion paths start a content-free email request without requiring the app', async () => {
  const expectedMailto =
    'mailto:support@example.invalid?subject=KinFlow%20account%20deletion%20request';

  for (const file of ['delete-account/index.html', 'privacy-request/index.html']) {
    const html = await distText(file);
    const deletionLink = anchorHrefs(html).find((href) =>
      href.startsWith('mailto:'),
    );
    assert.equal(deletionLink, expectedMailto, file);
    assert.doesNotMatch(deletionLink, /body=|cc=|bcc=|user|household|member|token|receipt/iu);
    assert.match(html, /앱 없이도 삭제를 요청하세요/u);
    assert.match(html, /does not require the app to be installed/u);
    assert.match(html, /last Owner/iu);
    assert.match(html, /does not automatically cancel a Google Play subscription/u);
    assert.match(html, /default cancellation window is 24 hours/u);
  }
});

test('support action has a fixed subject and attaches no user context', async () => {
  const html = await distText('support/index.html');
  const supportLink = anchorHrefs(html).find((href) => href.startsWith('mailto:'));

  assert.equal(
    supportLink,
    'mailto:support@example.invalid?subject=KinFlow%20support%20request',
  );
  assert.doesNotMatch(supportLink, /body=|cc=|bcc=|user|household|member|token|receipt/iu);
  assert.match(html, /no body or personal context is attached/u);
});

test('build emits no browser JavaScript and CSS has the accessibility contracts', async () => {
  const files = await walk(distRoot);
  assert.deepEqual(
    files.filter((file) => file.endsWith('.js')),
    [],
    'static public pages must not ship browser JavaScript',
  );

  const sourceCss = await text('src/styles/global.css');
  assert.match(sourceCss, /:focus-visible/u);
  assert.match(sourceCss, /\.visually-hidden\s*\{[^}]*position:\s*absolute[^}]*clip:/su);
  assert.match(sourceCss, /\.section-spacing\s*\{[^}]*margin-block-start:\s*3rem/su);
  assert.match(sourceCss, /\.button\s*\{[^}]*min-block-size:\s*3rem/su);
  assert.match(sourceCss, /@media \(prefers-reduced-motion: reduce\)/u);
  assert.match(sourceCss, /@media print/u);
  assert.doesNotMatch(sourceCss, /url\(/iu);
});

test('security headers, robots, sitemap, and Android association survive output', async () => {
  const headers = await distText('_headers');
  for (const header of [
    'Content-Security-Policy:',
    'Referrer-Policy: no-referrer',
    'X-Content-Type-Options: nosniff',
    'X-Frame-Options: DENY',
    'Permissions-Policy:',
    'Strict-Transport-Security:',
  ]) {
    assert.ok(headers.includes(header), header);
  }
  assert.match(headers, /default-src 'none'/u);
  assert.match(headers, /form-action 'none'/u);
  assert.match(headers, /frame-ancestors 'none'/u);

  assert.equal(await distText('robots.txt'), 'User-agent: *\nDisallow: /\n');
  const sitemap = await distText('sitemap.xml');
  for (const route of ['/', '/terms', '/privacy', '/support', '/delete-account']) {
    const expected = route === '/' ? 'https://example.invalid/' : `https://example.invalid${route}`;
    assert.ok(sitemap.includes(`<loc>${expected}</loc>`), route);
  }
  assert.equal(sitemap.includes('/privacy-request'), false);

  assert.equal(
    await distText('.well-known/assetlinks.json'),
    await text('public/.well-known/assetlinks.json'),
  );
  assert.equal(await distText('.nojekyll'), await text('public/.nojekyll'));
});
