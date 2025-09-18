#!/bin/bash
# Rocky Linux 9/10 - Composer安装脚本

PHP_INSTALL_DIR='/usr/local/php'

install_composer()
{
    echo 'Composer install, try to from composer official website...'
    curl -sS --connect-timeout 30 -m 60 https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    if [ $? -eq 0 ]; then
        echo 'Composer install successfully.'
    fi
    
    yum install -y unzip
    
    if [ ! -s ${PHP_INSTALL_DIR}/etc/php-cli.ini ] && [ -s ${PHP_INSTALL_DIR}/etc/php.ini ]; then
        cp ${PHP_INSTALL_DIR}/etc/php.ini ${PHP_INSTALL_DIR}/etc/php-cli.ini
        sed -i 's/^disable_functions =.*/disable_functions = /' ${PHP_INSTALL_DIR}/etc/php-cli.ini
    fi
}

uninstall_composer()
{
    rm -rf /usr/local/bin/composer
}

action=${1:-'install'}
case "${action}" in
    install) install_composer ;;
    uninstall) uninstall_composer ;;
    [eE][xX][iI][tT]) exit 1;;
    *) echo "Usage: $0 {install|uninstall}"; exit 1;;
esac