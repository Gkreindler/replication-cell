* this do file: coding hartal panel part 1

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** LOAD CODED PANEL DATA
	use "data_coded_bgd/flows/daily_trips_panel", clear

*** SAMPLE
	keep if dhaka == 1
	drop dhaka has_google_data

*** What fraction of the sample is home =/= work?
preserve
	merge m:1 uid using "data_coded_bgd/flows/home_work_idlevel"
	keep if _m==3
	drop _m

	drop if tower_work == .

	gen byte hw_diff = tower_home != tower_work
	hashsort uid
	by uid: gen o1=_n==1

	tab hw_diff if o1==1, m
	// 35.8 % of users have distinct home and work
restore

*** CODING
	// count if duration_intp == .
	// assert r(N) == 3 //<= 9394

	gen is_trip = origin != destination // duration_intp != 0

	* dates
	assert inlist(date_type_igc,0,1,2,3,4)
	gen byte hartal_igc = date_type_igc == 4
	gen byte hartal = date_type == 4

	* winsorize
	gen dur_w = duration_intp

	qui centile duration_intp if is_trip == 1, centile(99.5)
	replace dur_w = r(c_1) if dur_w > duration_intp & !missing(dur_w)

	replace dur_w = 0 if is_trip == 0

	replace duration_intp = duration_intp / 60 // minutes
	replace dur_w = dur_w / 60 // minutes

* IDs with trips on both hartal and non-hartal days
	sort uid hartal_igc
	by uid: gen has_both_igc = hartal_igc[1] != hartal_igc[_N]
	sort uid hartal
	by uid: gen has_both = hartal[1] != hartal[_N]
	by uid: gen o1 = _n==1

	tab has_both     if o1==1, m
	tab has_both_igc if o1==1, m
	tab has_both has_both_igc if o1==1, m

	tab has_both_igc
	tab has_both
	
	drop o1
	drop duration_intp

*** SAMPLE - users who appear both during hartal and non-hartal days
	keep if has_both_igc == 1
	drop has_both*
	drop hartal //hartal_igc
	drop is_trip

	save "data_coded_bgd/flows/daily_trips_panel_hartal", replace


