* This do file:
clear all
set more off
pause on

*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** Load data
	use "data_coded_bgd/dhuts/merged_comparison.dta", clear

	gen one=1
	label var log_flow_dhuts 	"Log flow survey data (DHUTS)"
	label var flow_dhuts 		"Flow survey data (DHUTS)"
	label var log_flow 			"Log flow cell phone data"
	label var mean_log_dur 		"Log duration"


*** drop origins with zero variation
	bys origin_czone: gegen orig_max_flow = max(flow_dhuts)
	bys origin_czone: gen o1=_n==1

	bys destination_czone: gegen dest_max_flow = max(flow_dhuts)
	bys destination_czone: gen d1=_n==1

	tab orig_max_flow if o1==1
	tab dest_max_flow if d1==1

	drop if orig_max_flow == 0
	assert dest_max_flow > 0
	drop *_max_flow


*** Specifications
	est clear
	local xvar "log_flow"

	* Log DHUTS on Log CELL, cluster by o and d, drop zero DHUTS flow
		_eststo: poisson flow_dhuts `xvar', vce(cluster origin_czone)	

	* with O and D fixed effects 
		_eststo: ppmlhdfe flow_dhuts `xvar', ab(origin_czone destination_czone) cluster(origin_czone)
		estadd local fe="Yes"

	* include distance
		_eststo: poisson flow_dhuts `xvar'  mean_log_dur, vce(cluster origin_czone)

	* include distance, with O and D fixed effects 
		_eststo: ppmlhdfe flow_dhuts `xvar' mean_log_dur, ab(origin_czone destination_czone) cluster(origin_czone)
		estadd local fe="Yes"

*** Save to file
	local outputfile_1 "tables/table_H2/comparison_dhuts_v0_hw.tex"
	esttab using "`outputfile_1'", se label replace booktab ///
									 keep(log_flow* mean_log_dur) eqlabels(none) ///
									 b(a2) stats(fe N, label("\shortstack{Origin and destination\\fixed effects}" "Observations") fmt(%12.0fc a2)) ///
									 nonotes noconstant nomtitle ///
									 mgroups("Flow survey data (DHUTS)", pattern(1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span}))
