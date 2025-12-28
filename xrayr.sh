#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

XRAYR_DIR="/etc/XrayR"
SCREEN_SESSION="XrayR"
ARCH="64"
GUARD_FILE="/usr/local/bin/xrayr_guard.sh"

#=============================
# 安装 XrayR
#=============================
install_XrayR() {
    apk add --no-cache wget unzip screen

    [[ -d ${XRAYR_DIR} ]] && rm -rf ${XRAYR_DIR}
    mkdir -p ${XRAYR_DIR}
    cd ${XRAYR_DIR}

    LAST_VERSION=$(curl -Ls "https://api.github.com/repos/wyusgw/XrayR/releases/latest" \
                   | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$LAST_VERSION" ]] && { echo -e "${red}获取最新版本失败${plain}"; exit 1; }

    echo -e ">>> 下载 XrayR ${LAST_VERSION}"
    wget -q -N --no-check-certificate -O XrayR-linux.zip \
        "https://github.com/wyusgw/XrayR/releases/download/${LAST_VERSION}/XrayR-linux-${ARCH}.zip"

    unzip -o XrayR-linux.zip
    rm -f XrayR-linux.zip
    chmod +x XrayR
    echo -e "${green}XrayR 安装完成${plain}"
}

#=============================
# 启动 / 停止 / 重启 XrayR
#=============================
start_XrayR() {
    if screen -list | grep -q "${SCREEN_SESSION}"; then
        echo ">>> XrayR 已在运行"
        return
    fi
    echo ">>> 启动 XrayR（无日志）"
    screen -dmS ${SCREEN_SESSION} bash -c "cd ${XRAYR_DIR} && ./XrayR --config config.yml"
}

stop_XrayR() {
    if screen -list | grep -q "${SCREEN_SESSION}"; then
        echo ">>> 停止 XrayR"
        screen -S ${SCREEN_SESSION} -X quit
    else
        echo ">>> XrayR 未运行"
    fi
}

restart_XrayR() {
    stop_XrayR
    sleep 1
    start_XrayR
}

status_XrayR() {
    if screen -list | grep -q "${SCREEN_SESSION}"; then
        echo -e "${green}XrayR 正在运行${plain}"
    else
        echo -e "${red}XrayR 未运行${plain}"
    fi
}

log_XrayR() {
    echo -e ">>> 附加到 screen 查看 XrayR 输出（退出不会停止进程）"
    screen -r ${SCREEN_SESSION}
}

#=============================
# 安装守护脚本
#=============================
install_guard() {
    cat > ${GUARD_FILE} <<EOF
#!/bin/bash
XRAYR_DIR="${XRAYR_DIR}"
SCREEN_SESSION="${SCREEN_SESSION}"

while true; do
    if ! screen -list | grep -q "\${SCREEN_SESSION}"; then
        screen -dmS \${SCREEN_SESSION} bash -c "cd \${XRAYR_DIR} && ./XrayR --config config.yml"
    fi
    sleep 10
done
EOF
    chmod +x ${GUARD_FILE}

    # 开机自启
    mkdir -p /etc/local.d
    echo "${GUARD_FILE} &" > /etc/local.d/xrayr.start
    chmod +x /etc/local.d/xrayr.start
    rc-update add local default
    rc-service local start

    echo -e "${green}守护脚本已安装并设置开机自启${plain}"
}

#=============================
# 守护控制
#=============================
start_guard() {
    if pgrep -f "${GUARD_FILE}" >/dev/null; then
        echo ">>> 守护已运行"
    else
        nohup ${GUARD_FILE} >/dev/null 2>&1 &
        echo ">>> 守护已启动"
    fi
}

stop_guard() {
    pkill -f "${GUARD_FILE}"
    echo ">>> 守护已停止"
}

status_guard() {
    if pgrep -f "${GUARD_FILE}" >/dev/null; then
        echo -e "${green}守护正在运行${plain}"
    else
        echo -e "${red}守护未运行${plain}"
    fi
}

#=============================
# 菜单
#=============================
while true; do
    echo "--------------------------------------"
    echo "XrayR 管理菜单（无日志版）"
    echo "1. 安装 XrayR + 守护"
    echo "2. 启动 XrayR"
    echo "3. 停止 XrayR"
    echo "4. 重启 XrayR"
    echo "5. 查看 XrayR 状态"
    echo "6. 附加 screen 查看输出"
    echo "7. 启动守护"
    echo "8. 停止守护"
    echo "9. 查看守护状态"
    echo "0. 退出"
    echo "--------------------------------------"
    read -rp "请选择操作 [0-9]: " choice
    case $choice in
        1) install_XrayR; install_guard ;;
        2) start_XrayR ;;
        3) stop_XrayR ;;
        4) restart_XrayR ;;
        5) status_XrayR ;;
        6) log_XrayR ;;
        7) start_guard ;;
        8) stop_guard ;;
        9) status_guard ;;
        0) exit 0 ;;
        *) echo "请输入正确数字 [0-9]" ;;
    esac
done
