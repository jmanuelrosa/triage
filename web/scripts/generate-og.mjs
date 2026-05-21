#!/usr/bin/env node
// Generates web/public/og.png at build time using Satori + resvg.
// Falls back gracefully if satori/@resvg/resvg-js are not installed (e.g. fresh clone)
// or if the font cannot be read — so a first-time `npm install && npm run build`
// keeps working and the OG tag will reference an absent image until install completes.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..");
const require = createRequire(import.meta.url);

const outPath = resolve(repoRoot, "public/og.png");

async function loadDeps() {
  try {
    const [{ default: satori }, { Resvg }] = await Promise.all([
      import("satori"),
      import("@resvg/resvg-js"),
    ]);
    return { satori, Resvg };
  } catch (err) {
    console.warn(
      "[generate-og] satori / @resvg/resvg-js not installed yet — skipping og.png generation.",
    );
    console.warn("[generate-og] reason:", err?.message ?? err);
    return null;
  }
}

function loadInterWoff(weightLabel) {
  // @fontsource/inter ships hinted woff files at /files/inter-latin-<weight>-normal.woff.
  // Use createRequire to resolve the package, then read the static file beside it.
  try {
    const pkgJson = require.resolve("@fontsource/inter/package.json");
    const fontPath = resolve(
      dirname(pkgJson),
      `files/inter-latin-${weightLabel}-normal.woff`,
    );
    if (!existsSync(fontPath)) {
      throw new Error(`Font file not found at ${fontPath}`);
    }
    return readFileSync(fontPath);
  } catch (err) {
    throw new Error(
      `Could not load @fontsource/inter (weight ${weightLabel}). ` +
        `Run 'npm install' to install dev dependencies. Original error: ${err.message}`,
    );
  }
}

const colors = {
  bg: "#0a0a0c",
  bgSoft: "#111114",
  line: "#222227",
  fg: "#f4f4f5",
  fgSoft: "#c5c5cb",
  fgMute: "#7a7a82",
  accent: "#7c5cff",
  accent2: "#3ec7a4",
  accent3: "#ff8a5b",
};

const yamlSnippet =
  `rules:
  - host: "*.example.com"
    browser: work_dev
  - source_app: Slack
    browser: work_general
  - cwd: "~/work/*"
    browser: work_dev`;

function template() {
  return {
    type: "div",
    props: {
      style: {
        width: 1200,
        height: 630,
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        padding: 72,
        background: colors.bg,
        color: colors.fg,
        fontFamily: "Inter",
        position: "relative",
      },
      children: [
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              alignItems: "center",
              gap: 12,
              color: colors.fgMute,
              fontSize: 22,
              letterSpacing: 4,
              textTransform: "uppercase",
            },
            children: [
              {
                type: "div",
                props: {
                  style: {
                    width: 10,
                    height: 10,
                    borderRadius: 999,
                    background: colors.accent3,
                  },
                },
              },
              "Triage · macOS · open source",
            ],
          },
        },
        {
          type: "div",
          props: {
            style: { display: "flex", flexDirection: "column", gap: 18 },
            children: [
              {
                type: "div",
                props: {
                  style: {
                    fontSize: 96,
                    fontWeight: 700,
                    lineHeight: 1,
                    letterSpacing: -3,
                    color: colors.fg,
                    display: "flex",
                  },
                  children: "Rule-based, never asks.",
                },
              },
              {
                type: "div",
                props: {
                  style: {
                    fontSize: 30,
                    color: colors.fgSoft,
                    maxWidth: 980,
                    lineHeight: 1.35,
                    display: "flex",
                  },
                  children:
                    "macOS menu-bar app that routes every clicked link to the right browser and Chrome profile, from a single YAML file.",
                },
              },
            ],
          },
        },
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              flexDirection: "column",
              background: colors.bgSoft,
              border: `1px solid ${colors.line}`,
              borderRadius: 14,
              padding: "20px 24px",
              fontFamily: "Inter",
              fontSize: 22,
              color: colors.fgSoft,
              lineHeight: 1.55,
              whiteSpace: "pre",
            },
            children: yamlSnippet,
          },
        },
      ],
    },
  };
}

async function main() {
  const deps = await loadDeps();
  if (!deps) return;
  const { satori, Resvg } = deps;

  const regular = loadInterWoff("400");
  const bold = loadInterWoff("700");

  const svg = await satori(template(), {
    width: 1200,
    height: 630,
    fonts: [
      { name: "Inter", data: regular, weight: 400, style: "normal" },
      { name: "Inter", data: bold, weight: 700, style: "normal" },
    ],
  });

  const png = new Resvg(svg, { fitTo: { mode: "width", value: 1200 } })
    .render()
    .asPng();

  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, png);
  console.log(`[generate-og] wrote ${outPath} (${png.length} bytes)`);
}

main().catch((err) => {
  console.error("[generate-og] failed:", err);
  process.exitCode = 1;
});
