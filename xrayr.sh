#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

XRAYR_DIR="/etc/XrayR"
SCREEN_SESSION="XrayR"
ARCH="64"
GUARD_FILE="/usr/bin/xrayr_guard.sh"
SCRIPT_PATH="/usr/bin/xrayr"

#=============================
# 清理 screen 残留
#=============================
clean_screen() {
    screen -wipe >/dev/null 2>&1

    # 删除所有 dead / orphan 的 XrayR socket
    find /root/.screen -type s -name "*.${SCREEN_SESSION}" -exec rm -f {} \; 2>/dev/null
}

#=============================
# 检测 XrayR 是否真实运行
#=============================
is_xrayr_running() {
    pgrep -f "${XRAYR_DIR}/XrayR --config config.yml" >/dev/null
}

#=============================
# 安装 XrayR
#=============================
install_XrayR() {
    apk add --no-cache wget unzip screen curl

    [[ -d ${XRAYR_DIR} ]] && rm -rf "${XRAYR_DIR}"
    mkdir -p "${XRAYR_DIR}"
    cd "${XRAYR_DIR}" || exit 1

    LAST_VERSION=$(curl -Ls "https://api.github.com/repos/wyusgw/XrayR/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    [[ -z "$LAST_VERSION" ]] && {
        echo -e "${red}获取最新版本失败${plain}"
        exit 1
    }

    echo -e ">>> 下载 XrayR ${LAST_VERSION}"
    wget -c --no-check-certificate -O XrayR-linux.zip \
        "https://github.com/wyusgw/XrayR/releases/download/${LAST_VERSION}/XrayR-linux-${ARCH}.zip"

    unzip -o XrayR-linux.zip
    rm -f XrayR-linux.zip
    chmod +x XrayR

    [[ ! -f config.yml ]] && touch config.yml
    [[ ! -f geoip.dat ]] && touch geoip.dat
    [[ ! -f geosite.dat ]] && touch geosite.dat

    echo -e "${green}XrayR 安装完成${plain}"

    install_self
}

#=============================
# 启动
#=============================
start_XrayR() {
    clean_screen

    if is_xrayr_running; then
        echo ">>> XrayR 已在运行"
        return
    fi

    echo ">>> 启动 XrayR（无日志）"
    screen -dmS "${SCREEN_SESSION}" bash -c "cd ${XRAYR_DIR} && exec ./XrayR --config config.yml"
}

#=============================
# 停止
#=============================
stop_XrayR() {
    if is_xrayr_running; then
        echo ">>> 停止 XrayR"
        pkill -f "${XRAYR_DIR}/XrayR --config config.yml"
        sleep 1
        clean_screen
    else
        clean_screen
        echo ">>> XrayR 未运行"
    fi
}

#=============================
# 重启
#=============================
restart_XrayR() {
    stop_XrayR
    sleep 1
    clean_screen
    start_XrayR
}

#=============================
# 状态
#=============================
status_XrayR() {
    if is_xrayr_running; then
        echo -e "${green}XrayR 正在运行${plain}"
    else
        clean_screen
        echo -e "${red}XrayR 未运行${plain}"
    fi
}

#=============================
# 查看输出
#=============================
log_XrayR() {
    if ! is_xrayr_running; then
        clean_screen
        echo -e "${red}XrayR 未运行，无法查看日志${plain}"
        return
    fi

    clean_screen

    if ! screen -list | grep -q "${SCREEN_SESSION}"; then
        echo -e "${yellow}检测到 XrayR 进程存在但 screen 会话丢失${plain}"
        echo -e "${yellow}当前无法恢复历史输出，请后续使用重启后重新接管日志${plain}"
        return
    fi

    echo -e "${green}>>> 附加到 XrayR 输出（Ctrl+A+D 退出，不影响运行）${plain}"
    screen -D -r "${SCREEN_SESSION}"
}

#=============================
# 安装守护
#=============================
install_guard() {
    cat > "${GUARD_FILE}" <<EOF
#!/bin/bash
XRAYR_DIR="${XRAYR_DIR}"
SCREEN_SESSION="${SCREEN_SESSION}"

is_xrayr_running() {
    pgrep -f "\${XRAYR_DIR}/XrayR --config config.yml" >/dev/null
}

clean_screen() {
    screen -wipe >/dev/null 2>&1
    find /root/.screen -type s -name "*.\${SCREEN_SESSION}" -exec rm -f {} \; 2>/dev/null
}

while true; do
    if ! is_xrayr_running; then
        clean_screen
        screen -dmS "\${SCREEN_SESSION}" bash -c "cd \${XRAYR_DIR} && exec ./XrayR --config config.yml"
    fi
    sleep 10
done
EOF

    chmod +x "${GUARD_FILE}"
    echo -e "${green}守护脚本已安装（未启动）${plain}"
}

#=============================
# 启动守护
#=============================
start_guard() {
    install_guard

    if pgrep -f "${GUARD_FILE}" >/dev/null; then
        echo ">>> 守护已运行"
    else
        nohup "${GUARD_FILE}" >/dev/null 2>&1 &
        echo ">>> 守护已启动"
    fi

    mkdir -p /etc/local.d
    echo "${GUARD_FILE} &" > /etc/local.d/xrayr.start
    chmod +x /etc/local.d/xrayr.start
    rc-update add local default >/dev/null 2>&1
    rc-service local start >/dev/null 2>&1

    echo -e "${green}守护已设置开机自启${plain}"
}

#=============================
# 停止守护
#=============================
stop_guard() {
    pkill -f "${GUARD_FILE}" >/dev/null 2>&1
    echo ">>> 守护已停止"

    rm -f /etc/local.d/xrayr.start
    rc-update del local default >/dev/null 2>&1

    echo -e "${green}守护开机自启已移除${plain}"
}

#=============================
# 守护状态
#=============================
status_guard() {
    if pgrep -f "${GUARD_FILE}" >/dev/null; then
        echo -e "${green}守护正在运行${plain}"
    else
        echo -e "${red}守护未运行${plain}"
    fi
}

#=============================
# 安装全局命令
#=============================
install_self() {
    curl -o /usr/bin/xrayr -Ls https://raw.githubusercontent.com/Cyan9110/Cyan/refs/heads/main/xrayr.sh
    chmod +x /usr/bin/xrayr
    echo -e "${green}命令 xrayr 已生成${plain}"
}

#=============================
# 卸载
#=============================
uninstall_XrayR() {
    echo -e "${red}正在卸载 XrayR...${plain}"
    stop_guard
    stop_XrayR
    clean_screen
    rm -rf "${XRAYR_DIR}"
    rm -f "${GUARD_FILE}"
    rm -f "${SCRIPT_PATH}"
    echo -e "${green}卸载完成${plain}"
}

#=============================
# 菜单
#=============================
while true; do
    echo "--------------------------------------"
    echo "XrayR 管理菜单（稳定修复版）"
    echo "1. 安装 XrayR"
    echo "2. 启动 XrayR"
    echo "3. 停止 XrayR"
    echo "4. 重启 XrayR"
    echo "5. 查看 XrayR 状态"
    echo "6. 附加 screen 查看输出"
    echo "7. 启动守护（含开机自启）"
    echo "8. 停止守护（移除开机自启）"
    echo "9. 查看守护状态"
    echo "10. 卸载 XrayR"
    echo "0. 退出"
    echo "--------------------------------------"
    read -rp "请选择操作 [0-10]: " choice

    case $choice in
        1) install_XrayR ;;
        2) start_XrayR ;;
        3) stop_XrayR ;;
        4) restart_XrayR ;;
        5) status_XrayR ;;
        6) log_XrayR ;;
        7) start_guard ;;
        8) stop_guard ;;
        9) status_guard ;;
        10) uninstall_XrayR ;;
        0) exit 0 ;;
        *) echo "请输入正确数字 [0-10]" ;;
    esac
done
