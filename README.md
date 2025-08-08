# Zabbix Agent 2 Installation Script

This script automates the installation and configuration of Zabbix Agent 2 on CentOS 9 and Ubuntu 22.04–24.04 systems.

## Features
- Automatically detects the operating system (CentOS 9 or Ubuntu 22.04–24.04).
- Installs `wget` if not already present.
- Sets up the Zabbix repository and installs Zabbix Agent 2.
- Configures Zabbix Agent 2 with user-specified or prompted server and hostname, and customizable parameters for log file size, listen port, listen IP, and timeout.
- Enables disk performance monitoring using additional configuration and scripts.
- Configures firewall rules to allow Zabbix Agent communication.
- Enables and starts the Zabbix Agent 2 service.

## Prerequisites
- Supported operating systems: CentOS 9, Ubuntu 22.04, or Ubuntu 24.04.
- Root or sudo privileges.
- Internet access to download packages and configuration files.

## Usage
1. **Download the Script**:
   Using `wget`:
   ```bash
   wget https://raw.githubusercontent.com/RA-Apps/zabbix/main/zabbix-install.sh
   ```
   Alternatively, using `curl`:
   ```bash
   curl -O https://raw.githubusercontent.com/RA-Apps/zabbix/main/zabbix-install.sh
   ```
2. **Make the Script Executable**:
   ```bash
   chmod +x zabbix-install.sh
   ```
3. **Run the Script**:
   Run the script with optional command-line arguments to specify the Zabbix server, hostname, and other configuration parameters:
   ```bash
   ./zabbix-install.sh [--server <Zabbix Server>] [--hostname <Hostname>] [--logfilesize <Size>] [--listenport <Port>] [--listenip <IP>] [--timeout <Seconds>]
   ```

### Options
- `--server <Zabbix Server>`: Specify the Zabbix server IP or hostname (required, prompts if not provided).
- `--hostname <Hostname>`: Specify the hostname for the Zabbix Agent (required, prompts if not provided).
- `--logfilesize <Size>`: Specify the maximum log file size in MB (default: `0`, unlimited).
- `--listenport <Port>`: Specify the port for the Zabbix Agent to listen on (default: `10050`).
- `--listenip <IP>`: Specify the IP address for the Zabbix Agent to listen on (default: `0.0.0.0`).
- `--timeout <Seconds>`: Specify the timeout for agent operations in seconds (default: `30`).
- `-h` or `--help`: Display usage information.

If `--server` or `--hostname` are not provided, the script will prompt for these values during execution.

### Example
```bash
./zabbix-install.sh --server 192.168.1.100 --hostname my-server --logfilesize 10 --listenport 10051 --listenip 127.0.0.1 --timeout 15
```

### Default Values
The script uses the following default configuration values if not overridden via command-line arguments:
- `LogFileSize`: `0` (unlimited log file size)
- `ListenPort`: `10050`
- `ListenIP`: `0.0.0.0` (listen on all interfaces)
- `Timeout`: `30` seconds

## Installation Steps
1. **OS Detection**: Identifies the operating system and version.
2. **Wget Installation**: Installs `wget` if not already present.
3. **Zabbix Repository Setup**: Adds the Zabbix 7.0 repository for the detected OS.
4. **Zabbix Agent 2 Installation**: Installs the Zabbix Agent 2 package.
5. **Configuration**: Updates the Zabbix Agent configuration file with provided or prompted values, and sets parameters:
   - `LogFileSize=<specified or default value>`
   - `Server=<specified or prompted value>`
   - `Hostname=<specified or prompted value>`
   - `ListenPort=<specified or default value>`
   - `ListenIP=<specified or default value>`
   - `Timeout=<specified or default value>`
6. **Disk Performance Monitoring**: Downloads and configures disk monitoring scripts and parameters.
7. **Service Management**: Enables and starts the Zabbix Agent 2 service.
8. **Firewall Configuration**: Opens the specified or default port (`10050`) in `firewalld` (CentOS) or `ufw` (Ubuntu), if available.

## Files and Directories
- **Configuration File**: `/etc/zabbix/zabbix_agent2.conf` (backed up as `zabbix_agent2.conf.bak`).
- **Disk Monitoring**:
  - `/etc/zabbix/zabbix_agent2.d/userparameter_diskstats.conf`: Disk performance monitoring configuration.
  - `/usr/local/bin/lld-disks.py`: Script for low-level discovery of disks.
- **Firewall**:
  - CentOS: Adds `zabbix-agent` service to `firewalld`.
  - Ubuntu: Allows the specified or default port (`10050/tcp`) in `ufw`.

## Notes
- Ensure the Zabbix server IP/hostname and agent hostname are valid to avoid connectivity issues.
- The script assumes the Zabbix 7.0 repository is accessible.
- Disk monitoring scripts are sourced from [madhushacw/zabbix-disk-performance](https://github.com/madhushacw/zabbix-disk-performance).
- If `firewalld` or `ufw` is not installed, firewall configuration is skipped.
- Custom port or IP settings may require additional firewall adjustments outside the script.

## Author
- Roman Apanovich
- Date: 08.08.2025

## License
This script is provided under the MIT License. See [LICENSE](LICENSE) for details.
