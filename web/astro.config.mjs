import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';

const buildDate = new Date().toISOString().slice(0, 10);

// https://astro.build/config
export default defineConfig({
  site: 'https://jmanuelrosa.github.io',
  base: '/triage/',
  trailingSlash: 'ignore',
  integrations: [sitemap()],
  vite: {
    plugins: [tailwindcss()],
    define: {
      __BUILD_DATE__: JSON.stringify(buildDate),
    },
  },
});
