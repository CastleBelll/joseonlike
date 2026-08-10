# CI, Testing & Export

## Running tests locally

Requires Godot **4.7-stable** (`godot --version` should print `4.7.stable...`).

```sh
godot --headless --path . --script tests/run_tests.gd
```

Exits 0 and prints `PASS` when every `tests/**/test_*.gd` file's `run()` returns an
empty array; exits 1 and prints `FAIL <message>` per failure otherwise.

## Running data validation locally

`content-data` owns `tools/validate_data.gd`. Until it lands, this step doesn't exist
yet — CI treats a missing file as a skipped step with a warning, not a failure:

```sh
godot --headless --path . --script tools/validate_data.gd
```

## What CI does (`.github/workflows/ci.yml`)

On every push and pull request:

1. Downloads and caches the pinned Godot **4.7-stable** binary (never "latest" — a
   silent engine bump is exactly the failure mode the pin exists to prevent).
2. Caches the `.godot` import folder, keyed by a hash of scenes/resources, so
   re-imports are fast on unchanged content.
3. Imports the project headlessly (`--import --quit`).
4. Runs `tests/run_tests.gd`.
5. Runs `tools/validate_data.gd` if present, else logs a `::warning::` and skips.

**GDScript-error gate:** Godot can exit 0 in some headless paths even when a script
has a parse/compile error. Every step's output is captured and grepped for
`SCRIPT ERROR` / `Parse Error`; a match fails the job explicitly, regardless of the
process exit code. Verified locally: a broken script wired into
`tests/run_tests.gd`'s discovery path (i.e. a `tests/test_*.gd` file) reliably
fails the run with `SCRIPT ERROR`/`Parse Error` in the output.

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

## Services

`scripts/services/ads.gd` (`AdsService`) and `scripts/services/analytics.gd`
(`AnalyticsService`) are M1 no-op stubs — no ad or analytics SDK is integrated yet.
Gameplay/meta code can call `show_rewarded()`, `show_interstitial()`, `is_available()`,
and `log_event()` today; each file's header comment documents which SDK it's shaped
for and what real integration requires.
