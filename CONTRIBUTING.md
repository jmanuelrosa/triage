# Contributing to Triage

Thanks for your interest. Triage is a small, opinionated project — keeping it small is a feature — but issues, fixes, and well-scoped feature PRs are welcome.

## Before opening an issue

- **Search existing issues first.** Especially the closed ones; some questions have prior answers.
- **For bug reports**, include the relevant excerpt from `~/.config/triage/triage.log` and the output of:

  ```sh
  log show --predicate 'subsystem == "com.jmrosamoncayo.triage"' --info --last 5m
  ```

- **For feature requests**, explain the *workflow* the feature unblocks. Triage is intentionally narrow — features that would push it toward "general-purpose router" or "rules editor UI" are unlikely to land. See [`README.md`'s comparison section](./README.md#-how-it-compares) for the niche it fills.
- **For questions / "is this the right tool for me"**, please use [GitHub Discussions](https://github.com/jmanuelrosa/triage/discussions) instead of opening an issue.

## Development setup

**Requirements**
- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`) — full Xcode is not required for local development

**Clone and verify**

```sh
git clone https://github.com/jmanuelrosa/triage.git
cd triage
swift test
```

You should see `Test run with N tests passed`. If not, paste the failure into a draft issue before going further.

**Run a local build**

```sh
./Scripts/build.sh           # release config, native arch
./Scripts/build.sh debug     # debug config (faster compile, slower runtime)
```

This produces `Triage.app` in the repo root. To test it as your default browser:

```sh
cp -R Triage.app /Applications/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Triage.app
open /Applications/Triage.app
```

Then **System Settings → Desktop & Dock → Default web browser → Triage**. Stream live logs with:

```sh
log stream --predicate 'subsystem == "com.jmrosamoncayo.triage"' --info
```

## Code organization

```
Sources/
  TriageCore/        # Pure logic, AppKit-free, fully unit-tested.
                     # Adding new logic? It probably belongs here.
  triage/            # Executable. AppKit, Apple Events, NSWorkspace.
                     # The thin layer that wires Core into a running app.
Tests/
  TriageCoreTests/   # swift-testing (NOT XCTest). Mirror the type names
                     # you're testing in the file name.
Scripts/
  build.sh           # Compile + bundle + sign.
  install.sh         # End-user installer (curl|bash).
  release.sh         # Maintainer release helper.
.github/workflows/
  ci.yml             # Tests on every push + PR.
  release.yml        # Tag-driven release pipeline.
```

## Conventions

- **Tests use `swift-testing`, not XCTest** (Command Line Tools doesn't ship XCTest). Use `@Test` and `#expect`. See `Tests/TriageCoreTests/RuleMatcherTests.swift` for shape.
- **No new dependencies casually.** The current set (Yams, swift-testing) is the entire dependency budget for v1. Adding to it requires a strong case in the PR description.
- **Public types in `TriageCore` are marked `public`**; everything else stays internal. Don't widen access without need.
- **Comments explain *why*, not *what*.** The codebase already has examples (`URLHandler.swift`'s loop-protection block, `Info.plist`'s `LSUIElement` rationale).
- **Commit messages**: lowercase imperative, focused. Match the existing style:
  - ✅ `add ChromeProfileResolver: friendly profile name → directory name`
  - ✅ `wire URL routing pipeline end-to-end`
  - ❌ `Updated some files`

## Pull requests

1. **One concern per PR.** A bug fix and a refactor in the same PR is two PRs.
2. **Tests for new logic.** If it lives in `TriageCore`, it needs a test. UI-side code (`AppDelegate`, menu rendering) is exempt — those paths are exercised manually.
3. **Run `swift test` locally before pushing.** CI will catch regressions but the feedback loop is faster locally.
4. **Update `CHANGELOG.md`** under the `[Unreleased]` section if your change affects users (new feature, behavior change, fix). Internal refactors don't need a changelog entry.
5. **Expect review from [@jmanuelrosa](https://github.com/jmanuelrosa)** (see `.github/CODEOWNERS`). Solo-maintained project; allow a few days.

## Out-of-scope changes

These will likely be closed without merge — please open a discussion first if you want to argue otherwise:

- A graphical rules editor / preferences window. The YAML *is* the UI.
- A picker UI for unmatched URLs. Triage's whole point is *not* asking.
- Auto-learning rules from observed clicks.
- Universal scheme handling beyond `http`/`https` (PDFs, Zoom, Figma deep links, etc.).
- Migrations from Velja / Finicky / Choosy configs.
- Windows / Linux ports.

## License

Triage is [MIT-licensed](./LICENSE). Contributions are accepted under the same terms.
