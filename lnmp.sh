#!/bin/bash
# Rocky Linux 9/10 - Linux+Nginx+MySQL+PHP安装脚本

NGINX_INSTALL_DIR='/usr/local/nginx'
DEFAULT_WEBSITE_DIR='/home/wwwroot/default'

install_lnmp()
{
    yum update -y
    
    ./php84.sh -a install
    ./php_opcache.sh install
    ./php_composer.sh install
    ./nginx.sh -a install
    ./mysql8.sh -a install
    
    \cp conf/nginx/nginx.conf ${NGINX_INSTALL_DIR}/conf/nginx.conf
    \cp -ra conf/nginx/rewrite ${NGINX_INSTALL_DIR}/conf/
    \cp conf/nginx/pathinfo.conf ${NGINX_INSTALL_DIR}/conf/pathinfo.conf
    \cp conf/nginx/enable-php.conf ${NGINX_INSTALL_DIR}/conf/enable-php.conf
    \cp conf/nginx/enable-php-pathinfo.conf ${NGINX_INSTALL_DIR}/conf/enable-php-pathinfo.conf
    \cp -ra conf/nginx/example ${NGINX_INSTALL_DIR}/conf/example
    
    mkdir -p ${DEFAULT_WEBSITE_DIR}
    chmod +w ${DEFAULT_WEBSITE_DIR}
    mkdir -p /home/wwwlogs
    chmod 777 /home/wwwlogs
    chown -R www:www ${DEFAULT_WEBSITE_DIR}
    
    mkdir ${NGINX_INSTALL_DIR}/conf/vhost
    
    if [ "${DEFAULT_WEBSITE_DIR}" != "/home/wwwroot/default" ]; then
        sed -i "s#/home/wwwroot/default#${DEFAULT_WEBSITE_DIR}#g" ${NGINX_INSTALL_DIR}/conf/nginx.conf
    fi
    
    cat > ${DEFAULT_WEBSITE_DIR}/.user.ini <<EOF
open_basedir=${DEFAULT_WEBSITE_DIR}:/tmp/:/proc/
EOF
    chmod 644 ${DEFAULT_WEBSITE_DIR}/.user.ini
    chattr +i ${DEFAULT_WEBSITE_DIR}/.user.ini
        cat >> ${NGINX_INSTALL_DIR}/conf/fastcgi.conf <<EOF
# fastcgi_param PHP_ADMIN_VALUE "open_basedir=\$document_root/:/tmp/:/proc/";
EOF
    
    ./php_phpmyadmin.sh install
    
    systemctl reload nginx.service
}

uninstall_lnmp()
{   
    ./php84.sh -a uninstall
    ./php_composer.sh uninstall
    ./nginx.sh -a uninstall
    ./mysql8.sh -a uninstall
    
    ./php_phpmyadmin.sh uninstall
}

action=${1:-'install'}
case "${action}" in
    install) install_lnmp ;;
    uninstall) uninstall_lnmp ;;
    [eE][xX][iI][tT]) exit 1;;
    *) echo "Usage: $0 {install|uninstall}"; exit 1;;
esac