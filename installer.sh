#!/bin/bash

if [ `id -u ` -ne 0 ] ;then
echo "Require Root Login"
exit 0
fi
echo "http://ppa.launchpad.net/ondrej/php5/ubuntu precise main">> /etc/apt/source.list
apt-get update >/dev/null 2>&1 
apt-get --force-yes -y  --fix-missing install php5-fpm >/dev/nulll 2>&1
apt-get --force-yes -y  --fix-missing install mysql-server >/dev/null 2>&1
apt-get --force-yes -y --fix-missing install php5-mysql > /dev/null 2>&1
apt-get --force-yes -y --fix-missing install  nginx-full >/dev/null 2>&1
sed -i 's/cgi.fix_path=0/cgi.fix_path=1/g' /etc/php5/fpm/php.ini
echo "cgi.fix_path=1" >> /etc/php5/fpm/php.ini
sed -i 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php5-fpm.sock/g' /etc/php5/fpm/pool.d/www.conf
echo "listen = /var/run/php5-fpm.sock" >> /etc/php5/fpm/pool.d/www.conf
service php5-fpm restart
echo " Please enter domain name : "
read dm
echo "Please enter IP for given domain name: "
read ip
grep $dm /etc/hosts >/dev/null 2>&1 || echo "$ip $dm">> /etc/hosts

if [ -s /etc/nginx/sites-available/$dm ];then 
echo "site already exists"
exit 0
fi
service mysql restart
touch /etc/nginx/sites-available/$dm
ln -s /etc/nginx/sites-available/$dm /etc/nginx/sites-enabled/$dm
if [ -d /var/www/html/$dm/wordpress ];then
echo "wordpress content already exist"
exit 0
fi
mkdir -p /var/www/html/$dm/wordpress
cat > /tmp/domain-file<<end
server {
	listen $ip:80;


	root /var/www/html/$dm/wordpress/;
	index index.php index.html index.htm;

	
	server_name $dm;

	location / {
		try_files \$uri \$uri/ =404;
	}

	location ~ \.php$ {
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
		fastcgi_pass unix:/var/run/php5-fpm.sock;
		fastcgi_index index.php;
		include fastcgi_params;
	}

}	
end
cat /tmp/domain-file >  /etc/nginx/sites-available/$dm
chown -R www-data.www-data /var/www/html/$dm
rm  /tmp/domain-file
service nginx restart
cd /var/www/html/$dm/
rm latest.tar.gz
wget https://wordpress.org/latest.tar.gz 
tar -xzvf latest.tar.gz
cd -

echo "Enter username for wordpress "
read ur
echo " Enter password for wordpress user $ur"
read ps
echo " Enter password for wordpress database"
read dps
echo "Enter database name for wordpress"
read wps
echo "Enter database user name for wordpress"
read urwps
echo "Enter your email address "
read email
echo "Enter username of mysql server"
read u
echo "Enter password of mysql server"
read p
sed -i 's/example.com/'$dm'/g' wordpress.sql
sed -i 's/mail.example.com/'$dm'/g' wordpress.sql
sed -i 's/login@example.com/login@'$dm'/g' wordpress.sql
sed -i 's/wordpress/'$wps'/g' wordpress.sql
cat > grant.sql<<end
use mysql;
create user '$urwps'@'localhost' identified by '$dps';
grant all on $wps.* to '$urwps'@'localhost';
end
mysql -u $u -p$p < grant.sql 
mysql --host=localhost -u $wps  -p$dps < wordpress.sql
year=`date +%Y`
month=`date +%m`
day=`date +%d`
time=`date +%H:%M:%S`
rm wordpress.sql
cp wordpress.org.sql wordpress.sql
cat > /tmp/wordpress2.sql << wpr1
use $wps;
delete  from wp_users;
insert into wp_users values(1,'$ur',MD5('$ps'),'$ur','$email','','$year-$month-$day $time','',0,'$ur');
wpr1
mysql --host=localhost -u $urwps -p$dps  < /tmp/wordpress2.sql

cat > /tmp/wp-config.php << wpp1
<?php
define('DB_NAME', '$wps');
define('DB_USER', '$urwps');
define('DB_PASSWORD', '$dps');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
wpp1
wget https://api.wordpress.org/secret-key/1.1/salt/
cat index.html >> /tmp/wp-config.php
echo "\$table_prefix  = 'wp_';" >> /tmp/wp-config.php
echo "define('WPLANG', '');" >> /tmp/wp-config.php
echo "define('WP_DEBUG', false);" >> /tmp/wp-config.php
echo "if ( !defined('ABSPATH') )" >> /tmp/wp-config.php
echo "        define('ABSPATH', dirname(__FILE__) . '/');" >> /tmp/wp-config.php
echo " require_once(ABSPATH . 'wp-settings.php');" >> /tmp/wp-config.php

rm index.html

cp /tmp/wp-config.php /var/www/html/$dm/wordpress/.
chown -R www-data.www-data /var/www/html/$dm/wordpress/
rm /tmp/wp-config.php
rm /tmp/wordpress2.sql
rm grant.sql




