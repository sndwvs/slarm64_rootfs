#!/bin/sh
set +o posix

# Copyright 2010,2015,2016  Stuart Winter, Surrey, England, UK.
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
##############################################################################
# Script : build_minirootfs.sh
# Purpose: Build a mini Slackware root filesystem.
#          The mini root filesystem is a useful tool for embedded developers
#          who want a pre-made basic system from which to build on, or to
#          have a small but working OS to squeeze onto a low capacity
#          storage device such as NAND.
#          One of the other features is that it can be used in the bootstrap
#          process of supporting a new device.
# Author:  Stuart Winter <mozes@slackware.com>
# Date::   04-Feb-2010
###############################################################################

##############################################################################
# Changes: Script adapted for assembly on x86 systems, x86_64
# Author:  mara <mara@fail.pp.ua>
# Date::   2016-06-28
##############################################################################

export LC_ALL=C

CWD=$(pwd)

TTY_X=$(($(stty size | cut -f2 -d " ")-10))
TTY_Y=$(($(stty size | cut -f1 -d " ")-10))

PKG_FILE="packages-minirootfs.conf"
URL="http://dl.fail.pp.ua/slackware/slackwarearm-current/slackware/"

# Set your host name:
NEWHOST="slackware.localdomain"
ROOTPASS="$( mkpasswd -l 15 -d 3 -C 5 )"

PACK_NAME="slack-current-miniroot_"$(date +%d%b%g)

# Temporary location where the root filesystem will be created:
ROOTFS=$CWD/miniroot/

TMP_PKG=$CWD/pkg
mkdir -vpm755 {$TMP_PKG,$ROOTFS}

if [[ ! -f $PKG_FILE ]]; then
    dialog --title "error" --infobox "no configuration packet file" $TTY_Y $TTY_X
    sleep 2
    exit 1
fi

source $PKG_FILE

# number of packages
COUNT_PKG=$(echo $PKGLIST | wc -w)




download_pkg() {
    (
        processed=1
        for pkg in $PKGLIST; do
            pct=$(( $processed * 100 / $COUNT_PKG ))
            procent=${pct%.*}
            processed=$((processed+1))
            type_pkg=$(echo $pkg | cut -f1 -d "/")
            name_pkg=$(echo $pkg | cut -f2 -d "/")
            PKG=$(wget -q -O - ${URL}/$type_pkg/ | grep -oP "($(echo $pkg | sed "s#\+#\\\+#")[\.\-\+\d\w]+.txz)" | head -n1)
            wget -c -q -nc -nd -np ${URL}/$PKG -P $TMP_PKG/
            echo "XXX"
            echo $name_pkg
            echo "XXX"
            printf '%.0f\n' ${procent}
        done
    ) | dialog --title "Download packages" --gauge "Download package..." 6 $TTY_X
}


install_pkg() {
    # Needed to find package names:
    shopt -s extglob
    (
        processed=1
        for pkg in $PKGLIST; do
            pct=$(( $processed * 100 / $COUNT_PKG ))
            procent=${pct%.*}
            processed=$((processed+1))
            name_pkg=$(echo $pkg | cut -f2 -d "/")
            installpkg --root $ROOTFS $TMP_PKG/$name_pkg* 2>&1>/dev/null
            if [[ $name_pkg == glibc-solibs ]]; then
                fixing_glibc
            fi
            echo "XXX"
            echo $name_pkg
            echo "XXX"
            printf '%.0f\n' ${procent}
        done
    ) | dialog --title "Instalation packages" --gauge "Instalation package..." 6 $TTY_X
}


set_chroot() {
    # Configure binfmt_misc qemu to use for the new arm-elf:
    if [[ ! $(lsmod | grep binfmt_misc ) ]]; then
        sudo modprobe binfmt_misc || exit 1
    fi
    if [[ ! $(mount | grep binfmt_misc ) ]]; then
        sudo mount -t binfmt_misc none /proc/sys/fs/binfmt_misc || exit 1
    fi

    # If you have to write something, the third team can generate an error in the /proc/sys/fs/binfmt_misc/register:
    # -bash: echo: write error: Invalid argument
    # This command is corrected
    echo -1 > /proc/sys/fs/binfmt_misc/arm

    sudo sh -c 'echo ":arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:" > /proc/sys/fs/binfmt_misc/register'

    if [[ ! -x /usr/bin/qemu-arm-static ]]; then
        dialog --title "messages" --progressbox $TTY_Y $TTY_X << EOF
To continue install the package:
qemu-user-static-2.2-x86_64-1mara.txz
http://dl.fail.pp.ua/slackware/pkg/x86_64/ap/qemu-user-static-2.2-x86_64-1mara.txz
EOF
        sleep 2
        exit 1
    fi
    # Copy a HOST static qemu-arm inside arm root:
    sudo cp /usr/bin/qemu-arm-static $ROOTFS/usr/bin

#    sudo chroot $ROOTFS bin/bash
#    uname -a
}


fixing_glibc() {
    pushd $ROOTFS/lib > /dev/null
    ln -sf libnss_nis-2.23.so libnss_nis.so.2
    ln -sf libm-2.23.so libm.so.6
    ln -sf libnss_files-2.23.so libnss_files.so.2
    ln -sf libresolv-2.23.so libresolv.so.2
    ln -sf libnsl-2.23.so libnsl.so.1
    ln -sf libutil-2.23.so libutil.so.1
    ln -sf libnss_compat-2.23.so libnss_compat.so.2
    ln -sf libthread_db-1.0.so libthread_db.so.1
    ln -sf libnss_hesiod-2.23.so libnss_hesiod.so.2
    ln -sf libanl-2.23.so libanl.so.1
    ln -sf libcrypt-2.23.so libcrypt.so.1
    ln -sf libBrokenLocale-2.23.so libBrokenLocale.so.1
    ln -sf ld-2.23.so ld-linux.so.3
    ln -sf libdl-2.23.so libdl.so.2
    ln -sf libnss_dns-2.23.so libnss_dns.so.2
    ln -sf libpthread-2.23.so libpthread.so.0
    ln -sf libnss_nisplus-2.23.so libnss_nisplus.so.2
    ln -sf libc-2.23.so libc.so.6
    ln -sf librt-2.23.so librt.so.1
    popd > /dev/null
}



download_pkg
install_pkg
#fixing_glibc
set_chroot


#### Configure the system ############################################################

cd $ROOTFS

# # Update ld.so.conf:
# cat << EOF >> etc/ld.so.conf
# /lib
# /usr/lib
# EOF
#
# chroot $ROOTFS sbin/ldconfig

# Create fstab.
# This needs to be updated by the admin prior to use.
cat << EOF > etc/fstab
#
# Sample /etc/fstab
#
# This must be modified prior to use.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
proc            /proc           proc    defaults        0       0
#
# tmpfs            /dev/shm         tmpfs       defaults         0   0
#
##############################################################################
# This sample fstab comes from the Slackware ARM 'build_minirootfs.sh' script.
#
#
# The Slackware ARM installation documents recommend creating a separate /boot
# partition that uses the ext2 filesystem so that u-boot can load the kernels
# & initrd from it:
#/dev/sda1       /boot           ext2    errors=remount-ro 0       1

# Swap:
#/dev/sda2       none            swap    sw                0       0

# The rest is for the root filesystem:
#/dev/sda3       /               ext4    errors=remount-ro 0       1
EOF

# Update your resolver details:
cat << EOF > etc/resolv.conf
# These values were configured statically for the Slackware ARM
# mini rootfs.  You need to change them to suit your environment, or
# use dhcpcd to obtain your network settings automatically if
# you run DHCP on your network.
search localdomain
nameserver 192.168.1.1
EOF

# I need SSHd and RPC for NFS running at boot:
chmod +x etc/rc.d/rc.{ssh*,rpc}

# Set the timezone to Europe/London. You should use '/usr/sbin/timeconfig' to
# change this if you're not in the UK.
( cd etc
  cat << EOF > hardwareclock
# /etc/hardwareclock
#
# Tells how the hardware clock time is stored.
# You should run timeconfig to edit this file.

localtime
EOF

  rm -f localtime*
  ln -vfs /usr/share/zoneinfo/Europe/London localtime-copied-from
  cp -favv $ROOTFS/usr/share/zoneinfo/Europe/London localtime ) 2>&1>/dev/null

# Set the keymap:
# We'll set this to the US keymap, but you might want to change it
# to your own locale!
cat << EOF > etc/rc.d/rc.keymap
#!/bin/sh
# Load the keyboard map.  More maps are in /usr/share/kbd/keymaps.
if [ -x /usr/bin/loadkeys ]; then
 /usr/bin/loadkeys us.map
fi
EOF
chmod 755 etc/rc.d/rc.keymap

# Set the host name:
echo $NEWHOST > etc/HOSTNAME

# Update fonts so that X and xVNC will work:
if [ -d usr/share/fonts/ ]; then
   ( cd usr/share/fonts/
     find . -type d -mindepth 1 -maxdepth 1 | while read dir ; do
     ( cd $dir
        mkfontscale .
        mkfontdir . )
     done
   /usr/bin/fc-cache -f )
fi

# Set default window manager to WindowMaker because it's light weight
# and therefore fast.
if [ -d etc/X11/xinit/ ]; then
   ( cd etc/X11/xinit/
     ln -vfs xinitrc.wmaker xinitrc )
fi

# Allow root login on the first serial port
# (useful for SheevaPlugs, Marvell OpenRD systems, and numerous others)
sed -i 's?^#ttyS0?ttyS0?' etc/securetty
# Start a login on the first serial port:
# Only add the line if it's absent -- since I usually use a Marvell ARM device to
# build these images, the post install scripts for some packages will detect
# "Marvell" in /proc/cpuinfo, and adjust these config files during installation.
grep -q '^s0:.*ttyS0.*vt100' etc/inittab || sed -i '/^# Local serial lines:/ a\s0:12345:respawn:/sbin/agetty 115200 ttyS0 vt100' etc/inittab

# Set root password:
cat << EOF > tmp/setrootpw
/usr/bin/echo "root:${ROOTPASS}" | /usr/sbin/chpasswd
chage -d 0 root
EOF
chmod 755 tmp/setrootpw
chroot $ROOTFS /tmp/setrootpw
rm -f tmp/setrootpw
# Log the root password so that we can document it in the "details"
# file for each rootfs.  This file will be wiped by the archiving script.
#echo "${ROOTPASS}" > tmp/rootpw

# Write out the build date of this image:
cat << EOF > root/rootfs_build_date
This mini root filesystem was built on:
$( date -u )
EOF

# Set eth0 to be DHCP by default
sed -i 's?USE_DHCP\[0\]=.*?USE_DHCP\[0\]="yes"?g' etc/rc.d/rc.inet1.conf

# Create SSH keys.
# It's expected that the admins will replace these if they wish to use the mini
# root permanently:
#echo "Generating SSH keys for the mini root"
# So we can set the host name that generated the SSH keys:
# this library is stored in the slackkit package.
# [ -s /usr/lib/libfakeuname.so ] && cp -fav /usr/lib/libfakeuname.so usr/lib/
cat << EOF > tmp/sshkeygen
# export LD_PRELOAD=/usr/lib/libfakeuname.so
# export FAKEUNAME=SlackwareARM-miniroot
#
#/usr/bin/ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ''
#/usr/bin/ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
#
# Use OpenSSH's own tool to generate the list of keys:
/usr/bin/ssh-keygen -A | dialog --title "Generating SSH keys for the mini root" --progressbox $TTY_Y $TTY_X
sleep 2
EOF
chmod 755 tmp/sshkeygen
chroot $ROOTFS /tmp/sshkeygen
rm -f tmp/sshkeygen
#rm -f usr/lib/libfakeuname.so

# e2fsck v1.4.x needs a RTC which QEMU emulating ARM does not have
# so we need to tell it to be happy anyway.
# Normally we only do this if e2fsprogs finds itself being installed
# on an "ARM Versatile" board, but since we don't prepare these mini roots
# on such a system, but we may well use it on one, we will configure e2fsprogs
# in this way.
cat << EOF > etc/e2fsck.conf
# These options stop e2fsck from erroring/requiring manual intervention
# when it encounters bad time stamps on filesystems -- which happens on
# the Versatile platform because QEMU does not have RTC (real time clock)
# support.
#
[options]
        accept_time_fudge = 1
        broken_system_clock = 1
EOF

# Check the installation works:
dialog --title "messages" --progressbox $TTY_Y $TTY_X << EOF
*****************************************************************
Dropping into chroot NOW
Test this works.  We might need additional packages if there are
new dependencies.

exit the chroot to continue packaging this filesystem.
*****************************************************************
EOF

sleep 2

if [[ $(uname -a | grep arm) ]]; then
   chroot $ROOTFS bin/bash -l
   echo "chroot finished." | dialog --title "messages" --progressbox $TTY_Y $TTY_X
fi

# Clean up anything left over from the test within the chroot:
rm -f root/.bash_history

sleep 2

dialog --title "messages" --progressbox $TTY_Y $TTY_X << EOF
*****************************************************************
Archive creation.
This may take some time...
*****************************************************************
EOF

pushd $ROOTFS > /dev/null
tar cJf $CWD/$PACK_NAME.tar.xz .
popd > /dev/null

# deleting old files
rm -rf $ROOTFS || exit 1
rm -rf $TMP_PKG || exit 1

dialog --title "messages" --progressbox $TTY_Y $TTY_X << EOF
*****************************************************************
Creating mini rootfs completed.
minirootfs created in the directory:
$CWD
Archive: $PACK_NAME.tar.xz
*****************************************************************
EOF

sleep 2

#EOF
