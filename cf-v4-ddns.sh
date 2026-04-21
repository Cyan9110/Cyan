#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# ===== 配置区域 =====

# API Token（不是 Global Key！）
CFKEY="cfut_wH6wSidoe1xyppx1yyOBIPud6H9vNMAEI0siKMKab392c685"

# Zone 名
CFZONE_NAME="vcweb.top"

# 主机名（支持子域）
CFRECORD_NAME="mlxy"

# 记录类型：A=IPv4 / AAAA=IPv6
CFRECORD_TYPE="A"

# TTL
CFTTL=120

# 是否强制更新
FORCE=false

# 获取公网IP
WANIPSITE="http://ipv4.icanhazip.com" # Site to retrieve WAN ip, other examples are: bot.whatismyipaddress.com, https://api.ipify.org/
# ===== 自动处理 =====

# 补全 FQDN
if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && ! [[ "$CFRECORD_NAME" == *"$CFZONE_NAME" ]]; then
  CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
  echo "=> 自动补全为: $CFRECORD_NAME"
fi

# 获取当前 IP
WAN_IP=$(curl -s $WANIPSITE)

# 本地缓存文件
WAN_IP_FILE="$HOME/.cf-wan_ip_$CFRECORD_NAME.txt"

if [ -f "$WAN_IP_FILE" ]; then
  OLD_WAN_IP=$(cat "$WAN_IP_FILE")
else
  OLD_WAN_IP=""
fi

# IP 没变就退出
if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = false ]; then
  echo "IP 未变化: $WAN_IP"
  exit 0
fi

echo "当前IP: $WAN_IP"

# ===== 获取 Zone ID =====
CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [ "$CFZONE_ID" = "null" ] || [ -z "$CFZONE_ID" ]; then
  echo "获取 Zone ID 失败"
  exit 1
fi

# ===== 获取 Record ID =====
CFRECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [ "$CFRECORD_ID" = "null" ] || [ -z "$CFRECORD_ID" ]; then
  echo "获取 Record ID 失败（记录可能不存在）"
  exit 1
fi

# ===== 更新 DNS =====
echo "更新 DNS: $CFRECORD_NAME -> $WAN_IP"

RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\":\"$CFRECORD_TYPE\",
    \"name\":\"$CFRECORD_NAME\",
    \"content\":\"$WAN_IP\",
    \"ttl\":$CFTTL
  }")

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
  echo "✅ 更新成功"
  echo "$WAN_IP" > "$WAN_IP_FILE"
else
  echo "❌ 更新失败"
  echo "$RESPONSE"
  exit 1
fi
