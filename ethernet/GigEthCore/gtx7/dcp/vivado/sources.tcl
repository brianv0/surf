set RUCKUS_DIR $::env(RUCKUS_DIR)
source -quiet ${RUCKUS_DIR}/vivado_env_var_v1.tcl
source -quiet ${RUCKUS_DIR}/vivado_proc_v1.tcl

## Set the top level file
set_property top GigEthGtx7Core [current_fileset]

## Set the Secure IP library 
set_property library gig_ethernet_pcs_pma_v15_1_0 [get_files ${PROJ_DIR}/hdl/gig_ethernet_pcs_pma_v15_1_rfs.vhd]

