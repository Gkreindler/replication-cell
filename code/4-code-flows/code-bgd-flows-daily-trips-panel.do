* this do file: 

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"


*** Load Google Maps data 
	import delimited using "data_coded_bgd/travel-times/all tower pair in Dhaka after interpolation.csv", clear stringcols(5 7)

	* drop previous NaNs
	drop if duration_intp == .
	assert duration_intp > 0 & !missing(duration_intp)

	rename orig origin
	rename dest destination

	tempfile google_times
	save 	`google_times'


*** Antennas
	tempfile antenna_origin antenna_destination tower_origin tower_destination tower_o_d
	
	use "data_raw_bgd/other/antenna and tower coordinates - DhakaGaziNara", clear

	keep ant10 tower lat lon area
	gisid ant10
	compress
	
	preserve
		rename ant10 origin_ant
		rename tower origin
		keep origin*
		tempfile antenna_origin
		save 	`antenna_origin'
	restore

	preserve
		rename ant10 destination_ant
		rename tower destination
		keep destination*
		tempfile antenna_destination
		save 	`antenna_destination'
	restore

	use "data_raw_bgd/other/towers_bgd.dta", clear
	assert District == "DHAKA" if inrange(czone,1,90)
	gen dhaka_only = District == "DHAKA"

	keep tower dhaka_only
	rename tower origin
	rename dhaka dhaka_o
	tempfile tower_origin
	save 	`tower_origin'

	rename origin destination
	rename dhaka_o dhaka_d
	tempfile tower_destination
	save 	`tower_destination'

	* all O/D tower pairs
	keep destination
	rename destination tower
	duplicates drop
	rename tower origin
	gen destination = origin
	fillin origin destination
	drop _f

	merge m:1 origin using `tower_origin'
		assert _m==3
		drop _m

	merge m:1 destination using `tower_destination'
		assert _m==3
		drop _m


	*** Merge google maps data
	merge m:1 origin destination using `google_times'
	assert _m!=2
	
	* dummy to identify pairs with google travel time
	gen byte has_google_data = _m==3 | (origin == destination)
	drop _m


	* google distance between same tower = 0
	replace duration_intp = 0 if origin == destination

	compress
	save `tower_o_d', replace



*** PANEL DATA

*
forv im=1/4{
local month: word `im' of "08" "09" "11" "12"
	forv j=0/1{
		di "Loading and saving... commuting-`month'-r-0000`j'"
		local file_path "data_raw_bgd/flows-daily-trips/commuting_panel/commuting-`month'-r-0000`j'.txt"
		import delimited using "`file_path'", clear
		// 1,20131201,14074,14072
		rename v1 uid
		rename v2 date_numeric 
		rename v3 origin_ant
		rename v4 destination_ant
		replace date_numeric = mod(date_numeric,10000)
		compress
		save "data_coded_bgd/flows/commuting_panel/commuting_panel_`month'_`j'", replace
	}
}
// 

** APPEND TOGETHER
	use 			"data_coded_bgd/flows/commuting_panel/commuting_panel_08_0.dta"
	append using 	"data_coded_bgd/flows/commuting_panel/commuting_panel_08_1.dta"
	append using 	"data_coded_bgd/flows/commuting_panel/commuting_panel_09_0.dta"
	append using 	"data_coded_bgd/flows/commuting_panel/commuting_panel_09_1.dta"
	append using 	"data_coded_bgd/flows/commuting_panel/commuting_panel_11_0.dta"
	append using 	"data_coded_bgd/flows/commuting_panel/commuting_panel_11_1.dta"
	append using 	"data_coded_bgd/flows/commuting_panel/commuting_panel_12_0.dta"
	append using 	"data_coded_bgd/flows/commuting_panel/commuting_panel_12_1.dta"

	compress

*** Combine with other data sources

	*** Merge tower info
	merge m:1 origin_ant using `antenna_origin'
		drop if _m == 2 // towers without flow data
		assert _m != 1  // all towers with flow are found
		drop _m

	merge m:1 destination_ant using `antenna_destination'
		drop if _m == 2 // towers without flow data
		assert _m != 1  // all towers with flow are found
		drop _m

	drop origin_ant destination_ant 

	*** Merge tower information
	merge m:1 origin destination using `tower_o_d'
	drop if _m==2
	assert _m==3
	drop _m

	assert inlist(dhaka_o,0,1) & inlist(dhaka_d,0,1)
	gen dhaka = dhaka_o==1 & dhaka_d==1
	drop dhaka_?

*** Merge dates
	merge m:1 date_numeric using "data_coded_bgd/other/dates_igc.dta", keepusing(date_numeric date_type date_type_igc)
	assert _m==3
	drop _m


*** FINAL SAVE
	compress
	sort uid date_numeric
	gisid uid date_numeric
	save "data_coded_bgd/flows/daily_trips_panel", replace

