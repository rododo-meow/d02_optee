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

all: grub

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

