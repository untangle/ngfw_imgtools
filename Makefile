## constants
IMGTOOLS_DIR := $(shell readlink -f $(shell dirname $(MAKEFILE_LIST)))
PKGTOOLS_DIR := $(IMGTOOLS_DIR)/../ngfw_pkgtools

## overridables
ifeq ($(REPOSITORY),)
REPOSITORY := bullseye
endif
ifeq ($(DISTRIBUTION),)
DISTRIBUTION := $(shell cat $(PKGTOOLS_DIR)/resources/DISTRIBUTION)
endif
ifeq ($(ARCHITECTURE),)
ARCHITECTURE := $(shell dpkg-architecture -qDEB_BUILD_ARCH)
endif
ifeq ($(VERSION),)
VERSION := $(shell cat $(PKGTOOLS_DIR)/resources/VERSION)
endif
ifeq ($(PUBVERSION),)
PUBVERSION := $(shell cat $(PKGTOOLS_DIR)/resources/PUBVERSION)
endif

REGION_NAME=
REGION_PROFILE=
ifneq ($(REGION),)
REGION_NAME=-$(REGION)
REGION_PROFILE=,region-$(REGION)
endif

## shell variables
export http_proxy=$(shell perl -pe 's/.*"(.*?)".*/$$1/' 2> /dev/null < /etc/apt/apt.conf.d/01proxy)

## make variables
DEBVERSION := 10.0
ifeq ($(ARCHITECTURE),i386)
  KERNEL_ARCH := 686-pae
else
  KERNEL_ARCH := $(ARCHITECTURE)
endif
KERNEL_VERSION := 5.10.0-14
KERNEL := linux-image-$(KERNEL_VERSION)-untangle-$(KERNEL_ARCH)
ISO_IMAGE := ngfw-+FLAVOR++REGION_NAME++SERIAL+-$(VERSION)_$(REPOSITORY)_$(ARCHITECTURE)_$(DISTRIBUTION)_$(shell date --iso-8601=seconds)_$(shell hostname -s).iso
WAF_ISO_IMAGE := waf-+FLAVOR+-$(VERSION)_$(REPOSITORY)_$(ARCHITECTURE)_$(DISTRIBUTION)_$(shell date --iso-8601=seconds)_$(shell hostname -s).iso
NGFW_IMAGES_DIR := /data/ngfw-images-$(REPOSITORY)
WAF_IMAGES_DIR := /data/waf-images-$(REPOSITORY)
MOUNT_SCRIPT := /data/image-manager/mounts.py
NETBOOT_HOST := package-server
NETBOOT_USER := buildbot
NETBOOT_DIR_TXT := $(IMGTOOLS_DIR)/d-i/build/dest/netboot/debian-installer/$(ARCHITECTURE)
NETBOOT_DIR_GTK := $(IMGTOOLS_DIR)/d-i/build/dest/netboot/gtk/debian-installer/$(ARCHITECTURE)
NETBOOT_INITRD_TXT := $(NETBOOT_DIR_TXT)/initrd.gz
NETBOOT_INITRD_GTK := $(NETBOOT_DIR_GTK)/initrd.gz
NETBOOT_KERNEL := $(NETBOOT_DIR_TXT)/linux
BOOT_IMG := $(IMGTOOLS_DIR)/d-i/build/dest/hd-media/boot.img.gz
PROFILES_DIR := $(IMGTOOLS_DIR)/profiles
COMMON_PRESEED :=  $(PROFILES_DIR)/common.preseed
AUTOPARTITION_PRESEED :=  $(PROFILES_DIR)/auto-partition.preseed
NGFW_PRESEED := $(PROFILES_DIR)/ngfw.preseed
NETBOOT_PRESEED := $(PROFILES_DIR)/netboot.preseed
NETBOOT_PRESEED_FINAL := $(NETBOOT_PRESEED).$(ARCHITECTURE)
NETBOOT_PRESEED_EXPERT := $(PROFILES_DIR)/netboot.expert.preseed.$(ARCHITECTURE)
NETBOOT_PRESEED_EXTRA := $(NETBOOT_PRESEED).extra
DEFAULT_PRESEED_FINAL := $(PROFILES_DIR)/default.preseed
DEFAULT_PRESEED_EXPERT := $(PROFILES_DIR)/expert.preseed
DEFAULT_PRESEED_EXTRA := $(DEFAULT_PRESEED_FINAL).extra
CONF_FILE := $(PROFILES_DIR)/ngfw.conf
CONF_FILE_TEMPLATE := $(CONF_FILE).template
WAF_CONF_FILE := $(PROFILES_DIR)/waf.conf
WAF_CONF_FILE_TEMPLATE := $(WAF_CONF_FILE).template
WAF_PRESEED_FILE := $(PROFILES_DIR)/waf.preseed
WAF_PRESEED_FILE_TEMPLATE := $(WAF_PRESEED_FILE).template
UNTANGLE_PKGS := $(PROFILES_DIR)/untangle.packages
UNTANGLE_PKGS_TEMPLATE := $(UNTANGLE_PKGS).template
DEBIAN_PATCHES := $(wildcard $(IMGTOOLS_DIR)/patches/*.patch)
DEBIAN_PATCH_STAMP := patch-stamp
UNTANGLE_LOGO_SRC := $(IMGTOOLS_DIR)/patches/logo_untangle.png
UNTANGLE_LOGO_DST := installer-pkgs-modified/rootskel-gtk/src/usr/share/graphics/logo_untangle.png

SERIAL_ENV=
SERIAL_PARAMETER=
SERIAL_NAME=
ifneq ($(SERIAL),)
# Modify isoconfig menu to remove graphics mode.
# Modify conf template to use normal VGA
SERIAL_ENV_PRE_CMD=export export serial_console_opts=$(SERIAL) ; \
cp -f ./cd-root/isolinux/menu.cfg . ; \
sed -i -e '/include gtk.cfg/d' ./cd-root/isolinux/menu.cfg ; \
cp -f $(CONF_FILE) ./conf ; \
echo 'vga_normal="true"' >> $(CONF_FILE) ;
# Restore isoconfig menu, conf template.
SERIAL_ENV_POST_CMD=cp -f ./menu.cfg ./cd-root/isolinux/menu.cfg ; \
cp -f ./conf $(CONF_FILE) ;
SERIAL_BSC_PARAMETER=--serial-console
SERIAL_NAME=-serial
endif

## main section
all: # do nothing by default

## d-i section
patch: $(DEBIAN_PATCH_STAMP)
$(DEBIAN_PATCH_STAMP):
	for p in $(DEBIAN_PATCHES) ; do \
	  patch -p0 < $$p ; \
	done
	cp $(UNTANGLE_LOGO_SRC) $(UNTANGLE_LOGO_DST)
	touch $@

unpatch:
	if [ -f $(DEBIAN_PATCH_STAMP) ] ; then \
	  for p in $(DEBIAN_PATCHES) ; do \
	    patch -p0 -R < $$p ; \
	  done ; \
	  rm -f $(DEBIAN_PATCH_STAMP) ; \
	fi
	rm -f $(UNTANGLE_LOGO_DST)

## iso section
iso/dependencies:
	apt install -y simple-cdd dose-distcheck mtools dosfstools

iso/%-clean:
	rm -fr $(IMGTOOLS_DIR)/tmp profiles/default.conf

ngfw/iso/conf:
	perl -pe 's|\+IMGTOOLS_DIR\+|'$(IMGTOOLS_DIR)'|g' $(CONF_FILE_TEMPLATE) >| $(CONF_FILE)
	perl -pe 's|\+KERNEL\+|'$(KERNEL)'|g' $(UNTANGLE_PKGS_TEMPLATE) >| $(UNTANGLE_PKGS)
	cat $(COMMON_PRESEED) $(AUTOPARTITION_PRESEED) $(NETBOOT_PRESEED_EXTRA) $(NGFW_PRESEED) | perl -pe 's|\+VERSION\+|'$(VERSION)'|g ; s|\+ARCH\+|'$(ARCHITECTURE)'|g ; s|\+REPOSITORY\+|'$(REPOSITORY)'|g ; s|\+KERNELS\+|'$(KERNEL)'|g ; s/^(d-i preseed\/early_command string anna-install.*)/#$1/' >| $(NETBOOT_PRESEED_FINAL)
	cat $(COMMON_PRESEED) $(AUTOPARTITION_PRESEED) $(DEFAULT_PRESEED_EXTRA) | perl -pe 's|\+VERSION\+|'$(VERSION)'|g ; s|\+ARCH\+|'$(ARCHITECTURE)'|g ; s|\+REPOSITORY\+|'$(REPOSITORY)'|g ; s|\+KERNEL\+|'$(KERNEL)'|g' >| $(DEFAULT_PRESEED_FINAL)
	cat $(COMMON_PRESEED) $(NETBOOT_PRESEED_EXTRA) $(NGFW_PRESEED) | perl -pe 's|\+VERSION\+|'$(VERSION)'|g ; s|\+ARCH\+|'$(ARCHITECTURE)'|g ; s|\+REPOSITORY\+|'$(REPOSITORY)'|g ; s|\+KERNEL\+|'$(KERNEL)'|g ; s/^(d-i preseed\/early_command string anna-install.*)/#$1/' >| $(NETBOOT_PRESEED_EXPERT)
	cat $(COMMON_PRESEED) $(DEFAULT_PRESEED_EXTRA) | perl -pe 's|\+VERSION\+|'$(VERSION)'|g ; s|\+ARCH\+|'$(ARCHITECTURE)'|g ; s|\+REPOSITORY\+|'$(REPOSITORY)'|g ; s|\+KERNEL\+|'$(KERNEL)'|g' >| $(DEFAULT_PRESEED_EXPERT)

ngfw/iso/%-image: iso/dependencies ngfw/iso/conf
	$(eval flavor := $*)
	perl -pe 's|\+IMGTOOLS_DIR\+|'$(IMGTOOLS_DIR)'|g' $(CONF_FILE_TEMPLATE) >| $(CONF_FILE); \
	export CODENAME=$(REPOSITORY) DEBVERSION=$(DEBVERSION) ; \
	export CDNAME=$(flavor) DISKINFO=$(flavor) ; \
	build-simple-cdd \
	    --local-packages local-packages \
		--keyboard us \
		--locale en_US.UTF-8 \
		--keyring /usr/share/keyrings/untangle-archive-keyring.gpg \
		--force-root \
		--auto-profiles default,ngfw,$(flavor)$(REGION_PROFILE) \
		--profiles hands-free,ngfw,$(flavor)$(REGION_PROFILE),expert \
		--debian-mirror http://package-server/public/$(REPOSITORY)/ \
		--debian-mirror http://package-server/public/$(REPOSITORY)/ \
		--security-mirror "" \
		--updates-mirror "" \
		--dist $(DISTRIBUTION) \
		--require-optional-packages \
		--mirror-tools reprepro \
		--extra-udeb-dist $(DISTRIBUTION) \
		--do-mirror \
                --mirror-only \
		--verbose \
		--logfile $(IMGTOOLS_DIR)/simplecdd-mirror.log  ; \
	perl -pe s/$(DISTRIBUTION)/$(REPOSITORY)/ $(IMGTOOLS_DIR)/tmp/mirror/conf/distributions > $(IMGTOOLS_DIR)/tmp/mirror/conf/distributions.ngfw ; \
	cat $(IMGTOOLS_DIR)/tmp/mirror/conf/distributions.ngfw >> $(IMGTOOLS_DIR)/tmp/mirror/conf/distributions ; \
	reprepro -Vb $(IMGTOOLS_DIR)/tmp/mirror copymatched $(REPOSITORY) $(DISTRIBUTION) '*' ; \
	export CUSTOMSIZE=`du -s --block-size=2048 $(IMGTOOLS_DIR)/tmp/mirror | awk '{print $$1}')` ; \
	echo $(CUSTOMSIZE) ; \
	$(SERIAL_ENV_PRE_CMD) \
	build-simple-cdd \
		$(SERIAL_BSC_PARAMETER) \
		--keyboard us \
		--locale en_US.UTF-8 \
		--force-root \
		--auto-profiles default,ngfw,$(flavor)$(REGION_PROFILE) \
		--profiles hands-free,ngfw,$(flavor)$(REGION_PROFILE),expert \
		--debian-mirror http://package-server/public/$(REPOSITORY)/ \
		--security-mirror "" \
		--updates-mirror "" \
		--dist $(REPOSITORY) \
		--require-optional-packages \
		--mirror-tools reprepro \
		--verbose \
		--no-do-mirror \
		--logfile $(IMGTOOLS_DIR)/simplecdd-image.log ; \
	$(SERIAL_ENV_POST_CMD) \
	mv images/$(flavor)-$(DEBVERSION)*-$(ARCHITECTURE)-*1.iso $(subst +SERIAL+,$(SERIAL_NAME),$(subst +FLAVOR+,$(flavor),$(subst +REGION_NAME+,$(REGION_NAME),$(ISO_IMAGE))))

ngfw/iso/%-push: # pushes the most recent image
	$(eval iso_image := $(shell ls --sort=time *$(VERSION)*$(REPOSITORY)*$(ARCHITECTURE)*$(DISTRIBUTION)*.iso | head -1))
	$(eval timestamp := $(shell echo $(iso_image) | perl -pe 's/.*(\d{4}(-\d{2}){2}T(\d{2}:?){3}).*/$$1/'))
	ssh $(NETBOOT_USER)@$(NETBOOT_HOST) mkdir -p $(NGFW_IMAGES_DIR)/$(VERSION)
	scp ./$(iso_image) $(NETBOOT_PRESEED_FINAL) $(NETBOOT_PRESEED_EXPERT) $(NETBOOT_USER)@$(NETBOOT_HOST):$(NGFW_IMAGES_DIR)/$(VERSION)

waf/iso/conf:
	perl -pe 's|\+IMGTOOLS_DIR\+|'$(IMGTOOLS_DIR)'|g' $(WAF_CONF_FILE_TEMPLATE) >| $(WAF_CONF_FILE)
	perl -pe 's|\+VERSION\+|'$(VERSION)'|g ; s|\+PUBVERSION\+|'$(PUBVERSION)'|g ; s|\+ARCH\+|'$(ARCHITECTURE)'|g ; s|\+REPOSITORY\+|'$(REPOSITORY)'|g' profiles/waf.preseed.template > profiles/waf.preseed

waf/iso/%-image: iso/dependencies waf/iso/conf
	# built in 3 simple-cdd passes:
	#   1. add upstream installer and upstream packages from debian mirror
	#   2. add WAF packages from internal mirror
	#   3. build image without mirroring anything else
	$(eval flavor := $*)
	export CODENAME=$(REPOSITORY) DEBVERSION=$(DEBVERSION) ; \
	export CDNAME=waf-$(flavor) DISKINFO=waf-$(flavor) ; \
	export CUSTOMSIZE=$(shell echo $$(( 700 * 1024 * 1024 / 2048 )) ) ; \
	export http_proxy="" ; \
	build-simple-cdd \
		--keyboard us \
		--locale en_US.UTF-8 \
		--force-root \
		--debian-mirror http://ftp.us.debian.org/debian/ \
		--security-mirror http://security.debian.org/debian-security/ \
		--dist $(REPOSITORY) \
		--verbose \
		--mirror-only \
		--logfile $(IMGTOOLS_DIR)/simplecdd-mirror-debian.log ; \
	cp $(IMGTOOLS_DIR)/tmp/mirror/conf/distributions $(IMGTOOLS_DIR)/tmp/mirror/conf/distributions.debian ; \
	build-simple-cdd \
		--keyboard us \
		--locale en_US.UTF-8 \
		--force-root \
		--profiles waf,auto-partition \
		--auto-profiles waf,auto-partition \
		--keyring /usr/share/keyrings/does-not-exist.gpg \
		--debian-mirror http://package-server/public/$(REPOSITORY)/ \
		--security-mirror "" \
		--mirror-tools reprepro \
		--dist $(DISTRIBUTION) \
		--verbose \
		--mirror-only \
		--logfile $(IMGTOOLS_DIR)/simplecdd-mirror-waf.log ; \
	cat $(IMGTOOLS_DIR)/tmp/mirror/conf/distributions.debian >> $(IMGTOOLS_DIR)/tmp/mirror/conf/distributions ; \
	reprepro -Vb $(IMGTOOLS_DIR)/tmp/mirror copymatched $(REPOSITORY) $(DISTRIBUTION) '*' ; \
	build-simple-cdd \
		--keyboard us \
		--locale en_US.UTF-8 \
		--force-root \
		--profiles waf,auto-partition \
		--auto-profiles waf,auto-partition \
		--keyring /usr/share/keyrings/does-not-exist.gpg \
		--mirror-tools reprepro \
		--dist $(REPOSITORY) \
		--verbose \
		--no-do-mirror \
		--logfile $(IMGTOOLS_DIR)/simplecdd-image.log
	mv images/waf-$(flavor)-$(DEBVERSION)*-$(ARCHITECTURE)-*1.iso $(subst +FLAVOR+,$(flavor),$(WAF_ISO_IMAGE))
	cp -f $(subst +FLAVOR+,$(flavor),$(WAF_ISO_IMAGE)) waf.iso

waf/iso/%-push:
	$(eval iso_image := $(shell ls --sort=time *$(VERSION)*$(REPOSITORY)*$(ARCHITECTURE)*$(DISTRIBUTION)*.iso | head -1))
	$(eval timestamp := $(shell echo $(iso_image) | perl -pe 's/.*(\d{4}(-\d{2}){2}T(\d{2}:?){3}).*/$$1/'))
	ssh $(NETBOOT_USER)@$(NETBOOT_HOST) mkdir -p $(WAF_IMAGES_DIR)/$(VERSION)
	scp ./$(iso_image) $(NETBOOT_USER)@$(NETBOOT_HOST):$(WAF_IMAGES_DIR)/$(VERSION)
