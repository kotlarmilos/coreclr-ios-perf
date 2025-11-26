# CoreCLR iOS Performance Testing

This repository provides an environment for measuring CoreCLR performance on iOS devices using .NET MAUI applications.

## Setup Overview

The complete setup involves three main steps:
1. **Build the .NET Runtime** - Custom runtime packs for iOS
2. **Build the iOS SDK (macios)** - Build the custom iOS SDK workload
3. **Patch Local Workloads** - Replace your local iOS workloads with the custom builds

After setup, you can build and run a MAUI sample app to test CoreCLR performance.

## Step 1: Build the .NET Runtime

The first step is to build the .NET runtime repository with iOS runtime packs. This is necessary because the CoreCLR changes for iOS performance testing are not yet integrated into the unified build.

```bash
./scripts/build-runtime.sh
```

## Step 2: Build the iOS SDK (macios)

Next, build the macios repository which contains the iOS SDK workload that integrate with the .NET runtime.

```bash
./scripts/build-macios.sh
```

## Step 3: Patch iOS Workloads

After building both repositories, you need to replace your local .NET iOS workloads with the custom-built versions. This allows you to use CoreCLR runtime when building iOS apps.

**Run the script:**

```bash
./scripts/install-local-ios-sdk.sh
```

⚠️ **Important:** This modifies your system's .NET installation. Make sure to run the cleanup script (see below) when you're done testing to restore the original workloads.

## Testing with the MAUI App

The repository includes a sample .NET MAUI app in the `MyMauiApp` directory. This app is configured to run with CoreCLR on iOS devices.

**Build options:**

- To build and run with CoreCLR: `-p:UseMonoRuntime=false`
- To enable R2R: `-p:PublishReadyToRun=true`
- To build and run with Mono: `-p:UseMonoRuntime=true`

```bash
dotnet build -f net10.0-ios -p:DeviceName=YOUR_DEVICE_ID /bl
dotnet build -f net10.0-ios -t:Run -p:DeviceName=YOUR_DEVICE_ID
```

## Cleanup

When you're finished testing, it's important to restore your original iOS workloads.

```bash
./scripts/restore-local-ios-sdk.sh
```