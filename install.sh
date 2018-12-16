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

_default_rel=${_kernelrelease}
_tempfile=$(mktemp -p /boot/extlinux/)

test -f /boot/vmlinuz-${_default_rel} || { echo "Unable to find default kernel file for release ${_default_rel}"; exit 1; }

cd /boot

exec 3>${_tempfile}
exec 4< ${_tempfile}
rm -f ${_tempfile}

echo "timeout 30" >&3
echo "menu title select kernel" >&3
echo "default kernel-${_default_rel}" >&3
echo >&3

for _kernel in vmlinuz-* ; do
	_rel=$(echo ${_kernel} | sed 's/vmlinuz-//')
	_label=kernel-${_rel}

	# Test for dtb directory for this release
	if [ \! -d ./dtbs/${_rel} ]; then
		echo "No dtbs directory found for ${_rel}, skipping..." >&2
		continue
	fi
	# Test for initramfs
	_initramfs=$(echo ${_kernel} | sed 's/vmlinuz-/initramfs-/')
	if [ \! -f ./${_initramfs} ]; then
		echo "No initramfs found for ${_rel}, skipping..." >&2
		continue
	fi

	# Output the block for this kernel
	echo >&3
	echo "label ${_label}" >&3
	echo "    kernel /vmlinuz-${_rel}" >&3
	echo "    initrd /${_initramfs}" >&3
	echo "    devicetreedir /dtbs/${_rel}" >&3
	echo '    append rw panic=10 init=/sbin/init coherent_pool=1M ethaddr=${ethaddr} serial=${serial#} cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 root=LABEL=gentoo-root rootwait rootfstype=ext4' >&3

done

rm -f /boot/extlinux/new.conf
cat <&4 >/boot/extlinux/new.conf

_size=$(stat -c '%s' /boot/extlinux/new.conf)

test -z "${_size}" && { echo "Output file has zero size, aborting" >&2 ; exit 1; }

mv /boot/extlinux/new.conf /boot/extlinux/extlinux.conf
exec >&3-
exec >&4-

