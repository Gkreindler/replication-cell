* this do file: Main hartal analysis (table 5)

clear all
set more off
pause on

*** Argument: value of epsilon and string for saving files, e.g. 9.09 and "909"
	scalar myvalue_epsilon=8.3 

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"


****** 

*** Load estimated gravity equations
	import delimited using "data_coded/dfe_bgd_skills.csv", clear
	tempfile dfe
	save 	`dfe'
	
*** Tower distance to CBD
	use "data_coded_bgd/other/dist2cbd.dta"
	gen log_dest_dist2cbd = log(distCBD)
	rename tower destination
	gisid destination
	
	tempfile dist2cbd
	save 	`dist2cbd'

*** Tower area
	use "data_raw_bgd/other/towers_bgd.dta", clear
	keep  tower area_km2
	rename area_km2 km2_tower_o
	rename tower origin
	tempfile orig_km2s
	save 	`orig_km2s'

	rename origin destination
	rename km2_tower_o km2_tower_d
	tempfile dest_km2s
	save 	`dest_km2s'

*** Load destination FEs by skill
	use "data_coded_bgd/flows/home_work_odmatrix_2kills", clear
	keep origin destination volume log_dur pop_work pop_res_high pop_res_low perc_literate

	merge m:1 destination using `dfe'
	assert _m!=2
	keep if _m==3
	drop _m

	merge m:1 destination using `dest_km2s'
	assert _m!=1
	drop if _m==2
	drop _m

	merge m:1 destination using `dist2cbd'
	assert _m!=1
	drop if _m==2
	drop _m

	*** Destination log employment density 
	gen log_work_density = log(pop_work) - log(km2_tower_d)

	hashsort destination
	foreach myvar of varlist dfe_ols_low 	dfe_ols_high _beta_* {
		// gegen temp = mean(`myvar'), by(destination)
		// replace `myvar' = temp
		// drop temp
		assert !missing(`myvar')
	}

	*** Predicted workplace flows
	hashsort origin

	forv i=1/2{
		local destfename: word `i' of ols_low 				ols_high
		local destfe 	: word `i' of dfe_ols_low 			dfe_ols_high
		local beta_slope: word `i' of _beta_slope_ols_low 	_beta_slope_ols_high

	*** Version 00 - z and d neither productive
		gen double `destfename'_probs = exp(`destfe' + `beta_slope' * log_dur)
		gegen double sum_temp = sum(`destfename'_probs), by(origin)
		replace `destfename'_probs = `destfename'_probs / sum_temp
		drop sum_temp
	}

	*** predict low-skill share
	gen ratio_ols_high = ols_high_probs * pop_res_high / (ols_low_probs * pop_res_low + ols_high_probs * pop_res_high)
	sum ratio_ols_high, d

	gen dfe_adj_low  = dfe_ols_low  - log(km2_tower_d)
	gen dfe_adj_high = dfe_ols_high - log(km2_tower_d)

	keep origin destination ratio_ols_high perc_literate ///
			dfe_ols_low dfe_ols_high log_dur dfe_adj_* log_dest_dist2cbd log_work_density
	gduplicates drop
	gisid origin destination
	rename origin home_origin
	rename destination work_destination

	tempfile skill_frac
	save 	`skill_frac'




***
	import delimited using "data_coded/dfe_bgd_home_work.csv", clear

	merge 1:1 destination using `dest_km2s'
	assert _m!=1
	keep if _m==3
	drop _m

	gen dfe_adj_temp = dfe - log(km2_tower_d)
	
	tempfile predicted_income
	save 	`predicted_income'


**** Load full data (dhaka, users with both hartal and non-hartal days)
	use "data_coded_bgd/flows/daily_trips_panel_hartal", clear

** Merge home and work
	merge m:1 uid using "data_coded_bgd/flows/home_work_idlevel"
	keep if _m==3
	drop _m

	* SAMPLE: drop 525 observations without assigned work tower
	drop if tower_work == .

	* what are the origin and destination of the trip?
	gen byte orig_is_home = origin==tower_home 
	gen byte dest_is_work = destination==tower_work
	gen byte hw_diff = tower_home != tower_work
	gen byte is_trip = origin != destination

	* fraction of the sample with distinct home and work towers
	preserve
		hashsort uid
		by uid: gen o1=_n==1
		tab hw_diff if o1==1, m
		//  35.29 % 
	restore

	* stats on data coverage
	bys uid: gegen n_dates_per_uid = nunique(date_numeric)
	gen above75_new = n_dates_per_uid > `=0.75*122' // 75% of the dates
	gen above50_new = n_dates_per_uid > `=0.50*122' // 50% of the dates

	* destination is work only when a real trip is made
	replace dest_is_work = dest_is_work * (origin != destination)

	* merge destination FEs
	merge m:1 destination using `predicted_income'

	count if _m==1 & origin != destination
	assert r(N) == 694
	drop if _m==1 & origin != destination
	drop if _m==2
	drop _m

*** SAMPLE: only commuters with distinct home and work towers)
	keep if hw_diff == 1
	drop hw_diff

***	intermediate cleaning
	keep uid date_numeric date_type_igc hartal_igc ///
		origin destination ///
		orig_is_home dest_is_work is_trip dfe_adj above50_new

*** the relevant destination is the person-specific work destination
	gen temp = destination if dest_is_work == 1
	gegen work_destination = min(temp), by(uid)
	drop temp

	gen temp = origin if orig_is_home == 1
	gegen home_origin = min(temp), by(uid)
	drop temp

*** Code destination fixed efefcts at the (work) destination level
	gen temp = dfe_adj_temp if dest_is_work == 1
	gegen dfe_adj = min(temp), by(uid)
	drop temp

*** SAMPLE: 
	keep if home_origin !=.
	keep if work_destination != .
	
*** Merge low- and high-skills
	merge m:1 home_origin work_destination using `skill_frac'
	drop _m

*** SAMPLE --- only home-origin and work-destination pairs used in the gravity eqn sample 
	* drop when duration > 99th percentile
	keep if !missing(log_dur)

*** save
	compress
	save "data_coded_bgd/flows/daily_trips_panel_hartal_coded", replace



