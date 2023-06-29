* This do file: Table H1

clear all
set more off
pause on
version 16

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

	scalar number_format="%7.2e"
	

************
*** BGD ****
************

*** BGD unique users overall
	import delimited using "data_raw_bgd/flows-home-work/user_home_office_list", clear
	rename tmax tower
	merge m:1 tower using "data_raw_bgd/other/towers_bgd", keepusing(dhaka)
	assert _m!=1
	drop if _m==2
	keep if dhaka == 1

	gunique userid
	scalar nunique_users_hw_bgd = "`:di `=number_format' r(J)'"
	di "Number of unique users BGD (Home-Work): `=nunique_users_hw_bgd'"

*** BGD home work flows
	use "data_coded_bgd/flows/home_work_odmatrix.dta", clear

	assert workday == 1
	keep if dhaka == 1
	by origin destination: gen od1 = _n==1

	qui sum volume
	scalar nusers_bgd = "`:di `=number_format' r(sum)'"
	di "Number of unique users BGD (Home-Work): `=nusers_bgd'"
	
	qui sum volume if origin != destination
	scalar nusers_bgd_orig_neq_dest = "`:di `=number_format' r(sum)'"
	di "Number of unique users BGD (proper commuting Home-Work): `=nusers_bgd_orig_neq_dest'"

	sum duration_intp if od1==1, d
	gen duration_sample = inrange(duration_intp,180,r(p99))

	qui sum volume if duration_sample == 1
	scalar nusers_bgd_gravity_sample = "`:di `=number_format' r(sum)'"
	di "Number of unique users BGD (gravity sample Home-Work): `=nusers_bgd_gravity_sample'"


*** BGD daily trips
	
	use "data_coded_bgd/flows/daily_trips_odmatrix.dta", clear
    keep if workday == 1	
    keep if dhaka == 1

    by origin destination: gen od1 = _n==1
   
    qui sum volume
	scalar nusers_daily_bgd = "`:di `=number_format' r(sum)'"
	scalar nusers_daily_bgd_plain = r(sum)
	di "Number of unique users BGD (DAILY): `=nusers_daily_bgd'"
	
	qui sum volume if origin != destination
	scalar nusers_daily_bgd_orig_neq_dest = "`:di `=number_format' r(sum)'"
	di "Number of unique users BGD (proper commuting DAILY): `=nusers_daily_bgd_orig_neq_dest'"

	sum duration_intp if od1==1, d
	gen duration_sample = inrange(duration_intp,180,r(p99))

	qui sum volume if duration_sample == 1
	scalar nusers_daily_bgd_gravity_sample = "`:di `=number_format' r(sum)'"
	di "Number of unique users BGD (gravity sample DAILY): `=nusers_daily_bgd_gravity_sample'"

*** BGD unique users and dates (daily trip)
	use "data_coded_bgd/flows/daily_trips_panel", clear

	* SAMPLE = both towers in DHAKA 
	keep if dhaka == 1

	* number of users with trips
	gunique uid if date_type_igc  == 0
	scalar nunique_users_daily_bgd = "`:di `=number_format' r(J)'"
	di nunique_users_daily_bgd

	scalar nmax_daily_bgd = "`:di `=number_format' `=87*r(J)''"
	di nmax_daily_bgd

	* weekdays
	scalar coverage_daily_bgd = "`: di %4.1f `=nusers_daily_bgd_plain / 87 / r(J) * 100''\\%"
	di coverage_daily_bgd



************
*** SLK ****
************

*** SLK tower sample
	use "data_raw_slk/other/towers_slk.dta", clear
	keep if province == "Western"
	keep tower
	rename tower origin

	tempfile sample_tower_origin
	save 	`sample_tower_origin'

	rename origin destination
	tempfile sample_tower_destination
	save 	`sample_tower_destination'

*** SLK home work 
	use "data_coded_slk/flows/home_work_odmatrix.dta", clear
	assert workday == 1 
	
	merge m:1 origin using `sample_tower_origin'
	keep if _m==3
	drop _m

	merge m:1 destination using `sample_tower_destination'
	keep if _m==3
	drop _m


	bys origin destination: gen od1 = _n==1

	qui sum volume
	scalar nusers_slk = "`:di `=number_format' r(sum)'"
	di "Number of unique users SLK (Home-Work): `=nusers_slk'"
	
	qui sum volume if origin != destination
	scalar nusers_slk_orig_neq_dest = "`:di `=number_format' r(sum)'"
	di "Number of unique users SLK (proper commuting Home-Work): `=nusers_slk_orig_neq_dest'"

	sum duration_intp if od1==1, d
	gen duration_sample = inrange(duration_intp,180,r(p99))

	qui sum volume if duration_sample == 1
	scalar nusers_slk_gravity_sample = "`:di `=number_format' r(sum)'"
	di "Number of unique users SLK (gravity sample Home-Work): `=nusers_slk_gravity_sample'"




*** SLK daily trips

	use "data_coded_slk/flows/daily_trips_odmatrix.dta", clear
    
    keep if workday == 1
	
	merge m:1 origin using `sample_tower_origin'
	keep if _m==3
	drop _m

	merge m:1 destination using `sample_tower_destination'
	keep if _m==3
	drop _m

    bys origin destination: gen od1 = _n==1
   
    qui sum volume
	scalar nusers_daily_slk = "`:di `=number_format' r(sum)'"
	scalar nusers_daily_slk_plain = r(sum)
	di "Number of unique users SLK (DAILY): `=nusers_daily_slk'"
	
	qui sum volume if origin != destination
	scalar nusers_daily_slk_orig_neq_dest = "`:di `=number_format' r(sum)'"
	di "Number of unique users SLK (proper commuting DAILY): `=nusers_daily_slk_orig_neq_dest'"

	sum duration_intp if od1==1, d
	gen duration_sample = inrange(duration_intp,180,r(p99))

	qui sum volume if duration_sample == 1
	scalar nusers_daily_slk_gravity_sample = "`:di `=number_format' r(sum)'"
	di "Number of unique users SLK (gravity sample DAILY): `=nusers_daily_slk_gravity_sample'"


*** Load data on user home locations
	use "data_coded_slk/flows/home_work_intermed_idlevel.dta", clear
	keep id hw Tmax 
	rename Tmax tower
	
	merge m:1 tower using "data_raw_slk/other/towers_slk.dta", keepusing(province)
	assert _m!=1
	drop if _m==2
	drop _m

	gen byte western = province == "Western"
	keep if western == 1

	gunique id
	scalar nunique_users_daily_slk = "`:di `=number_format' r(J)'"
	di nunique_users_daily_slk
	// gunique id if hw==1 // work in Western
	// gunique id if hw==0 // live in Western

	scalar nunique_users_hw_slk = "`:di `=number_format' r(J)'"
	di "Number of unique users SLK (Home-Work): `=nunique_users_hw_slk'"

	* 395 days in the sample
	* 282 weekdays
	scalar nmax_daily_slk = "`:di `=number_format' `=282*r(J)''"
	di nmax_daily_slk

	scalar coverage_daily_slk = "`: di %4.1f `=nusers_daily_slk_plain / 282 / r(J) * 100''\\%"
	di coverage_daily_slk

	



*** Output to tex
	file open myfile using "tables/table_H1/sample_size_stats.tex", write replace
	file write myfile "\resizebox{0.8\textwidth}{!}{" _n "\begin{tabular}{clcc}" _n "\toprule" _n  ///
					  " & & Dhaka, & Colombo,\\" _n ///
					  " & & Bangladesh & Sri Lanka\\" _n ///
					  " \hline \addlinespace" _n ///
					  " \multicolumn{4}{l}{\textit{Panel A. Home-Work Commuting Flows}} \\" _n ///
					  " (1) & Unique users                           & `=nunique_users_hw_bgd'		& `=nunique_users_hw_slk' \\" _n ///
					  " (2) & Users with home and work towers  		 & `=nusers_bgd' 				& `=nusers_slk' \\" _n ///
					  " (3) & Users (distinct home and work towers)  & `=nusers_bgd_orig_neq_dest' 	& `=nusers_slk_orig_neq_dest' \\" _n ///
					  " (4) & Users (gravity equation sample)  		 & `=nusers_bgd_gravity_sample' & `=nusers_slk_gravity_sample' \\" _n ///
					  " \addlinespace " _n ///
					  " \multicolumn{4}{l}{\textit{Panel B. Daily Commuting Flows}} \\" _n ///
					  " (5) & Unique users 		                     	& `=nunique_users_daily_bgd' 	& `=nunique_users_daily_slk' \\" _n ///
					  " (6) & Weekdays in sample                   		& 87 				  			& 282 \\" _n ///
					  " (7) & All user-days possible ($=(5)\times(6)$)  & `=nmax_daily_bgd' 			& `=nmax_daily_slk' \\" _n ///
					  " (8) & User-days with data (daily trips) 		& `=nusers_daily_bgd' 			& `=nusers_daily_slk' \\ " _n ///
					  " (9) & Coverage rate ($=(8)/(7)$) 				& `=coverage_daily_bgd' 		& `=coverage_daily_slk' \\ " _n ///
					  " \addlinespace " _n ///
					  " (10) & Trips (distinct origin and destination towers)  & `=nusers_daily_bgd_orig_neq_dest'  & `=nusers_daily_slk_orig_neq_dest' \\" _n ///
					  " (11) & Trips (gravity equation sample)  		 	 & `=nusers_daily_bgd_gravity_sample' & `=nusers_daily_slk_gravity_sample' \\" _n ///
					  "\bottomrule" _n "\end{tabular}" _n "}" _n 

	file close myfile






