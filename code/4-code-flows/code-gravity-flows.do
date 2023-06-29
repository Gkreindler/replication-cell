* This do file does final coding for the gravity equation: adding some useful variables to the od matrices
* Sri Lanka and Bangladesh

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

***********
*** SLK ***
***********

*** tower data
	use "data_raw_slk/other/towers_slk.dta", clear
	keep if province == "Western"
	keep tower
	gduplicates drop
	gisid tower

	rename tower origin 
	tempfile origin_towerlist
	save 	`origin_towerlist'
	
	rename origin destination
	tempfile destination_towerlist
	save 	`destination_towerlist'

***********************
*** Load daily trip data
	use "data_coded_slk/flows/daily_trips_odmatrix.dta", clear
	keep if workday == 1

	*** keep only western province
	merge m:1 origin using `origin_towerlist'
	keep if _m==3
	drop _m

	merge m:1 destination using `destination_towerlist'
	keep if _m==3
	drop _m

	*** Define sample - exclude very nearby and distant tower pairs
	scalar min_dur = 180
	sum duration_intp, d
	scalar max_dur = r(p99)

	// ## sample 1 = exclude only distant tower pairs
  	// ## sample 2 = exclude both distant and nearby tower pairs
  	gen sample_v1 = duration_intp < max_dur
  	gen sample_v2 = (duration_intp > min_dur) & (duration_intp < max_dur)
  	gen sample_v3 = (duration_intp > min_dur) & (duration_intp < max_dur) & (volume != 0)

  	gegen outflow_v1 = sum(volume * sample_v1), by(origin)
  	gegen outflow_v2 = sum(volume * sample_v2), by(origin)

  	gegen inflow_v1 = sum(volume * sample_v1), by(destination)
  	gegen inflow_v2 = sum(volume * sample_v2), by(destination)

  	gisid 	origin destination
  	sort 	origin destination
  	save "data_coded_slk/flows/daily_trips_odmatrix_gravity.dta", replace


***********************
*** Load home work data
	use "data_coded_slk/flows/home_work_odmatrix.dta", clear
	keep if workday == 1

	*** keep only western province
	merge m:1 origin using `origin_towerlist'
	keep if _m==3
	drop _m

	merge m:1 destination using `destination_towerlist'
	keep if _m==3
	drop _m

	*** Define sample - exclude very nearby and distant tower pairs
	scalar min_dur = 180
	sum duration_intp, d
	scalar max_dur = r(p99)

	// ## sample 1 = exclude only distant tower pairs
  	// ## sample 2 = exclude both distant and nearby tower pairs
  	gen sample_v1 = duration_intp < max_dur
  	gen sample_v2 = (duration_intp > min_dur) & (duration_intp < max_dur)
  	gen sample_v3 = (duration_intp > min_dur) & (duration_intp < max_dur) & (volume != 0)

  	gegen outflow_v1 = sum(volume * sample_v1), by(origin)
  	gegen outflow_v2 = sum(volume * sample_v2), by(origin)

  	gegen inflow_v1 = sum(volume * sample_v1), by(destination)
  	gegen inflow_v2 = sum(volume * sample_v2), by(destination)

  	gisid 	origin destination
  	sort 	origin destination
  	save "data_coded_slk/flows/home_work_odmatrix_gravity.dta", replace

***********
*** BGD ***
***********

*** code survey areas ("czone") information by tower
	use "data_raw_bgd/other/towers_bgd", clear
	keep tower czone

	gisid tower

	preserve
		keep tower czone
		gduplicates drop

		rename tower origin
		rename czone origin_czone
		tempfile origin_czone
		save 	`origin_czone'

		rename origin destination
		rename origin_czone destination_czone
		tempfile destination_czone
		save 	`destination_czone'
	restore

   	drop if missing(czone)

   	keep tower czone

   	tempfile czonelist
   	save 	`czonelist'

************************
*** Load daily trip data
	use "data_coded_bgd/flows/daily_trips_odmatrix.dta", clear
	keep if workday == 1 & dhaka == 1

	* merge survey area (czone) data
	merge m:1 origin using `origin_czone'
	drop if _m==2
	assert _m!=1
	drop _m

	merge m:1 destination using `destination_czone'
	drop if _m==2
	assert _m!=1
	drop _m

	*** Define sample - exclude very nearby and distant tower pairs
	scalar min_dur = 180
	sum duration_intp, d
	scalar max_dur = r(p99)

	// ## sample 1 = exclude only distant tower pairs
  	// ## sample 2 = exclude both distant and nearby tower pairs
  	gen sample_v1 = duration_intp < max_dur
  	gen sample_v2 = (duration_intp > min_dur) & (duration_intp < max_dur)
  	gen sample_v3 = (duration_intp > min_dur) & (duration_intp < max_dur) & (volume != 0)

  	gegen outflow_v1 = sum(volume * sample_v1), by(origin)
  	gegen outflow_v2 = sum(volume * sample_v2), by(origin)

  	gegen inflow_v1 = sum(volume * sample_v1), by(destination)
  	gegen inflow_v2 = sum(volume * sample_v2), by(destination)

  	gisid 	origin destination
  	sort 	origin destination
  	save "data_coded_bgd/flows/daily_trips_odmatrix_gravity.dta", replace

************************
*** Load home work data
	use "data_coded_bgd/flows/home_work_odmatrix.dta", clear
	keep if workday == 1 & dhaka == 1

	* merge survey area (czone) data
	merge m:1 origin using `origin_czone'
	drop if _m==2
	assert _m!=1
	drop _m

	merge m:1 destination using `destination_czone'
	drop if _m==2
	assert _m!=1
	drop _m

	*** Define sample - exclude very nearby and distant tower pairs
	scalar min_dur = 180
	sum duration_intp, d
	scalar max_dur = r(p99)

	// ## sample 1 = exclude only distant tower pairs
  	// ## sample 2 = exclude both distant and nearby tower pairs
  	gen sample_v1 = duration_intp < max_dur
  	gen sample_v2 = (duration_intp > min_dur) & (duration_intp < max_dur)
  	gen sample_v3 = (duration_intp > min_dur) & (duration_intp < max_dur) & (volume != 0)

  	gegen outflow_v1 = sum(volume * sample_v1), by(origin)
  	gegen outflow_v2 = sum(volume * sample_v2), by(origin)

  	gegen inflow_v1 = sum(volume * sample_v1), by(destination)
  	gegen inflow_v2 = sum(volume * sample_v2), by(destination)

  	save "data_coded_bgd/flows/home_work_odmatrix_gravity.dta", replace

