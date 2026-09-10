#!/usr/bin/env python3
"""Party-composition sweep driver for tests/sim.tscn.

Runs every 3-of-6 trio of the Early Access playable characters against the full
Act 1 encounter set (standard fight pools, both elites, boss), policy=timed,
n=30 per configuration, and writes:
  - one JSON summary per config under <out>/json/
  - a single combined JSON at <out>/party-sweep-<date>-raw.json (list of all summaries)

This is a measurement tool only. It runs the existing sim unchanged and does not
modify any game data.

Usage (from the Godot project root, i.e. /home/claude/poe/game):
    python3 tests/party_sweep.py [--n 30] [--policy timed] [--out /home/claude/poe/out]
"""
import argparse, datetime, itertools, json, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.path.join(os.path.dirname(PROJECT), "Godot_v4.5-stable_linux.x86_64")

# The six Early Access playable characters -- confirmed from data: these are the
# only characters in Path-of-Embers/data/characters/*.tres with a non-empty
# ability_id (the other five: warrior_3, warrior_4, hollow, mechanist, sibyl --
# are Early-Access-locked per the comment in CharacterData.gd).
CHARACTERS = ["warrior_1", "warrior_2", "golemancer", "grove", "living_armor", "witch"]

# Mirrors EncounterDirector.FIGHT_POOLS / ELITE_POOLS ordering.
POOLS = [
    ("fight:0", "cinder_imp x2"),
    ("fight:1", "smolder_shade + cinder_imp"),
    ("fight:2", "ash_man"),
    ("fight:3", "smolder_shade x2"),
    ("fight:4", "ember_brute"),
    ("fight:5", "ash_man + cinder_imp"),
    ("elite:0", "ashen_knight (elite)"),
    ("elite:1", "char_sentinel (elite)"),
    ("boss", "boss_act1"),
]


def run_config(label, party, pool, act, n, policy, seed, json_dir):
    jpath = os.path.join(json_dir, re.sub(r"[^A-Za-z0-9]+", "_", label) + ".json")
    cmd = [GODOT, "--headless", "--path", PROJECT, "res://tests/sim.tscn", "--",
           f"--party={','.join(party)}", f"--pool={pool}", f"--act={act}", f"--n={n}",
           f"--policy={policy}", f"--seed={seed}", f"--label={label}", f"--json={jpath}"]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    summary = json.load(open(jpath)) if os.path.exists(jpath) else None
    return summary, p.returncode, p.stdout, p.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=30)
    ap.add_argument("--policy", default="timed")
    ap.add_argument("--seed", type=int, default=12345)
    ap.add_argument("--act", type=int, default=1)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(PROJECT), "out"))
    args = ap.parse_args()

    date = datetime.date.today().isoformat()
    json_dir = os.path.join(args.out, "json")
    os.makedirs(json_dir, exist_ok=True)

    trios = list(itertools.combinations(CHARACTERS, 3))
    print(f"{len(trios)} trios x {len(POOLS)} encounters = {len(trios) * len(POOLS)} configs", file=sys.stderr)

    results = []
    t0 = time.time()
    for party in trios:
        trio_label = "+".join(party)
        for pool, pool_name in POOLS:
            label = f"{trio_label} | A{args.act} {pool_name}"
            summary, rc, stdout, stderr = run_config(label, party, pool, args.act, args.n, args.policy, args.seed, json_dir)
            if summary is None:
                print(f"FAILED {label} rc={rc}\n{stdout[-500:]}\n{stderr[-1500:]}", file=sys.stderr)
                continue
            summary["trio"] = list(party)
            summary["pool_key"] = pool
            summary["pool_name"] = pool_name
            results.append(summary)
            print(f"{label:70s} win={summary['win_rate']:.2f} dmg={summary['damage_taken']['mean']:.1f}/{summary['hp_max']}", file=sys.stderr)

    raw_path = os.path.join(args.out, f"party-sweep-{date}-raw.json")
    with open(raw_path, "w") as f:
        json.dump(results, f)
    print(f"wrote {raw_path} ({len(results)} configs, {time.time()-t0:.1f}s)", file=sys.stderr)


if __name__ == "__main__":
    main()
