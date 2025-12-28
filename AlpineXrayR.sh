#!/bin/sh
# Alpine XrayR Install Script (No config generator)

echo "===== Alpine XrayR Installer ====="

SERVICE_NAME="XrayR"
INSTALL_DIR="/etc/XrayR"
BIN_PATH="/usr/bin/XrayR"
SERVICE_FILE="/etc/init.d/XrayR"

apk update
apk add unzip wget curl openrc jq bash

mkdir -p $INSTALL_DIR

arch=$(arch)
if [ "$arch" = "x86_64" ]; then
    arch="amd64"
elif [ "$arch" = "aarch64" ]; then
    arch="arm64"
else
    arch="amd64"
fi

echo "检测架构: $arch"

latest=$(curl -Ls https://api.github.com/repos/XrayR-project/XrayR/releases/latest \
  | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

echo "最新版本: $latest"

wget -O $INSTALL_DIR/XrayR-linux.zip \
  https://github.com/XrayR-project/XrayR/releases/download/$latest/XrayR-linux-$arch.zip

unzip -o $INSTALL_DIR/XrayR-linux.zip -d $INSTALL_DIR
chmod +x $INSTALL_DIR/XrayR
ln -sf $INSTALL_DIR/XrayR $BIN_PATH

cat > $SERVICE_FILE <<EOF
#!/sbin/openrc-run
depend() { need net; after sshd; }
start() {
  ebegin "Starting XrayR"
  start-stop-daemon --start --exec /usr/bin/XrayR --background
  eend \$?
}
stop() {
  ebegin "Stopping XrayR"
  start-stop-daemon --stop --exec /usr/bin/XrayR
  eend \$?
}
restart() {
  ebegin "Restarting XrayR"
  start-stop-daemon --stop --exec /usr/bin/XrayR
  sleep 1
  start-stop-daemon --start --exec /usr/bin/XrayR --background
  eend \$?
}
EOF

chmod +x $SERVICE_FILE
rc-update add XrayR default

echo
echo "✔ XrayR 安装完成"
echo "✔ 服务已注册到 OpenRC"
echo "⚠ 请手动放置配置文件：$INSTALL_DIR/config.yml"
echo
echo "常用命令："
echo "  rc-service XrayR start"
echo "  rc-service XrayR stop"
echo "  rc-service XrayR restart"
echo "  rc-service XrayR status"
