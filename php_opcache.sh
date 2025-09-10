#!/bin/bash
# Rocky Linux 9/10 - PHP Opcache安装脚本

color_text() { echo -e " \e[0;$2m$1\e[0m"; }
# red
log_error() { echo $(color_text "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" "31"); }
# green
log_info() { echo $(color_text "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" "32"); }
# yellow
log_warn() { echo $(color_text "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1" "33"); }

# Check if user is root
if [ $(id -u) != "0" ]; then
    log_error 'You must be root to run this script'
    exit 1
fi

PHP_INSTALL_DIR='/usr/local/php'

CURRENT_PHP_VERSION="`${PHP_INSTALL_DIR}/bin/php-config --version`"
ZEND_EXT_DIR="`${PHP_INSTALL_DIR}/bin/php-config --extension-dir`/"

restart_php()
{
    log_info 'Restarting php-fpm......'
    systemctl restart php-fpm
}

install_opcache()
{
    log_info 'Installing zend opcache...'
    
    zend_ext="${ZEND_EXT_DIR}opcache.so"
    if [ ! -s "${zend_ext}" ]; then
        log_error 'OPcache install failed!'
        exit 1
    fi
    
    cat > ${PHP_INSTALL_DIR}/conf.d/004-opcache.ini <<EOF
[Zend Opcache]
zend_extension=opcache
opcache.enable_cli=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1

opcache.jit = 1255
opcache.jit_buffer_size = 64M
EOF
    restart_php
    
    log_info 'Opcache install completed.'
}

uninstall_opcache()
{
    log_warn 'You will uninstall opcache...'
    
    rm -f ${PHP_INSTALL_DIR}/conf.d/004-opcache.ini
    restart_php
    
    log_info 'Uninstall Opcache completed.'
}

action=${1:-'install'}
case "${action}" in
    install) install_opcache ;;
    uninstall) uninstall_opcache ;;
    [eE][xX][iI][tT]) exit 1 ;;
    *) log_error "Usage: $0 {install|uninstall}"; exit 1 ;;
esac