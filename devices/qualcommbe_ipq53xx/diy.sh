#!/bin/bash

shopt -s extglob

rm -rf target/linux/generic target/linux/qualcommbe package/kernel package/firmware package/boot

git_clone_path main https://github.com/openwrt/openwrt package/kernel

rm -rf package/kernel/mac80211
git_clone_path master https://github.com/coolsnowwolf/lede  target/linux/generic target/linux/qualcommbe package/boot package/firmware package/kernel/mac80211 package/kernel/rtl837x
rm package/kernel/mac80211/patches-qualcommbe/build/160-backports-sockaddr_unsized-is-in-6.18.57.patch

wget -N https://github.com/coolsnowwolf/lede/raw/refs/heads/master/include/kernel-6.18 -P target/linux/generic/

wget -N https://github.com/openwrt/openwrt/raw/refs/heads/main/include/kernel.mk -P include/

wget -N https://github.com/openwrt/openwrt/raw/refs/heads/main/include/netfilter.mk -P include/

rm -rf package/feeds/kiddin9/{quectel_QMI_WWAN,simcom_QMI_WWAN,fibocom_QMI_WWAN,quectel_MHI,rkp-ipid} package/feeds/packages/{v4l2loopback,libpfring,xtables-addons}
# Ensure luci-app-honk is present
if [ ! -d package/feeds/kiddin9/luci-app-honk ] && [ ! -d package/luci-app-honk ]; then
  git clone --depth=1 https://github.com/QiuSimons/luci-app-honk.git package/luci-app-honk
fi

# LAN 192.168.0.1/24 (DHCP on), WAN PPPoE, disable Honk autostart
sed -i "s/10.0.0/192.168.0/g" package/base-files/files/bin/config_generate
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-be6500-custom
#!/bin/sh
uci set network.lan.ipaddr='192.168.0.1'
uci set network.lan.netmask='255.255.255.0'
uci set dhcp.lan.ignore='0'
uci set network.wan.proto='pppoe'
uci commit network
uci commit dhcp
if [ -x /etc/init.d/honk ]; then
  /etc/init.d/honk disable
fi
if uci -q get honk.config >/dev/null 2>&1; then
  uci set honk.config.enabled='0'
  uci commit honk
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-be6500-custom

# Trim kernel 6.18 config for FIT <= 7168k while keeping BTF intact
KCONF="target/linux/qualcommbe/config-6.18"
if [ -f "$KCONF" ]; then
  for sym in CONFIG_IO_URING CONFIG_FTRACE CONFIG_FUNCTION_TRACER CONFIG_TRACING CONFIG_MTD_SPI_NOR CONFIG_MTD_NAND CONFIG_MTD_UBI CONFIG_UBIFS_FS; do
    sed -i "/^${sym}=/d" "$KCONF"
    sed -i "/^# ${sym} is not set/d" "$KCONF"
    echo "# ${sym} is not set" >> "$KCONF"
  done
  sed -i "/^CONFIG_DEBUG_INFO_BTF/d" "$KCONF"
  echo "CONFIG_DEBUG_INFO_BTF=y" >> "$KCONF"
fi
