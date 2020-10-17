#!/bin/bash
#=============================================================
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#=============================================================

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default
sed -i '$a src-git vmtools https://github.com/srchack/custom-packages' feeds.conf.default
git clone https://github.com/srchack/custom-packages package/custom-packages
git clone https://github.com/jerrykuku/luci-app-vssr package/vssr
git clone https://github.com/jerrykuku/lua-maxminddb package/lean/lua-maxminddb
git clone https://github.com/tty228/luci-app-serverchan package/luci-app-serverchan
git clone https://github.com/kenzok8/openwrt-packages package/openwrt-packages
git clone https://github.com/fw876/helloworld package/helloworld
rm -rf package/lean/luci-theme-argon
git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
#svn co https://github.com/Lienol/openwrt-package/trunk/lienol/luci-app-passwall package/luci-app-passwall
#svn co https://github.com/kenzok8/small/trunk/brook package/brook
#svn co https://github.com/kenzok8/small/trunk/chinadns-ng package/chinadns-ng
#svn co https://github.com/kenzok8/small/trunk/simple-obfs package/simple-obfs
#svn co https://github.com/kenzok8/small/trunk/tcping package/tcping
#rm -rf package/openwrt-packages/luci-app-passwall
