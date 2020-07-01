## constants
IMGTOOLS_DIR := $(shell readlink -f $(shell dirname $(MAKEFILE_LIST)))
PKGTOOLS_DIR := $(IMGTOOLS_DIR)/../ngfw_pkgtools

## overridables
ifeq ($(REPOSITORY),)
REPOSITORY := buster
endif
ifeq ($(DISTRIBUTION),)
DISTRIBUTION := $(shell cat $(PKGTOOLS_DIR)/resources/DISTRIBUTION)
endif

## shell variables
export http_proxy=$(shell perl -pe 's/.*"(.*?)".*/$$1/' 2> /dev/null < /etc/apt/apt.conf.d/01proxy)

## make variables
PKGS := bf-utf-source debiandoc-sgml genext2fs glibc-pic grub-common grub-efi-amd64-bin isolinux libbogl-dev libnewt-pic librsvg2-bin libslang2-pic mklibs module-init-tools pxelinux syslinux-utils tofrodos win32-loader xorriso
ARCH := $(shell dpkg-architecture -qDEB_BUILD_ARCH)
DEBVERSION := 10.0
ifeq ($(ARCH),amd64)
  KERNEL_ARCH_FLAVOR := amd64
else
  KERNEL_ARCH_FLAVOR := 686-pae
endif
KERNEL_VERSION := 4.19.0-8
KERNEL := linux-image-$(KERNEL_VERSION)-untangle-$(KERNEL_ARCH_FLAVOR)
VERSION = $(shell cat $(PKGTOOLS_DIR)/resources/VERSION)
ISO_IMAGE := ngfw-+FLAVOR+-$(VERSION)_$(REPOSITORY)_$(ARCH)_$(DISTRIBUTION)_$(shell date --iso-8601=seconds)_$(shell hostname -s).iso
IMAGES_DIR := /data/untangle-images-$(REPOSITORY)
MOUNT_SCRIPT := /data/image-manager/mounts.py
NETBOOT_HOST := package-server
NETBOOT_USER := buildbot
NETBOOT_DIR_TXT := $(IMGTOOLS_DIR)/d-i/build/dest/netboot/debian-installer/$(ARCH)
NETBOOT_DIR_GTK := $(IMGTOOLS_DIR)/d-i/build/dest/netboot/gtk/debian-installer/$(ARCH)
NETBOOT_INITRD_TXT := $(NETBOOT_DIR_TXT)/initrd.gz
NETBOOT_INITRD_GTK := $(NETBOOT_DIR_GTK)/initrd.gz
NETBOOT_KERNEL := $(NETBOOT_DIR_TXT)/linux
BOOT_IMG := $(IMGTOOLS_DIR)/d-i/build/dest/hd-media/boot.img.gz
PROFILES_DIR := $(IMGTOOLS_DIR)/profiles
COMMON_PRESEED :=  $(PROFILES_DIR)/common.preseed
AUTOPARTITION_PRESEED :=  $(PROFILES_DIR)/auto-partition.preseed
UNTANGLE_PRESEED := $(PROFILES_DIR)/untangle.preseed
NETBOOT_PRESEED := $(PROFILES_DIR)/netboot.preseed
NETBOOT_PRESEED_FINAL := $(NETBOOT_PRESEED).$(ARCH)
NETBOOT_PRESEED_EXPERT := $(PROFILES_DIR)/netboot.expert.preseed.$(ARCH)
NETBOOT_PRESEED_EXTRA := $(NETBOOT_PRESEED).extra
DEFAULT_PRESEED_FINAL := $(PROFILES_DIR)/default.preseed
DEFAULT_PRESEED_EXPERT := $(PROFILES_DIR)/expert.preseed
DEFAULT_PRESEED_EXTRA := $(DEFAULT_PRESEED_FINAL).extra
CONF_FILE := $(PROFILES_DIR)/default.conf
CONF_FILE_TEMPLATE := $(CONF_FILE).template
UNTANGLE_PKGS := $(PROFILES_DIR)/untangle.packages
UNTANGLE_PKGS_TEMPLATE := $(UNTANGLE_PKGS).template
CUSTOMSIZE := $(shell echo $$(( 800 * 1024 * 1024 / 2048 )) ) # from MB to 2kB blocks
DEBIAN_INSTALLER_PATCH := $(IMGTOOLS_DIR)/patches/d-i.patch
DEBIAN_CD_PATCH := $(IMGTOOLS_DIR)/patches/debian-cd.patch
DEBIAN_PKGS_PATCH := $(IMGTOOLS_DIR)/patches/installer-pkgs.patch
DEBIAN_PATCHES := $(DEBIAN_INSTALLER_PATCH) $(DEBIAN_CD_PATCH) $(DEBIAN_PKGS_PATCH)
DEBIAN_PATCH_STAMP := patch-stamp

## main section
all: # do nothing by default

## d-i section
d-i/patch: $(DEBIAN_PATCH_STAMP)
$(DEBIAN_PATCH_STAMP):
	for p in $(DEBIAN_PATCHES) ; do \
	  patch -p0 < $$p ; \
	done
	touch $@

d-i/unpatch:
	if [ -f $(DEBIAN_PATCH_STAMP) ] ; then \
	  for p in $(DEBIAN_PATCHES) ; do \
	    patch -p0 -R < $$p ; \
	  done ; \
	  rm -f $(DEBIAN_PATCH_STAMP) ; \
	fi

## iso section
repoint-stable: repoint-stable-stamp
repoint-stable-stamp:
	@$(PKGTOOLS_DIR)/package-server-proxy.sh $(PKGTOOLS_DIR)/create-di-links.sh $(REPOSITORY) $(DISTRIBUTION) || { \
	echo ; \
	echo "*** Creating d-i links via SSH failed ***" ; \
	echo "*** You will need to manually run http://jenkins.untangle.int/job/Create%20d-i%20links ***" ; \
	echo "*** Please do this and re-run your make command ***" ; \
	touch $@ ; \
	exit 1 ; }
	touch $@

iso/conf:
	perl -pe 's|\+IMGTOOLS_DIR\+|'$(IMGTOOLS_DIR)'|g' $(CONF_FILE_TEMPLATE) >| $(CONF_FILE)
	perl -pe 's|\+KERNEL\+|'$(KERNEL)'|g' $(UNTANGLE_PKGS_TEMPLATE) >| $(UNTANGLE_PKGS)
	cat $(COMMON_PRESEED) $(AUTOPARTITION_PRESEED) $(NETBOOT_PRESEED_EXTRA) $(UNTANGLE_PRESEED) | perl -pe 's|\+VERSION\+|'$(VERSION)'|g ; s|\+ARCH\+|'$(ARCH)'|g ; s|\+REPOSITORY\+|'$(REPOSITORY)'|g ; s|\+KERNELS\+|'$(KERNEL)'|g ; s/^(d-i preseed\/early_command string anna-install.*)/#$1/' >| $(NETBOOT_PRESEED_FINAL)
	cat $(COMMON_PRESEED) $(AUTOPARTITION_PRESEED) $(DEFAULT_PRESEED_EXTRA) | perl -pe 's|\+VERSION\+|'$(VERSION)'|g ; s|\+ARCH\+|'$(ARCH)'|g ; s|\+REPOSITORY\+|'$(REPOSITORY)'|g ; s|\+KERNEL\+|'$(KERNEL)'|g' >| $(DEFAULT_PRESEED_FINAL)
	cat $(COMMON_PRESEED) $(NETBOOT_PRESEED_EXTRA) $(UNTANGLE_PRESEED) | perl -pe 's|\+VERSION\+|'$(VERSION)'|g ; s|\+ARCH\+|'$(ARCH)'|g ; s|\+REPOSITORY\+|'$(REPOSITORY)'|g ; s|\+KERNEL\+|'$(KERNEL)'|g ; s/^(d-i preseed\/early_command string anna-install.*)/#$1/' >| $(NETBOOT_PRESEED_EXPERT)
	cat $(COMMON_PRESEED) $(DEFAULT_PRESEED_EXTRA) | perl -pe 's|\+VERSION\+|'$(VERSION)'|g ; s|\+ARCH\+|'$(ARCH)'|g ; s|\+REPOSITORY\+|'$(REPOSITORY)'|g ; s|\+KERNEL\+|'$(KERNEL)'|g' >| $(DEFAULT_PRESEED_EXPERT)

iso/dependencies:
	apt install -y simple-cdd dose-distcheck mtools dosfstools

iso/%-image: repoint-stable iso/dependencies iso/conf
	$(eval flavor := $*)
	export CODENAME=$(REPOSITORY) DEBVERSION=$(DEBVERSION) ; \
	export CDNAME=$(flavor) DISKINFO=$(flavor) CUSTOMSIZE=$(CUSTOMSIZE) ; \
	build-simple-cdd --keyring /usr/share/keyrings/untangle-archive-keyring.gpg --force-root --auto-profiles default,untangle,$(flavor) --profiles untangle,$(flavor),expert --debian-mirror http://package-server/public/$(REPOSITORY)/ --security-mirror http://package-server/public/$(REPOSITORY)/ --dist $(REPOSITORY) --require-optional-packages --mirror-tools reprepro --extra-udeb-dist $(DISTRIBUTION) --do-mirror --verbose --logfile $(IMGTOOLS_DIR)/simplecdd.log  ; 
	mv images/$(flavor)-$(DEBVERSION)*-$(ARCH)-*1.iso $(subst +FLAVOR+,$(flavor),$(ISO_IMAGE))

iso/%-push: # pushes the most recent image
	$(eval iso_image := $(shell ls --sort=time *$(VERSION)*$(REPOSITORY)*$(ARCH)*$(DISTRIBUTION)*.iso | head -1))
	$(eval timestamp := $(shell echo $(iso_image) | perl -pe 's/.*(\d{4}(-\d{2}){2}T(\d{2}:?){3}).*/$$1/'))
	ssh $(NETBOOT_USER)@$(NETBOOT_HOST) "sudo python $(MOUNT_SCRIPT) new $(VERSION) $(timestamp) $(ARCH) $(REPOSITORY)"
	scp ./$(iso_image) $(NETBOOT_PRESEED_FINAL) $(NETBOOT_PRESEED_EXPERT) $(NETBOOT_USER)@$(NETBOOT_HOST):$(IMAGES_DIR)/$(VERSION)
	scp $(NETBOOT_INITRD_TXT) $(NETBOOT_USER)@$(NETBOOT_HOST):$(IMAGES_DIR)/$(VERSION)/initrd-$(ARCH)-txt.gz
	scp $(NETBOOT_INITRD_GTK) $(NETBOOT_USER)@$(NETBOOT_HOST):$(IMAGES_DIR)/$(VERSION)/initrd-$(ARCH)-gtk.gz
	scp $(NETBOOT_KERNEL) $(NETBOOT_USER)@$(NETBOOT_HOST):$(IMAGES_DIR)/$(VERSION)/linux-$(ARCH)
	ssh $(NETBOOT_USER)@$(NETBOOT_HOST) "sudo python $(MOUNT_SCRIPT) link $(VERSION) $(timestamp) $(ARCH) $(REPOSITORY)"

iso/%-clean:
	rm -fr $(IMGTOOLS_DIR)/tmp /tmp/untangle-images-$(REPOSITORY)-$(DISTRIBUTION)-$* repoint-stable-stamp

## ova-section
ova/%-image:
	make -C $(IMGTOOLS_DIR)/ova FLAVOR=$* image
ova/%-push:
	make -C $(IMGTOOLS_DIR)/ova FLAVOR=$* push
ova/%-clean:
	make -C $(IMGTOOLS_DIR)/ova FLAVOR=$* clean

## cloud-section
# cloud/<provider>/<license> -> make LICENSE=<license> <provider>-image
cloud/%-image:
	$(eval license := $(shell basename $*))
	$(eval provider := $(shell dirname $(subst cloud/,"",$*)))
	make -C $(IMGTOOLS_DIR)/cloud LICENSE=$(license) $(provider)-image
cloud/%-push:
	$(eval license := $(shell basename $*))
	$(eval provider := $(shell dirname $(subst cloud/,"",$*)))
	make -C $(IMGTOOLS_DIR)/cloud LICENSE=$(license) $(provider)-push
cloud/%-clean:
	$(eval license := $(shell basename $*))
	$(eval provider := $(shell dirname $(subst cloud/,"",$*)))
	make -C $(IMGTOOLS_DIR)/cloud LICENSE=$(license) clean

## firmware section
# the next 4 rules are generic ones meant for firmware images; they
# take something like "buffalo/wzr1900dhp-image" and make it into
# "make -C firmware/buffalo-wzr1900dhp image"

%-image:
	make -C $(IMGTOOLS_DIR)/firmware/$(subst /,-,$*) image
%-rootfs:
	make -C $(IMGTOOLS_DIR)/firmware/$(subst /,-,$*) rootfs
%-push:
	make -C $(IMGTOOLS_DIR)/firmware/$(subst /,-,$*) push
%-clean:
	make -C $(IMGTOOLS_DIR)/firmware/$(subst /,-,$*) clean
