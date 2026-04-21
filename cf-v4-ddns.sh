#!/usr/bin/env bash
set -o nounset
set -o pipefail

# =========================================================
# Cloudflare DDNS Script (CLI 参数版)
# =========================================================
#
# 用途：
#   自动检测公网 IP，并更新 Cloudflare DNS 记录
#
# =========================================================
# 参数说明（CLI）
# =========================================================
#
# -k  Cloudflare API Token
#     例：-k abc123xxxxx
#
# -z  Zone 域名（主域）
#     例：-z example.com
#
# -h  记录主机名（FQDN 或子域）
#     例：-h vpn 或 -h vpn.example.com
#
# -t  记录类型（可选）
#     A     = IPv4（默认）
#     AAAA  = IPv6
#
# -f  强制更新开关（可选）
#     true  = 强制更新（忽略 IP 是否变化）
#     false = 不强制（默认）
#
# -i  公网 IP 获取接口（可选）
#     默认：http://ipv4.icanhazip.com
#     可替换：
#       https://api.ipify.org
#       https://ipv6.icanhazip.com
#
# =========================================================

# =========================
# 默认参数
# =========================
CFKEY=""
CFZONE_NAME=""
CFRECORD_NAME=""
CFRECORD_TYPE="A"
CFTTL=120
FORCE=false
WANIPSITE="http://ipv4.icanhazip.com"

# =========================
# 解析 CLI 参数
# =========================
while getopts "k:z:h:t:f:i:" opt; do
  case "$opt" in
    k)
      # Cloudflare API Token
      CFKEY="$OPTARG"
      ;;
    z)
      # Zone 域名（example.com）
      CFZONE_NAME="$OPTARG"
      ;;
    h)
      # DNS 记录（vpn / vpn.example.com）
      CFRECORD_NAME="$OPTARG"
      ;;
    t)
      # 记录类型（A / AAAA）
      CFRECORD_TYPE="$OPTARG"
      ;;
    f)
      # 是否强制更新（true / false）
      FORCE="$OPTARG"
      ;;
    i)
      # 公网 IP 获取地址
      WANIPSITE="$OPTARG"
      ;;
    *)
      echo "用法: $0 -k API_KEY -z zone -h host -t A|AAAA -f true|false -i ip_source"
      exit 1
      ;;
  esac
done

# =========================
# 参数校验
# =========================
if [ -z "$CFKEY" ] || [ -z "$CFZONE_NAME" ] || [ -z "$CFRECORD_NAME" ]; then
  echo "错误：缺少必要参数 -k -z -h"
  exit 1
fi

# =========================
# 获取当前公网 IP
# =========================
WAN_IP=$(curl -s "$WANIPSITE")

# 本地缓存文件（用于判断 IP 是否变化）
WAN_IP_FILE="$HOME/.cf-wan_ip_$CFRECORD_NAME.txt"

if [ -f "$WAN_IP_FILE" ]; then
  OLD_WAN_IP=$(cat "$WAN_IP_FILE")
else
  OLD_WAN_IP=""
fi

# =========================
# IP 未变化则跳过更新
# =========================
if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = "false" ]; then
  echo "IP未变化，跳过更新"
  exit 0
fi

# =========================
# 自动补全域名（防止只填子域）
# =========================
if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && ! [[ "$CFRECORD_NAME" == *"$CFZONE_NAME" ]]; then
  CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
fi

# =========================
# 获取 Zone ID
# =========================
ZONE_RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json")

CFZONE_ID=$(echo "$ZONE_RESP" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$CFZONE_ID" ]; then
  echo "Zone 获取失败（检查 Token 或 Zone 名称）"
  exit 1
fi

# =========================
# 获取 DNS Record ID
# =========================
RECORD_RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json")

CFRECORD_ID=$(echo "$RECORD_RESP" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$CFRECORD_ID" ]; then
  echo "DNS 记录获取失败（检查域名是否存在）"
  exit 1
fi

# =========================
# 更新 DNS 记录
# =========================
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\":\"$CFRECORD_TYPE\",
    \"name\":\"$CFRECORD_NAME\",
    \"content\":\"$WAN_IP\",
    \"ttl\":$CFTTL
  }")

# =========================
# 判断更新结果
# =========================
if echo "$RESPONSE" | grep -q '"success":true'; then
  echo "更新成功: $WAN_IP"

  # 成功后才写入本地缓存 IP
  echo "$WAN_IP" > "$WAN_IP_FILE"
else
  echo "更新失败"
  echo "$RESPONSE"
  exit 1
fi
