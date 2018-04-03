
DTC ?= dtc
CPP = cpp
DT_CHECKER = ../yaml-bindings/dt-validate.py
DT_DOC_CHECKER = ../yaml-bindings/tools/dt-doc-validate

MAKEFLAGS += -rR --no-print-directory

# Do not:
# o  use make's built-in rules and variables
#    (this increases performance and avoids hard-to-debug behaviour);
# o  print "Entering directory ...";
MAKEFLAGS += -rR --no-print-directory

# To put more focus on warnings, be less verbose as default
# Use 'make V=1' to see the full commands

ifeq ("$(origin V)", "command line")
  KBUILD_VERBOSE = $(V)
endif
ifndef KBUILD_VERBOSE
  KBUILD_VERBOSE = 0
endif

# Beautify output
# ---------------------------------------------------------------------------
#
# Normally, we echo the whole command before executing it. By making
# that echo $($(quiet)$(cmd)), we now have the possibility to set
# $(quiet) to choose other forms of output instead, e.g.
#
#         quiet_cmd_cc_o_c = Compiling $(RELDIR)/$@
#         cmd_cc_o_c       = $(CC) $(c_flags) -c -o $@ $<
#
# If $(quiet) is empty, the whole command will be printed.
# If it is set to "quiet_", only the short version will be printed. 
# If it is set to "silent_", nothing will be printed at all, since
# the variable $(silent_cmd_cc_o_c) doesn't exist.
#
# A simple variant is to prefix commands with $(Q) - that's useful
# for commands that shall be hidden in non-verbose mode.
#
#       $(Q)ln $@ :<
#
# If KBUILD_VERBOSE equals 0 then the above command will be hidden.
# If KBUILD_VERBOSE equals 1 then the above command is displayed.

ifeq ($(KBUILD_VERBOSE),1)
  quiet =
  Q =
else
  quiet=quiet_
  Q = @
endif

# If the user is running make -s (silent mode), suppress echoing of
# commands

ifneq ($(filter 4.%,$(MAKE_VERSION)),)	# make-4
ifneq ($(filter %s ,$(firstword x$(MAKEFLAGS))),)
  quiet=silent_
endif
else					# make-3.8x
ifneq ($(filter s% -s%,$(MAKEFLAGS)),)
  quiet=silent_
endif
endif

ifeq ("$(origin C)", "command line")
  KBUILD_CHECKSRC = $(C)
endif
ifndef KBUILD_CHECKSRC
  KBUILD_CHECKSRC = 0
endif

export quiet Q KBUILD_VERBOSE KBUILD_CHECKSRC

%/: DTB	= $(patsubst %.dts,%.dtb,$(shell find $@ -name \*.dts))

%/: FORCE
	$(Q)$(MAKE) DTB="$(DTB)"

DTB ?= $(patsubst %.dts,%.dtb,$(shell find src/ -name \*.dts))

src	:= src/
obj	:= src/

ifneq ($(KBUILD_CHECKSRC),0)
  DTYAML = $(patsubst %.dtb,%.dt.yaml,$(DTB))
endif

PHONY += all
all: $(DTB) $(DTYAML)

include scripts/Kbuild.include

cmd_files := $(wildcard $(foreach f,$(DTB),$(dir $(f)).$(notdir $(f)).cmd))

ifneq ($(cmd_files),)
  include $(cmd_files)
endif

quiet_cmd_clean    = CLEAN   $(obj)
      cmd_clean    = rm -f $(__clean-files)

dtc-tmp = $(subst $(comma),_,$(dot-target).dts.tmp)

dtc_cpp_flags  = -Wp,-MD,$(depfile).pre.tmp -nostdinc		\
                 -Iinclude -I$(src) -Isrc -Itestcase-data	\
                 -undef -D__DTS__

quiet_cmd_dtc = DTC     $@
cmd_dtc = $(CPP) $(dtc_cpp_flags) -x assembler-with-cpp -o $(dtc-tmp) $< ; \
        $(DTC) -O $(2) -o $@ -b 0 \
                -i $(src) $(DTC_FLAGS) \
                -d $(depfile).dtc.tmp $(dtc-tmp) ; \
        cat $(depfile).pre.tmp $(depfile).dtc.tmp > $(depfile)

ifneq ($(KBUILD_CHECKSRC),0)
  ifeq ($(KBUILD_CHECKSRC),2)
    quiet_cmd_force_checksrc = CHECK   $@
          cmd_force_checksrc = $(DT_CHECKER) $@ ;
  else
      quiet_cmd_checksrc     = CHECK   $@
            cmd_checksrc     = $(DT_CHECKER) $@ ;
  endif
endif

define rule_dt_yaml
        $(call echo-cmd,dtc) $(cmd_dtc) ;                                   \
        $(call echo-cmd,checksrc) $(cmd_checksrc)
endef

dt_yaml_cmd_files := $(wildcard $(foreach f,$(DTYAML),$(dir $(f)).$(notdir $(f)).cmd))

ifneq ($(dt_yaml_cmd_files),)
  include $(dt_yaml_cmd_files)
endif

%.dt.yaml: %.dts FORCE
	$(call if_changed_rule,dt_yaml,yaml)
	$(call cmd,force_checksrc)

%.dtb: %.dts FORCE
	$(call if_changed_dep,dtc,dtb)

BINDINGS := $(shell find Bindings/ -name \*.yaml)

PHONY += checkbindings
checkbindings: $(BINDINGS)

quiet_cmd_chk_binding = CHKBIND	$@
      cmd_chk_binding = $(DT_DOC_CHECKER) $@

%.yaml: FORCE
	$(call cmd,chk_binding)

RCS_FIND_IGNORE := \( -name SCCS -o -name BitKeeper -o -name .svn -o -name CVS \
                   -o -name .pc -o -name .hg -o -name .git \) -prune -o

PHONY += clean
clean: __clean-files = $(DTB) $(patsubst %.dtb,%.dt.yaml,$(DTB))
clean: FORCE
	$(call cmd,clean)
	@find . $(RCS_FIND_IGNORE) \
		\( -name '.*.cmd' \
		-o -name '.*.d' \
		-o -name '.*.tmp' \
		\) -type f -print | xargs rm -f

help:
	@echo "Targets:"
	@echo "  all:                   Build all device tree binaries"
	@echo "  clean:                 Clean all generated files"
	@echo ""
	@echo "  checkbindings          Check all binding schema docs"
	@echo ""
	@echo "  src/<dir>/<DTS>.dtb    Build a single device tree binary"
	@echo "  src/<dir>/             Build all device tree binaries in specified directory"

PHONY += FORCE
FORCE:

.PHONY: $(PHONY)
