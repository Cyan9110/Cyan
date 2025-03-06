#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif grep -Eqi "debian" /etc/issue; then
    release="debian"
elif grep -Eqi "ubuntu" /etc/issue; then
    release="ubuntu"
elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
    release="centos"
elif grep -Eqi "debian" /proc/version; then
    release="debian"
elif grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
elif grep -Eqi "centos|red hat|redhat" /proc/version; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm -rf /usr/local/XrayR/
    fi
    mkdir -p /usr/local/XrayR/
    cd /usr/local/XrayR/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/wyx2685/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -z "$last_version" ]]; then
            echo -e "${yellow}无法自动检测 XrayR 版本，请手动输入版本号:${plain}"
            read -rp "请输入版本号（如 v1.5.0）: " last_version
            [[ -z "$last_version" ]] && echo -e "${red}未输入版本号，安装失败${plain}" && exit 1
        fi
    else
        last_version=$1
        [[ $1 != v* ]] && last_version="v$1"
    fi

    echo -e "开始安装 XrayR ${last_version}"
    url="https://github.com/wyx2685/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip"
    wget -q -N --no-check-certificate -O XrayR-linux.zip ${url}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 XrayR ${last_version} 失败，请检查版本号是否正确或稍后重试${plain}"
        exit 1
    fi

    unzip XrayR-linux.zip
    rm -f XrayR-linux.zip
    chmod +x XrayR
    mkdir -p /etc/XrayR/
    systemctl daemon-reload
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} 安装完成，已设置开机自启"

    cd $cur_dir
    echo -e ""
    echo "XrayR 管理命令: "
    echo "------------------------------------------"
    echo "XrayR start              - 启动 XrayR"
    echo "XrayR stop               - 停止 XrayR"
    echo "XrayR restart            - 重启 XrayR"
    echo "XrayR status             - 查看 XrayR 状态"
    echo "XrayR enable             - 设置 XrayR 开机自启"
    echo "XrayR disable            - 取消 XrayR 开机自启"
    echo "XrayR log                - 查看 XrayR 日志"
    echo "XrayR update             - 更新 XrayR"
    echo "XrayR update x.x.x       - 更新 XrayR 指定版本"
    echo "XrayR uninstall          - 卸载 XrayR"
    echo "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_XrayR $1
