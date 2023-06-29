
* this do file: Creates asset index from 2012 Sri Lanka census data, then average at tower level
* Date: 19 Oct 2019
* Author: gabriel kreindler

clear all
set more off

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** Population (from the code that processes the education census data)
	use "data_coded_slk/census/censuspop_tower_education.dta", clear
	keep tower population
	tempfile population_data
	save 	`population_data'

*** GN - tower correspondence 
	/* 
		This file is created in QGIS by intersecting the shapefile of Grama Niladari with cell phone tower Voronoi polygons
	*/
	use "data_raw_slk/census/150406_gn_tower.dta", clear
	rename km2 intersect_area
	label var intersect_area "Area of GN and cell tower intersection"

	tempfile gn_tower_slk
	save 	`gn_tower_slk'
	
*** GN census data
	use "data_raw_slk/census/140728_census_gn_clean.dta", clear
	destring code7, replace

	*** cleaning
	count if gn_n_orig == "Henawatta"
	assert r(N) == 1
	assert  n_hh_toilet == 1        if gn_n_orig == "Henawatta"
	replace n_hh_toilet = n_hh_wall if gn_n_orig == "Henawatta"

*** Construct variables

	* toiled in the household (exclusive or shared)
		gen perc_toiled_inside = (toilet_in_excl + toilet_in_share) / n_hh_toilet

	* roof material asbestos 
		gen perc_roof_good = mat_roof_conc / n_hh_roof
		gen perc_roof_good_med = (mat_roof_conc+mat_roof_asbes) / n_hh_roof

	* wall material
		gen perc_wall_good = (mat_wall_bri + mat_wall_cemnt) / n_hh_wall

	* tap water
		// gen perc_water_tap = (dw_pipe_in + dw_pipe_inout + dw_pipe_out) / n_hh_dw
		gen perc_water_tap = dw_pipe_in / n_hh_dw

	* light source
		gen perc_grid = light_elec_nat / n_hh_light

	// merge 1:m code7 using `gn_tower_slk'

*** All vars
	foreach myvar of varlist toilet_*{
		di "`myvar'"
		gen pr_`myvar' = `myvar' / n_hh_toilet
	}

	foreach myvar of varlist mat_roof_*{
		di "`myvar'"
		gen pr_`myvar' = `myvar' / n_hh_roof
	}

	foreach myvar of varlist mat_wall_*{
		di "`myvar'"
		gen pr_`myvar' = `myvar' / n_hh_wall
	}

	foreach myvar of varlist dw_*{
		di "`myvar'"
		gen pr_`myvar' = `myvar' / n_hh_dw
	}

	foreach myvar of varlist light_*{
		di "`myvar'"
		gen pr_`myvar' = `myvar' / n_hh_light
	}	

*** checks:
	sum perc_toiled_inside ///
		perc_roof_good ///
		perc_roof_good_med ///
		perc_wall_good ///
		perc_water_tap ///
		perc_grid

	* a few typos in the excel file (original census or maybe our editing)
	count if perc_toiled_inside > 1 & !missing(perc_toiled_inside)
	assert r(N) == 6 
	replace perc_toiled_inside = . if perc_toiled_inside > 1

	assert perc_roof_good <= 1 		if !missing(perc_roof_good)
	assert perc_roof_good_med <= 1 	if !missing(perc_roof_good_med)
	assert perc_wall_good <= 1 		if !missing(perc_wall_good)
	assert perc_water_tap <= 1 		if !missing(perc_water_tap)
	assert perc_grid <= 1 			if !missing(perc_grid)

*** PCA 1
	pca perc_toiled_inside ///
		perc_roof_good ///
		perc_roof_good_med ///
		perc_wall_good ///
		perc_water_tap ///
		perc_grid
	predict pca1

*** PCA 2 (all var, direction ambiguous)
	// pca pr_*
	// predict pca2
	// reg pca1 pca2

	merge 1:m code7 using `gn_tower_slk'
	keep if _m==3
	drop _m

***
	bys tower: gegen tower_area = sum(intersect_area)

	foreach yvar of varlist perc_* pr_* pca1 {
		replace `yvar' = intersect_area / tower_area * `yvar'
	}

	*** Manualy average the precomputed score
	gcollapse (sum) pca1 perc_* pr_* , by(tower)

	*** Add population
	merge 1:1 tower using `population_data'
	assert _m!=2
	drop _m

*** save 
	compress
	save "data_coded_slk/census/censuspop_tower_allvars.dta", replace	

