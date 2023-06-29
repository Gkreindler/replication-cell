* This do file takes Hadoop code output for home work and processes it into origin-destionation flows
* Sri Lanka

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

***Load the raw data (three parts)
forv i=0/2{
	import delimited using "data_raw_slk/flows-home-work/part-0000`i'.csv", clear


	rename v1 id
	rename v2 hw
	label define hw 0 "home 9pm - 5am" 1 "work 10am-3pm"
	label variable hw hw
	rename v3 Tmax  // max tower
	rename v4 Tmaxfreq
	// replace v6=.  if v5=="NaN"
	// replace v5="" if v5=="NaN"
	// destring v5, replace
	rename v5 Tmax2
	rename v6 Tmaxfreq2
	rename v7 totfreq

	compress

	tempfile part_`i'
	save 	`part_`i'', replace
}

append using `part_1'
append using `part_0'

	save "data_coded_slk/flows/home_work_intermed_idlevel.dta", replace
//
	
****************
** collapse at the OD level
****************
	use "data_coded_slk/flows/home_work_intermed_idlevel.dta", clear
	
	keep id Tmax hw
	
	greshape wide Tmax, i(id) j(hw)
	
	rename Tmax0 origin
	rename Tmax1 destination
	
	* out sample is users with both home and work locations identified
	keep if origin != . & destination != .
	
	gen volume = 1
	gcollapse (sum) volume, by(origin destination) fast
	
    * merge with commuting matrix data (to obtain distances)
	tempfile tempdf
	saveold `tempdf'

*** Start from daily trip OD matrix and merge home work commuting flows 
	use  "data_coded_slk/flows/daily_trips_odmatrix.dta", clear

	* single cross-section
	keep if workday == 1

	* instead of the daily trip volume, use home-work volumes
	drop volume

	merge 1:1 origin destination using `tempdf'	
	assert _m != 2
	drop _m
	
	replace volume = 0 if volume == .
	
	save "data_coded_slk/flows/home_work_odmatrix.dta", replace
