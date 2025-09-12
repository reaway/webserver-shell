#!/bin/bash
#
# Rocky Linux 9/10 - MySQL 8.0/8.4 二进制安装脚本
# 所有参数可选:
#   -a <install|uninstall> 默认 install
#   -v <版本号> 默认 8.4.6
#   -t <binary|source|repository> 默认 binary

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

INSTALL_TYPE='binary'   # 默认二进制安装 binary/source/repository
GLIBC_VERSION='2.28'    # 默认glibc版本

MYSQL_VERSION='8.4.6'
MYSQL_INSTALL_DIR='/usr/local/mysql'
MYSQL_DATA_DIR='/usr/local/mysql/data'

USER='mysql'
GROUP='mysql'

ACTION='install'

# mysql 8.0.43 glibc2.28包下载地址："https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.43-linux-glibc2.28-x86_64.tar.xz"
# mysql 8.0.43 glibc2.17包下载地址："https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.43-linux-glibc2.17-x86_64.tar.xz"
# mysql 8.4.6 glibc2.28包下载地址："https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.6-linux-glibc2.28-x86_64.tar.xz"
# mysql 8.4.6 glibc2.17包下载地址："https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.6-linux-glibc2.17-x86_64.tar.xz"

# 解析参数
while getopts 'a:v:t:h' opt; do
    case "$opt" in
        a) ACTION="$OPTARG" ;;
        v) MYSQL_VERSION="$OPTARG" ;;
        t) INSTALL_TYPE="$OPTARG" ;;
        h) log_info "Usage: $0 [-a install|uninstall] [-v <mysql_version>] [-t <binary|source|repository>]"; exit 0 ;;
        *) log_error "Usage: $0 [-a install|uninstall] [-v <mysql_version>] [-t <binary|source|repository>]"; exit 1 ;;
    esac
done

set -e

disable_selinux()
{
    if command -v setenforce &>/dev/null; then
        setenforce 0 || true
    fi
    
    if [ -f /etc/selinux/config ]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    fi
}

set_my_cnf()
{
    cat > /etc/my.cnf <<EOF
[client]
#password=your_password
port=3306
socket=/tmp/mysql.sock

[mysqld]
port=3306
basedir=${MYSQL_INSTALL_DIR}
datadir=${MYSQL_DATA_DIR}
socket=/tmp/mysql.sock
log-error=${MYSQL_DATA_DIR}/mysql.log
pid-file=${MYSQL_DATA_DIR}/mysql.pid

skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_cache_size = 8
tmp_table_size = 16M
performance_schema_max_table_instances = 500
explicit_defaults_for_timestamp = true

#skip-networking
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin=mysql-bin
binlog_expire_logs_seconds=864000
server-id=1
early-plugin-load=""

default_storage_engine = InnoDB
innodb_file_per_table = 1
innodb_data_home_dir = ${MYSQL_DATA_DIR}
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = ${MYSQL_DATA_DIR}
innodb_buffer_pool_size = 16M
innodb_log_file_size = 5M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

sql_mode=""
[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash
EOF
    
    MemTotal=`free -m | grep Mem | awk '{print  $2}'`
    if [[ ${MemTotal} -gt 1024 && ${MemTotal} -lt 2048 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 32M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 128#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 768K#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 768K#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 16#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 16M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 32M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 128M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 32M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 1000#" /etc/my.cnf
        elif [[ ${MemTotal} -ge 2048 && ${MemTotal} -lt 4096 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 64M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 256#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 1M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 1M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 32#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 32M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 64M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 256M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 64M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 2000#" /etc/my.cnf
        elif [[ ${MemTotal} -ge 4096 && ${MemTotal} -lt 8192 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 128M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 512#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 2M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 2M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 32M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 64#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 64M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 64M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 512M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 128M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 4000#" /etc/my.cnf
        elif [[ ${MemTotal} -ge 8192 && ${MemTotal} -lt 16384 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 256M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 1024#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 4M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 4M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 64M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 128#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 128M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 128M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 1024M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 256M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 6000#" /etc/my.cnf
        elif [[ ${MemTotal} -ge 16384 && ${MemTotal} -lt 32768 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 512M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 2048#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 128M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 256#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 256M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 256M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 2048M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 512M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 8000#" /etc/my.cnf
        elif [[ ${MemTotal} -ge 32768 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 1024M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 4096#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 256M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 512#" /etc/my.cnf
        sed -i "s#^query_cache_size.*#query_cache_size = 512M#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 512M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 4096M#" /etc/my.cnf
        sed -i "s#^innodb_log_file_size.*#innodb_log_file_size = 1024M#" /etc/my.cnf
        sed -i "s#^performance_schema_max_table_instances.*#performance_schema_max_table_instances = 10000#" /etc/my.cnf
    fi
}

init_data_dir()
{
    if [ ! -d ${MYSQL_DATA_DIR} ]; then
        mkdir -p ${MYSQL_DATA_DIR}
    fi
    chown -R ${USER}:${GROUP} ${MYSQL_DATA_DIR}
    ${MYSQL_INSTALL_DIR}/bin/mysqld --initialize-insecure --basedir=${MYSQL_INSTALL_DIR} --datadir=${MYSQL_DATA_DIR} --user=${USER}
}

set_auto_start()
{
    # 现代Systemd服务管理
    cat > /etc/systemd/system/mysqld.service <<EOF
[Unit]
Description=MySQL Server
Documentation=man:mysqld(8)
Documentation=http://dev.mysql.com/doc/refman/en/using-systemd.html
After=network.target
After=syslog.target

[Service]
User=mysql
Group=mysql

# Have mysqld write its state to the systemd notify socket
Type=notify

# Disable service start and stop timeout logic of systemd for mysqld service.
TimeoutSec=0

# Start main service
ExecStart=${MYSQL_INSTALL_DIR}/bin/mysqld --defaults-file=/etc/my.cnf \$MYSQLD_OPTS

# Use this to switch malloc implementation
EnvironmentFile=-/etc/sysconfig/mysql

# Sets open_files_limit
LimitNOFILE = 10000

Restart=on-failure

RestartPreventExitStatus=1

# Set environment variable MYSQLD_PARENT_PID. This is required for restart.
Environment=MYSQLD_PARENT_PID=1

PrivateTmp=false

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable mysqld.service
    systemctl start mysqld.service
}

reset_root_password()
{
    mysqlpwd=`tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c 16`
    ${MYSQL_INSTALL_DIR}/bin/mysqladmin -u root password "${mysqlpwd}"
    log_info "============================================================================================"
    log_info ">>> MySQL ${MYSQL_VERSION} 安装完成!"
    log_info ">>> systemd管理: systemctl {start|stop|reload} mysqld"
    log_info ">>> 初始 root 密码: ${mysqlpwd}"
}

install_mysql_8_yum_repository()
{
    # 添加MySQL源
    wget https://dev.mysql.com/get/mysql84-community-release-el$(rpm -E %rhel)-2.noarch.rpm
    yum localinstall -y mysql84-community-release-el$(rpm -E %rhel)-2.noarch.rpm
    
    # 安装MySQL
    yum install -y mysql-community-server
    
    # 启动MySQL
    systemctl start mysqld
    systemctl status mysqld
    
    # 获取临时密码
    if grep -q 'temporary password' /var/log/mysqld.log; then
        TEMP_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
        log_info "临时root密码: $TEMP_PASSWORD (请立即修改)$"
    else
        log_error "未能获取临时密码，请检查日志文件: /var/log/mysqld.log$"
    fi
}

install_mysql_8_binary()
{
    log_info "开始安装 MySQL ${MYSQL_VERSION} (二进制方式)"
    
    yum install -y libaio
    
    # 检查glibc版本
    CURRENT_GLIBC=$(ldd --version | head -n1 | awk '{print $NF}')
    if [ "$(printf '%s\n' "$GLIBC_VERSION" "$CURRENT_GLIBC" | sort -V | head -n1)" != "$GLIBC_VERSION" ]; then
        log_error "系统glibc版本($CURRENT_GLIBC)低于要求($GLIBC_VERSION)"
        exit 1
    fi
    
    # 下载包
    if [ -s mysql-${MYSQL_VERSION}-linux-glibc${GLIBC_VERSION}-x86_64.tar.xz ]; then
        log_info "mysql-${MYSQL_VERSION}-linux-glibc${GLIBC_VERSION}-x86_64.tar.xz [found]"
    else
        wget https://cdn.mysql.com/Downloads/MySQL-${MYSQL_VERSION%.*}/mysql-${MYSQL_VERSION}-linux-glibc${GLIBC_VERSION}-x86_64.tar.xz || {
            log_error "下载MySQL失败"
            exit 1
        }
    fi
    
    tar Jxf mysql-${MYSQL_VERSION}-linux-glibc${GLIBC_VERSION}-x86_64.tar.xz mysql-${MYSQL_VERSION}-linux-glibc${GLIBC_VERSION}-x86_64
    mv mysql-${MYSQL_VERSION}-linux-glibc${GLIBC_VERSION}-x86_64 ${MYSQL_INSTALL_DIR}
    chown -R ${USER}:${GROUP} ${MYSQL_INSTALL_DIR}
}

install_mysql_8_source()
{
    log_info "开始安装 MySQL ${MYSQL_VERSION} (源码方式)"
    
    yum install -y cmake gcc gcc-c++
    yum install -y openssl-devel ncurses-devel rpcgen
    dnf install -y --enablerepo=crb libtirpc-devel
    yum install -y boost-devel bison
    
    # 下载包
    if [ -s mysql-${MYSQL_VERSION}.tar.gz ]; then
        log_info "mysql-${MYSQL_VERSION}.tar.gz [found]"
    else
        wget https://cdn.mysql.com/Downloads/MySQL-${MYSQL_VERSION%.*}/mysql-${MYSQL_VERSION}.tar.gz || {
            log_error "下载MySQL失败"
            exit 1
        }
    fi
    
    tar zxf mysql-${MYSQL_VERSION}.tar.gz mysql-${MYSQL_VERSION}
    cd mysql-${MYSQL_VERSION}
    
    mkdir build && cd build
    
    # 编译选项：https://dev.mysql.com/doc/refman/8.4/en/source-configuration-options.html
    cmake .. \
    -DCMAKE_INSTALL_PREFIX=${MYSQL_INSTALL_DIR} \
    -DSYSCONFDIR=/etc \
    -DWITH_MYISAM_STORAGE_ENGINE=1 \
    -DWITH_INNOBASE_STORAGE_ENGINE=1 \
    -DWITH_PARTITION_STORAGE_ENGINE=1 \
    -DWITH_FEDERATED_STORAGE_ENGINE=1 \
    -DEXTRA_CHARSETS=all \
    -DDEFAULT_CHARSET=utf8mb4 \
    -DDEFAULT_COLLATION=utf8mb4_general_ci \
    -DWITH_EMBEDDED_SERVER=1 \
    -DENABLED_LOCAL_INFILE=1
    
    make -j$(nproc)
    make install
}

install_mysql()
{
    if [ "$INSTALL_TYPE" = 'repository' ]; then
        install_mysql_8_yum_repository
        exit 0
    fi
    
    if [ -d ${MYSQL_INSTALL_DIR} ]; then
        log_error "MYSQL已存在，安装失败"
        exit 1
    fi
    
    yum remove -y mysql-server mysql mysql-libs mariadb-server mariadb mariadb-libs
    
    yum install -y wget tar
    
    if ! id ${USER} &>/dev/null; then
        groupadd ${GROUP}
        useradd -s /sbin/nologin -M -g ${GROUP} ${USER}
    fi
    
    if [ "$INSTALL_TYPE" = "source" ]; then
        install_mysql_8_source
    else
        install_mysql_8_binary
    fi
    
    # 添加环境变量
    echo "PATH=${MYSQL_INSTALL_DIR}/bin/:\$PATH" > /etc/profile.d/mysql.sh
    . /etc/profile.d/mysql.sh
    
    init_data_dir
    set_my_cnf
    
    disable_selinux
    set_auto_start
    reset_root_password
}

uninstall_mysql()
{
    log_warn '开始卸载 MySQL'
    
    if [ "$INSTALL_TYPE" = 'repository' ]; then
        systemctl stop mysqld 2>/dev/null || true
        yum remove -y mysql-community-server
        exit 0
    fi
    
    if command -v systemctl &>/dev/null; then
        systemctl stop mysql.service
        systemctl disable mysql.service
        rm -rf /etc/systemd/system/mysql.service
        systemctl daemon-reload
    else
        service mysql stop
        chkconfig mysql off
        chkconfig --del mysql
    fi
    
    rm -rf ${MYSQL_INSTALL_DIR}
    
    rm -rf /etc/my.cnf
    rm -rf /etc/init.d/mysql
    rm -f /etc/profile.d/mysql.sh
    
    log_info 'MySQL 已卸载'
}

case "${ACTION}" in
    install) install_mysql ;;
    uninstall) uninstall_mysql ;;
    *) log_error "无效的操作: ${ACTION}，仅支持 install 或 uninstall"; exit 1 ;;
esac