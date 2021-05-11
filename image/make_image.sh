#!/usr/bin/env bash
set -ex

if [ -z ${UBOOT_DIR} ]; then
  echo "Set UBOOT_DIR to the U-boot build dir"
  exit 1
fi

if [ -z ${KERNEL_DIR} ]; then
  echo "Set KERNEL_DIR to the kernel build dir"
  exit 1
fi

if [ -z ${BUILDROOT_DIR} ]; then
  echo "Set BUILDROOT_DIR to the buildroot build dir"
  exit 1
fi

out_file=$1

if [ -z ${out_file} ]; then
  echo "Usage: make_image.sh out.img"
  exit 1
fi

dd if=/dev/zero of=${out_file} bs=128M count=1
sfdisk ${out_file} <<EOT
1M,1M,0xA2,
2M,,,*
EOT

dd if=${UBOOT_DIR}/u-boot-with-spl.sfp of=${out_file} bs=1M count=1 seek=1 conv=notrunc

loopdev=$(udisksctl loop-setup -f ${out_file} | grep -o '/dev/loop[0-9]*')

echo "Loop device is ${loopdev}"

mkfs.ext4 -L rootfs ${loopdev}p2

temp_dir=$(mktemp -d)
mkdir -p ${temp_dir}/rootfs
mount ${loopdev}p2 ${temp_dir}/rootfs

tar -xvpf ${BUILDROOT_DIR}/output/images/rootfs.tar -C ${temp_dir}/rootfs
mkdir -p ${temp_dir}/rootfs/boot
cp ${KERNEL_DIR}/arch/arm/boot/zImage ${temp_dir}/rootfs/boot/vmlinuz
mkdir -p ${temp_dir}/rootfs/boot/dtbs

# Not a typo, there is no DTB for the DE10-nano but the DE0-nano one works well enough...
cp ${KERNEL_DIR}/arch/arm/boot/dts/socfpga_cyclone5_de0_nano_soc.dtb ${temp_dir}/rootfs/boot/dtbs/socfpga_cyclone5_de10_nano.dtb

mkdir -p ${temp_dir}/rootfs/boot/extlinux
echo 'label Linux' > ${temp_dir}/rootfs/boot/extlinux/extlinux.conf
echo '    kernel /boot/vmlinuz' >> ${temp_dir}/rootfs/boot/extlinux/extlinux.conf
echo '    append root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait quiet' >> ${temp_dir}/rootfs/boot/extlinux/extlinux.conf
echo '    fdtdir /boot/dtbs/' >> ${temp_dir}/rootfs/boot/extlinux/extlinux.conf

# Configure a DHCP server for USB networking
cat > ${temp_dir}/rootfs/etc/udhcpd.conf <<EOT
start 192.168.69.100
end 192.168.69.110
option subnet 255.255.255.0
interface usb0
lease_file /tmp/udhcpd.leases
EOT

mkdir -p ${temp_dir}/rootfs/etc/network/if-up.d
cat > ${temp_dir}/rootfs/etc/network/if-up.d/start_udhcpd <<EOT
#!/bin/sh
if [ $IFACE usb0 ] && [ $MODE start ]
then
touch /tmp/udhcpd.leases
/usr/sbin/udhcpd /etc/udhcpd.conf
fi
EOT
chmod +x ${temp_dir}/rootfs/etc/network/if-up.d/start_udhcpd

mkdir -p ${temp_dir}/rootfs/etc/network/if-down.d
cat > ${temp_dir}/rootfs/etc/network/if-down.d/stop_dhcp <<EOT
#!/bin/sh
if [ $IFACE usb0 ] && [ $MODE stop ]
then
pkill udhcpd
fi
exit 0
EOT
chmod +x ${temp_dir}/rootfs/etc/network/if-down.d/stop_dhcp


cat > ${temp_dir}/rootfs/etc/network/interfaces <<EOT
auto usb0
iface usb0 inet static
    address 192.168.69.1
    netmask 255.255.255.0
EOT

# Add a device tree overlay for configuring the FPGA
mkdir -p ${temp_dir}/rootfs/lib/firmware/
dtc -O dtb -o ${temp_dir}/rootfs/lib/firmware/load_rbf.dtbo -b 0 -@ /dev/stdin <<EOT
/dts-v1/;
/plugin/;
/ {
 fragment@0 {
    target-path = "/soc/base-fpga-region";
    #address-cells = <1>;
    #size-cells = <1>;
    __overlay__ {
       #address-cells = <1>;
       #size-cells = <1>;

       firmware-name = "bitstream.rbf";
       config-complete-timeout-us = <30000000>;
       };
    };
};
EOT

# Add a script for activating the overlay
cat > ${temp_dir}/rootfs/bin/reload-fpga <<EOT
#!/bin/sh
mount -t configfs none /sys/kernel/config/
rmdir /sys/kernel/config/device-tree/overlays/test
mkdir /sys/kernel/config/device-tree/overlays/test
echo load_rbf.dtbo > /sys/kernel/config/device-tree/overlays/test/path
EOT
chmod +x ${temp_dir}/rootfs/bin/reload-fpga

# Allow passwordless root login (tut tut)
mkdir -p ${temp_dir}/rootfs/etc/default/
cat > ${temp_dir}/rootfs/etc/default/dropbear <<EOT
DROPBEAR_ARGS="-B"
EOT
chmod +x ${temp_dir}/rootfs/etc/default/dropbear

umount ${temp_dir}/rootfs

udisksctl loop-delete -b ${loopdev}
