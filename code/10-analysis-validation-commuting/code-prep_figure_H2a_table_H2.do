* This do file: 

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

***********************
******* DAILY *********
***********************

*** load data
	use "data_coded_bgd/dhuts/daily_trips_odmatrix_dhuts.dta", clear
	count // 7921
	gisid origin_czone destination_czone

	gen flow_3 			= flow_2			if origin_czone != destination_czone
	gen mean_log_dur_3	= mean_log_dur_2 	if origin_czone != destination_czone

	gen flow 		= flow_1
	gen mean_log_dur= mean_log_dur_1

*** CODING 
	* LOG (flow)
	gen log_flow      	= log(flow)
	gen log_flow_dhuts 	= log(flow_dhuts_sample)

	* duration bins
	sum mean_log_dur, d
	local binw = (r(p99) - r(p1))/100
	egen mean_log_dur_cat = cut(mean_log_dur), at(`r(min)'(`binw')`r(p99)')

	* count volume by sample 
	qui sum flow if origin_czone == destination_czone
	di r(sum)
	qui sum flow if origin_czone != destination_czone
	di r(sum)

	* Sample based on distance
	qui sum mean_log_dur, d
	gen mean_log_dur_sample = inrange(mean_log_dur, r(min), r(p99))

	qui sum flow if mean_log_dur_sample==1
	di r(sum)


* LOG (mean flow by distance bin)
	qui reg log_flow if mean_log_dur_sample==1
	predict log_flow_r, r

	qui reg log_flow_dhuts if mean_log_dur_sample==1
	predict log_flow_dhuts_r, r

* Save
	// save "data_coded_bgd/dhuts/commuting_comparison.dta", replace
	keep origin_czone	destination_czone log_flow flow
	rename log_flow log_flow_daily
	rename flow flow_daily

	tempfile daily
	save 	`daily'

***********************
******* HOME-WORK *****
***********************

*** load data
	use "data_coded_bgd/dhuts/home_work_odmatrix_dhuts.dta", clear
	count // 7921
	gisid origin_czone destination_czone

	gen flow_3 			= flow_2			if origin_czone != destination_czone
	gen mean_log_dur_3	= mean_log_dur_2 	if origin_czone != destination_czone

	gen flow 		= flow_1
	gen mean_log_dur= mean_log_dur_1

*** CODING 
	* LOG (flow)
	gen log_flow      	= log(flow)
	gen log_flow_dhuts 	= log(flow_dhuts_sample)

	* duration bins
	sum mean_log_dur, d
	local binw = (r(p99) - r(p1))/100
	egen mean_log_dur_cat = cut(mean_log_dur), at(`r(min)'(`binw')`r(p99)')

	* count volume by sample 
	qui sum flow if origin_czone == destination_czone
	di r(sum)
	qui sum flow if origin_czone != destination_czone
	di r(sum)

	* Sample based on distance
	qui sum mean_log_dur, d
	gen mean_log_dur_sample = inrange(mean_log_dur, r(min), r(p99))

	qui sum flow if mean_log_dur_sample==1
	di r(sum)


* LOG (mean flow by distance bin)
	qui reg log_flow if mean_log_dur_sample==1
	predict log_flow_r, r

	qui reg log_flow_dhuts if mean_log_dur_sample==1
	predict log_flow_dhuts_r, r

* Merge daily
	merge 1:1 origin_czone destination_czone using `daily'
	assert _m==3
	drop _m

	replace flow_dhuts = 0 if flow_dhuts == .

* Save
	save "data_coded_bgd/dhuts/merged_comparison.dta", replace

