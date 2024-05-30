#!/bin/bash

# 
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires the use of root, please type su root and rerun this script"
    exit 1
  fi
}

get_system_info() {
  RAM_USED=$(free -h | awk '/^Mem/ {print $3}')
  RAM_TOTAL=$(free -h | awk '/^Mem/ {print $2}')
  CPU_IDENTIFIER=$(lscpu | grep "Model name" | awk -F: '{print $2}' | xargs)
  CPU_GHZ=$(lscpu | grep "CPU MHz" | awk -F: '{print $2}' | xargs)
  OS_NAME=$(lsb_release -ds)
  STORAGE_USED=$(df -h / | awk 'NR==2 {print $3}')
  STORAGE_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
}

generate_password() {
  PASSWORD=$(openssl rand -base64 24)
}

check_root

get_system_info

echo "You are installing NamelessMC on your server, please click enter to proceed; click CTRL+C to exit."
echo "-- Script by Auri (github.com/imlayered) --"
echo "System Information:"
echo "- RAM: ${RAM_USED} / ${RAM_TOTAL}"
echo "- CPU: ${CPU_IDENTIFIER} (${CPU_GHZ} MHz)"
echo "- OS: ${OS_NAME}"
echo "- Storage: ${STORAGE_USED} / ${STORAGE_TOTAL}"
echo "-- Note: We recommend having at least 10GB storage free and at least 3GB total RAM"
read -p ""

read -p "Please enter your email: " USER_EMAIL
read -p "Please enter the domain for which you want NamelessMC installed on: " USER_DOMAIN

sudo apt update && sudo apt install -y nginx php-fpm php-curl php-exif php-gd php-mbstring php-mysql php-pdo php-xml mariadb-server

mkdir -p /var/www/html
curl -L "https://github.com/NamelessMC/Nameless/releases/latest/download/nameless-deps-dist.tar.xz" | tar --xz --extract --directory=/var/www/html --file -
chown -R www-data:www-data /var/www/html
chmod -R ugo-x,u+rwX,go-rw /var/www/html

generate_password

mysql -u root -e "CREATE USER 'nameless'@'127.0.0.1' IDENTIFIED BY '${PASSWORD}';"
mysql -u root -e "CREATE DATABASE nameless;"
mysql -u root -e "GRANT ALL PRIVILEGES ON nameless.* TO 'nameless'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"

read -p "Would you like to setup the webserver? (Y/n) " SETUP_WEBSERVER
if [ "$SETUP_WEBSERVER" != "n" ]; then
  sudo apt install -y snapd
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
  sudo certbot certonly --nginx --email "$USER_EMAIL" --agree-tos --no-eff-email -d "$USER_DOMAIN"

  cat <<EOL > /etc/nginx/sites-available/nameless.conf
server {
    listen 80;
    server_name ${USER_DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${USER_DOMAIN};

    root /var/www/html;
    index index.php index.html;

    client_max_body_size 100m;


    ssl_certificate /etc/letsencrypt/live/${USER_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${USER_DOMAIN}/privkey.pem;

    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options "SAMEORIGIN";
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.php?route=\$uri&\$args;
    }

    location ~ \.(tpl|cache|htaccess)$ {
        return 403;
    }

    location ^~ /node_modules/ {
        return 403;
    }

    location ^~ /scripts/ {
        return 403;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php-fpm.sock; # May need to be edited
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOL

  sudo ln -s /etc/nginx/sites-available/nameless.conf /etc/nginx/sites-enabled/nameless.conf
  sudo nginx -s reload

  echo "NamelessMC has been installed on your system and is running on ${USER_DOMAIN}"
else
  echo "NamelessMC has been installed on your system, you will need to setup a webserver by following https://docs.namelessmc.com/en/webserver"
  echo "Script by Auri (github.com/imlayered) | "
fi

echo "Database user 'nameless' has been created with the following password: ${PASSWORD}"

echo "Script by Auri (github.com/imlayered)"
