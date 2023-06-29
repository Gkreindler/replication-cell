* This do file: Table E1: gravity regression overidentification

clear all
set seed 342423

*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** SLK
	use "data_coded_slk/flows/home_work_odmatrix_gravity.dta", clear

	drop if missing(duration_intp)
	gen 	log_dur = log(duration_intp)
	replace log_dur = log(180) if duration_intp < 180
	assert !missing(log_dur)

	keep origin destination log_dur volume duration_intp

	gen old_sample = duration_intp >= 180
	bys destination: gen d1=_n==1

*** Pooled regression results
	eststo gravity_slk_pool: ppmlhdfe volume log_dur if old_sample == 1, ab(origin DFE_pool=destination)
	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)
	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	gen double _beta_slope_pool = _b[log_dur]

*** find distance cutoff
	sum duration_intp if old_sample == 1 [fw=volume], d
	scalar median_duration = r(p50)

	di median_duration // 1098.6209

	sum volume if duration_intp <= `=median_duration' & old_sample == 1
	di r(sum)
	sum volume if duration_intp > `=median_duration'  & old_sample == 1
	di r(sum)	

*** OVER-ID gravity
	eststo gravity_slk_close: ppmlhdfe volume log_dur if old_sample == 1 & duration_intp <= `=median_duration' , ab(origin DFE_close=destination)
	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)
	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)
	
	eststo gravity_slk_far: ppmlhdfe volume log_dur if old_sample == 1 & duration_intp >  `=median_duration' , ab(origin DFE_far=destination)
	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)
	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	*** Fill in destination FEs and beta
	hashsort destination
	foreach myvar of varlist DFE_close DFE_far DFE_pool _beta_* {
		gegen temp = mean(`myvar'), by(destination)
		replace `myvar' = temp
		drop temp
	}

	corr DFE_close DFE_far if d1==1
	estadd scalar rho_destfe = r(rho)


*** BGD tower area
	use "data_raw_bgd/other/towers_bgd", clear
	keep tower area_km2
	rename tower destination
	rename area_km2 km2_tower_d

	tempfile dest_area
	save 	`dest_area'


*** BGD
	use "data_coded_bgd/flows/home_work_odmatrix_gravity.dta", clear
	drop if missing(duration_intp)
	gen 	log_dur = log(duration_intp)
	replace log_dur = log(180) if duration_intp < 180
	assert !missing(log_dur)

	keep origin destination origin_czone destination_czone log_dur volume duration_intp

	merge m:1 destination using `dest_area'
	drop if _m==2
	assert _m!=1
	drop _m

	gen old_sample = duration_intp >= 180
	bys destination: gen d1=_n==1

*** Pooled regression results
	eststo gravity_bgd_pool: ppmlhdfe volume log_dur if old_sample == 1, ab(origin DFE_pool=destination)
	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)
	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	gen double _beta_slope_pool = _b[log_dur]
	

*** find distance cutoff
	sum duration_intp if old_sample == 1 [fw=volume], d
	scalar median_duration = r(p50)

	di median_duration // 805

	sum volume if duration_intp <= `=median_duration' & old_sample == 1
	di r(sum)
	sum volume if duration_intp > `=median_duration'  & old_sample == 1
	di r(sum)

	

*** OVER-ID gravity
	eststo gravity_bgd_close: ppmlhdfe volume log_dur if old_sample == 1 & duration_intp <= `=median_duration' , ab(origin DFE_close=destination)
	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)
	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	gen double _beta_slope_pool_close = _b[log_dur]
	
	eststo gravity_bgd_far: ppmlhdfe volume log_dur if old_sample == 1 & duration_intp >  `=median_duration' , ab(origin DFE_far=destination)
	gunique destination if e(sample) == 1
	estadd scalar n_dest = r(J)
	qui sum volume if e(sample) == 1
	estadd scalar n_trips = r(sum)

	gen double _beta_slope_pool_far = _b[log_dur]

	*** Fill in destination FEs and beta
	hashsort destination
	foreach myvar of varlist DFE_close DFE_far DFE_pool _beta_* {
		gegen temp = mean(`myvar'), by(destination)
		replace `myvar' = temp
		drop temp
	}

	corr DFE_close DFE_far if d1==1
	estadd scalar rho_destfe = r(rho)


*** Save Panel A (gravity equation) -- precise sample sizes
	esttab * using "tables/table_E1/table_E1_panel_A_exact_sample_size.tex", ///
		frag replace drop(_cons) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	log_dur "log Travel Time") ///
		starlevels(* .10 ** .05 *** .01) nonumbers nomtitles ///
		stats(	rho_destfe n_dest n_trips N r2_p, ///
				labels(" $ Corr(\hat\psi_j^{Close}, \hat\psi_j^{Far}) $" "Number of Destination FE" "Number of Trips" "Observations" "Pseudo R2") ///
				fmt("%4.2f" "%12.0fc" "%12.0fc" "%12.0fc" "%12.2f")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes

*** Save Panel A (gravity equation) -- Exponential notation for sample size
	esttab * using "tables/table_E1/table_E1_panel_A.tex", ///
		frag replace drop(_cons) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	log_dur "log Travel Time") ///
		starlevels(* .10 ** .05 *** .01) nonumbers nomtitles ///
		stats(	rho_destfe n_dest n_trips N r2_p, ///
				labels(" $ Corr(\hat\psi_j^{Close}, \hat\psi_j^{Far}) $" "Number of Destination FE" "Number of Trips" "Observations" "Pseudo R2") ///
				fmt("%4.2f" "%12.0fc" "%3.1e" "%3.1e" "%12.2f")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes


*** Table E1 Panel B Workplace Income Validation (only BGD)

*** Three types:
* 1. pooled
* 2. ols low/high
* 3. mle   low/high

*** Construct vij measures i,j=0,1

forv i=1/3{
	local destfename: word `i' of pool 				pool_close 				pool_far 
	local destfe 	: word `i' of DFE_pool			DFE_close 				DFE_far 		
	local beta_slope: word `i' of _beta_slope_pool  _beta_slope_pool_close 	_beta_slope_pool_far 	
	
*** Version 00 - z and d neither productive (benchmark case used in the paper except Appendix C)
	gen `destfename'_v00 		= `destfe'
	gen `destfename'_adj_v00 	= `destfe' - log(km2_tower_d)
}

	gcollapse (mean) *_v??  [fw=volume], by(destination_czone)

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

*** Table E1: Validation using model income estimated using disjoint samples (close/far)
	estimates clear

	eststo valid_pool: reg mean_logy_dhuts_no_weight pool_adj_v00 [aw=vol_dhuts], r

	replace pool_adj_v00 = pool_close_adj_v00
	eststo valid_close: reg mean_logy_dhuts_no_weight pool_adj_v00 [aw=vol_dhuts], r

	replace pool_adj_v00 = pool_far_adj_v00
	eststo valid_far  : reg mean_logy_dhuts_no_weight pool_adj_v00 [aw=vol_dhuts], r


*** Save Panel B (Validation in BGD)
	esttab * using "tables/table_E1/table_E1_panel_B.tex", ///
		frag replace drop(_cons) ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	pool_adj_v00 "$\epsilon\times$ log Model Income (workplace)") ///
		starlevels(* .10 ** .05 *** .01) nonumbers mtitles("Pooled" "Close" "Far") ///
		stats(	N r2_a, ///
				labels("Observations" "Adjusted R2") ///
				fmt("%12.0fc" "%12.2f")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes


*** Write main table tex file
	file open myfile using "tables/table_E1/table_E1.tex", write replace
	file write myfile "\begin{tabular}{lccc@{\hskip 0.25in}ccc}" _n "\toprule" _n  ///
					  " & (1) & (2) & (3) & (4) & (5) & (6) \\" _n ///
					  " & \multicolumn{3}{c}{Dhaka} & \multicolumn{3}{c}{Colombo} & \\ " _n ///
					  "\textit{Sample:} &\multicolumn{1}{c}{Pooled}&\multicolumn{1}{c}{Close}&\multicolumn{1}{c}{Far} &\multicolumn{1}{c}{Pooled}&\multicolumn{1}{c}{Close}&\multicolumn{1}{c}{Far} \\" _n ///
					  "\addlinespace\addlinespace\multicolumn{7}{l}{\emph{Panel A. Gravity Equation}} \\" _n ///
					  "ADD PANEL A HERE MANUALLY \\" _n ///
					  "\addlinespace" _n ///
					  "\addlinespace\addlinespace\multicolumn{7}{l}{\emph{Panel B. Validation (Outcome: log Survey Income, Workplace)}} \\" _n ///
					  "ADD PANEL B HERE MANUALLY \\" _n ///
					  "\bottomrule" _n "\end{tabular}" _n ///

	file close myfile

