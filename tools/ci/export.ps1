# Reproducible local/CI export for JOSEONLIKE.
#
# Usage: tools/ci/export.ps1 -Platform android|ios|windows [-BuildType debug|release]
#
# Secrets are never read from export_presets.cfg (committed) — this script
# writes a gitignored export_credentials.cfg at the project root from
# environment variables, which Godot 4.3+ merges over export_presets.cfg
# at export time. See docs/CI.md for the full env var list per platform.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("android", "ios", "windows")]
    [string]$Platform,

    [ValidateSet("debug", "release")]
    [string]$BuildType = "release"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$CredentialsFile = Join-Path $ProjectRoot "export_credentials.cfg"
$GodotBin = if ($env:GODOT) { $env:GODOT } else { "godot" }
$GodotVersion = "4.7.stable"

function Fail($message) {
    Write-Error $message
    exit 1
}

function Require-Env($name) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrEmpty($value)) {
        Fail "$name is required for a release $Platform export"
    }
    return $value
}

if (-not (Get-Command $GodotBin -ErrorAction SilentlyContinue)) {
    Fail "Godot binary not found (looked for '$GodotBin'). Set `$env:GODOT or install Godot $GodotVersion."
}

$templateDirs = @(
    "$env:APPDATA\Godot\export_templates\$GodotVersion",
    "$env:HOME\.local\share\godot\export_templates\$GodotVersion"
) | Where-Object { $_ }

$templatesFound = $false
foreach ($dir in $templateDirs) {
    if (Test-Path $dir) {
        $templatesFound = $true
        break
    }
}
if (-not $templatesFound) {
    Fail "Export templates for Godot $GodotVersion not found. Install them via the editor (Editor > Manage Export Templates) or download Godot_v${GodotVersion}_export_templates.tpz and extract to one of: $($templateDirs -join ', ')"
}

switch ($Platform) {
    "android" {
        $Preset = "Android"
        $OutDir = Join-Path $ProjectRoot "build\android"
        $Out = Join-Path $OutDir "joseonlike.apk"
        if ($BuildType -eq "release") {
            $keystorePath = Require-Env "ANDROID_KEYSTORE_RELEASE_PATH"
            $keystoreUser = Require-Env "ANDROID_KEYSTORE_RELEASE_USER"
            $keystorePassword = Require-Env "ANDROID_KEYSTORE_RELEASE_PASSWORD"
            $debugPath = $env:ANDROID_KEYSTORE_DEBUG_PATH
            $debugUser = $env:ANDROID_KEYSTORE_DEBUG_USER
            $debugPassword = $env:ANDROID_KEYSTORE_DEBUG_PASSWORD
            @"
[preset.0.options]

keystore/release="$keystorePath"
keystore/release_user="$keystoreUser"
keystore/release_password="$keystorePassword"
keystore/debug="$debugPath"
keystore/debug_user="$debugUser"
keystore/debug_password="$debugPassword"
"@ | Set-Content -Path $CredentialsFile -Encoding UTF8
        }
    }
    "ios" {
        $Preset = "iOS"
        $OutDir = Join-Path $ProjectRoot "build\ios"
        $Out = Join-Path $OutDir "joseonlike.ipa"
        if ($BuildType -eq "release") {
            $teamId = Require-Env "IOS_TEAM_ID"
            $codeSignIdentity = Require-Env "IOS_CODE_SIGN_IDENTITY_RELEASE"
            $provisioningUuid = Require-Env "IOS_PROVISIONING_PROFILE_UUID_RELEASE"
            $debugUuid = $env:IOS_PROVISIONING_PROFILE_UUID_DEBUG
            @"
[preset.1.options]

application/app_store_team_id="$teamId"
application/code_sign_identity_release="$codeSignIdentity"
application/provisioning_profile_uuid_release="$provisioningUuid"
application/provisioning_profile_uuid_debug="$debugUuid"
"@ | Set-Content -Path $CredentialsFile -Encoding UTF8
        }
    }
    "windows" {
        $Preset = "Windows Desktop"
        $OutDir = Join-Path $ProjectRoot "build\windows"
        $Out = Join-Path $OutDir "joseonlike.exe"
        if ($BuildType -eq "release" -and $env:WINDOWS_CODESIGN_IDENTITY) {
            $codesignPassword = Require-Env "WINDOWS_CODESIGN_PASSWORD"
            @"
[preset.2.options]

codesign/identity="$($env:WINDOWS_CODESIGN_IDENTITY)"
codesign/password="$codesignPassword"
"@ | Set-Content -Path $CredentialsFile -Encoding UTF8
        }
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$exportFlag = if ($BuildType -eq "debug") { "--export-debug" } else { "--export-release" }

Write-Host "Exporting $Preset ($BuildType) -> $Out"
& $GodotBin --headless --path $ProjectRoot $exportFlag $Preset $Out
$exportExit = $LASTEXITCODE

if (Test-Path $CredentialsFile) {
    Remove-Item $CredentialsFile -Force
}

if ($exportExit -ne 0) {
    Fail "Godot export exited with status $exportExit"
}

Write-Host "Done: $Out"
