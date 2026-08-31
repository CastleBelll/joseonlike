"""Writes docs/TREE_OVERVIEW.md straight from the data files.

Run from the repo root after any change to data/meta_tree.json,
data/weapons.json, data/characters.json or data/weapon_mods.json:

    python tools/dump_tree.py

The document is generated, never hand-edited — a hand-kept copy drifts from
the data within a session and then lies to whoever reads it.
"""
import io
import json
import sys
from collections import defaultdict

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

TREE = json.load(open("data/meta_tree.json", encoding="utf-8"))
WEAPONS = json.load(open("data/weapons.json", encoding="utf-8"))
CHARACTERS = json.load(open("data/characters.json", encoding="utf-8"))
MODS = json.load(open("data/weapon_mods.json", encoding="utf-8"))

NODES = {n["id"]: n for n in TREE["nodes"]}

TAB_NAMES = {"": "공용 — 운영", "_refine": "연마 — 기본기"}
FAMILY_NAMES = {
    "fire": "화염", "lightning": "뇌전", "curse": "저주", "seal": "봉인",
    "hwando": "환도", "wolto": "언월도", "pyeongon": "편곤",
    "gakgung": "각궁", "soenoe": "쇠뇌", "pyeonjeon": "편전",
}
TABS = ["", "_refine", "taoist", "warrior", "archer"]


def tab_of(node):
    character = node.get("character", "")
    if character:
        return character
    return "_refine" if node["id"].startswith("refine_") else ""


def cost_text(node):
    costs = node["costs"]
    if len(costs) == 1:
        return f"{costs[0]:,}냥"
    return " → ".join(f"{c:,}" for c in costs) + "냥"


def effect_text(node):
    family = node.get("build_family", "")
    effect = node.get("effect", {})
    if family and not effect:
        return f"**{FAMILY_NAMES.get(family, family)} 계열 개방** — 그 계열 무기가 4배 자주 등장"
    label = node.get("desc_ko", "")
    if family:
        label += f" _({FAMILY_NAMES.get(family, family)} 계열 전용)_"
    return label


def children_of(tab):
    kids = defaultdict(list)
    roots = []
    for node in TREE["nodes"]:
        if tab_of(node) != tab:
            continue
        requires = node.get("requires", [])
        if not requires or requires[0] not in NODES:
            roots.append(node["id"])
        else:
            kids[requires[0]].append(node["id"])
    return roots, kids


def render_branch(node_id, kids, prefix, is_last, out):
    node = NODES[node_id]
    elbow = "└─ " if is_last else "├─ "
    ranks = f" · {len(node['costs'])}단계" if len(node["costs"]) > 1 else ""
    out.append(f"{prefix}{elbow}**{node['name_ko']}** — {effect_text(node)}")
    out.append(f"{prefix}{'   ' if is_last else '│  '}`{cost_text(node)}`{ranks}")
    child_ids = sorted(kids.get(node_id, []), key=lambda i: NODES[i]["costs"][0])
    for index, child in enumerate(child_ids):
        render_branch(
            child, kids, prefix + ("   " if is_last else "│  "),
            index == len(child_ids) - 1, out
        )


def tab_title(tab):
    if tab in TAB_NAMES:
        return TAB_NAMES[tab]
    entry = CHARACTERS[tab]
    return f"{entry['name_ko']} — {entry['title_ko']}"


def weapon_lines(family):
    bases, evolutions = [], []
    for weapon_id, stats in WEAPONS.items():
        if weapon_id.startswith("_") or stats.get("family") != family:
            continue
        row = f"{stats['name_ko']}"
        (evolutions if stats.get("evolution_only") else bases).append(row)
    return bases, evolutions


def main():
    out = ["# 수련 트리 한눈에 보기", ""]
    out.append(
        "`python tools/dump_tree.py`가 **데이터에서 직접 생성**한다. "
        "손으로 고치지 말고 데이터를 고친 뒤 다시 돌려라."
    )
    out.append("")
    per_tab = defaultdict(int)
    for node in TREE["nodes"]:
        per_tab[tab_of(node)] += 1
    summary = " · ".join(
        f"{tab_title(t).split(' — ')[0]} {per_tab[t]}" for t in TABS
    )
    out.append(f"**총 {len(TREE['nodes'])}노드** — {summary}")
    out.append("")

    for tab in TABS:
        out.append(f"## {tab_title(tab)}")
        out.append("")
        roots, kids = children_of(tab)
        roots.sort(key=lambda i: NODES[i]["costs"][0])
        for index, root in enumerate(roots):
            render_branch(root, kids, "", index == len(roots) - 1, out)
            out.append("")
        if tab not in TAB_NAMES:
            out.append("### 이 수행자의 무기")
            out.append("")
            out.append("| 계열 | 런에서 직접 획득 | 개조로만 나오는 것 |")
            out.append("|---|---|---|")
            seen = []
            for node in TREE["nodes"]:
                family = node.get("build_family", "")
                if family and node.get("character") == tab and family not in seen:
                    seen.append(family)
            for family in seen:
                bases, evolutions = weapon_lines(family)
                out.append(
                    f"| **{FAMILY_NAMES.get(family, family)}** | "
                    f"{' · '.join(bases) or '—'} | {' · '.join(evolutions) or '—'} |"
                )
            out.append("")
            out.append("### 이 수행자의 비기 (액티브)")
            out.append("")
            for active in CHARACTERS[tab].get("actives", []):
                out.append(
                    f"- **{active.get('name_ko')}** ({active.get('type')}) — "
                    f"재사용 {active.get('cooldown_sec')}초"
                )
            out.append("")
            out.append(
                "> 비기는 공용 탭의 **주문 속도**(재사용 −8%/단계)와 "
                "**깊은 수행**(위력·범위 +12%/단계)이 함께 키운다."
            )
            out.append("")

    out.append("## 개조 (대장간)")
    out.append("")
    out.append(
        f"레시피 {sum(1 for k in MODS if not k.startswith('_'))}종. "
        "대장간에서 엽전과 재료로 해금해야 런에 개조 카드로 나온다."
    )
    out.append("")
    out.append("| 결과 무기 | 기반 무기 | 필요 레벨 | 촉매 |")
    out.append("|---|---|---|---|")
    for mod_id, mod in sorted(MODS.items()):
        if mod_id.startswith("_"):
            continue
        base = WEAPONS.get(mod["weapon_id"], {}).get("name_ko", mod["weapon_id"])
        result = WEAPONS.get(mod["result_weapon"], {}).get("name_ko", mod["result_weapon"])
        out.append(
            f"| {result} | {base} | Lv.{mod.get('level_required', 1)} | "
            f"{mod.get('loot_id', '—')} |"
        )
    out.append("")

    with open("docs/TREE_OVERVIEW.md", "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(out) + "\n")
    print(f"docs/TREE_OVERVIEW.md written — {len(TREE['nodes'])} nodes")


main()
