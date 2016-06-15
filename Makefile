# Makefile for OP-TEE for Hisilicon D02
#
# 'make help' for details

SHELL = /bin/bash

ifeq ($(V),1)
  Q :=
  ECHO := @:
else
  Q := @
  ECHO := @echo
endif

CROSS_COMPILE32 ?= ccache arm-linux-gnueabihf-
CROSS_COMPILE64 ?= ccache aarch64-linux-gnu-

# Where the various Linux files get installed by "make install" (kernel
# modules, TEE client library, test applications...).
# This has to be merged with the root FS of the linux distribution you will
# be using, for instance using:
#  mount -t overlay overlay -olowerdir=/path/to/d02_optee/install,/path/to/Debian_ARM64_ro \
#                           -oupperdir=/path/to/Debian_ARM64_rw /path/to/Debian_ARM64_merged

INSTALL_DIR = install

all: arm-trusted-firmware grub linux optee-client optee-os

help:
	@echo TODO

#
# GRUB
#

GRUB = grubaa64.efi grub.cfg

grub: grubaa64.efi

grubaa64.efi: grub/grub-mkimage
	$(ECHO) '  GEN    $@'
	$(Q)cd grub ; \
		./grub-mkimage -o ../grubaa64.efi \
			--format=arm64-efi \
			--prefix=/ \
			--directory=grub-core \
			boot chain configfile efinet ext2 fat gettext help \
			hfsplus loadenv lsefi normal normal ntfs ntfscomp \
			part_gpt part_msdos read search search_fs_file \
			search_fs_uuid search_label terminal terminfo tftp \
			linux

grub/grub-mkimage: grub/Makefile
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C grub

grub/Makefile: grub/configure
	$(ECHO) '  GEN     $@'
	$(Q)cd grub ; ./configure --target=aarch64-linux-gnu --with-platform=efi 

grub/configure: grub/configure.ac
	$(ECHO) '  GEN     $@'
	$(Q)cd grub ; ./autogen.sh

clean-grub:
	$(ECHO) '  CLEAN   $@'
	$(Q)if [ -e grub/Makefile ] ; then $(MAKE) -C grub clean ; fi
	$(Q)rm -f grubaa64.efi

clean: clean-grub

distclean-grub:
	$(ECHO) '  DISTCLEAN   $@'
	$(Q)if [ -e grub/Makefile ] ; then $(MAKE) -C grub distclean ; fi
	$(Q)rm -f grub/configure

distclean: distclean-grub

#
# ARM Trusted Firmware
#

BL32 = optee_os/out/arm-plat-d02/core/tee.bin

ARMTF_FLAGS := PLAT=d02
ARMTF_FLAGS += SPD=opteed
ARMTF_FLAGS += DEBUG=1
#ARMTF_FLAGS += LOG_LEVEL=40

ARMTF_EXPORTS += CROSS_COMPILE='$(CROSS_COMPILE64)'
ARMTF_EXPORTS += BL32=$(CURDIR)/$(BL32)

define arm-tf-make
	+$(Q)export $(ARMTF_EXPORTS) ; \
		$(MAKE) -C arm-trusted-firmware $(ARMTF_FLAGS) $(1) $(2)
endef

.PHONY: arm-trusted-firmware
arm-trusted-firmware: optee-os
	$(ECHO) '  BUILD   $@'
	$(call arm-tf-make, bl1 fip)

clean-arm-trusted-firmware:
	$(ECHO) '  CLEAN   $@'
	$(call arm-tf-make, clean)

clean: clean-arm-trusted-firmware

#
# OP-TEE OS
#

optee-os-flags := PLATFORM=d02
optee-os-flags += DEBUG=0
optee-os-flags += CFG_TEE_CORE_LOG_LEVEL=2 # 0=none 1=err 2=info 3=debug 4=flow
optee-os-flags += CFG_TEE_TA_LOG_LEVEL=3
optee-os-flags += CFG_ARM64_core=y
optee-os-flags += CROSS_COMPILE32="$(CROSS_COMPILE32)" CROSS_COMPILE64="$(CROSS_COMPILE64)"

.PHONY: optee-os
optee-os:
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C optee_os $(optee-os-flags)

.PHONY: clean-optee-os
clean-optee-os:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C optee_os $(optee-os-flags) clean

clean: clean-optee-os

#
# OP-TEE client (libteec)
#

optee-client-flags := CROSS_COMPILE="$(CROSS_COMPILE64)"
#optee-client-flags += CFG_TEE_SUPP_LOG_LEVEL=4 CFG_TEE_CLIENT_LOG_LEVEL=4

.PHONY: optee-client
optee-client:
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C optee_client $(optee-client-flags)

.PHONY: install-optee-client
install-optee-client: optee-client
	$(ECHO) '  INSTALL $@'
	$(Q)mkdir -p $(INSTALL_DIR)
	$(Q)$(MAKE) -C optee_client $(optee-client-flags) install EXPORT_DIR=$(CURDIR)/$(INSTALL_DIR)

install: install-optee-client

.PHONY: clean-optee-client
clean-optee-client:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C optee_client $(optee-client-flags) clean

clean: clean-optee-client

#
# OP-TEE tests (xtest)
#

optee-test-deps := optee-os

optee-test-flags := CROSS_COMPILE_HOST="$(CROSS_COMPILE64)" \
		    CROSS_COMPILE_TA="$(CROSS_COMPILE64)" \
		    TA_DEV_KIT_DIR=$(CURDIR)/optee_os/out/arm-plat-d02/export-ta_arm64 \
		    O=$(CURDIR)/optee_test/out
#optee-test-flags += CFG_TEE_TA_LOG_LEVEL=3

ifneq (,$(wildcard optee_test/TEE_Initial_Configuration-Test_Suite_v1_1_0_4-2014_11_07))
GP_TESTS=1
endif

ifeq ($(GP_TESTS),1)
optee-test-flags += CFG_GP_PACKAGE_PATH=$(CURDIR)/optee_test/TEE_Initial_Configuration-Test_Suite_v1_1_0_4-2014_11_07
optee-test-flags += COMPILE_NS_USER=64
optee-test-deps += optee-test-do-patch
endif


.PHONY: optee-test
optee-test: $(optee-test-deps)
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C optee_test $(optee-test-flags)

.PHONY: optee-test-do-patch
optee-test-do-patch:
	$(Q)$(MAKE) -C optee_test $(optee-test-flags) patch


.PHONY: install-optee-test
install-optee-test: optee-test
	$(Q)$(MAKE) -C optee_test $(optee-test-flags) install DESTDIR=$(CURDIR)/$(INSTALL_DIR)

install: install-optee-test

.PHONY: clean-optee-test
clean-optee-test:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C optee_test $(optee-test-flags) clean

clean: clean-optee-test

#
# Linux kernel
#

LINUX = linux/arch/arm64/boot/Image
DTB = linux/arch/arm64/boot/dts/hisilicon/hip05-d02.dtb

linux-flags := CROSS_COMPILE="$(CROSS_COMPILE64)" ARCH=arm64

# Install modules and firmware files
.PHONY: install-linux
install-linux: linux
	$(ECHO) '  INSTALL $@'
	$(Q)mkdir -p $(INSTALL_DIR)
	$(Q)$(MAKE) -C linux $(linux-flags) modules_install INSTALL_MOD_PATH=$(CURDIR)/$(INSTALL_DIR)
	$(Q)$(MAKE) -C linux $(linux-flags) firmware_install INSTALL_FW_PATH=$(CURDIR)/$(INSTALL_DIR)/lib/firmware

install: install-linux

.PHONY: linux
linux: linux/.config
	$(ECHO) '  BUILD   $@'
	$(Q)$(MAKE) -C linux $(linux-flags) Image modules dtbs

# FIXME: *lots* of modules are built uselessly
linux/.config:
	$(ECHO) '  GEN     $@'
	$(Q)$(MAKE) -C linux $(linux-flags) defconfig
	$(Q)cd linux ; ./scripts/config --enable TEE --enable OPTEE

clean-linux:
	$(ECHO) '  CLEAN   $@'
	$(Q)$(MAKE) -C linux $(linux-flags) clean
	$(ECHO) '  RM      linux/.config'
	$(Q)rm -f linux/.config

clean: clean-linux
