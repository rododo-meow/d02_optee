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

CROSS_COMPILE ?= "ccache aarch64-linux-gnu-"

all: arm-trusted-firmware grub

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

BL32=pouic.bin

ARMTF_FLAGS := PLAT=d02
ARMTF_FLAGS += SPD=opteed
ARMTF_FLAGS += DEBUG=1
#ARMTF_FLAGS += LOG_LEVEL=40

ARMTF_EXPORTS += CROSS_COMPILE='"$(CROSS_COMPILE)"'
ARMTF_EXPORTS += BL32=$(CURDIR)/$(BL32)

define arm-tf-make
	+$(Q)export $(ARMTF_EXPORTS) ; \
		$(MAKE) -C arm-trusted-firmware $(ARMTF_FLAGS) $(1) $(2)
endef

.PHONY: arm-trusted-firmware
arm-trusted-firmware:
	$(ECHO) '  BUILD   $@'
	$(call arm-tf-make, bl1 fip)

clean-arm-trusted-firmware:
	$(ECHO) '  CLEAN   $@'
	$(call arm-tf-make, clean)

clean: clean-arm-trusted-firmware

