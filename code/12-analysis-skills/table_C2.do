* This do file: gravity equation by skills using MLE (the first model cited in appendix C)

clear all
set seed 342423

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"
	adopath ++ "${cellphone_root}ado/"

/* 
Columns 1 and 3 of Table C2 are identical to columns 3 and 6 in Table 1 and hence generated in table_1.do
*/


************
*** BGD MLE
************

*** Load OLS results (generated in table_1.do)
	import delimited using "data_coded/dfe_bgd_skills.csv", clear
	tempfile bgd_ols
	save 	`bgd_ols'


*** Load
	use "data_coded_bgd/gravity/home_work_odmatrix_2kills", clear
	bys destination: gen d1 = _n==1

*** merge OLS results
	merge m:1 destination using `bgd_ols'
	assert _m==3
	drop _m

*** Run MLE with initial conditions given by the OLS destination fixed effects and beta slope
	sum _beta_slope_ols_low
	scalar s_beta_low = r(mean)
	sum _beta_slope_ols_high
	scalar s_beta_high = r(mean)
	
	gravity2skills volume dfe_ols_low dfe_ols_high pop_res_low pop_res_high, ///
									beta_slope_low(`=s_beta_low') beta_slope_high(`=s_beta_high') ///
									tolerance_ll(10) debug_level(1)

	rename DFE_current_low  DFE_MLE_low
	rename DFE_current_high DFE_MLE_high

	keep destination DFE_MLE_low DFE_MLE_high _beta_slope_low _beta_slope_high
	gduplicates drop
	keep if !missing(DFE_MLE_low)
	gduplicates drop
	gisid destination
	export delimited using "data_coded/dfe_bgd_skills_MLE.csv", replace

*** Save column 2 in Table C2
	use "data_coded_bgd/gravity/home_work_odmatrix_2kills", clear
	qui sum volume
	local n_trips: di %10.0fc r(sum)
	local n_obs: di %10.0fc r(N)

	import delimited using "data_coded/dfe_bgd_skills_MLE.csv", clear
	merge 1:1 destination using `bgd_ols'
	assert _m==3
	drop _m

	gunique destination
	local n_dest: di %10.0fc r(J)

	qui sum _beta_slope_low
	local beta_low: di %4.2f r(mean)

	qui sum _beta_slope_high
	local beta_high: di %4.2f r(mean)

	corr dfe_mle_high dfe_ols_high
	local corr_high: di %4.2f r(rho)

	corr dfe_mle_low dfe_ols_low
	local corr_low: di %4.2f r(rho)

*** Write main table tex file
	file open myfile using "tables/table_C2/table_C2_col2.tex", write replace
	file write myfile "\begin{tabular}{lc}" _n "\toprule" _n  ///
					  " & (2) \\" _n ///
					  "\addlinespace\addlinespace" _n ///
					  "Low Skill $\times$ log Travel Time&       `beta_low' \\" _n ///
					  "\addlinespace" _n ///
					  "High Skill $\times$ log Travel Time&       `beta_high' \\" _n ///
					  "\addlinespace\addlinespace" _n ///
					  "City & Dhaka" _n ///
					  "Estimation Method & MLE" _n ///
					  "$\text{Corr}(\hat\psi_j^{L,MLE}, \hat\psi_j^{L,LL})$ &        `corr_low'   \\" _n ///
					  "$\text{Corr}(\hat\psi_j^{H,MLE}, \hat\psi_j^{H,LL})$ &        `corr_high'   \\" _n ///
					  "Number of Destination FE&        `n_dest'   \\" _n ///
					  "Number of Trips&     `n_trips'   \\" _n ///
					  "Observations&   `n_obs'   \\" _n ///
					  "\bottomrule" _n "\end{tabular}" _n ///

	file close myfile




************
*** SLK MLE
************

*** Load OLS results (generated in table_1.do)
	import delimited using "data_coded/dfe_slk_skills.csv", clear
	tempfile slk_ols
	save 	`slk_ols'

** Load
	use "data_coded_slk/gravity/home_work_odmatrix_2kills", clear
	bys destination: gen d1 = _n==1

*** merge OLS results
	merge m:1 destination using `slk_ols'
	assert _m==3
	drop _m

*** Run MLE with initial conditions given by the OLS destination fixed effects and beta slope
	sum _beta_slope_ols_low
	scalar s_beta_low = r(mean)
	sum _beta_slope_ols_high
	scalar s_beta_high = r(mean)
	
	gravity2skills volume dfe_ols_low dfe_ols_high pop_res_low pop_res_high, ///
									beta_slope_low(`=s_beta_low') beta_slope_high(`=s_beta_high') ///
									tolerance_ll(10) debug_level(1)

	rename DFE_current_low  DFE_MLE_low
	rename DFE_current_high DFE_MLE_high

	keep destination DFE_MLE_low DFE_MLE_high _beta_slope_low _beta_slope_high
	gduplicates drop
	keep if !missing(DFE_MLE_low)
	gduplicates drop
	gisid destination
	export delimited using "data_coded/dfe_slk_skills_MLE.csv", replace

*** Save column 2 in Table C2
	use "data_coded_slk/gravity/home_work_odmatrix_2kills", clear
	qui sum volume
	local n_trips: di %10.0fc r(sum)
	local n_obs: di %10.0fc r(N)

	import delimited using "data_coded/dfe_slk_skills_MLE.csv", clear
	merge 1:1 destination using `slk_ols'
	assert _m==3
	drop _m

	gunique destination
	local n_dest: di %10.0fc r(J)
	
	qui sum _beta_slope_low
	local beta_low: di %4.2f r(mean)
	
	qui sum _beta_slope_high
	local beta_high: di %4.2f r(mean)

	corr dfe_mle_high dfe_ols_high
	local corr_high: di %4.2f r(rho)

	corr dfe_mle_low dfe_ols_low
	local corr_low: di %4.2f r(rho)

*** Write main table tex file
	file open myfile using "tables/table_C2/table_C2_col4.tex", write replace
	file write myfile "\begin{tabular}{lc}" _n "\toprule" _n  ///
					  " & (4) \\" _n ///
					  "\addlinespace\addlinespace" _n ///
					  "Low Skill $\times$ log Travel Time&       `beta_low' \\" _n ///
					  "\addlinespace" _n ///
					  "High Skill $\times$ log Travel Time&       `beta_high' \\" _n ///
					  "\addlinespace\addlinespace" _n ///
					  "City & Colombo" _n ///
					  "Estimation Method & MLE" _n ///
					  "$\text{Corr}(\hat\psi_j^{L,MLE}, \hat\psi_j^{L,LL})$ &        `corr_low'   \\" _n ///
					  "$\text{Corr}(\hat\psi_j^{H,MLE}, \hat\psi_j^{H,LL})$ &        `corr_high'   \\" _n ///
					  "Number of Destination FE&        `n_dest'   \\" _n ///
					  "Number of Trips&     `n_trips'   \\" _n ///
					  "Observations&   `n_obs'   \\" _n ///
					  "\bottomrule" _n "\end{tabular}" _n ///

	file close myfile




