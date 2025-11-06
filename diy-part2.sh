#!/bin/bash

# diy-part2.sh - 修改 OpenWrt 默认 IP 地址


echo "修改默认 IP 地址为 10.0.0.1..."

# 方法1: 修改 package/base-files/files/bin/config_generate
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192\.168\.1\.1/10.0.0.1/g' package/base-files/files/bin/config_generate
    #sed -i 's/192\.168\.\$.1/10.0.$.1/g' package/base-files/files/bin/config_generate
	sed -i 's/192\.168\./10.0./g' package/base-files/files/bin/config_generate
    echo "已修改 config_generate 中的 IP 地址"
fi

