#!/usr/bin/env bash
# repo の 3 ルールを ~/.config/karabiner/karabiner.json の active profile に反映する。
# Karabiner-Elements は karabiner.json の変更を検知して自動 reload する。
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KARA_JSON="$HOME/.config/karabiner/karabiner.json"

if [ ! -f "$KARA_JSON" ]; then
    echo "error: $KARA_JSON が存在しません。Karabiner-Elements は起動・初期化済みですか?" >&2
    exit 1
fi

BACKUP="$KARA_JSON.bak.$(date +%Y%m%d_%H%M%S)"
cp "$KARA_JSON" "$BACKUP"
echo "backup: $BACKUP"

python3 - "$REPO_DIR" "$KARA_JSON" <<'PY'
import json, sys, pathlib, tempfile, os

repo = pathlib.Path(sys.argv[1])
kara = pathlib.Path(sys.argv[2])

files = [
    "karabiner-elements_a-base.json",
    "karabiner-elements_b1-shift-kana.json",
    "karabiner-elements_b2-enter-shift.json",
]

rules_by_desc = {}
for f in files:
    rule = json.loads((repo / f).read_text())
    if "description" not in rule or "manipulators" not in rule:
        sys.exit(f"error: {f} に description/manipulators がありません")
    rules_by_desc[rule["description"]] = rule

data = json.loads(kara.read_text())
profiles = [p for p in data.get("profiles", []) if p.get("selected")]
if not profiles:
    sys.exit("error: selected=true の profile が見つかりません")
prof = profiles[0]
print(f"target profile: {prof.get('name')!r}")

rules = prof.setdefault("complex_modifications", {}).setdefault("rules", [])
replaced, inserted = [], []
for i, r in enumerate(rules):
    desc = r.get("description")
    if desc in rules_by_desc:
        rules[i] = rules_by_desc.pop(desc)
        replaced.append(desc)
for desc, rule in list(rules_by_desc.items()):
    rules.insert(0, rule)
    inserted.append(desc)

for d in replaced:
    print(f"  replaced: {d}")
for d in inserted:
    print(f"  inserted: {d}")
if not replaced and not inserted:
    print("  (no changes)")

tmp = tempfile.NamedTemporaryFile("w", dir=str(kara.parent), delete=False, encoding="utf-8")
json.dump(data, tmp, indent=4, ensure_ascii=False)
tmp.write("\n")
tmp.close()
os.replace(tmp.name, str(kara))
print("written:", kara)
PY

echo "done. Karabiner-Elements が起動中なら自動 reload されます。"
echo "ロールバック: cp '$BACKUP' '$KARA_JSON'"
