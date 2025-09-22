# Update OS packages without remove redundant packages
Update_Packages() {
	# apt-get: traditional, stable, backward-compatible -> preferred in automation scripts, CI/CD, production setup
	# apt: newer, human-friendly (colors, progress bar, concise syntax) -> best for manual interactive use, but interface may change
	sudo apt-get update -y && sudo apt-get upgrade -y
}

# Update OS packages with remove redundant packages and clean cache
# Usage: $0 [mode]
# mode: safe (default) | full
# - safe: only upgrade existing packages, no removals
# - full: may install new packages or remove existing ones if necessary
Update_Packages_WithAutoRemoveAndClean() {
	# Default to 'safe' if no argument is passed
	updateMode=${1:-safe}

	sudo apt-get update -y

	if [ "$updateMode" = "full" ]; then
		echo "[INFO] Running full upgrade (may install/remove packages)..."
		sudo apt-get dist-upgrade -y
	else
		echo "[INFO] Running safe upgrade (no removals)..."
		sudo apt-get upgrade -y
	fi

	echo "[INFO] Cleaning up unused packages and cache..."
	sudo apt-get autoremove -y
	sudo apt-get autoclean -y

	echo "[INFO] Update complete!"
}

# Upgrade OS version (e.g., from 22.04 to 24.04)
Upgrade_OS() {
	# Update packages first
	Update_Packages
	Update_Packages_WithAutoRemoveAndClean full

	# Start upgrade OS version
	sudo do-release-upgrade -f DistUpgradeViewNonInteractive

	# Cleanup after upgrade
	sudo apt-get autoremove -y
	sudo apt-get autoclean -y

	# Reboot if required
	if [ -f /var/run/reboot-required ]; then
		echo "[INFO] Reboot required. Rebooting now..."
		sudo reboot
	else
		echo "[INFO] Upgrade finished. No reboot required."
	fi
}

Install_Git() {
	# Update packages
	sudo apt update
	sudo apt install -y software-properties-common

	# Add the official Git PPA
	sudo add-apt-repository ppa:git-core/ppa -y

	# Update again
	sudo apt update

	# Install latest Git
	sudo apt install -y git

	# Verify version
	git --version
}

# Ref: https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-ubuntu?view=sql-server-ver16&tabs=ubuntu2204
Install_SqlServer2022() {
	# curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
	curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
	curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list

	# Run the following commands to install SQL Server
	sudo apt-get update
	sudo apt-get install -y mssql-server

	# Set the SA password and choose your edition
	# For eg,. at staging: sa/Staging1234!
	sudo /opt/mssql/bin/mssql-conf setup

	# Verify that the service is running
	systemctl status mssql-server --no-pager

	# Install SQL Server (sqlcmd, bcp,...)
	printf "Install SQL Server tools? (y/*): "
	read ans
	if [[ $ans == "y" ]]; then
		sudo apt-get update
		sudo apt install curl
		curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
		curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

		sudo apt-get update
		sudo apt-get install mssql-tools18 unixodbc-dev
		echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bash_profile
		echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
		source ~/.bashrc

		echo "Installed SQL Server tools (sqlcmd, bcp) !"
		echo "For update tools, just hit: sudo apt-get update && sudo apt-get install mssql-tools"
	else
		echo "Skip install tools !"
	fi

	echo "=> Installed sql server."
	echo "To connect remotely, at ec2 instance, let allow firewall at port 1433 (for production, should also restrict incoming ip) as below:"
	echo "  - Click to target ec2 server to open detail page"
	echo "  - Select tab Security -> Click Security groups -> Click Edit inbound rules"
	echo "  - Add TCP 1433 with source 0.0.0.0/0"
}

# At this time, MSSQL 2019 does not support for ubuntu 22.04. So we use ubuntu 20.04 instead.
# Ref: https://docs.microsoft.com/en-us/sql/linux/quickstart-install-connect-ubuntu?view=sql-server-linux-ver15
Install_SqlServer2019() {
	printf "[Ask] Ubuntu 20.04 is required since it does not yet support for Ubuntu 22.04. Press y to continue? (y/*): "
	read ans
	if [[ $ans != "y" ]]; then
		echo "Aborted."
		return
	fi

	echo "[Info] Installing sql server..."

	# Import the public repository GPG keys
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

	# Register the SQL Server Ubuntu repository
	sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2019.list)"

	# Run the following commands to install SQL Server
	sudo apt-get update
	sudo apt-get install -y mssql-server

	# Set the SA password and choose your edition
	# For eg,. at staging: sa/Staging1234!
	sudo /opt/mssql/bin/mssql-conf setup

	# Verify that the service is running
	systemctl status mssql-server --no-pager

	# Install SQL Server (sqlcmd, bcp,...)
	printf "Install SQL Server tools? (y/*): "
	read ans
	if [[ $ans == "y" ]]; then
		sudo apt-get update
		sudo apt install curl
		curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
		curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list

		sudo apt-get update
		sudo apt-get install mssql-tools unixodbc-dev
		echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
		source ~/.bashrc

		echo "Installed SQL Server tools (sqlcmd, bcp) !"
		echo "For update tools, just hit: sudo apt-get update && sudo apt-get install mssql-tools"
	else
		echo "Skip install tools !"
	fi

	echo "=> Installed sql server."
	echo "To connect remotely, at ec2 instance, let allow firewall at port 1433 (for production, should also restrict incoming ip) as below:"
	echo "  - Click to target ec2 server to open detail page"
	echo "  - Select tab Security -> Click Security groups -> Click Edit inbound rules"
	echo "  - Add TCP 1433 with source 0.0.0.0/0"
}

# Ref: https://www.digitalocean.com/community/tutorials/how-to-install-mysql-on-ubuntu-22-04
Install_MySQL() {
	# Update the package index on server
	sudo apt update

	# Install the mysql-server package
	sudo apt install mysql-server

	# Start service
	sudo systemctl start mysql.service

	# Run secure script with root previledge
	echo "OK, please continue to secure installation"
	sudo mysql_secure_installation

	echo "Done !"
}

Install_PostgreSQL() {
	# Update OS and install postgresql
	sudo apt update && sudo apt upgrade -y
	sudo apt install postgresql postgresql-contrib -y

	# Start service and register start at boot time
	sudo systemctl start postgresql
	sudo systemctl enable postgresql

	sudo systemctl status postgresql
	echo "Done !"
}

Uninstall_Nginx() {
	# Stop/disable nginx
	sudo systemctl stop nginx
	sudo systemctl disable nginx

	# Remove nginx packages
	sudo apt purge -y nginx nginx-common nginx-full

	# Remove leftover files
	sudo rm -rf /etc/nginx
	sudo rm -rf /var/log/nginx
	sudo rm -rf /var/cache/nginx

	# Remove unused dependencies
	sudo apt autoremove -y
}

# Install latest official mainline package (user will be nginx)
Install_Nginx() {
	# Add the official Nginx signing key
	curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg

	# Add the official Nginx repository (main branch)
	echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" | \
	sudo tee /etc/apt/sources.list.d/nginx.list

	sudo apt update
	sudo apt install nginx

	sudo systemctl enable nginx
	sudo systemctl start nginx
	sudo service nginx status
	nginx -v

	echo "=> Installed nginx."
	echo "Please allow firewall at port 80, 443 (for production, should also restrict incoming ip), for eg,. at ec2:"
	echo "  - Click to target ec2 server to open detail page"
	echo "  - Select tab Security -> Click Security groups -> Click Edit inbound rules"
	echo "  - Add TCP 80, 443 with source 0.0.0.0/0"
}

# Install nginx at Ubuntu repo (user will be www-data)
Install_Nginx_AtUbuntuRepo() {
	echo "[Info] Installing nginx..."

	# After, ssh to server,
	# let Update OS, Install nginx and Enable nginx at startup
	sudo apt-get update
	sudo apt-get install nginx
	sudo systemctl enable nginx

	# Below are nginx control commands
	sudo service nginx start
	sudo service nginx status

	echo "=> Installed nginx."
	echo "Please allow firewall at port 80, 443 (for production, should also restrict incoming ip), for eg,. at ec2:"
	echo "  - Click to target ec2 server to open detail page"
	echo "  - Select tab Security -> Click Security groups -> Click Edit inbound rules"
	echo "  - Add TCP 80, 443 with source 0.0.0.0/0"
}

# Ref: https://docs.microsoft.com/en-us/dotnet/core/install/linux-ubuntu
Remove_Dotnet() {
	sudo apt remove dotnet*
	sudo apt remove aspnetcore*
	sudo apt remove netstandard*

	sudo apt-get remove dotnet*
	sudo apt-get remove aspnetcore*


	sudo rm /etc/apt/sources.list.d/microsoft-prod.list
	sudo rm /etc/apt/sources.list.d/microsoft-prod.list.save

	sudo apt autoremove
	sudo apt update
}

Install_Dotnet9_ForUbuntu2204() {
	sudo add-apt-repository ppa:dotnet/backports
	sudo apt-get update && sudo apt-get install -y dotnet-sdk-9.0
}

# Ref: https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu-2204
Install_Dotnet8_ForUbuntu2204Above() {
	sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0
}

# Ref: https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu#2204-microsoft-package-feed
Install_Dotnet7_ForUbuntu2204Above() {
	# Just install from Ubuntu repo to avoid multiple installation sources
	sudo apt-get update && sudo apt-get install -y dotnet-sdk-7.0
}

# Ref: https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu#2204-microsoft-package-feed
Install_Dotnet7_ForUbuntu1804Above() {
	# Cleanup previous version
	# Dotnet 7 is NOT included in Ubuntu feed, we have to use Microsoft feed !
	sudo wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
	sudo dpkg -i packages-microsoft-prod.deb
	sudo rm packages-microsoft-prod.deb

	# Install full sdk (includes runtime)
	sudo apt-get update && sudo apt-get install -y dotnet-sdk-7.0
}

Install_Dotnet6_ForUbuntu2204() {
	echo "[Info] Installing dotnet..."

	sudo apt-get update && sudo apt-get install -y dotnet6

	echo "=> Installed dotnet."
}

Install_Dotnet6_ForUbuntu2004() {
	echo "[Info] Installing dotnet..."

	sudo wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
	sudo dpkg -i packages-microsoft-prod.deb
	sudo rm packages-microsoft-prod.deb

	sudo apt-get update && sudo apt-get install -y dotnet-sdk-6.0

	echo "=> Installed dotnet."
}

Install_RedisServer() {
	sudo apt update
	sudo apt install redis-server
}

Uninstall_RedisServer() {
	sudo apt-get purge --auto-remove redis-server
}

# Install certbot (nginx version)
Install_Certbot() {
	echo "[Info] Installing certbot..."

	sudo mkdir -p /srv/certbot
	sudo chown -R www-data:www-data /srv/certbot

	# Install certbot
	# For uninstall: sudo apt remove certbot
	sudo snap install core
	sudo snap refresh core
	sudo snap install --classic certbot
	sudo ln -s /snap/bin/certbot /usr/bin/certbot

	# Create hook (auto-reload nginx) when certbot renew certs
	sudo certbot renew --deploy-hook "sudo systemctl reload nginx"

	# Check grammar
	sudo nginx -t

	# If we use long domain name that needs edit nginx config,
	# just comment out and change 64 -> 128: server_names_hash_bucket_size 128;
	echo "[Ask] If we use long domain name, you maybe need increase server_names_hash_bucket_size of nginx config."
	printf "Do you want to increase current value (64)? (y/*): "
	read ans
	if [[ $ans == "y" ]]; then
		printf "[Ask] Enter new integer value: "
		read newValue
		# Increase size by regex replacing.
		sudo sed -i -e "'s/# server_names_hash_bucket_size 64;/server_names_hash_bucket_size ${newValue};/g'" /etc/nginx/nginx.conf

		# Reload nginx config
		sudo service nginx reload
	fi

	echo "=> Installed certbot."
}

# Note: nvm is used to install node per user (not for all users)
# Ref: https://github.com/nvm-sh/nvm#installing-and-updating
InstallAndSetupNodejs_ViaNvm() {
	local NODE_VERSION="$1"

	if [ -z "$NODE_VERSION" ]; then
		echo "Usage: InstallAndSetupNodejs_ViaNvm <node_version>"
		echo "Example: InstallAndSetupNodejs_ViaNvm 18"
		return 1
	fi

	echo ">>> Installing NVM if not already installed..."
	if [ ! -d "$HOME/.nvm" ]; then
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
	else
		echo "NVM already installed at $HOME/.nvm"
	fi

	# Load nvm for this script
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

	echo ">>> Installing Node.js v$NODE_VERSION ..."
	nvm install "$NODE_VERSION"
	nvm use "$NODE_VERSION"

	echo ">>> Setting up system-wide symlinks ..."
	sudo unlink /usr/local/bin/node 2>/dev/null || true
	sudo unlink /usr/local/bin/npm 2>/dev/null || true
	sudo unlink /usr/local/bin/npx 2>/dev/null || true
	sudo ln -s "$(which node)" /usr/local/bin/node
	sudo ln -s "$(which npm)" /usr/local/bin/npm
	sudo ln -s "$(which npx)" /usr/local/bin/npx

	echo ">>> Checking installed versions ..."
	ll /usr/local/bin/node
	ll /usr/local/bin/npm
	node -v
	npm -v

	echo "=> Done installing Node.js v$NODE_VERSION"
	echo "And add below command to ~/.bash_profile to ensure ~/.bashrc is loaded well"
	echo "if [ -f "$HOME/.bashrc" ]; then"
	echo "	. "$HOME/.bashrc""
	echo "fi"
}

Install_Curl() {
	sudo apt install curl
}

Install_Zip() {
	sudo apt install zip
}

Install_Unzip() {
	sudo apt install unzip
}

Install_Docker() {
	# 1. Uninstall old version first
	for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

	# 2. Setup apt's repo
	# Add Docker's official GPG key:
	sudo apt-get update
	sudo apt-get install ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
		$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
		sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update

	# 3. Install latest version
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

	# 4. Post install
	# Enable auto-start docker
	sudo systemctl enable docker
	sudo systemctl start docker

	# Add current user to Docker group (so we don’t need sudo for every command)
	sudo usermod -aG docker $USER

	# 4. Verify docker
	# Check version
	docker --version
	docker compose version

	# Check runtime
	sudo docker run hello-world
}

Upgrade_Docker() {
	# 1. Update package information
	sudo apt-get update

	# 2. Upgrade Docker packages
	sudo apt-get install --only-upgrade -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

	# 3. Restart docker
	sudo systemctl restart docker

	# 4. Verify upgrade
	docker --version
	docker compose version
}

Install_AwsCli() {
	sudo apt install -y awscli

	# Config credential (key/secret/region)
	aws configure
}

Uninstall_Php() {
	# Check all versions
	php -v
	dpkg -l | grep php

	# Choose one of version (8.2 or all)
	sudo apt purge 'php8.2*'
	sudo apt purge 'php*'

	# Remove dependencies
	sudo apt autoremove --purge -y
	sudo apt autoclean

	# Verify php removed
	php -v
	which php
}

Install_Kubernetes() {
	sudo apt update
	sudo apt install -y apt-transport-https ca-certificates curl

	# Add Kubernetes GPG key
	sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
		https://packages.cloud.google.com/apt/doc/apt-key.gpg

	# Add repo
	echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
	https://apt.kubernetes.io/ kubernetes-xenial main" | \
	sudo tee /etc/apt/sources.list.d/kubernetes.list

	# Install kubelet, kubeadm, kubectl
	sudo apt update
	sudo apt install -y kubelet kubeadm kubectl
	sudo apt-mark hold kubelet kubeadm kubectl

	# Disable swap
	sudo swapoff -a
	sudo sed -i '/ swap / s/^/#/' /etc/fstab
}

# Tool for store/pull/push docker image
Download_Harbor() {
	set -e

	# Update OS packages
	Update_Packages

	# Install dependencies
	sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release openssl

	# Install docker if not installed
	if ! command -v docker >/dev/null 2>&1; then
		echo "=== Installing Docker ==="
		Install_Docker
	fi

	# Download latest Harbor
	cd /tmp
	HARBOR_URL=$(curl -s https://api.github.com/repos/goharbor/harbor/releases/latest \
		| grep browser_download_url | grep offline-installer | grep tgz \
		| cut -d '"' -f 4)

	echo "Downloading Harbor from $HARBOR_URL ..."
	wget -q --show-progress $HARBOR_URL

	HARBOR_PKG=$(basename $HARBOR_URL)
	tar xzf $HARBOR_PKG
	sudo rm -rf /opt/harbor
	sudo mv harbor /opt/harbor

	# Configure Harbor
	cd /opt/harbor
	cp harbor.yml.tmpl harbor.yml
}

Install_Jenkins() {
	Update_Packages

	# Install Java (OpenJDK 21)
	sudo apt install -y openjdk-21-jdk
	java -version

	# Add Jenkins LTS repository with key
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
	echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

	# Install Jenkins
	sudo apt update
	sudo apt install -y jenkins

	# Start/enable Jenkins
	sudo systemctl start jenkins
	sudo systemctl enable jenkins

	# Check status
	sudo systemctl status jenkins

	echo "Jenkins installed."
	echo "To access Jenkins web console, open browser at: http://<server-ip>:8080"
	echo "Get initial admin password by running: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}
