#!/bin/bash
# XrayR 一键安装与管理脚本（screen 后台运行）

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

XRAYR_DIR="/etc/XrayR"
SCREEN_SESSION="XrayR"
ARCH="64"  # 默认 64 位，可根据需要修改

#==============================
# 安装 XrayR
#==============================
install_XrayR() {
    if [[ -d ${XRAYR_DIR} ]]; then
        rm -rf ${XRAYR_DIR}
    fi
    mkdir -p ${XRAYR_DIR}
    cd ${XRAYR_DIR}

    # 获取最新版本
    if [[ $# -eq 0 ]]; then
        LAST_VERSION=$(curl -Ls "https://api.github.com/repos/wyusgw/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        [[ -z "$LAST_VERSION" ]] && { echo -e "${red}检测版本失败${plain}"; exit 1; }
    else
        LAST_VERSION=$1
        [[ $1 != v* ]] && LAST_VERSION="v$1"
    fi

    echo -e ">>> 安装 XrayR ${LAST_VERSION} ..."
    wget -q -N --no-check-certificate -O XrayR-linux.zip \
        https://github.com/wyusgw/XrayR/releases/download/${LAST_VERSION}/XrayR-linux-${ARCH}.zip
    unzip -o XrayR-linux.zip
    rm -f XrayR-linux.zip
    chmod +x XrayR
    echo -e "${green}XrayR ${LAST_VERSION} 安装完成${plain}"
}

#==============================
# 启动 XrayR（screen 后台）
#==============================
start_XrayR() {
    if screen -list | grep -q "${SCREEN_SESSION}"; then
        echo ">>> XrayR 已在 screen 中运行"
        return
    fi
    echo ">>> 启动 XrayR（screen 后台）"
    screen -dmS ${SCREEN_SESSION} bash -c "cd ${XRAYR_DIR} && ./XrayR --config config.yml"
    echo ">>> 使用 'screen -r ${SCREEN_SESSION}' 查看输出"
}

#==============================
# 停止 XrayR
#==============================
stop_XrayR() {
    if screen -list | grep -q "${SCREEN_SESSION}"; then
        echo ">>> 停止 XrayR"
        screen -S ${SCREEN_SESSION} -X quit
    else
        echo ">>> XrayR 未运行"
    fi
}

#==============================
# 重启 XrayR
#==============================
restart_XrayR() {
    stop_XrayR
    sleep 1
    start_XrayR
}

#==============================
# 查看 XrayR 状态
#==============================
status_XrayR() {
    if screen -list | grep -q "${SCREEN_SESSION}"; then
        echo -e "${green}XrayR 正在运行${plain}"
    else
        echo -e "${red}XrayR 未运行${plain}"
    fi
}

#==============================
# 查看日志
#==============================
log_XrayR() {
    echo -e ">>> 查看 XrayR 输出"
    screen -r ${SCREEN_SESSION}
}

#==============================
# 菜单
#==============================
show_menu() {
    echo "------------------------------------------"
    echo "XrayR 管理菜单"
    echo "1. 安装 XrayR"
    echo "2. 启动 XrayR"
    echo "3. 停止 XrayR"
    echo "4. 重启 XrayR"
    echo "5. 查看状态"
    echo "6. 查看日志"
    echo "0. 退出"
    echo "------------------------------------------"
}

#==============================
# 主逻辑
#==============================
while true; do
    show_menu
    read -rp "请选择操作 [0-6]: " choice
    case $choice in
        1) install_XrayR ;;
        2) start_XrayR ;;
        3) stop_XrayR ;;
        4) restart_XrayR ;;
        5) status_XrayR ;;
        6) log_XrayR ;;
        0) exit 0 ;;
        *) echo "请输入正确数字 [0-6]" ;;
    esac
done
