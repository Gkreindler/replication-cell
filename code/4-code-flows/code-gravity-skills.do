* This do file: code commuting flows with skill heterogeneity for SLK

clear all
set seed 342423

*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"


***********
*** SLK ***
***********

*** Census vars
	use "data_coded_slk/census/censuspop_tower_education", clear

	gen population_atleast_secondary = population * perc_atleast_secondary
	gen population_atmost_primary    = population * (1-perc_atleast_secondary)

	sum population_atleast_secondary
	local total_literate = r(sum)
	sum population_atmost_primary
	local total_illiterate = r(sum)
	di (`total_literate') / (`total_literate' + `total_illiterate') // .8064647

	sum perc_atleast_secondary, d //  Mean           .8115162

	keep tower perc_*
	rename tower origin

	tempfile tower_literacy
	save 	`tower_literacy'


*** Load gravity data
	use "data_coded_slk/flows/home_work_odmatrix_gravity.dta", clear

	merge m:1 origin using `tower_literacy'
	drop if _m==2 // 36 towers
	assert _m!=1
	drop _m

*** Sample
	keep if sample_v2 == 1

*** Heterogeneity variable
	gen perc_literate = perc_atleast_secondary

*** Coding 
	keep 	origin destination duration_intp perc_literate volume

	bys destination: gegen pop_work = sum(volume)

	hashsort origin destination
	by origin: gegen pop_res = sum(volume)
	gen pop_res_high = perc_literate * pop_res
	gen pop_res_low  = pop_res - pop_res_high

	gen log_dur = log(duration_intp)

*** Sample
	* drop origins with zero flows
	gunique origin // 1866
	drop if pop_res == 0
	gunique origin // 1825

	gunique destination // 1869
	drop if pop_work == 0
	gunique destination // 1,859

*** Naive regression
	gen log_dur_literate   = log_dur * perc_literate
	gen log_dur_non_literate   = log_dur * (1-perc_literate)

*** Save
	save "data_coded_slk/flows/home_work_odmatrix_2kills", replace









***********
*** BGD ***
***********

*** Census vars
	use "data_coded_bgd/census/censuspop_tower_allvars", clear

	sum pop_literate_isx
	local total_literate = r(sum)
	sum pop_illiterate_isx
	local total_illiterate = r(sum)
	di (`total_literate') / (`total_literate' + `total_illiterate') // .66963767

	sum perc_literate, d // Mean           .7434782

	keep tower perc_literate
	rename tower origin

	tempfile tower_literacy
	save 	`tower_literacy'

*** Load gravity data
	use "data_coded_bgd/flows/home_work_odmatrix_gravity.dta", clear

	merge m:1 origin using `tower_literacy'

	gunique origin if _m==1
	assert r(J) == 2 // only two towers
	drop if _m==1 

	count if _m==2
	assert r(N) == 1
	drop if _m==2 // a single tower
	
	drop _m

*** Sample
	keep if sample_v2 == 1

*** Coding 
	keep 	origin destination duration_intp perc_literate volume

	bys destination: gegen pop_work = sum(volume)

	hashsort origin destination
	by origin: gegen pop_res = sum(volume)
	gen pop_res_high = perc_literate * pop_res
	gen pop_res_low  = pop_res - pop_res_high

	gen log_dur = log(duration_intp)

*** Sample
	* drop origins with zero flows
	gunique origin // 1866
	drop if pop_res == 0
	gunique origin // 1825

	gunique destination // 1869
	drop if pop_work == 0
	gunique destination // 1,859

*** Naive regression
	gen log_dur_literate   = log_dur * perc_literate
	gen log_dur_non_literate   = log_dur * (1-perc_literate)

*** Save
	save "data_coded_bgd/flows/home_work_odmatrix_2kills", replace

