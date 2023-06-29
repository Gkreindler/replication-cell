* this do file: creates dataset with hartal and holidays dates

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** get hartal days from IGC dataset
	import excel using "data_raw_bgd/other/Hartal Data IGC.xlsx", clear firstrow case(lower) sheet("Data")
	keep if year==2013 & inlist(month, 8, 9, 11, 12)
	
	gen date = mdy(month, day, year)
	gen hartal_igc = 1

	tempfile hartal_igc
	save 	`hartal_igc'

*** get hartal days
	import delimited using "data_raw_bgd/other/hartal_list.csv", clear varnames(1)
	gen date_ = date(date,"YMD")
	format %td date_
	drop date
	rename date_ date

	gen hartal = 1

	merge 1:1 date using `hartal_igc'
	drop _m

	recode hartal hartal_igc (.=0)

	tab hartal_igc hartal, m

	keep date hartal hartal_igc
	keep if hartal == 1 | hartal_igc == 1

	tempfile dates_hartal
	save 	`dates_hartal'

*** get holidays
	import delimited using "data_raw_bgd/other/holiday_list_revised.csv", varnames(1) clear
	gen date_ = date(date,"YMD")
	format %td date_
	drop date
	rename date_ date

	keep if type == "Public Holiday"
	// gen holiday_opt = type == "Optional Holiday"
	// gen holiday_hin = type == "Hindu Holiday"

	keep date

	gen holiday = 1

	tempfile dates_holiday
	save 	`dates_holiday'

	merge 1:1 date using `dates_hartal'
	drop _m

* fill in gaps (non-hartal non-holiday days)
	set obs `=_N+1'
	replace date = mdy(8,1,2013) in `=_N'
	set obs `=_N+1'
	replace date = mdy(12,31,2013) in `=_N'

	tsset date
	tsfill 
	tsset, clear
	drop if month(date) == 10 // drop October

	recode holiday hartal hartal_igc (.=0)

	gen dow = dow(date)
	gen friday = dow == 5
	gen saturday = dow == 6

**** one categorical date type variable
	/* 
	In case of overlap, the decreasing order of priority is:
	1) Holiday
	2) Hartal
	3) Friday/Saturday 
	
	*/

	assert friday   == 0 if hartal == 1
	// assert saturday == 0 if hartal == 1

	gen 	date_type = 0 if friday   == 0 				   & holiday == 0 & hartal == 0
	replace date_type = 1 if friday   == 1 				   & holiday == 0
	replace date_type = 2 if 				 saturday == 1 & holiday == 0
	replace date_type = 3 if                                 holiday == 1
	replace date_type = 4 if friday   == 0 & saturday == 0 & holiday == 0 & hartal == 1
	assert inlist(date_type,0,1,2,3,4,5)
	label define date_type 0 "none" 1 "friday" 2 "saturday" 3 "holiday" 4 "hartal"
	label values date_type date_type

*** Redo for IGC definition of Hartal

	* no holiday which is also hartal
	assert hartal_igc == 0 if holiday == 1

	* two fridays which are also hartal -- code as hartal
	count if friday == 1 & hartal_igc == 1
	assert r(N) == 2

	* three saturdays which are also hartal -- code as hartals
	count if saturday == 1 & hartal_igc == 1
	assert r(N) == 3

	gen 	date_type_igc = 0 if friday   == 0 				   & holiday == 0 & hartal_igc == 0
	replace date_type_igc = 1 if friday   == 1 				   & holiday == 0 & hartal_igc == 0
	replace date_type_igc = 2 if 				 saturday == 1 & holiday == 0 & hartal_igc == 0
	replace date_type_igc = 3 if                                 holiday == 1
	replace date_type_igc = 4 if 												hartal_igc == 1
	assert inlist(date_type_igc,0,1,2,3,4,5)
	label values date_type date_type_igc

* generate numeric date (used for merging)
	gen date_numeric = month(date) * 100 + day(date)

	keep date date_numeric dow holiday hartal hartal_igc friday date_type date_type_igc
	compress 
	save "data_coded_bgd/other/dates_igc.dta", replace
