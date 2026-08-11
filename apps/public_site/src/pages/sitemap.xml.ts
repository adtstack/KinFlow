import type { APIRoute } from 'astro';

import { siteConfig } from '../config/site-config.mjs';

const paths = ['/', '/terms', '/privacy', '/support', '/delete-account'];

function escapeXml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

export const GET: APIRoute = () => {
  const urls = paths
    .map((path) => {
      const location = new URL(path, `${siteConfig.origin}/`).toString();
      return `  <url><loc>${escapeXml(location)}</loc><lastmod>${siteConfig.publishedOn}</lastmod></url>`;
    })
    .join('\n');
  const body = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`;

  return new Response(body, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
    },
  });
};
