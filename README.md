# iOS performance measurements

Compare startup time, build time, and bundle size between CoreCLR, Mono, and NativeAOT runtimes for iOS apps.

## Requirements

- macOS with Apple Silicon (arm64)
- Xcode with iOS SDK installed
- iPhone connected via USB (for on-device measurement)

## Setup

### Step 1: Install .NET SDK and workloads

Downloads the latest .NET 11 preview SDK and installs `ios`, `maccatalyst`, and `maui` workloads into a local `./dotnet` directory.

```bash
./dotnet.sh
```

**Note:** `global.json` must match the installed preview SDK version. If you get SDK resolution errors, update the `version` field in `global.json` to match the installed SDK (shown in the script output).

### Step 2: Install custom macios (optional)

Clones `dotnet/macios`, patches it to enable `DEBUG_LAUNCH_TIME` timing instrumentation, builds it, and replaces the stock iOS SDK packs in `./dotnet/packs/`.

```bash
./install-custom-macios.sh
```

This step takes a long time (cloning + full native build). To skip the build and only re-install previously built packs:

```bash
./install-custom-macios.sh --skip-build
```

To revert to stock SDK packs, re-run `./dotnet.sh`.

### Step 3: Measure performance

```bash
./measure-perf.sh <app> <runtime> <config>
```

| Parameter | Values |
|-----------|--------|
| app | `ios`, `maui` |
| runtime | `coreclr`, `mono`, `nativeaot` |
| config | `debug`, `release` |

## Requirements

- macOS and iPhone with arm64 (Apple Silicon)
- Xcode with iOS SDK

## Output

Each run creates a timestamped directory in `results/` containing:
- `results` - xharness device logs

