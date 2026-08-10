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

**Asset import:** `asset/**` PNGs (character rotations, monster sprites) have no
`.import` sidecar files committed — Godot generates those during the import step
above. Verified locally against a fully clean `.godot`-less checkout: `--import`
imports every asset under `asset/**` without any manual editor pass.

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
