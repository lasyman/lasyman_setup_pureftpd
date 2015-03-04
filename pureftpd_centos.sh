#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Check if user is root
if [ $(id -u) != "0" ]; then
    printf "Error: You must be root to run this script!\n"
    exit 1
fi
clear
printf "=========================================================================\n"
printf "Pureftpd for Linux for CentOs\n"
printf "=========================================================================\n"
printf "Usage: ./pureftpd.sh \n"
printf "=========================================================================\n"
cur_dir=$(pwd)
yum install httpd mysql-server
bash reset_mysql_root_password.sh

if [ -s /usr/local/mariadb/bin/mysql ]; then
	ismysql="no"
else
	ismysql="yes"
fi
#set mysql root password

	mysqlrootpwd=""
	read -p "Please input your root password of mysql:" mysqlrootpwd
	if [ "$mysqlrootpwd" = "" ]; then
		echo "MySQL root password can't be NULL!"
		exit 1
	else
	echo "==========================="
	echo "Your root password of mysql was:$mysqlrootpwd"
	echo "==========================="
	fi

#set password of User manager

	ftpmanagerpwd=""
	read -p "Please input password of User manager:" ftpmanagerpwd
	if [ "$ftpmanagerpwd" = "" ]; then
		echo "password of User manager can't be NULL!"
		exit 1
	else
	echo "==========================="
	echo "Your password of User manager was:$ftpmanagerpwd"
	echo "==========================="
	fi

#set password of mysql ftp user

	mysqlftppwd=""
	read -p "Please input password of mysql ftp user:" mysqlftppwd
	if [ "$mysqlftppwd" = "" ]; then
		echo "password of User manager can't be NULL!"
		echo "script will randomly generated a password!"
		mysqlftppwd=`cat /dev/urandom | head -1 | md5sum | head -c 8`
	echo "==========================="
	echo "Your password of mysql ftp user was:$mysqlftppwd"
	echo "==========================="
	fi

	get_char()
	{
	SAVEDSTTY=`stty -g`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo
	stty $SAVEDSTTY
	}
	echo ""
	echo "Press any key to start install Pure-FTPd..."
	char=`get_char`


if [ "$ismysql" = "no" ]; then
	\cp /usr/local/mariadb/lib/* /usr/lib/
elif [ "$ismysql" = "yes" ]; then
	mysql_version=`/usr/local/mysql/bin/mysql -V | awk '{print $5}' | tr -d ","`
	if [[ "$mysql_version" =~ "5.1." ]]; then
		\cp /usr/local/mysql/lib/mysql/*.* /usr/lib/
	else
		\cp /usr/local/mysql/lib/* /usr/lib/
	fi
fi

if [ -s /var/lib/mysql/mysql.sock ]; then
rm -f /var/lib/mysql/mysql.sock
fi
mkdir /var/lib/mysql
ln -s /tmp/mysql.sock /var/lib/mysql/mysql.sock

echo "Start install pure-ftpd..."
tar zxvf pure-ftpd-1.0.36.tar.gz
cd pure-ftpd-1.0.36/
if [ "$ismysql" = "no" ]; then
	./configure --prefix=/usr/local/pureftpd CFLAGS=-O2 --with-mysql=/usr/local/mariadb --with-quotas --with-cookie --with-virtualhosts --with-diraliases --with-sysquotas --with-ratios --with-altlog --with-paranoidmsg --with-shadow --with-welcomemsg --with-throttling --with-uploadscript --with-language=english --with-rfc2640
else
	./configure --prefix=/usr/local/pureftpd CFLAGS=-O2 --with-mysql=/usr/local/mysql --with-quotas --with-cookie --with-virtualhosts --with-diraliases --with-sysquotas --with-ratios --with-altlog --with-paranoidmsg --with-shadow --with-welcomemsg --with-throttling --with-uploadscript --with-language=english --with-rfc2640
fi

make && make install

echo "Copy configure files..."
cp configuration-file/pure-config.pl /usr/local/pureftpd/sbin/
chmod 755 /usr/local/pureftpd/sbin/pure-config.pl
cp $cur_dir/conf/pureftpd-mysql.conf /usr/local/pureftpd/
cp $cur_dir/conf/pure-ftpd.conf /usr/local/pureftpd/

echo "Modify parameters of pureftpd configures..."
sed -i 's/127.0.0.1/localhost/g' /usr/local/pureftpd/pureftpd-mysql.conf
sed -i 's/tmppasswd/'$mysqlftppwd'/g' /usr/local/pureftpd/pureftpd-mysql.conf
cp $cur_dir/conf/script.mysql /tmp/script.mysql
sed -i 's/mysqlftppwd/'$mysqlftppwd'/g' /tmp/script.mysql
sed -i 's/ftpmanagerpwd/'$ftpmanagerpwd'/g' /tmp/script.mysql

echo "Import pureftpd database..."
if [ "$ismysql" = "no" ]; then
	/usr/local/mariadb/bin/mysql -u root -p$mysqlrootpwd -h localhost < /tmp/script.mysql
elif [ "$ismysql" = "yes" ]; then
	/usr/local/mysql/bin/mysql -u root -p$mysqlrootpwd -h localhost < /tmp/script.mysql
else
	echo "MySQL or MariaDB NOT FOUND!Please check."
	exit 1
fi

rm -f /tmp/script.mysql

echo "Install GUI User manager for PureFTPd..."
cd $cur_dir
unzip User_manager_for-PureFTPd_v2.1_CN.zip
mv ftp /var/www/
chmod 777 -R /var/www/ftp/
chown www -R /var/www/ftp/

echo "Modify parameters of GUI User manager for PureFTPd..."
sed -i 's/English/Chinese/g' /var/www/ftp/config.php
sed -i 's/tmppasswd/'$mysqlftppwd'/g' /var/www/ftp/config.php
sed -i 's/127.0.0.1/localhost/g' /var/www/ftp/config.php
sed -i 's/myipaddress.com/localhost/g' /var/www/ftp/config.php
mv /var/www/ftp/install.php /var/www/ftp/install.php.bak

cp init.d.pureftpd /etc/init.d/pureftpd
chmod +x /etc/init.d/pureftpd

if [ -s /etc/debian_version ]; then
update-rc.d pureftpd defaults
elif [ -s /etc/redhat-release ]; then
chkconfig --level 345 pureftpd on
fi

if [ -s /sbin/iptables ]; then
/sbin/iptables -I INPUT -p tcp --dport 21 -j ACCEPT
/sbin/iptables -I INPUT -p tcp --dport 20 -j ACCEPT
/sbin/iptables -I INPUT -p tcp --dport 20000:30000 -j ACCEPT
/sbin/iptables-save
fi

clear
printf "=======================================================================\n"
printf "Starting pureftpd...\n"
/etc/init.d/pureftpd start
printf "=======================================================================\n"
printf "Install Pure-FTPd completed,enjoy it!\n"
printf "=======================================================================\n"
