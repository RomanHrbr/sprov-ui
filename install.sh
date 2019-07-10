#!/bin/bash

#=================================================
#   System Required: CentOS 7+ / Debian 8+ / Ubuntu 16+
#=================================================

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

conf_dir="/etc/sprov-ui/"
conf_path="${conf_dir}sprov-ui.conf"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error${plain}: debe ejecutar este script con el usuario root. \n" && exit 1

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
    echo -e "${red}no detecta la versión del sistema, comuníquese con el autor del script!${plain}\n" && exit 1
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
        echo -e "${red}Por favor use CentOS 7 o superior! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Por favor use Ubuntu 16 o superior! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Por favor use Debian 8 o superior! ${plain}\n" && exit 1
    fi
fi

install_base() {
    command -v bc >/dev/null 2>&1 || yum install bc -y || apt install bc -y
    command -v curl >/dev/null 2>&1 || yum install curl -y || apt install curl -y
}

install_java() {
    if [[ -f /usr/bin/java ]]; then
        install_base
        java_version=`/usr/bin/java -version 2>&1 | awk -F '\"' 'NR==1{print $2}' | awk -F '.' '{OFS="."; print $1,$2;}'`
        require_version=1.8
        is_ok=`echo "$java_version>=$require_version" | bc`
        if [[ is_ok -eq 1 ]]; then
	    echo -e "${green}ha detectado la version 1.8 y superior de Java, no es necesario reinstalar${plain}"
	else
	    echo -e "Error：${red}/usr/bin/java${red}es menor que 1.8, instale java que es mayor o igual que la version 1.8${plain}"
        echo -e "Intentar actualizar el sistema puede resolver el problema:："
	    echo -e "CentOS: ${green}yum update${plain}"
        echo -e "Debian / Ubuntu: ${green}apt-get update && apt-get upgrade${plain}"
        exit -1
	fi
    elif [[ x"${release}" == x"centos" ]]; then
        yum install java-1.8.0-openjdk -y
    elif [[ x"${release}" == x"debian" || x"${release}" == x"ubuntu" ]]; then
        apt install default-jre -y
    fi
    if [[ $? -ne 0 ]]; then
        echo -e "${red}La instalacion del entorno Java fallo, compruebe el mensaje de error${plain}"
        echo -e "Intentar actualizar el sistema puede resolver el problema"
        echo -e "CentOS: ${green}yum update${plain}"
        echo -e "Debian / Ubuntu: ${green}apt-get update && apt-get upgrade${plain}"
        echo -e ""
        echo -e "Debian / Ubuntu tambin puede intentar instalar el entorno java con el siguiente comando, si la instalacion de java es correcta, vuelva a ejecutar el panel de instalacion:"
        echo -e "1. ${green}apt-get install openjdk-11-jre-headless -y${plain}"
        echo -e "2. ${green}apt-get install openjdk-8-jre-headless -y${plain}"
        exit 1
    fi
}

install_v2ray() {
    echo -e "${green}comienza a instalar o actualizar v2ray${plain}"
    bash <(curl -L -s https://install.direct/go.sh) -f
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Falló la instalación o actualización de v2ray，verifique el mensaje de error${plain}"
        exit 1
    fi
    systemctl enable v2ray
    systemctl start v2ray
}

close_firewall() {
    if [[ x"${release}" == x"centos" ]]; then
        systemctl stop firewalld
        systemctl disable firewalld
    elif [[ x"${release}" == x"ubuntu" ]]; then
        ufw disable
    elif [[ x"${release}" == x"debian" ]]; then
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -F
    fi
}

port=7000
user="dankelthaher"
pwd="dankelthaher"

init_config() {
    if [[ ! -e "${conf_dir}" ]]; then
        mkdir ${conf_dir}
    fi
    if [[ ! -f ${conf_path} ]]; then
        echo "port=${port}" >> ${conf_path}
        echo "username=${user}" >> ${conf_path}
        echo "password=${pwd}" >> ${conf_path}
        echo "keystoreFile=" >> ${conf_path}
        echo "keystorePass=" >> ${conf_path}
    else
        sed -i "s/^port=.*/port=${port}/" ${conf_path}
        sed -i "s/^username=.*/username=${user}/" ${conf_path}
        sed -i "s/^password=.*/password=${pwd}/" ${conf_path}
    fi

    echo ""
    echo -e "puerto del panel (no puerto v2ray)：${green}${port}${plain}"
    echo -e "nombre de usuario：${green}${user}${plain}"
    echo -e "contrasena：${green}${pwd}${plain}"
}

init_service() {
    echo "[Unit]" > /etc/systemd/system/sprov-ui.service
    echo "Description=sprov-ui Service" >> /etc/systemd/system/sprov-ui.service
    echo "After=network.target" >> /etc/systemd/system/sprov-ui.service
    echo "Wants=network.target" >> /etc/systemd/system/sprov-ui.service
    echo "" >> /etc/systemd/system/sprov-ui.service
    echo "[Service]" >> /etc/systemd/system/sprov-ui.service
    echo "Type=simple" >> /etc/systemd/system/sprov-ui.service
    java_cmd="/usr/bin/java"
    echo "ExecStart=${java_cmd} -jar /usr/local/sprov-ui/sprov-ui.jar" >> /etc/systemd/system/sprov-ui.service
    echo "" >> /etc/systemd/system/sprov-ui.service
    echo "[Install]" >> /etc/systemd/system/sprov-ui.service
    echo "WantedBy=multi-user.target" >> /etc/systemd/system/sprov-ui.service
    systemctl daemon-reload
}

set_systemd() {
    init_service
    reset="y"
    first="y"
    if [[ -f "${conf_path}" ]]; then
        read -p "Desea restablecer el puerto, el usuario y la contrasena del panel [por defecto n]：" reset
        first="n"
    fi
    if [[ x"$reset" == x"y" || x"$reset" == x"Y" ]]; then
        read -p "Ingrese el puerto del panel [predeterminado ${port}]：" port
        read -p "Ingrese el nombre de usuario [predeterminado ${user}]：" user
        read -p "Ingrese la contrasena [predeterminado${pwd}]：" pwd
        if [[ -z "${port}" ]]; then
            port=7000
        fi
        if [[ -z "${user}" ]]; then
            user="dankelthaher"
        fi
        if [[ -z "${pwd}" ]]; then
            pwd="dankelthaher"
        fi
        init_config
        if [[ x"${first}" == x"n" ]]; then
            echo ""
            echo -e "${green}Recuerde reiniciar el panel despues de configurar el nuevo puerto, el nombre de usuario y la contrasena${plain}"
        fi
    fi
}

install_sprov-ui() {
    if [[ ! -e "/usr/local/sprov-ui" ]]; then
        mkdir /usr/local/sprov-ui
    fi
    if [[ -f "/usr/local/sprov-ui/sprov-ui.war" ]]; then
        rm /usr/local/sprov-ui/sprov-ui.war -f
    fi
    last_version=$(curl --silent "https://api.github.com/repos/Mydong/sprov-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo -e "Detectó la ltima versión：${last_version}，comienza a descargar los archivos principales"
    wget -N --no-check-certificate -O /usr/local/sprov-ui/sprov-ui.jar https://github.com/RomanHrbr/sprov-ui/blob/master/sprov-ui-3.1.0.jar
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Error al descargar el archivo del núcleo. Asegurese de que su servidor pueda descargar archivos. Si la instalacion falla varias veces, consulte el tutorial de instalacion manual${plain}"
        exit 1
    fi
    set_systemd
    echo -e ""
    echo -e "${green}v2ray Panel se instalo correctamente${plain}\n"
    echo -e ""
    #echo -e "sprov-ui 管理脚本使用方法: "
    #echo -e "------------------------------------------"
    #echo -e "sprov-ui              - 显示管理菜单 (功能更多)"
    #echo -e "sprov-ui start        - 启动 sprov-ui 面板"
    #echo -e "sprov-ui stop         - 停止 sprov-ui 面板"
    #echo -e "sprov-ui restart      - 重启 sprov-ui 面板"
    #echo -e "sprov-ui status       - 查看 sprov-ui 状态"
    #echo -e "sprov-ui enable       - 设置 sprov-ui 开机自启"
    #echo -e "sprov-ui disable      - 取消 sprov-ui 开启自启"
    #echo -e "sprov-ui log          - 查看 sprov-ui 日志"
    #echo -e "sprov-ui update       - 更新 sprov-ui 面板"
    #echo -e "sprov-ui install      - 安装 sprov-ui 面板"
    #echo -e "sprov-ui uninstall    - 卸载 sprov-ui 面板"
    #echo -e "------------------------------------------"
    #echo -e ""
    #echo -e "若未下载管理脚本，使用以下命令下载管理脚本:"
    echo -e ""
}

echo "Iniciar instalacion"
install_java
install_v2ray
close_firewall
install_sprov-ui
