* This do file: compute tower distance to CBD for the two countries

clear all
version 16
set seed XXXXX // <----- removed in public release of the data

*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"

*******
*** BGD
*******

	use "data_raw_bgd/other/towers_bgd", clear
	keep tower latitude longitude
	rename latitude lat
	rename longitude lon

	gen lat_cbd = 23.7268867
	gen lon_cbd = 90.4198178 
	geodist lat_cbd lon_cbd lat lon, gen(distCBD) 

	* distance in meters
	replace distCBD = 1000 * distCBD 

	*** ONLY IN PUBLIC RELEASE
	* we are introducing normally distributed noise to avoid disclosing the exact tower locations
	* this leads to results that differ slightly from those in the published paper
	replace distCBD = distCBD + 1000 * rnormal()
	
	keep tower distCBD
	gisid tower

	save "data_coded_bgd/other/dist2cbd_public.dta", replace


*******
*** SLK
*******

	use "data_raw_slk/other/towers_slk.dta", clear
	rename latitude lat
	rename longitude lon

	gen lat_cbd = 6.934988
	gen lon_cbd = 79.845297
	geodist lat_cbd lon_cbd lat lon, gen(distCBD) 

	* distance in meters
	replace distCBD = 1000 * distCBD 

	*** ONLY IN PUBLIC RELEASE
	* we are introducing normally distributed noise to avoid disclosing the exact tower locations
	* this leads to results that differ slightly from those in the published paper
	replace distCBD = distCBD + 1000 * rnormal()
	
	keep tower distCBD
	gisid tower

	save "data_coded_slk/other/dist2cbd_public.dta", replace
