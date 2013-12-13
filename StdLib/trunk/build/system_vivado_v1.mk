
# Detect project name
export PROJECT = $(notdir $(PWD))

# Top level directories
export PROJ_DIR = $(abspath $(PWD))
export TOP_DIR  = $(abspath $(PROJ_DIR)/../..)

# Project Build Directory
export OUT_DIR  = $(abspath $(TOP_DIR)/build/$(PROJECT))
export IMPL_DIR = $(OUT_DIR)/$(VIVADO_PROJECT).runs/impl_1

# Synthesis Variables
export ISE_DIR          = $(abspath $(PROJ_DIR)/ise)
export VIVADO_DIR       = $(abspath $(PROJ_DIR)/vivado)
export VIVADO_PROJECT   = $(PROJECT)_project
export VIVADO_DEPEND    = $(OUT_DIR)/$(PROJECT)_project.xpr
export VIVADO_BUILD_DIR = $(TOP_DIR)/modules/StdLib/build
export PROJECT_SETUP    = $(abspath $(PROJ_DIR)/vivado/project_setup.tcl)
export BUILD_FLAG       = 0

# Images Directory
export IMAGES_DIR = $(abspath $(PROJ_DIR)/images)

# Get Project Version
export PRJ_VERSION = $(shell grep MAKE_VERSION $(PROJ_DIR)/Version.vhd | sed 's|.*x"\(\S\+\)";.*|\1|')

# Core Directories
export CORE_LISTS = $(abspath $(foreach ARG,$(MODULE_DIRS),$(ARG)/cores.txt))
export CORE_FILES = $(abspath $(foreach A1,$(MODULE_DIRS),$(foreach A2,$(shell grep -v "\#" $(A1)/cores.txt),$(A1)/$(A2))))

# Source Files
export SRC_LISTS   = $(abspath $(foreach ARG,$(MODULE_DIRS),$(ARG)/sources.txt))
export RTL_FILES   = $(abspath $(foreach ARG,$(MODULE_DIRS),$(shell grep -v "\#" $(ARG)/sources.txt | sed 's|\(\S\+\)\(\s\+\)\(\S\+\)\(\s\+\)\(\S\+\).*|$(ARG)/\5|')))

# XDC Files
export XDC_LIST    = $(PROJ_DIR)/constraints.txt))
export XDC_FILES   = $(abspath $(foreach ARG,$(shell grep -v "\#" $(PROJ_DIR)/constraints.txt | grep "\.xdc"), $(PROJ_DIR)/$(ARG)))

define ACTION_HEADER
@echo 
@echo    "============================================================================="
@echo    $(1)
@echo    "   Project = $(PROJECT)"
@echo    "   Out Dir = $(OUT_DIR)"
@echo    "   Version = $(PRJ_VERSION)"
@echo -e "   Changed = $(foreach ARG,$?,$(ARG)\n            )"
@echo    "============================================================================="
@echo 	
endef

.PHONY : all
all: target

.PHONY : test
test:
	@echo PROJECT: $(PROJECT)
	@echo PROJ_DIR: $(PROJ_DIR)
	@echo PRJ_VERSION: $(PRJ_VERSION)
	@echo PRJ_PART: $(PRJ_PART)
	@echo TOP_DIR: $(TOP_DIR)
	@echo OUT_DIR: $(OUT_DIR)
	@echo IMAGES_DIR: $(OUT_DIR)
	@echo ISE_DIR: $(ISE_DIR)
	@echo IMPL_DIR: $(IMPL_DIR)
	@echo VIVADO_DIR: $(VIVADO_DIR)
	@echo VIVADO_PROJECT: $(VIVADO_PROJECT)
	@echo PROJECT_SETUP: $(PROJECT_SETUP)
	@echo MODULE_DIRS: $(MODULE_DIRS)
	@echo CORE_LISTS: $(CORE_LISTS)
	@echo CORE_FILES:
	@echo -e "$(foreach ARG,$(CORE_FILES), $(ARG)\n)"
	@echo XDC_LISTS: $(XDC_LISTS)
	@echo XDC_FILES: 
	@echo -e "$(foreach ARG,$(XDC_FILES),  $(ARG)\n)"
	@echo SRC_LISTS: $(SRC_LISTS)
	@echo RTL_FILES: 
	@echo -e "$(foreach ARG,$(RTL_FILES),  $(ARG)\n)"

#### Build Location ########################################
.PHONY : dir
dir:

#### Check Source Files ###################################

%.txt : 
	@test -d $*.txt || echo "$*.txt does not exist"; false;

%.vhd : 
	@test -d $*.vhd || echo "$*.vhd does not exist"; false;

%.v : 
	@test -d $*.v || echo "$*.v does not exist"; false;

%.xdc : 
	@test -d $*.xdc || echo "$*.xdc does not exist"; false;

#### Vivado Project #############################################
$(VIVADO_DEPEND) : $(CORE_LISTS) $(SRC_LISTS) $(XDC_LISTS) $(CORE_FILES) $(PROJECT_SETUP)
	$(call ACTION_HEADER,"Vivado Project Creation")
	@test -d $(TOP_DIR)/build/ || { \
			 echo ""; \
			 echo "Build directory missing!"; \
			 echo "You must create a build directory at the top level."; \
			 echo ""; \
			 echo "This directory can either be a normal directory:"; \
			 echo "   mkdir $(TOP_DIR)/build"; \
			 echo ""; \
			 echo "Or by creating a symbolic link to a directory on another disk:"; \
			 echo "   ln -s /tmp/build $(TOP_DIR)/build"; \
			 echo ""; false; }
	@test -d $(OUT_DIR) || mkdir $(OUT_DIR)
	@cd $(OUT_DIR); vivado -mode batch -source $(VIVADO_BUILD_DIR)/vivado_project_v1.tcl

#### Vivado Batch #############################################
$(IMPL_DIR)/$(PROJECT).bit : $(RTL_FILES) $(XDC_FILES) $(CORE_FILES) $(VIVADO_DEPEND)
	$(call ACTION_HEADER,"Vivado Build")
	@cd $(OUT_DIR); vivado -mode batch -source $(VIVADO_BUILD_DIR)/vivado_build_v1.tcl

#### Bitfile Copy #############################################
$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit : $(IMPL_DIR)/$(PROJECT).bit
	@cp $< $@
	@echo ""
	@echo "Bit file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

#### Vivado Interactive #############################################
.PHONY : interactive
interactive : $(VIVADO_DEPEND)
	$(call ACTION_HEADER,"Vivado Interactive")
	@cd $(OUT_DIR); vivado -mode tcl

#### Vivado Gui #############################################
.PHONY : gui
gui : $(VIVADO_DEPEND)
	$(call ACTION_HEADER,"Vivado GUI")
	@cd $(OUT_DIR); vivado -mode batch -source $(VIVADO_BUILD_DIR)/vivado_gui_v1.tcl

#### Prom ##################################################
PROM_OPTIONS_FILE = $(ISE_DIR)/promgen_options.txt
$(IMPL_DIR)/$(PROJECT).mcs: $(PROM_OPTIONS_FILE) $(IMPL_DIR)/$(PROJECT).bit
	$(call ACTION_HEADER,"PROM Generate")
	@cd $(OUT_DIR); promgen \
	  -f $(PROM_OPTIONS_FILE) \
	  -u 0 $(IMPL_DIR)/$(PROJECT).bit

#### Prom Copy ###############################################
$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).mcs : $(IMPL_DIR)/$(PROJECT).mcs
	@cp $< $@
	@echo ""
	@echo "Prom file copied to $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

#### BitBin ##################################################
$(IMPL_DIR)/$(PROJECT).bitbin : $(IMPL_DIR)/$(PROJECT).bit
	$(call ACTION_HEADER,"Binary Bit file Generate")
	@cd $(OUT_DIR); promgen -intstyle silent -p bin -data_width 32 -b -w -u 0x0 $(IMPL_DIR)/$(PROJECT).bit
	@mv $(IMPL_DIR)/$(PROJECT).bin $(IMPL_DIR)/$(PROJECT).bitbin

#### BitBin Copy #############################################
$(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bitbin : $(IMPL_DIR)/$(PROJECT).bitbin
	@cp $< $@
	@echo ""
	@echo "Binary bit file generated at $@"
	@echo "Don't forget to 'svn commit' when the image is stable!"

#### Makefile Targets ######################################
.PHONY : bit
bit    : $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bit 

.PHONY : prom
prom   : bit $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).mcs

.PHONY  : bitbin
bitbin  : bit $(IMAGES_DIR)/$(PROJECT)_$(PRJ_VERSION).bitbin

#### Clean #################################################
.PHONY : clean
clean:
	rm -rf $(OUT_DIR) 


