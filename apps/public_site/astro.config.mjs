import { defineConfig } from 'astro/config';

import { loadSiteConfig } from './src/config/site-config.mjs';

const siteConfig = loadSiteConfig(process.env);

export default defineConfig({
  site: siteConfig.origin,
  output: 'static',
  trailingSlash: 'never',
  build: {
    format: 'directory',
  },
});
