# CI, Testing & Export

## Running tests locally

Requires Godot **4.7-stable** (`godot --version` should print `4.7.stable...`). Run an
import pass first — `tests/run_tests.gd` needs `res://.godot/global_script_class_cache.cfg`
to resolve bare `class_name` identifiers in test files, and that cache is gitignored:

```sh
godot --headless --path . --import
godot --headless --path . --script tests/run_tests.gd
```

Exits 0 and prints `PASS <N> file(s): <N> passed, 0 failed, 0 errored` when every
`tests/**/test_*.gd` file's `run()` returns an empty array. Otherwise it prints one
`ERROR`/`FAIL` line per problem plus a `<N> file(s): P passed, F failed, E errored`
summary and exits 1 — a suite that fails to compile, can't be instantiated, or lacks
`run()` counts as `ERROR`, not a skip. A `_process` backstop guarantees this exit even
if a suite's `run()` aborts mid-call (previously this hung forever instead of failing).

**Known runner gap: autoload `_ready()` never fires here.** Bare `class_name`/autoload
identifiers resolve fine (see the import-cache note above), but under this custom
`SceneTree` main loop the autoload singletons' own `_ready()` callback is never
invoked — only under a real game run (`godot --headless --path . --quit`) does that
fire. A test that depends on `_ready()`-driven setup (e.g. a timer built in `_ready`)
will silently pass without exercising that code. Drive the underlying behavior
directly instead (e.g. call the timer's callback method, not `Timer.start()`, which
also refuses to run outside a live scene tree) — see `tests/core/test_save_manager.gd`
for a worked example.

## Running data validation locally

`tools/validate_data.gd` checks that every cross-file id reference in `data/**`
resolves. CI treats a missing file as a skipped step with a warning, not a failure:

```sh
godot --headless --path . --script tools/validate_data.gd
```

## What CI does (`.github/workflows/ci.yml`)

On every push and pull request:

1. Downloads and caches the pinned Godot **4.7-stable** binary (never "latest" — a
   silent engine bump is exactly the failure mode the pin exists to prevent).
2. Restores the `.godot` cache, keyed by a hash of scenes/resources/imports.
3. **Imports the project headlessly (`godot --headless --path . --import`) — this is
   the authoritative step.** It always runs, whether or not the `.godot` cache above
   hit, because a cache hit can carry a stale/absent
   `global_script_class_cache.cfg` from before new `class_name` scripts or assets
   (e.g. `asset/**`) landed. `--import` (no `--quit`) is the dedicated
   headless-import-and-exit mode; `--import --quit` was dropped per core-engine's
   root-cause finding that it opens the full editor and can exit before the class
   cache write is flushed to disk — the exact bug that made bare `class_name`
   references randomly fail to compile in CI.
4. Runs `tests/run_tests.gd`.
5. Runs `tools/validate_data.gd` if present, else logs a `::warning::` and skips.

**Known local-only quirk: intermittent exit 139 on Windows after `--import` completes.**
`godot --headless --path . --import` has been observed on Windows dev machines to
segfault (exit 139) *after* the `[ DONE ] reimport` line prints — a crash during
process teardown once the actual import work is already done, roughly one run in
eight, only with `.godot` already present, gone on an immediate re-run. This is a
teardown crash, not a failed import, and it has not been reproduced on Linux: 40
consecutive warm runs of the exact same command on the actual `ubuntu-latest` GitHub
Actions runner all exited 0
(https://github.com/CastleBelll/joseonlike/actions/runs/31384597597). If you hit
`exit 139` running this locally on Windows, it is this known issue, not your change —
re-run once and move on. **CI itself is not exposed** (no step was added to tolerate
it, on purpose: a step that silently swallows a real Linux failure would be worse
than the flake it's working around). If this ever reproduces on a GitHub runner,
that would be new information and should reopen this — the conclusion above is
"unaffected so far under real testing," not "provably impossible."

**GDScript-error gate:** Godot can exit 0 in some headless paths even when a script
has a parse/compile error. Every step's output is captured and grepped for
`SCRIPT ERROR` / `Parse Error`; a match fails the job explicitly, regardless of the
process exit code. Verified on a real GitHub Actions run against the rewritten
`tests/run_tests.gd` (which now exits nonzero via its own `_process` backstop instead
of hanging): a broken `tests/test_*.gd` file fails the job.

**Known limitation, verified on a real GitHub Actions run:** a `.gd` file that
nothing references yet (no scene, no autoload, not preloaded, no test file
loads it) is never compiled by Godot at all — during import, during a
headless game boot, or in the shipped game itself — so a syntax error in a
genuinely orphaned file will not fail CI. Confirmed by pushing a deliberately
broken, unreferenced file under `scripts/services/` to a throwaway branch:
the real run came back green
(https://github.com/CastleBelll/joseonlike/actions/runs/31362918354). This
isn't a gap specific to this workflow; it's how Godot's script loading works.
Wire new scripts into a scene/autoload/test as soon as they're written to get
gate coverage.

**Asset import policy:** `.import` sidecar files are **not tracked** (`*.import`
is gitignored) — Godot regenerates them with default params during the import step
above. Verified against a fresh clone with zero `.import` files present: `--import`
imports every asset without errors or a manual editor pass.

**The one exception: `asset/font/neodgm.ttf.import` is tracked** (gitignore
whitelist `!asset/font/neodgm.ttf.import`). It carries non-default pixel-font
import params (`antialiasing=0` plus the matching hinting/subpixel settings)
that a default regeneration would lose, making the UI font blurry. Godot honors
a pre-existing `.import` file's params on first import, so committing this one
file preserves the setting on fresh clones with no manual re-import step. If you
customize import params on any other asset, whitelist its `.import` the same
way — otherwise the customization silently disappears for everyone else.

## Exporting per platform

Presets live in `export_presets.cfg` (Android arm64 / GL Compatibility / portrait,
iOS, Windows Desktop). It never contains secrets — keystore paths, iOS signing
identity, and provisioning profile UUIDs are blank there and are injected at export
time from environment variables into a local `export_credentials.cfg` (gitignored,
deleted after export).

Prerequisites: Godot 4.7-stable installed, and the matching export templates
installed for that exact version (Editor > Manage Export Templates, or download
`Godot_v4.7-stable_export_templates.tpz`). Both scripts preflight-check this and
fail with a clear message if templates are missing.

```sh
# macOS/Linux
tools/ci/export.sh android release
tools/ci/export.sh ios release
tools/ci/export.sh windows release

# Windows
tools/ci/export.ps1 -Platform android -BuildType release
```

`debug` builds don't require signing env vars; `release` builds do.

### Required secrets per platform (release builds)

| Platform | Env var | Purpose |
|---|---|---|
| Android | `ANDROID_KEYSTORE_RELEASE_PATH` | Path to the release `.keystore`/`.jks` |
| Android | `ANDROID_KEYSTORE_RELEASE_USER` | Keystore alias |
| Android | `ANDROID_KEYSTORE_RELEASE_PASSWORD` | Keystore password |
| Android | `ANDROID_KEYSTORE_DEBUG_PATH` / `_USER` / `_PASSWORD` | Optional debug keystore override |
| iOS | `IOS_TEAM_ID` | Apple Developer Team ID |
| iOS | `IOS_CODE_SIGN_IDENTITY_RELEASE` | Signing identity, e.g. `iPhone Distribution` |
| iOS | `IOS_PROVISIONING_PROFILE_UUID_RELEASE` | Provisioning profile UUID |
| iOS | `IOS_PROVISIONING_PROFILE_UUID_DEBUG` | Optional debug profile UUID |
| Windows | `WINDOWS_CODESIGN_IDENTITY` / `WINDOWS_CODESIGN_PASSWORD` | Optional; only used if `WINDOWS_CODESIGN_IDENTITY` is set |

None of these are read from `export_presets.cfg`, logged, or committed. A maintainer
running CI-driven release exports must configure them as CI secrets (e.g. GitHub
Actions repository/environment secrets); local exports read them from the shell
environment.

## Web build and itch.io deploy (`.github/workflows/web-deploy.yml`)

Pushing to `main` builds the `Web` preset (WASM) and publishes it to itch.io
via butler (owner 2026-08-22: Vercel is retired; itch.io is the only web
channel). `workflow_dispatch` runs it on demand.

- `paths-ignore` skips commits that touch only `*.md`, `captures/`,
  `new_asset/`, `docs/` or `.github/` — none of those reach the export.
- `concurrency: web-deploy` with `cancel-in-progress` publishes the newest
  commit of a burst instead of every one in turn.

**Cross-origin isolation is mandatory, not optional.** Godot 4's web runtime
uses `SharedArrayBuffer` and refuses to start without
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp`. On itch.io this is the
**SharedArrayBuffer support** checkbox in the project's embed options — set
once by hand when the page was created. Any other host has to send those two
headers itself or the page loads and then sits blank.

**The build always runs; the deploy is conditional.** Without the butler
secret the job still exports, verifies and uploads the artifact, then logs a
notice and stops — the export stays a real check on every push and a fork
never goes red over a secret it cannot have.

### Connecting itch.io (one-time, needs a human)

1. Create the itch.io project by hand once (kind: HTML, upload any web zip,
   check "played in the browser", set viewport 540x960, mobile friendly, and
   SharedArrayBuffer support).
2. itch.io → Settings → API keys → generate a key → save it as the
   `BUTLER_API_KEY` repository secret (Settings → Secrets and variables →
   Actions → Secrets).
3. Add the `ITCH_TARGET` repository **variable** (same page, Variables tab):
   `<account>/<project>:html5`, e.g. `owner/joseonlike:html5`.

butler pushes are diffs, so repeat deploys are fast; `--userversion` stamps
each itch build with the commit sha that produced it. The N9-108
sha-fingerprint rename existed only for Vercel's immutable cache and is
retired with it — itch serves uploads from its own versioned CDN.

### Two traps this workflow guards, and why

- **Import before export.** `.import` sidecars are untracked here, so an export
  on a fresh checkout would ship missing resources rather than fail loudly.
- **The import runs twice and only the second pass is checked.** On a cold
  `.godot`, `asset/ui_theme.tres` is parsed before the font it references and
  reports `Parse Error: referenced non-existent resource`; it resolves on the
  next pass. Checking the first pass turns that ordering artifact into a red
  build (observed in run 32218173780). Only an error that survives a second
  full import is real.
  **`ci.yml` still has the single-pass version** and passes only because its
  `.godot` cache is warm — a cache eviction will fail main's CI this way.
- **Exit code zero is not proof of an export.** `index.html`, `index.wasm` and
  `index.pck` are each checked for existence and non-zero size, because an
  export missing the wasm is exactly what would deploy a blank page.

### Known limits of the web build

- The three BGM tracks are ~17MB together and load over the network before the
  game starts. Re-encoding to OGG for web would cut this substantially.
- Saves go to IndexedDB, so they are per-browser and per-profile and vanish
  when site data is cleared. Fine for playtesting, not for a release.
- The game is authored for 540x960 portrait; on a desktop browser it letterboxes.

## Services

`scripts/services/ads.gd` (`AdsService`) and `scripts/services/analytics.gd`
(`AnalyticsService`) are M1 no-op stubs — no ad or analytics SDK is integrated yet.
Gameplay/meta code can call `show_rewarded()`, `show_interstitial()`, `is_available()`,
and `log_event()` today; each file's header comment documents which SDK it's shaped
for and what real integration requires.


## QA 워크트리 사전 절차 (N11 게이트 I-2)

`git add --renormalize .` 은 **인덱스만** 정규화한다 — CRLF로 체크아웃된 워킹 트리는
그대로 남아 멀티라인 문자열 리터럴에 을 끼워 넣고, 테스트가 "3/600 실패"처럼
제품 회귀로 위장한다(2026-08-28 landscape QA, 2026-08-30 통합 게이트 — 220파일).
QA 워크트리는 측정 전에 반드시:

```sh
git config core.autocrlf false
git add --renormalize . && git checkout-index --force -a   # 워킹 트리까지 LF
git ls-files '*.gd' '*.tscn' '*.json' '*.tres'   | xargs grep -lU $'' && echo "CRLF LEFT — 게이트 중단"
```
