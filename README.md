# iOS performance measurements

Compare build times and bundle sizes between CoreCLR, Mono, and NativeAOT runtimes for iOS apps.

## Quick Start

```bash
./measure-perf.sh ios coreclr release simulator
```

## Scripts

| Script | Description |
|--------|-------------|
| `dotnet.sh` | Downloads .NET SDK, installs iOS/MAUI workloads, and xharness |
| `measure-perf.sh` | Runs performance measurement |

## Usage

```bash
./measure-perf.sh <app> <runtime> <config> <target>
```

| Parameter | Values |
|-----------|--------|
| app | `ios`, `maui` |
| runtime | `coreclr`, `mono`, `nativeaot` |
| config | `debug`, `release` |
| target | `simulator`, `device` |

### Examples

```bash
./measure-perf.sh ios coreclr release simulator   # iOS, CoreCLR, Release, Simulator
./measure-perf.sh ios mono release device         # iOS, Mono, Release, Device
./measure-perf.sh maui coreclr debug simulator    # MAUI, CoreCLR, Debug, Simulator
```

## Requirements

- macOS with arm64 (Apple Silicon)
- Xcode with iOS SDK

## Output

Each run creates a timestamped directory in `results/` containing:
- `results.md` - Markdown report with metrics
- `*.app` - App bundle snapshot
- `logs/` - xharness device/simulator logs

