#----------------------------------------------------------------------------------------------------------------------#
# Run before setup each project
#----------------------------------------------------------------------------------------------------------------------#

# Each project must import functions from core in advance !
# source ../tool/compet/shell-ubuntu/installer.sh

#----------------------------------------------------------------------------------------------------------------------#
# Utility functions for each project
#----------------------------------------------------------------------------------------------------------------------#

__CloneProject() {
	echo "Complete below settings:"
	echo "1. Register with gitlab.com to allow connection from this server:"
	echo "- Run: ssh-keygen -t ed25519 -C \"ec2 ${PROJ_ACTUAL_FOLDER_NAME}\""
	echo "- Copy/Paste the public key (cat ~/.ssh/id_ed25519.pub) to: https://gitlab.com/-/profile/keys"
	printf "Press y to continue? (y/*): "
	read ans
	if [[ $ans != "y" ]]; then
		echo "Aborted"
		return
	fi

	# Make tmp-user folder
	if [[ ! -d "/var/www/tmp-${SERVICE_USER}" ]]; then
		sudo mkdir -p /var/www/tmp-${SERVICE_USER}
		sudo chown ${SERVICE_USER}:${SERVICE_USER} -R /var/www/tmp-${SERVICE_USER}
		echo "[Info] Created new dir: /var/www/tmp-${SERVICE_USER}, and make owner as ${SERVICE_USER}"
	fi

	# Please config in advance to use gitlab SSH connection
	cd /var/www/tmp-${SERVICE_USER}
	git clone ${GIT_REPO_BASE_URL}/${GIT_REPO_NAME}.git
	sudo mv -f ${GIT_REPO_NAME} ${ROOT_DIR_PATH}/${PROJ_ACTUAL_FOLDER_NAME}
}

_CreateAspProject() {
	__CloneProject

	# Setup env
	cd ${ROOT_DIR_PATH}/${PROJ_ACTUAL_FOLDER_NAME}
	git checkout ${BRANCH}
	cp Properties/launchSettings.${BRANCH} Properties/launchSettings.json
	cp appsettings.${BRANCH} appsettings.json

	# Move convenience files to local folder
	mkdir local
	cp ${CONFIG_PROJ_ROOT_DIR_PATH}/data/local/*.sh local/
	chmod +x local/*.sh

	echo "=> Done make project"

	cd ${CONFIG_PROJ_ROOT_DIR_PATH}
}

_CreateNodejsProject() {
	__CloneProject

	# Setup env
	cd ${ROOT_DIR_PATH}/${PROJ_ACTUAL_FOLDER_NAME}
	git checkout ${BRANCH}
	cp .env.${BRANCH} .env
	npm install

	# Move convenience files to local folder
	mkdir local
	cp ${CONFIG_PROJ_ROOT_DIR_PATH}/data/local/*.sh local/
	chmod +x local/*.sh

	echo "=> Done setup project"

	cd ${CONFIG_PROJ_ROOT_DIR_PATH}
}

_CreateLaravelProject() {
	__CloneProject

	# Setup env
	cd ${ROOT_DIR_PATH}/${PROJ_ACTUAL_FOLDER_NAME}
	git checkout ${BRANCH}
	cp .env.${BRANCH} .env

	mkdir -p storage/app
	mkdir -p storage/logs
	mkdir -p storage/framework/sessions storage/framework/views storage/framework/cache
	sudo chown -R $USER:www-data storage
	sudo chown -R $USER:www-data bootstrap/cache
	chmod -R 775 storage
	chmod -R 775 bootstrap/cache

	composer install --ignore-platform-reqs

	# Move convenience files to local folder
	mkdir local
	cp ${CONFIG_PROJ_ROOT_DIR_PATH}/data/local/*.sh local/
	chmod +x local/*.sh

	echo "=> Done setup project"

	cd ${CONFIG_PROJ_ROOT_DIR_PATH}
}

_ConfigNginxForProject() {
	# Remove default config
	sudo rm /etc/nginx/sites-available/default
	sudo rm /etc/nginx/sites-enabled/default

	# Create nginx config file
	sudo cp ${CONFIG_PROJ_ROOT_DIR_PATH}/data/config/${NGINX_CONFIG_FILE_NAME}.config /etc/nginx/sites-available/

	# Enable our site
	sudo ln -s /etc/nginx/sites-available/${NGINX_CONFIG_FILE_NAME}.config /etc/nginx/sites-enabled/

	# Validate config grammar
	sudo nginx -t

	# Done, reload config
	sudo service nginx reload

	echo "=> Done config nginx for the project"

	cd ${CONFIG_PROJ_ROOT_DIR_PATH}
}

_CreateServiceForProject() {
	# Create service file
	sudo cp ${CONFIG_PROJ_ROOT_DIR_PATH}/data/config/${SERVICE_IDENTIFIER}.service /etc/systemd/system/

	# Enable service start when machine boots.
	# To disable, just change enable -> disable.
	sudo systemctl enable ${SERVICE_IDENTIFIER}

	# Reload services
	sudo systemctl daemon-reload

	# Commented out since we should start service at final stage
	# Start service
	# sudo systemctl restart ${SERVICE_IDENTIFIER}
	# sudo systemctl status ${SERVICE_IDENTIFIER}

	echo "=> Created service /etc/systemd/system/${SERVICE_IDENTIFIER}.service for ${PROJ_ACTUAL_FOLDER_NAME}"

	cd ${CONFIG_PROJ_ROOT_DIR_PATH}
}

_ConfigSSH() {
	echo "Complete below settings:"
	echo "1. Domain is pointing to server"
	echo "- Domain xxx.abc.com and www.xxx.abc.com are pointing to the server public IP address??"
	echo "2. Enable firewall at ec2"
	echo "- Allow ports 80, 443 to the server by edit inbounds rules."
	echo "3. Enable firewall at remote server"
	echo "- Allow ports 80, 443 to the server by hit below commands:"
	echo "	sudo ufw allow http"
	echo "	sudo ufw allow https"
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

	cd ${CONFIG_PROJ_ROOT_DIR_PATH}
}

_CompleteSetupForAspProject() {
	cd ${ROOT_DIR_PATH}/${PROJ_ACTUAL_FOLDER_NAME}
	git branch

	echo "=> Congratulation ! Please follow below steps before start server:"
	echo "- Modify setting to match with current env: nano appsettings.json"
	echo "- Deploy server: ./local/deploy.sh"
	echo "- Check service status: sudo systemctl status ${SERVICE_IDENTIFIER}"
	echo "- Check service log: journalctl --unit=${SERVICE_IDENTIFIER} --follow"
}

_CompleteSetupForNodejsProject() {
	cd ${ROOT_DIR_PATH}/${PROJ_ACTUAL_FOLDER_NAME}
	git branch

	echo "=> Congratulation ! Please follow below steps before start server:"
	echo "- Modify setting to match with current env: nano .env"
	echo "- Deploy server: ./local/deploy.sh"
	echo "- Check service status: sudo systemctl status ${SERVICE_IDENTIFIER}"
	echo "- Check service log: journalctl --unit=${SERVICE_IDENTIFIER} --follow"
}

_CompleteSetupForLaravelProject() {
	cd ${ROOT_DIR_PATH}/${PROJ_ACTUAL_FOLDER_NAME}
	git branch

	echo "=> Congratulation ! Please follow below steps before start server:"
	echo "- Modify setting to match with current env: nano .env"
	echo "- Deploy server: ./local/deploy.sh"
	echo "- Start server: sudo systemctl start ${SERVICE_IDENTIFIER}"
	echo "- Check service status: sudo systemctl status ${SERVICE_IDENTIFIER}"
	echo "- Check service log: journalctl --unit=${SERVICE_IDENTIFIER} --follow"
}
