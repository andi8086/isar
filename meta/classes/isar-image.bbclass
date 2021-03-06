# Root filesystem for target installation
#
# This software is a part of ISAR.
# Copyright (C) 2015-2018 ilbers GmbH

inherit image
inherit isar-bootstrap-helper

def cfg_script(d):
    cf = d.getVar('DISTRO_CONFIG_SCRIPT', True) or ''
    if cf:
        return 'file://' + cf
    return ''

FILESPATH =. "${LAYERDIR_core}/conf/distro:"
SRC_URI += "${@ cfg_script(d) }"

DEPENDS += "${IMAGE_INSTALL} ${IMAGE_TRANSIENT_PACKAGES}"

IMAGE_TRANSIENT_PACKAGES += "isar-cfg-localepurge"

WORKDIR = "${TMPDIR}/work/${DISTRO}-${DISTRO_ARCH}/${PN}"

ISAR_RELEASE_CMD_DEFAULT = "git -C ${LAYERDIR_core} describe --tags --dirty --match 'v[0-9].[0-9]*'"
ISAR_RELEASE_CMD ?= "${ISAR_RELEASE_CMD_DEFAULT}"

do_rootfs[root_cleandirs] = "${IMAGE_ROOTFS} \
                             ${IMAGE_ROOTFS}/isar-apt"

isar_image_gen_fstab() {
    cat > ${WORKDIR}/fstab << EOF
# Begin /etc/fstab
/dev/root	/		auto		defaults		0	0
proc		/proc		proc		nosuid,noexec,nodev	0	0
sysfs		/sys		sysfs		nosuid,noexec,nodev	0	0
devpts		/dev/pts	devpts		gid=5,mode=620		0	0
tmpfs		/run		tmpfs		defaults		0	0
devtmpfs	/dev		devtmpfs	mode=0755,nosuid	0	0

# End /etc/fstab
EOF
}

isar_image_gen_rootfs() {
    setup_root_file_system --clean --keep-apt-cache \
        --fstab "${WORKDIR}/fstab" \
        "${IMAGE_ROOTFS}" ${IMAGE_PREINSTALL} ${IMAGE_INSTALL}
}

isar_image_conf_rootfs() {
    # Configure root filesystem
    if [ -n "${DISTRO_CONFIG_SCRIPT}" ]; then
        sudo install -m 755 "${WORKDIR}/${DISTRO_CONFIG_SCRIPT}" "${IMAGE_ROOTFS}"
        TARGET_DISTRO_CONFIG_SCRIPT="$(basename ${DISTRO_CONFIG_SCRIPT})"
        sudo chroot ${IMAGE_ROOTFS} "/$TARGET_DISTRO_CONFIG_SCRIPT" \
                                    "${MACHINE_SERIAL}" "${BAUDRATE_TTY}"
        sudo rm "${IMAGE_ROOTFS}/$TARGET_DISTRO_CONFIG_SCRIPT"
   fi
}

isar_image_cleanup() {
    # Cleanup
    sudo sh -c ' \
        rm "${IMAGE_ROOTFS}/etc/apt/sources.list.d/isar-apt.list"
        test ! -e "${IMAGE_ROOTFS}/usr/share/doc/qemu-user-static" && \
            find "${IMAGE_ROOTFS}/usr/bin" \
                -maxdepth 1 -name 'qemu-*-static' -type f -delete
             umount -l ${IMAGE_ROOTFS}/isar-apt
        rmdir ${IMAGE_ROOTFS}/isar-apt
        umount -l ${IMAGE_ROOTFS}/dev
        umount -l ${IMAGE_ROOTFS}/proc
        umount -l ${IMAGE_ROOTFS}/sys
        rm -f "${IMAGE_ROOTFS}/etc/apt/apt.conf.d/55isar-fallback.conf"
        if [ "${ISAR_USE_CACHED_BASE_REPO}" = "1" ]; then
            umount -l ${IMAGE_ROOTFS}/base-apt
            rmdir ${IMAGE_ROOTFS}/base-apt
            # Replace the local apt we bootstrapped with the
            # APT sources initially defined in DISTRO_APT_SOURCES
            rm -f "${IMAGE_ROOTFS}/etc/apt/sources.list.d/base-apt.list"
            mv "${IMAGE_ROOTFS}/etc/apt/sources-list" \
                "${IMAGE_ROOTFS}/etc/apt/sources.list.d/bootstrap.list"
        fi
        rm -f "${IMAGE_ROOTFS}/etc/apt/sources-list"
    '
}

do_rootfs() {
    isar_image_gen_fstab
    isar_image_gen_rootfs
    isar_image_conf_rootfs
    isar_image_cleanup
}
