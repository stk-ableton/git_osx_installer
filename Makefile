SHELL := /bin/bash
SUDO := sudo
C_INCLUDE_PATH := /usr/include
CPLUS_INCLUDE_PATH := /usr/include
LD_LIBRARY_PATH := /usr/lib

OSX_VERSION := 10.6
SDK_PATH := $(shell bin/find-dir  $(PWD)/MacOSX10.9.sdk /Developer/SDKs/MacOSX$(OSX_VERSION).sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX$(OSX_VERSION).sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform)
TARGET_FLAGS := -mmacosx-version-min=$(OSX_VERSION) -DMACOSX_DEPLOYMENT_TARGET=$(OSX_VERSION)

ifeq ("$(OSX_VERSION)", "10.6")
OSX_NAME := Snow Leopard
endif
ifeq ("$(OSX_VERSION)", "10.7")
OSX_NAME := Lion
endif
ifeq ("$(OSX_VERSION)", "10.8")
OSX_NAME := Mountain Lion
endif
ifeq ("$(OSX_VERSION)", "10.9")
OSX_NAME := Mavericks
endif
ifeq ("$(OSX_VERSION)", "10.10")
OSX_NAME := Yosemite
endif
ifeq ("$(OSX_VERSION)", "10.11")
OSX_NAME := El Capitan
endif

OSX_CODE := $(shell echo "$(OSX_NAME)" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

ARCH := Universal
ARCH_CODE := universal
ARCH_FLAGS_universal := -arch x86_64
ARCH_FLAGS_x86_64 := -arch x86_64

CFLAGS := $(TARGET_FLAGS) $(ARCH_FLAGS_${ARCH_CODE})
LDFLAGS := $(TARGET_FLAGS) $(ARCH_FLAGS_${ARCH_CODE})

BAK_FOLDER := $(shell date +%s)
PREFIX := /usr/local
GIT_PREFIX := $(PREFIX)/git

DOWNLOAD_LOCATION=https://www.kernel.org/pub/software/scm/git

XML_CATALOG_FILES=$(shell bin/find-file /usr/local/etc/xml/catalog)

TCL_VERSION = 8.6

BUILD_CODE := intel-$(ARCH_CODE)-$(OSX_CODE)
BUILD_DIR := build/$(BUILD_CODE)
DESTDIR := $(PWD)/stage/git-$(BUILD_CODE)-$(VERSION)
SUBMAKE := $(MAKE) C_INCLUDE_PATH="$(C_INCLUDE_PATH)" CPLUS_INCLUDE_PATH="$(CPLUS_INCLUDE_PATH)" LD_LIBRARY_PATH="$(LD_LIBRARY_PATH)" TARGET_FLAGS="$(TARGET_FLAGS)" CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" NO_GETTEXT=1 NO_DARWIN_PORTS=1 prefix=$(GIT_PREFIX) DESTDIR=$(DESTDIR)


CORES := $(shell bash -c "sysctl hw.ncpu | awk '{print \$$2}'")

vars:
	# OSX_NAME = $(OSX_NAME)
	# OSX_CODE = $(OSX_CODE)
	# ARCH = $(ARCH)
	# ARCH_CODE = $(ARCH_CODE)
	# CFLAGS = $(CFLAGS)
	# BUILD_CODE = $(BUILD_CODE)
	# PREFIX = $(PREFIX)
	# DESTDIR = $(DESTDIR)
	# GIT_PREFIX = $(GIT_PREFIX)
	# BUILD_DIR = $(BUILD_DIR)
	# SDK_PATH = $(SDK_PATH)

.PHONY: compile download install install-assets install-bin install-man install-subtree image package deploy reinstall setup readme

.SECONDARY:

/usr/local/etc/xml/catalog:
	brew install docbook

/usr/local/bin/xmlto:
	brew install xmlto

/usr/local/bin/asciidoc:
	brew install asciidoc


tmp/setup-verified: /usr/local/etc/xml/catalog /usr/local/bin/xmlto /usr/local/bin/asciidoc
	grep -q docbook-xsl /usr/local/etc/xml/catalog && exit 0 || (echo "You need docbook-xsl installed to build docs; If it is already installed, uninstall and reinstall it"; brew install docbook-xsl)
	touch	$@

setup: tmp/setup-verified

$(DESTDIR)$(GIT_PREFIX)/VERSION-$(VERSION)-$(BUILD_CODE):
	rm -f $(BUILD_DIR)/git-$(VERSION)/osx-installed*
	mkdir -p $(DESTDIR)$(GIT_PREFIX)
	touch $@

build/%.tar.gz:
	mkdir -p build
	curl -L -o build/$*.tar.gz.working "$(DOWNLOAD_LOCATION)/$*.tar.gz"
	mv build/$*.tar.gz.working build/$*.tar.gz

$(BUILD_DIR)/git-$(VERSION)/Makefile: build/git-$(VERSION).tar.gz
	mkdir -p $(BUILD_DIR)
	tar xzf build/git-$(VERSION).tar.gz -C $(BUILD_DIR)
	echo TCL_PATH=$(GIT_PREFIX)/tcl-tk/bin/tclsh$(TCL_VERSION) >$(BUILD_DIR)/git-$(VERSION)/config.mak
	echo TCLTK_PATH=$(GIT_PREFIX)/tcl-tk/bin/wish$(TCL_VERSION) >>$(BUILD_DIR)/git-$(VERSION)/config.mak
	touch $@

$(BUILD_DIR)/git-$(VERSION)/osx-built: $(BUILD_DIR)/git-$(VERSION)/Makefile
	[ -d $(DESTDIR)$(GIT_PREFIX) ] && $(SUDO) rm -rf $(DESTDIR) || echo ok
	mkdir -p $(DESTDIR)$(GIT_PREFIX)
	./build_tcl.sh && cp -r $(GIT_PREFIX)/tcl-tk $(DESTDIR)$(GIT_PREFIX)
	cd $(BUILD_DIR)/git-$(VERSION); $(SUBMAKE) -j $(CORES) all html strip
	touch $@

$(BUILD_DIR)/git-$(VERSION)/osx-built-keychain: $(BUILD_DIR)/git-$(VERSION)/Makefile
	cd $(BUILD_DIR)/git-$(VERSION)/contrib/credential/osxkeychain; $(SUBMAKE) CFLAGS="$(CFLAGS) -g -O2 -Wall"
	touch $@

$(BUILD_DIR)/git-$(VERSION)/osx-built-subtree: $(BUILD_DIR)/git-$(VERSION)/Makefile | setup
	cd $(BUILD_DIR)/git-$(VERSION)/contrib/subtree; $(SUBMAKE) XML_CATALOG_FILES="$(XML_CATALOG_FILES)" all html git-subtree.1
	touch $@

$(BUILD_DIR)/git-$(VERSION)/osx-installed-subtree: $(BUILD_DIR)/git-$(VERSION)/osx-built-subtree
	mkdir -p $(DESTDIR)
	cd $(BUILD_DIR)/git-$(VERSION)/contrib/subtree; $(SUBMAKE) XML_CATALOG_FILES="$(XML_CATALOG_FILES)" install install-man install-html
	touch $@

$(BUILD_DIR)/git-$(VERSION)/osx-installed-assets: $(BUILD_DIR)/git-$(VERSION)/osx-installed-bin
	mkdir -p $(DESTDIR)$(GIT_PREFIX)/etc
	cp assets/etc/gitconfig.default $(DESTDIR)$(GIT_PREFIX)/etc/gitconfig
	cat assets/etc/gitconfig.osxkeychain >> $(DESTDIR)$(GIT_PREFIX)/etc/gitconfig
	cp assets/uninstall.sh $(DESTDIR)$(GIT_PREFIX)/uninstall.sh
	sh -c "echo .DS_Store >> $(DESTDIR)$(GIT_PREFIX)/share/git-core/templates/info/exclude"
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cd $(DESTDIR)$(PREFIX)/bin; find ../git/bin -type f -exec ln -sf {} \;
	for man in man1 man5 man7; do mkdir -p $(DESTDIR)$(PREFIX)/share/man/$$man; (cd $(DESTDIR)$(PREFIX)/share/man/$$man; ln -sf ../../../git/share/man/$$man/* ./); done
	touch $@

$(BUILD_DIR)/git-$(VERSION)/osx-installed-bin: $(BUILD_DIR)/git-$(VERSION)/osx-built $(BUILD_DIR)/git-$(VERSION)/osx-built-keychain $(DESTDIR)$(GIT_PREFIX)/VERSION-$(VERSION)-$(BUILD_CODE)
	cd $(BUILD_DIR)/git-$(VERSION); $(SUBMAKE) INSTALL_SYMLINKS=1 install install-html
	cp $(BUILD_DIR)/git-$(VERSION)/contrib/credential/osxkeychain/git-credential-osxkeychain $(DESTDIR)$(GIT_PREFIX)/bin/git-credential-osxkeychain
	mkdir -p $(DESTDIR)$(GIT_PREFIX)/contrib/completion
	cp $(BUILD_DIR)/git-$(VERSION)/contrib/completion/git-completion.bash $(DESTDIR)$(GIT_PREFIX)/contrib/completion/
	cp $(BUILD_DIR)/git-$(VERSION)/contrib/completion/git-completion.zsh $(DESTDIR)$(GIT_PREFIX)/contrib/completion/
	cp $(BUILD_DIR)/git-$(VERSION)/contrib/completion/git-prompt.sh $(DESTDIR)$(GIT_PREFIX)/contrib/completion/
	# This is needed for Git-Gui, GitK
	mkdir -p $(DESTDIR)$(GIT_PREFIX)/lib/perl5/site_perl
	[ ! -f $(DESTDIR)$(GIT_PREFIX)/lib/perl5/site_perl/Error.pm ] && cp $(BUILD_DIR)/git-$(VERSION)/perl/private-Error.pm $(DESTDIR)$(GIT_PREFIX)/lib/perl5/site_perl/Error.pm || echo done
	touch $@

$(BUILD_DIR)/git-$(VERSION)/osx-installed-man: build/git-manpages-$(VERSION).tar.gz $(BUILD_DIR)/git-$(VERSION)/osx-installed-bin
	mkdir -p $(DESTDIR)$(GIT_PREFIX)/share/man
	tar xzfo build/git-manpages-$(VERSION).tar.gz -C $(DESTDIR)$(GIT_PREFIX)/share/man
	touch $@

$(BUILD_DIR)/git-$(VERSION)/osx-installed: $(BUILD_DIR)/git-$(VERSION)/osx-installed-bin $(BUILD_DIR)/git-$(VERSION)/osx-installed-man $(BUILD_DIR)/git-$(VERSION)/osx-installed-assets $(BUILD_DIR)/git-$(VERSION)/osx-installed-subtree
	$(SUDO) chown -R root:wheel $(DESTDIR)$(GIT_PREFIX)
	find $(DESTDIR)$(GIT_PREFIX) -type d -exec chmod ugo+rx {} \;
	find $(DESTDIR)$(GIT_PREFIX) -type f -exec chmod ugo+r {} \;
	touch $@

$(BUILD_DIR)/git-$(VERSION)/osx-built-assert-$(ARCH_CODE): $(BUILD_DIR)/git-$(VERSION)/osx-built
ifeq ("$(ARCH_CODE)", "universal")
	File $(BUILD_DIR)/git-$(VERSION)/git
	File $(BUILD_DIR)/git-$(VERSION)/contrib/credential/osxkeychain/git-credential-osxkeychain
else
	[ "$$(File $(BUILD_DIR)/git-$(VERSION)/git | cut -f 5 -d' ')" == "$(ARCH_CODE)" ]
	[ "$$(File $(BUILD_DIR)/git-$(VERSION)/contrib/credential/osxkeychain/git-credential-osxkeychain | cut -f 5 -d' ')" == "$(ARCH_CODE)" ]
endif
	touch $@


disk-image/VERSION-$(VERSION)-$(ARCH_CODE)-$(OSX_CODE):
	rm -f disk-image/*.pkg disk-image/VERSION-* disk-image/.DS_Store
	touch "$@"

disk-image/git-$(VERSION).pkg: disk-image/VERSION-$(VERSION)-$(ARCH_CODE)-$(OSX_CODE) $(DESTDIR)$(GIT_PREFIX)/VERSION-$(VERSION)-$(BUILD_CODE) $(BUILD_DIR)/git-$(VERSION)/osx-installed $(BUILD_DIR)/git-$(VERSION)/osx-built-assert-$(ARCH_CODE)
	pkgbuild --identifier com.git.pkg --version $(VERSION) --root $(DESTDIR)$(PREFIX) --install-location $(PREFIX) --component-plist ./git-components.plist disk-image/git-$(VERSION).pkg

git-%.dmg: disk-image/git-%.pkg
	rm -f git-$(VERSION)*.dmg
	hdiutil create git-$(VERSION).uncompressed.dmg -fs HFS+ -srcfolder disk-image -volname "Git $(VERSION) $(OSX_NAME) Intel $(ARCH)" -ov
	hdiutil convert -format UDZO -o $@ git-$(VERSION).uncompressed.dmg
	rm -f git-$(VERSION).uncompressed.dmg

tmp/deployed-%-$(BUILD_CODE): git-%.dmg
	mkdir -p tmp
	scp git-$(VERSION).dmg timcharper@frs.sourceforge.net:/home/pfs/project/git-osx-installer | tee $@.working
	mv $@.working $@

package: disk-image/git-$(VERSION).pkg
install-assets: $(BUILD_DIR)/git-$(VERSION)/osx-installed-assets
install-bin: $(BUILD_DIR)/git-$(VERSION)/osx-installed-bin
install-man: $(BUILD_DIR)/git-$(VERSION)/osx-installed-man
install-subtree: $(BUILD_DIR)/git-$(VERSION)/osx-installed-subtree

install: $(BUILD_DIR)/git-$(VERSION)/osx-installed

download: build/git-$(VERSION).tar.gz build/git-manpages-$(VERSION).tar.gz

compile: $(BUILD_DIR)/git-$(VERSION)/osx-built $(BUILD_DIR)/git-$(VERSION)/osx-built-keychain $(BUILD_DIR)/git-$(VERSION)/osx-built-subtree

deploy: tmp/deployed-$(VERSION)-$(BUILD_CODE)

tmp/deployed-readme: README.md
	scp README.md timcharper@frs.sourceforge.net:/home/pfs/project/git-osx-installer | tee $@.working
	mv $@.working $@

readme: tmp/deployed-readme


clean:
	$(SUDO) rm -rf $(BUILD_DIR)/git-$(VERSION)/osx-* $(DESTDIR)
	[ -d $(BUILD_DIR)/git-$(VERSION) ] && cd $(BUILD_DIR)/git-$(VERSION) && $(SUBMAKE) clean || echo done
	[ -d $(BUILD_DIR)/git-$(VERSION)/contrib/credential/osxkeychain ] && cd $(BUILD_DIR)/git-$(VERSION)/contrib/credential/osxkeychain && $(SUBMAKE) clean || echo done
	[ -d $(BUILD_DIR)/git-$(VERSION)/contrib/subtree ] && cd $(BUILD_DIR)/git-$(VERSION)/contrib/subtree && $(SUBMAKE) clean || echo done

reinstall:
	$(SUDO) rm -rf /usr/local/git/VERSION-*
	rm -f $(BUILD_DIR)/git-$(VERSION)/osx-installed*
	$(SUBMAKE) install

image: git-$(VERSION).dmg
