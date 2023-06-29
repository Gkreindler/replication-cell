* This do file:
clear all
set more off
pause on

*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"
	adopath ++ "${cellphone_root}ado/"

*** Load data
	use "data_coded_bgd/dhuts/merged_comparison.dta", clear

****************
*** GRAPH ***
****************
	local bw = 0.2
	local niter = 500

	* we are using Home-Work flows
	rename flow flow_hw
	lpoly_cluster_ci_cat flow_hw		mean_log_dur_cat  	if mean_log_dur_sample==1, cluster(origin_czone) catvar(mean_log_dur_cat) niter(`niter') bw(`bw')
	lpoly_cluster_ci_cat flow_dhuts 	mean_log_dur_cat  	if mean_log_dur_sample==1, cluster(origin_czone) catvar(mean_log_dur_cat) niter(`niter') bw(`bw')
	
	* travel time in minutes
	replace mean_log_dur_cat = mean_log_dur_cat - log(60)

* compare decay with distance of h-w cell phone flows and DHUTS (all)
	local bw = 0.2
	twoway 	(line logmean_flow_dhuts_r_p025 		mean_log_dur_cat  	if mean_log_dur_sample==1, lcolor(gs12)) ///
			(line logmean_flow_dhuts_r_p975 		mean_log_dur_cat  	if mean_log_dur_sample==1, lcolor(gs12)) ///
			(line logmean_flow_dhuts_r_median 		mean_log_dur_cat 	if mean_log_dur_sample==1, lcolor(red) lwidth(medthick) lpattern(dash) ) ///
			(line logmean_flow_hw_r_p025 			mean_log_dur_cat  	if mean_log_dur_sample==1, lcolor(gs12)) ///
			(line logmean_flow_hw_r_p975 			mean_log_dur_cat  	if mean_log_dur_sample==1, lcolor(gs12)) ///
			(line logmean_flow_hw_r_median 			mean_log_dur_cat  	if mean_log_dur_sample==1, lcolor(blue) lwidth(medthick)) ///
			, legend(order(6 "Cell data, log(mean())" 3 "Survey data, log(mean())" ///
						   2 "Bootstrapped CI"  ) rows(3)) ///
			xlabel(`=log(5)' "5" `=log(10)' "10" `=log(30)' "30" `=log(60)' "60") ///
			graphregion(color(white)) xtitle("Travel Time (Minutes, log scale)") ytitle("log Commuting Flow") title("Dhaka") subtitle("90 survey wards")

	graph set window fontface "Helvetica"	// Set graph font
	graph set eps fontface "Helvetica"
	graph display, ysize(3) xsize(2.5)

	graph save   "figures/figure_H2/figure_dhuts_comp_full_appendix.gph", replace
	graph export "figures/figure_H2/figure_dhuts_comp_full_appendix.eps", replace
	graph export "figures/figure_H2/figure_dhuts_comp_full_appendix.pdf", replace	
