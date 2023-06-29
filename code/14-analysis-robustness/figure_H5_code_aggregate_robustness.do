* This do file: prepares the data for making Figure H5

/* 
	Code uses frames. Requires Stata 16.
*/

clear all

*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"

	scalar epsilon_scalar = 8.3

*********************
********* SLK *******
*********************


*** Frame for keeping the results 
	frame create agg_results
	frame change agg_results
	set obs 10
	gen sq_size = _n
	gen _beta_slope = .
	gen r2 = .
	gen n_locations = .

	frame change default

*** Code residential income from census
*** Load gravity results
	import delimited using "data_coded/dfe_slk_home_work.csv", clear
	sum _beta_log_dur
	scalar _beta_slope_scalar = r(mean)

	keep destination dfe
	tempfile dfes
	save 	`dfes'

*** tower area
	use "data_raw_slk/other/towers_slk", clear
	keep tower area_km2
	rename tower destination
	rename area_km2 km2_tower_d
	tempfile area_km2_d
	save 	`area_km2_d'

*** Load 
	use "data_coded_slk/flows/home_work_odmatrix_gravity.dta", clear

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

  	*** census outcome censuspop_tower_allvars
	merge 1:1 tower using "data_coded_slk/census/censuspop_tower_allvars", keepusing(population pca1)
	drop if _m==2
	drop _m

	tempfile residential_income_census
	save 	`residential_income_census'


*** Loop over size of the aggregation 
forv sq_size=1/10{
*** Run gravity equation at the grid-cell level
	use "data_coded_slk/flows/home_work_odmatrix_gravity.dta", clear

	*** Sample
	keep if sample_v2 == 1

	merge m:1 origin using "data_coded_slk/other/tower_grid_cells_origin.dta", keepusing(origin_g`sq_size')
	drop if _m==2
	assert _m==3
	drop _m

	merge m:1 destination using "data_coded_slk/other/tower_grid_cells_destination.dta", keepusing(destination_g`sq_size')
	drop if _m==2
	assert _m==3
	drop _m

	rename origin_g`sq_size' 		origin_square
	rename destination_g`sq_size' 	destination_square

	*** Collapse at grid level
	gcollapse (rawsum) volume (mean) duration_intp [aw=volume], by(origin_square destination_square)

	*** Coding 
	bys destination: gegen pop_work = sum(volume)
	hashsort origin destination
	by origin: gegen pop_res = sum(volume)

	gen log_dur = log(duration_intp)

	*** Sample
	* drop origins with zero flows
	gunique origin // 1866
	drop if pop_res == 0
	gunique origin // 1825

	gunique destination // 1869
	drop if pop_work == 0
	gunique destination // 1,859

	*** Gravity

	*** run with destination-specific slope of the origin-level percent literate
	ppmlhdfe volume log_dur, ab(origin DFE=destination)
	frame agg_results: replace _beta_slope = _b[log_dur] in `sq_size'

	*** Define 
	// res.meanlogy.v00     = weighted.mean(logy.v00    , w= volume, na.rm=T),
	gcollapse (mean) square_res_meanlogy_v00=DFE [aw=volume], by(origin_square)

	tempfile model_residential_income
	save 	`model_residential_income'

*** Load census income and collapse at the same level
	use `residential_income_census', clear

	rename tower origin
	merge 1:1 origin using "data_coded_slk/other/tower_grid_cells_origin.dta", keepusing(origin_g`sq_size')
	assert _m!=1
	drop if _m==2
	drop _m

	rename origin_g`sq_size' origin_square

	bys origin_square: gegen volume_origin_total = sum(volume_origin)

	gcollapse (mean) pca1 [aw=volume_origin], by(origin_square volume_origin_total)

	*** Merge model income 
	merge 1:1 origin_square using `model_residential_income'
	assert _m!=2
	count if _m==1
	assert r(N) <= 1
	drop _m


	reg pca1 square_res_meanlogy_v00 [aw=volume_origin_total], r		
	frame agg_results: replace r2 =e(r2_a) in `sq_size'

	count 
	frame agg_results: replace n_locations =r(N) in `sq_size'
		
}

	frame change agg_results
	save "data_coded/residential_income_grid_cells_slk.dta", replace


*********************
********* BGD *******
*********************



*** Results 
	frame change default
	frame drop  agg_results

	frame create agg_results
	frame change agg_results
	set obs 10
	gen sq_size = _n
	gen _beta_slope = .
	gen r2 = .
	gen n_locations = .

	frame change default


*** Code residential income from census
*** Load gravity results
	import delimited using "data_coded/dfe_bgd_home_work.csv", clear
	sum _beta_log_dur
	scalar _beta_slope_scalar = r(mean)

	keep destination dfe
	tempfile dfes
	save 	`dfes'

*** tower area
	use "data_raw_bgd/other/towers_bgd", clear
	keep tower area_km2
	rename tower destination
	rename area_km2 km2_tower_d
	tempfile area_km2_d
	save 	`area_km2_d'

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

  	*** census outcome variable
	merge 1:1 tower using "data_coded_bgd/census/censuspop_tower_allvars", keepusing(tot_pop_isx pca_thana_tower_avg)
	drop if _m==2
	drop _m


	tempfile residential_income_census
	save 	`residential_income_census'



forv sq_size=1/10{
*** Run gravity equation at the grid-cell level
	use "data_coded_bgd/flows/home_work_odmatrix_gravity.dta", clear

	*** Sample
	keep if sample_v2 == 1

	merge m:1 origin using "data_coded_bgd/other/tower_grid_cells_origin.dta", keepusing(origin_g`sq_size')
	assert _m!=1
	drop if _m==2
	drop _m

	merge m:1 destination using "data_coded_bgd/other/tower_grid_cells_destination.dta", keepusing(destination_g`sq_size')
	assert _m!=1
	drop if _m==2
	drop _m

	rename origin_g`sq_size' 		origin_square
	rename destination_g`sq_size' 	destination_square

	*** Collapse at grid level
	gcollapse (rawsum) volume (mean) duration_intp [aw=volume], by(origin_square destination_square)


	bys destination: gegen pop_work = sum(volume)
	hashsort origin destination
	by origin: gegen pop_res = sum(volume)

	gen log_dur = log(duration_intp)

	*** Sample
	* drop origins with zero flows
	gunique origin // 1866
	drop if pop_res == 0
	gunique origin // 1825

	gunique destination // 1869
	drop if pop_work == 0
	gunique destination // 1,859

	*** Gravity

	*** run with destination-specific slope of the origin-level percent literate
	ppmlhdfe volume log_dur, ab(origin DFE=destination)
	frame agg_results: replace _beta_slope = _b[log_dur] in `sq_size'

	*** Define 
	gcollapse (mean) square_res_meanlogy_v00=DFE [aw=volume], by(origin_square)

	tempfile model_residential_income
	save 	`model_residential_income'


*** Load census income and collapse at the same level
	use `residential_income_census', clear
	rename tower origin
	merge 1:1 origin using "data_coded_bgd/other/tower_grid_cells_origin.dta", keepusing(origin_g`sq_size')
	assert _m!=1
	drop if _m==2
	drop _m

	rename origin_g`sq_size' origin_square

	bys origin_square: gegen volume_origin_total = sum(volume_origin)

	gcollapse (mean) pca_thana_tower_avg  [aw=volume_origin], by(origin_square volume_origin_total)

	*** Merge model income 
	merge 1:1 origin_square using `model_residential_income'

	reg pca_thana_tower_avg square_res_meanlogy_v00 [aw=volume_origin_total], r		
	frame agg_results: replace r2 =e(r2_a) in `sq_size'

	count 
	frame agg_results: replace n_locations =r(N) in `sq_size'
		
}

	frame change agg_results
	save "data_coded/residential_income_grid_cells_bgd.dta", replace
