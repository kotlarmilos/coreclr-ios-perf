# CoreCLR iOS Performance Testing

This repository provides an environment for measuring CoreCLR performance on iOS devices using .NET MAUI applications.

## Setup Overview

The complete setup involves two main steps:
1. **Build the .NET Runtime** - Custom runtime packs for iOS
2. **Build the iOS SDK (macios)** - Build the custom iOS SDK workload

After setup, you can build and run a MAUI sample app to test CoreCLR performance. The included `NuGet.config` automatically uses the local builds without modifying your system.

## Step 1: Build the .NET Runtime

The first step is to build the .NET runtime repository with iOS runtime packs. This is necessary because the CoreCLR changes for iOS performance testing are not yet integrated into the unified build.

```bash
./scripts/build-runtime.sh
```

## Step 2: Build the iOS SDK (macios)

Next, build the macios repository which contains the iOS SDK workload that integrates with the .NET runtime.

```bash
./scripts/build-macios.sh
```

TODO: Remove fix below after https://github.com/dotnet/macios/issues/24339 gets resolved.

`macios/builds/Makefile` needs manual fix to look for runtime pack in Release instead of Debug:

```sh
CUSTOM_DOTNET_NUGET_FEED=\
	--source $(DOTNET_RUNTIME_PATH)/artifacts/packages/Release/Shipping \
	$(foreach feed,$(ALL_NUGET_FEEDS), --source $(feed))
```

## Testing with the MAUI App

The repository includes a sample .NET MAUI app in the `MyMauiApp` directory. This app is configured to run with CoreCLR on iOS devices.

**Build options:**

- To build and run with CoreCLR: `-p:UseMonoRuntime=false`
- To enable R2R: `-p:PublishReadyToRun=true`
- To build and run with Mono: `-p:UseMonoRuntime=true`

```bash
cd MyMauiApp
dotnet build -f net10.0-ios -c Release -p:DeviceName=YOUR_DEVICE_ID /bl
dotnet build -f net10.0-ios -c Release -t:Run -p:DeviceName=YOUR_DEVICE_ID
```

## How It Works

The `MyMauiApp/NuGet.config` file configures NuGet to look for packages in this order:
1. Local macios build (`../macios/_build/nupkgs`) - highest priority
2. Official NuGet feeds - fallback for other packages

This means your local iOS SDK will be used automatically without any system modifications. To switch back to the official SDK, simply rename or remove the `NuGet.config` file.