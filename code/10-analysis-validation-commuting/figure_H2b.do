* This do file: Figure H2 panel B

clear all
set more off
pause on

*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"
	adopath ++ "${cellphone_root}ado/"

***********
*** BGD ***
***********

*** Load home-work commuting matrix
	use "data_coded_bgd/flows/home_work_odmatrix.dta", clear
	keep if dhaka == 1
	keep if workday == 1

	rename volume volume_hw
	keep origin destination volume_hw
	tempfile hw
	save 	`hw'

*** Load daily commuting matrix
	use "data_coded_bgd/flows/daily_trips_odmatrix.dta", clear
	keep if dhaka == 1
	keep if workday == 1
	keep origin destination duration_intp volume

	merge 1:1 origin destination using `hw'
	assert _m==3
	drop _m

	gen ldur = log(max(150,duration_intp))
	recode volume_hw (.=0)
	assert volume !=.

* duration bins
	sum ldur, d
	local binw = (r(p99) - r(p1))/100
	egen ldur_cat = cut(ldur), at(`r(min)'(`binw')`r(p99)')
	bys ldur_cat: gen o1 = _n==1

* duration sample
	sum ldur, d
	gen sample_dur = inrange(ldur, r(min), r(p99)) 

* residual volumes
	gen log_volume = log(volume)
	reg log_volume
	predict log_volume_r, residual

	gen log_volume_hw = log(volume_hw)
	reg log_volume_hw
	predict log_volume_hw_r, residual

* mean volume by duration bin
	bys ldur_cat: egen log_mean_volume    = mean(volume)
	replace log_mean_volume = log(log_mean_volume)
	bys ldur_cat: egen log_mean_volume_hw = mean(volume_hw)
	replace log_mean_volume_hw = log(log_mean_volume_hw)

* travel time in minutes
	replace ldur_cat = ldur_cat - log(60)

	gen double durcat = exp(ldur_cat)
	
* number of towers
	gunique origin
	local ntowers: di %5.0fc r(J)
	di "`ntowers'"

* Graph
	local bw = 0.2
	twoway 	(lpoly log_mean_volume 		ldur_cat 	if o1==1, bw(`bw') lcolor(blue) lwidth(medthick)) ///
			(lpoly log_mean_volume_hw 	ldur_cat	if o1==1, bw(`bw') lcolor(black) lwidth(medthick) lpattern(dash)) ///
			, legend(order(1 "Daily Commuting, log(mean()) " 2 "Home Work, log(mean())" ) cols(2)) ///
			xlabel(`=log(5)' "5" `=log(10)' "10" `=log(30)' "30" `=log(60)' "60" `=log(90)' "90" ) ///
			graphregion(color(white)) ///
			xtitle("Travel Time (Minutes, log scale)") ///
			ytitle("Log commuting flow") title("Dhaka") subtitle("`ntowers' cell phone towers")

	graph save   "figures/figure_H2/figure_bgd_comm_hw.gph", replace
	graph export "figures/figure_H2/figure_bgd_comm_hw.eps", replace
	graph export "figures/figure_H2/figure_bgd_comm_hw.pdf", replace	

***********
*** SLK ***
***********

*** Western Province only
	use "data_raw_slk/other/towers_slk.dta", clear
	keep if province == "Western"
	keep tower
	gisid tower

	rename tower origin
	tempfile towers_o
	save 	`towers_o'

	rename origin destination
	tempfile towers_d
	save 	`towers_d'	


*** Load home-work commuting matrix
	use "data_coded_slk/flows/home_work_odmatrix.dta", clear
	keep if workday == 1

	merge m:1 origin using `towers_o'
	keep if _m==3
	drop _m

	merge m:1 destination using `towers_d'
	keep if _m==3
	drop _m

	rename volume volume_hw
	keep origin destination volume_hw

	tempfile hw
	save 	`hw'

*** Load daily commuting matrix
	use "data_coded_slk/flows/daily_trips_odmatrix.dta", clear
	keep if workday == 1
		
	cap drop _m

	merge m:1 origin using `towers_o'
	keep if _m==3
	drop _m

	merge m:1 destination using `towers_d'
	keep if _m==3
	drop _m

	keep origin destination duration_intp volume

	merge 1:1 origin destination using `hw'
	assert _m==3
	drop _m

* distance
	drop if duration_intp == .
	gen ldur = log(max(150,duration_intp))
	recode volume_hw (.=0)
	assert volume !=.

* duration bins
	sum ldur, d
	local binw = (r(p99) - r(p1))/100
	egen ldur_cat = cut(ldur), at(`r(min)'(`binw')`r(p99)')
	bys ldur_cat: gen o1 = _n==1

* duration sample
	sum ldur, d
	gen sample_dur = inrange(ldur, r(min), r(p99)) 

* residual volumes
	gen log_volume = log(volume)
	reg log_volume
	predict log_volume_r, residual

	gen log_volume_hw = log(volume_hw)
	reg log_volume_hw
	predict log_volume_hw_r, residual

* mean volume by duration bin
	bys ldur_cat: egen log_mean_volume    = mean(volume)
	replace log_mean_volume = log(log_mean_volume)
	bys ldur_cat: egen log_mean_volume_hw = mean(volume_hw)
	replace log_mean_volume_hw = log(log_mean_volume_hw)
	
* travel time in minutes
	replace ldur_cat = ldur_cat - log(60)

* number of towers
	gunique origin
	local ntowers: di %5.0fc r(J)
	di "`ntowers'"

* Graph
	local bw = 0.2
	twoway 	(lpoly log_mean_volume 		ldur_cat if o1==1, bw(`bw') lcolor(blue)  lwidth(medthick)) ///
			(lpoly log_mean_volume_hw 	ldur_cat if o1==1, bw(`bw') lcolor(black) lwidth(medthick) lpattern(dash)) ///
			, legend(order(1 "Daily Commuting, log(mean()) " 2 "Home Work, log(mean())") cols(2)) ///
			xlabel(`=log(5)' "5" `=log(10)' "10" `=log(30)' "30" `=log(60)' "60" `=log(90)' "90" ) ///
			graphregion(color(white)) xtitle("Travel Time (Minutes, log scale)") ytitle(" ") ///
			ylabel(, labcolor(white)) /* ytick(-2(2)8) */ title("Colombo") ///
			subtitle("`ntowers' cell phone towers")
	
	
	graph save   "figures/figure_H2/figure_slk_comm_hw.gph", replace
	graph export "figures/figure_H2/figure_slk_comm_hw.eps", replace
	graph export "figures/figure_H2/figure_slk_comm_hw.pdf", replace	


* Combine?
	cd "figures/figure_H2/"
	graph set window fontface "Helvetica"	// Set graph font
	graph set eps fontface "Helvetica"
	
	// graph combine
	grc1leg  "figure_bgd_comm_hw.gph" "figure_slk_comm_hw.gph", col(2) scheme(s1color) imargin(zero) iscale(1) ycommon xcommon

	graph display, ysize(3) xsize(5)
	graph save   "figure_both_comm_hw", replace
	graph export "figure_both_comm_hw.eps", replace
	graph export "figure_both_comm_hw.pdf", replace

