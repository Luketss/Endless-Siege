#!/usr/bin/env python3
"""Fails if a translation key used in code or data is missing from tools/translations_source.py."""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from translations_source import S  # noqa: E402

used = set()
for path in glob.glob("scripts/**/*.gd", recursive=True):
    src = open(path, encoding="utf-8").read()
    used |= set(re.findall(r'\btr\("([A-Z0-9_]+)"\)', src))
    used |= set(re.findall(r'translate\("([A-Z0-9_]+)"\)', src))

data = {n: json.load(open(f"data/{n}.json")) for n in ["structures", "enemies", "upgrades", "synergies", "events", "unlocks", "modifiers", "heroes"]}
for d in data["structures"].values():
    used |= {d["name_key"], d["desc_key"]}
for d in data["enemies"].values():
    used.add(d["name_key"])
for uid, u in data["upgrades"].items():
    used |= {"U_" + uid.upper(), "U_" + uid.upper() + "_DESC", "RARITY_" + u["rarity"].upper()}
    used |= {"TAG_" + t.upper() for t in u["tags"]}
for sid in data["synergies"]:
    used |= {"SYN_" + sid.upper(), "SYN_" + sid.upper() + "_DESC"}
for e in data["events"].values():
    used |= {e["title_key"], e["text_key"]} | {c["key"] for c in e["choices"]}
for uid, u in data["unlocks"].items():
    used |= {u["name_key"], "UNL_" + uid.upper() + "_DESC"}
for m in data["modifiers"].values():
    used |= {m["name_key"], m["name_key"] + "_DESC"}
for t in ["COMBAT", "ELITE", "SHOP", "EVENT", "REST", "BOSS"]:
    used |= {"NODE_" + t, "NODE_" + t + "_REWARD"}
src = open("scripts/core/battle_sim.gd").read()
used |= set(re.findall(r'"(SYN_FX_[A-Z_]+)"', src))
used |= {"TARGET_FIRST", "TARGET_STRONG", "TARGET_CLOSE"}
used |= {"ACTION_" + a.upper() for a in re.findall(r'"([a-z_0-9]+)"', re.search(r"REMAPPABLE := \[(.*?)\]", open("scripts/autoload/settings.gd").read(), re.S).group(1))}

missing = sorted(k for k in used if k not in S)
if missing:
    print("Missing translation keys:", *missing, sep="\n  ")
    sys.exit(1)
print(f"ok: {len(used)} keys used, {len(S)} defined")
