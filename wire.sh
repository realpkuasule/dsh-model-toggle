#!/usr/bin/env bash
# wire.sh — 在目标机器上把 model-toggle 接线进 dsh web profile（幂等，可重复执行）。
# 前置：package/ 内容已就位（install.sh 负责放置）。
# 用法：PROFILE=~/.dsh/profiles/web ./wire.sh
set -euo pipefail
PROFILE="${PROFILE:-$HOME/.dsh/profiles/web}"
PKG="$PROFILE/packages/model-toggle"
[ -f "$PKG/package.json" ] || { echo "wire: 找不到 $PKG/package.json"; exit 1; }

# 1) package.json 依赖（幂等）
python3 - "$PROFILE/package.json" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f:
    data = json.load(f)
deps = data.setdefault("dependencies", {})
if "model-toggle" not in deps:
    deps["model-toggle"] = "file:./packages/model-toggle"
    with open(p, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("wire: package.json 依赖已添加")
else:
    print("wire: package.json 依赖已存在")
PY

# 2) pnpm install（offline 失败则联网重试）
cd "$PROFILE"
if pnpm install --offline >/dev/null 2>&1; then
    echo "wire: pnpm install（offline）完成"
elif pnpm install >/dev/null 2>&1; then
    echo "wire: pnpm install 完成"
else
    echo "wire: pnpm install 失败" >&2
    exit 1
fi

# 3) cordis.patch.yml 行（幂等；先备份）
PATCH="$PROFILE/cordis.patch.yml"
if ! grep -q "name: 'model-toggle'" "$PATCH"; then
    cp "$PATCH" "$PATCH.bak-model-toggle"
    python3 - "$PATCH" <<'PY'
import sys
p = sys.argv[1]
with open(p) as f:
    text = f.read()
row = (
    "    # 本会话模型一键切换按钮（⚡ Pro Max ↔ Flash Max），走官方 wire API。\n"
    "    # 见 packages/model-toggle/。\n"
    "    - id: model-toggle\n"
    "      name: 'model-toggle'\n"
)
if "model-toggle" in text:
    print("wire: cordis.patch.yml 已包含 model-toggle")
else:
    marker = "    - id: lan-gate\n"
    if marker in text:
        text = text.replace(marker, row + marker)
    else:
        text += "\n- insert:\n" + row
    with open(p, "w") as f:
        f.write(text)
    print("wire: cordis.patch.yml 行已添加（备份在 .bak-model-toggle）")
PY
else
    echo "wire: cordis.patch.yml 行已存在"
fi

echo "wire: 完成。请重启 dsh web 进程使按钮生效（重启后刷新页面）。"
