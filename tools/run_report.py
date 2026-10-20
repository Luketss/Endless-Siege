#!/usr/bin/env python3
"""Summarises Endless Siege play logs (runs.jsonl). Pass one or more files, e.g. the ones
sent by playtesters:

  python3 tools/run_report.py ~/.local/share/godot/app_userdata/Endless\\ Siege/runs.jsonl other.jsonl

Where the file lives:
  Windows: %APPDATA%\\Godot\\app_userdata\\Endless Siege\\runs.jsonl
  Linux:   ~/.local/share/godot/app_userdata/Endless Siege/runs.jsonl
"""
import collections
import json
import sys


def load(paths):
    runs = []
    for p in paths:
        with open(p, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        runs.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
    return runs


def main(paths):
    runs = load(paths)
    if not runs:
        print("no runs found")
        return
    wins = sum(1 for r in runs if r.get("victory"))
    print(f"journeys: {len(runs)}   victories: {wins} ({100 * wins / len(runs):.0f}%)")
    print(f"avg stage reached: {sum(r.get('end_layer', 0) for r in runs) / len(runs):.1f}")
    ends = collections.Counter(f"{r.get('end_type')}@L{r.get('end_layer')}" for r in runs if not r.get("victory"))
    print("\nwhere defeats happen:")
    for k, v in ends.most_common():
        print(f"  {k:<14} {v}")

    offered, picked, skipped = collections.Counter(), collections.Counter(), 0
    for r in runs:
        for e in r.get("log", []):
            if e.get("t") in ("reward", "event_reward"):
                offered.update(e.get("offered", []))
                if e.get("picked"):
                    picked[e["picked"]] += 1
                else:
                    skipped += 1
    if offered:
        print(f"\nupgrade pick rate (picked / offered), {skipped} rewards skipped:")
        for uid in sorted(offered, key=lambda u: -picked[u] / offered[u]):
            print(f"  {uid:<20} {picked[uid]:>3}/{offered[uid]:<3} {100 * picked[uid] / offered[uid]:5.0f}%")

    enc = collections.defaultdict(list)
    for r in runs:
        for e in r.get("log", []):
            if e.get("t") == "encounter":
                enc[(e["type"], e["layer"])].append(e)
    if enc:
        print("\nencounters: avg core lost / avg time (s) / defeats")
        for (t, layer), es in sorted(enc.items(), key=lambda x: (x[0][1], x[0][0])):
            lost = sum(e["core_before"] - e["core_after"] for e in es) / len(es)
            time = sum(e["time"] for e in es) / len(es)
            defeats = sum(1 for e in es if e.get("defeated"))
            print(f"  L{layer} {t:<7} n={len(es):<3} core -{lost:5.1f}   {time:6.0f}s   {defeats}")

    dmg = collections.Counter()
    for r in runs:
        for e in r.get("log", []):
            if e.get("t") == "encounter":
                dmg.update(e.get("damage", {}))
    if dmg:
        total = sum(dmg.values())
        print("\ndamage share by source:")
        for k, v in dmg.most_common():
            print(f"  {k:<10} {100 * v / total:5.1f}%")


if __name__ == "__main__":
    main(sys.argv[1:])
