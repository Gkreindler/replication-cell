* this do file: Process Bangladesh GoogleMap Travel Time Data to feed in JAVA interpolation code
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

*** tower lat, lon and area
	use "data_raw_bgd/other/towers_bgd.dta", clear
	keep if dhaka_google == 1
	keep tower lon lat area_km2
	gisid tower
	tempfile tempdata
	save `tempdata'

** first, create the matched pairs of towers
	use `tempdata', clear
		rename lat orig_lat
		rename lon orig_long
		rename tower orig_tower
		rename area_km2 orig_area_km2
		gen const = 1
		tempfile origdata
		save `origdata'

	use `tempdata', clear
		rename lat dest_lat
		rename lon dest_long
		rename tower dest_tower
		rename area_km2 dest_area_km2
		gen const = 1
		tempfile destdata
		save `destdata'

	joinby const using `origdata'

	* drop when the pair shares the same tower
	drop if dest_tower == orig_tower

	* measure distance
	geodist orig_lat orig_long dest_lat dest_long, gen(dist)
	

** adjust the bandwidth
	* obtain the radius
	gen h_d=sqrt(dest_area_km2)
	egen dtagtemp = tag(dest_tower)
	qui sum h_d if dtagtemp
	replace h_d = h_d/r(mean)
	drop dtagtemp

	gen h_o=sqrt(orig_area_km2)
	egen dtagtemp = tag(orig_tower)
	qui sum h_o if dtagtemp
	replace h_o = h_o/r(mean)
	drop dtagtemp

drop const *_km2
order dest_long	dest_lat	dest_tower	orig_long	orig_lat	orig_tower	dist	h_d	h_o

keep if dist <= 50
export delimited using "data_coded_bgd/travel-times/all tower pair in Dhaka before interpolation.csv", replace novarnames


	
**********************
* create File 2:  googlemap prediction with tower-level information (lon, lat, radius for bandwidth)
**********************

*** tower lat, lon and area
	use "data_raw_bgd/other/towers_bgd.dta", clear
	keep if dhaka_google == 1
	keep tower lon lat area_km2
	gisid tower
	tempfile tempdata
	save `tempdata'

	use `tempdata', clear
		rename tower origin
		rename area_km2 orig_area_km2
		tempfile origdata
		save `origdata'

	use `tempdata', clear
		rename tower destination
		rename area_km2 dest_area_km2
		tempfile destdata
		save `destdata'

		
** read googlemap prediction CSV
	import delimited using "data_raw_bgd/travel-times/random pair 90000 - google prediction.csv", clear

	rename dur_bg duration_bg
	
	preserve 
		import delimited using "data_raw_bgd/travel-times/random pair 90000 for googlemap API BGD.csv", clear
		destring _all, replace
		tempfile data
		save `data'
	restore

	merge 1:m odid using `data'
		keep if _merge == 3
		drop _merge

	* check whether orig_tower and dest_tower are ID
	isid orig dest
		
	merge m:1 orig using `origdata'
		keep if _m == 3
		drop _m
	
	merge m:1 dest using `destdata'
		keep if _m == 3
		drop _m		
	
		
** obtain the radius
	* obtain the radius
	gen h_d=sqrt(dest_area_km2)
	egen dtagtemp = tag(destination)
	qui sum h_d if dtagtemp
	replace h_d = h_d/r(mean)
	drop dtagtemp

	gen h_o=sqrt(orig_area_km2)
	egen dtagtemp = tag(origin)
	qui sum h_o if dtagtemp
	replace h_o = h_o/r(mean)
	drop dtagtemp

	drop *_km2
	
** create straight_line distance
geodist lat_o lon_o lat_d lon_d, gen(dist)

gunique destination
// 1904
gunique origin
// 1904

gisid origin destination

*** Save 
	order lon_d	lat_d	destination	lon_o	lat_o	origin	dist	duration_bg	distance_bg	h_d	h_o
	export delimited using "data_coded_bgd/travel-times/random tower pair - google prediction before interpolation.csv", replace novarnames



