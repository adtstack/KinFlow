import type { APIRoute } from 'astro';

import { siteConfig } from '../config/site-config.mjs';

export const GET: APIRoute = () => {
  const directives = siteConfig.production
    ? `User-agent: *\nAllow: /\nSitemap: ${siteConfig.origin}/sitemap.xml\n`
    : 'User-agent: *\nDisallow: /\n';

  return new Response(directives, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
    },
  });
};
