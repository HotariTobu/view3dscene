# build / clean --------------------------------------------------------------

# Hint: use
#   export CASTLE_ENGINE_TOOL_OPTIONS='--mode=debug'
#   make
# to build in debug mode.

.PHONY: compile
compile:
	./compile.sh

.PHONY: clean
clean:
	castle-engine clean
	castle-engine clean --manifest-name=CastleEngineManifest.tovrmlx3d.xml
# remove also macOS stuff
	rm -Rf view3dscene.app \
	       tovrmlx3d.app \
	       macosx/view3dscene.app \
	       macosx/tovrmlx3d.app \
	       macosx/*.dmg

# install / uninstall --------------------------------------------------------
#
# By default view3dscene is installed system-wide to /usr/local .
# You can run "make" followed by "sudo make install" to have it
# ready on a typical Unix system.

# Standard installation dirs, following conventions on
# http://www.gnu.org/prep/standards/html_node/Directory-Variables.html#Directory-Variables
PREFIX=$(DESTDIR)/usr/local
EXEC_PREFIX=$(PREFIX)
BINDIR=$(EXEC_PREFIX)/bin
DATAROOTDIR=$(PREFIX)/share
DATADIR=$(DATAROOTDIR)

.PHONY: install
install:
	install -d $(BINDIR)
	install view3dscene $(BINDIR)
	install tovrmlx3d $(BINDIR)
	install -d  $(DATADIR)
	cd freedesktop/ && ./install.sh "$(DATADIR)"

.PHONY: uninstall
uninstall:
	rm -f $(BINDIR)/view3dscene \
	      $(BINDIR)/tovrmlx3d
	cd freedesktop/ && ./uninstall.sh "$(DATADIR)"

# code generation ------------------------------------------------------------

# Run a couple of child targets to autogenerate some code
.PHONY: generate-code
generate-code:
	$(MAKE) -C images/
	$(MAKE) -C internal_scenes/
	$(MAKE) -C screen_effects/

# Clean autogenerated code
.PHONY: clean-code
clean-code:
	$(MAKE) -C images/ clean
	$(MAKE) -C internal_scenes/ clean
	$(MAKE) -C screen_effects/ clean
