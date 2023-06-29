*** This do file: simulates data using BGD geographic structure, and runs naive and MLE 2 skills gravity

clear all
set seed 342423

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"
	adopath ++ "${cellphone_root}ado/"

*** Simulation parameters
	scalar beta_low_skill = -4
	scalar beta_high_skill = -2

	scalar dfe_standard_deviation = 0.8
	scalar dfe_skill_specific_sd  = 0.4


*** Create true destination fixed effects
	use "data_coded_bgd/flows/home_work_odmatrix_2kills", clear

	keep destination
	gduplicates drop
	sort destination
	gen dfe_common = rnormal(-1,dfe_standard_deviation)
	gen dfe_low  = dfe_common + rnormal(0,dfe_skill_specific_sd)
	gen dfe_high = dfe_common + rnormal(0,dfe_skill_specific_sd)

	** keep support limited
	replace dfe_low = min(2,dfe_low)
	replace dfe_high = min(2,dfe_high)

	tempfile dfes_true
	save    `dfes_true'


*** Load BGD data and simulate volume
	use "data_coded_bgd/flows/home_work_odmatrix_2kills", clear

	bys origin: gen o1=_n==1
	sum perc_literate if o1==1, d
	
	scalar p01_lit = r(p1) // .5774792
	scalar p10_lit = r(p10) // .5774792
	scalar p90_lit = r(p90) // .8607344
	scalar p99_lit = r(p99) // .8607344

	bys destination: gen d1 = _n==1

	hashsort origin destination

	keep origin destination volume log_dur perc_literate pop_res_low pop_res_high d1

	merge m:1 destination using `dfes_true'
	assert _m==3
	drop _m

	*** LOW type 
	gen double u_low = dfe_low + beta_low_skill * log_dur
	gen double choice_prob_low = exp(u_low)
	gegen double choice_prob_low_sum_origin = sum(choice_prob_low), by(origin)
	replace choice_prob_low = choice_prob_low / choice_prob_low_sum_origin

	*** HIGH type
	gen double u_high = dfe_high + beta_high_skill * log_dur
	gen double choice_prob_high = exp(u_high)
	gegen double choice_prob_high_sum_origin = sum(choice_prob_high), by(origin)
	replace choice_prob_high = choice_prob_high / choice_prob_high_sum_origin

	gen volume_simulated = pop_res_low * choice_prob_low + pop_res_high * choice_prob_high
	gen vol_sim_low = pop_res_low  * choice_prob_low
	gen vol_sim_high= pop_res_high * choice_prob_high


*** Simulate three scenarios for the Poisson variable
	gen volume_simulated_poisson = rpoisson(volume_simulated)
	gen volume_simulated_poisson_x10 = rpoisson(volume_simulated * 10)
	gen volume_simulated_poisson_x100 = rpoisson(volume_simulated * 100)

	count if volume_simulated_poisson      == 0
	count if volume_simulated_poisson_x10  == 0
	count if volume_simulated_poisson_x100 == 0

*** Save 
	// compress
	// save "data/coded_bgd/skills-ppml/sim_ready.dta", replace


*** initialize iterative procedure with naive FEs 
	// use "data/coded_bgd/skills-ppml/sim_ready.dta", clear

*** Run pooled regression on simulated data 
	ppmlhdfe volume_simulated_poisson log_dur, ab(origin DFE_pool=destination) cl(origin destination) // standardize_data(0)
	gen _beta_slope_pool = _b[log_dur]


*** Run naive regression on simulated data 
	gen log_dur_literate   = log_dur * perc_literate
	gen log_dur_non_literate   = log_dur * (1-perc_literate)

	*** run with destination-specific slope of the origin-level percent literate
	ppmlhdfe volume_simulated_poisson log_dur_non_literate log_dur_literate, ///
				ab(origin DFE_naive=destination##c.perc_literate) cl(origin destination)

	*** 
	gen _beta_slope_naive_low  = _b[log_dur_non_literate]
	gen _beta_slope_naive_high = _b[log_dur_literate]

	*** fes
	gen DFE_naive_low  = DFE_naive
	gen DFE_naive_high = DFE_naive + DFE_naiveSlope1

	drop DFE_naive DFE_naiveSlope1


*** Run MLE starting from zero
	*** RUN starting from ZERO dest FE and naive slope
	sum _beta_slope_naive_low
	scalar s_beta_low = r(mean)
	sum _beta_slope_naive_high
	scalar s_beta_high = r(mean)

	*** Start from zero DEST FE
	// DFE_naive_low DFE_naive_high
	gen double DFE_init_low = 0
	gen double DFE_init_high = 0
	
	gravity2skills volume_simulated_poisson DFE_init_low DFE_init_high pop_res_low pop_res_high, ///
									beta_slope_low(`=s_beta_low') beta_slope_high(`=s_beta_high') ///
									tolerance_ll(1) debug_level(1)

	label var DFE_pool 				"Destination FE pooled regression"
	label var _beta_slope_pool 		"log dist slope pooled regression"
	label var DFE_naive_low  		"Destination FE low  skill linear interactions"
	label var DFE_naive_high 		"Destination FE high skill linear interactions"
	label var _beta_slope_naive_low "log dist slope low  skill linear interactions"
	label var _beta_slope_naive_high "log dist slope high skill linear interactions"
	label var DFE_current_low  		"Destination FE low  skill gravity 2 types (MLE)"
	label var DFE_current_high  	"Destination FE high skill gravity 2 types (MLE)"
	label var _beta_slope_low 		"log dist slope low  skill gravity 2 types (MLE)"
	label var _beta_slope_high 		"log dist slope high skill gravity 2 types (MLE)"


*** Save 
	// compress
	// save "data/coded_bgd/skills-ppml/sim_results.dta", replace

*** Output for simulation table
	keep if d1 ==1 
	keep destination DFE_pool DFE_naive_* DFE_current_* _beta_slope_* dfe_low dfe_high
	gisid destination

	estimates clear

	*** pooled regression
	eststo dfe_pooled: reg DFE_pool dfe_low dfe_high, r

	*** naive regression
	eststo dfe_naive_low: reg DFE_naive_low  dfe_low dfe_high, r
	eststo dfe_naive_high: reg DFE_naive_high dfe_low dfe_high, r

	*** MLE
	eststo dfe_mle_low : reg DFE_current_low  dfe_low dfe_high, r
	eststo dfe_mle_high: reg DFE_current_high dfe_low dfe_high, r

*** Panel A: compare the destination FEs
	esttab * using "tables/table_C1/simulation_gravity_panelA.tex", ///
		replace drop(_cons) frag ///
		b(%12.2f) se(%12.2f) ///
		coeflabels(	dfe_low  "True Low Skill FE $\psi_j^L$" ///
					dfe_high "True High Skill FE $$\psi_j^H$$" ///
					_cons "Constant") ///
		starlevels(* .10 ** .05 *** .01) nonumbers nomtitles ///
		stats(N r2_a, labels("Observations" "Adjusted R2") fmt("%12.0fc" "%12.2f")) booktabs ///
		substitute(_ \_ "<" "$<$" "\midrule" "\addlinespace\addlinespace") nonotes


*** Distance slopes to put in the table
	sum _beta_slope_pool
	local bp: display %4.2f `r(mean)' 

	sum _beta_slope_naive_low
	local bnlow: display %4.2f `r(mean)' 

	sum _beta_slope_naive_high
	local bnhigh: display %4.2f `r(mean)' 

	sum _beta_slope_low
	local bmlelow: display %4.2f `r(mean)' 

	sum _beta_slope_high
	local bmlehigh: display %4.2f `r(mean)' 

	local btruelow : display %4.2f `=beta_low_skill'
	local btruehigh: display %4.2f `=beta_high_skill'

*** Write main table tex file
	file open myfile using "tables\table_C1\simulation_gravity_main.tex", write replace
	file write myfile "\begin{tabular}{lc{\hskip 0.25in}cc@{\hskip 0.25in}cc@{\hskip 0.25in}c}" _n "\toprule" _n  ///
					  " & (1) & (2) & (3) & (4) & (5) & (6) \\" _n ///
					  "\textit{Estimation Method:} & Pooled eq. (3) & \multicolumn{2}{c}{Log-linear eq. (8)} & \multicolumn{2}{c}{MLE eq. (7)} & \\ " _n ///
					  "\addlinespace" _n ///
					  "\textit{Outcome} & $\hat\psi_j$ & $\hat\psi_j^L$ & $\hat\psi_j^H$ & $\hat\psi_j^L$ & $\hat\psi_j^H$ &  \\" _n ///
					  "\addlinespace\addlinespace\multicolumn{7}{l}{\emph{Panel A. Destination Fixed Effects}} \\" _n ///
				   	  "\ExpandableInput{simulation_gravity_panelA}" _n ///
				   	  "\addlinespace\addlinespace\multicolumn{7}{l}{\emph{Panel B. Distance Slopes}} \\" _n ///
				   	  "\textit{Estimation Method:} & Pooled eq. (3) & \multicolumn{2}{c}{Log-linear eq. (8)} & \multicolumn{2}{c}{MLE eq. (7)} & \thead{True \\ parameter} \\ " _n ///
				   	  "log Travel Time 					   & `bp' & 		 & & 			& & \\" _n ///
				   	  "log Travel Time $\times$ Low Skill  &      & \multicolumn{2}{c}{`bnlow'}  & \multicolumn{2}{c}{`bmlelow'} & `btruelow' \\" _n ///
				   	  "log Travel Time $\times$ High Skill &      & \multicolumn{2}{c}{`bnhigh'} & \multicolumn{2}{c}{`bmlehigh'} & `btruehigh' \\" _n ///
					  "\addlinespace" _n "\bottomrule" _n "\end{tabular}" _n ///

	file close myfile



