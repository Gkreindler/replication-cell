* this do file: Process Sri Lanka GoogleMap Travel Time Data to feed in JAVA interpolation code
*	- Two input files to feed in to JAVA interpolation code.
*		- File 1: All tower pairs with straight line distance.
*		- File 2: Googlemap query results on travel time.
*	- For the time being, do not use all short distance pairs extracted separately for interpolation input.

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

**********************
* create File 1:  googlemap prediction with tower-level information (lon, lat, radius for bandwidth)
**********************

** first, create the matched pairs
	use "data_raw_slk/other/towers_slk.dta", clear
		rename latitude orig_lat
		rename longitude orig_long
		rename tower orig_tower
		rename province orig_province_n
		gen const = 1
		tempfile origdata
		save `origdata'

	use "data_raw_slk/other/towers_slk.dta", clear
		rename latitude dest_lat
		rename longitude dest_long
		rename tower dest_tower
		rename province dest_province_n
		gen const = 1
		tempfile destdata
		save `destdata'

	* all posible combinations (cross join)
	joinby const using `origdata'

	* drop when the pair shares the same tower
	drop if dest_tower == orig_tower

	* measure distance
	geodist orig_lat orig_long dest_lat dest_long, gen(dist)
	
	keep if dist <= 50


** merge with the cell tower size to adjust the bandwidth
	preserve
		use "data_raw_slk/other/towers_slk.dta", clear
		rename tower dest_tower
		rename area_km2 dest_km2_tower
		tempfile data_d
		save `data_d'
		
		rename dest_tower orig_tower
		rename dest_km2_tower orig_km2_tower
		tempfile data_o
		save `data_o'
	restore

	merge m:1 dest_tower using `data_d', gen(_md)
	merge m:1 orig_tower using `data_o', gen(_mo)

	* obtain the radius
	gen h_d=sqrt(dest_km2_tower)
	egen dtagtemp = tag(dest_tower)
	qui sum h_d if dtagtemp
	replace h_d = h_d/r(mean)
	drop dtagtemp

	gen h_o=sqrt(orig_km2_tower)
	egen dtagtemp = tag(orig_tower)
	qui sum h_o if dtagtemp
	replace h_o = h_o/r(mean)
	drop dtagtemp

	keep if  _md == 3 & _mo == 3
	drop _m*
	drop /* pop_tower */ *_km2_*

drop dest_province_n orig_province_n const
order dest_long	dest_lat	dest_tower	orig_long	orig_lat	orig_tower	dist	h_d	h_o
export delimited using "data_coded_slk/travel-times/all tower pair within 50km before interpolation.csv", replace novarnames

	
**********************
* create File 2:  googlemap prediction with tower-level information (lon, lat, radius for bandwidth)
**********************



import delimited using "data_raw_slk/travel-times/random 90000 tower pair within 50km - base.csv", clear
	tempfile tempdata
	save `tempdata'
	keep dest_long dest_lat dest_tower orig_long orig_lat orig_tower id dist
	rename id odid
	duplicates drop odid, force	


** merge with the travel time data extracted from googlemap
	preserve 
		import delimited using "data_raw_slk/travel-times/random 90000 tower pair within 50km - google prediction.csv", clear
		destring _all, replace
		keep odid duration_bg duration_in_traffic_bg querytime_utc distance_bg
		tempfile data
		save `data'
		
		duplicates drop odid, force
	restore

	merge 1:m odid using `data'
		keep if _merge == 3
		drop _merge
		// Note: there are some missing odid's

	
** merge with the cell tower size for the bandwidth of interpolation
	preserve
		use "data_raw_slk/other/towers_slk.dta", clear
		rename tower dest_tower
		rename area_km2 dest_km2_tower
		tempfile data_d
		save `data_d'
		
		rename dest_tower orig_tower
		rename dest_km2_tower orig_km2_tower
		tempfile data_o
		save `data_o'
	restore

	merge m:1 dest_tower using `data_d', gen(_md)
	merge m:1 orig_tower using `data_o', gen(_mo)

	* obtain the radius
	gen h_d=sqrt(dest_km2_tower)
	egen dtagtemp = tag(dest_tower)
	qui sum h_d if dtagtemp
	replace h_d = h_d/r(mean)
	drop dtagtemp

	gen h_o=sqrt(orig_km2_tower)
	egen dtagtemp = tag(orig_tower)
	qui sum h_o if dtagtemp
	replace h_o = h_o/r(mean)
	drop dtagtemp

	keep if _md == 3 & _mo == 3
	drop _m*
	drop *_km2_*

gunique dest_tower
// 3049
gunique orig_tower
// 3047

drop querytime_utc
keep if duration_in_traffic_bg != .
order dest_long	dest_lat	dest_tower	orig_long	orig_lat	orig_tower	dist	odid	duration_bg	duration_in_traffic_bg	distance_bg	h_d	h_o
export delimited using "data_coded_slk/travel-times/random 90000 towe pair within 50km - google prediction before interpolation.csv", replace novarnames



