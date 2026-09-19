.PHONY: all build install uninstall clean run

all: build

build:
	@chmod +x Scripts/*.sh
	@./Scripts/build.sh

install: build
	@echo "Installing requires root privileges..."
	@sudo ./Scripts/install.sh

uninstall:
	@echo "Uninstalling requires root privileges..."
	@sudo ./Scripts/uninstall.sh

clean:
	@rm -rf build

run: build
	@open build/LidSleepManager.app
