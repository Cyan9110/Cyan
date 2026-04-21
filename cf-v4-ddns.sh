#!/usr/bin/env bash
set -o nounset
set -o pipefail

# ===== 配置 =====
CFKEY=""
CFZONE_NAME="vcweb.top"
CFRECORD_NAME=""
CFRECORD_TYPE="A"
CFTTL=120
FORCE=false

WANIPSITE="https://api.ipify.org"

# ===== 获取IP =====
WAN_IP=$(curl -s "$WANIPSITE")

WAN_IP_FILE="$HOME/.cf-wan_ip_$CFRECORD_NAME.txt"

if [ -f "$WAN_IP_FILE" ]; then
  OLD_WAN_IP=$(cat "$WAN_IP_FILE")
else
  OLD_WAN_IP=""
fi

if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = false ]; then
  echo "IP未变化，跳过更新"
  exit 0
fi

# ===== 补全域名 =====
if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && ! [[ "$CFRECORD_NAME" == *"$CFZONE_NAME" ]]; then
  CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
fi

# ===== Zone ID =====
ZONE_RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json")

CFZONE_ID=$(echo "$ZONE_RESP" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$CFZONE_ID" ]; then
  echo "Zone获取失败（请检查Token权限）"
  exit 1
fi

# ===== Record ID =====
RECORD_RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json")

CFRECORD_ID=$(echo "$RECORD_RESP" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$CFRECORD_ID" ]; then
  echo "记录获取失败（请检查域名是否存在）"
  exit 1
fi

# ===== 更新DNS =====
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
  -H "Authorization: Bearer $CFKEY" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\":\"$CFRECORD_TYPE\",
    \"name\":\"$CFRECORD_NAME\",
    \"content\":\"$WAN_IP\",
    \"ttl\":$CFTTL
  }")

if echo "$RESPONSE" | grep -q '"success":true'; then
  echo "更新成功: $WAN_IP"
  echo "$WAN_IP" > "$WAN_IP_FILE"
else
  echo "更新失败（请检查Token权限或DNS记录）"
  exit 1
fi
