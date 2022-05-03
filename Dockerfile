ARG FLATCAR_VERSION=3200.0.0

FROM mediadepot/flatcar-developer:${FLATCAR_VERSION} AS base

CMD ["/bin/bash"]

RUN emerge-gitclone
RUN echo 'FEATURES="-network-sandbox -pid-sandbox -ipc-sandbox -usersandbox -sandbox"' >>/etc/portage/make.conf
COPY repos.conf /etc/portage/repos.conf/zfs.conf
COPY overlay /var/lib/portage/zfs-overlay/

FROM base AS builder
RUN emerge -j4 --getbinpkg --autounmask-write --autounmask-continue --onlydeps zfs
RUN emerge -j4 --getbinpkg --buildpkgonly zfs squashfs-tools

FROM base AS staging
COPY --from=builder /var/lib/portage/pkgs /var/lib/portage/pkgs
RUN emerge --getbinpkg --usepkg squashfs-tools
RUN pkgs=$(emerge 2>/dev/null --usepkgonly --pretend zfs| awk -F'] ' '/binary/{ print $ 2 }' | awk '{ print "="$1 }'); emerge --usepkgonly --root=/work --nodeps $pkgs
RUN mkdir -p /work/usr/lib/extension-release.d && echo -e 'ID=flatcar\nSYSEXT_LEVEL=1.0' >/work/usr/lib/extension-release.d/extension-release.zfs
RUN mkdir -p /work/usr/src
RUN mv /work/etc /work/usr/etc
COPY usr /work/usr
RUN mkdir -p /output && mksquashfs /work /output/zfs.raw -noappend

FROM busybox
COPY --from=staging /output /output
CMD ["cp", "/output/zfs.raw", "/out"]
