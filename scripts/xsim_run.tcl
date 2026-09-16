run all
if {[info exists ::env(VERIDMA_COV_DIR)] && [info exists ::env(VERIDMA_COV_NAME)]} {
  file mkdir $::env(VERIDMA_COV_DIR)
  write_xsim_coverage -cov_db_dir $::env(VERIDMA_COV_DIR) \
                      -cov_db_name $::env(VERIDMA_COV_NAME)
}
quit
