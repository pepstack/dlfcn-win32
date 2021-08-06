#######################################################################
# Makefile
#   Build libdl
#
# Author: 350137278@qq.com
#
# Update: 2021-06-22
#
# Show all predefinitions of gcc:
#
#   https://blog.csdn.net/10km/article/details/49023471
#
#   $ gcc -posix -E -dM - < /dev/null
#
#######################################################################
# MSYS_NT
shuname="$(shell uname)"
OSARCH=$(shell echo $(shuname)|awk -F '-' '{ print $$1 }')

# debug | release (default)
RELEASE = 1
BUILDCFG = release

# 32 | 64 (default)
BITS = 64

# is MINGW(1) or not(0)
ifneq ($(findstring $(OSARCH),  "MSYS_NT MINGW64_NT MINGW32_NT"),)
    MINGW_FOUND=1
else
    MINGW_FOUND=0
endif

ifeq ($(MINGW_FOUND), 0)
  $(error $(OSARCH) not supported !)
endif


###########################################################
# Compiler Specific Configuration

CC = gcc

# for gcc-8+
# -Wno-unused-const-variable
CFLAGS += -std=gnu99 -D_GNU_SOURCE -fPIC -Wall -Wno-unused-function -Wno-unused-variable
#......

# LDFLAGS += -lpthread -lm
#......


###########################################################
# Architecture Configuration

ifeq ($(RELEASE), 0)
	# debug: make RELEASE=0
	CFLAGS += -D_DEBUG -g
	BUILDCFG = debug
else
	# release: make RELEASE=1
	CFLAGS += -DNDEBUG -O3
	BUILDCFG = release
endif

ifeq ($(BITS), 32)
	# 32bits: make BITS=32
	CFLAGS += -m32 -D__MINGW32__
	LDFLAGS += -m32
else
	# 64bits: make BITS=64
	CFLAGS += -m64 -D__MINGW64__
	LDFLAGS += -m64
endif


###########################################################
# Project Specific Configuration
PREFIX = .
DISTROOT = $(PREFIX)/dist

# Given dirs for all source (*.c) files
SRC_DIR = $(PREFIX)/src


#----------------------------------------------------------
# dl

DL_DIR = $(SRC_DIR)/dl
DL_VERSION_FILE = $(DL_DIR)/VERSION
DL_VERSION = $(shell cat $(DL_VERSION_FILE))

DL_STATIC_LIB = libdl.a
DL_DYNAMIC_LIB = libdl.so.$(DL_VERSION)

DL_DISTROOT = $(DISTROOT)/libdl-$(DL_VERSION)
DL_DIST_LIBDIR=$(DL_DISTROOT)/lib/$(OSARCH)/$(BITS)/$(BUILDCFG)
#----------------------------------------------------------


# add other projects here:
#...


# Set all dirs for C source: './src/a ./src/b'
ALLCDIRS += $(SRCDIR) $(DL_DIR)
#...


# Get pathfiles for C source files: './src/a/1.c ./src/b/2.c'
CSRCS := $(foreach cdir, $(ALLCDIRS), $(wildcard $(cdir)/*.c))

# Get names of object files: '1.o 2.o'
COBJS = $(patsubst %.c, %.o, $(notdir $(CSRCS)))


# Given dirs for all header (*.h) files
INCDIRS += -I$(PREFIX) \
	-I$(SRC_DIR) \
	-I$(DL_DIR)
#...


MINGW_COBJS = $(patsubst %.c, %.o, $(notdir $(MINGW_CSRCS)))

###########################################################
# Build Target Configuration
.PHONY: all clean cleanall dist


all: $(DL_DYNAMIC_LIB).$(OSARCH) $(DL_STATIC_LIB).$(OSARCH)

#...


#----------------------------------------------------------
# http://www.gnu.org/software/make/manual/make.html#Eval-Function

define COBJS_template =
$(basename $(notdir $(1))).o: $(1)
	$(CC) $(CFLAGS) -c $(1) $(INCDIRS) -o $(basename $(notdir $(1))).o
endef
#----------------------------------------------------------


$(foreach src,$(CSRCS),$(eval $(call COBJS_template,$(src))))

$(foreach src,$(MINGW_CSRCS),$(eval $(call COBJS_template,$(src))))


help:
	@echo
	@echo "Build all libs and apps as the following"
	@echo
	@echo "Build 64 bits release (default):"
	@echo "    $$ make clean && make"
	@echo
	@echo "Build 32 bits debug:"
	@echo "    $$ make clean && make RELEASE=0 BITS=32"
	@echo
	@echo "Dist target into default path:"
	@echo "    $$ make clean && make dist"
	@echo
	@echo "Dist target into given path:"
	@echo "    $$ make DL_DISTROOT=/path/to/YourInstallDir dist"
	@echo
	@echo "Show make options:"
	@echo "    $$ make help"


#----------------------------------------------------------
$(DL_STATIC_LIB).$(OSARCH): $(COBJS) $(MINGW_COBJS)
	rm -f $@
	rm -f $(DL_STATIC_LIB)
	ar cr $@ $^
	ln -s $@ $(DL_STATIC_LIB)

$(DL_DYNAMIC_LIB).$(OSARCH): $(COBJS) $(MINGW_COBJS)
	$(CC) $(CFLAGS) -shared \
		-Wl,--soname=$(DL_DYNAMIC_LIB) \
		-Wl,--rpath='$(PREFIX):$(PREFIX)/lib:$(PREFIX)/libs:$(PREFIX)/libs/lib' \
		-o $@ \
		$^ \
		$(LDFLAGS) \
		$(MINGW_LINKS)
	ln -s $@ $(DL_DYNAMIC_LIB)
#----------------------------------------------------------

dist: all
	@mkdir -p $(DL_DISTROOT)/include/dl
	@mkdir -p $(DL_DIST_LIBDIR)
	@cp $(DL_DIR)/dlfcn.h $(DL_DISTROOT)/include/dl/
	@cp $(PREFIX)/$(DL_STATIC_LIB).$(OSARCH) $(DL_DIST_LIBDIR)/
	@cp $(PREFIX)/$(DL_DYNAMIC_LIB).$(OSARCH) $(DL_DIST_LIBDIR)/
	@cd $(DL_DIST_LIBDIR)/ && ln -sf $(PREFIX)/$(DL_STATIC_LIB).$(OSARCH) $(DL_STATIC_LIB)
	@cd $(DL_DIST_LIBDIR)/ && ln -sf $(PREFIX)/$(DL_DYNAMIC_LIB).$(OSARCH) $(DL_DYNAMIC_LIB)
	@cd $(DL_DIST_LIBDIR)/ && ln -sf $(DL_DYNAMIC_LIB) libdl.so


clean:
	-rm -f *.stackdump
	-rm -f $(COBJS) $(MINGW_COBJS)
	-rm -f $(DL_STATIC_LIB)
	-rm -f $(DL_DYNAMIC_LIB)
	-rm -f $(DL_STATIC_LIB).$(OSARCH)
	-rm -f $(DL_DYNAMIC_LIB).$(OSARCH)
	-rm -rf ./msvc/libdl/build
	-rm -rf ./msvc/libdl/target
	-rm -rf ./msvc/libdl_dll/build
	-rm -rf ./msvc/libdl_dll/target
	-rm -f ./msvc/*.VC.db


cleanall: clean
	-rm -rf $(DISTROOT)