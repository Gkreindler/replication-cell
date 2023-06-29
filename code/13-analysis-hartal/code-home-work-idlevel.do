* this do file:

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** Get panel IDS
	import delimited using "data_raw_bgd/flows-daily-trips/commuting_panel/userid_table.csv", clear
	rename v1 uid_panel
	rename v2 uids

	tempfile ids_panel
	save 	`ids_panel'

*** Get home-work IDS
	import delimited using "data_raw_bgd/flows-home-work/home_work_panel/userid_table.csv", clear
	rename v1 uid
	rename v2 uids

	** not all home-work appear in panel
	merge 1:1 uids using `ids_panel'
	assert _m!=2
	drop _m

	compress
	tempfile ids_hw
	save 	`ids_hw'

*** Prepare hw assignment
	import delimited using "data_raw_bgd/flows-home-work/user_home_office_list", clear

	greshape wide tmax tmaxfreq totfreq, i(userid) j(home_work_dummy) fast

	rename userid uids
	merge 1:1 uid using `ids_hw'
	// assert _m!=1
	count if _m==1
	assert r(N) == 1391
	drop if _m==1
	drop if _m==2
	drop if uid_panel == .
	drop _m

	drop uids uid
	rename uid_panel uid

	gen relfreq_home = tmaxfreq0 / totfreq0
	gen relfreq_work = tmaxfreq1 / totfreq1

	* mean reliability: 66% for home and 60% for work
	sum relfreq*, d

	* number of days with data: home mean (median) 24 (29.3) and work: 40 (44.9)
	sum totfreq*, d

*** Clean, save
	rename tmax0 tower_home
	rename tmax1 tower_work

	rename totfreq0 totfreq_home
	rename totfreq1 totfreq_work

	keep uid  tower_home tower_work relfreq_* /* above50 above75 */ totfreq_*

	gisid uid

	compress
	save "data_coded_bgd/flows/home_work_idlevel", replace
