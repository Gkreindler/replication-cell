* This do file: Table 1: gravity equation and save destination fixed effects

clear all
set seed 342423

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"


***********************
*** BGD home work
***********************
	use "data_coded_bgd/flows/home_work_odmatrix_gravity", clear

	gen log_dur = log(duration_intp)

	*** run with destination-specific slope of the origin-level percent literate
	ppmlhdfe volume log_dur if sample_v2 == 1, ab(origin DFE=destination) cl(origin destination) verbose(1)

	estadd local city="Dhaka" 
	estadd local vol_measure = "Home-Work"

	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)

	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	estimates store bgd_home_work

	gen _beta_log_dur = _b[log_dur]

	keep destination DFE _beta_log_dur
	keep if !missing(DFE)
	gduplicates drop
	gisid destination
	export delimited using "data_coded/dfe_bgd_home_work.csv", replace

***********************
*** BGD daily trips
***********************
	use "data_coded_bgd/flows/daily_trips_odmatrix_gravity", clear

	gen log_dur = log(duration_intp)

	*** run with destination-specific slope of the origin-level percent literate
	ppmlhdfe volume log_dur if sample_v2 == 1, ab(origin DFE=destination) cl(origin destination) verbose(1)

	estadd local city="Dhaka" 
	estadd local vol_measure = "Daily Trips"

	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)

	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	estimates store bgd_daily_trips

	gen _beta_log_dur = _b[log_dur]

	keep destination DFE _beta_log_dur
	keep if !missing(DFE)
	gduplicates drop
	gisid destination
	export delimited using "data_coded/dfe_bgd_daily_trips.csv", replace


***********************
*** BGD with skills ***
***********************

*** load data
	use "data_coded_bgd/flows/home_work_odmatrix_2kills", clear

	*** run with destination-specific slope of the origin-level percent literate
	ppmlhdfe volume log_dur_non_literate log_dur_literate, ///
			ab(origin DFE=destination##c.perc_literate) cl(origin destination) verbose(1)

	estadd local city="Dhaka" 
	estadd local vol_measure = "Home-Work"
	estadd local estimation_method = "Log-Linear"

	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)

	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	estimates store bgd_skill

	*** Save FE and distance slope 
	gen _beta_slope_OLS_low  = _b[log_dur_non_literate]
	gen _beta_slope_OLS_high = _b[log_dur_literate]

	gen DFE_OLS_low  = DFE
	gen DFE_OLS_high = DFE + DFESlope1

	keep destination DFE_OLS_low DFE_OLS_high _beta_slope_OLS_low _beta_slope_OLS_high
	keep if !missing(DFE_OLS_low)
	gduplicates drop
	gisid destination
	export delimited using "data_coded/dfe_bgd_skills.csv", replace








***********************
*** SLK home work
***********************
	use "data_coded_slk/flows/home_work_odmatrix_gravity", clear

	gen log_dur = log(duration_intp)

	*** run with destination-specific slope of the origin-level percent literate
	ppmlhdfe volume log_dur if sample_v2 == 1, ab(origin DFE=destination) cl(origin destination) verbose(1)

	estadd local city="Colombo" 
	estadd local vol_measure = "Home-Work"

	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)

	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	estimates store slk_home_work

	gen _beta_log_dur = _b[log_dur]

	keep destination DFE _beta_log_dur
	keep if !missing(DFE)
	gduplicates drop
	gisid destination
	export delimited using "data_coded/dfe_slk_home_work.csv", replace


***********************
*** SLK daily trips
***********************
	use "data_coded_slk/flows/daily_trips_odmatrix_gravity", clear

	gen log_dur = log(duration_intp)

	*** run with destination-specific slope of the origin-level percent literate
	ppmlhdfe volume log_dur if sample_v2 == 1, ab(origin DFE=destination) cl(origin destination) verbose(1)

	estadd local city="Colombo" 
	estadd local vol_measure = "Daily Trips"

	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)

	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	estimates store slk_daily_trips

	gen _beta_log_dur = _b[log_dur]

	keep destination DFE _beta_log_dur
	keep if !missing(DFE)
	gduplicates drop
	gisid destination
	export delimited using "data_coded/dfe_slk_daily_trips.csv", replace




***********************
*** SLK with skills ***
***********************

*** load data
	use "data_coded_slk/flows/home_work_odmatrix_2kills", clear

	*** run with destination-specific slope of the origin-level percent literate
	ppmlhdfe volume log_dur_non_literate log_dur_literate, ab(origin DFE=destination##c.perc_literate) ///
			cl(origin destination) verbose(1)

	estadd local city="Colombo" 
	estadd local vol_measure = "Home-Work"
	estadd local estimation_method = "Log-Linear"

	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)

	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	estimates store slk_skill

	*** Save FE and distance slope 
	gen _beta_slope_OLS_low  = _b[log_dur_non_literate]
	gen _beta_slope_OLS_high = _b[log_dur_literate]

	gen DFE_OLS_low  = DFE
	gen DFE_OLS_high = DFE + DFESlope1

	keep destination DFE_OLS_low DFE_OLS_high _beta_slope_OLS_low _beta_slope_OLS_high
	keep if !missing(DFE_OLS_low)
	gduplicates drop
	gisid destination
	export delimited using "data_coded/dfe_slk_skills.csv", replace


















*** Full notation for sample size
	esttab * using "tables/table_1/table_1_main_exact_sample_size.tex", ///
		replace drop(_cons) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	log_dur 			 "log Travel Time" ///
					log_dur_non_literate "log Travel Time $\times$ Low Skill" ///
						log_dur_literate "log Travel Time $\times$ High Skill" ) ///
		starlevels(* .10 ** .05 *** .01) /* nonumbers */ ///
		mtitles("Commuting Probability" ) ///
		stats(city vol_measure n_dest n_trips N r2_p, ///
				labels("City" "Comuting Measure" "Number of Destination FE" "Number of Trips" "Observations" "Pseudo R2") ///
				fmt("%s" "%s"  "%12.0fc" "%12.2fc" "%12.2fc" "%12.2f")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes

*** Exponential notation for sample size
	esttab * using "tables/table_1/table_1_main.tex", ///
		replace drop(_cons) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	log_dur 			 "log Travel Time" ///
					log_dur_non_literate "log Travel Time $\times$ Low Skill" ///
						log_dur_literate "log Travel Time $\times$ High Skill" ) ///
		starlevels(* .10 ** .05 *** .01) /* nonumbers */ ///
		mtitles("Commuting Probability" ) ///
		stats(city vol_measure n_dest n_trips N r2_p, ///
				labels("City" "Comuting Measure" "Number of Destination FE" "Number of Trips" "Observations" "Pseudo R2") ///
				fmt("%s" "%s"  "%12.0fc" "%3.1e" "%3.1e" "%12.2f")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes



*** For table C2: column 1 (BGD)
	esttab bgd_skill using "tables/table_C2/table_C2_col1.tex", ///
		replace drop(_cons) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	log_dur_non_literate "log Travel Time $\times$ Low Skill" ///
						log_dur_literate "log Travel Time $\times$ High Skill" ) ///
		starlevels(* .10 ** .05 *** .01) /* nonumbers */ ///
		mtitles("Commuting Probability" ) ///
		stats(city estimation_method n_dest n_trips N, ///
				labels("City" "Estimation Method" "Number of Destination FE" "Number of Trips" "Observations") ///
				fmt("%s" "%s"  "%12.0fc" "%3.1e" "%3.1e")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes

*** For table C2: column 3
	esttab slk_skill using "tables/table_C2/table_C2_col3.tex", ///
		replace drop(_cons) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	log_dur_non_literate "log Travel Time $\times$ Low Skill" ///
						log_dur_literate "log Travel Time $\times$ High Skill" ) ///
		starlevels(* .10 ** .05 *** .01) /* nonumbers */ ///
		mtitles("Commuting Probability" ) ///
		stats(city estimation_method n_dest n_trips N, ///
				labels("City" "Estimation Method" "Number of Destination FE" "Number of Trips" "Observations") ///
				fmt("%s" "%s"  "%12.0fc" "%3.1e" "%3.1e")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes
