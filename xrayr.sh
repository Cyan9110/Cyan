#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

XRAYR_DIR="/etc/XrayR"
SCREEN_SESSION="XrayR"
ARCH="64"
GUARD_FILE="/usr/bin/xrayr_guard.sh"   # 守护脚本放 /usr/bin，Alpine 默认存在
SCRIPT_PATH=""                          # 全局命令路径，稍后确定

#=============================
# 安装 XrayR
#=============================
install_XrayR() {
    apk add --no-cache wget unzip screen

    [[ -d ${XRAYR_DIR} ]] && rm -rf ${XRAYR_DIR}
    mkdir -p ${XRAYR_DIR}
    cd ${XRAYR_DIR} || exit

    LAST_VERSION=$(curl -Ls "https://api.github.com/repos/wyusgw/XrayR/releases/latest" \
                   | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$LAST_VERSION" ]] && { echo -e "${red}获取最新版本失败${plain}"; exit 1; }

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

    # 安装自身为全局命令
    install_self
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
    echo -e "${green}守护脚本已安装（未启动）${plain}"
}

start_guard() {
    install_guard
    if pgrep -f "${GUARD_FILE}" >/dev/null; then
        echo ">>> 守护已运行"
    else
        nohup ${GUARD_FILE} >/dev/null 2>&1 &
        echo ">>> 守护已启动"
    fi

    # 开机自启
    mkdir -p /etc/local.d
    echo "${GUARD_FILE} &" > /etc/local.d/xrayr.start
    chmod +x /etc/local.d/xrayr.start
    rc-update add local default
    rc-service local start
    echo -e "${green}守护已设置开机自启${plain}"
}

stop_guard() {
    pkill -f "${GUARD_FILE}" >/dev/null 2>&1
    echo ">>> 守护已停止"

    # 移除开机自启
    rm -f /etc/local.d/xrayr.start
    rc-update del local default >/dev/null 2>&1
    echo -e "${green}守护开机自启已移除${plain}"
}

status_guard() {
    if pgrep -f "${GUARD_FILE}" >/dev/null; then
        echo -e "${green}守护正在运行${plain}"
    else
        echo -e "${red}守护未运行${plain}"
    fi
}

#=============================
# 安装自身为全局命令
#=============================
install_self() {
    SCRIPT_REAL_PATH=$(readlink -f "$0")

    # Alpine 默认 /usr/local/bin 可能不存在，优先使用
    if [[ -d /usr/local/bin ]]; then
        SCRIPT_PATH="/usr/local/bin/xrayr"
    else
        SCRIPT_PATH="/usr/bin/xrayr"
    fi

    cp "$SCRIPT_REAL_PATH" ${SCRIPT_PATH}
    chmod +x ${SCRIPT_PATH}
    echo -e "${green}命令 'xrayr' 已生成，可直接在终端输入使用${plain}"
}

#=============================
# 卸载 XrayR
#=============================
uninstall_XrayR() {
    echo -e "${red}正在卸载 XrayR...${plain}"
    stop_guard
    stop_XrayR
    rm -rf ${XRAYR_DIR}
    [[ -f ${SCRIPT_PATH} ]] && rm -f ${SCRIPT_PATH}
    [[ -f ${GUARD_FILE} ]] && rm -f ${GUARD_FILE}
    echo -e "${green}卸载完成，包括 XrayR 程序、守护脚本和全局命令${plain}"
}

#=============================
# 菜单
#=============================
while true; do
    echo "--------------------------------------"
    echo "XrayR 管理菜单（无日志版）"
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
