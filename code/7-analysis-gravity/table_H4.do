* This do file: Table H4: robustness of estimated destination fixed effects to various specifications

clear all
set seed 342423

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

/* 

Part 1: run gravity equations for BGD with various changes
Part 2: run gravity equations for SLK with various changes
Part 3: merge destination FEs and regress the benchmark dest FE on robustness versions

*/

***********************
*** Part 1: BGD
***********************

*** BGD: "home work" and "daily trips" are already ran for Table 1

***********************
*** BGD full sample -- include tower pairs < 180 seconds away and include dummy
***********************
	use "data_coded_bgd/flows/home_work_odmatrix_gravity", clear

	* define log duration censored from below at 180
	gen log_dur = log(max(180,duration_intp))
	gen closer_tower = duration_intp < 180

	*** 
	ppmlhdfe volume log_dur closer_tower if sample_v1 == 1, ///
			ab(origin DFE_close_towers=destination) cl(origin destination) verbose(1)

	preserve 
		keep destination DFE_close_towers
		keep if !missing(DFE_close_towers)
		gduplicates drop
		gisid destination
		export delimited using "data_coded/dfe_bgd_robust_close_towers.csv", replace
	restore

***********************
*** BGD log volume (dropping zeros)
***********************
	gen log_volume = log(volume)

	*** 
	reghdfe log_volume log_dur if sample_v2 == 1, ///
			ab(origin DFE_logvol=destination) cl(origin destination) verbose(1)

	preserve 
		keep destination DFE_logvol
		keep if !missing(DFE_logvol)
		gduplicates drop
		gisid destination
		export delimited using "data_coded/dfe_bgd_robust_logvol.csv", replace
	restore

***********************
*** BGD log volume plus 1
***********************
	gen log_volume_plus1 = log(volume+1)

	*** 
	reghdfe log_volume_plus1 log_dur if sample_v2 == 1, ///
			ab(origin DFE_plus1=destination) cl(origin destination) verbose(1)

	preserve
		keep destination DFE_plus1
		keep if !missing(DFE_plus1)
		gduplicates drop
		gisid destination
		export delimited using "data_coded/dfe_bgd_robust_logvol_plus1.csv", replace
	restore

***********************
*** BGD non-parametric distance
***********************
	gquantiles duration_intp_q10 = duration_intp, xtile nq(10)

	*** 
	ppmlhdfe volume duration_intp_q10 if sample_v2 == 1, ///
			ab(origin DFE_nonparam=destination) cl(origin destination) verbose(1)

	preserve
		keep destination DFE_nonparam
		keep if !missing(DFE_nonparam)
		gduplicates drop
		gisid destination
		export delimited using "data_coded/dfe_bgd_robust_nonparam.csv", replace
	restore








***********************
*** Part 2
***********************

*** SLK: "home work" and "daily trips" are already ran for Table 1

***********************
*** SLK full sample -- include tower pairs < 180 seconds away and include dummy
***********************
	use "data_coded_slk/flows/home_work_odmatrix_gravity", clear

	* define log duration censored from below at 180
	gen log_dur = log(max(180,duration_intp))
	gen closer_tower = duration_intp < 180

	*** 
	ppmlhdfe volume log_dur closer_tower if sample_v1 == 1, ///
			ab(origin DFE_close_towers=destination) cl(origin destination) verbose(1)

	preserve 
		keep destination DFE_close_towers
		keep if !missing(DFE_close_towers)
		gduplicates drop
		gisid destination
		export delimited using "data_coded/dfe_slk_robust_close_towers.csv", replace
	restore

***********************
*** SLK log volume (dropping zeros)
***********************
	gen log_volume = log(volume)

	*** 
	reghdfe log_volume log_dur if sample_v2 == 1, ///
			ab(origin DFE_logvol=destination) cl(origin destination) verbose(1)

	preserve 
		keep destination DFE_logvol
		keep if !missing(DFE_logvol)
		gduplicates drop
		gisid destination
		export delimited using "data_coded/dfe_slk_robust_logvol.csv", replace
	restore

***********************
*** SLK log volume plus 1
***********************
	gen log_volume_plus1 = log(volume+1)

	*** 
	reghdfe log_volume_plus1 log_dur if sample_v2 == 1, ///
			ab(origin DFE_plus1=destination) cl(origin destination) verbose(1)

	preserve
		keep destination DFE_plus1
		keep if !missing(DFE_plus1)
		gduplicates drop
		gisid destination
		export delimited using "data_coded/dfe_slk_robust_logvol_plus1.csv", replace
	restore

***********************
*** SLK non-parametric distance
***********************
	gquantiles duration_intp_q10 = duration_intp, xtile nq(10)

	*** 
	ppmlhdfe volume duration_intp_q10 if sample_v2 == 1, ///
			ab(origin DFE_nonparam=destination) cl(origin destination) verbose(1)

	preserve
		keep destination DFE_nonparam
		keep if !missing(DFE_nonparam)
		gduplicates drop
		gisid destination
		export delimited using "data_coded/dfe_slk_robust_nonparam.csv", replace
	restore


***********************
*** SLK using duration with traffic 
***********************

	gen log_dur_traffic = log(duration_in_traffic_intp)

	*** 
	ppmlhdfe volume log_dur_traffic if sample_v2 == 1, ///
			ab(origin DFE_traffic=destination) cl(origin destination) verbose(1)

	preserve
		keep destination DFE_traffic
		keep if !missing(DFE_traffic)
		gduplicates drop
		gisid destination
		export delimited using "data_coded/dfe_slk_robust_traffic.csv", replace
	restore




***********************
*** Part 3: Table H4
***********************

*** Load and merge for BGD
	forv i=1/5{
		local file_name: word `i' of 	"dfe_bgd_daily_trips" ///
										"dfe_bgd_robust_close_towers" ///
										"dfe_bgd_robust_logvol" ///
										"dfe_bgd_robust_logvol_plus1" ///
										"dfe_bgd_robust_nonparam"
		import delimited using "data_coded/`file_name'.csv", clear
		tempfile part`i'
		save 	`part`i''
	}

	import delimited using "data_coded/dfe_bgd_home_work.csv", clear

	rename dfe DFE_benchmark
	
	forv i=1/5{
		merge 1:1 destination using `part`i''
		drop _m
	}

estimates clear

*** Column 1: Daily Flows
	eststo: reg DFE_benchmark dfe, r
	estadd local estimation_method = "PPML"
	estadd local city="Dhaka"

*** Column 2: Full sample
	eststo: reg DFE_benchmark dfe_close_towers, r
	estadd local estimation_method = "PPML"
	estadd local city="Dhaka" 

*** Column 3: Log(volume)
	eststo: reg DFE_benchmark dfe_logvol, r
	estadd local estimation_method = "OLS"
	estadd local city="Dhaka" 

*** Column 4: Log(volume+1)
	eststo: reg DFE_benchmark dfe_plus1, r
	estadd local estimation_method = "OLS"
	estadd local city="Dhaka" 

*** Column 5: non-parametric
	eststo: reg DFE_benchmark dfe_nonparam, r
	estadd local estimation_method = "PPML"
	estadd local city="Dhaka"



*** Load and merge for SLK
	forv i=1/6{
		local file_name: word `i' of 	"dfe_slk_daily_trips" ///
										"dfe_slk_robust_close_towers" ///
										"dfe_slk_robust_logvol" ///
										"dfe_slk_robust_logvol_plus1" ///
										"dfe_slk_robust_nonparam" ///
										"dfe_slk_robust_traffic"
		import delimited using "data_coded/`file_name'.csv", clear
		tempfile part`i'
		save 	`part`i''
	}

	import delimited using "data_coded/dfe_slk_home_work.csv", clear

	rename dfe DFE_benchmark
	
	forv i=1/6{
		merge 1:1 destination using `part`i''
		// assert _m==3
		drop _m
	}


*** Column 6: Daily Flows
	eststo: reg DFE_benchmark dfe, r
	estadd local estimation_method = "PPML"
	estadd local city="Colombo"

*** Column 7: Full sample
	eststo: reg DFE_benchmark dfe_close_towers, r
	estadd local estimation_method = "PPML"
	estadd local city="Colombo"

*** Column 8: Log(volume)
	eststo: reg DFE_benchmark dfe_logvol, r
	estadd local estimation_method = "OLS"
	estadd local city="Colombo"

*** Column 9: Log(volume+1)
	eststo: reg DFE_benchmark dfe_plus1, r
	estadd local estimation_method = "OLS"
	estadd local city="Colombo"

*** Column 10: non-parametric
	eststo: reg DFE_benchmark dfe_nonparam, r
	estadd local estimation_method = "PPML"
	estadd local city="Colombo"

*** Column 11: travel time with congestion
	eststo: reg DFE_benchmark dfe_traffic, r
	estadd local estimation_method = "PPML"
	estadd local city="Colombo"



*** Save to table
	esttab * using "tables/table_H4/table_H4.tex", ///
		replace drop(_cons) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	dfe 			 "Dest FE (Daily Flows)" ///
					dfe_close_towers "Dest FE (Full Sample)" ///
					dfe_logvol		 "Dest FE (OLS with log(volume))" ///
					dfe_plus1		 "Dest FE (OLS with log(volume+1))" ///
					dfe_nonparam	 "Dest FE (Nonparametric Gravity Equation)" ///
					dfe_traffic		 "Dest FE (Travel Time with Congestion)") ///
		starlevels(* .10 ** .05 *** .01) /* nonumbers */ ///
		mtitles("Destination Fixed Effects (Benchmark)" ) ///
		stats(estimation_method city N r2_a, ///
				labels("Estimation method" "City" "Observations" "Adjusted R2") ///
				fmt("%s" "%s"  "%12.0fc" "%12.2f")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes



