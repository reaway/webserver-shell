#!/bin/bash
# Rocky Linux 9/10 - Nginx安装脚本
# 所有参数可选:
#   -a <install|uninstall> 默认 install
#   -v <版本号> 默认 1.28.0
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

NGINX_VERSION='1.28.0'
NGINX_INSTALL_DIR='/usr/local/nginx'

USER='www'
GROUP='www'

ACTION='install'
INSTALL_TYPE='source'

# 解析参数
while getopts 'a:v:t:h' opt; do
    case "$opt" in
        a) ACTION="$OPTARG" ;;
        v) NGINX_VERSION="$OPTARG" ;;
        t) INSTALL_TYPE="$OPTARG" ;;
        h) log_info "Usage: $0 [-a install|uninstall] [-v <nginx_version>] [-t <source|repository>]"; exit 0 ;;
        *) log_error "Usage: $0 [-a install|uninstall] [-v <nginx_version>] [-t <source|repository>]"; exit 1 ;;
    esac
done

set -e

install_nginx_repository()
{
    # 添加Nginx官方源到系统中
    cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/rhel/$(rpm -E %rhel)/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
    # 安装Nginx
    dnf -y install nginx
}

install_nginx_source()
{
    if [ -d ${NGINX_INSTALL_DIR} ]; then
        log_error 'Nginx已存在, 安装失败'
        exit 1
    fi
    
    log_info "开始安装 Nginx ${NGINX_VERSION} (源码方式)"
    
    yum install -y epel-release
    yum install -y wget tar bzip2
    
    for packages in make gcc gcc-c++ openssl-devel zlib-devel gd-devel;
    do yum -y install $packages; done
    
    if ! id ${USER} &>/dev/null; then
        groupadd ${GROUP}
        useradd -s /sbin/nologin -g ${GROUP} ${USER}
    fi
    
    if [ -s nginx-${NGINX_VERSION}.tar.gz ]; then
        log_info "nginx-${NGINX_VERSION}.tar.gz [found]"
    else
        wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
    fi
    
    tar zxf nginx-${NGINX_VERSION}.tar.gz nginx-${NGINX_VERSION}
    
    cd nginx-${NGINX_VERSION} || exit
    
    ./configure --user=${USER} --group=${GROUP} --prefix=${NGINX_INSTALL_DIR} \
    --with-http_ssl_module --with-http_v2_module --with-http_v3_module \
    --with-http_realip_module \
    --with-http_sub_module --with-http_gzip_static_module --with-http_stub_status_module \
    --with-pcre \
    --with-stream --with-stream_ssl_module \
    --with-http_image_filter_module
    
    make -j$(nproc)
    make install
    
    cd ..
    rm -rf nginx-${NGINX_VERSION}
    
    ln -sf ${NGINX_INSTALL_DIR}/sbin/nginx /usr/bin/nginx
    
  cat > /etc/systemd/system/nginx.service <<EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=${NGINX_INSTALL_DIR}/logs/nginx.pid
ExecStart=${NGINX_INSTALL_DIR}/sbin/nginx -c ${NGINX_INSTALL_DIR}/conf/nginx.conf
ExecReload=${NGINX_INSTALL_DIR}/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=false

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

install_nginx()
{
    if [ "$INSTALL_TYPE" = 'repository' ]; then
        install_nginx_repository
    else
        install_nginx_source
    fi
    
    # 添加防火墙规则
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
    fi
    
    systemctl enable nginx.service
    systemctl start nginx.service
    systemctl status nginx.service
}

uninstall_nginx()
{
    log_warn '开始卸载 Nginx...'
    
    systemctl stop nginx.service
    systemctl disable nginx.service
    if [ "$INSTALL_TYPE" = 'repository' ]; then
        dnf remove -y nginx
    else
        rm -rf /etc/systemd/system/nginx.service
        rm -rf ${NGINX_INSTALL_DIR}
    fi
    systemctl daemon-reload
    
    log_info 'Nginx 已卸载'
}

case "${ACTION}" in
    install) install_nginx ;;
    uninstall) uninstall_nginx ;;
    *) log_error "无效的操作: ${ACTION}，仅支持 install 或 uninstall"; exit 1 ;;
esac