#!/bin/bash
# Rocky Linux 9/10 - PHP8.4安装脚本
# 所有参数可选:
#   -a <install|uninstall> 默认 install
#   -v <版本号> 默认 8.4.12
#   -t <source|repository> 默认 source

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

PHP_VERSION='8.4.12'
PHP_INSTALL_DIR='/usr/local/php'

USER='www'
GROUP='www'

ACTION='install'
INSTALL_TYPE='source'

# 解析参数
while getopts 'a:v:t:h' opt; do
    case "$opt" in
        a) ACTION="$OPTARG" ;;
        v) PHP_VERSION="$OPTARG" ;;
        t) INSTALL_TYPE="$OPTARG" ;;
        h) log_info "Usage: $0 [-a install|uninstall] [-v <php_version>] [-t <source|repository>]"; exit 0 ;;
        *) log_error "Usage: $0 [-a install|uninstall] [-v <php_version>] [-t <source|repository>]"; exit 1 ;;
    esac
done

set -e

create_php_fpm_conf()
{
    if ! id ${USER} &>/dev/null; then
        groupadd ${GROUP}
        useradd -s /sbin/nologin -g ${GROUP} ${USER}
    fi
    
    PHP_PM_TYPE='dynamic'
    MemTotal=`free -m | grep Mem | awk '{print  $2}'`
    if [ "${MemTotal}" ];then
        if [ "${MemTotal}" -le 2200 ];then
            PHP_PM_TYPE='ondemand'
        fi
    fi
    
    log_info 'Creating new php-fpm configure file...'
  cat > ${PHP_INSTALL_DIR}/etc/php-fpm.conf <<EOF
[global]
pid = ${PHP_INSTALL_DIR}/var/run/php-fpm.pid
error_log = ${PHP_INSTALL_DIR}/var/log/php-fpm.log
log_level = notice

[www]
prefix = ${PHP_INSTALL_DIR}

user = ${USER}
group = ${GROUP}

listen = /tmp/php-cgi.sock
listen.backlog = -1
listen.owner = ${USER}
listen.group = ${GROUP}
listen.mode = 0660
listen.allowed_clients = 127.0.0.1

pm = ${PHP_PM_TYPE}
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
pm.process_idle_timeout = 10s
pm.max_requests = 1024

slowlog = var/log/slow.log
request_slowlog_timeout = 3
request_terminate_timeout = 100
EOF
}

set_php_fpm_conf()
{
    MemTotal=`free -m | grep Mem | awk '{print  $2}'`
    if [[ ${MemTotal} -gt 1024 && ${MemTotal} -le 2048 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 30#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 5#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 5#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 10#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        elif [[ ${MemTotal} -gt 2048 && ${MemTotal} -le 4096 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 50#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 5#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 5#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 20#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        elif [[ ${MemTotal} -gt 4096 && ${MemTotal} -le 8192 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 100#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 10#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 10#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 30#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        elif [[ ${MemTotal} -gt 8192 && ${MemTotal} -le 16384 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 150#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 15#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 15#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 30#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        elif [[ ${MemTotal} -gt 16384 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 300#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 20#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 20#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 50#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
    fi
    #backLogValue=$(cat ${PHP_INSTALL_DIR}/etc/php-fpm.conf |grep max_children|awk '{print $3*1.5}')
    #sed -i "s#listen.backlog.*#listen.backlog = "${backLogValue}"#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
    sed -i "s#listen.backlog.*#listen.backlog = 8192#" ${PHP_INSTALL_DIR}/etc/php-fpm.conf
}

php_fpm_service_add()
{
    log_info 'Copy php-fpm init.d file...'
    
    # 现代Systemd服务管理：
    # cp sapi/fpm/php-fpm.service /etc/systemd/system/php-fpm.service
      cat > /etc/systemd/system/php-fpm.service <<EOF
[Unit]
Description=The PHP FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=${PHP_INSTALL_DIR}/var/run/php-fpm.pid
ExecStart=${PHP_INSTALL_DIR}/sbin/php-fpm --nodaemonize --fpm-config ${PHP_INSTALL_DIR}/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=false

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

set_php_ini()
{
    log_info 'Modify php.ini......'
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${PHP_INSTALL_DIR}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${PHP_INSTALL_DIR}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${PHP_INSTALL_DIR}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${PHP_INSTALL_DIR}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' ${PHP_INSTALL_DIR}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${PHP_INSTALL_DIR}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = exec,system,passthru,shell_exec,proc_open,pcntl_exec/g' ${PHP_INSTALL_DIR}/etc/php.ini
    sed -i 's/expose_php = On/expose_php = Off/g' ${PHP_INSTALL_DIR}/etc/php.ini
    sed -i 's/;sendmail_path =.*/sendmail_path = \/usr\/sbin\/sendmail -t -i/g' ${PHP_INSTALL_DIR}/etc/php.ini
}

ln_php_bin()
{
    ln -sf ${PHP_INSTALL_DIR}/bin/php /usr/bin/php
    ln -sf ${PHP_INSTALL_DIR}/bin/phpize /usr/bin/phpize
    ln -sf ${PHP_INSTALL_DIR}/bin/pear /usr/bin/pear
    ln -sf ${PHP_INSTALL_DIR}/bin/pecl /usr/bin/pecl
    ln -sf ${PHP_INSTALL_DIR}/sbin/php-fpm /usr/bin/php-fpm
}

Set_Pear_Pecl()
{
    pear config-set php_ini ${PHP_INSTALL_DIR}/etc/php.ini
    pecl config-set php_ini ${PHP_INSTALL_DIR}/etc/php.ini
}

install_php_84_repository()
{
    log_info "开始安装 PHP ${PHP_VERSION} (Remi's RPM repository)"
    
    dnf install -y epel-release
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm
    dnf module reset php -y
    dnf module enable php:remi-8.4 -y
    dnf install -y php php-mysqlnd php-gd php-bcmath php-intl php-zip php-posix
}

install_php_84_source()
{
    if [ -d ${PHP_INSTALL_DIR} ]; then
        log_error 'PHP已存在, 安装失败'
        exit 1
    fi
    
    log_info "开始安装 PHP ${PHP_VERSION} (源码方式)"
    
    yum -y install epel-release
    yum install -y wget tar bzip2
    yum install -y make gcc gcc-c++ \
    libxml2-devel \
    sqlite-devel \
    openssl-devel \
    bzip2-devel \
    libcurl-devel \
    libpng libpng-devel libjpeg-devel libavif-devel freetype-devel libwebp-devel libXpm-devel \
    libsodium-devel \
    readline-devel \
    libxslt-devel
    
    dnf --enablerepo=crb install -y oniguruma-devel libzip-devel
    
    #
    if [ -s php-${PHP_VERSION}.tar.bz2 ]; then
        log_info "php-${PHP_VERSION}.tar.bz2 [found]"
    else
        wget https://www.php.net/distributions/php-${PHP_VERSION}.tar.bz2
    fi
    tar jxf php-${PHP_VERSION}.tar.bz2 php-${PHP_VERSION}
    
    cd php-${PHP_VERSION} || exit
    
    ./configure --prefix=${PHP_INSTALL_DIR} --with-config-file-path=${PHP_INSTALL_DIR}/etc --with-config-file-scan-dir=${PHP_INSTALL_DIR}/conf.d \
    --enable-fpm --with-fpm-user=${USER} --with-fpm-group=${GROUP} \
    --enable-mysqlnd --with-mysqli --with-pdo-mysql \
    --with-zlib --with-bz2 --with-zip \
    --enable-gd --with-avif --with-webp --with-jpeg --with-xpm --with-freetype \
    --with-openssl --with-openssl-legacy-provider --with-openssl-argon2 \
    --with-sodium \
    --enable-bcmath \
    --enable-mbstring \
    --with-curl --enable-sockets \
    --enable-intl \
    --enable-pcntl \
    --with-readline \
    --enable-calendar \
    --enable-sysvsem --enable-sysvshm \
    --enable-shmop \
    --enable-soap \
    --with-gettext \
    --with-xsl \
    --with-pear
    
    make -j$(nproc)
    make install
    
    log_info 'Copy new php configure file...'
    mkdir -p /usr/local/php/conf.d
    cp php.ini-production ${PHP_INSTALL_DIR}/etc/php.ini
}

install_php()
{
    if [ "$INSTALL_TYPE" = 'repository' ]; then
        install_php_84_repository
    else
        install_php_84_source
        
        set_php_ini
        ln_php_bin
        Set_Pear_Pecl
        
        create_php_fpm_conf
        set_php_fpm_conf
        php_fpm_service_add
        
        cd ..
        rm -rf php-${PHP_VERSION}
    fi
    systemctl enable php-fpm.service
    systemctl start php-fpm.service
    systemctl status php-fpm.service
}

uninstall_php()
{
    log_warn '开始卸载 PHP...'

    systemctl stop php-fpm.service
    systemctl disable php-fpm.service
    if [ "$INSTALL_TYPE" = 'repository' ]; then
        dnf remove -y php php-mysqlnd php-gd php-bcmath php-intl php-zip php-posix
    else
        rm -rf /etc/systemd/system/php-fpm.service        
        rm -rf ${PHP_INSTALL_DIR}
    fi
    systemctl daemon-reload

    log_info 'PHP 已卸载'
}

case "${ACTION}" in
    install) install_php ;;
    uninstall) uninstall_php ;;
    *) log_error "无效的操作: ${ACTION}，仅支持 install 或 uninstall"; exit 1 ;;
esac