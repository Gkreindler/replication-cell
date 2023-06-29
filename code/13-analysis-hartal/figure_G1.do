* this do file: Create Figure G1. Event study graph of hartal onset events.

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

/* *** Run analysis with date FE
	use "data_coded_bgd/flows/daily_trips_panel_hartal_coded", clear

	* travel anywhere 
	sum is_trip if date_type_igc == 0
	gen is_trip_pp = is_trip / r(mean)

	* travel to work 
	sum dest_is_work if date_type_igc == 0
	gen dest_is_work_pp = dest_is_work / r(mean)

*** Get date fixed effects
	*** using trip to work probability as outcome
	reghdfe dest_is_work_pp, ab(uid DATE_FE_TW=date_numeric)
	gen DATE_FE_TW_C = DATE_FE_TW + _b[_cons] - 1

 	bys date_numeric: gen d1=_n==1
 	keep if d1==1

 	save "data_coded_bgd/hartal/hartal_date_fes", replace
 //	 */
 
**** load data 
	use "data_coded_bgd/hartal/hartal_date_fes", clear

	*** coding dates
	gen day = mod(date_numeric, 100)
	gen month = (date_numeric - day) / 100
	gen date = mdy(month, day, 2013)
	format %tdddMon date

	format %tdddMon date 

	gen friday   = dow(date) == 5
	gen saturday = dow(date) == 6
	gen weekend = friday == 1 | saturday == 1
	gen holiday = date_type_igc == 3
	
	*** Add back Friday and Saturday average differences
	* Friday and saturday effects relative to weekday
	recode friday saturday weekend (.=0)
	recode hartal_igc (.=0)
	replace DATE_FE_TW_C = 100 * DATE_FE_TW_C
	reg DATE_FE_TW_C hartal_igc friday saturday holiday

	gen  	DATE_FE_C_fix = DATE_FE_TW_C 
	replace DATE_FE_C_fix = DATE_FE_TW_C - _b[friday]   if friday == 1   & e(sample) == 1
	replace DATE_FE_C_fix = DATE_FE_TW_C - _b[saturday] if saturday == 1 & e(sample) == 1


	*** SAMPLE: drop holidays
	tsset date
	drop if holiday == 1

	*** SAMPLE: dropping dates that are BOTH hartal and friday/saturday
	drop if hartal_igc == 1 & friday == 1
	drop if hartal_igc == 1 & saturday == 1

	*** Defining leads and lags (up to 5)
	forv i=1/5{
		gen hartal_L`i' = L`i'.hartal_igc
		gen hartal_F`i' = F`i'.hartal_igc

		gen FE_L`i' = L`i'.DATE_FE_C_fix
		gen FE_F`i' = F`i'.DATE_FE_C_fix
	}

	gen FE_F0 = DATE_FE_C_fix

	*** Defining events
	sort date_numeric
	cap drop event_anchor
	gen event_anchor = hartal_igc == 1 & hartal_L1 == 0

	tab event_anchor
	list date_numeric if event_anchor == 1

	keep if event_anchor == 1

	replace FE_L5 = . if hartal_L5 == 1 | hartal_L4 == 1 | hartal_L3 == 1 | hartal_L2 == 1
	replace FE_L4 = . if hartal_L4 == 1 | hartal_L3 == 1 | hartal_L2 == 1
	replace FE_L3 = . if hartal_L3 == 1 | hartal_L2 == 1
	replace FE_L2 = . if hartal_L2 == 1

	replace FE_F5 = . if hartal_F5 == 0 | hartal_F4 == 0 | hartal_F3 == 0 | hartal_F2 == 0 | hartal_F1 == 0
	replace FE_F4 = . if hartal_F4 == 0 | hartal_F3 == 0 | hartal_F2 == 0 | hartal_F1 == 0
	replace FE_F3 = . if hartal_F3 == 0 | hartal_F2 == 0 | hartal_F1 == 0
	replace FE_F2 = . if hartal_F2 == 0 | hartal_F1 == 0
	replace FE_F1 = . if hartal_F1 == 0

	rename hartal_igc hartal_F0
	keep date_numeric FE_* hartal_*

	mdesc FE_L5 FE_L4 FE_L3 FE_L2 FE_L1 FE_F0 FE_F1 FE_F2 FE_F3 FE_F4 FE_F5
	// fsdfd

	greshape long FE_ hartal_ , i(date) j(delta) string

	gen time_delta = 0
	replace time_delta = -5 if delta == "L5"
	replace time_delta = -4 if delta == "L4"
	replace time_delta = -3 if delta == "L3"
	replace time_delta = -2 if delta == "L2"
	replace time_delta = -1 if delta == "L1"
	replace time_delta =  0 if delta == "F0"
	replace time_delta =  1 if delta == "F1"
	replace time_delta =  2 if delta == "F2"
	replace time_delta =  3 if delta == "F3"
	replace time_delta =  4 if delta == "F4"
	replace time_delta =  5 if delta == "F5"

	gen day_l5 = delta == "L5"
	gen day_l4 = delta == "L4"
	gen day_l3 = delta == "L3"
	gen day_l2 = delta == "L2"
	gen day_l1 = delta == "L1"
	gen day_f0 = delta == "F0"
	gen day_f1 = delta == "F1"
	gen day_f2 = delta == "F2"
	gen day_f3 = delta == "F3"
	gen day_f4 = delta == "F4"
	gen day_f5 = delta == "F5"

	replace FE_ = . if date == 813 & delta == "L5"

	replace day_l1 = day_l2
	order day_l1, after(day_l2)

	sort date_numeric time_delta

	* We require at least two days between hartal events, which leads to a sample of six hartal onset events
	tab date_numeric

	assert !inlist(date_numeric,1217,1207,1201)
	gunique date_numeric
	tab date_numeric

	*** Run event study regression
	eststo est_TW: reg FE_ day_l? day_f?, r

	coefplot, vertical omit ///
			 keep(day_l5 day_l4 day_l3 day_l2 day_l1 day_f0 day_f1 day_f2 day_f3 day_f4) ///
			order(day_l5 day_l4 day_l3 day_l2 day_l1 day_f0 day_f1 day_f2 day_f3 day_f4) ///
			mcolor(cranberry) ciop(lcolor(gs12)) graphregion(color(white)) ylabel(, tlcolor(gs15%25)) yline(0, lcolor(gs14%50)) ///
			xlabel(1 "-5" 2 "-4" 3 "-3" 4 "-2" 5 "-1" 6 "start" 7 "+1" 8 "+2" 9 "+3" 10 "+4") ///
			xtitle("Days relative to hartal start date", margin(medium)) ///
			ytitle("% Change" "`varname'", orientation(horizontal))

	graph display, ysize(3) xsize(3)

	graph export   "figures/figure_G1/figure_G1_hartal_event_TW.png", replace
	graph export   "figures/figure_G1/figure_G1_hartal_event_TW.pdf", replace
	graph export   "figures/figure_G1/figure_G1_hartal_event_TW.eps", replace


