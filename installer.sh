
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

	echo "[Warn] Please continue with manual configure MySQL"
}
# Caller should follow it after installed MySQL.
__MySQL_Manual_Config() {
	# [Run mysql_secure_installation script]
	# We need root priviledge to run mysql_secure_installation script.
	# Since by default MySQL 8.0 uses auth_socket for authentication,
	# so we will adjust to authenticate with id/pwd instead, then revert after done.
	sudo mysql
	mysql> ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Root1234!';
	mysql> \q

	# Run secure script with root previledge (enter root password if be asked).
	# Yes all for more secure.
	sudo mysql_secure_installation

	# Create our account
	sudo mysql -u root -p
	# [Option 1] Use authentication_plugin will prevent remote-connection, so client cannot interact with db.
	# mysql> CREATE USER 'darkcompet'@'localhost' IDENTIFIED WITH authentication_plugin BY 'password';
	# [Option 2] For test purpose, use id/pwd so client can connect to db, but it is less security than authentication_plugin.
	mysql> CREATE USER 'darkcompet'@'localhost' IDENTIFIED BY 'Test1234!';
	# mysql> CREATE USER 'darkcompet'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';
	mysql> GRANT ALL ON phongthuydainam.* TO 'darkcompet'@'localhost';
	mysql> FLUSH PRIVILEGES;
	mysql> \q

	# Rever root authentication to auth_socket
	mysql -u root -p
	mysql> ALTER USER 'root'@'localhost' IDENTIFIED WITH auth_socket;
	mysql> \q
	# Now, we can once again connect to MySQL as your root user using the [sudo mysql] command.

	# Check service status
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
Install_Dotnet() {
	echo "[Info] Installing dotnet..."

	# Install package
	wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
	sudo dpkg -i packages-microsoft-prod.deb
	rm packages-microsoft-prod.deb

	# Install SDK for development
	sudo apt-get update; \
  sudo apt-get install -y apt-transport-https && \
  sudo apt-get update && \
  sudo apt-get install -y dotnet-sdk-6.0

	# Install runtime (asp.net core)
	sudo apt-get update; \
  sudo apt-get install -y apt-transport-https && \
  sudo apt-get update && \
  sudo apt-get install -y aspnetcore-runtime-6.0

	echo "=> Installed dotnet."
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

# Ref: https://github.com/nvm-sh/nvm#installing-and-updating
InstallAndSetupNodejs_PreSetup() {
	# Install nvm (node version management)
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

	echo "[Warn] Please exit terminal and re-enter to continue setup."
}
InstallAndSetupNodejs_PostSetup() {
	# Install and Use node with specific version
	# Note: 18 means we use latest version, for eg,. 18.2.0
	# After installed, should reload terminal (for eg,. by exit and re-enter to server)
	nvm install $NODE_VERSION

	# To switch nodejs version, just use
	nvm use $NODE_VERSION

	# Create symbol link from /usr/bin to our installed node, npm
	sudo unlink /usr/local/bin/node
	sudo unlink /usr/local/bin/npm
	sudo ln -s "$(which node)" /usr/local/bin/node
	sudo ln -s "$(which npm)" /usr/local/bin/npm

	# Check versions
	node -v
	npm -v
}
