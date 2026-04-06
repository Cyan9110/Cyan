#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

XRAYR_DIR="/etc/XrayR"
SCRIPT_PATH="/usr/bin/xrayr"
LOG_FILE="/var/log/xrayr.log"
ERROR_LOG_FILE="/var/log/xrayr-error.log"

#=============================
# 安装自身为全局命令
#=============================
install_self() {
    cp "$0" "${SCRIPT_PATH}"
    chmod +x "${SCRIPT_PATH}"
    echo -e "${green}菜单脚本已更新到最新本地版本${plain}"
}

#=============================
# 日志轮转与权限
#=============================
rotate_log() {
    for logfile in "$LOG_FILE" "$ERROR_LOG_FILE"; do
        [[ ! -f "$logfile" ]] && touch "$logfile"
        chown root:root "$logfile"
        chmod 644 "$logfile"
        maxsize=$((20*1024*1024))
        filesize=$(stat -c%s "$logfile" 2>/dev/null || echo 0)
        if (( filesize > maxsize )); then
            mv "$logfile" "${logfile}.1"
            touch "$logfile"
        fi
    done
}

setup_logrotate() {
    apk add --no-cache logrotate >/dev/null 2>&1
    cat > /etc/logrotate.d/xrayr <<EOF
$LOG_FILE $ERROR_LOG_FILE {
    daily
    rotate 7
    size 20M
    compress
    missingok
    notifempty
    copytruncate
}
EOF
    echo -e "${green}logrotate 已配置，日志自动轮转已启用${plain}"
}

clean_logs() {
    rm -f "$LOG_FILE" "$ERROR_LOG_FILE"
    touch "$LOG_FILE" "$ERROR_LOG_FILE"
    echo -e "${green}日志已清理${plain}"
}

#=============================
# 安装 XrayR（仅当不存在）
#=============================
install_XrayR() {
    if [[ -f "${XRAYR_DIR}/XrayR" ]]; then
        echo -e "${yellow}检测到已有 XrayR 文件，跳过下载安装${plain}"
        rebuild_openrc_service
        return
    fi

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
    rebuild_openrc_service
}

#=============================
# 重建 OpenRC 服务文件（带日志重定向）
#=============================
rebuild_openrc_service() {
    mkdir -p /var/log
    touch "$LOG_FILE" "$ERROR_LOG_FILE"
    chown root:root "$LOG_FILE" "$ERROR_LOG_FILE"
    chmod 644 "$LOG_FILE" "$ERROR_LOG_FILE"

    cat > /etc/init.d/xrayr <<EOF
#!/sbin/openrc-run

name="XrayR"
description="XrayR Service"

command="${XRAYR_DIR}/XrayR"
command_args="--config ${XRAYR_DIR}/config.yml"

# 使用 OpenRC 官方守护
supervisor="supervise-daemon"
command_background="yes"

# 日志
output_log="${LOG_FILE}"
error_log="${ERROR_LOG_FILE}"

# 自动守护
respawn_delay=5
respawn_max=0
respawn_period=60
EOF

    chmod +x /etc/init.d/xrayr
    rc-update add xrayr default >/dev/null 2>&1

    echo -e "${green}OpenRC 服务文件已重建（最终稳定版）${plain}"
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
    if rc-update show 2>/dev/null | grep -Eq "\\bxrayr\\b.*default"; then
        echo -e "${green}已开启${plain}"
    else
        echo -e "${red}未开启${plain}"
    fi
}

#=============================
# 启动 / 停止 / 重启 / 状态
#=============================
start_XrayR() {
    rotate_log
    rc-service xrayr start
}

stop_XrayR() {
    rc-service xrayr stop
}

restart_XrayR() {
    rotate_log
    rc-service xrayr restart
}

status_XrayR() {
    echo -e "XrayR 状态：$(get_service_status)"
}

#=============================
# 开机自启管理
#=============================
enable_autostart() {
    rc-update add xrayr default >/dev/null 2>&1
    echo -e "${green}已成功设置开机自启${plain}"
}

disable_autostart() {
    rc-update del xrayr default >/dev/null 2>&1
    echo -e "${green}已取消开机自启${plain}"
}

#=============================
# 日志查看
#=============================
log_XrayR() {
    [[ ! -f "$LOG_FILE" ]] && touch "$LOG_FILE"
    echo -e ">>> 正在查看 XrayR 运行日志（Ctrl+C 退出）"
    tail -f "$LOG_FILE"
}

error_log_XrayR() {
    [[ ! -f "$ERROR_LOG_FILE" ]] && touch "$ERROR_LOG_FILE"
    echo -e ">>> 正在查看 XrayR 错误日志（Ctrl+C 退出）"
    tail -f "$ERROR_LOG_FILE"
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
    echo "XrayR 管理菜单（OpenRC 智能版 + 日志保护 20MB）"
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
    echo "10. 更新菜单脚本自身"
    echo "11. 重建 OpenRC 服务文件"
    echo "12. 配置 logrotate 自动轮转日志"
    echo "13. 清理日志"
    echo "14. 卸载 XrayR"
    echo "0. 退出"
    echo "--------------------------------------"
    read -rp "请选择操作 [0-14]: " choice
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
        10) update_self ;;
        11) rebuild_openrc_service ;;
        12) setup_logrotate ;;
        13) clean_logs ;;
        14) uninstall_XrayR ;;
        0) exit 0 ;;
        *) echo "请输入正确数字 [0-14]" ;;
    esac
    echo
    sleep 1
done
