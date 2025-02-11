#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: ${plain} vui lòng cấp quyền truy cập root！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "armbian"; then
    release="armbian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "armbian"; then
    release="armbian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Hệ điều hành hiện tại không hỗ trợ！${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Hệ điều hành CentOS 7 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Hệ điều hành Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Hệ điều hành Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Mặc định$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Có bắt đầu lại XrayR không?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn Enter để quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/XrayR-project/chau020620/XrayR/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Cập nhật phiên bản chỉ định(mặc định phiên bản mới nhất): " && read version
    else
        version=$2
    fi
#    confirm "本功能会强制重装当前最新版，数据不会丢失，是否继续?" "n"
#    if [[ $? != 0 ]]; then
#        echo -e "${red}已取消${plain}"
#        if [[ $1 != 0 ]]; then
#            before_show_menu
#        fi
#        return 0
#    fi
    bash <(curl -Ls https://raw.githubusercontent.com/chau020620/XrayR/main/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Cập nhật thành công, XrayR sẽ tự động bắt đầu, sử dụng XrayR log để xem nhật ký.${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "XrayR sẽ tự bắt đầu lại sau khi sửa đổi cấu hình"
    vi /etc/XrayR/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "Trạng thái XrayR: ${green}Đang chạy${plain}"
            ;;
        1)
            echo -e "XrayR không chạy, hoạc bắt đầu không thành công, bạn có muốn xem nhật ký không?[Y/n]" && echo
            read -e -p "(Mặc : y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Trạng thái XrayR: ${red}Chưa cài đặt${plain}"
    esac
}

uninstall() {
    confirm "Bạn có chắc muốn gỡ cài đặt XrayR không?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop XrayR
    systemctl disable XrayR
    rm /etc/systemd/system/XrayR.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/XrayR/ -rf
    rm /usr/local/XrayR/ -rf

    echo ""
    echo -e "Đã gỡ cài đặt XrayR, sử dụng ${green}rm /usr/bin/XrayR -f${plain} để dọn dẹp bảng điều khiển"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}XrayR đang chạy, không cần khởi động lại${plain}"
    else
        systemctl start XrayR
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR đã bắt đầu, sử dụng XrayR log để xem nhật ký hoạt động.${plain}"
        else
            echo -e "${red}XrayR không thể bắt đầu, sử dụng XrayR log để xem nhật ký lỗi${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop XrayR
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}XrayR đã dừng${plain}"
    else
        echo -e "${red}XrayR không thể dừng, có thể do thời gian thực hiện vượt quá 2s, vui lòng kiểm tra nhật ký.${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart XrayR
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR đã bắt đầu, dùng XrayR log để xem nhật ký lỗi.${plain}"
    else
        echo -e "${red}XrayR không thể bắt đầu, dùng XrayR log để xem nhật ký lỗi.${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status XrayR --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}Đã đặt tự bắt đầu XrayR${plain}"
    else
        echo -e "${red}Không thể đặt tự bắt đầu XrayR${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}Đã hủy tự bắt đầu XrayR${plain}"
    else
        echo -e "${red}Không thể hủy tự bắt đầu XrayR${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u XrayR.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh)
    #if [[ $? == 0 ]]; then
    #    echo ""
    #    echo -e "${green}安装 bbr 成功，请重启服务器${plain}"
    #else
    #    echo ""
    #    echo -e "${red}下载 bbr 安装脚本失败，请检查本机能否连接 Github${plain}"
    #fi

    #before_show_menu
}

update_shell() {
    wget -O /usr/bin/XrayR -N --no-check-certificate https://raw.githubusercontent.com/chau020620/XrayR//XrayR.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Tập lệnh tải không thành công, vui lòng kiểm tra kết nối đến Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/XrayR
        echo -e "${green}Tập lệnh tải xuống thành công, vui lòng chạy lại tập lệnh${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled XrayR)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}XrayR đã cài đặt, không cần cài đặt lại${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui lòng cài đặt XrayR${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Trạng Thái XrayR: ${green}Đang chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Trạng Thái XrayR: ${yellow}Không chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Trạng thái XrayR: ${red}Chưa cài đặt${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Tự bắt đầu: ${green}Mở${plain}"
    else
        echo -e "Tự bắt đầu: ${red}Tắt${plain}"
    fi
}

show_XrayR_version() {
    echo -n "XrayR Phiên bản："
    /usr/local/XrayR/XrayR version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
    echo "Lệnh điều khiển nhanh: "
    echo "------------------------------------------"
    echo "XrayR              - Mở bảng điều khiển XrayR"
    echo "XrayR start        - Bắt đầu XrayR"
    echo "XrayR stop         - Dừng XrayR"
    echo "XrayR restart      - Bắt đầu lại XrayR"
    echo "XrayR status       - Trạng thái XrayR"
    echo "XrayR enable       - Đặt XrayR tự bắt đầu"
    echo "XrayR disable      - Hủy XrayR tự bắt đầu"
    echo "XrayR log          - Nhật ký XrayR"
    echo "XrayR update       - Cập nhật XrayR"
    echo "XrayR update x.x.x - Cập nhật XrayR Phiên bản"
    echo "XrayR install      - Cài đặt XrayR"
    echo "XrayR uninstall    - Gỡ cài đặt XrayR"
    echo "XrayR version      - Phiên bản XrayR"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Bảng điều khiển XrayR ，${plain}${red}Không dùng cho docker${plain}
--- https://github.com/chau020620/XrayR ---
  ${green}0.${plain} Cấu hình
————————————————
  ${green}1.${plain} Cài đặt XrayR
  ${green}2.${plain} Cập nhật XrayR
  ${green}3.${plain} Gỡ cài đặt XrayR
————————————————
  ${green}4.${plain} Bắt đầu XrayR
  ${green}5.${plain} Dừng XrayR
  ${green}6.${plain} Bắt đầu lại XrayR
  ${green}7.${plain} Trạng thái XrayR
  ${green}8.${plain} Nhật ký XrayR
————————————————
  ${green}9.${plain} Đặt XrayR tự bắt đầu
 ${green}10.${plain} Hủy XrayR tự bắt đầu
————————————————
 ${green}11.${plain} Cập nhật Kernel mới
 ${green}12.${plain} Phiên bản XrayR 
 ${green}13.${plain} Cập nhật tập lệnh
 "
 #后续更新可加入上方字符串中
    show_status
    echo && read -p "Nhập [0-13]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_XrayR_version
        ;;
        13) update_shell
        ;;
        *) echo -e "${red}Nhập lại [0-12]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_XrayR_version 0
        ;;
        "update_shell") update_shell
        ;;
        *) show_usage
    esac
else
    show_menu
fi
