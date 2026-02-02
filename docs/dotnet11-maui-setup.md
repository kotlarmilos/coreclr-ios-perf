# Building net11.0-ios MAUI Apps with .NET 11 SDK

**Date:** 2026-01-30  
**Status:** ✅ Working

## Problem

The .NET 11 SDK preview doesn't have a MAUI workload manifest for the 11.0.100 feature band. The MAUI workload manifest lives at `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.maui/10.0.0/` and only references net10.0 and net9.0 packs.

Building a MAUI app with `net11.0-ios` fails because:
1. The manifest doesn't include `Microsoft.Maui.Sdk.net11` pack references
2. The `WorkloadManifest.targets` has no import for `TargetFrameworkVersion == '11.0'`

## Solution

Manually edit the MAUI workload manifest files to add net11.0 support, then install the packs from the dotnet11 feed.

### Prerequisites

- .NET 11 SDK installed (e.g., at `~/.dotnet11`)
- iOS workload already patched for net11.0 (see `dotnet11-ios-setup.md`)
- Xcode 26.2
- iOS 26.2 Simulator

### Step 1: Backup Original Files

```bash
cp ~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.maui/10.0.0/WorkloadManifest.json \
   ~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.maui/10.0.0/WorkloadManifest.json.bak
cp ~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.maui/10.0.0/WorkloadManifest.targets \
   ~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.maui/10.0.0/WorkloadManifest.targets.bak
```

### Step 2: Edit WorkloadManifest.json

File: `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.maui/10.0.0/WorkloadManifest.json`

#### 2a. Add net11 packs to the `maui-core` workload's `packs` array:

```json
"maui-core": {
  "abstract": true,
  "description": ".NET MAUI SDK Core Packages",
  "packs": [
      "Microsoft.Maui.Sdk.net11",        // ADD
      "Microsoft.Maui.Sdk.net10",
      "Microsoft.Maui.Sdk.net9",
      "Microsoft.Maui.Graphics",
      "Microsoft.Maui.Resizetizer",
      "Microsoft.Maui.Templates.net11",  // ADD
      "Microsoft.Maui.Templates.net10",
      "Microsoft.Maui.Templates.net9",
      ...
  ]
},
```

#### 2b. Add net11 pack definitions to the `packs` section:

```json
"packs": {
    "Microsoft.Maui.Sdk.net11": {
      "kind": "sdk",
      "version": "11.0.0-ci.net11.26079.5",
      "alias-to": {
        "any": "Microsoft.Maui.Sdk"
      }
    },
    "Microsoft.Maui.Templates.net11": {
      "kind": "template",
      "version": "11.0.0-ci.net11.26079.5"
    },
    ...
}
```

#### 2c. Update all library pack versions to net11:

```json
"Microsoft.AspNetCore.Components.WebView.Maui": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
"Microsoft.Maui.Core": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
"Microsoft.Maui.Controls": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
"Microsoft.Maui.Controls.Build.Tasks": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
"Microsoft.Maui.Controls.Core": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
"Microsoft.Maui.Controls.Xaml": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
"Microsoft.Maui.Controls.Compatibility": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
"Microsoft.Maui.Essentials": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
"Microsoft.Maui.Graphics": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
"Microsoft.Maui.Resizetizer": {
  "kind": "library",
  "version": "11.0.0-ci.net11.26079.5"
},
```

### Step 3: Edit WorkloadManifest.targets

File: `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.maui/10.0.0/WorkloadManifest.targets`

Add import for net11.0 **before** the net10.0 import:

```xml
<Import
    Condition=" ('$(UseMaui)' == 'true' or '$(UseMauiCore)' == 'true' or '$(UseMauiEssentials)' == 'true' or '$(UseMauiAssets)' == 'true') and ($([MSBuild]::VersionEquals($(TargetFrameworkVersion), '11.0'))) and ('$(SkipMauiWorkloadManifest)' != 'true') "
    Project="Sdk.targets" Sdk="Microsoft.Maui.Sdk.net11"
/>
<Import
    Condition=" ('$(UseMaui)' == 'true' or '$(UseMauiCore)' == 'true' or '$(UseMauiEssentials)' == 'true' or '$(UseMauiAssets)' == 'true') and ($([MSBuild]::VersionEquals($(TargetFrameworkVersion), '10.0'))) and ('$(SkipMauiWorkloadManifest)' != 'true') "
    Project="Sdk.targets" Sdk="Microsoft.Maui.Sdk.net10"
/>
```

### Step 4: Install the MAUI Workload with net11 Packs

```bash
~/.dotnet11/dotnet workload install maui \
    --skip-manifest-update \
    --source "https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet11/nuget/v3/index.json" \
    --source "https://api.nuget.org/v3/index.json"
```

This will install:
- `Microsoft.Maui.Sdk` version `11.0.0-ci.net11.26079.5`
- `Microsoft.Maui.Templates.net11` version `11.0.0-ci.net11.26079.5`
- `Microsoft.Maui.Core` version `11.0.0-ci.net11.26079.5`
- `Microsoft.Maui.Controls` version `11.0.0-ci.net11.26079.5`
- `Microsoft.Maui.Controls.Build.Tasks` version `11.0.0-ci.net11.26079.5`
- `Microsoft.Maui.Controls.Core` version `11.0.0-ci.net11.26079.5`
- `Microsoft.Maui.Controls.Xaml` version `11.0.0-ci.net11.26079.5`
- `Microsoft.Maui.Essentials` version `11.0.0-ci.net11.26079.5`
- `Microsoft.Maui.Graphics` version `11.0.0-ci.net11.26079.5`
- `Microsoft.Maui.Resizetizer` version `11.0.0-ci.net11.26079.5`
- `Microsoft.AspNetCore.Components.WebView.Maui` version `11.0.0-ci.net11.26079.5`

### Step 5: Create a MAUI Project

```bash
mkdir -p ~/maui-test && cd ~/maui-test
~/.dotnet11/dotnet new maui -n MauiNet11Test
```

**Note:** The template already generates `net11.0-*` target frameworks!

### Step 6: Configure NuGet.config

Create `NuGet.config` in your project directory to include the dotnet11 feed (required for Microsoft.Extensions packages):

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="dotnet11" value="https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet11/nuget/v3/index.json" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
```

### Step 7: Update .csproj for iOS-only (Optional)

If you only want to target iOS (Android workload not yet patched), update the `TargetFrameworks`:

```xml
<PropertyGroup>
    <TargetFrameworks>net11.0-ios;net11.0-maccatalyst</TargetFrameworks>
    ...
</PropertyGroup>
```

### Step 8: Build

```bash
cd ~/maui-test/MauiNet11Test
~/.dotnet11/dotnet build -f net11.0-ios -c Release
```

## Root Cause Analysis

1. **Workload manifest location**: The MAUI manifest is at `sdk-manifests/10.0.100/` (not `11.0.100/`), so the .NET 11 SDK uses the .NET 10 MAUI workload.

2. **Missing net11.0 in WorkloadManifest.json**: The manifest only listed `net10.0` and `net9.0` SDK packs.

3. **Missing net11.0 imports in WorkloadManifest.targets**: The targets file had no `Import` for `TargetFrameworkVersion == '11.0'`.

4. **The net11.0 packs ARE published** to the dotnet11 feed (version `11.0.0-ci.net11.26079.5`), but the manifest doesn't reference them.

5. **Microsoft.Extensions packages** also need the dotnet11 feed since they have `11.0.0-alpha.1.*` versions not on nuget.org yet.

## Files Modified

- `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.maui/10.0.0/WorkloadManifest.json`
- `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.maui/10.0.0/WorkloadManifest.targets`

## Environment

- macOS (Darwin) arm64
- .NET 11 SDK: 11.0.100-preview.2.26079.117
- MAUI Workload: 10.0.0 (modified)
- MAUI SDK Pack: 11.0.0-ci.net11.26079.5
- iOS Workload: 26.0.11017 (modified for net11.0)
- iOS SDK Pack: 26.2.11303-net11-p2
- Xcode: 26.2
- iOS Simulator: 26.2

## NuGet Feed

```
https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet11/nuget/v3/index.json
```

## Known Limitations

- **Android not supported yet**: The Android workload manifest also needs patching for `net11.0-android`
- **MacCatalyst partially works**: Uses iOS workload, should work if iOS is patched
- **Windows not tested**: Would need Windows workload patches

## Related Documentation

- `dotnet11-ios-setup.md` - iOS workload patching (prerequisite)
- `dotnet-ios-test-results.md` - Initial iOS testing results
