#!/bin/bash

#======================================================
#   System Required: CentOS 7+ / Debian 8+ / Ubuntu 16+
#   Description: Manage sprov-ui
#   version: v1.1.1
#======================================================

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.1.1"
conf_dir="/etc/sprov-ui/"
conf_path="${conf_dir}sprov-ui.conf"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} debe ejecutar este script con el usuario root\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}no detecta la versión del sistema, comuniquese con el autor del script!${plain}\n" && exit 1
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
        echo -e "${red}Por favor use CentOS 7 o superior!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Por favor use Ubuntu 16 o superior!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Por favor use Debian 8 o superior!${plain}\n" && exit 1
    fi
fi

# -1:no instalado, 0: ya se está ejecutando, 1: no se está ejecutando
sprov_ui_status=-1

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [por defecto]: " temp
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
    confirm "Desea reiniciar el panel" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Presione Intro para volver al menu principal: ${plain}" && read temp
    show_menu
}

install_base() {
    (command -v curl >/dev/null 2>&1 && command -v wget >/dev/null 2>&1)\
    || (command -v yum >/dev/null 2>&1 && yum install curl wget -y)\
    || (command -v apt >/dev/null 2>&1 && apt install curl wget -y)\
    || (command -v apt-get >/dev/null 2>&1 && apt-get install curl wget -y)
}

install_soft() {
    (command -v $1 >/dev/null 2>&1)\
    || (command -v yum >/dev/null 2>&1 && yum install $1 -y)\
    || (command -v apt >/dev/null 2>&1 && apt install $1 -y)\
    || (command -v apt-get >/dev/null 2>&1 && apt-get install $1 -y)
}

install() {
    install_base
    bash <(curl -L -s https://raw.githubusercontent.com/RomanHrbr/sprov-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Esta funcion forzara la recarga de la version actual, los datos no se perderan, ¿continuara?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}ha cancelado${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    install_base
    bash <(curl -L -s https://raw.githubusercontent.com/RomanHrbr/sprov-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            restart
        else
            restart 0
        fi
    fi
}

uninstall() {
    confirm "Esta seguro de que desea desinstalar el panel?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop sprov-ui
    systemctl disable sprov-ui
    rm /etc/systemd/system/sprov-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/sprov-ui/ -rf
    rm /usr/local/sprov-ui/ -rf

    echo ""
    echo -e "${gree}Desinstale satisfactoriamente${plain}, gracias por su uso, si tiene mas sugerencias o comentarios, puede analizarlo en los siguientes lugares: "
    echo ""
    echo -e "Telegram: ${green}https://t.me/dankelthaher${plain}"

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

modify_user() {
    echo && read -p "Por favor ingrese nombre de usuario: " user
    read -p "Por favor ingrese su contrasena: " pwd
    if [[ -z "${user}" || -z "${pwd}" ]]; then
        echo -e "${red}nombre de usuario y contrasena no pueden estar vacios${plain}"
        before_show_menu
        return 1
    fi
    sed -i "s/^username=.*/username=${user}/" ${conf_path}
    sed -i "s/^password=.*/password=${pwd}/" ${conf_path}
    confirm_restart
}

modify_port() {
    echo && read -p "Puerto nuevo del panel de entrada [recomendado 10000-65535]: " port
    if [[ -z "${port}" ]]; then
        echo -e "${red}no entró en el puerto${plain}"
        before_show_menu
        return 1
    fi
    sed -i "s/^port=.*/port=${port}/" ${conf_path}
    confirm_restart
}

modify_config() {
    install_soft vim
    echo -e "----------------------------------------------------"
    echo -e "                descripcion de uso vim: "
    echo -e "Primero ingrese ${green} por la letra ${red} i ${plain } [modo de edición] ${plain}"
    echo -e "${green} [modo de edicion] Bajo ${plain} , las teclas de flecha mueven el cursor, y el hábito de editar texto es el mismo."
    echo -e "Despues de editar, presione ${red} Esc ${plain} para salir de ${green} [modo de edicion] ${plain} "
    echo -e "Por ultimo, pulse ${red} : wq ${plain} para guardar el archivo y salga de vim ${yellow} (tenga en cuenta que hay dos puntos en ingles)${plain}"
    echo -e "----------------------------------------------------"
    echo -e -n "${green}se editara con vim, presione Enter para continuar, o escriba n para regresar: ${plain}"
    read temp
    if [[ x"${temp}" == x"n" || x"${temp}" == x"N" ]]; then
        show_menu
        return 0
    fi
    vim ${conf_path}
    confirm_restart
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}panel ya se esta ejecutando, no es necesario comenzar de nuevo, si necesita reiniciar, elija reiniciar${plain}"
    else
        systemctl start sprov-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}v2ray panel Iniciado con exito${plain}"
        else
            echo -e "${red}no se pudo iniciar, probablemente porque el tiempo de inicio es de más de dos segundos, verifique la información de registro mas tarde${plain}"
        fi
    fi
        
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green}panel se ha detenido, no hay necesidad de detener de nuevo${plain}"
    else
        systemctl stop sprov-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}v2ray Panel Detenido con exito${plain}"
        else
            echo -e "${red}panel no detenido, probablemente porque el tiempo de parada es de más de dos segundos, verifique la información de registro mas tarde${plain}"
        fi
    fi
        
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart sprov-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Reiniciado con exito${plain}"
    else
        echo -e "${red}panel no pudo reiniciarse, probablemente porque el tiempo de inicio es de más de dos segundos, verifique la información de registro mas tarde${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable sprov-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}Exito en comienzo de arranque${plain}"
    else
        echo -e "${red}v2ray Panel ha fallado el arranque automático del arranque${plain}"
    fi
    
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable sprov-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}v2ray Panel cancela el inicio del arranque${plain}"
    else
        echo -e "${red}v2ray Panel cancela el fallo de inicio automático de arranque${plain}"
    fi
    
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    systemctl status sprov-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://github.com/sprov065/blog/raw/master/bbr.sh)
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}BBR intalado con exito${plain}"
    else
        echo ""
        echo -e "${red}Error al descargar el script de instalación de bbr${plain}"
    fi

    before_show_menu
}

update_shell() {
    wget -O /usr/bin/sprov-ui -N --no-check-certificate https://github.com/Mydong/sprov-ui/raw/master/sprov-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}no pudo descargar el script${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/sprov-ui
        echo -e "${green}script de actualización es exitoso, vuelva a ejecutar el script${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/sprov-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status sprov-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled sprov-ui)
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
        echo -e "${red}El panel ha sido instalado, por favor, no vuelva a instalar${plain}"
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
        echo -e "${red}Instale el panel primero${plain}"
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
            echo -e "estado del panel: ${green}ha ejecutado${plain}"
            show_enable_status
            ;;
        1)
            echo -e "estado del panel: ${yellow}no se está ejecutando${plain}"
            show_enable_status
            ;;
        2)
            echo -e "estado del panel: ${red}no instala${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Está encendido: ${green}SI${plain}"
    else
        echo -e "Está encendido: ${red}NO${plain}"
    fi
}

show_usage() {
    echo "Uso del script v2ray Panel: "
    echo "------------------------------------------"
    echo "sprov-ui              - menú de gestión de pantalla (más funciones)"
    echo "sprov-ui start        - 启动 sprov-ui 面板"
    echo "sprov-ui stop         - 停止 sprov-ui 面板"
    echo "sprov-ui restart      - 重启 sprov-ui 面板"
    echo "sprov-ui status       - 查看 sprov-ui 状态"
    echo "sprov-ui enable       - 设置 sprov-ui 开机自启"
    echo "sprov-ui disable      - 取消 sprov-ui 开启自启"
    echo "sprov-ui log          - 查看 sprov-ui 日志"
    echo "sprov-ui update       - 更新 sprov-ui 面板"
    echo "sprov-ui install      - 安装 sprov-ui 面板"
    echo "sprov-ui uninstall    - 卸载 sprov-ui 面板"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}sprov-ui 面板管理脚本${plain} ${red}${version}${plain}

--- https://blog.sprov.xyz/sprov-ui ---

————————————————
  ${green}1.${plain} Instalar v2ray Panel
  ${green}2.${plain} Actualizar v2ray Panel
  ${green}3.${plain} Desinstalar v2ray Panel
————————————————
  ${green}4.${plain} Modificar la contrasena d acceso al panel
  ${green}5.${plain} Modificar el puertodel panel
  ${green}6.${plain} Modificar manualmente la configuracion
————————————————
  ${green}7.${plain} inicia v2ray Panel
  ${green}8.${plain} Detener v2ray Panel
  ${green}9.${plain} reiniciar v2ray Panel
 ${green}10.${plain} Ver registros del Panel
————————————————
 ${green}11.${plain} Habilitar v2ray Panel
 ${green}12.${plain} Deshabilitar v2ray Panel
————————————————
 ${green}13.${plain} Instalar BBR
 ${green}14.${plain} Actualizar este script
————————————————
 ${green}0.${plain} salir del script
 "
    show_status
    echo && read -p "Por favor eliga una opcion [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && modify_user
        ;;
        5) check_install && modify_port
        ;;
        6) check_install && modify_config
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && show_log
        ;;
        11) check_install && enable
        ;;
        12) check_install && disable
        ;;
        13) install_bbr
        ;;
        14) update_shell
        ;;
        *) echo -e "${red}Por favor ingrese el número correcto [0-14]${plain}"
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
        "status") check_install 0 && show_status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) echo -e "${yellow}Use solo las opciones numericas${plain}" 
    esac
else
    show_menu
fi
