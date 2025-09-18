#!/bin/bash
# Rocky Linux 9/10 - Linux+Nginx+MySQL+PHP安装脚本

NGINX_INSTALL_DIR='/usr/local/nginx'
DEFAULT_WEBSITE_DIR='/home/wwwroot/default'

disable_selinux()
{
    if command -v setenforce &>/dev/null; then
        setenforce 0 || true
    fi
    
    if [ -f /etc/selinux/config ]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    fi
}

create_default_website()
{
    \cp conf/nginx/nginx.conf ${NGINX_INSTALL_DIR}/conf/nginx.conf
    \cp -ra conf/nginx/rewrite ${NGINX_INSTALL_DIR}/conf/
    \cp conf/nginx/pathinfo.conf ${NGINX_INSTALL_DIR}/conf/pathinfo.conf
    \cp conf/nginx/enable-php.conf ${NGINX_INSTALL_DIR}/conf/enable-php.conf
    \cp conf/nginx/enable-php-pathinfo.conf ${NGINX_INSTALL_DIR}/conf/enable-php-pathinfo.conf
    \cp -ra conf/nginx/example ${NGINX_INSTALL_DIR}/conf/example
    
    mkdir ${NGINX_INSTALL_DIR}/conf/vhost
    if [ "${DEFAULT_WEBSITE_DIR}" != "/home/wwwroot/default" ]; then
        sed -i "s#/home/wwwroot/default#${DEFAULT_WEBSITE_DIR}#g" ${NGINX_INSTALL_DIR}/conf/nginx.conf
    fi
    cat >> ${NGINX_INSTALL_DIR}/conf/fastcgi.conf <<EOF
# fastcgi_param PHP_ADMIN_VALUE "open_basedir=\$document_root/:/tmp/:/proc/";
EOF
    
    mkdir -p /home/wwwlogs
    chmod 777 /home/wwwlogs
    
    mkdir -p ${DEFAULT_WEBSITE_DIR}
    chmod +w ${DEFAULT_WEBSITE_DIR}
    chown -R www:www ${DEFAULT_WEBSITE_DIR}
    
    cat > ${DEFAULT_WEBSITE_DIR}/.user.ini <<EOF
open_basedir=${DEFAULT_WEBSITE_DIR}:/tmp/:/proc/
EOF
    chmod 644 ${DEFAULT_WEBSITE_DIR}/.user.ini
    chattr +i ${DEFAULT_WEBSITE_DIR}/.user.ini

    systemctl reload nginx.service
}

install_lnmp()
{
    yum update -y
    disable_selinux
    
    ./php84.sh -a install
    ./php_opcache.sh install
    ./php_composer.sh install
    ./nginx.sh -a install
    ./mysql8.sh -a install
    
    create_default_website
    ./php_phpmyadmin.sh install
}

uninstall_lnmp()
{
    ./php84.sh -a uninstall
    ./php_composer.sh uninstall
    ./nginx.sh -a uninstall
    ./mysql8.sh -a uninstall
    
    ./php_phpmyadmin.sh uninstall
    chattr -i ${DEFAULT_WEBSITE_DIR}/.user.ini
    rm -rf ${DEFAULT_WEBSITE_DIR}
    rm -rf /home/wwwlogs
}

action=${1:-'install'}
case "${action}" in
    install) install_lnmp ;;
    uninstall) uninstall_lnmp ;;
    [eE][xX][iI][tT]) exit 1;;
    *) echo "Usage: $0 {install|uninstall}"; exit 1;;
esac