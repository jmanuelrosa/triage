export interface FaqEntry {
  question: string;
  /** Visible HTML — also used verbatim in FAQPage JSON-LD. */
  answerHtml: string;
}

export const faqEntries: FaqEntry[] = [
  {
    question: "What is Triage?",
    answerHtml:
      "Triage is a free, open-source macOS menu-bar app that routes every clicked link to the right browser — and the right Chrome profile — based on rules you write in a YAML file. It is written in pure Swift (~500 lines), has no dock icon, and never asks you to pick a browser.",
  },
  {
    question: "Is Triage free and open source?",
    answerHtml:
      "Yes. Triage is MIT-licensed and developed in the open at <a href=\"https://github.com/jmanuelrosa/triage\">github.com/jmanuelrosa/triage</a>. There is no paid tier, no telemetry by default, and no account is required to use it.",
  },
  {
    question: "What macOS versions does Triage support?",
    answerHtml:
      "Triage runs on macOS 13 (Ventura) or later. It ships as a universal binary, so it runs natively on both Apple Silicon (M1, M2, M3, M4) and Intel Macs. The app is daily-driven on the latest macOS release.",
  },
  {
    question: "How does Triage compare to Velja, Finicky, Browserosaurus, and Choosy?",
    answerHtml:
      "Triage is rule-first and picker-free, like Finicky, but configured in YAML instead of JavaScript. Velja and Choosy lean on a graphical picker; Browserosaurus is an Electron picker. Triage is also fully free and open-source, where Velja and Choosy are paid or freemium.",
  },
  {
    question: "Can Triage route links to different Chrome profiles?",
    answerHtml:
      "Yes — Chrome profile routing is first-class. You reference profiles by their friendly display name in YAML (for example <code>\"Work [Dev]\"</code>) and Triage resolves them to Chrome's internal directory names by reading Chrome's <code>Local State</code> file.",
  },
  {
    question: "Does Triage ever ask which browser to use?",
    answerHtml:
      "No. Triage is rules-only and never shows a picker. Every URL is evaluated against your YAML config top-down, first-match-wins. URLs that match no rule open in your previous default browser (captured automatically the first time you launch Triage).",
  },
  {
    question: "How do I write rules?",
    answerHtml:
      "Rules live in <code>~/.config/triage/config.yaml</code> as a list of objects with optional <code>host</code>, <code>path</code>, and <code>source_app</code> matchers plus a target <code>browser</code>. Save the file and Triage live-reloads. Broken YAML triggers a modal alert with a plain-text error log.",
  },
  {
    question: "Can Triage match links by the source app, like Slack or WhatsApp?",
    answerHtml:
      "Yes. Each rule can include a <code>source_app</code> matcher, so you can send every link clicked from Slack to your work browser, every link clicked from WhatsApp to your personal browser, and so on — independent of the URL itself.",
  },
  {
    question: "What happens to a link that doesn't match any rule?",
    answerHtml:
      "Triage opens it in your previous default browser, which it captures automatically the first time you set Triage as the system default. You can change the fallback at any time from the menu-bar item, without editing the YAML.",
  },
  {
    question: "How do I install Triage?",
    answerHtml:
      "Recommended: <code>brew install --cask jmanuelrosa/tap/triage</code>. Homebrew handles the Gatekeeper quarantine and updates via <code>brew upgrade --cask triage</code>. You can also use the curl install script, download the DMG from GitHub Releases, or build from source.",
  },
  {
    question: "Is Triage code-signed and notarized?",
    answerHtml:
      "Not yet — Triage is currently an unsigned beta. Homebrew users get the quarantine attribute stripped automatically. DMG users need to right-click Triage.app and choose Open the first time. Code signing and notarization are on the roadmap before the 1.0 release.",
  },
];
