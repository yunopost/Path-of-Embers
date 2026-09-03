#!/usr/bin/env python3
"""Baseline sweep driver for tests/sim.tscn.

Runs one headless Godot process per configuration (so stderr is attributed per config),
collects the per-config JSON summaries and the shared CSV, and assembles a markdown report.

Usage (from the Godot project root):
    python3 tests/run_sweep.py [--n 100] [--policy greedy] [--out /home/claude/poe/out] [--quick]
"""
import argparse, collections, datetime, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.path.join(os.path.dirname(PROJECT), "Godot_v4.5-stable_linux.x86_64")

TRIOS = {
    "timer": ["warrior_1", "warrior_2", "golemancer"],
    "mass": ["witch", "living_armor", "grove"],
}
# mirrors EncounterDirector.FIGHT_POOLS / ELITE_POOLS ordering (the sim reads the real constants via --pool)
POOL_NAMES = {
    "fight:0": "cinder_imp x2", "fight:1": "smolder_shade + cinder_imp", "fight:2": "ash_man",
    "fight:3": "smolder_shade x2", "fight:4": "ember_brute", "fight:5": "ash_man + cinder_imp",
    "elite:0": "ashen_knight (elite)", "elite:1": "char_sentinel (elite)", "boss": "boss",
}
IGNORE_STDERR = re.compile(r"mp3|MusicManager")


def run_config(label, party, pool, act, n, policy, seed, out_dir, csv_path):
    jpath = os.path.join(out_dir, "json", re.sub(r"[^A-Za-z0-9]+", "_", label) + ".json")
    cmd = [GODOT, "--headless", "--path", PROJECT, "res://tests/sim.tscn", "--",
           f"--party={','.join(party)}", f"--pool={pool}", f"--act={act}", f"--n={n}",
           f"--policy={policy}", f"--seed={seed}", f"--label={label}", f"--json={jpath}", f"--csv={csv_path}"]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    stderr_lines = [l for l in p.stderr.splitlines() if l.strip()]
    findings = collections.Counter()
    i = 0
    while i < len(stderr_lines):
        l = stderr_lines[i]
        if l.startswith(("ERROR", "WARNING", "SCRIPT ERROR", "USER ERROR", "USER WARNING")) and not IGNORE_STDERR.search(l):
            where = ""
            for j in range(i + 1, min(i + 6, len(stderr_lines))):
                m = re.search(r"\[\d+\] (\S+ \(res://[^)]+\))", stderr_lines[j])
                if m:
                    where = " @ " + m.group(1)
                    break
            findings[l.strip() + where] += 1
        i += 1
    summary = json.load(open(jpath)) if os.path.exists(jpath) else None
    return summary, findings, p.returncode, p.stdout


def fmt(s):
    return f"{s['mean']:.1f} ({s['p10']}/{s['p90']})"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=100)
    ap.add_argument("--policy", default="greedy")
    ap.add_argument("--seed", type=int, default=12345)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(PROJECT), "out"))
    ap.add_argument("--quick", action="store_true", help="act 1 only")
    args = ap.parse_args()

    date = datetime.date.today().isoformat()
    os.makedirs(os.path.join(args.out, "json"), exist_ok=True)
    csv_path = os.path.join(args.out, f"playtest-baseline-{date}.csv")
    if os.path.exists(csv_path):
        os.remove(csv_path)
    md_path = os.path.join(args.out, f"playtest-baseline-{date}.md")

    configs = []
    acts = [1] if args.quick else [1, 2, 3]
    for act in acts:
        pools = [f"fight:{i}" for i in range(6)] + ["elite:0", "elite:1", "boss"]
        for pool in pools:
            for trio, party in TRIOS.items():
                configs.append((f"A{act} {POOL_NAMES[pool]} | {trio}", party, pool, act))

    results = []
    all_findings = collections.Counter()
    for label, party, pool, act in configs:
        summary, findings, rc, stdout = run_config(label, party, pool, act, args.n, args.policy, args.seed, args.out, csv_path)
        for k, v in findings.items():
            all_findings[(label, k)] += v
        if summary is None:
            print(f"FAILED {label} rc={rc}\n{stdout[-800:]}", file=sys.stderr)
            continue
        results.append(summary)
        print(f"{label:48s} win={summary['win_rate']:.2f} turns={summary['turns']['mean']:.1f} ticks={summary['ticks']['mean']:.1f} "
              f"enemy_acts={summary['enemy_actions']['mean']:.1f} dmg={summary['damage_taken']['mean']:.1f}/{summary['hp_max']} "
              f"({summary['elapsed_ms']} ms)")

    # ── markdown ────────────────────────────────────────────────────────────
    L = []
    L.append(f"# Path of Embers — playtest baseline {date}")
    L.append("")
    L.append(f"Turn-based model (pre card-clock). Policy `{args.policy}`: cheapest playable card, lowest-HP enemy target, End Turn when nothing is playable. "
             f"N={args.n} fights per configuration, base seed {args.seed} (fight i uses seed+i), max 60 turns. "
             f"Acts 2/3 use EncounterDirector ACT_HP_MULT/ACT_DMG_MULT (1.6/1.3, 2.2/1.6); bosses are unscaled authored blocks as in-game. "
             f"Ticks = card timer ticks (Haste 0 / Slow 2 / else 1) + 1 per End Turn (the Focus-equivalent under card-clock).")
    L.append("")
    L.append("Parties: **timer** = warrior_1 (Monster Hunter), warrior_2 (Shadowfoot), golemancer — 78 HP; "
             "**mass** = witch, living_armor, grove — 72 HP. Starter decks only (3 generic + 2 unique per character, 15 cards).")
    L.append("")
    L.append("Sim files: `tests/sim.gd`, `tests/sim.tscn`, `tests/run_sweep.py`. Per-fight rows: `" + os.path.basename(csv_path) + "`. Per-config JSON in `out/json/`.")
    L.append("")
    L.append("## Headline table")
    L.append("")
    L.append("Columns are mean (p10/p90). Dmg = net HP lost (start − end, after heals); gross = HP lost before heals. Block wasted = Block still up when it was wiped at the next turn start.")
    L.append("")
    L.append("| config | win | turns | ticks | enemy acts | dmg net | gross | HP max | block gained | block wasted | E unspent/turn | cards |")
    L.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for s in results:
        L.append(f"| {s['label']} | {s['win_rate']:.2f} | {fmt(s['turns'])} | {fmt(s['ticks'])} | {fmt(s['enemy_actions'])} | {fmt(s['damage_taken'])} | {s['hp_lost_gross']['mean']:.1f} | {s['hp_max']} | "
                 f"{fmt(s['block_gained'])} | {fmt(s['block_wasted'])} | {s['energy_unspent_per_turn']['mean']:.2f} | {fmt(s['cards_played_total'])} |")
    L.append("")

    # Per-party card usage aggregated over act 1 standard fights
    L.append("## Card usage (all configs pooled, per party)")
    L.append("")
    for trio in TRIOS:
        pooled = collections.defaultdict(lambda: [0, 0, 0, 0])  # plays, seen, affordable, fights
        copies = {}
        catalogue = {}
        fights = 0
        for s in results:
            if not s["label"].endswith("| " + trio):
                continue
            fights += s["n"]
            for c in s["per_card"]:
                pooled[c["card_id"]][0] += c["plays"]
                pooled[c["card_id"]][1] += c["seen"]
                pooled[c["card_id"]][2] += c["affordable"]
                copies[c["card_id"]] = c["copies"]
            for c in s["catalogue"]:
                catalogue[c["card_id"]] = c
        L.append(f"### {trio} trio ({fights} fights)")
        L.append("")
        L.append("| card | owner | cost | type | targeting | copies | plays/fight | in hand at decision pts | playable at decision pts | effects |")
        L.append("|---|---|---|---|---|---|---|---|---|---|")
        for cid, (plays, seen, aff, _) in sorted(pooled.items(), key=lambda kv: -kv[1][0]):
            cat = catalogue.get(cid, {})
            L.append(f"| {cid} | {cat.get('owner','-')} | {cat.get('cost','-')} | {cat.get('type','-')} | {cat.get('targeting','-')} | {copies.get(cid,0)} | "
                     f"{plays / max(1, fights):.2f} | {seen} | {aff} | {cat.get('effects','')} |")
        never = [cid for cid, v in pooled.items() if v[0] == 0]
        L.append("")
        L.append("Never played: " + (", ".join(f"`{c}`" for c in never) if never else "none — greedy plays every starter card in these decks."))
        L.append("")

    L.append("## Per-enemy actions and HP damage per fight")
    L.append("")
    L.append("| config | enemy | actions/fight | HP dmg/fight |")
    L.append("|---|---|---|---|")
    for s in results:
        for e in s["per_enemy"]:
            L.append(f"| {s['label']} | {e['enemy_id']} | {e['actions_per_fight']:.2f} | {e['hp_damage_per_fight']:.2f} |")
    L.append("")

    L.append("## Sim-side findings (reset sanity checks, refused plays, signal mismatches)")
    L.append("")
    any_f = False
    for s in results:
        for f in s.get("findings", []):
            any_f = True
            L.append(f"- {s['label']}: {f}")
    if not any_f:
        L.append("None. Deck size, opening hand, HP, energy, block, statuses and haste flag verified fresh at the start of every fight in every configuration.")
    L.append("")

    L.append("## stderr findings (SCRIPT ERROR / push_error / push_warning, MusicManager mp3 noise excluded)")
    L.append("")
    if not all_findings:
        L.append("None across all configurations.")
    else:
        grouped = collections.defaultdict(list)
        for (label, msg), cnt in all_findings.items():
            grouped[msg].append((label, cnt))
        for msg, lst in sorted(grouped.items(), key=lambda kv: -sum(c for _, c in kv[1])):
            L.append(f"- **{sum(c for _, c in lst)}×** `{msg}` — in {len(lst)} config(s): " + ", ".join(f"{l} ({c})" for l, c in lst[:6]) + (" …" if len(lst) > 6 else ""))
    L.append("")
    open(md_path, "w").write("\n".join(L))
    print("wrote", md_path)
    print("wrote", csv_path)


if __name__ == "__main__":
    main()
