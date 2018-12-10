#! /bin/sh

test -f /boot/extlinux/extlinux.conf || {
	echo "No boot config file found...";
	exit 1;
}


if [ `id -u` -ne 0 ] ; then
	echo "Need to be root to install...";
	exit 1;
fi

test -f ./vmlinux || {
	echo "No kernel image found...";
	exit 1;
}

_kernelrelease=$(make kernelrelease)

# Create all directoris
_dtbs="/boot/dtbs/${_kernelrelease}"

mkdir -p "${_dtbs}/rockchip" || {
	echo "Unable to create dtb directory.";
	exit 1;
}
cp arch/arm64/boot/dts/rockchip/rk3399-rockpro64.dtb "${_dtbs}/rockchip"
make modules_install || { echo "Unable to install modules..." ; exit 1; }
make install || { echo "Unable to install kernel..." ; exit 1; }

( cd initrd/ && bin/mkinitrd ${_kernelrelease} ) || exit 1

# TODO create extlinux entries



echo ${_kernelrelease}
