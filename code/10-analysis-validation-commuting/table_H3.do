* This do file: coding for Table H3
clear all
set more off
pause on
// version 11

*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"
	adopath ++ "${cellphone_root}ado/"


************
*** BGD ****
************

*** Census
	use "data_coded_bgd/census/censuspop_tower_allvars", clear
	keep tower tot_pop_isx
	rename tot_pop_isx tot_pop_tower

	tempfile tower_population
	save 	`tower_population'

*** load cell phone commuting data
	use "data_coded_bgd/flows/home_work_odmatrix", clear
	keep if workday == 1
	
	* volume_nosame: exclude same-tower pairs
		gen volume_nosame = volume
		replace volume_nosame = 0 if origin == destination
		
	gcollapse (sum) volume volume_nosame, by(origin)
	rename origin tower
	
	*** Add census population
	merge 1:1 tower using `tower_population'
	keep if _merge == 3
	drop _merge

	*** Add area
	merge 1:1 tower using "data_raw_bgd/other/towers_bgd", keepusing(area_km2)
	drop if _m==2
	assert _m!=1
	drop _m
		
*** prepareation for regression
	gen log_volume = log(volume)
	gen log_volume_nosame = log(volume_nosame)
	gen log_tot_pop_tower = log(tot_pop_tower)
	
	gen log_density = log(volume / area_km2)
	gen log_density_nosame = log(volume_nosame / area_km2)
	gen log_tot_density_tower = log(tot_pop_tower / area_km2)

*** save
	save "data_coded_bgd/census/table_H3_population_CDR_census", replace





*** SLK preparation

*** Tower area
	use "data_raw_slk/other/towers_slk", clear
	keep tower area_km2 province
	tempfile area_km2
	save 	`area_km2'

*** load cell phone data
	use "data_coded_slk/flows/home_work_odmatrix", clear
	keep if workday == 1
	
	* volume_nosame: exclude same-tower pairs
		gen volume_nosame = volume
		replace volume_nosame = 0 if origin == destination
		
	gcollapse (sum) volume volume_nosame , by(origin)
	rename origin tower	
	
	* merge census population
		merge 1:1 tower using "data_coded_slk/census/censuspop_tower_allvars.dta", ///
		 		keepusing(population)
		keep if _merge == 3
		drop _merge

	* merge area 
		merge 1:1 tower using `area_km2'
		keep if _m==3
		drop _m

	* SAMPLE: only Western province
		keep if province == "Western"
		
*** show the correlation
	gen log_volume = log(volume)
	gen log_volume_nosame = log(volume_nosame)
	gen log_tot_pop_tower = log(population)
	
	gen log_density = log(volume / area_km2)
	gen log_density_nosame = log(volume_nosame / area_km2)
	gen log_tot_density_tower = log(population / area_km2)

	
*** save
	save "data_coded_slk/census/table_H3_population_CDR_census", replace





************************************
*** regressions (without Conley SEs)
************************************
eststo clear

*** BGD
use "data_coded_bgd/census/table_H3_population_CDR_census", clear
	eststo: reg log_volume_nosame log_tot_pop_tower, r
	eststo: reg log_density_nosame log_tot_density_tower, r
	
*** SLK
use "data_coded_slk/census/table_H3_population_CDR_census", clear
	eststo: reg log_volume_nosame log_tot_pop_tower, r
	eststo: reg log_density_nosame log_tot_density_tower, r
			
*** output table
	esttab, se ar2 drop(_cons)


************************************
*** regression (with Conley SEs with cutoff 5km)
************************************

*******
*** BGD
*******
	clear all
	use "data_coded_bgd/census/table_H3_population_CDR_census", clear

	*** merge true latitude and longitude
	merge 1:1 tower using "data_raw_bgd/other/towers_bgd.dta", keepusing(latitude longitude)
	assert _m!=1
	drop if _m==2
	drop _m

	gen tvar = 1
	gen one_var = 1

	keep log_volume_nosame log_tot_pop_tower log_density_nosame log_tot_density_tower one_var latitude longitude tvar tower

*** density regression
	reg log_density_nosame log_tot_density_tower
	local adj_r2=e(r2_a)

	eststo bgd_density: ols_spatial_HAC log_density_nosame log_tot_density_tower one_var, ///
			lat(latitude) lon(longitude) timevar(tvar) panelvar(tower)  dist(5)
	estadd scalar adjusted_r2=`adj_r2'
	estadd local city="Dhaka"


*** population regression
	reg log_volume_nosame log_tot_pop_tower 
	local adj_r2=e(r2_a)

	eststo bgd_pop: ols_spatial_HAC log_volume_nosame log_tot_pop_tower one_var, ///
			lat(latitude) lon(longitude) timevar(tvar) panelvar(tower) dist(5)
	
	estadd scalar adjusted_r2=`adj_r2'
	estadd local city="Dhaka"


*******
*** SLK
*******
	use "data_coded_slk/census/table_H3_population_CDR_census", clear
	
	*** merge true latitude and longitude
	merge 1:1 tower using "data_raw_slk/other/towers_slk.dta", keepusing(latitude longitude)
	assert _m!=1
	drop if _m==2
	drop _m

	*** in public release: using random latitude and longitude (to not disclose tower locations)
	// gen latitude=runiform()
	// gen longitude=runiform()

	gen tvar = 1
	gen one_var = 1

	drop if missing(log_volume_nosame)

	keep log_volume_nosame log_tot_pop_tower log_density_nosame log_tot_density_tower one_var latitude longitude tvar tower

*** density regression
	reg log_density_nosame log_tot_density_tower
	local adj_r2=e(r2_a)

	eststo slk_density: ols_spatial_HAC log_density_nosame log_tot_density_tower one_var, ///
			lat(latitude) lon(longitude) timevar(tvar) panelvar(tower)  dist(5)
	estadd scalar adjusted_r2=`adj_r2'
	estadd local city="Colombo"


*** population regression
	reg log_volume_nosame log_tot_pop_tower 
	local adj_r2=e(r2_a)

	eststo slk_pop: ols_spatial_HAC log_volume_nosame log_tot_pop_tower one_var, ///
			lat(latitude) lon(longitude) timevar(tvar) panelvar(tower) dist(5)
	
	estadd scalar adjusted_r2=`adj_r2'
	estadd local city="Colombo"


*** Save to file
	local outputfile_1 "tables/table_H3/table_H3.tex"
	esttab bgd_density slk_density bgd_pop slk_pop ///
			 using "`outputfile_1'", se label replace booktab ///
			 keep(log_tot_pop_tower log_tot_density_tower) ///
			 coeflabels(	///
			 	log_tot_pop_tower 		"log Residential Population (census)" ///
				log_tot_density_tower 	"log Residential Density (census)" ///
				) ///
			 b(a2) ///
			 stats(city N adjusted_r2, ///
			 	 label("City" "Observations" "Adjusted $ R^2$") fmt(%12.0fc a2)) ///
			 nonotes nomtitle ///
			 mgroups("log Res. Density (cell phone)" "log Res. Pop. (cell phone)", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span}))
