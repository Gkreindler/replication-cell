* This do file takes Hadoop code output for home work and processes it into origin-destionation flows
* Bangladesh

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"
	
*** Load home and work assignments by user
	/* This data records the most frequent cell phone tower during daytime (work) and nighttime (home) time intervals:
	Home (nighttime) time interval:  9pm - 5am
	Work (  daytime) time interval: 10am - 3pm
	*/
	import delimited using 	"data_raw_bgd/flows-home-work/user_home_office_list.csv", clear
	
	* reliability
	gen rel_max = tmaxfreq / totfreq
	label variable rel_max "Reliability of most frequent tower"
	
	*drop freq_tower*
	greshape wide tmax rel_* totfreq tmaxfreq, i(userid) j(home_work_dummy)
	rename tmax0 origin
	rename tmax1 destination

	// 96.19% have both home and work: 5,017,582 out of 5,216,464
	count if origin != . & destination != .
	keep if origin != . & destination != .

	gen byte home_work_same = origin == destination
	
*** collapse at the OD level
	gen volume = 1
	gcollapse (sum) volume, by(origin destination) fast
	gisid origin destination
	
    * merge with commuting matrix data (to obtain distances)
	tempfile tempdf
	save `tempdf'

*** Start from daily trip OD matrix and merge home work commuting flows 
	use  "data_coded_bgd/flows/daily_trips_odmatrix.dta", clear
	keep if workday == 1
	drop volume

	merge 1:1 origin destination using `tempdf'	
	drop if origin == . | destination == .
	assert _m!=2 // all observations from home-work are also in the daily commuting
	drop _m
	
	recode volume* (.=0)

*** Save	
	compress
	gisid origin destination
	save "data_coded_bgd/flows/home_work_odmatrix", replace
