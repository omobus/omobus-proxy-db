# Copyright (c) 2006 - 2022 omobus-agent-db authors, see the included COPYRIGHT file.

PACKAGE_NAME 	= omobus-proxy-db
PACKAGE_VERSION = 3.5.34
COPYRIGHT 	= Copyright (c) 2006 - 2022 ak obs, ltd. <info@omobus.net>
SUPPORT 	= Support and bug reports: <support@omobus.net>
AUTHOR		= Author: Igor Artemov <i_artemov@omobus.net>
BUGREPORT	= support@omobus.net
ETC_PATH 	= /etc/omobus.d

INSTALL		= install
RM		= rm -f
CP		= cp
CHOWN 		= chown
TAR		= tar -cf
BZIP		= bzip2

DISTR_NAME	= $(PACKAGE_NAME)-$(PACKAGE_VERSION)

all:
	@echo "$(PACKAGE_NAME) $(PACKAGE_VERSION)"

install:
	$(INSTALL) -m 0644 *.xconf *.sh omobus.ldif *.sql $(ETC_PATH)
	$(CP) -r connections/ $(ETC_PATH)
	$(CP) -r transactions/ $(ETC_PATH)
	$(CP) -r kernels/ $(ETC_PATH)
	$(CP) -r queries/ $(ETC_PATH)
	$(CP) -r roles/ $(ETC_PATH)
	$(CP) -r schemas/ $(ETC_PATH)
	$(CHOWN) -Rv omobus:omobus $(ETC_PATH)/*
	$(INSTALL) -m 0644 systemd/*.service /etc/systemd/system
	$(CHOWN) root:root /etc/systemd/system/omobus-*.service
