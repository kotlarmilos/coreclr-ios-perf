# Building net11.0-ios with .NET 11 SDK

**Date:** 2026-01-30  
**Status:** ✅ Working

## Problem

The .NET 11 SDK preview doesn't have an iOS workload manifest for the 11.0.100 feature band. The iOS workload manifest lives at `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.ios/` (note: **10.0.100**, not 11.0.100) and only references net10.0 and net9.0 packs.

Building with `net11.0-ios` fails with:
```
error NETSDK1073: The FrameworkReference 'Microsoft.iOS' was not recognized
error NETSDK1073: The FrameworkReference 'Microsoft.iOS.Runtimes' was not recognized
```

## Solution

Manually edit the workload manifest files to add net11.0 support, then install the packs from the dotnet11 feed.

### Prerequisites

- .NET 11 SDK installed (e.g., at `~/.dotnet11`)
- Xcode 26.2
- iOS 26.2 Simulator

### Step 1: Edit WorkloadManifest.json

File: `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.ios/26.0.11017/WorkloadManifest.json`

Add net11.0 packs to the `"ios"` workload's `"packs"` array:
```json
"packs": [
    "Microsoft.iOS.Sdk.net11.0_26.2",        // ADD
    "Microsoft.iOS.Sdk.net10.0_26.0",
    ...
    "Microsoft.iOS.Ref.net11.0_26.2",        // ADD
    "Microsoft.iOS.Ref.net10.0_26.0",
    "Microsoft.iOS.Runtime.ios-arm64.net11.0_26.2",        // ADD
    "Microsoft.iOS.Runtime.ios.net10.0_26.0",
    ...
    "Microsoft.iOS.Runtime.iossimulator-x64.net11.0_26.2",   // ADD
    "Microsoft.iOS.Runtime.iossimulator-x64.net10.0_26.0",
    "Microsoft.iOS.Runtime.iossimulator-arm64.net11.0_26.2", // ADD
    "Microsoft.iOS.Runtime.iossimulator-arm64.net10.0_26.0",
    ...
]
```

Add net11.0 pack definitions to the `"packs"` section:
```json
"packs": {
    "Microsoft.iOS.Sdk.net11.0_26.2": {
        "kind": "sdk",
        "version": "26.2.11303-net11-p2"
    },
    ...
    "Microsoft.iOS.Ref.net11.0_26.2": {
        "kind": "framework",
        "version": "26.2.11303-net11-p2"
    },
    "Microsoft.iOS.Runtime.ios-arm64.net11.0_26.2": {
        "kind": "framework",
        "version": "26.2.11303-net11-p2"
    },
    "Microsoft.iOS.Runtime.iossimulator-x64.net11.0_26.2": {
        "kind": "framework",
        "version": "26.2.11303-net11-p2"
    },
    "Microsoft.iOS.Runtime.iossimulator-arm64.net11.0_26.2": {
        "kind": "framework",
        "version": "26.2.11303-net11-p2"
    },
    ...
}
```

### Step 2: Edit WorkloadManifest.targets

File: `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.ios/26.0.11017/WorkloadManifest.targets`

Add import groups for net11.0 at the beginning (after `<Project>`):

```xml
<ImportGroup Condition=" '$(TargetPlatformIdentifier)' == 'iOS' And '$(UsingAppleNETSdk)' != 'true' And $([MSBuild]::VersionEquals($(TargetFrameworkVersion), '11.0')) And '$(TargetPlatformVersion)' == '26.2'">
    <Import Project="Sdk.props" Sdk="Microsoft.iOS.Sdk.net11.0_26.2" />
</ImportGroup>

<ImportGroup Condition=" '$(TargetPlatformIdentifier)' == 'iOS' And '$(UsingAppleNETSdk)' != 'true' And $([MSBuild]::VersionEquals($(TargetFrameworkVersion), '11.0'))">
    <Import Project="Sdk.props" Sdk="Microsoft.iOS.Sdk.net11.0_26.2" />
</ImportGroup>
```

Also update the fallback at the bottom to use net11.0 for versions > 11.0:
```xml
<Import Project="Sdk.props" Sdk="Microsoft.iOS.Sdk.net11.0_26.2" Condition=" $([MSBuild]::VersionGreaterThan($(TargetFrameworkVersion), '11.0'))" />
```

### Step 3: Install the net11.0 packs

```bash
~/.dotnet11/dotnet workload install ios \
    --skip-manifest-update \
    --source "https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet11/nuget/v3/index.json"
```

This will install the net11.0 packs from the dotnet11 feed:
- `Microsoft.iOS.Sdk.net11.0_26.2`
- `Microsoft.iOS.Ref.net11.0_26.2`
- `Microsoft.iOS.Runtime.ios-arm64.net11.0_26.2`
- `Microsoft.iOS.Runtime.iossimulator-arm64.net11.0_26.2`
- `Microsoft.iOS.Runtime.iossimulator-x64.net11.0_26.2`

### Step 4: Install Xcode 26.2 and iOS 26.2 Simulator

```bash
# Update Xcode via App Store to 26.2

# Install iOS 26.2 Simulator
xcodebuild -downloadPlatform iOS
```

### Step 5: Build

```bash
cd ~/ios-test
~/.dotnet11/dotnet build -f net11.0-ios \
    -p:UseMonoRuntime=false \
    -p:PublishReadyToRun=true \
    -c Release \
    /bl
```

## Root Cause Analysis

1. **Workload manifest location**: The iOS manifest is at `sdk-manifests/10.0.100/` (not `11.0.100/`), so the .NET 11 SDK uses the .NET 10 iOS workload.

2. **Missing net11.0 in WorkloadManifest.json**: The manifest only listed `net10.0` and `net9.0` packs.

3. **Missing net11.0 imports in WorkloadManifest.targets**: The targets file had no `ImportGroup` for `TargetFrameworkVersion == '11.0'`, causing it to fall back to net10.0, which doesn't have `KnownFrameworkReference` entries for net11.0-ios.

4. **The net11.0 packs ARE published** to the dotnet11 feed (version `26.2.11303-net11-p2`), but the manifest doesn't reference them.

## Files Modified

- `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.ios/26.0.11017/WorkloadManifest.json`
- `~/.dotnet11/sdk-manifests/10.0.100/microsoft.net.sdk.ios/26.0.11017/WorkloadManifest.targets`

## Environment

- macOS (Darwin) arm64
- .NET 11 SDK: 11.0.100-preview.2.26079.117
- iOS Workload: 26.0.11017 (modified)
- iOS SDK Pack: 26.2.11303-net11-p2
- Xcode: 26.2
- iOS Simulator: 26.2

## NuGet Feed

```
https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet11/nuget/v3/index.json
```
