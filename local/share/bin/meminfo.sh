#!/usr/bin/env python3
"""Memory Info script for Waybar custom/memory module.
Outputs JSON: text (icon + percentage) and detailed tooltip with RAM & Swap usage."""

import json

def get_mem():
    try:
        mem = {}
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    key = parts[0].strip()
                    val = int(parts[1].split()[0])
                    mem[key] = val

        total = mem.get("MemTotal", 0) / 1024 / 1024
        avail = mem.get("MemAvailable", 0) / 1024 / 1024
        used = total - avail
        pct = (used / total * 100) if total > 0 else 0

        swap_total = mem.get("SwapTotal", 0) / 1024 / 1024
        swap_free = mem.get("SwapFree", 0) / 1024 / 1024
        swap_used = swap_total - swap_free
        swap_pct = (swap_used / swap_total * 100) if swap_total > 0 else 0

        tooltip = (
            f"󰍛 RAM Usage: {pct:.1f}%\n"
            f"Used: {used:.2f} GB / {total:.2f} GB\n"
            f"Available: {avail:.2f} GB\n\n"
            f"󰓡 Swap Usage: {swap_pct:.0f}%\n"
            f"Used: {swap_used:.2f} GB / {swap_total:.2f} GB"
        )

        return {"text": f"󰍛 {int(round(pct))}%", "tooltip": tooltip}
    except Exception as e:
        return {"text": "󰍛 --%", "tooltip": f"Memory error: {e}"}

if __name__ == "__main__":
    print(json.dumps(get_mem()))
