#!/bin/bash
################################################################################
# Original Author:   Kudaraidee
# Modified by : msy2008 (https://github.com/msy2008/yiimp_install_scrypt)

# Program:
#   Install yiimp on Ubuntu 22.04 / 24.04 running Nginx, MariaDB
#   PHP 8.2 (22.04) or PHP 8.3 (24.04)
#   v1.1 (updated November 2026)
#
################################################################################

    # Always run from the directory that contains this script, so the files in
    # conf/ and utils/ can be found even when the script is called by path.
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR" || exit 1

    # Never prompt in the middle of package installation.
    export DEBIAN_FRONTEND="noninteractive"

    output() {
    printf "\E[0;33;40m"
    echo "$1"
    printf "\E[0m"
    }

    displayErr() {
    echo
    echo $1;
    echo
    exit 1;
    }

    #Add user group sudo + no password
    whoami=`whoami`
    sudo usermod -aG sudo ${whoami}
    echo '# yiimp
    # It needs passwordless sudo functionality.
    '""''"${whoami}"''""' ALL=(ALL) NOPASSWD:ALL
    ' | sudo -E tee /etc/sudoers.d/${whoami} >/dev/null 2>&1

    #Copy needed files
    sudo cp -r conf/functions.sh /etc/
    sudo cp -r utils/screen-scrypt.sh /etc/
    sudo cp -r conf/editconf.py /usr/bin/
    sudo chmod +x /usr/bin/editconf.py
    sudo chmod +x /etc/screen-scrypt.sh

    source /etc/functions.sh

    # Package installation helpers
    apt_install() {
        sudo apt-get install -y "$@"
    }

    apt_install_optional() {
        local pkg
        for pkg in "$@"; do
            if apt-cache show "$pkg" >/dev/null 2>&1; then
                apt_install "$pkg" || echo -e "$YELLOW WARNING: failed to install $pkg $COL_RESET"
            else
                echo -e "$YELLOW WARNING: package $pkg is not available, skipping it $COL_RESET"
            fi
        done
    }


    clear
    echo
    echo -e "$GREEN************************************************************************$COL_RESET"
    echo -e "$GREEN Yiimp Install Script v1.1 $COL_RESET"
    echo -e "$GREEN Install yiimp on Ubuntu 22.04 / 24.04 running Nginx, MariaDB and PHP $COL_RESET"
    echo -e "$GREEN************************************************************************$COL_RESET"
    echo
    sleep 3


    # Update package and Upgrade Ubuntu
    echo
    echo
    echo -e "$CYAN => Updating system and installing required packages :$COL_RESET"
    echo
    sleep 3

    sudo apt -y update
    sudo apt -y upgrade
    sudo apt -y autoremove
    sudo apt-get install -y software-properties-common
    sudo apt -y install dialog python3 python3-pip acl nano apt-transport-https \
        lsb-release ca-certificates curl wget gnupg cron
    echo -e "$GREEN Done...$COL_RESET"


    source conf/prerequisite.sh
    echo -e "$CYAN Detected Ubuntu ${DISTRO} - using PHP ${PHP_VER}$COL_RESET"
    sleep 3
    source conf/getip.sh


    echo 'PUBLIC_IP='"${PUBLIC_IP}"'
    PUBLIC_IPV6='"${PUBLIC_IPV6}"'
    DISTRO='"${DISTRO}"'
    PRIVATE_IP='"${PRIVATE_IP}"'' | sudo -E tee conf/pool.conf >/dev/null 2>&1

    echo
    echo
    echo -e "$RED Make sure you double check before hitting enter! Only one shot at these! $COL_RESET"
    echo
    #read -e -p "Enter time zone (e.g. America/New_York) : " TIME
    read -e -p "Domain Name (no http:// or www. just : example.com or pool.example.com or Public IP (185.22.24.26)) : " server_name
    read -e -p "Are you using a subdomain (mycryptopool.example.com?) [y/N] : " sub_domain
    read -e -p "Enter support email (e.g. admin@example.com) : " EMAIL
    read -e -p "Set Pool to AutoExchange? i.e. mine any coin with BTC address? [y/N] : " BTC
    #read -e -p "Please enter a new location for /site/adminRights this is to customize the Admin Panel entrance url (e.g. myAdminpanel) : " admin_panel
    read -e -p "Enter the Public IP of the system you will use to access the admin panel (IP of YOUR PC where need to be access to Panel) : " Public
    read -e -p "Install Fail2ban? [Y/n] : " install_fail2ban
    read -e -p "Install UFW and configure ports? [Y/n] : " UFW
    read -e -p "Install LetsEncrypt SSL? IMPORTANT! You MUST have your domain name pointed to this server prior to running the script!! [Y/n]: " ssl_install

    # Normalise the host name and validate the optional inputs.
    server_name="${server_name#http://}"
    server_name="${server_name#https://}"
    server_name="${server_name%%/*}"

    if [ -z "$Public" ]; then
        Public="$PUBLIC_IP"
    fi

    if [ -z "$EMAIL" ]; then
        echo -e "$YELLOW No support e-mail was entered; Let's Encrypt will be skipped.$COL_RESET"
        ssl_install="n"
    fi

    # Let's Encrypt does not issue certificates for bare IPv4 addresses.
    if [[ "$server_name" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        echo -e "$YELLOW $server_name looks like an IP address; SSL will be skipped.$COL_RESET"
        ssl_install="n"
        sub_domain="n"
    fi


    # Switch Aptitude
    #echo
    #echo -e "$CYAN Switching to Aptitude $COL_RESET"
    #echo
    #sleep 3
    #sudo apt -y install aptitude
    #echo -e "$GREEN Done...$COL_RESET $COL_RESET"


    # Installing Nginx
    echo
    echo
    echo -e "$CYAN => Installing Nginx server : $COL_RESET"
    echo
    sleep 3

    if [ -f /usr/sbin/apache2 ]; then
    echo -e "Removing apache..."
    sudo apt-get -y purge apache2 apache2-*
    sudo apt-get -y --purge autoremove
    fi

    sudo apt -y install nginx
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl start nginx.service
    sudo systemctl enable nginx.service
    sudo systemctl start cron.service
    sudo systemctl enable cron.service
    sleep 5
    sudo systemctl status nginx | sed -n "1,3p"
    sleep 15
    echo
    echo -e "$GREEN Done...$COL_RESET"


    # Making Nginx a bit hard
    echo 'map $http_user_agent $blockedagent {
    default         0;
    ~*malicious     1;
    ~*bot           1;
    ~*backdoor      1;
    ~*crawler       1;
    ~*bandit        1;
    }
    ' | sudo -E tee /etc/nginx/blockuseragents.rules >/dev/null 2>&1


    # Installing Mariadb
    echo
    echo
    echo -e "$CYAN => Installing Mariadb Server : $COL_RESET"
    echo
    sleep 3

    # Create random password
    rootpasswd=$(openssl rand -base64 12)
    export DEBIAN_FRONTEND="noninteractive"
    sudo apt -y install mariadb-server
    sudo systemctl enable mariadb.service
    sudo systemctl start mariadb.service
    sleep 5
    sudo systemctl status mariadb | sed -n "1,3p"
    sleep 15
    echo
    echo -e "$GREEN Done...$COL_RESET"


    # Installing PHP (8.2 on Ubuntu 22.04, 8.3 on Ubuntu 24.04)
    echo
    echo
    echo -e "$CYAN => Installing PHP ${PHP_VER} : $COL_RESET"
    echo
    sleep 3

    source conf/pool.conf

    # Add the Ondrej PHP repository if it is not configured yet.
    if ! grep -rqs "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/; then
        echo "Adding Ondrej PHP repository..."
        sudo add-apt-repository -y ppa:ondrej/php
        sudo apt-get update
    fi

    sudo apt-get update

    # Versioned packages are used so the requested PHP version is installed
    # even when the distribution default is a different version.
    PHP_PKGS=(
        "php${PHP_VER}-fpm" "php${PHP_VER}-opcache" "php${PHP_VER}" "php${PHP_VER}-common"
        "php${PHP_VER}-gd" "php${PHP_VER}-mysql" "php${PHP_VER}-imap" "php${PHP_VER}-cli"
        "php${PHP_VER}-cgi" php-pear imagemagick libruby "php${PHP_VER}-curl"
        "php${PHP_VER}-intl" "php${PHP_VER}-pspell" "php${PHP_VER}-sqlite3" "php${PHP_VER}-tidy"
        "php${PHP_VER}-xmlrpc" "php${PHP_VER}-xsl" memcached "php${PHP_VER}-memcache"
        "php${PHP_VER}-imagick" "php${PHP_VER}-zip" "php${PHP_VER}-mbstring"
        libpsl-dev libnghttp2-dev "php${PHP_VER}-memcached" net-tools
    )

    # A single missing package makes apt abort the whole transaction, so fall
    # back to installing the packages one by one.
    if ! apt_install "${PHP_PKGS[@]}"; then
        echo -e "$YELLOW WARNING: batch PHP install failed, retrying packages one by one...$COL_RESET"
        for pkg in "${PHP_PKGS[@]}"; do
            apt_install "$pkg" || echo -e "$YELLOW WARNING: could not install $pkg $COL_RESET"
        done
    fi

    if ! command -v "php${PHP_VER}" >/dev/null 2>&1; then
        displayErr "PHP ${PHP_VER} could not be installed. Check your network/apt sources and re-run the script."
    fi

    # Enable required PHP modules (mbstring for multibyte string handling)
    sudo phpenmod -v "${PHP_VER}" mbstring

    # Make the selected PHP version the default one
    sudo update-alternatives --install /usr/bin/php php "/usr/bin/php${PHP_VER}" 100
    sudo update-alternatives --set php "/usr/bin/php${PHP_VER}"

    # Start PHP-FPM and memcached and check their status
    sudo systemctl enable --now "php${PHP_VER}-fpm" || displayErr "Failed to start php${PHP_VER}-fpm"
    sudo systemctl status "php${PHP_VER}-fpm" --no-pager | sed -n "1,3p"
    sudo systemctl enable --now memcached || true

    echo -e "\033[32mDone... PHP ${PHP_VER} installed successfully!\033[0m"
    
    # Installing other needed files
    echo
    echo
    echo -e "$CYAN => Installing other needed files : $COL_RESET"
    echo
    sleep 3

    sudo apt -y install libgmp3-dev libmysqlclient-dev libcurl4-gnutls-dev libkrb5-dev libldap2-dev libidn11-dev gnutls-dev \
    librtmp-dev sendmail mutt screen git
    sudo apt -y install pwgen
    echo -e "$GREEN Done...$COL_RESET"
    sleep 3


    # Installing Package to compile crypto currency
    echo
    echo
    echo -e "$CYAN => Installing Package to compile crypto currency $COL_RESET"
    echo
    sleep 3

    apt_install libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils git cmake libboost-all-dev zlib1g-dev libz-dev libseccomp-dev libcap-dev libminiupnpc-dev gettext
    apt_install libminiupnpc17 libzmq5
    apt_install libcanberra-gtk-module libqrencode-dev libzmq3-dev libminizip-dev
    apt_install libqt5gui5 libqt5core5a libqt5webkit5-dev libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler fonts-powerline
    apt_install libssh-dev libbrotli-dev

    # Berkeley DB 4.8 is only available from the Bitcoin Core PPA.
    if ! apt-cache show libdb4.8-dev >/dev/null 2>&1; then
        sudo add-apt-repository -y ppa:luke-jr/bitcoincore || true
        hide_output sudo apt -y update
    fi
    apt_install_optional libdb4.8-dev libdb4.8++-dev libdb5.3 libdb5.3++
    echo -e "$GREEN Done...$COL_RESET"


    # Generating Random Passwords
    password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    password2=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    adminpasswd=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    AUTOGENERATED_PASS=`pwgen -c -1 20`

    # Send a test e-mail (best effort; a broken MTA must not abort the install)
    echo
    echo
    echo -e "$CYAN => Testing to see if server emails are sent $COL_RESET"
    echo
    sleep 3

    if [ -n "$EMAIL" ] && command -v sendmail >/dev/null 2>&1; then
        printf 'To: %s\nSubject: yiimp SMTP test\n\nThis is a test message from %s.\n' \
            "$EMAIL" "$server_name" | sudo sendmail -t \
            || echo -e "$YELLOW WARNING: the test e-mail could not be sent $COL_RESET"
    else
        echo -e "$YELLOW sendmail is not available; skipping the test e-mail $COL_RESET"
    fi
    echo -e "$GREEN Done...$COL_RESET"

    # Installing Fail2Ban & UFW
    echo
    echo
    echo -e "$CYAN => Some optional installs (Fail2Ban & UFW) $COL_RESET"
    echo
    sleep 3


    if [[ ("$install_fail2ban" == "y" || "$install_fail2ban" == "Y" || "$install_fail2ban" == "") ]]; then
    sudo apt -y install fail2ban
    sleep 5
    sudo systemctl status fail2ban | sed -n "1,3p"
        fi


    if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
    sudo apt -y install ufw
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw allow 3333/tcp
    sudo ufw allow 3339/tcp
    sudo ufw allow 3334/tcp
    sudo ufw allow 3433/tcp
    sudo ufw allow 3555/tcp
    sudo ufw allow 3556/tcp
    sudo ufw allow 3573/tcp
    sudo ufw allow 3535/tcp
    sudo ufw allow 3533/tcp
    sudo ufw allow 3553/tcp
    sudo ufw allow 3633/tcp
    sudo ufw allow 3733/tcp
    sudo ufw allow 3636/tcp
    sudo ufw allow 3737/tcp
    sudo ufw allow 3739/tcp
    sudo ufw allow 3747/tcp
    sudo ufw allow 3833/tcp
    sudo ufw allow 3933/tcp
    sudo ufw allow 4033/tcp
    sudo ufw allow 4133/tcp
    sudo ufw allow 4233/tcp
    sudo ufw allow 4234/tcp
    sudo ufw allow 4333/tcp
    sudo ufw allow 4433/tcp
    sudo ufw allow 4533/tcp
    sudo ufw allow 4553/tcp
    sudo ufw allow 4633/tcp
    sudo ufw allow 4733/tcp
    sudo ufw allow 4833/tcp
    sudo ufw allow 4933/tcp
    sudo ufw allow 5033/tcp
    sudo ufw allow 5133/tcp
    sudo ufw allow 5233/tcp
    sudo ufw allow 5333/tcp
    sudo ufw allow 5433/tcp
    sudo ufw allow 5533/tcp
    sudo ufw allow 5733/tcp
    sudo ufw allow 5743/tcp
    sudo ufw allow 3252/tcp
    sudo ufw allow 5755/tcp
    sudo ufw allow 5766/tcp
    sudo ufw allow 5833/tcp
    sudo ufw allow 5900/tcp
    sudo ufw allow 5933/tcp
    sudo ufw allow 6033/tcp
    sudo ufw allow 5034/tcp
    sudo ufw allow 6133/tcp
    sudo ufw allow 6233/tcp
    sudo ufw allow 6333/tcp
    sudo ufw allow 6433/tcp
    sudo ufw allow 7433/tcp
    sudo ufw allow 7070/tcp
    sudo ufw allow 8333/tcp
    sudo ufw allow 8463/tcp
    sudo ufw allow 8433/tcp
    sudo ufw allow 8533/tcp
    sudo ufw allow 9333/tcp
    sudo ufw allow 9321/tcp
    sudo ufw allow 22556/tcp
    sudo ufw allow 22171/tcp
    sudo ufw --force enable
    sleep 5
    sudo systemctl status ufw | sed -n "1,3p"
    fi


    echo
    echo -e "$GREEN Done...$COL_RESET"


    # Installing PhpMyAdmin
    echo
    echo
    echo -e "$CYAN => Installing phpMyAdmin $COL_RESET"
    echo
    sleep 3

    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-user string root" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $rootpasswd" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $AUTOGENERATED_PASS" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password $AUTOGENERATED_PASS" | sudo debconf-set-selections
    sudo apt -y install phpmyadmin
    echo -e "$GREEN Done...$COL_RESET"


    # Installing Yiimp
    echo
    echo
    echo -e "$CYAN => Installing Yiimp $COL_RESET"
    echo
    echo -e "Grabbing yiimp fron Github, building files and setting file structure."
    echo
    sleep 3


    # Generating Random Password for stratum
    blckntifypass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`

    # Compile Blocknotify
    echo -e "Compiling Blocknotify"
    cd "$HOME"
    if [ -d "$HOME/yiimp" ]; then
        displayErr "The directory $HOME/yiimp already exists. Move or remove it, then run the installer again."
    fi
    if [ -e /var/web ]; then
        displayErr "/var/web already exists. This installer must be run on a fresh server."
    fi
    git clone https://github.com/Kudaraidee/yiimp.git || displayErr "Could not clone the yiimp repository."
    cd "$HOME/yiimp/blocknotify" || displayErr "yiimp/blocknotify was not found after cloning."
    sed -i "s/tu8tu5/${blckntifypass}/" blocknotify.cpp
    make -j"$(nproc)"
    strip blocknotify

    # Compile Stratum
    echo -e "Compiling Stratum"
    cd "$HOME/yiimp/stratum/"
    git submodule update --init --recursive

    # yiimp's stratum is tested with gcc-10. Put small compiler wrappers first
    # in PATH instead of changing the system-wide compiler alternatives.
    BUILD_BIN="$HOME/.yiimp-build/bin"
    mkdir -p "$BUILD_BIN"
    if apt_install gcc-10 g++-10 && command -v gcc-10 >/dev/null 2>&1; then
        printf '#!/bin/sh\nexec gcc-10 "$@"\n' > "$BUILD_BIN/gcc"
        printf '#!/bin/sh\nexec g++-10 "$@"\n' > "$BUILD_BIN/g++"
        chmod +x "$BUILD_BIN/gcc" "$BUILD_BIN/g++"
        export PATH="$BUILD_BIN:$PATH"
        echo "Using gcc-10/g++-10 for the stratum build"
    else
        echo "gcc-10 is not available, using the default compiler ($(gcc -dumpversion))"
    fi

    make -C algos
    make -C sha3
    make -C iniparser
    cd secp256k1
    chmod +x autogen.sh
    ./autogen.sh
    ./configure --enable-experimental --enable-module-ecdh --with-bignum=no --enable-endomorphism
    make -j"$(nproc)"
    cd "$HOME/yiimp/stratum/"
    if [[ ("$BTC" == "y" || "$BTC" == "Y") ]]; then
        sed -i 's/CFLAGS += -DNO_EXCHANGE/#CFLAGS += -DNO_EXCHANGE/' Makefile
    fi
    make -j"$(nproc)"

    # Drop the temporary compiler wrappers from PATH.
    export PATH="${PATH#"$BUILD_BIN:"}"
    rm -rf "$BUILD_BIN"

    # Copy Files (Blocknotify,iniparser,Stratum)
    cd "$HOME/yiimp"
    sudo sed -i 's/AdminRights/'AdminPanel'/' "$HOME/yiimp/web/yaamp/modules/site/SiteController.php"
    sudo cp -r "$HOME/yiimp/web" /var/
    sudo mkdir -p /var/stratum
    cd "$HOME/yiimp/stratum"
    sudo cp -a config.sample/. /var/stratum/config
    sudo cp -r stratum /var/stratum
    sudo cp -r run.sh /var/stratum
    cd "$HOME/yiimp"
    sudo cp -r "$HOME/yiimp/bin/." /bin/
    sudo cp -r "$HOME/yiimp/blocknotify/blocknotify" /usr/bin/
    sudo cp -r "$HOME/yiimp/blocknotify/blocknotify" /var/stratum/
    sudo mkdir -p /etc/yiimp
    sudo mkdir -p /var/bin
    sudo chgrp www-data /var/bin
    sudo chmod 775 /var/bin
    #fixing yiimp
    sudo sed -i "s|ROOTDIR=/data/yiimp|ROOTDIR=/var|g" /bin/yiimp
    #fixing run.sh
    sudo rm -f /var/stratum/config/run.sh
    echo '
    #!/bin/bash
    ulimit -n 1024000
    ulimit -u 1024000
    cd /var/stratum
    while true; do
    ./stratum /var/stratum/config/$1
    sleep 2
    done
    exec bash
    ' | sudo -E tee /var/stratum/config/run.sh >/dev/null 2>&1
    sudo chmod +x /var/stratum/config/run.sh

    echo -e "$GREEN Done...$COL_RESET"


    # Update Timezone
    echo
    echo
    echo -e "$CYAN => Update default timezone. $COL_RESET"
    echo

    echo -e " Setting TimeZone to UTC...$COL_RESET"
    sudo timedatectl set-timezone UTC 2>/dev/null || echo "Etc/UTC" | sudo tee /etc/timezone >/dev/null
    sudo systemctl try-restart rsyslog 2>/dev/null || true
    echo
    echo -e "$GREEN Done...$COL_RESET"


    # Creating webserver initial config file
    echo
    echo
    echo -e "$CYAN => Creating webserver initial config file $COL_RESET"
    echo

    # Adding user to group, creating dir structure, setting permissions
    sudo mkdir -p /var/www/$server_name/html

    if [[ ("$sub_domain" == "y" || "$sub_domain" == "Y") ]]; then
    echo 'include /etc/nginx/blockuseragents.rules;
    server {
    if ($blockedagent) {
                return 403;
        }
        if ($request_method !~ ^(GET|HEAD|POST)$) {
        return 444;
        }
        listen 80;
        listen [::]:80;
        server_name '"${server_name}"';
        root "/var/www/'"${server_name}"'/html/web";
        index index.html index.htm index.php;
        charset utf-8;

        location / {
        try_files $uri $uri/ /index.php?$args;
        }
        location @rewrite {
        rewrite ^/(.*)$ /index.php?r=$1;
        }

        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        access_log /var/log/nginx/'"${server_name}"'.app-access.log;
        error_log /var/log/nginx/'"${server_name}"'.app-error.log;

        # allow larger file uploads and longer script runtimes
        client_body_buffer_size  50k;
        client_header_buffer_size 50k;
        client_max_body_size 20m;
        large_client_header_buffers 2 50k;
        sendfile off;

        location ~ ^/index\.php$ {
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:/var/run/php/php'"${PHP_VER}"'-fpm.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_intercept_errors off;
            fastcgi_buffer_size 16k;
            fastcgi_buffers 4 16k;
            fastcgi_connect_timeout 300;
            fastcgi_send_timeout 300;
            fastcgi_read_timeout 1300;
        try_files $uri $uri/ =404;
        }
        location ~ \.php$ {
            return 404;
        }
        location ~ \.sh {
        return 404;
        }
        location ~ /\.ht {
        deny all;
        }
        location ~ /.well-known {
        allow all;
        }
		location ^~ /list-algos/ {
		deny all;
			access_log off;
			return 301 https://$server_name;
		}
        location /phpmyadmin {
        root /usr/share/;
        index index.php;
        try_files $uri $uri/ =404;
        location ~ ^/phpmyadmin/(doc|sql|setup)/ {
            deny all;
      }
        location ~ /phpmyadmin/(.+\.php)$ {
            fastcgi_pass unix:/run/php/php'"${PHP_VER}"'-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
            include snippets/fastcgi-php.conf;
        }
      }
    }
    ' | sudo -E tee /etc/nginx/sites-available/$server_name.conf >/dev/null 2>&1

    sudo ln -sfn /etc/nginx/sites-available/$server_name.conf /etc/nginx/sites-enabled/$server_name.conf
    sudo ln -sfn /var/web /var/www/$server_name/html
    sudo ln -sfn /var/stratum/config /var/web/list-algos
    sudo systemctl reload php${PHP_VER}-fpm.service
    sudo systemctl restart nginx.service
    echo -e "$GREEN Done...$COL_RESET"

    if [[ ("$ssl_install" == "y" || "$ssl_install" == "Y" || "$ssl_install" == "") ]]; then


    # Install SSL (with SubDomain)
    echo
    echo -e "Install LetsEncrypt and setting SSL (with SubDomain)"
    echo

    apt_install certbot
    if ! sudo certbot certonly --non-interactive -a webroot --webroot-path=/var/web \
        --email "$EMAIL" --agree-tos -d "$server_name"; then
        echo -e "$RED WARNING: the certificate could not be obtained. Keeping the HTTP-only configuration.$COL_RESET"
        ssl_install="n"
    fi
    if [[ "$ssl_install" != "n" ]]; then
    sudo rm -f /etc/nginx/sites-available/$server_name.conf
    sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    # I am SSL Man!
    echo 'include /etc/nginx/blockuseragents.rules;
    server {
    if ($blockedagent) {
                return 403;
        }
        if ($request_method !~ ^(GET|HEAD|POST)$) {
        return 444;
        }
        listen 80;
        listen [::]:80;
        server_name '"${server_name}"';
        # enforce https
        return 301 https://$server_name$request_uri;
    }

    server {
    if ($blockedagent) {
                return 403;
        }
        if ($request_method !~ ^(GET|HEAD|POST)$) {
        return 444;
        }
            listen 443 ssl http2;
            listen [::]:443 ssl http2;
            server_name '"${server_name}"';

            root /var/www/'"${server_name}"'/html/web;
            index index.php;

            access_log /var/log/nginx/'"${server_name}"'.app-access.log;
            error_log  /var/log/nginx/'"${server_name}"'.app-error.log;

        # allow larger file uploads and longer script runtimes
        client_body_buffer_size  50k;
        client_header_buffer_size 50k;
        client_max_body_size 20m;
        large_client_header_buffers 2 50k;
        sendfile off;

            # strengthen ssl security
            ssl_certificate /etc/letsencrypt/live/'"${server_name}"'/fullchain.pem;
            ssl_certificate_key /etc/letsencrypt/live/'"${server_name}"'/privkey.pem;
            ssl_protocols TLSv1.2 TLSv1.3;
            ssl_prefer_server_ciphers on;
            ssl_session_cache shared:SSL:10m;
            ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:ECDHE-RSA-AES128-GCM-SHA256:AES256+EECDH:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";
            ssl_dhparam /etc/ssl/certs/dhparam.pem;

            # Add headers to serve security related headers
            add_header Strict-Transport-Security "max-age=15768000; preload;";
            add_header X-Content-Type-Options nosniff;
            add_header X-XSS-Protection "1; mode=block";
            add_header X-Robots-Tag none;
            add_header Content-Security-Policy "frame-ancestors 'self'";

        location / {
        try_files $uri $uri/ /index.php?$args;
        }
        location @rewrite {
        rewrite ^/(.*)$ /index.php?r=$1;
        }


            location ~ ^/index\.php$ {
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass unix:/var/run/php/php'"${PHP_VER}"'-fpm.sock;
                fastcgi_index index.php;
                include fastcgi_params;
                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                fastcgi_intercept_errors off;
                fastcgi_buffer_size 16k;
                fastcgi_buffers 4 16k;
                fastcgi_connect_timeout 300;
                fastcgi_send_timeout 300;
                fastcgi_read_timeout 1300;
                include /etc/nginx/fastcgi_params;
            try_files $uri $uri/ =404;
        }
        location ~ \.php$ {
            return 404;
        }
        location ~ \.sh {
        return 404;
        }

            location ~ /\.ht {
                deny all;
            }
        location /phpmyadmin {
        root /usr/share/;
        index index.php;
        try_files $uri $uri/ =404;
        location ~ ^/phpmyadmin/(doc|sql|setup)/ {
            deny all;
    }
        location ~ /phpmyadmin/(.+\.php)$ {
            fastcgi_pass unix:/run/php/php'"${PHP_VER}"'-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
            include snippets/fastcgi-php.conf;
       }
     }
    }

    ' | sudo -E tee /etc/nginx/sites-available/$server_name.conf >/dev/null 2>&1
    fi
    fi

    sudo systemctl reload php${PHP_VER}-fpm.service
    sudo systemctl restart nginx.service
    echo -e "$GREEN Done...$COL_RESET"


    else
    echo 'include /etc/nginx/blockuseragents.rules;
    server {
    if ($blockedagent) {
                return 403;
        }
        if ($request_method !~ ^(GET|HEAD|POST)$) {
        return 444;
        }
        listen 80;
        listen [::]:80;
        server_name '"${server_name}"' www.'"${server_name}"';
        root "/var/www/'"${server_name}"'/html/web";
        index index.html index.htm index.php;
        charset utf-8;

        location / {
        try_files $uri $uri/ /index.php?$args;
        }
        location @rewrite {
        rewrite ^/(.*)$ /index.php?r=$1;
        }

        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        access_log /var/log/nginx/'"${server_name}"'.app-access.log;
        error_log /var/log/nginx/'"${server_name}"'.app-error.log;

        # allow larger file uploads and longer script runtimes
        client_body_buffer_size  50k;
        client_header_buffer_size 50k;
        client_max_body_size 20m;
        large_client_header_buffers 2 50k;
        sendfile off;

        location ~ ^/index\.php$ {
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:/var/run/php/php'"${PHP_VER}"'-fpm.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_intercept_errors off;
            fastcgi_buffer_size 16k;
            fastcgi_buffers 4 16k;
            fastcgi_connect_timeout 300;
            fastcgi_send_timeout 300;
            fastcgi_read_timeout 1300;
        try_files $uri $uri/ =404;
        }
        location ~ \.php$ {
            return 404;
        }
        location ~ \.sh {
        return 404;
        }
        location ~ /\.ht {
        deny all;
        }
        location ~ /.well-known {
        allow all;
        }
		location ^~ /list-algos/ {
		deny all;
			access_log off;
			return 301 https://$server_name;
		}
        location /phpmyadmin {
        root /usr/share/;
        index index.php;
        try_files $uri $uri/ =404;
        location ~ ^/phpmyadmin/(doc|sql|setup)/ {
            deny all;
    }
        location ~ /phpmyadmin/(.+\.php)$ {
            fastcgi_pass unix:/run/php/php'"${PHP_VER}"'-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
            include snippets/fastcgi-php.conf;
        }
      }
    }
    ' | sudo -E tee /etc/nginx/sites-available/$server_name.conf >/dev/null 2>&1

    sudo ln -sfn /etc/nginx/sites-available/$server_name.conf /etc/nginx/sites-enabled/$server_name.conf
    sudo ln -sfn /var/web /var/www/$server_name/html
    sudo ln -sfn /var/stratum/config /var/web/list-algos
    sudo systemctl reload php${PHP_VER}-fpm.service
    sudo systemctl restart nginx.service
    echo -e "$GREEN Done...$COL_RESET"


    if [[ ("$ssl_install" == "y" || "$ssl_install" == "Y" || "$ssl_install" == "") ]]; then

    # Install SSL (without SubDomain)
    echo
    echo -e "Install LetsEncrypt and setting SSL (without SubDomain)"
    echo
    sleep 3

    apt_install certbot
    if ! sudo certbot certonly --non-interactive -a webroot --webroot-path=/var/web \
        --email "$EMAIL" --agree-tos -d "$server_name" -d "www.${server_name}"; then
        echo -e "$RED WARNING: the certificate could not be obtained. Keeping the HTTP-only configuration.$COL_RESET"
        ssl_install="n"
    fi
    if [[ "$ssl_install" != "n" ]]; then
    sudo rm -f /etc/nginx/sites-available/$server_name.conf
    sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    # I am SSL Man!
    echo 'include /etc/nginx/blockuseragents.rules;
    server {
    if ($blockedagent) {
                return 403;
        }
        if ($request_method !~ ^(GET|HEAD|POST)$) {
        return 444;
        }
        listen 80;
        listen [::]:80;
        server_name '"${server_name}"';
        # enforce https
        return 301 https://$server_name$request_uri;
    }

    server {
    if ($blockedagent) {
                return 403;
        }
        if ($request_method !~ ^(GET|HEAD|POST)$) {
        return 444;
        }
            listen 443 ssl http2;
            listen [::]:443 ssl http2;
            server_name '"${server_name}"' www.'"${server_name}"';

            root /var/www/'"${server_name}"'/html/web;
            index index.php;

            access_log /var/log/nginx/'"${server_name}"'.app-access.log;
            error_log  /var/log/nginx/'"${server_name}"'.app-error.log;

        # allow larger file uploads and longer script runtimes
        client_body_buffer_size  50k;
        client_header_buffer_size 50k;
        client_max_body_size 20m;
        large_client_header_buffers 2 50k;
        sendfile off;

            # strengthen ssl security
            ssl_certificate /etc/letsencrypt/live/'"${server_name}"'/fullchain.pem;
            ssl_certificate_key /etc/letsencrypt/live/'"${server_name}"'/privkey.pem;
            ssl_protocols TLSv1.2 TLSv1.3;
            ssl_prefer_server_ciphers on;
            ssl_session_cache shared:SSL:10m;
            ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:ECDHE-RSA-AES128-GCM-SHA256:AES256+EECDH:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";
            ssl_dhparam /etc/ssl/certs/dhparam.pem;

            # Add headers to serve security related headers
            add_header Strict-Transport-Security "max-age=15768000; preload;";
            add_header X-Content-Type-Options nosniff;
            add_header X-XSS-Protection "1; mode=block";
            add_header X-Robots-Tag none;
            add_header Content-Security-Policy "frame-ancestors 'self'";

        location / {
        try_files $uri $uri/ /index.php?$args;
        }
        location @rewrite {
        rewrite ^/(.*)$ /index.php?r=$1;
        }


            location ~ ^/index\.php$ {
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass unix:/var/run/php/php'"${PHP_VER}"'-fpm.sock;
                fastcgi_index index.php;
                include fastcgi_params;
                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                fastcgi_intercept_errors off;
                fastcgi_buffer_size 16k;
                fastcgi_buffers 4 16k;
                fastcgi_connect_timeout 300;
                fastcgi_send_timeout 300;
                fastcgi_read_timeout 1300;
                include /etc/nginx/fastcgi_params;
            try_files $uri $uri/ =404;
        }
        location ~ \.php$ {
            return 404;
        }
 
		location ~ \.sh {
			return 404;
        }

		location ~ /\.ht {
			deny all;
		}
		
		location /phpmyadmin {
        root /usr/share/;
        index index.php;
        try_files $uri $uri/ =404;
        location ~ ^/phpmyadmin/(doc|sql|setup)/ {
            deny all;
    }
        location ~ /phpmyadmin/(.+\.php)$ {
            fastcgi_pass unix:/run/php/php'"${PHP_VER}"'-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
            include snippets/fastcgi-php.conf;
        }
      }
    }

    ' | sudo -E tee /etc/nginx/sites-available/$server_name.conf >/dev/null 2>&1

    echo -e "$GREEN Done...$COL_RESET"

    fi
    fi
    sudo systemctl reload php${PHP_VER}-fpm.service
    sudo systemctl restart nginx.service
    fi


    # Config Database
    echo
    echo
    echo -e "$CYAN => Now for the database fun! $COL_RESET"
    echo
    sleep 3

    # Create database and users (MariaDB on Ubuntu uses unix_socket for root)
    sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS yiimpfrontend;"
    sudo mysql -u root -e "CREATE USER IF NOT EXISTS 'panel'@'localhost' IDENTIFIED BY '${password}'; GRANT ALL PRIVILEGES ON *.* TO 'panel'@'localhost'; FLUSH PRIVILEGES;"
    sudo mysql -u root -e "CREATE USER IF NOT EXISTS 'stratum'@'localhost' IDENTIFIED BY '${password2}'; GRANT ALL PRIVILEGES ON *.* TO 'stratum'@'localhost'; FLUSH PRIVILEGES;"

    #Create my.cnf

    echo '
    [clienthost1]
    user=panel
    password='"${password}"'
    database=yiimpfrontend
    host=localhost
    [clienthost2]
    user=stratum
    password='"${password2}"'
    database=yiimpfrontend
    host=localhost
    [myphpadmin]
    user=phpmyadmin
    password='"${AUTOGENERATED_PASS}"'
    [mysql]
    user=panel
    password='"${password}"'
    database=yiimpfrontend
    [admin]
    user=admin
    password='"${adminpasswd}"'
    ' | sudo -E tee "$HOME/.my.cnf" >/dev/null 2>&1
      sudo chmod 0600 "$HOME/.my.cnf"


    # Create keys file
    echo '
    <?php
    /* Sample config file to put in /etc/yiimp/keys.php */
    define('"'"'YIIMP_MYSQLDUMP_USER'"'"', '"'"'panel'"'"');
    define('"'"'YIIMP_MYSQLDUMP_PASS'"'"', '"'"''"${password}"''"'"');
    define('"'"'YIIMP_MYSQLDUMP_PATH'"'"', '"'"''"/var/yiimp/sauv"''"'"');
    /* Keys required to create/cancel orders and access your balances/deposit addresses */

    define('"'"'EXCH_BINANCE_SECRET'"'"', '"'"''"'"');

    define('"'"'EXCH_CEXIO_SECRET'"'"', '"'"''"'"');

    define('"'"'EXCH_HITBTC_SECRET'"'"', '"'"''"'"');

    define('"'"'EXCH_KRAKEN_SECRET'"'"', '"'"''"'"');

    define('"'"'EXCH_KUCOIN_SECRET'"'"', '"'"''"'"');

    define('"'"'EXCH_POLONIEX_SECRET'"'"', '"'"''"'"');

    define('"'"'EXCH_SAFETRADE_SECRET'"'"', '"'"''"'"');

    define('"'"'EXCH_TRADEOGRE_SECRET'"'"', '"'"''"'"');

    define('"'"'EXCH_YOBIT_SECRET'"'"', '"'"''"'"');

    define('"'"'EXCH_NESTEX_SECRET'"'"', '"'"''"'"');
    ' | sudo -E tee /etc/yiimp/keys.php >/dev/null 2>&1
    sudo chown root:www-data /etc/yiimp/keys.php
    sudo chmod 640 /etc/yiimp/keys.php

    echo -e "$GREEN Done...$COL_RESET"


    # Peforming the SQL import
    echo
    echo
    echo -e "$CYAN => Database 'yiimpfrontend' and users 'panel' and 'stratum' created with password $password and $password2, will be saved for you in ~/.my.cnf $COL_RESET"
    echo
    echo -e "Performing the SQL import"
    echo
    sleep 3

    cd "$HOME/yiimp/sql" || displayErr "yiimp/sql was not found after cloning."

    MYSQL=(sudo mysql "--defaults-file=$HOME/.my.cnf" --defaults-group-suffix=host1)

    # Import the newest full database dump
    DUMP_FILE=$(ls -1 *-complete_export.sql.gz 2>/dev/null | sort | tail -n 1)
    if [ -z "$DUMP_FILE" ]; then
        displayErr "No SQL dump (*-complete_export.sql.gz) found in $HOME/yiimp/sql"
    fi
    echo -e "Importing ${DUMP_FILE}..."
    zcat "$DUMP_FILE" | "${MYSQL[@]}"
    echo -e "$GREEN Done...$COL_RESET"

    # Apply every follow-up migration in date order. --force keeps going when a
    # migration is already included in the full dump.
    for sqlfile in $(ls -1 2*.sql 2>/dev/null | sort); do
        echo -e "Applying ${sqlfile}..."
        "${MYSQL[@]}" yiimpfrontend --force < "$sqlfile"
    done
    echo -e "$GREEN Done...$COL_RESET"

    
    # Generating a basic Yiimp serverconfig.php
    echo
    echo
    echo -e "$CYAN => Generating a basic Yiimp serverconfig.php $COL_RESET"
    echo
    sleep 3

    # Make config file
    echo '
    <?php
    ini_set('"'"'date.timezone'"'"', '"'"'UTC'"'"');
    define('"'"'YAAMP_LOGS'"'"', '"'"'/var/log/yiimp'"'"');
    define('"'"'YAAMP_HTDOCS'"'"', '"'"'/var/web'"'"');

    define('"'"'YAAMP_BIN'"'"', '"'"'/var/bin'"'"');

    define('"'"'YAAMP_DBHOST'"'"', '"'"'localhost'"'"');
    define('"'"'YAAMP_DBNAME'"'"', '"'"'yiimpfrontend'"'"');
    define('"'"'YAAMP_DBUSER'"'"', '"'"'panel'"'"');
    define('"'"'YAAMP_DBPASSWORD'"'"', '"'"''"${password}"''"'"');

    define('"'"'YAAMP_PRODUCTION'"'"', true);
    define('"'"'YAAMP_RENTAL'"'"', false);

    define('"'"'YAAMP_LIMIT_ESTIMATE'"'"', false);

    define('"'"'YAAMP_FEES_SOLO'"'"', 5);
    define('"'"'YAAMP_FEES_MINING'"'"', 2);
    
    define('"'"'YAAMP_FEES_EXCHANGE'"'"', 2);
    define('"'"'YAAMP_FEES_RENTING'"'"', 2);
    define('"'"'YAAMP_TXFEE_RENTING_WD'"'"', 0.002);

    define('"'"'YAAMP_PAYMENTS_FREQ'"'"', 3*60*60);
    define('"'"'YAAMP_CLEARS_DELAY'"'"', 5*60);
    define('"'"'YAAMP_PAYMENTS_MINI'"'"', 0.001);

    define('"'"'YAAMP_ALLOW_EXCHANGE'"'"', false);
    define('"'"'YIIMP_PUBLIC_EXPLORER'"'"', true);
    define('"'"'YIIMP_PUBLIC_BENCHMARK'"'"', false);

    define('"'"'YIIMP_FIAT_ALTERNATIVE'"'"', '"'"'USD'"'"'); // USD is main
    define('"'"'YAAMP_USE_NICEHASH_API'"'"', false);

    define('"'"'YAAMP_BTCADDRESS'"'"', '"'"'1C1hnjk3WhuAvUN6Ny6LTxPD3rwSZwapW7'"'"');

    define('"'"'YAAMP_SITE_URL'"'"', '"'"''"${server_name}"''"'"');
    define('"'"'YAAMP_STRATUM_URL'"'"', YAAMP_SITE_URL); // change if your stratum server is on a different host
    define('"'"'YAAMP_SITE_NAME'"'"', '"'"'YIIMP'"'"');
    define('"'"'YAAMP_ADMIN_EMAIL'"'"', '"'"''"${EMAIL}"''"'"');
    define('"'"'YAAMP_ADMIN_IP'"'"', '"'"''"${Public}"''"'"'); // samples: "80.236.118.26,90.234.221.11" or "10.0.0.1/8"
    define('"'"'YAAMP_ADMIN_USER'"'"', '"'"'admin'"'"');
    define('"'"'YAAMP_ADMIN_PASS'"'"', '"'"''"${adminpasswd}"''"'"');

    define('"'"'YAAMP_ADMIN_LOGIN'"'"', true);
    define('"'"'YAAMP_ADMIN_WEBCONSOLE'"'"', true);
    define('"'"'YAAMP_CREATE_NEW_COINS'"'"', false);
    define('"'"'YAAMP_NOTIFY_NEW_COINS'"'"', false);

    define('"'"'YAAMP_DEFAULT_ALGO'"'"', '"'"'all'"'"');

    define('"'"'YAAMP_USE_NGINX'"'"', true);

    // Exchange public keys (private keys are in a separate config file)
    define('"'"'EXCH_BINANCE_KEY'"'"', '"'"''"'"');

    define('"'"'EXCH_EXBITRON_KEY'"'"', '"'"''"'"');

    define('"'"'EXCH_HITBTC_KEY'"'"', '"'"''"'"');

    define('"'"'EXCH_KRAKEN_KEY'"'"', '"'"''"'"');

    define('"'"'EXCH_POLONIEX_KEY'"'"', '"'"''"'"');

    define('"'"'EXCH_SAFETRADE_KEY'"'"', '"'"''"'"');

    define('"'"'EXCH_YOBIT_KEY'"'"', '"'"''"'"');

    define('"'"'EXCH_NESTEX_KEY'"'"', '"'"''"'"');
	
    // Automatic withdraw to Yaamp btc wallet if btc balance > 0.3
    define('"'"'EXCH_AUTO_WITHDRAW'"'"', 0.3);

    // nicehash keys deposit account & amount to deposit at a time
    define('"'"'NICEHASH_API_KEY'"'"','"'"''"'"');
    define('"'"'NICEHASH_API_ID'"'"','"'"''"'"');
    define('"'"'NICEHASH_DEPOSIT'"'"','"'"''"'"');
    define('"'"'NICEHASH_DEPOSIT_AMOUNT'"'"','"'"'0.01'"'"');

    $cold_wallet_table = array(
	'"'"'1PqjApUdjwU9k4v1RDWf6XveARyEXaiGUz'"'"' => 0.10,
    );

    // Sample fixed pool fees
    $configFixedPoolFees = array(
        '"'"'zr5'"'"' => 2.0,
        '"'"'scrypt'"'"' => 2.0,
        '"'"'sha256'"'"' => 2.0,
     );

     // Sample fixed pool fees solo
    $configFixedPoolFeesSolo = array(
        '"'"'zr5'"'"' => 5.0,
        '"'"'scrypt'"'"' => 5.0,
        '"'"'sha256'"'"' => 5.0,

    );

    // Sample custom stratum ports
    $configCustomPorts = array(
    //	'"'"'x11'"'"' => 7000,
    );

    // mBTC Coefs per algo (default is 1.0)
    $configAlgoNormCoef = array(
    //	'"'"'x11'"'"' => 5.0,
    );
    ' | sudo -E tee /var/web/serverconfig.php >/dev/null 2>&1

    echo -e "$GREEN Done...$COL_RESET"


    # Updating stratum config files with database connection info
    echo
    echo
    echo -e "$CYAN => Updating stratum config files with database connection info. $COL_RESET"
    echo
    sleep 3

    cd /var/stratum/config
    sudo sed -i 's/password = tu8tu5/password = '$blckntifypass'/g' *.conf
    sudo sed -i 's/server = yaamp.com/server = '$server_name'/g' *.conf
    sudo sed -i 's/host = yaampdb/host = localhost/g' *.conf
    sudo sed -i 's/database = yaamp/database = yiimpfrontend/g' *.conf
    sudo sed -i 's/username = root/username = stratum/g' *.conf
    sudo sed -i 's/password = patofpaq/password = '$password2'/g' *.conf
    cd ~
    echo -e "$GREEN Done...$COL_RESET"


    # Final Directory permissions
    echo
    echo
    echo -e "$CYAN => Final Directory permissions $COL_RESET"
    echo
    sleep 3

    whoami=$(whoami)
    sudo usermod -aG www-data $whoami

    sudo find /var/web -type d -exec chmod 775 {} +
    sudo find /var/web -type f -exec chmod 664 {} +
    sudo chgrp www-data /var/web -R
    sudo chmod -R g+w /var/web

    sudo mkdir -p /var/log/yiimp
    sudo touch /var/log/yiimp/debug.log
    sudo chgrp www-data /var/log/yiimp -R
    sudo chmod -R 775 /var/log/yiimp

    sudo chgrp www-data /var/stratum -R
    sudo chmod 775 /var/stratum

    sudo mkdir -p /var/yiimp/sauv
    sudo chgrp www-data /var/yiimp -R
    sudo chmod -R 775 /var/yiimp


    #Add to contrab screen-scrypt
    (crontab -l 2>/dev/null; echo "@reboot sleep 20 && /etc/screen-scrypt.sh") | crontab -

    #fix error screen main "service"
    sudo sed -i 's/service $webserver start/sudo service $webserver start/g' /var/web/yaamp/modules/thread/CronjobController.php
    sudo sed -i 's/service nginx stop/sudo service nginx stop/g' /var/web/yaamp/modules/thread/CronjobController.php

    #fix error screen main "backup sql frontend"
    sudo sed -i "s|/root/backup|/var/yiimp/sauv|g" /var/web/yaamp/core/backend/system.php

    #Misc
    sudo mv "$HOME/yiimp/" "$HOME/yiimp-install-only-do-not-run-commands-from-this-folder-$(date +%Y%m%d-%H%M%S)"
    sudo rm -rf /var/log/nginx/*

    #Restart service
    sudo systemctl restart cron.service
    sudo systemctl restart mariadb
    sudo systemctl status mariadb | sed -n "1,3p"
    sudo systemctl restart nginx.service
    sudo systemctl status nginx | sed -n "1,3p"
    sudo systemctl restart php${PHP_VER}-fpm.service
    sudo systemctl status php${PHP_VER}-fpm | sed -n "1,3p"


    echo
    echo -e "$GREEN Done...$COL_RESET"
    sleep 3

    echo
    echo
    echo
    echo -e "$GREEN***************************$COL_RESET"
    echo -e "$GREEN Yiimp Install Script v1.1 $COL_RESET"
    echo -e "$GREEN Finish !!! (Ubuntu ${DISTRO} / PHP ${PHP_VER}) $COL_RESET"
    echo -e "$GREEN***************************$COL_RESET"
    echo
    echo
    echo
    echo -e "$CYAN Whew that was fun, just some reminders. $COL_RESET"
    echo -e "$RED Your mysql information is saved in ~/.my.cnf. $COL_RESET"
    echo
    echo -e "$RED Yiimp at : http://"$server_name" (https... if SSL enabled)"
    echo -e "$RED Yiimp Admin at : http://"$server_name"/admin/login (https... if SSL enabled)"
    echo -e "$RED Yiimp phpMyAdmin at : http://"$server_name"/phpmyadmin (https... if SSL enabled)"
    echo
    echo -e "$RED If you want change 'AdminPanel' to access Panel Admin : Edit this file : /var/web/yaamp/modules/site/SiteController.php"
    echo -e "$RED Line 11 => change 'AdminPanel' and use the new address"
    echo
    echo -e "$CYAN Please make sure to change your public keys / wallet addresses in the /var/web/serverconfig.php file. $COL_RESET"
    echo -e "$CYAN Please make sure to change your private keys in the /etc/yiimp/keys.php file. $COL_RESET"
    echo
    echo -e "$CYAN TUTO Youtube : https://www.youtube.com/watch?v=qE0rhfJ1g2k $COL_RESET"
    echo
    echo -e "$RED***************************************************$COL_RESET"
    echo -e "$RED YOU MUST REBOOT NOW  TO FINALIZE INSTALLATION !!! $COL_RESET"
    echo -e "$RED***************************************************$COL_RESET"
    echo -e "$RED if u have white page blank on site check          $COL_RESET"
    echo -e "$RED php${PHP_VER}-memcache | php${PHP_VER}-memcached | php${PHP_VER}-fpm   $COL_RESET"
    echo -e "$RED try just restart them first...                    $COL_RESET"
    echo -e "$RED***************************************************$COL_RESET"
    echo
