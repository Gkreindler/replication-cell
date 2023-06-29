* This do file: Workplace income validation: Table 2 (panel B) and Table C3

clear all
set seed 342423

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** Tower area
	use "data_raw_bgd/other/towers_bgd", clear
	keep tower area_km2
	rename tower destination
	rename area_km2 km2_tower_d 

	tempfile km2
	save 	`km2'

***
	use "data_coded_bgd/flows/home_work_odmatrix_gravity.dta", clear
	drop if missing(duration_intp)
	gen 	log_dur = log(duration_intp)
	replace log_dur = log(180) if duration_intp < 180
	assert !missing(log_dur)

	keep origin destination origin_czone destination_czone log_dur volume

	merge m:1 destination using `km2'
	drop if _m==2
	assert _m!=1
	drop _m

	tempfile od_vars
	save 	`od_vars'


*** Load all the necessary fixed effects
	import delimited using "data_coded/dfe_bgd_home_work.csv", clear
	renam dfe dfe_pool
	rename _beta_log_dur _beta_slope_pool
	tempfile part1
	save 	`part1'

	import delimited using "data_coded/dfe_bgd_skills.csv", clear
	tempfile part2
	save 	`part2'

	import delimited using "data_coded/dfe_bgd_skills_MLE.csv", clear
	rename _beta_slope_low  _beta_slope_mle_low
	rename _beta_slope_high _beta_slope_mle_high
	tempfile part3
	save 	`part3'
	

*** Load skills coded data
	use "data_coded_bgd/flows/home_work_odmatrix_2kills", clear

*** merge OLS results
	merge m:1 destination using `part1'
	assert _m==3
	drop _m

	merge m:1 destination using `part2'
	assert _m==3
	drop _m

	merge m:1 destination using `part3'
	assert _m==3
	drop _m

	rename log_dur 	log_dur_old
	rename volume 	volume_old

	merge 1:1 origin destination using `od_vars'
	assert _m!=1
	// drop if _m==2
	drop _m

	label var dfe_pool 				"Destination FE pooled regression"
	label var _beta_slope_pool 		"log dist slope pooled regression"
	label var dfe_ols_low  			"Destination FE low  skill linear interactions"
	label var dfe_ols_high 			"Destination FE high skill linear interactions"
	label var _beta_slope_ols_low 	"log dist slope low  skill linear interactions"
	label var _beta_slope_ols_high 	"log dist slope high skill linear interactions"
	label var dfe_mle_low  			"Destination FE low  skill gravity 2 types (MLE)"
	label var dfe_mle_high  		"Destination FE high skill gravity 2 types (MLE)"
	label var _beta_slope_mle_low 	"log dist slope low  skill gravity 2 types (MLE)"
	label var _beta_slope_mle_high 	"log dist slope high skill gravity 2 types (MLE)"

	*** Fill in destination FEs and beta
	hashsort destination
	foreach myvar of varlist dfe_pool dfe_ols_low dfe_ols_high dfe_mle_low dfe_mle_high _beta_* {
		gegen temp = mean(`myvar'), by(destination)
		replace `myvar' = temp
		drop temp
	}

*** Three types:
* 1. pool
* 2. ols low/high
* 3. mle   low/high

*** Construct vij measures i,j=0,1

	gen pop_res_all = pop_res_low + pop_res_high

forv i=1/5{
	local destfename: word `i' of pool 				ols_low 			ols_high 				mle_low 			mle_high
	local destfe 	: word `i' of dfe_pool			dfe_ols_low 		dfe_ols_high 			dfe_mle_low 		dfe_mle_high
	local beta_slope: word `i' of _beta_slope_pool _beta_slope_ols_low 	_beta_slope_ols_high 	_beta_slope_mle_low _beta_slope_mle_high

*** Version 11 - z and d both productive 
	hashsort origin

*** Version 00 - z and d neither productive (this is the benchmark throughout the paper except Appendix D)
	gen double `destfename'_v00 		= `destfe'
	gen double `destfename'_adj_v00 	= `destfe' - log(km2_tower_d)

*** Predicted workplace flows
	gen double `destfename'_probs = exp(`destfe' + `beta_slope' * log_dur)
	gegen double sum_temp = sum(`destfename'_probs), by(origin)
	replace `destfename'_probs = `destfename'_probs / sum_temp
	drop sum_temp
}

*** What share of this volume does the model predict is low vs high skilled?
	gen ratio_ols_low = ols_low_probs * pop_res_low / (ols_low_probs * pop_res_low + ols_high_probs * pop_res_high)
	gen ratio_mle_low   =   mle_low_probs * pop_res_low / (  mle_low_probs * pop_res_low +   mle_high_probs * pop_res_high)

	* use the REAL volume, adjusted with the share of low- or high-skilled
	gen volume_ols_low   =    ratio_ols_low  * volume
	gen volume_ols_high  = (1-ratio_ols_low) * volume

	gen volume_mle_low   =    ratio_mle_low  * volume
	gen volume_mle_high  = (1-ratio_mle_low) * volume

forv i=1/4{
	local destfename: word `i' of ols_low ols_high mle_low mle_high
	preserve
		gcollapse (mean) `destfename'_v?? `destfename'_adj_v?? [aw=volume_`destfename'], by(destination_czone)

		tempfile file_`destfename'
		save 	`file_`destfename''
	restore
}

*** Also construct with overall weights (meaning not separated by skill)
	gcollapse (mean) *_v??  [fw=volume], by(destination_czone)

	foreach myvar of varlist pool_v00-mle_high_adj_v00 {
		rename `myvar' `myvar'_w
	}

forv i=1/4{
	local destfename: word `i' of ols_low ols_high mle_low mle_high
	merge 1:1 destination_czone using `file_`destfename''
	assert _m==3
	drop _m
}

	// gcollapse (mean) *_v??  [fw=volume], by(destination_czone)

*** Merge the Survey data (DHUTS) 
	/* 
	here we have: 
	- aggregate volume between survey areaz (c zones) 
	- avearge income for commuters working in location "dest"
	- both of the above by skill
	*/
	merge 1:1 destination_czone using "data_coded_bgd/dhuts/dhuts_dest_y_temp.dta"
	keep if _m==3
	drop _m



************************
*** Run Analysis
************************


*** Table C3
	estimates clear

*** What does the "pooled" measure capture? High or low skilled?
	eststo: reg mean_logy_dhuts_no_weight_low2  pool_adj_v00_w [aw=vol_dhuts_low2], r
	eststo: reg mean_logy_dhuts_no_weight_high2 pool_adj_v00_w [aw=vol_dhuts_high2], r

*** using model income computed using destination FEs computed with OLS (model 2)
	eststo: reg mean_logy_dhuts_no_weight_low2  ols_low_adj_v00  [aw=vol_dhuts_low2], r
	eststo: reg mean_logy_dhuts_no_weight_high2 ols_high_adj_v00 [aw=vol_dhuts_high2], r

	eststo: reg mean_logy_dhuts_no_weight_low2  ols_low_adj_v00 ols_high_adj_v00 [aw=vol_dhuts_low2], r
	eststo: reg mean_logy_dhuts_no_weight_high2 ols_low_adj_v00 ols_high_adj_v00 [aw=vol_dhuts_high2], r

*** using model income computed using destination FEs computed with MLE (model 1)
	eststo: reg mean_logy_dhuts_no_weight_low2  mle_low_adj_v00  [aw=vol_dhuts_low2], r
	eststo: reg mean_logy_dhuts_no_weight_high2 mle_high_adj_v00 [aw=vol_dhuts_high2], r

	eststo: reg mean_logy_dhuts_no_weight_low2  mle_low_adj_v00 mle_high_adj_v00 [aw=vol_dhuts_low2], r
	eststo: reg mean_logy_dhuts_no_weight_high2 mle_low_adj_v00 mle_high_adj_v00 [aw=vol_dhuts_high2], r

*** Save to table
	esttab * using "tables/table_C3/table_C3.tex", ///
		replace keep(pool_adj_v00_w ols_* mle_*) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	pool_adj_v00_w "Pooled" ols_low_adj_v00 "Log-linear Low" ols_high_adj_v00 "Log-linear High" ///
					mle_low_adj_v00 "MLE Low" mle_high_adj_v00 "MLE High"  ) ///
		starlevels(* .10 ** .05 *** .01) /* nonumbers */ ///
		mgroups( "\emph{Outcome:} log Survey Income (workplace)", pattern(1 0 0 0 0 0 0 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
		mtitles("Low" "High" "Low" "High" "Low" "High" "Low" "High" "Low" "High" ) ///
		stats(N r2_a, labels("Observations" "Adjusted R2") fmt("%12.0fc" "%12.2f")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes




*** Table 2 panel B, only OLS (model 2)
	estimates clear

*** Outcome variable: low skilled survey income income
	eststo: reg mean_logy_dhuts_no_weight_low2  ols_low_adj_v00  [aw=vol_dhuts_low2], r
	eststo: reg mean_logy_dhuts_no_weight_low2  ols_high_adj_v00 [aw=vol_dhuts_low2], r
	eststo: reg mean_logy_dhuts_no_weight_low2  ols_low_adj_v00 ols_high_adj_v00 [aw=vol_dhuts_low2], r

*** Outcome variable: high skilled survey income income
	eststo: reg mean_logy_dhuts_no_weight_high2 ols_low_adj_v00  [aw=vol_dhuts_high2], r
	eststo: reg mean_logy_dhuts_no_weight_high2 ols_high_adj_v00 [aw=vol_dhuts_high2], r
	eststo: reg mean_logy_dhuts_no_weight_high2 ols_low_adj_v00 ols_high_adj_v00 [aw=vol_dhuts_high2], r

*** Save to table
	esttab * using "tables/table_2/table_2B.tex", ///
		replace keep(ols_*) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	ols_low_adj_v00 "Log-linear  Low" ///
					ols_high_adj_v00 "Log-linear  High" ) ///
		starlevels(* .10 ** .05 *** .01) /* nonumbers */ ///
		mgroups("Low Skill" "High Skill", pattern(1 0 0 1 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
		stats(N r2_a rmse, labels("Observations" "Adjusted R2" "RMSE") fmt("%12.0fc" "%12.2f" "%12.2f")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes nomtitles
