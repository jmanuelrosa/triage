/// <reference types="astro/client" />

declare const __BUILD_DATE__: string;

interface Window {
  umami?: {
    track: (event: string, data?: Record<string, string | number | boolean>) => void;
  };
}
