
Update_OS() {
	sudo apt-get update -y && sudo apt-get upgrade -y
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

	echo "[Warn] Please continue with manual configuration at `__MySQL_Manual_Config`"
}
# Caller should follow it after installed MySQL.
__MySQL_Manual_Config() {
	# Step 1. Use root native password to setup.
	# We need root priviledge to run mysql_secure_installation script.
	# Since by default MySQL 8.0 uses auth_socket for authentication,
	# so we will adjust to authenticate with id/pwd instead, then revert after done.
	sudo mysql
	mysql> ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Root1234!';
	mysql> \q

	# Step 2. Run secure script with root previledge (enter root password if be asked).
	# Yes all for more secure.
	sudo mysql_secure_installation

	# Step 3. CRUD user account
	sudo mysql -u root -p

	# [Option 1] Use authentication_plugin will prevent remote-connection, so client cannot interact with db.
	# mysql> CREATE USER 'mydb_user'@'localhost' IDENTIFIED WITH authentication_plugin BY 'password';

	# [Option 2] For test purpose, use id/pwd so client can connect to db, but it is less security than authentication_plugin.
	# Use `localhost` or remote ip (for eg,. %, 212.123.99.182,...)
	mysql> CREATE USER 'mydb_user'@'%' IDENTIFIED BY 'Staging1234!';

	# [Option 3] For rename existed user
	mysql> RENAME USER 'mydb_user'@'%' TO 'ncp_user'@'%';

	# [Option 4] For drop the user
	mysql> DROP USER 'ncp_user'@'%';

	# Step 4. Grant access to db for the user
	# mysql> CREATE USER 'ncp_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';
	mysql> GRANT ALL ON ncp_mysql.* TO 'ncp_user'@'%';
	mysql> FLUSH PRIVILEGES;
	mysql> \q

	# Step 5. Revert root authentication to auth_socket
	mysql -u root -p
	mysql> ALTER USER 'root'@'localhost' IDENTIFIED WITH auth_socket;
	mysql> \q
	# Now, we can once again connect to MySQL as your root user using the [sudo mysql] command.

	# Allow access from remote connection (or outside network)
	sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
	# Uncomment 2 lines
	bind-address = 127.0.0.1
	mysqlx-bind-address = 127.0.0.1
	# Finally, restart mysql server
	sudo systemctl restart mysql

	# Step 6. Check service status
	systemctl status mysql.service
	echo "[Note] If service is not started, go with: sudo systemctl start mysql"
}

# Ref: https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-ubuntu-22-04
Install_Nginx() {
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
Dotnet_Cleanup() {
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
	# If you use apt-get to install redis then use
	sudo apt-get purge --auto-remove redis-server
}

ConfigSSH() {
	$DOMAIN_NAME=$1

	echo "Complete below settings:"
	echo "1. Domain is pointing to server"
	echo "- Domain xxx.abc.com and www.xxx.abc.com are pointing to the server public IP address??"
	echo "2. Enable firewall for http, https"
	echo "- If you are on aws ec2, then allow ports 80, 443 to the server by edit inbounds rules."
	echo "- If you are on ubuntu machine, then run: sudo ufw allow http & sudo ufw allow https"
	printf "Press y to continue? (y/*): "
	read ans
	if [[ $ans != "y" ]]; then
		echo "Aborted"
		return
	fi

	Install_Certbot

	# Obtain ssh cert and Reload nginx
	sudo certbot --nginx -d ${DOMAIN_NAME} -d www.${DOMAIN_NAME}
	sudo service nginx reload

	echo "=> Done config SSH."
}

# Ref: https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-22-04
Install_Certbot() {
	echo "[Info] Installing certbot..."

	# Install certbot
	# For uninstall: sudo apt remove certbot
	sudo snap install core
	sudo snap refresh core
	sudo snap install --classic certbot
	sudo ln -s /snap/bin/certbot /usr/bin/certbot

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

# Note: nodesource is used to install node for all users.
# Ref: https://github.com/nodesource/distributions/blob/master/README.md
InstallAndSetupNodejs_ViaNodeSource() {
	printf "Enter node version (current, 16, 18,...): "
	read node_version
	printf "Install node ${node_version}? (y/*): "
	read ans
	if [[ $ans != "y" ]]; then
		echo "Aborted"
		return
	fi

	curl -fsSL https://deb.nodesource.com/setup_${node_version}.x | sudo -E bash -
	sudo apt-get install -y nodejs

	# curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
	# sudo apt-get install -y nodejs
}

# Note: nvm is used to install node per user (not for all users)
# Ref: https://github.com/nvm-sh/nvm#installing-and-updating
InstallAndSetupNodejs_ViaNvm_PreSetup() {
	# Should use `curl` of ubuntu
	echo "If curl is not installed, pls install with: sudo apt install curl"

	# Install nvm (node version management)
	# Need change owner back later at post-phase
	# sudo mkdir -p /usr/local/nvm
	# sudo chown $USER:$USER /usr/local/nvm
	# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | NVM_DIR=/usr/local/nvm bash
	# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

	echo "[Warn] Please run above command to add nvm to bash. Or otherwise, exit terminal and re-enter to continue setup."
	echo "And add below command to ~/.bash_profile to ensure ~/.bashrc is loaded well"
	echo "if [ -f "$HOME/.bashrc" ]; then"
	echo "	. "$HOME/.bashrc""
	echo "fi"
}
# After installed, should reload terminal (for eg,. source ~/.bashrc, or exit -> re-enter to server)
InstallAndSetupNodejs_ViaNvm_PostSetup() {
	# Install and Use node with specific version
	# Note: 18 means we use latest version, for eg,. 18.2.0
	nvm install ${NODE_VERSION}

	# Switch nodejs version, just use
	nvm use ${NODE_VERSION}

	# Make nodejs available for all users by create symbol link at /usr/local/bin to our installed node, npm
	# Before it, we need change back owner to root so other users can use node, npm
	# sudo chown root:root /usr/local/nvm
	sudo unlink /usr/local/bin/node
	sudo unlink /usr/local/bin/npm
	sudo unlink /usr/local/bin/npx
	sudo ln -s "$(which node)" /usr/local/bin/node
	sudo ln -s "$(which npm)" /usr/local/bin/npm
	sudo ln -s "$(which npx)" /usr/local/bin/npx

	# Check path and version
	ll /usr/local/bin/node
	ll /usr/local/bin/npm
	node -v
	npm -v

	echo "=> Done install node, npm"
}
