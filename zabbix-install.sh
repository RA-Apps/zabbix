#!/bin/bash
# Роман Апанович
# 08.08.2025 → обновлено 24.07.2026
# Автоматическая установка Zabbix Agent 2 на CentOS 7, CentOS 9, AlmaLinux 10, Ubuntu 22.04–26.04, Debian 9–13

usage() {
    echo "Флаги: $0 [--server <Zabbix Server>] [--hostname <Hostname>] [--logfilesize <Size>] [--listenport <Port>] [--listenip <IP>] [--timeout <Seconds>] [--disk]"
    exit 1
}

# Значения по умолчанию
ZBX_LOGFILESIZE="0"
ZBX_LISTENPORT="10050"
ZBX_LISTENIP="0.0.0.0"
ZBX_TIMEOUT="30"
DISK_MONITORING=false

# Парсинг аргументов
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --server)   ZBX_SERVER="$2";   shift ;;
        --hostname) ZBX_HOSTNAME="$2"; shift ;;
        --logfilesize) ZBX_LOGFILESIZE="$2"; shift ;;
        --listenport)  ZBX_LISTENPORT="$2";  shift ;;
        --listenip)    ZBX_LISTENIP="$2";    shift ;;
        --timeout)     ZBX_TIMEOUT="$2";     shift ;;
        --disk)        DISK_MONITORING=true ;;
        -h|--help)     usage ;;
        *) echo "Неизвестный параметр: $1"; usage ;;
    esac
    shift
done

# Определение ОС
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_NAME=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    OS_VERSION=$(echo "$VERSION_ID" | cut -d'.' -f1)
else
    echo "Не удалось определить операционную систему!"
    exit 1
fi

# Проверка поддерживаемых ОС и версий
case "$OS_NAME" in
    centos)
        if [[ "$OS_VERSION" != "7" && "$OS_VERSION" != "9" ]]; then
            echo "Неподдерживаемая версия CentOS: $OS_VERSION. Поддерживаются 7 и 9."
            exit 1
        fi
        ;;
    almalinux)
        if [[ "$OS_VERSION" != "10" ]]; then
            echo "Неподдерживаемая версия AlmaLinux: $OS_VERSION. Поддерживается 10."
            exit 1
        fi
        ;;
    ubuntu)
        if [[ "$OS_VERSION" != "22" && "$OS_VERSION" != "24" && "$OS_VERSION" != "26" ]]; then
            echo "Неподдерживаемая версия Ubuntu: $OS_VERSION. Поддерживаются 22.04, 24.04 и 26.04."
            exit 1
        fi
        ;;
    debian)
        if [[ "$OS_VERSION" -lt 9 || "$OS_VERSION" -gt 13 ]]; then
            echo "Неподдерживаемая версия Debian: $OS_VERSION. Поддерживаются 9–13."
            exit 1
        fi
        ;;
    *)
        echo "Неподдерживаемая ОС: $OS_NAME"
        exit 1
        ;;
esac

# Запрос обязательных параметров, если не переданы
[[ -z "$ZBX_HOSTNAME" ]] && {
    read -rp "Введите Hostname для Zabbix Agent: " ZBX_HOSTNAME
    [[ -z "$ZBX_HOSTNAME" ]] && { echo "Hostname не может быть пустым!"; exit 1; }
}

[[ -z "$ZBX_SERVER" ]] && {
    read -rp "Введите Server для Zabbix Agent (IP или DNS): " ZBX_SERVER
    [[ -z "$ZBX_SERVER" ]] && { echo "Server не может быть пустым!"; exit 1; }
}

# Установка wget, если отсутствует
if ! command -v wget >/dev/null; then
    echo "Устанавливаю wget..."
    if [[ "$OS_NAME" == "centos" ]]; then
        [[ "$OS_VERSION" == "7" ]] && yum install -y wget || dnf install -y wget
    elif [[ "$OS_NAME" == "almalinux" ]]; then
        dnf install -y wget
    else  # ubuntu / debian
        apt-get update && apt-get install -y wget
    fi
fi

# Установка репозитория Zabbix
echo "Устанавливаю репозиторий Zabbix..."

if [[ "$OS_NAME" == "centos" ]]; then
    if [[ "$OS_VERSION" == "7" ]]; then
        rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/7/x86_64/zabbix-release-latest-7.0.el7.noarch.rpm
        yum clean all
    else
        rpm -Uvh https://repo.zabbix.com/zabbix/7.0/centos/9/x86_64/zabbix-release-latest-7.0.el9.noarch.rpm
        dnf clean all
    fi
    # Отключаем zabbix-пакеты в EPEL, если репозиторий есть
    [[ -f /etc/yum.repos.d/epel.repo ]] && sed -i '/^\[epel\]/a excludepkgs=zabbix*' /etc/yum.repos.d/epel.repo

elif [[ "$OS_NAME" == "almalinux" ]]; then
    rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/10/x86_64/zabbix-release-latest-7.0.el10.noarch.rpm
    dnf clean all
    # Отключаем zabbix-пакеты в EPEL, если репозиторий есть
    [[ -f /etc/yum.repos.d/epel.repo ]] && sed -i '/^\[epel\]/a excludepkgs=zabbix*' /etc/yum.repos.d/epel.repo

elif [[ "$OS_NAME" == "ubuntu" ]]; then
    # Скачиваем официальный пакет для конкретной версии Ubuntu
    wget "https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu${OS_VERSION}.04_all.deb"
    dpkg -i "zabbix-release_latest_7.0+ubuntu${OS_VERSION}.04_all.deb"
    apt-get update

elif [[ "$OS_NAME" == "debian" ]]; then
    if [[ "$OS_VERSION" == "9" ]]; then
        # Для старого stretch используем 6.0 (7.0 официально не поддерживается)
        wget https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_6.0+debian9_all.deb
        dpkg -i zabbix-release_latest_6.0+debian9_all.deb
    else
        # Debian 10–13 → используем 7.0
        wget "https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian${OS_VERSION}_all.deb"
        dpkg -i "zabbix-release_latest_7.0+debian${OS_VERSION}_all.deb"
    fi
    apt-get update
fi

# Установка самого агента
echo "Устанавливаю Zabbix Agent 2..."
if [[ "$OS_NAME" == "centos" ]]; then
    [[ "$OS_VERSION" == "7" ]] && yum install -y zabbix-agent2 || dnf install -y zabbix-agent2
elif [[ "$OS_NAME" == "almalinux" ]]; then
    dnf install -y zabbix-agent2
else
    apt-get install -y zabbix-agent2
fi

# Настройка конфига
echo "Настраиваю конфигурацию Zabbix Agent 2..."
CONFIG_FILE="/etc/zabbix/zabbix_agent2.conf"
[[ -f "$CONFIG_FILE" ]] || { echo "Конфиг $CONFIG_FILE не найден!"; exit 1; }

cp -f "$CONFIG_FILE" "${CONFIG_FILE}.bak_$(date +%F_%H%M)"

set_param() {
    local key="$1" value="$2"
    sed -i "/^[# ]*$key=/d" "$CONFIG_FILE"
    echo "$key=$value" >> "$CONFIG_FILE"
}

set_param "LogFileSize"  "$ZBX_LOGFILESIZE"
set_param "Server"       "$ZBX_SERVER"
set_param "Hostname"     "$ZBX_HOSTNAME"
set_param "ListenPort"   "$ZBX_LISTENPORT"
set_param "ListenIP"     "$ZBX_LISTENIP"
set_param "Timeout"      "$ZBX_TIMEOUT"

echo "Конфигурация обновлена."

# Дополнительный мониторинг дисков (если запрошен)
if [[ "$DISK_MONITORING" == true ]]; then
    echo "Устанавливаю пользовательские параметры для мониторинга дисков..."
    if [[ "$OS_NAME" == "debian" && "$OS_VERSION" == "9" ]]; then
        apt-get install -y python3
    fi
    mkdir -p /etc/zabbix/zabbix_agent2.d /usr/local/bin
    wget -qO /etc/zabbix/zabbix_agent2.d/userparameter_diskstats.conf \
        https://raw.githubusercontent.com/madhushacw/zabbix-disk-performance/master/userparameter_diskstats.conf
    wget -qO /usr/local/bin/lld-disks.py \
        https://raw.githubusercontent.com/madhushacw/zabbix-disk-performance/master/lld-disks.py
    chmod +x /usr/local/bin/lld-disks.py
fi

# Запуск и автозагрузка
echo "Запускаю и включаю автозагрузку zabbix-agent2..."
systemctl enable --now zabbix-agent2

# Настройка файрвола (если есть)
echo "Настраиваю firewall (если присутствует)..."
if [[ "$OS_NAME" == "centos" || "$OS_NAME" == "almalinux" ]]; then
    if command -v firewall-cmd >/dev/null; then
        firewall-cmd --permanent --add-service=zabbix-agent
        firewall-cmd --reload
    fi
else  # ubuntu/debian
    if command -v ufw >/dev/null; then
        ufw allow 10050/tcp
        ufw reload
    fi
fi

systemctl restart zabbix-agent2

echo "Установка и настройка Zabbix Agent 2 завершена!"
echo "Проверьте статус:   systemctl status zabbix-agent2"
echo "Лог:               tail -f /var/log/zabbix/zabbix_agent2.log"
