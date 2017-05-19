
OS := $(shell uname -s)
MINGW := $(findstring MINGW,$(OS))
THIS_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))


########## PATHS ##########

llvm_cflags = $(shell llvm-config --cflags --ldflags) -lclang
ifeq ($(OS),Linux)
    llvm_cflags += -fPIC
    so := .so
else
 ifeq ($(MINGW),MINGW)
    so := .dll
 else
    $(error unknown platform)
 endif
endif

luajit := luajit
asciidoc := asciidoctor


########## OPTIONS ##########

OPTLEV ?= 2
DEBUG ?= 0
SAN ?= 0
WARN := -std=c99 -pedantic -Wall -Werror-implicit-function-declaration
CFLAGS ?=
CFLAGS += $(llvm_cflags)

ifneq ($(SAN),0)
    CFLAGS += -fsanitize=address,undefined
endif

ifneq ($(DEBUG),0)
    CFLAGS += -g
endif

########## RULES ##########

libljclang_support$(so): ljclang_support.c Makefile
	$(CC) $(CFLAGS) $(WARN) -O$(OPTLEV) -shared $< $(lib) -o $@


.PHONY: clean bootstrap doc

clean:
	rm -f libljclang_support$(so)

CKIND_LUA := ljclang_cursor_kind.lua
EXTRACT_OPTS := -R -p '^CXCursor_' -x '_First' -x '_Last' -x '_GCCAsmStmt' -x '_MacroInstantiation' -s '^CXCursor_' \
    -1 'return { name={' -2 '}, }' -Q

# Generate list of CXCursorKind names
bootstrap:
	@echo 'return {}' > $(CKIND_LUA)
	LD_LIBRARY_PATH=$(THIS_DIR) $(luajit) ./extractdecls.lua $(EXTRACT_OPTS) $(incdir)/clang-c/Index.h > $(CKIND_LUA).tmp
	@mv $(CKIND_LUA).tmp $(CKIND_LUA)
	@printf "\033[1mGenerated $(CKIND_LUA)\033[0m\n"

doc:
	$(asciidoc) README.adoc

# Usage example:
# BINDIR=~/bin make install
install:
# XXX: MAKECMDGOALS is a list, i.e. will not be effective for e.g. "make install qwe"
ifeq ($(MAKECMDGOALS),install)
ifeq ($(BINDIR),)
    $(error "Must pass $$BINDIR with the environment")
endif
endif
	sed "s|LJCLANG_DEV_DIR|$(THIS_DIR)|g" ./mgrep.sh.in > $(BINDIR)/mgrep
	chmod +x $(BINDIR)/mgrep
