KVERSION := $(shell uname -r)
KDIR := /lib/modules/${KVERSION}/build
MAKEFLAGS+="-j $(shell nproc)"

# Use same compiler as the running kernel to avoid flag mismatches (e.g. clang-only flags with gcc).
# Prefer /proc/version since kernel cc-name can be unavailable for out-of-tree builds.
KERNEL_CLANG := $(shell grep -q clang /proc/version 2>/dev/null && echo 1)
ifneq ($(KERNEL_CLANG),1)
KERNEL_CC := $(shell $(MAKE) -C $(KDIR) -s cc-name 2>/dev/null || echo "gcc")
ifeq ($(KERNEL_CC),clang)
    CC ?= clang
    LD ?= ld.lld
else
    CC ?= gcc
    LD ?= ld
endif
endif

# When kernel was built with clang, use LLVM=1 and let kernel set CC/LD; otherwise pass CC/LD.
BUILD_FLAGS := $(if $(KERNEL_CLANG),LLVM=1,CC=$(CC) LD=$(LD))

# Clang-built kernels need generated/autoconf.h; distro headers sometimes omit it.
# modules_prepare can fail (e.g. missing arch/arm/crypto/Kconfig); use the script instead.
KERNEL_AUTOCONF := $(KDIR)/include/generated/autoconf.h
check-kernel-headers:
	@if [ -n "$(KERNEL_CLANG)" ] && ! [ -r "$(KERNEL_AUTOCONF)" ]; then \
		echo >&2 '***'; \
		echo >&2 '***  Missing $(KERNEL_AUTOCONF)'; \
		echo >&2 '***  Generate it with: sudo ./scripts/gen-autoconf.sh'; \
		echo >&2 '***  (If that fails, try: sudo make -C $(KDIR) modules_prepare)'; \
		echo >&2 '***'; \
		exit 1; \
	fi

default: check-kernel-headers clean
	$(MAKE) -C $(KDIR) M=$$PWD $(BUILD_FLAGS)

debug: check-kernel-headers clean
	$(MAKE) -C $(KDIR) M=$$PWD $(BUILD_FLAGS) ccflags-y="-Og -g3 -DDEBUG"

clean:
	$(MAKE) -C $(KDIR) M=$$PWD clean

unload:
	./modules_load.sh unload

load: unload
	./modules_load.sh

test:
	$(MAKE) debug &&\
		$(MAKE) load
	$(MAKE) clean

remove: clean
	./uninstall.sh

install: clean
	./install.sh
	./install/firmware.sh --skip-disclaimer

install-debug: clean
	./install.sh --debug
	./install/firmware.sh --skip-disclaimer
