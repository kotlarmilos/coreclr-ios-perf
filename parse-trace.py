#!/usr/bin/env python3
"""
Parse xctrace Time Profiler output to extract timing between specific functions.
Measures:
  - Runtime startup: xamarin_main -> xamarin_initialize end
  - VM init: xamarin_vm_initialize start -> end (CoreCLR/Mono initialization)
  - Managed startup: xamarin_initialize end -> FinishedLaunching
"""

import subprocess
import sys
import re

def export_table(trace_path, xpath):
    """Export a specific table from trace."""
    result = subprocess.run(
        ['xcrun', 'xctrace', 'export', '--input', trace_path, '--xpath', xpath],
        capture_output=True, text=True
    )
    return result.stdout

def parse_time_profile(trace_path):
    """Parse time-profile samples to find function timestamps."""
    xml_data = export_table(trace_path, '/trace-toc/run/data/table[@schema="time-profile"]')
    
    if not xml_data.strip():
        return {}
    
    # Find timestamps:
    # - xamarin_main: FIRST occurrence (start of runtime)
    # - xamarin_vm_initialize: FIRST and LAST occurrence (CoreCLR/Mono init)
    # - xamarin_initialize: LAST occurrence (end of runtime init)
    # - FinishedLaunching: LAST occurrence (end of managed startup)
    
    timestamps = {
        'xamarin_main_start': None,
        'vm_init_start': None,
        'vm_init_end': None,
        'xamarin_init_end': None,
        'ui_app_main': None,
        'finished_launching_end': None,
    }
    
    # Split into rows (each <row>...</row> is a sample)
    rows = re.findall(r'<row>.*?</row>', xml_data, re.DOTALL)
    
    for row in rows:
        # Extract sample time (nanoseconds)
        time_match = re.search(r'<sample-time[^>]*>(\d+)</sample-time>', row)
        if not time_match:
            continue
        sample_time = int(time_match.group(1))
        
        # xamarin_main: first occurrence only
        if timestamps['xamarin_main_start'] is None and 'name="xamarin_main"' in row:
            timestamps['xamarin_main_start'] = sample_time
        
        # xamarin_vm_initialize or xamarin_bridge_vm_initialize: first and last occurrence
        if 'xamarin_vm_initialize"' in row or 'xamarin_bridge_vm_initialize"' in row:
            if timestamps['vm_init_start'] is None:
                timestamps['vm_init_start'] = sample_time
            timestamps['vm_init_end'] = sample_time
            
        # xamarin_initialize: keep updating to get last occurrence
        if 'name="xamarin_initialize"' in row:
            timestamps['xamarin_init_end'] = sample_time
        
        # xamarin_UIApplicationMain: fallback for managed end (last occurrence)
        if 'xamarin_UIApplicationMain' in row:
            timestamps['ui_app_main'] = sample_time
            
        # FinishedLaunching or UIApplication scene update (fallback when FinishedLaunching is too short to sample)
        if 'FinishedLaunching' in row or '_reportMainSceneUpdateFinished' in row:
            timestamps['finished_launching_end'] = sample_time
    
    return timestamps

def main():
    if len(sys.argv) < 2:
        print("Usage: parse-trace.py <trace-file>")
        sys.exit(1)
    
    trace_path = sys.argv[1]
    
    # Parse function timings
    ts = parse_time_profile(trace_path)
    
    runtime_ms = None
    vm_init_ms = None
    managed_ms = None
    
    # Runtime: xamarin_main -> xamarin_initialize
    if ts.get('xamarin_main_start') and ts.get('xamarin_init_end'):
        runtime_ms = (ts['xamarin_init_end'] - ts['xamarin_main_start']) / 1_000_000  # ns to ms
    
    # VM init: xamarin_vm_initialize start -> end
    if ts.get('vm_init_start') and ts.get('vm_init_end'):
        vm_init_ms = (ts['vm_init_end'] - ts['vm_init_start']) / 1_000_000  # ns to ms
        
    # Managed: xamarin_initialize -> FinishedLaunching (no fallback - more representative)
    if ts.get('xamarin_init_end') and ts.get('finished_launching_end'):
        managed_ms = (ts['finished_launching_end'] - ts['xamarin_init_end']) / 1_000_000  # ns to ms
    
    # Output as simple key=value for bash parsing
    print(f"runtime_ms={int(runtime_ms) if runtime_ms else 'N/A'}")
    print(f"vm_init_ms={int(vm_init_ms) if vm_init_ms else 'N/A'}")
    print(f"managed_ms={int(managed_ms) if managed_ms else 'N/A'}")

if __name__ == '__main__':
    main()
