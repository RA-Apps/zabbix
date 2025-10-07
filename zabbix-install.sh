#!/bin/bash
# Роман Апанович
# 07.10.2025
# Автоматическая установка Zabbix Agent 2 на CentOS 7, CentOS 9 и Ubuntu 22.04 - 24.04

# Функция для вывода помощи
usage() {
    echo "Флаги: $0 [--server <Zabbix Server>] [--hostname <Hostname>] [--logfilesize <Size>] [--listenport <Port>] [--listenip <IP>] [--timeout <Seconds>]"
    exit 1
}

# Установка значений по умолчанию
ZBX_LOGFILESIZE="0"
ZBX_LISTENPORT="10050"
ZBX_LISTENIP="0.0.0.0"
ZBX_TIMEOUT="30"

# Парсинг аргументов командной строки
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --server) ZBX_SERVER="$2"; shift ;;
        --hostname) ZBX_HOSTNAME="$2"; shift ;;
        --logfilesize) ZBX_LOGFILESIZE="$2"; shift ;;
        --listenport) ZBX_LISTENPORT="$2"; shift ;;
        --listenip) ZBX_LISTENIP="$2"; shift ;;
        --timeout) ZBX_TIMEOUT="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Неизвестный параметр: $1"; usage ;;
    esac
    shift
done

# Определение операционной системы
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_NAME=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    OS_VERSION=$(echo "$VERSION_ID" | cut -d'.' -f1)
else
    echo "Не удалось определить операционную систему!"
    exit 1
fi

# Проверка поддерживаемых ОС
if [[ "$OS_NAME" != "centos" && "$OS_NAME" != "ubuntu" ]]; then
    echo "Неподдерживаемая ОС: $OS_NAME"
    exit 1
fi
if [[ "$OS_NAME" == "centos" && "$OS_VERSION" != "7" && "$OS_VERSION" != "9" ]]; then
    echo "Неподдерживаемая версия CentOS: $OS_VERSION. Поддерживаются CentOS 7 и 9."
    exit 1
fi
if [[ "$OS_NAME" == "ubuntu" && "$OS_VERSION" != "22" && "$OS_VERSION" != "24" ]]; then
    echo "Неподдерживаемая версия Ubuntu: $OS_VERSION. Поддерживаются Ubuntu 22.04 и 24.04."
    exit 1
fi

# Запрос hostname, если не указан через --hostname
if [[ -z "$ZBX_HOSTNAME" ]]; then
    read -rp "Введите Hostname для Zabbix Agent: " ZBX_HOSTNAME
    if [[ -z "$ZBX_HOSTNAME" ]]; then
        echo "Hostname не может быть пустым!"
        exit 1
    fi
fi

# Запрос server, если не указан через --server
if [[ -z "$ZBX_SERVER" ]]; then
    read -rp "Введите Server для Zabbix Agent: " ZBX_SERVER
    if [[ -z "$ZBX_SERVER" ]]; then
        echo "Server не может быть пустым!"
        exit 1
    fi
fi

# Проверка и установка wget
if ! command -v wget &> /dev/null; then
    echo "Устанавливаю wget..."
    if [[ "$OS_NAME" == "centos" ]]; then
        if [[ "$OS_VERSION" == "7" ]]; then
            yum install -y wget
        else
            dnf install -y wget
        fi
    elif [[ "$OS_NAME" == "ubuntu" ]]; then
        apt-get update
        apt-get install -y wget
    fi
else
    echo "wget уже установлен."
fi

# Установка репозитория Zabbix
echo "Устанавливаю репозиторий Zabbix..."
if [[ "$OS_NAME" == "centos" ]]; then
    if [[ "$OS_VERSION" == "7" ]]; then
        rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/7/x86_64/zabbix-release-latest-7.0.el7.noarch.rpm
        yum clean all -y
    else
        rpm -Uvh https://repo.zabbix.com/zabbix/7.0/centos/9/x86_64/zabbix-release-latest-7.0.el9.noarch.rpm
        dnf clean all -y
    fi
    if [[ -f /etc/yum.repos.d/epel.repo ]]; then
        echo "Отключаю Zabbix пакеты в EPEL..."
        sed -i '/^\[epel\]/a excludepkgs=zabbix*' /etc/yum.repos.d/epel.repo
    fi
elif [[ "$OS_NAME" == "ubuntu" ]]; then
    wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu${OS_VERSION}.04_all.deb
    dpkg -i zabbix-release_latest_7.0+ubuntu${OS_VERSION}.04_all.deb
    apt-get update
fi

# Установка Zabbix Agent 2
echo "Устанавливаю Zabbix Agent 2..."
if [[ "$OS_NAME" == "centos" ]]; then
    if [[ "$OS_VERSION" == "7" ]]; then
        yum install -y zabbix-agent2
    else
        dnf install -y zabbix-agent2
    fi
elif [[ "$OS_NAME" == "ubuntu" ]]; then
    apt-get install -y zabbix-agent2
fi

# Настройка конфигурации Zabbix Agent 2
echo "Настраиваю конфигурацию Zabbix Agent 2..."
CONFIG_FILE="/etc/zabbix/zabbix_agent2.conf"
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
set_param() {
    local key="$1"
    local value="$2"
    sed -i "/^[# ]*$key=/d" "$CONFIG_FILE"
    echo "$key=$value" >> "$CONFIG_FILE"
}
set_param "LogFileSize" "$ZBX_LOGFILESIZE"
set_param "Server" "$ZBX_SERVER"
set_param "Hostname" "$ZBX_HOSTNAME"
set_param "ListenPort" "$ZBX_LISTENPORT"
set_param "ListenIP" "$ZBX_LISTENIP"
set_param "Timeout" "$ZBX_TIMEOUT"
echo "Конфигурация Zabbix Agent 2 успешно обновлена."

# Установка мониторинга производительности дисков
echo "Устанавливаю мониторинг производительности дисков..."
mkdir -p /etc/zabbix/zabbix_agent2.d/
wget -O /etc/zabbix/zabbix_agent2.d/userparameter_diskstats.conf \
    https://raw.githubusercontent.com/madhushacw/zabbix-disk-performance/refs/heads/master/userparameter_diskstats.conf
mkdir -p /usr/local/bin/
wget -O /usr/local/bin/lld-disks.py \
    https://raw.githubusercontent.com/madhushacw/zabbix-disk-performance/refs/heads/master/lld-disks.py
chmod +x /usr/local/bin/lld-disks.py

# Запуск и добавление в автозагрузку
echo "Запускаю и добавляю Zabbix Agent 2 в автозагрузку..."
systemctl enable --now zabbix-agent2

# Настройка firewall
echo "Настраиваю firewall..."
if [[ "$OS_NAME" == "centos" ]]; then
    if command -v firewall-cmd &> /dev/null; then
        echo "Открываю порт Zabbix Agent в firewalld..."
        firewall-cmd --zone=public --add-service=zabbix-agent --permanent
        firewall-cmd --reload
    else
        echo "firewall-cmd не установлен, пропускаю настройку firewall."
    fi
elif [[ "$OS_NAME" == "ubuntu" ]]; then
    if command -v ufw &> /dev/null; then
        echo "Открываю порт Zabbix Agent в ufw..."
        ufw allow 10050/tcp
        ufw reload
    else
        echo "ufw не установлен, пропускаю настройку firewall."
    fi
fi
systemctl restart zabbix-agent2
echo "Установка Zabbix Agent 2 завершена!"
