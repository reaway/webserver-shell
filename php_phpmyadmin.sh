#!/bin/bash
# Rocky Linux 9/10 - phpMyAdmin安装脚本

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

INSTALL_DIR='/home/wwwroot/default'
PHPMYADMIN_VERSION='5.2.2'

install_phpmyadmin()
{
    log_info 'Install phpMyAdmin...'
    
    [[ -d ${INSTALL_DIR}/phpmyadmin ]] && rm -rf ${INSTALL_DIR}/phpmyadmin
    
    # 下载包
    if [ -s phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.xz ]; then
        log_info "phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.xz [found]"
    else
        wget https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.xz || {
            log_error '下载phpMyAdmin失败'
            exit 1
        }
    fi
    
    tar Jxf phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.xz
    mv phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages ${INSTALL_DIR}/phpmyadmin
    
    \cp ${INSTALL_DIR}/phpmyadmin/config.sample.inc.php ${INSTALL_DIR}/phpmyadmin/config.inc.php
    sed -i "s/^\$cfg\['UploadDir'\] = '';/\$cfg['UploadDir'] = 'upload';/" ${INSTALL_DIR}/phpmyadmin/config.inc.php
    sed -i "s/^\$cfg\['SaveDir'\] = '';/\$cfg['SaveDir'] = 'save';/" ${INSTALL_DIR}/phpmyadmin/config.inc.php
    secret=`tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c 32`
    sed -i "s/^\$cfg\['blowfish_secret'\] = '';/\$cfg['blowfish_secret'] = '${secret}';/" ${INSTALL_DIR}/phpmyadmin/config.inc.php
    mkdir ${INSTALL_DIR}/phpmyadmin/{tmp,upload,save}
    chown www:www -R ${INSTALL_DIR}/phpmyadmin/{tmp,upload,save}
    
    log_info 'phpMyAdmin install completed.'
}

uninstall_phpmyadmin()
{
    log_warn 'You will uninstall phpMyAdmin...'
    rm -rf ${INSTALL_DIR}/phpmyadmin
}

action=${1:-'install'}
case "${action}" in
    install) install_phpmyadmin ;;
    uninstall) uninstall_phpmyadmin ;;
    [eE][xX][iI][tT]) exit 1 ;;
    *) log_error "Usage: $0 {install|uninstall}"; exit 1 ;;
esac