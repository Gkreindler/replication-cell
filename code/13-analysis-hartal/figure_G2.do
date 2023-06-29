* this do file: Draw commute income by calendar date

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
 	
// */

*** Make graphs
	*** load data 
	use "data_coded_bgd/hartal/hartal_date_fes", clear

	* dates
	gen friday   = dow(date_numeric) == 5
	gen saturday = dow(date_numeric) == 6
	gen weekend = friday == 1 | saturday == 1
	count if weekend == 1 & hartal_igc == 1

	// gen byte workday  = date_type_igc == 0
	// gen byte friday 	 = date_type_igc == 1
	// gen byte saturday = date_type_igc == 2
	gen byte holiday = date_type_igc == 3
	// gen byte hartal   = date_type_igc == 4

	recode holiday hartal_igc friday saturday weekend (0=.)

	replace hartal_igc = hartal_igc * 10
	replace weekend = weekend * 10
	replace holiday = holiday * 10

	replace DATE_FE_TW_C = 100 * DATE_FE_TW_C

	gen day = mod(date_numeric, 100)
	gen month = (date_numeric - day) / 100
	gen date = mdy(month, day, 2013)
	format %tdddMon date

	gen m12 = inlist(month,8,9)

*** event study graph

*** November - December graph
	local ms=0
	twoway 	(bar holiday     date if m12==`ms', base(-60) fcolor(green%10) lwidth(none) lcolor(black%0)) ///
			(bar hartal_igc  date if m12==`ms', base(-60) fcolor(blue%20) lwidth(none) lcolor(black%0)) ///
			(bar weekend 	 date if m12==`ms', base(-60) fcolor(black%7) lwidth(none) lcolor(black%0)) ///
			(scatter DATE_FE_TW_C date if m12==`ms' & weekend == 10, msymbol(D) mcolor(black%30) mlwidth(none) msize(medium)) ///
			(scatter DATE_FE_TW_C date if m12==`ms' & inlist(date_type_igc,3)  , msymbol(D) mcolor(green%30) mlwidth(none) msize(medium)) ///
			(scatter DATE_FE_TW_C date if m12==`ms' & inlist(date_type_igc,0)  , 			 mcolor(black) 	 mlwidth(none) msize(medium)) ///
			(scatter DATE_FE_TW_C date if m12==`ms' & hartal_igc == 10  , msymbol(T) mcolor(blue) 	 	 mlwidth(none) msize(medium)) ///
			, graphregion(color(white)) xtitle("") xlabel(`=mdy(11,1,2013)'(7)`=mdy(12,30,2013)') ///
			ytitle("Percent change relative to work days") ylabel(-60(10)10) /// yline(0, lcolor(gs14))
			legend(order(- 6 "Weekdays" 2 "" 7 "Hartal" 1 "" 5 "Public Holiday" 3 "" 4 "Friday, Saturday") cols(4) colgap(*0.2)) ///
			xline(`=mdy(8,13,2013)-0.5' `=mdy(9,18,2013)-0.5' `=mdy(11,4,2013)-0.5' `=mdy(11,10,2013)-0.5' `=mdy(11,27,2013)-0.5' `=mdy(12,15,2013)-0.5')

	graph display, ysize(3) xsize(4)

	graph export   "figures/figure_G2/figure_G2_hartal_dates_TW_novdec.pdf", replace
	graph export   "figures/figure_G2/figure_G2_hartal_dates_TW_novdec.png", replace

*** August - September graph
	local ms=1
	twoway 	(bar holiday     date if m12==`ms', base(-80) fcolor(green%10) lwidth(0) lcolor(black%0)) ///
			(bar hartal_igc  date if m12==`ms', base(-80) fcolor(blue%20) lwidth(0) lcolor(black%0)) ///
			(bar weekend 	 date if m12==`ms', base(-80) fcolor(black%7) lwidth(0) lcolor(black%0)) ///
			(scatter DATE_FE_TW_C date if m12==`ms' & inlist(date_type_igc,1,2), msymbol(D) mcolor(black%30) mlwidth(none) msize(medium)) ///
			(scatter DATE_FE_TW_C date if m12==`ms' & inlist(date_type_igc,3)  , msymbol(D) mcolor(green%30) mlwidth(none) msize(medium)) ///
			(scatter DATE_FE_TW_C date if m12==`ms' & inlist(date_type_igc,0)  , 			 mcolor(black) 	 mlwidth(none) msize(medium)) ///
			(scatter DATE_FE_TW_C date if m12==`ms' & inlist(date_type_igc,4)  , msymbol(T) mcolor(blue) 	 	 mlwidth(none) msize(medium)) ///
			, graphregion(color(white)) xtitle("") xlabel(`=mdy(8,2,2013)'(7)`=mdy(9,28,2013)') ///
			ytitle("Percent change relative to work days") ylabel(-80(10)10) ///
			legend(off) ///
			xline(`=mdy(8,13,2013)-0.5' `=mdy(9,18,2013)-0.5' `=mdy(11,4,2013)-0.5' `=mdy(11,10,2013)-0.5' `=mdy(11,27,2013)-0.5' `=mdy(12,15,2013)-0.5')

	graph display, ysize(2.5) xsize(4)

	graph export   "figures/figure_G2/figure_G2_hartal_dates_TW_augsep.pdf", replace
	graph export   "figures/figure_G2/figure_G2_hartal_dates_TW_augsep.png", replace

