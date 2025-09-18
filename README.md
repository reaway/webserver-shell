# LNMP 一键安装包

## 介绍

Rocky Linux 9/10 - Linux+Nginx+MySQL+PHP安装脚本

## 下载源码

```bash
git clone https://github.com/reaway/webserver-shell.git
cd webserver-shell
```

## 安装

### LNMP 一键安装

```bash
./lnmp.sh install
```

### LNMP 一键卸载

```bash
./lnmp.sh uninstall
```

### 单独安装

### PHP8.4

```bash
./php84.sh
# 所有参数可选:
#   -a <install|uninstall> 默认 install
#   -v <版本号> 默认 8.4.12
#   -t <source|repository> 默认 source
```

- 参数: a 安装/卸载，默认 安装
- 参数: v 版本号，默认 8.4.12
- 参数: t 源码/仓库安装，默认 源码安装

### Nginx

```bash
./nginx.sh
# 所有参数可选:
#   -a <install|uninstall> 默认 install
#   -v <版本号> 默认 1.28.0
#   -t <source|repository> 默认 source
```

- 参数: a 安装/卸载，默认 安装
- 参数: v 版本号，默认 1.28.0
- 参数: t 源码/仓库安装，默认 源码安装

### MySQL8.0/8.4

```bash
./mysql8.sh
# 所有参数可选:
#   -a <install|uninstall> 默认 install
#   -v <版本号> 默认 8.4.6
#   -t <binary|source|repository> 默认 binary
```

- 参数: a 安装/卸载，默认 安装
- 参数: v 版本号，默认 8.4.6
- 参数: t 二进制/源码/仓库安装，默认 二进制安装

## 状态管理

- PHP-FPM 状态管理：`systemctl {start|stop|reload} php-fpm`
- Nginx 状态管理：`systemctl {start|stop|reload} nginx`
- MySQL 状态管理：`systemctl {start|stop|reload} mysqld`
