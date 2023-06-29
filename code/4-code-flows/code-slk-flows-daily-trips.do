* This do file takes Hadoop code output for daily trips and processes it into origin-destionation flows

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

************************
*** prepare other data
************************

** load working days - date is work day if it is non-weekend and not holiday
	import delimited using "data_raw_slk/other/140911_dow_holidays.csv", clear varnames(1)
	isid date
	tostring date, gen(date_string)
	drop date
	gen date = date(date_string, "YMD")
	format %td date
	drop date_string

	* h check
	gen dow = dow(date)
	tab dow workday
	assert workday == 0 if inlist(dow,0,6)
	drop dow

	compress
	tempfile workdays
	save	`workdays'


** load googlemap data
	import delimited using ///	
		"data_coded_slk/travel-times/all tower pair within 50 km after interpolation.csv", ///
		clear
		
	** rename orig and dest
	rename orig origin
	rename dest destination

	drop if duration_intp == .

	* checks
	assert duration_in_traffic_intp > 0 & !missing(duration_in_traffic_intp)
	assert duration_intp > 0 & !missing(duration_intp)

	tempfile google_times
	save 	`google_times'


****************
** load trips data
** orig, dest, date, daily volume
****************
	
	*** load the data extract
	forv file=0/2{
		import delimited using "data_raw_slk/flows-daily-trips/140910_trips`file'.csv", clear delimiters(",")

		gen date = date("20" + substr(v3,1,6),"YMD")
		format %td date
		gen volume = substr(v3,8,15) // start at 8 to skip the tab character
		destring volume, replace
		
		rename v1 orig
		rename v2 dest
		drop v3
		
		compress 
		tempfile trips`file'
		save	`trips`file''
	}

	use 		 `trips0', clear
	append using `trips1'
	append using `trips2'

	save "data_coded_slk/flows/daily_trips_intermed_idlevel.dta", replace


****************
** collapse to ignore dates - only OD level
** orig, dest, date, daily volume
****************
	use "data_coded_slk/flows/daily_trips_intermed_idlevel.dta", clear
	
	* merge information about dates
	merge m:1 date using `workdays'
	drop if _m==2
	assert _m!=1
	drop _m

	*** Collapse at o-d level
	gen ndays = 1
	gcollapse (sum) ndays volume, by(orig dest workday) fast

	compress

************************
** merge and define vars
************************
	
	fillin orig dest workday
	
	replace volume = 0 if _f==1
	replace ndays = 0 if _f==1
	
	assert volume!=.
	asser ndays!=.
	drop _f

*** Merge google travel times at O-D level
	rename orig origin
	rename dest destination

	gisid orig dest workday
	merge m:1 origin destination using `google_times'
	
	* some towers have no flows at all -> do not appear despite the fillin
	assert 	inlist(origin,		400, 462, 477, 1754, 151, 149, 404, 402, 369, 1898, 1907, 2238, 2250, 2408 ,2428, 2847, 3007) | ///
			inlist(destination, 400, 462, 477, 1754, 151, 149, 404, 402, 369, 1898, 1907, 2238, 2250, 2408 ,2428, 2847, 3007) ///
			if _m==2
	drop if _m==2
	* Note: non-merge are mostly > 50km or identical

	* dummy to identify pairs with google travel time
	gen has_google_data = _m==3 | (origin == destination)
	drop _m

	*** google distance between same tower = 0
	foreach va of varlist duration_in_traffic_intp duration_intp{
		replace `va' = 0 if origin == destination
	}

	sort orig dest workday

*** Save
	compress
	save "data_coded_slk/flows/daily_trips_odmatrix.dta", replace
