#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

XRAYR_DIR="/etc/XrayR"
SCRIPT_PATH="/usr/bin/xrayr"

#=============================
# 安装自身为全局命令
#=============================
install_self() {
    cp "$0" "${SCRIPT_PATH}"
    chmod +x "${SCRIPT_PATH}"
    echo -e "${green}菜单脚本已更新到最新本地版本${plain}"
}

#=============================
# 安装 XrayR
#=============================
install_XrayR() {
    apk add --no-cache wget unzip openrc

    [[ -d ${XRAYR_DIR} ]] && rm -rf ${XRAYR_DIR}
    mkdir -p ${XRAYR_DIR}
    cd ${XRAYR_DIR} || exit

    LAST_VERSION=$(curl -Ls "https://api.github.com/repos/wyusgw/XrayR/releases/latest" \
                   | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$LAST_VERSION" ]] && { echo -e "${red}获取最新版本失败${plain}"; exit 1; }

    echo -e ">>> 下载 XrayR ${LAST_VERSION}"
    wget -c --no-check-certificate -O XrayR-linux.zip \
        "https://github.com/wyusgw/XrayR/releases/download/${LAST_VERSION}/XrayR-linux-64.zip"

    unzip -o XrayR-linux.zip
    rm -f XrayR-linux.zip
    chmod +x XrayR

    [[ ! -f config.yml ]] && touch config.yml
    [[ ! -f geoip.dat ]] && touch geoip.dat
    [[ ! -f geosite.dat ]] && touch geosite.dat

    echo -e "${green}XrayR 安装完成${plain}"
    install_self

    # 创建 OpenRC 服务文件
    cat > /etc/init.d/xrayr <<EOF
#!/sbin/openrc-run

command="${XRAYR_DIR}/XrayR"
command_args="--config ${XRAYR_DIR}/config.yml"
command_background="yes"
pidfile="/run/xrayr.pid"
name="XrayR"
EOF
    chmod +x /etc/init.d/xrayr
    rc-update add xrayr default >/dev/null 2>&1
    echo -e "${green}XrayR OpenRC 服务已创建并设置开机自启${plain}"
}

#=============================
# 状态检测
#=============================
get_service_status() {
    if rc-service xrayr status 2>/dev/null | grep -q "started"; then
        echo -e "${green}运行中${plain}"
    else
        echo -e "${red}未运行${plain}"
    fi
}

get_autostart_status() {
    if rc-update show 2>/dev/null | grep -Eq "\bxrayr\b.*default"; then
        echo -e "${green}已开启${plain}"
    else
        echo -e "${red}未开启${plain}"
    fi
}

#=============================
# 启动 / 停止 / 重启 / 状态
#=============================
start_XrayR() {
    if rc-service xrayr status 2>/dev/null | grep -q "started"; then
        echo -e "${yellow}XrayR 已在运行，无需重复启动${plain}"
    else
        rc-service xrayr start
    fi
}

stop_XrayR() {
    if rc-service xrayr status 2>/dev/null | grep -q "started"; then
        rc-service xrayr stop
    else
        echo -e "${yellow}XrayR 当前未运行，无需停止${plain}"
    fi
}

restart_XrayR() {
    if rc-service xrayr status 2>/dev/null | grep -q "started"; then
        rc-service xrayr restart
    else
        echo -e "${yellow}XrayR 未运行，正在直接启动${plain}"
        rc-service xrayr start
    fi
}

status_XrayR() {
    echo -e "XrayR 状态：$(get_service_status)"
}

#=============================
# 开机自启管理
#=============================
enable_autostart() {
    if rc-update show 2>/dev/null | grep -Eq "\bxrayr\b.*default"; then
        echo -e "${yellow}XrayR 已经设置过开机自启，无需重复添加${plain}"
    else
        rc-update add xrayr default >/dev/null 2>&1
        rc-status >/dev/null 2>&1
        echo -e "${green}已成功设置开机自启${plain}"
    fi
}

disable_autostart() {
    if rc-update show 2>/dev/null | grep -Eq "\bxrayr\b.*default"; then
        rc-update del xrayr default >/dev/null 2>&1
        rc-status >/dev/null 2>&1
        echo -e "${green}已取消开机自启${plain}"
    else
        echo -e "${yellow}当前未设置开机自启${plain}"
    fi
}

#=============================
# 日志查看
#=============================
log_XrayR() {
    tail -f /var/log/xrayr.log
}

error_log_XrayR() {
    tail -f /var/log/xrayr-error.log
}

#=============================
# 卸载
#=============================
uninstall_XrayR() {
    stop_XrayR
    disable_autostart
    rm -rf ${XRAYR_DIR}
    [[ -f ${SCRIPT_PATH} ]] && rm -f ${SCRIPT_PATH}
    [[ -f /etc/init.d/xrayr ]] && rm -f /etc/init.d/xrayr
    echo -e "${green}卸载完成${plain}"
}

#=============================
# 更新菜单脚本自身
#=============================
update_self() {
    install_self
}

#=============================
# 菜单
#=============================
while true; do
    service_status=$(get_service_status)
    autostart_status=$(get_autostart_status)

    echo "--------------------------------------"
    echo "XrayR 管理菜单（OpenRC 智能版）"
    echo -e "服务状态：${service_status}"
    echo -e "开机自启：${autostart_status}"
    echo "--------------------------------------"
    echo "1. 安装 XrayR"
    echo "2. 启动 XrayR"
    echo "3. 停止 XrayR"
    echo "4. 重启 XrayR"
    echo "5. 查看 XrayR 状态"
    echo "6. 查看运行日志"
    echo "7. 查看错误日志"
    echo "8. 开启开机自启"
    echo "9. 关闭开机自启"
    echo "10. 卸载 XrayR"
    echo "11. 更新菜单脚本自身"
    echo "0. 退出"
    echo "--------------------------------------"
    read -rp "请选择操作 [0-11]: " choice
    case $choice in
        1) install_XrayR ;;
        2) start_XrayR ;;
        3) stop_XrayR ;;
        4) restart_XrayR ;;
        5) status_XrayR ;;
        6) log_XrayR ;;
        7) error_log_XrayR ;;
        8) enable_autostart ;;
        9) disable_autostart ;;
        10) uninstall_XrayR ;;
        11) update_self ;;
        0) exit 0 ;;
        *) echo "请输入正确数字 [0-11]" ;;
    esac
    echo
    sleep 1
done
