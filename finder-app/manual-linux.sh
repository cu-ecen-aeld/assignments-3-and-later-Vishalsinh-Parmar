#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    echo "building kernel"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all -j6
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules -j6
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs -j6
    cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}

    echo "built kernel"
fi

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir ${OUTDIR}/rootfs 
cd ${OUTDIR}/rootfs
mkdir bin dev etc home lib lib64 proc sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin var/log home/conf

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make distclean -j6
    make defconfig -j6
else
    cd busybox
fi

# TODO: Make and install busybox
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j6
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install -j6
cd ${OUTDIR}/rootfs

echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
echo "Add library dependencies to rootfs"
export SYSROOT=$(aarch64-none-linux-gnu-gcc -print-sysroot)
cp -L ${SYSROOT}/lib/ld-linux-aarch64.so.* lib
cp -L ${SYSROOT}/lib64/libc.so.* lib64
cp -L ${SYSROOT}/lib64/libm.so.* lib64
cp -L ${SYSROOT}/lib64/libresolv.so.* lib64

# TODO: Make device nodes
echo "Make device nodes"
cd ${OUTDIR}/rootfs
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1

# TODO: Clean and build the writer utility
echo "Building the writer utility"
cd ${FINDER_APP_DIR}
make clean -j6
make -j6

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
echo "Copying finder related scripts and executables to the /home directory"
cp -a ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home
cp -rL ${FINDER_APP_DIR}/../conf/username.txt ${OUTDIR}/rootfs/home/conf
cp -rL ${FINDER_APP_DIR}/../conf/assignment.txt ${OUTDIR}/rootfs/home/conf
cp -a ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home
cp -a ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home
cp -a ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home
cp -a ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home

# TODO: Chown the root directory
echo "Chown the root directory"
cd ${OUTDIR}/rootfs
sudo chown -R root:root ${OUTDIR}/rootfs

# TODO: Create initramfs.cpio.gz
echo "Create initramfs.cpio.gz"
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio

cd ${OUTDIR}
rm -f initramfs.cpio.gz #remove if gz file if exists
gzip -f initramfs.cpio
echo "initramfs.cpio.gz created"
echo "Kernel and rootfs built successfully"
