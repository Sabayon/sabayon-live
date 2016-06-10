SUBDIRS =
DESTDIR = 
UBINDIR ?= /usr/bin
LIBDIR ?= /usr/lib
SBINDIR ?= /sbin
USBINDIR ?= /usr/sbin
BINDIR ?= /bin
LIBEXECDIR ?= /usr/libexec
SYSCONFDIR ?= /etc
SYSTEMD_UNITDIR ?= $(LIBDIR)/systemd/system
SYSV_INITDIR = /etc/init.d

all:
	for d in $(SUBDIRS); do $(MAKE) -C $$d; done

clean:
	for d in $(SUBDIRS); do $(MAKE) -C $$d clean; done

install:
	for d in $(SUBDIRS); do $(MAKE) -C $$d install; done

	install -d $(DESTDIR)/$(LIBEXECDIR)
	install -m 0755 installer-{text,gui}.sh $(DESTDIR)/$(LIBEXECDIR)/
	install -m 0755 sabayonlive.sh $(DESTDIR)/$(LIBEXECDIR)/
	install -m 0755 x-setup.sh $(DESTDIR)/$(LIBEXECDIR)/
	install -m 0755 cdeject.sh $(DESTDIR)/$(LIBEXECDIR)/

	install -d $(DESTDIR)/$(SBINDIR)
	install -d $(DESTDIR)/$(BINDIR)
	install -m 0755 logscript.sh $(DESTDIR)/$(SBINDIR)/
	install -m 0755 *-functions.sh $(DESTDIR)/$(SBINDIR)/
	install -m 0755 bashlogin $(DESTDIR)/$(BINDIR)/
	install -m 0755 vga-cmd-parser $(DESTDIR)/$(BINDIR)/
	install -m 0755 gpu-configuration $(DESTDIR)/$(SBINDIR)/

	install -d $(DESTDIR)/$(USBINDIR)
	install -m 0755 net-setup $(DESTDIR)/$(USBINDIR)/
	
	install -d $(DESTDIR)/$(UBINDIR)
	install -m 0755 livespawn $(DESTDIR)/$(UBINDIR)/
	install -m 0755 sabutil $(DESTDIR)/$(UBINDIR)/
	install -m 0755 sabayon-live-check $(DESTDIR)/$(UBINDIR)/
	install -m 0755 sabayon-welcome-loader $(DESTDIR)/$(UBINDIR)/

	install -d $(DESTDIR)/$(SYSCONFDIR)/sabayon
	install -m 0644 sabayon-welcome-loader.desktop $(DESTDIR)/$(SYSCONFDIR)/sabayon

	install -d $(DESTDIR)/$(SYSTEMD_UNITDIR)/
	install -m 0644 *.service $(DESTDIR)/$(SYSTEMD_UNITDIR)/

	install -d $(DESTDIR)/$(SYSV_INITDIR)/
	install -m 0755 x-setup-init.d $(DESTDIR)/$(SYSV_INITDIR)/x-setup
	install -m 0755 sabayonlive $(DESTDIR)/$(SYSV_INITDIR)/
	install -m 0755 installer-gui $(DESTDIR)/$(SYSV_INITDIR)/
	install -m 0755 installer-text $(DESTDIR)/$(SYSV_INITDIR)/
	install -m 0755 cdeject $(DESTDIR)/$(SYSV_INITDIR)/
