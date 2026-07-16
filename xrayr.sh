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
install_self(){

    cp "$0" "$SCRIPT_PATH"

    chmod +x "$SCRIPT_PATH"

    echo -e "${green}脚本已更新到 ${SCRIPT_PATH}${plain}"

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
    logrotate \
    >/dev/null 2>&1

}



#=============================
# 初始化日志
#=============================
init_logs(){


    mkdir -p /var/log


    touch "$LOG_FILE"
    touch "$ERROR_LOG_FILE"


    chown root:root \
    "$LOG_FILE" \
    "$ERROR_LOG_FILE"


    chmod 644 \
    "$LOG_FILE" \
    "$ERROR_LOG_FILE"


}



#=============================
# 日志轮转
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


    rm -f "$LOG_FILE"
    rm -f "$ERROR_LOG_FILE"


    init_logs


    echo -e "${green}日志已清理${plain}"

}




#=============================
# 安装 XrayR
#=============================
install_XrayR(){


    install_dependencies



    if [[ -x "${XRAYR_DIR}/XrayR" ]]; then


        echo -e "${yellow}检测到已有 XrayR，跳过安装${plain}"


        rebuild_openrc_service

        return


    fi




    rm -rf "$XRAYR_DIR"


    mkdir -p "$XRAYR_DIR"


    cd "$XRAYR_DIR" || exit




    LAST_VERSION=$(curl -fsSL \
    https://api.github.com/repos/wyusgw/XrayR/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/')




    if [[ -z "$LAST_VERSION" ]]; then


        echo -e "${red}获取 XrayR 版本失败${plain}"

        exit 1


    fi




    echo "下载 XrayR ${LAST_VERSION}"




    wget -c \
    --no-check-certificate \
    -O XrayR-linux.zip \
    "https://github.com/wyusgw/XrayR/releases/download/${LAST_VERSION}/XrayR-linux-64.zip"




    if [[ $? != 0 ]]; then

        echo -e "${red}下载失败${plain}"

        exit 1

    fi





    unzip -o XrayR-linux.zip


    rm -f XrayR-linux.zip



    chmod +x XrayR




    [[ ! -f config.yml ]] && touch config.yml

    [[ ! -f geoip.dat ]] && touch geoip.dat

    [[ ! -f geosite.dat ]] && touch geosite.dat



    init_logs



    install_self



    rebuild_openrc_service



    echo -e "${green}XrayR 安装完成${plain}"


}





#=============================
# 重建 OpenRC 服务文件
#=============================
rebuild_openrc_service(){


    init_logs



cat > /etc/init.d/xrayr <<EOF
#!/sbin/openrc-run


name="XrayR"

description="XrayR Service"



command="${XRAYR_DIR}/XrayR"


command_args="--config ${XRAYR_DIR}/config.yml"



command_background="yes"



pidfile="/run/xrayr.pid"



output_log="${LOG_FILE}"

error_log="${ERROR_LOG_FILE}"



# 自动恢复

respawn_delay=5

respawn_max=10

respawn_period=60



depend(){

    need net

}

EOF




chmod +x /etc/init.d/xrayr



rc-update add xrayr default \
>/dev/null 2>&1



echo -e "${green}OpenRC 服务文件重建完成${plain}"

}
#=============================
# 清理残留 PID
#=============================
clear_stale_pid(){

    PID_FILE="/run/xrayr.pid"


    if [[ -f "$PID_FILE" ]]; then


        pid=$(cat "$PID_FILE" 2>/dev/null)



        if [[ -n "$pid" ]]; then


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


    if [[ ! -f "${XRAYR_DIR}/config.yml" ]]; then


        echo -e "${red}config.yml 不存在${plain}"

        return 1


    fi



    return 0

}




#=============================
# 获取服务状态
#=============================
get_service_status(){


    if rc-service xrayr status >/dev/null 2>&1; then


        echo -e "${green}运行中${plain}"


    else


        echo -e "${red}未运行${plain}"


    fi


}




#=============================
# 获取自启状态
#=============================
get_autostart_status(){


    if rc-update show 2>/dev/null \
    | grep -Eq "\\bxrayr\\b.*default"; then


        echo -e "${green}已开启${plain}"


    else


        echo -e "${red}未开启${plain}"


    fi

}





#=============================
# 启动
#=============================
start_XrayR(){


    check_config || return


    clear_stale_pid



    rc-service xrayr start


}





#=============================
# 停止
#=============================
stop_XrayR(){


    rc-service xrayr stop



}




#=============================
# 重启
#=============================
restart_XrayR(){


    clear_stale_pid


    rc-service xrayr restart



}




#=============================
# 状态
#=============================
status_XrayR(){


    echo -e "XrayR 状态：$(get_service_status)"


}





#=============================
# 开机自启
#=============================
enable_autostart(){


    rc-update add xrayr default \
    >/dev/null 2>&1


    echo -e "${green}已开启开机自启${plain}"


}




disable_autostart(){


    rc-update del xrayr default \
    >/dev/null 2>&1


    echo -e "${green}已关闭开机自启${plain}"


}




#=============================
# 查看日志
#=============================
log_XrayR(){


    touch "$LOG_FILE"


    echo "查看运行日志 Ctrl+C退出"


    tail -f "$LOG_FILE"


}





error_log_XrayR(){


    touch "$ERROR_LOG_FILE"


    echo "查看错误日志 Ctrl+C退出"



    tail -f "$ERROR_LOG_FILE"


}





#=============================
# 最近错误
#=============================
crash_log(){


    echo "===== 最近错误 ====="


    tail -100 "$ERROR_LOG_FILE"


}





#=============================
# 卸载
#=============================
uninstall_XrayR(){


    stop_XrayR


    disable_autostart



    rm -rf "$XRAYR_DIR"


    rm -f "$SCRIPT_PATH"


    rm -f /etc/init.d/xrayr


    rm -f /etc/logrotate.d/xrayr



    rm -f "$LOG_FILE"

    rm -f "$ERROR_LOG_FILE"



    echo -e "${green}卸载完成${plain}"


}





#=============================
# 更新脚本
#=============================
update_self(){

    install_self

}





#=============================
# 主菜单
#=============================
while true; do


service_status=$(get_service_status)

autostart_status=$(get_autostart_status)



echo "======================================"

echo " XrayR 管理菜单"

echo " OpenRC 自动守护版"

echo "======================================"

echo -e "服务状态：${service_status}"

echo -e "开机自启：${autostart_status}"

echo "--------------------------------------"

echo "1. 安装 XrayR"

echo "2. 启动 XrayR"

echo "3. 停止 XrayR"

echo "4. 重启 XrayR"

echo "5. 查看状态"

echo "6. 查看运行日志"

echo "7. 查看错误日志"

echo "8. 开启开机自启"

echo "9. 关闭开机自启"

echo "10. 更新菜单脚本"

echo "11. 重建 OpenRC 服务"

echo "12. 配置日志轮转"

echo "13. 清理日志"

echo "14. 卸载 XrayR"

echo "15. 查看最近错误"

echo "0. 退出"

echo "--------------------------------------"



read -rp "请选择 [0-15]: " choice



case $choice in


1)
install_XrayR
;;


2)
start_XrayR
;;


3)
stop_XrayR
;;


4)
restart_XrayR
;;


5)
status_XrayR
;;


6)
log_XrayR
;;


7)
error_log_XrayR
;;


8)
enable_autostart
;;


9)
disable_autostart
;;


10)
update_self
;;


11)
rebuild_openrc_service
;;


12)
setup_logrotate
;;


13)
clean_logs
;;


14)
uninstall_XrayR
;;


15)
crash_log
;;


0)
exit 0
;;


*)
echo "请输入正确数字"
;;


esac



echo

sleep 1


done
