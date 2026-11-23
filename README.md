# Yiimp_install_scrypt v1.1 (update Kudaraidee, 2026)

Site : http://amxpool.com:8282

X Twitter：https://twitter.com/dogmcoin

Discord: https://discord.gg/bYsZGSVf6e

Telegram: https://t.me/DogmcoinEnglish

X Twitter: https://twitter.com/msy2008

Discord: https://discord.gg/3Qq2neb

Telegram: https://t.me/infinitecoin_IFC


msy2008 Yiimp (used in this script for Yiimp Installation): https://github.com/msy2008/yiimp

msy2008 Stratum (Use separately developed stratum): https://github.com/msy2008/stratum-full

msy2008 Yiimp Installer : https://github.com/msy2008/yiimp_install_scrypt

Original Yiimp : https://github.com/tpruvot/yiimp

Original Yiimp Installer : https://github.com/xavatar/yiimp_install_scrypt


***********************************

## Install script for yiimp on Ubuntu Server 22.04 / 24.04 (uses Kudaraidee's Yiimp)

USE THIS SCRIPT ON A FRESH INSTALL OF UBUNTU SERVER 22.04 or 24.04!

| Ubuntu | PHP | Web stack |
|--------|-----|-----------|
| 22.04 LTS | 8.2 | Nginx + MariaDB |
| 24.04 LTS | 8.3 | Nginx + MariaDB |

The PHP version is selected automatically from the OS release. Other Ubuntu
versions (and ARM/32-bit systems) are rejected with an error message.

## Note: Enable root and log in to your Ubuntu system as root!!!

* Connect on your VPS =>

1.Update system and packages
```
apt update
```
```
apt -y upgrade
```
```
reboot
```
2.Add New User
```
adduser pool
```
```
adduser pool sudo
```
3.Switch to new user test and exit
```
su pool
```
```
exit
```
4.Switch to the new user again and install the software
```
su pool
```
```
sudo apt-get -y install build-essential libssl-dev curl git-core openssh-server lsb-release ca-certificates
```
5.Download the Yiimp installation script and install it
```
cd ~
```
```
git clone https://github.com/msy2008/yiimp_install_scrypt.git
```
```
cd yiimp_install_scrypt
```
```
bash install.sh
```
- At the end, you MUST REBOOT to finalize installation...

##  Use separately developed stratum
* Connect on your VPS =>
 
1.Download the Yiimp stratum
```
git clone https://github.com/msy2008/stratum-full.git
```

2.Compile
```
cd stratum-full/iniparser
```
```
make
```
```
cd ..
```
```
make
```

3.Move stratum file 
```
sudo mv stratum /var/stratum/stratum_full
```

4.Run as follows: For example, if you use the scrypt algorithm (copy the scrypt.conf file to the stratum folder)
```
./stratum_full scrypt
```

Finish !
- Go http://xxx.xxx.xxx.xxx or https://xxx.xxx.xxx.xxx (if you have chosen LetsEncrypt SSL). Enjoy !
- Go http://xxx.xxx.xxx.xxx/AdminPanel or https://xxx.xxx.xxx.xxx/AdminPanel to access Panel Admin

If you have an issue during installation (nginx, mariadb... not found), run
`bash install-debug.sh` instead of `bash install.sh`. It runs the same installer
with shell tracing enabled and saves everything to `install-debug.log` in this
directory. The log contains generated passwords - delete it when you are done.

Let's Encrypt SSL is installed with the `certbot` package. Certificates are
skipped automatically if you enter a bare IP address or leave the support
e-mail empty; the HTTP-only nginx configuration is kept in that case.

###### :bangbang: **YOU MUST UPDATE THE FOLLOWING FILES :**

- **/var/web/serverconfig.php :** update this file to include your public ip (line = YAAMP_ADMIN_IP) to access the admin panel (Put your PERSONNAL IP, NOT IP of your VPS). update with public keys from exchanges. update with other information specific to your server..
- **/etc/yiimp/keys.php :** update with secrect keys from the exchanges (not mandatory)
- **If you want change 'AdminPanel' to access Panel Admin :** Edit this file "/var/web/yaamp/modules/site/SiteController.php" and Line 11 => change 'AdminPanel'

###### :bangbang: **IMPORTANT** :

- The configuration of yiimp and coin require a minimum of knowledge in linux & many beers...
- Your mysql information (login/Password) is saved in **~/.my.cnf**

***********************************

###### This script has an interactive beginning and will ask for the following information :

- Server Name (no http:// or www !!!!! Example : crypto.com OR pool.crypto.com OR 80.41.52.63)
- Are you using a subdomain (mypoolx11.crypto.com)
- Enter support email
- Set stratum to AutoExchange
- Your Public IP for admin access (Put your PERSONNAL IP, NOT IP of your VPS)
- Install Fail2ban
- Install UFW and configure ports
- Install LetsEncrypt SSL

***********************************

**This install script will get you 95% ready to go with yiimp. There are a few things you need to do after the main install is finished.**

While I did add some server security to the script, it is every server owners responsibility to fully secure their own servers. After the installation you will still need to customize your serverconfig.php file to your liking, add your API keys, and build/add your coins to the control panel. 

There will be several wallets already in yiimp. These have nothing to do with the installation script and are from the database import from the yiimp github. 
You can clean up before adding your coins : https://bitcointalk.org/index.php?topic=2124257.20
