#!/bin/sh

# 定义颜色
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

XRAYR_DIR="/etc/XrayR"
SCRIPT_PATH_LOWER="/usr/bin/xrayr"
SCRIPT_PATH_UPPER="/usr/bin/XrayR"

LOG_FILE="/var/log/xrayr.log"
ERROR_LOG_FILE="/var/log/xrayr-error.log"

#=============================
# 安装自身为全局命令 (同时支持 xrayr 和 XrayR)
#=============================
install_self(){
    # 如果脚本文件存在，执行复制与链接
    if [ -n "$0" ] && [ -f "$0" ]; then
        # 1. 复制到小写快捷命令 /usr/bin/xrayr
        cp "$0" "$SCRIPT_PATH_LOWER"
        chmod +x "$SCRIPT_PATH_LOWER"

        # 2. 创建大写软链接 /usr/bin/XrayR
        rm -f "$SCRIPT_PATH_UPPER"
        ln -sf "$SCRIPT_PATH_LOWER" "$SCRIPT_PATH_UPPER"

        echo -e "${green}脚本已成功配置为全局命令！${plain}"
        echo -e "现在您可以在控制台直接输入 ${green}xrayr${plain} 或 ${green}XrayR${plain} 打开此菜单。"
    else
        echo -e "${red}无法获取当前脚本路径，全局快捷命令更新失败。${plain}"
    fi
}

#=============================
# 安装依赖
#=============================
install_dependencies(){
    apk add --no-cache \
        wget \
        curl \
        unzip \
        openrc \
        ca-certificates \
        logrotate \
        >/dev/null 2>&1
}

#=============================
# 初始化日志
#=============================
init_logs(){
    mkdir -p /var/log
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
    [ ! -f "$ERROR_LOG_FILE" ] && touch "$ERROR_LOG_FILE"
    chown root:root "$LOG_FILE" "$ERROR_LOG_FILE"
    chmod 644 "$LOG_FILE" "$ERROR_LOG_FILE"
}

#=============================
# 日志轮转配置
#=============================
setup_logrotate(){
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
    echo -e "${green}logrotate 配置完成${plain}"
}

#=============================
# 清理日志
#=============================
clean_logs(){
    > "$LOG_FILE"
    > "$ERROR_LOG_FILE"
    echo -e "${green}日志已清空${plain}"
}

#=============================
# 重建 OpenRC 服务文件 (Supervise Daemon 强力守护版)
#=============================
rebuild_openrc_service(){
    init_logs

    # 检查 supervise-daemon 支持
    if ! command -v supervise-daemon >/dev/null 2>&1 && [ ! -x /sbin/supervise-daemon ]; then
        echo -e "${yellow}提示: 尝试补充安装 openrc 扩展依赖...${plain}"
        apk add --no-cache openrc >/dev/null 2>&1
    fi

cat > /etc/init.d/xrayr <<EOF
#!/sbin/openrc-run

name="XrayR"
description="XrayR Service with Supervise Daemon"

# 使用 supervise-daemon 守护进程，防止崩溃后状态死锁
supervisor="supervise-daemon"

command="${XRAYR_DIR}/XrayR"
command_args="--config ${XRAYR_DIR}/config.yml"

# supervise 模式下设为 no
command_background="no"

pidfile="/run/xrayr.pid"
output_log="${LOG_FILE}"
error_log="${ERROR_LOG_FILE}"

# 崩溃自动拉起配置 (5秒后拉起，60秒内最多10次)
respawn_delay=5
respawn_max=10
respawn_period=60

depend(){
    need net
}
EOF

    chmod +x /etc/init.d/xrayr

    # 清理可能存在的旧卡死状态 (zap)
    rc-service xrayr stop >/dev/null 2>&1
    rc-service xrayr zap >/dev/null 2>&1

    rc-update add xrayr default >/dev/null 2>&1
    echo -e "${green}OpenRC 服务配置重建完成（已开启自动看守拉起）${plain}"
}

#=============================
# 安装 XrayR
#=============================
install_XrayR(){
    install_dependencies

    if [ -x "${XRAYR_DIR}/XrayR" ]; then
        echo -e "${yellow}检测到已有 XrayR 主程序，跳过二进制下载${plain}"
        rebuild_openrc_service
        install_self
        return
    fi

    mkdir -p "$XRAYR_DIR"
    cd "$XRAYR_DIR" || exit 1

    echo -e "${yellow}正在获取 XrayR 最新版本...${plain}"
    LAST_VERSION=$(curl -fsSL https://api.github.com/repos/wyusgw/XrayR/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$LAST_VERSION" ]; then
        echo -e "${red}获取 XrayR 版本失败，请检查网络或 GitHub API 限制${plain}"
        return 1
    fi

    echo -e "准备下载 XrayR ${green}${LAST_VERSION}${plain}"

    wget -c --no-check-certificate -O XrayR-linux.zip \
        "https://github.com/wyusgw/XrayR/releases/download/${LAST_VERSION}/XrayR-linux-64.zip"

    if [ $? -ne 0 ] || [ ! -f XrayR-linux.zip ]; then
        echo -e "${red}下载 XrayR 失败${plain}"
        rm -f XrayR-linux.zip
        return 1
    fi

    unzip -o XrayR-linux.zip
    rm -f XrayR-linux.zip
    chmod +x XrayR

    [ ! -f config.yml ] && echo "Log:" > config.yml

    init_logs
    install_self
    rebuild_openrc_service

    echo -e "${green}XrayR 安装完成！${plain}"
}

#=============================
# 清理残留 PID
#=============================
clear_stale_pid(){
    PID_FILE="/run/xrayr.pid"
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            if ! kill -0 "$pid" 2>/dev/null; then
                rm -f "$PID_FILE"
            fi
        else
            rm -f "$PID_FILE"
        fi
    fi
}

#=============================
# 检查配置
#=============================
check_config(){
    if [ ! -f "${XRAYR_DIR}/config.yml" ]; then
        echo -e "${red}错误: ${XRAYR_DIR}/config.yml 不存在，请先配置！${plain}"
        return 1
    fi
    return 0
}

#=============================
# 状态检查
#=============================
get_service_status(){
    if rc-service xrayr status >/dev/null 2>&1; then
        echo -e "${green}运行中${plain}"
    else
        echo -e "${red}未运行${plain}"
    fi
}

get_autostart_status(){
    if rc-update show 2>/dev/null | grep -Eq "\bxrayr\b.*default"; then
        echo -e "${green}已开启${plain}"
    else
        echo -e "${red}未开启${plain}"
    fi
}

#=============================
# 服务控制
#=============================
start_XrayR(){
    check_config || return 1
    clear_stale_pid
    rc-service xrayr start
}

stop_XrayR(){
    rc-service xrayr stop
}

restart_XrayR(){
    check_config || return 1
    clear_stale_pid
    rc-service xrayr restart
}

status_XrayR(){
    rc-service xrayr status
}

enable_autostart(){
    rc-update add xrayr default >/dev/null 2>&1
    echo -e "${green}已开启开机自启${plain}"
}

disable_autostart(){
    rc-update del xrayr default >/dev/null 2>&1
    echo -e "${green}已关闭开机自启${plain}"
}

#=============================
# 日志查看
#=============================
log_XrayR(){
    init_logs
    echo "正在查看运行日志 (Ctrl+C 退出)..."
    tail -f "$LOG_FILE"
}

error_log_XrayR(){
    init_logs
    echo "正在查看错误日志 (Ctrl+C 退出)..."
    tail -f "$ERROR_LOG_FILE"
}

crash_log(){
    init_logs
    echo "===== 最近 100 行错误日志 ====="
    tail -n 100 "$ERROR_LOG_FILE"
}

#=============================
# 卸载
#=============================
uninstall_XrayR(){
    read -rp "确定要完全卸载 XrayR 吗？[y/N]: " confirm
    case "$confirm" in
        [yY][eE][sS]|[yY])
            stop_XrayR >/dev/null 2>&1
            disable_autostart >/dev/null 2>&1
            rm -rf "$XRAYR_DIR"
            rm -f "$SCRIPT_PATH_LOWER"
            rm -f "$SCRIPT_PATH_UPPER"
            rm -f /etc/init.d/xrayr
            rm -f /etc/logrotate.d/xrayr
            rm -f "$LOG_FILE" "$ERROR_LOG_FILE"
            echo -e "${green}卸载完成${plain}"
            exit 0
            ;;
        *)
            echo "已取消卸载"
            ;;
    esac
}

#=============================
# 主菜单
#=============================
while true; do
    service_status=$(get_service_status)
    autostart_status=$(get_autostart_status)

    echo "======================================"
    echo " XrayR 管理菜单 (Alpine OpenRC 强力守护版)"
    echo "======================================"
    echo -e "服务状态：${service_status}"
    echo -e "开机自启：${autostart_status}"
    echo "--------------------------------------"
    echo "1. 安装/更新二进制 XrayR"
    echo "2. 启动 XrayR"
    echo "3. 停止 XrayR"
    echo "4. 重改/重启 XrayR"
    echo "5. 查看详细状态"
    echo "6. 查看运行日志"
    echo "7. 查看错误日志"
    echo "8. 开启开机自启"
    echo "9. 关闭开机自启"
    echo "10. 更新菜单脚本 / 配置全局快捷命令 (xrayr/XrayR)"
    echo "11. 重建 OpenRC 服务"
    echo "12. 配置日志轮转"
    echo "13. 清理日志"
    echo "14. 查看最近 100 条错误"
    echo "15. 卸载 XrayR"
    echo "0. 退出"
    echo "--------------------------------------"

    read -rp "请选择 [0-15]: " choice

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
        10) install_self ;;
        11) rebuild_openrc_service ;;
        12) setup_logrotate ;;
        13) clean_logs ;;
        14) crash_log ;;
        15) uninstall_XrayR ;;
        0) exit 0 ;;
        *) echo -e "${red}请输入有效数字${plain}" ;;
    esac

    echo
    sleep 1
done
