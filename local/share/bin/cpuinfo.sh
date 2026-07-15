#!/usr/bin/env python3
"""CPU Info script for Waybar custom/cpuinfo module.
Outputs JSON: text (icon + utilization %) and detailed tooltip with model, frequency, load, and core usages."""

import sys, os, json, subprocess, time

def get_cpu_info():
    try:
        # Read CPU model name
        model = "CPU"
        with open("/proc/cpuinfo", "r") as f:
            for line in f:
                if "model name" in line:
                    model = line.split(":")[1].strip()
                    break

        # Read overall CPU usage & per-core usage from /proc/stat
        with open("/proc/stat", "r") as f:
            lines = f.readlines()

        cores = []
        total_usage = 0

        # /proc/stat parsing
        # line format: cpu  user nice system idle iowait irq softirq steal guest guest_nice
        def calc_usage(p1, p2):
            idle1 = p1[3] + p1[4]
            idle2 = p2[3] + p2[4]
            total1 = sum(p1)
            total2 = sum(p2)
            total_diff = total2 - total1
            idle_diff = idle2 - idle1
            if total_diff == 0:
                return 0.0
            return (total_diff - idle_diff) / total_diff * 100.0

        def parse_stat(l):
            return [int(x) for x in l.split()[1:]]

        stat1 = {line.split()[0]: parse_stat(line) for line in lines if line.startswith("cpu")}
        time.sleep(0.1)
        with open("/proc/stat", "r") as f:
            lines2 = f.readlines()
        stat2 = {line.split()[0]: parse_stat(line) for line in lines2 if line.startswith("cpu")}

        if "cpu" in stat1 and "cpu" in stat2:
            total_usage = calc_usage(stat1["cpu"], stat2["cpu"])

        core_lines = []
        for k in sorted(stat1.keys()):
            if k.startswith("cpu") and k != "cpu":
                c_num = k.replace("cpu", "")
                if k in stat2:
                    u = calc_usage(stat1[k], stat2[k])
                    core_lines.append(f"Core {c_num:>2}: {u:4.1f}%")

        # Load average
        with open("/proc/loadavg", "r") as f:
            load = f.read().split()[:3]
        load_str = " ".join(load)

        # Average Frequency
        freq_str = ""
        try:
            with open("/proc/cpuinfo", "r") as f:
                freqs = [float(l.split(":")[1].strip()) for l in f if "cpu MHz" in l]
            if freqs:
                avg_freq = sum(freqs) / len(freqs) / 1000.0
                freq_str = f"{avg_freq:.2f} GHz"
        except Exception:
            pass

        # Build tooltip
        tooltip_lines = [f"{model}"]
        if freq_str:
            tooltip_lines.append(f"󰓅 Frequency: {freq_str}")
        tooltip_lines.append(f"󰻠 Usage: {total_usage:.1f}%  ·  Load: {load_str}")

        if core_lines:
            tooltip_lines.append("\nCores:")
            # Group cores into 2 columns for neat rendering
            for i in range(0, len(core_lines), 2):
                if i + 1 < len(core_lines):
                    tooltip_lines.append(f"  {core_lines[i]}    {core_lines[i+1]}")
                else:
                    tooltip_lines.append(f"  {core_lines[i]}")

        tooltip = "\n".join(tooltip_lines)
        return {"text": f"󰻠 {int(round(total_usage))}%", "tooltip": tooltip}
    except Exception as e:
        return {"text": "󰻠 --%", "tooltip": f"CPU error: {e}"}

if __name__ == "__main__":
    data = get_cpu_info()
    print(json.dumps(data))
