* This do file takes Hadoop code output for daily trips and processes it into origin-destionation flows
* Bangladesh

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

** list of Hartals and holidays
	tempfile hartalholiday
	import delimited using "data_raw_bgd/other/hartal_list.csv", clear varnames(1)
	save `hartalholiday'
	
	import delimited using "data_raw_bgd/other/holiday_list.csv", clear varnames(1)
	append using `hartalholiday'
	
	replace date = subinstr(date, "-", "",.)
	destring date, replace
	duplicates drop

	save `hartalholiday', replace
		
*** Antenna (ant10)-tower correspondence
	use "data_raw_bgd/other/antenna and tower coordinates - DhakaGaziNara", clear
	keep ant10 tower lat lon area District  
	gisid ant10
	gen dhaka = (District != "")
	assert inlist(dhaka,0,1)
	
	preserve
		rename ant10 origin_ant
		rename tower origin
		tempfile antenna_origin
		save `antenna_origin'
	restore

	preserve
		rename ant10 destination_ant
		rename tower destination
		tempfile antenna_destination
		save `antenna_destination'
	restore

	use "data_raw_bgd/other/towers_bgd.dta", clear
	keep tower dhaka
	rename tower origin
	rename dhaka dhaka_o
	tempfile tower_origin
	save 	`tower_origin'

	rename origin destination
	rename dhaka_o dhaka_d
	tempfile tower_destination
	save 	`tower_destination'

*** Load Google Maps data 
	import delimited using "data_coded_bgd/travel-times/all tower pair in Dhaka after interpolation.csv", clear // stringcols(5 7)

	rename orig origin
	rename dest destination

	drop if duration_intp == .

	* checks
	assert duration_intp > 0 & !missing(duration_intp)

	tempfile google_times
	save 	`google_times'


***************************************
** Load daily trips into monthly files
	local max_day_08 = 31
	local max_day_09 = 30
	local max_day_11 = 30
	local max_day_12 = 31

	foreach month in 8 9 11 12{
		* add leading zero
		local month_str = string(`month')
		if (length("`month_str'") == 1) local month_str = "0`month_str'"

		forv day=1/`max_day_`month_str''{
			* add leading zero
			local day_str = string(`day')
			if (length("`day_str'") == 1) local day_str = "0`day_str'"	
			di "Processing MONTH `month_str' DAY `day_str'"			

			local date_dir "data_raw_bgd/flows-daily-trips/commuter_matrix_2013_`month_str'/output_commuter/2013`month_str'`day_str'"
			local files: dir "`date_dir'" files "*.txt"

			local idx = -1
			foreach file of local files {
				local idx = `idx' + 1
				local filename "`date_dir'/`file'"
				di "`file'"
				import delimited using "`filename'", clear
				tempfile data_`month_str'_`day_str'_`idx'
				save 	`data_`month_str'_`day_str'_`idx''
			}	
			local idx_max_`month_str'_`day_str' = `idx'
		} // end day

		* append all together
		drop if _n>=0
		forv day=1/`max_day_`month_str''{
			di "adding day `day'"
			* add leading zero
			local day_str = string(`day')
			if (length("`day_str'") == 1) local day_str = "0`day_str'"
			forv idx=0/`idx_max_`month_str'_`day_str''{
				append using `data_`month_str'_`day_str'_`idx''
			}
		}
		
		rename v1 date
		rename v2 origin
		rename v3 destination
		rename v4 flow
		save "data_coded_bgd/flows/daily_trips_intermed_idlevel_2013-`month_str'.dta", replace

	} // end month


	
*************************************************
*** Append all data, collapse at tower-pair level
**************************************************

	** for each month, aggregate at tower-level

	foreach month_str in "08" "09" "11" "12"{	
		use "data_coded_bgd/flows/daily_trips_intermed_idlevel_2013-`month_str'.dta", clear
		tempfile month_`month_str'
		save 	`month_`month_str''
	}

	use 		 `month_08', clear
	append using `month_09'
	append using `month_11'
	append using `month_12'

	** non-Hartal non-holidays 
	merge m:1 date using `hartalholiday'
	assert _m != 2 // all dates match
	gen hartalholiday = _m==3
	drop _m

	gcollapse (sum) flow, by(origin destination hartalholiday) fast

	compress

***************************
** merge tower information
***************************
	// use "data_coded_bgd/flows/daily_trips_intermed_odlevel", clear

	*** Merge antenna->tower correspondence
	rename origin origin_ant
	rename destination destination_ant

	* no TOWER info for these antennas
	drop if inlist(origin_ant,      10912, 39434)
	drop if inlist(destination_ant, 10912, 39434)
		
	merge m:1 origin_ant using `antenna_origin'
		drop if _m == 2 // towers without flow data
		assert _m != 1  // all towers with flow are found
		drop _m
	
	merge m:1 destination_ant using `antenna_destination'
		drop if _m == 2 // towers without flow data
		assert _m != 1  // all towers with flow are found
		drop _m	

	* Drop antennas (keep tower)
	drop origin_ant destination_ant

	*** collapse at tower level
	gcollapse (sum) flow, by(origin destination hartalholiday) fast

	*** Fillin 
	fillin origin destination hartalholiday
	replace flow = 0 if _f==1
	assert flow!=.

	*** Merge tower data (dhaka indicator)
	merge m:1 origin using `tower_origin'
		drop if _m == 2 // towers without flow data
		assert _m != 1  // all towers with flow are found
		drop _m
	
	merge m:1 destination using `tower_destination'
		drop if _m == 2 // towers without flow data
		assert _m != 1  // all towers with flow are found
		drop _m	

	** label DHAKA / non-DHAKA
	gen dhaka = dhaka_o==1 & dhaka_d==1
	drop dhaka_o dhaka_d

	** rename for consistency with SLK data
	rename flow volume
	
	assert inlist(hartalholiday,0,1)		
	gen workday = 1 - hartalholiday
	drop hartalholiday

*** Merge Google Maps travel times
	merge m:1 origin destination using `google_times'
	
	* one origin doesn't appear at all in the flow data
	assert 	origin==966 if  _m==2
	drop if _m==2
	* Note: most towers without Google travel time data are either >50km, 
	* or out of Dhaka, or identical o and d
	
	* dummy to identify pairs with google travel time
	gen has_google_data = _m==3 | (origin == destination)
	drop _m

	* google distance between same tower = 0
	replace duration_intp = 0 if origin == destination
			
*** FINAL SAVE
	compress
	gisid origin destination workday dhaka
	sort  origin destination workday dhaka
	save "data_coded_bgd/flows/daily_trips_odmatrix.dta", replace

