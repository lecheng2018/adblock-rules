#!/bin/bash
# Adblock rules to dnsmasq format converter
# 定时更新广告域名规则，输出 dnsmasq 格式的 conf 文件
# 规则格式: address=/域名/0.0.0.0

RULES_DIR="$(dirname "$0")/../../rules"
OUTPUT="$RULES_DIR/adblock.conf"
TMPDIR=$(mktemp -d)
RAWDIR="$TMPDIR/raw"
mkdir -p "$RAWDIR"

echo "[$(date)] 开始更新广告规则..."

# ----- 规则源配置 -----
URLS=(
  "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt"
  "https://anti-ad.net/easylist.txt"
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  "https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt"
)

fetch_rules() {
  local url="$1"
  local out="$2"
  curl -sL --connect-timeout 10 --max-time 30 "$url" -o "$out" 2>/dev/null
  if [ -s "$out" ]; then
    echo "  ✓ $(basename $(echo $url | cut -d/ -f3-)) ($(wc -l < "$out") lines)"
    return 0
  fi
  echo "  ✗ 失败: $url"
  return 1
}

# 下载规则
echo "下载规则源..."
for url in "${URLS[@]}"; do
  fetch_rules "$url" "$RAWDIR/$(echo $url | md5sum | cut -c1-8)"
done

# 转换 dnsmasq 格式（先写到临时文件，再做全局去重）
echo "转换规则..."
TMP_OUTPUT="$TMPDIR/output.tmp"

{
  echo "# Adblock rules for dnsmasq"
  echo "# 自动更新于: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "# 来源: AdGuard DNS filter + anti-AD + StevenBlack + 秋风广告规则"
  echo ""

  for f in "$RAWDIR"/*; do
    [ -f "$f" ] || continue
    # 提取 ||domain^ 格式
    grep -oE '^\|\|([a-zA-Z0-9.-]+)\^' "$f" | sed 's/^||//;s/\^$//' | while read domain; do
      echo "address=/$domain/0.0.0.0"
    done
    # 提取 hosts 格式 (0.0.0.0 domain)
    grep -E '^0\.0\.0\.0\s+' "$f" | awk '{print $2}' | grep -v '^0\.0\.0\.0$' | grep -v '^localhost$' | while read domain; do
      echo "address=/$domain/0.0.0.0"
    done
  done
} > "$TMP_OUTPUT"

# 全局去重并统计
sort -u "$TMP_OUTPUT" > "$OUTPUT"
TOTAL=$(grep -c '^address=/' "$OUTPUT")
echo "完成: $TOTAL 条广告域名规则 -> $OUTPUT"

rm -rf "$TMPDIR"