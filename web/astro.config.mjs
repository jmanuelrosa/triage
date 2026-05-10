import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  site: 'https://jmanuelrosa.github.io',
  base: '/triage/',
  vite: {
    plugins: [tailwindcss()],
  },
});
