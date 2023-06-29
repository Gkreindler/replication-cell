* This do file: analyzes the predictive power as a function of radius to the city center Dhaka
* date: 10/10/2020
* author: Gabriel Kreindler

/* 
	Code uses frames. Requires Stata 16.
*/

clear all

*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"

*********************
********* SLK *******
*********************

*** Load tower coordinates
	use "data_raw_slk/other/towers_slk", clear
	keep tower latitude longitude
	rename tower origin

	forv i=1/10{
		gen lat_ceil = ceil(latitude  * 100 / `i') / 100 * `i'
		gen lon_ceil = ceil(longitude * 100 / `i') / 100 * `i'
		gegen origin_g`i' = group(lat_ceil lon_ceil)
		cap drop lat_ceil
		cap drop lon_ceil
	}
	drop latitude longitude

	save "data_coded_slk/other/tower_grid_cells_origin.dta", replace

	rename origin destination
	forv i=1/10{
		rename origin_g`i' destination_g`i'
	}

	save "data_coded_slk/other/tower_grid_cells_destination.dta", replace


*********************
********* BGD *******
*********************

*** Pre-code the square grids
	use "data_raw_bgd/other/towers_bgd", clear
	keep tower latitude longitude
	gduplicates drop
	gisid tower
	rename tower origin

	forv i=1/10{
		gen lat_ceil = ceil(latitude  * 100 / `i') / 100 * `i'
		gen lon_ceil = ceil(longitude * 100 / `i') / 100 * `i'
		gegen origin_g`i' = group(lat_ceil lon_ceil)
		cap drop lat_ceil
		cap drop lon_ceil
	}
	drop latitude longitude

	save "data_coded_bgd/other/tower_grid_cells_origin.dta", replace

	rename origin destination
	forv i=1/10{
		rename origin_g`i' destination_g`i'
	}

	save "data_coded_bgd/other/tower_grid_cells_destination.dta", replace

