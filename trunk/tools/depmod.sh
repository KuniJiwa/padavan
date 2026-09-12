#!/bin/sh

depmod_bin="/sbin/depmod"

# check env
if [ -z "${ROOTDIR}" ]; then
	echo "ROOTDIR is not set!"
	exit 1
fi

# get KERNELRELEASE from kernel Makefile
if [ -z "${KERNELRELEASE}" ]; then
  [ -f "${ROOTDIR}/$(LINUXDIR)/Makefile" ] && KERNELRELEASE=$(make -C "${ROOTDIR}/$(LINUXDIR)" -s kernelrelease 2>/dev/null)
  export KERNELRELEASE
fi
if [ -z "${KERNELRELEASE}" ]; then
	echo "KERNELRELEASE is not set!"
	exit 1
fi

if [ -z "${INSTALL_MOD_PATH}" ]; then
	echo "INSTALL_MOD_PATH is not set!"
	exit 1
fi

if [ ! -x "$depmod_bin" ]; then
	echo "$depmod_bin is not found! Please install package module-init-tools (kmod)"
	exit 1
fi

# These .ko files are only present if CONFIG_FIRMWARE_INCLUDE_IPSET is enabled
ipset_dir="${ROOTDIR}/build/ipset-7.11/kernel/net/netfilter"
mkdir -p "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/net/netfilter/ipset"
cp -f "$ipset_dir/xt_set.ko" "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/net/netfilter"
cp -f "$ipset_dir/ipset/ip_set.ko" "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/net/netfilter/ipset/"
cp -f "$ipset_dir/ipset/ip_set_hash_ip.ko" "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/net/netfilter/ipset/"
cp -f "$ipset_dir/ipset/ip_set_hash_net.ko" "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/net/netfilter/ipset/"

if [ "$CONFIG_FIRMWARE_INCLUDE_ANTFS" = "y" ] ; then
	antfs_dir="${ROOTDIR}/build/antfs-07.19"
	mkdir -p "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/antfs"
	cp -f "$antfs_dir/"antfs.ko "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/antfs"
fi

# call depmod
$depmod_bin -ae -F System.map -b "${INSTALL_MOD_PATH}" ${KERNELRELEASE}

# clear unneeded depmod files
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.alias"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.alias.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.dep.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.devname"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.softdep"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.symbols"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.symbols.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.builtin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.builtin.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.builtin.alias.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.order"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/build"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/source"
