*** MLE on gravity with two skill groups
* Syntax:
* Variables:
* 	1. outcome variable (with zeros)
* 	2. low  skill initial destination fixed effects (must be constant within destination -- no checks)
* 	3. high skill initial destination fixed effects (must be constant within destination -- no checks)
*	4. low  skill residential population (must be constant within origin -- no checks)
*	5. high skill residential population (must be constant within origin -- no checks)

cap program drop gravity2skills
program define gravity2skills

	syntax varlist(min=5 max=5 numeric), beta_slope_low(real) beta_slope_high(real) ///
										 tolerance_ll(real) [dfe_step(real 0.1) beta_score_param(real 0.001) debug_level(integer 0)]


*** Variables:
	local i=1
	foreach var of local varlist {
		local varlist_`i' `var'
		local i = `i' + 1
	}

	local yi_outcome 		`varlist_1'
	local DFE_initial_low  	`varlist_2'
	local DFE_initial_high 	`varlist_3'
	local pop_res_low 		`varlist_4'
	local pop_res_high 		`varlist_5'

*** initialize 

	scalar beta_score_param = `beta_score_param' //1/1000
	scalar dfe_step_gradient = `dfe_step' // 0.1
	scalar tolerance_ll = `tolerance_ll' // 0.1
	scalar debug_level = `debug_level' // 0


*** OUTCOME var, and initial conditions for distance and volume:

*****************
*** REAL DATA ***
	
	*** OUTCOME
	// local yi_outcome volume //volume_simulated_poisson

	*** Initial conditions
	gen DFE_current_low  = `DFE_initial_low'
	gen DFE_current_high = `DFE_initial_high'

	scalar beta_slope_current_low  = `beta_slope_low'
	scalar beta_slope_current_high = `beta_slope_high'


*** Frame to Store Results
	cap frame drop iteration_results
	frame create iteration_results
	frame change iteration_results
		qui set obs 10000
		qui gen iteration_number = .
		qui gen double current_ll = .
		qui gen double current_ll_change10 = .
		qui gen double beta_slope_low  = .
		qui gen double beta_slope_high = .

*** TEMPORARY empty variables
	frame change default

	qui gen double exp_high = .
	qui gen double exp_low  = .

	// mu_high defined each time

	qui gen double mu_high_other = .
	qui gen double mu_low_other  = .

	qui gen double lambda_ij = .
	
	qui gen double score_beta_low  = .
	qui gen double score_beta_high = .

	qui gen double indirect_ik_low = .
	qui gen double indirect_ik_sum_orig_less_low = .
	qui gen double indirect_ij_low = .
	qui gen double indirect_ik_high = .
	qui gen double indirect_ik_sum_orig_less_high = .
	qui gen double indirect_ij_high = .

	qui gen double score_low  = .
	qui gen double score_high = .
	qui gen double temp_score_norm_2 = .

	qui gen double B_low_var_TEMP  = .
	qui gen double B_high_var_TEMP = .

	qui gen double DFE_current_TEMP_low = .
	qui gen double DFE_current_TEMP_high = .

	* change in lambda this step
	qui gen double loglikelihood = 0

scalar converged = 0
scalar iteration_idx = 1

* initialize step size
	scalar dfe_step_gradient_TEMP = dfe_step_gradient
	local total_ll_old = -1000000

	hashsort destination origin

while (converged == 0){
	di "Iteration `=iteration_idx'"
	qui frame iteration_results: replace iteration_number = `=iteration_idx' in `=iteration_idx'

*** Define exp(psi_j^L - beta^L d_ij)
	qui replace exp_high = exp(DFE_current_high + beta_slope_current_high * log_dur)
	qui replace exp_low  = exp(DFE_current_low  + beta_slope_current_low  * log_dur)

	qui gegen double mu_high = sum(exp_high), by(origin)
	qui gegen double mu_low  = sum(exp_low) , by(origin)

	qui replace mu_high_other = mu_high - exp_high
	qui replace mu_low_other  = mu_low  - exp_low

	*** For distance slope score
	qui gegen double mu_dist_high = sum(exp_high * log_dur), by(origin)
	qui gegen double mu_dist_low  = sum(exp_low  * log_dur), by(origin)

	*** lambda term
	qui replace lambda_ij = `pop_res_high' * exp_high / (exp_high + mu_high_other) + ///
					     	`pop_res_low'  * exp_low  / (exp_low   + mu_low_other)

	*** log likelihood
	qui replace loglikelihood = - lambda_ij + `yi_outcome' * log(lambda_ij)

	// sum `yi_outcome', d
	qui sum loglikelihood
	scalar s_total_ll  = r(sum)
	local total_ll: di %20.2f `=s_total_ll'
	qui frame iteration_results: replace current_ll = s_total_ll in `=iteration_idx'

	qui replace indirect_ik_low = `pop_res_low' * exp_low / mu_low^2 * (`yi_outcome'/lambda_ij - 1)
	qui gegen double indirect_ik_sum_orig_low = sum(indirect_ik_low), by(origin)
	qui replace indirect_ik_sum_orig_less_low = indirect_ik_sum_orig_low - indirect_ik_low

	qui replace indirect_ij_low = - exp_low * (indirect_ik_sum_orig_less_low)
	qui gegen double indirect_score_low = sum(indirect_ij_low), by(destination)


	qui replace indirect_ik_high = `pop_res_high' * exp_high / mu_high^2 * (`yi_outcome'/lambda_ij - 1)
	qui gegen double indirect_ik_sum_orig_high = sum(indirect_ik_high), by(origin)
	qui replace indirect_ik_sum_orig_less_high = indirect_ik_sum_orig_high - indirect_ik_high

	qui replace indirect_ij_high = - exp_high * (indirect_ik_sum_orig_less_high)
	qui gegen double indirect_score_high = sum(indirect_ij_high), by(destination)

	qui gegen double direct_score_low  = sum(indirect_ik_low  * mu_low_other), by(destination)
	qui gegen double direct_score_high = sum(indirect_ik_high * mu_high_other), by(destination)

	qui replace score_low  = indirect_score_low  + direct_score_low
	qui replace score_high = indirect_score_high + direct_score_high

	cap drop indirect_ik_sum_orig_low indirect_ik_sum_orig_high
	cap drop indirect_score_*
	cap drop direct_score_*

	*** Imposing constraint \sum psi_j^L = 0. <<<<< Is this the correct way????????????????????????????????????????
		qui sum score_low if d1==1
		qui replace score_low = score_low - r(mean)
		qui sum score_high if d1==1
		qui replace score_high = score_high - r(mean)


	*** Distance coefficient slope 
		qui replace score_beta_low  = indirect_ik_low  * (log_dur * mu_low  - mu_dist_low)
		qui replace score_beta_high = indirect_ik_high * (log_dur * mu_high - mu_dist_high)

		qui sum score_beta_low
		scalar scalar_score_beta_low = r(sum) * beta_score_param // artificially lower the score for beta
		qui sum score_beta_high
		scalar scalar_score_beta_high = r(sum) * beta_score_param // artificially lower the score for beta

	drop mu_high
	drop mu_low
	drop mu_dist_high
	drop mu_dist_low

	*******************
	*** Update rule ***
	*******************

	*** Gradient ascent
		// faster than doing all observations
		qui replace temp_score_norm_2 = (score_low^2 + score_high^2)/2 if d1==1 

		** With 2 distance slopes as well 
			qui count if d1==1
			scalar N_DFE = r(N)

			qui sum temp_score_norm_2 if d1==1
			scalar temp_score_norm_2_inverse = ((r(sum) * 2 + scalar_score_beta_low^2 + scalar_score_beta_high^2) / (2 * N_DFE + 2))^(-0.5)

		qui replace score_low = min(0.5,max(-0.5, score_low * temp_score_norm_2_inverse))
		if (debug_level > 1){
			sum score_low if d1==1, d
		}

		qui replace score_high = min(0.5,max(-0.5, score_high * temp_score_norm_2_inverse))
		if (debug_level > 1){
			sum score_high if d1==1, d
		}

	*** Backtracking line search: try (dfe_step_gradient) but if it doesn't work, recursively try a smaller step
		scalar found_step_higher_ll = 0
		scalar initial_step_ok = 1
		*** Initialize step size
		* We use 2 x previous step size, in order to save time as we get closer to the optimum, 
		* while also allowing the algorithm to increase the step size 
		// scalar dfe_step_gradient_TEMP = min(dfe_step_gradient, 2 * dfe_step_gradient_TEMP)
		scalar dfe_step_gradient_TEMP = (1.5 + 0.5 * runiform()) * dfe_step_gradient_TEMP

		while (found_step_higher_ll == 0){

			di "...trying step size `=dfe_step_gradient_TEMP'" _c

			qui replace DFE_current_TEMP_low  = DFE_current_low  + score_low  * dfe_step_gradient_TEMP
			qui replace DFE_current_TEMP_high = DFE_current_high + score_high * dfe_step_gradient_TEMP

			scalar beta_slope_temp_low  = beta_slope_current_low  + scalar_score_beta_low  * temp_score_norm_2_inverse * dfe_step_gradient_TEMP
			scalar beta_slope_temp_high = beta_slope_current_high + scalar_score_beta_high * temp_score_norm_2_inverse * dfe_step_gradient_TEMP

			*** Define exp(psi_j^L - beta^L d_ij)
			qui replace exp_high = exp(DFE_current_TEMP_high + beta_slope_temp_high * log_dur)
			qui replace exp_low  = exp(DFE_current_TEMP_low  + beta_slope_temp_low  * log_dur)

			// cap drop mu_high
			// cap drop mu_low
			qui gegen double mu_high = sum(exp_high), by(origin)
			qui gegen double mu_low  = sum(exp_low) , by(origin)

			qui replace mu_high_other = mu_high - exp_high
			qui replace mu_low_other  = mu_low  - exp_low

			*** For distance slope score
			// cap drop mu_dist_high
			// cap drop mu_dist_low
			qui gegen double mu_dist_high = sum(exp_high * log_dur), by(origin)
			qui gegen double mu_dist_low  = sum(exp_low  * log_dur), by(origin)

			*** lambda term
			qui replace lambda_ij = `pop_res_high' * exp_high / (exp_high + mu_high_other) + ///
							     	`pop_res_low'  * exp_low  / (exp_low   + mu_low_other)

			*** log likelihood
			qui replace loglikelihood = - lambda_ij + `yi_outcome' * log(lambda_ij)
			qui sum loglikelihood
			scalar s_total_ll_temp = r(sum)

			if (s_total_ll_temp > s_total_ll){
				scalar found_step_higher_ll = 1
				di "...WORKS!"
			}
			else{
				scalar dfe_step_gradient_TEMP = dfe_step_gradient_TEMP * 0.5	
				scalar initial_step_ok = 0
				di "......does not work"
			}

			drop mu_high
			drop mu_low
			drop mu_dist_high
			drop mu_dist_low
		}

	*** Step size to use. 
	* 	If at the original step size the likelihood was higher, use it.
	*	If we had to shrink it to get at a point where the log likelihoods is higher,
	*		then use a smaller step 
		if (initial_step_ok == 1){
			scalar dfe_step_gradient_touse = dfe_step_gradient_TEMP
		}
		else{
			scalar dfe_step_gradient_touse = dfe_step_gradient_TEMP * 0.6
		}
		

	*** Update dest FEs and distance coefficients
		qui replace DFE_current_low  = DFE_current_low  + score_low  * dfe_step_gradient_touse
		qui replace DFE_current_high = DFE_current_high + score_high * dfe_step_gradient_touse

		if (debug_level > 0){
			di "Change in low  beta slope: `=scalar_score_beta_low  * temp_score_norm_2_inverse * dfe_step_gradient_TEMP'. (Old value: `=beta_slope_current_low')"
			di "Change in high beta slope: `=scalar_score_beta_high * temp_score_norm_2_inverse * dfe_step_gradient_TEMP'. (Old value: `=beta_slope_current_high')"
		}
		scalar beta_slope_current_low  = beta_slope_current_low  + scalar_score_beta_low  * temp_score_norm_2_inverse * dfe_step_gradient_touse
		scalar beta_slope_current_high = beta_slope_current_high + scalar_score_beta_high * temp_score_norm_2_inverse * dfe_step_gradient_touse

		qui frame iteration_results: replace beta_slope_low   = `=beta_slope_current_low' in `=iteration_idx'
		qui frame iteration_results: replace beta_slope_high  = `=beta_slope_current_high' in `=iteration_idx'


	scalar iteration_idx = iteration_idx + 1

	* Periodically draw log likelihood graph
	if mod(iteration_idx, 10) == 0{

		*** average log-likelihood over past 10 runs
		qui frame iteration_results: sum current_ll if (iteration_number > `=iteration_idx-10') & iteration_number < `=iteration_idx'
		local total_ll_past10 = r(mean)

		scalar change_in_ll = s_total_ll - `total_ll_past10'
		di "Change in LL: `=change_in_ll'"

		frame iteration_results: line current_ll iteration_number if (iteration_number > `=iteration_idx-100')
	}

	*** check convergence
	*** average log-likelihood over past 10 runs
		qui frame iteration_results: sum current_ll if (iteration_number > `=iteration_idx-10') & iteration_number < `=iteration_idx'
		local total_ll_past10 = r(mean)

	qui frame iteration_results: replace current_ll_change10 = s_total_ll - `total_ll_past10' in `=iteration_idx'

	di "Increase in log-likelihood (single ): `=abs(s_total_ll - `total_ll_old')'"
	di "Increase in log-likelihood (10 runs): `=abs(s_total_ll - `total_ll_past10')'"
	if (abs(s_total_ll - `total_ll_past10') < tolerance_ll & iteration_idx > 2) {
		scalar converged = 1
	}

	local total_ll_old = s_total_ll
}

*** Save beta coefficients
	gen _beta_slope_low  = beta_slope_current_low
	gen _beta_slope_high = beta_slope_current_high

*** Clean up
	drop exp_high-loglikelihood

end
