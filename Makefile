.PHONY: all build dmg install uninstall clean run

all: dmg

build:
	@chmod +x Scripts/*.sh
	@./Scripts/build.sh

dmg: build
	@./Scripts/create_dmg.sh

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
