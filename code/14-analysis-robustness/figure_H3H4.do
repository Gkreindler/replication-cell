* This do file: Figures H3 and H4 show model predictive power as a function of radius to the city center

clear all

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

scalar epsilon_scalar = 8.3

*** Bangladesh load km2 area
	use "data_raw_bgd/other/towers_bgd", clear
	keep tower area_km2
	tempfile area_km2
	save 	`area_km2'

	rename tower destination
	rename area_km2 km2_tower_d
	tempfile area_km2_d
	save 	`area_km2_d'

*** Load gravity results
	import delimited using "data_coded/dfe_bgd_home_work.csv", clear
	sum _beta_log_dur
	scalar _beta_slope_scalar = r(mean)

	keep destination dfe
	tempfile dfes
	save 	`dfes'

*** Load 
	use "data_coded_bgd/flows/home_work_odmatrix_gravity.dta", clear

	merge m:1 destination using `dfes'
	assert _m!=2
	drop _m

	merge m:1 destination using `area_km2_d'
	drop if _m==2
	assert _m!=1
	drop _m

	*** Construct income measures at the destination level
	gen destfe_adj = dfe - log(km2_tower_d)

	gegen volume_destination = sum(volume), by(destination)

*** residential income
	gen temp = exp(destfe_adj / epsilon_scalar)
	gcollapse (mean) res_meanincome_adj=temp (rawsum) volume_origin=volume [aw=volume], by(origin)

	replace res_meanincome_adj = log(res_meanincome_adj)
  	rename origin tower
  

*** Extra coding
	merge 1:1 tower using `area_km2'
	assert _m!=1
	drop if _m==2
	drop _m

	merge 1:1 tower using "data_coded_bgd/other/dist2cbd.dta"
	assert _m!=1 
	drop if _m==2
	drop _m	

*** census outcome variable
	merge 1:1 tower using "data_coded_bgd/census/censuspop_tower_allvars", keepusing(tot_pop_isx pca_thana_tower_avg)
	drop if _m==2
	drop _m

	* distance in KM
	replace distCBD = distCBD / 1000

	sum tot_pop_isx
	di %20.0fc r(sum)

*** Store results for final graph
	gen double km = .
	gen double r2 = .
	gen pop_at_km = .
	gen km2_at_km = .


*** 
	sum distCBD, d
	local dist_max = ceil(r(max))

	local i = 1
	forv km=5/`dist_max'{
		qui reg pca_thana_tower_avg res_meanincome_adj if distCBD < `km' [aw=volume_origin], r		
		
		replace km = `km' 		in `i'
		replace r2 = e(r2_a) 	in `i'

		sum tot_pop_isx if inrange(distCBD, `=`km'-3', `=`km'+3')
		replace pop_at_km = r(sum) in `i'

		sum area_km2 if inrange(distCBD, `=`km'-3', `=`km'+3')
		replace km2_at_km = r(sum) in `i'


		local i= `i' + 1
	}

	gen pop_per_km2_at_km = pop_at_km / km2_at_km

	keep pop_per_km2_at_km r2 km
	gen sample = "bgd"

	tempfile bgd_graph
	save 	`bgd_graph'

*****************
*** Sri Lanka ***
*****************

*** Tower area
	use "data_raw_slk/other/towers_slk", clear
	keep tower area_km2
	tempfile area_km2
	save 	`area_km2'

	rename tower destination
	rename area_km2 km2_tower_d
	tempfile area_km2_d
	save 	`area_km2_d'

*** Load gravity results
	import delimited using "data_coded/dfe_slk_home_work.csv", clear
	sum _beta_log_dur
	scalar _beta_slope_scalar = r(mean)

	keep destination dfe
	tempfile dfes
	save 	`dfes'

*** Load 
	use "data_coded_slk/flows/home_work_odmatrix_gravity.dta", clear

	merge m:1 destination using `dfes'
	assert _m==3
	drop _m

	merge m:1 destination using `area_km2_d'
	drop if _m==2
	assert _m!=1
	drop _m

	*** Construct income measures at the destination level
	gen destfe_adj = dfe - log(km2_tower_d)

	gegen volume_destination = sum(volume), by(destination)

*** residential income
	gen temp = exp(destfe_adj / epsilon_scalar)
	gcollapse (mean) res_meanincome_adj=temp (rawsum) volume_origin=volume [aw=volume], by(origin)

	replace res_meanincome_adj = log(res_meanincome_adj)
  	rename origin tower

*** Tower area
	merge 1:1 tower using `area_km2'
	assert _m!=1
	drop if _m==2
	drop _m

*** distance to CBD
  	merge 1:1 tower using "data_coded_slk/other/dist2cbd.dta"
	assert _m!=1 
	drop if _m==2
	drop _m	

*** census outcome censuspop_tower_allvars
	merge 1:1 tower using "data_coded_slk/census/censuspop_tower_allvars", keepusing(population pca1)
	drop if _m==2
	drop _m

	* distance in KM
	replace distCBD = distCBD / 1000

	* population density 
	gen pop_per_km2 = population / area_km2


*** Store results for final graphs
	gen double km = .
	gen double r2 = .
	gen pop_at_km = .
	gen km2_at_km = .


*** 
	sum distCBD, d
	local dist_max = ceil(r(max))

	local i = 1
	forv km=5/`dist_max'{
		qui reg pca1 res_meanincome_adj if distCBD < `km' [aw=volume_origin], r		
		
		replace km = `km' 		in `i'
		replace r2 = e(r2_a) 	in `i'

		sum population if inrange(distCBD, `=`km'-3', `=`km'+3')
		replace pop_at_km = r(sum) in `i'

		sum area_km2 if inrange(distCBD, `=`km'-3', `=`km'+3')
		replace km2_at_km = r(sum) in `i'


		local i= `i' + 1
	}

	gen pop_per_km2_at_km = pop_at_km / km2_at_km

*** Combined graphs
	keep pop_per_km2_at_km r2 km
	gen sample = "slk"

	append using `bgd_graph'

	gen log_pop_density = log(pop_per_km2_at_km)

*** Figure H3
	twoway  (lpoly pop_per_km2_at_km km if sample == "slk", yaxis(2) lcolor(gs10) lwidth(0.5) lpattern(dash)) ///
			(line r2 				 km if sample == "slk", lcolor(blue) lwidth(0.5)) ///
			(lpoly pop_per_km2_at_km km if sample == "bgd", yaxis(2) lcolor(gs10) lwidth(0.5) lpattern(dash)) ///
			(line r2 				 km if sample == "bgd", lcolor(red) lwidth(0.5)) ///
			, ylabel(0(0.2)0.8, angle(zero) /* labcolor(blue) */) yscale(log axis(2)) ///
			 ylabel(100 "100" 1000 "1k" 10000 "10k" 50000 "50k", axis(2) angle(zero)) ///
			ytitle("Adj" " " "R{sup:2}", orientation(horizontal) /* color(blue) */) ///
			ytitle("Pop" "density" "(/km2)" "(log" "scale)", orientation(horizontal) axis(2)) ///
			xtitle("Cutoff: distance from CBD (km)") ///
			graphregion(color(white)) legend(off) ///
			text(30000 60 "SLK R{sup:2}", yaxis(2) color(blue)) ///
			text( 8000 60 "BGD R{sup:2}", yaxis(2) color(red)) ///
			text(  200 50 "SLK pop density", yaxis(2) color(gs10)) ///
			text( 1400 65 "BGD pop density", yaxis(2) color(gs10)) scale(1.1)

	graph set window fontface "Helvetica"	// Set graph font
	graph set eps fontface "Helvetica"
	graph display, ysize(3) xsize(4.5)

	graph export "figures/figure_H3H4/figure_H3_r2_dist_both.png", replace
	graph export "figures/figure_H3H4/figure_H3_r2_dist_both.pdf", replace

*** Figure H4
	twoway 	(scatter r2 log_pop_density if sample == "slk", mcolor(blue)) ///
			(scatter r2 log_pop_density if sample == "bgd", mcolor(red) msymbol(square)) ///
			, xlabel(`=log(100)' "100" `=log(1000)' "1000" `=log(10000)' "10000" `=log(50000)' "50000") ///
			xtitle("Population density (/km2) (log scale)") ///
			ylabel(, angle(zero)) ///
			ytitle(" Adj" " " "R{sup:2}", orientation(horizontal)) ///
			graphregion(color(white)) legend(order(1 "Colombo (SLK)" 2 "Dhaka (BGD)") ring(0) position(7))  scale(1.1)

	graph set window fontface "Helvetica"	// Set graph font
	graph set eps fontface "Helvetica"
	graph display, ysize(3) xsize(3)

	graph export "figures/figure_H3H4/figure_H4_r2_popden_both.png", replace
	graph export "figures/figure_H3H4/figure_H4_r2_popden_both.pdf", replace
