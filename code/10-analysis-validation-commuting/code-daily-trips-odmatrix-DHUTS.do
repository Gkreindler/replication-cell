* This do file: 

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

********************
*** Antenna list ***
********************
	use "data_raw_bgd/other/towers_bgd", clear
	keep tower czone
	gisid tower

	preserve
		rename tower origin
		rename czone origin_czone
		tempfile czone_origin
		save 	`czone_origin'
	restore
	preserve
		rename tower destination
		rename czone destination_czone
		tempfile czone_destination
		save 	`czone_destination'
	restore

*** Cell Phone data
	use "data_coded_bgd/flows/daily_trips_odmatrix.dta", clear
	keep if dhaka == 1
	keep if workday == 1
	drop _fillin dhaka workday

	merge m:1 origin using `czone_origin'
	drop if _m==2
	drop _m

	merge m:1 destination using `czone_destination'
	drop if _m==2
	asser _m==3
	drop _m

	// 2045286 with one or both outside
	count if origin_czone ==. | destination_czone ==.
	drop  if origin_czone ==. | destination_czone ==.

*** Define distances
	gen log_dur  = log(duration_intp)
	winsor log_dur, p(0.0025) gen(log_dur_w)	

	
*** COLLAPSE
	replace duration_intp = 150  if origin == destination
	replace log_dur_w = log(150) if origin == destination
	*** Sample 1 = full sample excluding same tower

	*** Sample 2 = exclude duration_intp < 180
	gen sample_2 = duration_intp > 180
	gen log_dur_w_2     = log_dur_w     if sample_2 == 1 // missing otherwise
	gen duration_intp_2 = duration_intp if sample_2 == 1 // missing otherwise

	gen flow = 1
	gcollapse (sum)  flow_1=flow flow_2=sample_2 ///
			 (mean) mean_log_dur_1=log_dur_w   mean_dur_1=duration_intp ///
			 		mean_log_dur_2=log_dur_w_2 mean_dur_2=duration_intp_2 ///
			 [fweight=volume] ///
			 , by(origin_cz destination_cz) fast 

 * final coding
 	gen log_mean_dur_1 = log(mean_dur_1)
 	gen log_mean_dur_2 = log(mean_dur_2)

***************
*** COMBINE ***
***************

	merge 1:1 origin_czone destination_czone using "data_coded_bgd/dhuts/coded_dhuts_czone_pairs"
	sum flow_dhuts if _m==2
	assert r(sum) == 3 //59
	drop if _m==2
	drop _m

	fillin origin_czone destination_czone
	count if _f==1
	assert r(N) == 6 //9

	gen    flow_dhuts_w0 = flow_dhuts_sample
	recode flow_dhuts_w0 (.=0)

	sum flow_dhuts
	di r(sum) // 13,905 commuting trips

*** Save
	save "data_coded_bgd/dhuts/daily_trips_odmatrix_dhuts.dta", replace


	
