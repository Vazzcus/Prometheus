#!/bin/bash
##              Prometheus installation script 											                           
##              Date: 14/07/2022                                                                                                                                                                                   ##
##              Author: Nicolás Vázquez Figueiras

# Initial check if the user is root and the OS is Ubuntu
function initialCheck() {
	if ! isRoot; then
		echo "The script must be executed as a root"
		exit 1
	fi
}

# Check if the user is root
function isRoot() {
    if [ "$EUID" -ne 0 ]; then
		return 1
	fi
	checkOS
}

# Check the operating system
function checkOS() {
    source /etc/os-release
	if [[ $ID == "ubuntu" ]]; then
	    OS="ubuntu"
	    MAJOR_UBUNTU_VERSION=$(echo "$VERSION_ID" | cut -d '.' -f1)
	    if [[ $MAJOR_UBUNTU_VERSION -lt 20 ]]; then
            echo "⚠️ This script it's not tested in your Ubuntu version. You want to continue?"
			echo ""
			CONTINUE='false'
			until [[ $CONTINUE =~ (y|n) ]]; do
			    read -rp "Continue? [y/n]: " -e CONTINUE
			done
			if [[ $CONTINUE == "n" ]]; then
				exit 1
			fi
		fi
		questionsMenu
	else
        echo "Your OS it's not Ubuntu, in the case you are using Centos you can continue from here. Press [Y]"
		CONTINUE='false'
		until [[ $CONTINUE =~ (y|n) ]]; do
			read -rp "Continue? [y/n]: " -e CONTINUE
		done
		if [[ $CONTINUE == "n" ]]; then
			exit 1
		fi
		OS="centos"
		questionsMenu
	fi
}

function questionsMenu() {
    echo -e "What you want to do ?"
	echo "1. Install Prometheus."
	echo "2. Uninstall Prometheus."
    echo "0. exit."
    read -e CONTINUE
    if [[ $CONTINUE == 1 ]]; then
        installPrometheus
    elif [[ $CONTINUE == 2 ]]; then
        uninstallPrometheus
    elif [[ $CONTINUE == 0 ]]; then
        exit 1
    else
		echo "invalid option !"
        clear
		questionsMenu
    fi
}

function installPrometheus() {
    if [[ $OS == "ubuntu" ]]; then
        if dpkg -l | grep prometheus > /dev/null; then
            echo "Prometheus it's already installed."
            echo "Installation cancelled."
        else
            apt update -y
            # Create user for Prometheus.
            groupadd --system prometheus
            useradd -s /bin/false -r -g prometheus prometheus
            # Create required directories.
            mkdir /etc/prometheus
            mkdir /var/lib/prometheus
            # Download prometheus.
            mkdir /downloads/prometheus -p
            cd /downloads/prometheus
            wget https://github.com/prometheus/prometheus/releases/download/v2.36.2/prometheus-2.36.2.linux-amd64.tar.gz
            # Extract and install prometheus.
            tar -zxvf prometheus-2.36.2.linux-amd64.tar.gz
            cd prometheus-2.36.2.linux-amd64/
            install prometheus /usr/local/bin/
	    install promtool /usr/local/bin/
            mv consoles /etc/prometheus/
            mv console_libraries /etc/prometheus/
            # Create configuration file.
            cat << EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
EOF
            # Establish the permissions
            chown prometheus:prometheus /usr/local/bin/prometheus
            chown prometheus:prometheus /usr/local/bin/promtool
            chown prometheus:prometheus /var/lib/prometheus -R
            chown prometheus:prometheus /etc/prometheus -R
            chmod -R 775 /etc/prometheus/ /var/lib/prometheus/
            # Create a systemd service file for Prometheus to start at boot time.
            cat << EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Restart=always
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
            # Enable the Prometheus service to run at system startup.
            systemctl enable prometheus
            # Start the Prometheus service.
            systemctl start prometheus

            echo ""
            echo ""
            echo "Prometheus installation succeded."
            echo ""
            echo ""
        fi
    fi
}

function uninstallPrometheus() {
    service prometheus stop
    rm -f /etc/prometheus
    rm -f /var/lib/prometheus/
    rm /etc/systemd/system/prometheus.service
    echo ""
    echo ""
    echo ""
    echo "Prometheus uninstalled."
    echo ""
    echo ""
    echo ""
}

initialCheck
