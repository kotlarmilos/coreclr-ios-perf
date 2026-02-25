# iOS performance measurements

Compare build times and bundle sizes between CoreCLR, Mono, and NativeAOT runtimes for iOS apps.

## Quick Start

```bash
./dotnet.sh
./install-custom-macios.sh
./measure-perf.sh maui coreclr release
```

## Usage

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

