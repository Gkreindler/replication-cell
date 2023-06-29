* this do file: Figure 2: smoothing the destination fixed effects using an adaptive kernel bandwidth

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"
	adopath ++ "${cellphone_root}ado/"

*** Tower Voronoi Cell Area
	use "data_raw_bgd/other/tower_estimates_BGD.dta", clear
	keep tower km2_tower_d
	rename km2_tower_d km2_tower
	tempfile tower_areas
	save 	`tower_areas'

*** Tower coordinates
	use "data_raw_bgd/other/antenna and tower coordinates - DhakaGaziNara", clear
	keep ant10 tower lat lon area District  
	gisid ant10
	gen dhaka = (District != "")
	assert inlist(dhaka,0,1)
	keep tower lat lon
	duplicates drop
	gisid tower 

	merge 1:1 tower using `tower_areas'
	drop _m

	rename tower destination
	tempfile towers
	save 	`towers'

*** Read 
	import delimited using "data_coded/dfe_bgd_home_work.csv", clear

	merge 1:1 destination using `towers'
	assert _m!=1
	drop if _m==2
	drop _m

	assert !missing(km2_tower_d)

	gen double destfe_adj = dfe - log(km2_tower)
 	sum destfe_adj
 	replace destfe_adj = destfe_adj - r(mean)

 	* We are using epsilon = 8.3 as estimated in Table 2
 	gen double destfe_adj_div_eps = destfe_adj / 8.3

	*** adaptive bandwidth for smoothing, proportional to the radius of the equivalent area circle
 	gen double h = sqrt(km2_tower)

 	*** run local smoothing
	local bw = 0.015

 	foreach va of varlist destfe_adj destfe_adj_div_eps{
 		llrmap2 `va' lat lon h, bw(`bw')
	 	cap drop `va'_se
	 	rename `va'_hat `va'_15
 	}
	
	mdesc

	export delimited using "maps/dfe_bgd_home_work_smoothed.csv", replace


*******
*** SLK
*******

*** Tower Voronoi Cell Area
	use "data_raw_slk/other/140806_tower_pop.dta", clear
	keep tower km2_tower
	gisid tower
	tempfile tower_areas
	save 	`tower_areas'

*** Tower coordinates
	use "data_raw_slk/other/towers_cordinates.dta", clear
	keep if province_n == "Western"
	rename latitude lat
	rename longitude lon
	keep tower lat lon
	gisid tower 

	merge 1:1 tower using `tower_areas'
	drop _m

	rename tower destination
	tempfile towers
	save 	`towers'

	*** Load estimated destination FEs
	import delimited using "data_coded/dfe_slk_home_work.csv", clear

	merge 1:1 destination using `towers'
	assert _m!=1
	drop if _m==2
	drop _m

	assert !missing(km2_tower)
	// replace km2_tower = km2_tower / 1000000

	gen double destfe_adj = dfe - log(km2_tower)

	*** adaptive bandwidth for smoothing, proportional to the radius of the equivalent area circle
 	gen double h = sqrt(km2_tower)

 	sum destfe_adj
 	replace destfe_adj = destfe_adj - r(mean)

 	gen double destfe_adj_div_eps = destfe_adj / 8.3


 	*** run local smoothing
 	local bw = 0.015

 	foreach va of varlist destfe_adj destfe_adj_div_eps{
 		llrmap2 `va' lat lon h, bw(`bw')
	 	cap drop `va'_se
	 	rename `va'_hat `va'_15
 	}

	mdesc

	export delimited using "maps/dfe_slk_home_work_smoothed.csv", replace


