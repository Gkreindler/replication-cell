
* this do file: Creates asset index from 2011 Bangladesh census data, then averages at tower level
* Date: 19 Oct 2019
* Author: gabriel kreindler

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** Czones
	use "data_raw_bgd/other/towers_bgd.dta", clear
	keep tower czone
	gisid tower

	tempfile czones
	save	`czones'
 

*** Read and combine census data
forv ip=1/3{
	local provname: word `ip' of "Dhaka" "Narayanganj" "Gazipur"

	import excel using "data_raw_bgd/census/Community_3districts_varnames.xls", ///
			sheet("`provname'") cellrange(A8) case(lower) firstrow clear
	
	tempfile prov_`provname'
	save 	`prov_`provname''
}

	append using `prov_Dhaka'
	append using `prov_Narayanganj'

*** Cleaning 
	drop if zila == ""

	* very few denisty
	drop area
	drop pop_density

*** A few variables have much coarser data only
	drop admin_unit_name_8 - perc_disability_aut
	drop admin_unit_name_11- ethnic_pop_other

	foreach i of numlist 2 3 4 5 6 7 9 10 12 13 14 {
		di `i'
		assert admin_unit_name == admin_unit_name_`i'
		assert rmo == rmo_`i' // | rmo_`i' == ""
	}
	drop admin_unit_name_*
	drop rmo_*

*** New variables

	**** Population 7+
	*** REFERENCE: 
	gen tot_pop_7plus = tot_pop * ( pop_age_09/2 + pop_age_14 + pop_age_19 + pop_age_24 + pop_age_29 + pop_age_49 + pop_age_59 + pop_age_64 + pop_age_65) / 100

	gen temp = pop_illiterate + pop_literate
	reg temp tot_pop_7plus
	drop temp

	*** MAIN:
	// pop_literate
	// pop_illiterate


	*** Pop in school

	*** REFERENCE: 
	gen pop_0_29_tot_m =  	pop_05_school_m + ///
					 	pop_05_noschool_m	+ ///
						pop_10_school_m	+ ///
						pop_10_noschool_m	+ ///
						pop_14_school_m	+ ///
						pop_14_noschool_m	+ ///
						pop_19_school_m	+ ///
						pop_19_noschool_m	+ ///
						pop_24_school_m	+ ///
						pop_24_noschool_m	+ ///
						pop_29_school_m	+ ///
						pop_29_noschool_m

	*** MAIN:
	gen pop_0_29_school_m = pop_05_school_m + ///
						pop_10_school_m	+ ///
						pop_14_school_m	+ ///
						pop_19_school_m	+ ///
						pop_24_school_m	+ ///
						pop_29_school_m

	*** REFERENCE: 
	gen pop_0_29_tot_f =  	pop_05_school_f + ///
					 	pop_05_noschool_f	+ ///
						pop_10_school_f	+ ///
						pop_10_noschool_f	+ ///
						pop_14_school_f	+ ///
						pop_14_noschool_f	+ ///
						pop_19_school_f	+ ///
						pop_19_noschool_f	+ ///
						pop_24_school_f	+ ///
						pop_24_noschool_f	+ ///
						pop_29_school_f	+ ///
						pop_29_noschool_f

	*** MAIN:
	gen pop_0_29_school_f = pop_05_school_f + ///
						pop_10_school_f	+ ///
						pop_14_school_f	+ ///
						pop_19_school_f	+ ///
						pop_24_school_f	+ ///
						pop_29_school_f

	// gen perc_school_m = pop_0_29_school_m / pop_0_29_tot_m
	// gen perc_school_f = pop_0_29_school_f / pop_0_29_tot_f

	drop pop_??_*school_?
	// drop pop_0_29*

	**** Activity

		*** REFERENCE: 
		gen tot_activity_m = act_employed_m + act_unempl_m + act_hhwork_m + act_nowork_m
		gen tot_activity_f = act_employed_f + act_unempl_f + act_hhwork_f + act_nowork_f

		*** MAIN:
		// act_employed_m
		// act_employed_f

	**** Sector

		*** REFERENCE: 
		gen tot_sector_m = field_agri_m + field_industry_m + field_service_m
		gen tot_sector_f = field_agri_f + field_industry_f + field_service_f

		*** MAIN:
		// field_agri_m
		// field_agri_f

		// field_industry_m
		// field_industry_f

	*** Household building materials
		// http://en.banglapedia.org/index.php?title=Housing
		// Irrespective of location, housing in general is classified by type of materials used for construction. In this way houses are classified into four categories i.e. 
		// a) Jhupri (shacks); made of jute sticks, tree leaves, jute sacks etc. 
		// b) Kutcha (temporary); made of mud brick, bamboo, sun-grass, wood and occasionally corrugated iron sheets as roofs. 
		// c) Semi-pucca (semi-permanent); where walls are made partially of bricks, floors are cemented and roofs of corrugated iron sheets. 
		// d) Pucca (permanent, life span over 25 years); will walls of bricks and roofs of concrete. The four types are also associated with durability where jhupri and kutcha are temporary and semi-pucca and pucca are semi-permanent and permanent. The dominant type of housing by building material is kutcha type in the rural and pucca and semi-pucca type in urban areas (Table).

		* percentages (0-100)
		sum hh_pucka hh_semipucka hh_kutcha hh_jhupri
		assert inrange(hh_pucka,0,100) | hh_pucka == .
		assert inrange(hh_semipucka,0,100) | hh_semipucka == .
		assert inrange(hh_kutcha,0,100) | hh_kutcha == .
		assert inrange(hh_jhupri,0,100) | hh_jhupri == .

		*** REFERENCE: 
		//  hh_tot_4

		*** MAIN:
		gen hh_mat_good = hh_pucka * hh_tot_4 / 100
		gen hh_mat_good_med = (hh_pucka + hh_semipucka) * hh_tot_4 / 100
		// hh_pucka
		// hh_pucka + hh_semipucka
		
		// hh_tot_4 //
		// hh_pucka // Permanent durable (wood, bricks, cement etc)
		// hh_semipucka // 
		// hh_kutcha // TEMPORARY wood, mud straw, leaves
		// hh_jhupri // shacks -- only 2%
		
	**** Sanitary Toilet

		sum perc_hh_sanitary_seal perc_hh_sanitary_noseal
		assert inrange(perc_hh_sanitary_seal,0,100) | perc_hh_sanitary_seal == .
		assert inrange(perc_hh_sanitary_noseal,0,100) | perc_hh_sanitary_noseal == .


		*** REFERENCE
		// hh_tot_4

		*** MAIN
		gen hh_toilet_good     = perc_hh_sanitary_seal * hh_tot_4 / 100
		gen hh_toilet_good_med = (perc_hh_sanitary_seal + perc_hh_sanitary_noseal) * hh_tot_4 / 100

		// perc_hh_sanitary_seal 
		// perc_hh_sanitary_noseal 
		// perc_hh_nonsanitary 
		// perc_hh_none

	**** Water source

		sum perc_water_tap
		assert inrange(perc_water_tap,0,100) | perc_water_tap == .

		*** REFERENCE
		// hh_tot_4

		*** MAIN
		gen hh_water_tap =  perc_water_tap * hh_tot_4 / 100

	**** Electrical connection -- note, 25pp is 92%

		sum perc_elec_connection
		assert inrange(perc_elec_connection,0,100) | perc_elec_connection == .

		*** REFERENCE
		// hh_tot_4

		*** MAIN
		gen hh_elec = perc_elec_connection * hh_tot_4 / 100

	**** Ownership
		sum perc_elec_connection
		assert inrange(perc_elec_connection,0,100) | perc_elec_connection == .
		
		*** REFERENCE
		// hh_tot_4

		*** MAIN
		gen hh_tenancy_own = perc_tenancy_own * hh_tot_4 / 100

	**** Construct PCA here (at thana level)
	// gen perc_male = pop_male_isx / tot_pop_isx
	gen pr_literate = pop_literate / tot_pop_7plus
	// gen pr_insch_m = pop_0_29_school_m / pop_0_29_tot_m
	// gen pr_insch_f = pop_0_29_school_f / pop_0_29_tot_f
	gen pr_empl_m = act_employed_m / tot_activity_m
	gen pr_empl_f = act_employed_f / tot_activity_f
	gen pr_indu_m = field_industry_m / tot_sector_m
	gen pr_indu_f = field_industry_f / tot_sector_f

	gen pr_mat_good    = hh_mat_good     / hh_tot_4
	gen pr_mat_goodmed = hh_mat_good_med / hh_tot_4

	gen pr_toilet_good = hh_toilet_good			/ hh_tot_4 
	gen pr_toilet_good_med = hh_toilet_good_med	/ hh_tot_4

	gen pr_water_tap		= hh_water_tap			/ hh_tot_4 
	gen pr_elec			= hh_elec				/ hh_tot_4 
	// gen pr_tenancy_own	= hh_tenancy_own		/ hh_tot_4

*** Sample
	keep if trim(village) == ""
	drop if trim(mza) == ""

	assert trim(zila) !=""
	assert trim(upazila) !=""
	assert trim(un_ward) !=""
	assert trim(mza) !=""

	gen thanaid = zila + upazila + un_ward + mza

	gisid thanaid

*** Quality Checks
	sum pr_mat_good  ///
		pr_mat_goodmed  ///
		pr_toilet_good  ///
		pr_toilet_good_med  ///
		pr_water_tap  ///
		pr_elec 

	assert inrange(pr_mat_good,		0,1) if !missing(pr_mat_good)
	assert inrange(pr_mat_goodmed,	0,1) if !missing(pr_mat_goodmed)
	assert inrange(pr_toilet_good,	0,1) if !missing(pr_toilet_good)
	assert inrange(pr_toilet_good_med,0,1) if !missing(pr_toilet_good_med)
	assert inrange(pr_water_tap,	0,1) if !missing(pr_water_tap)
	assert inrange(pr_elec,			0,1) if !missing(pr_elec)

*** PCA formula -- only housing variables
	pca pr_mat_good pr_mat_goodmed pr_toilet_good pr_toilet_good_med pr_water_tap pr_elec 

	predict pca_thana, score
	
	drop pr_*

	compress
	mdesc

	tempfile censuspop
	save 	`censuspop'


*** Read intersection
	/* 
		This file is created in QGIS by intersecting the shapefile of Thana with cell phone tower Voronoi polygons
	*/
	import excel using "data_raw_bgd/census/Census_Tower_Intersection.xlsx", clear firstrow case(lower)
	bys geocode: gegen thana_area = sum(shape_area)
	reg thana_area area // coef == 1

	keep geocode11 shape_area tower

	gen thanaid = substr(geocode11,3,9)
	drop geocode11

	merge m:1 thanaid using `censuspop'
	assert _m!=2
	drop if _m==1
	drop _m

	// drop area // only available in census at upazila level

*** Population attribution
	rename shape_area intersect_area 
	// bys tower: gegen thana_area = sum(intersect_area)
	bys thanaid: gegen thana_area = sum(intersect_area)

	* interpolate main variables based on AREA from the thanas
	foreach yvar of varlist ///
		tot_hh tot_pop pop_male pop_female ///
		thana_area ///
		sex_ratio ///
		pop_literate pop_illiterate    tot_pop_7plus ///
		pop_0_29_school_m pop_0_29_school_f     pop_0_29_tot_m pop_0_29_tot_f ///
		act_employed_m act_employed_f    tot_activity_m   tot_activity_f ///
		field_agri_m field_agri_f     tot_sector_m   tot_sector_f ///
		field_industry_m field_industry_f   ///
		hh_mat_good hh_mat_good_med hh_tot_4 ///
		hh_toilet_good hh_toilet_good_med ///
		hh_water_tap ///
		hh_elec ///
		hh_tenancy_own {
		di "computing tower-thana intersection for `yvar'"
		// cap drop temp
		gen `yvar'_isx = intersect_area / thana_area * `yvar'
		// bys tower: gegen tw_`yvar' = sum(temp)
	}

	*** Check population is the same as before (~18 million)
	sum tot_pop_isx
	di  %20.0fc r(sum)

	*** Manualy average the precomputed score
	gen weight = intersect_area / thana_area
	bys tower: gegen weight_tower = sum(weight)
	bys tower: gegen pca_thana_tower_avg = sum(weight / weight_tower * pca_thana)


	*** Reference categories
	// tot_pop_7plus
	// pop_0_29_tot_m
	// pop_0_29_tot_f
	// tot_activity_m
	// tot_activity_f
	// tot_sector_m
	// tot_sector_f
	// hh_tot_4
	// hh_tot_4
	// hh_tot_4
	// hh_tot_4
	// hh_tot_4

	gcollapse (sum) *_isx (mean) pca_thana_tower_avg, by(tower)

	gen perc_male = pop_male_isx / tot_pop_isx
	gen perc_literate = pop_literate_isx / tot_pop_7plus_isx
	gen perc_insch_m = pop_0_29_school_m_isx / pop_0_29_tot_m_isx
	gen perc_insch_f = pop_0_29_school_f_isx / pop_0_29_tot_f_isx
	gen perc_empl_m = act_employed_m_isx / tot_activity_m_isx
	gen perc_empl_f = act_employed_f_isx / tot_activity_f_isx
	gen perc_indu_m = field_industry_m_isx / tot_sector_m_isx
	gen perc_indu_f = field_industry_f_isx / tot_sector_f_isx

	gen perc_mat_good    = hh_mat_good_isx     / hh_tot_4_isx
	gen perc_mat_goodmed = hh_mat_good_med_isx / hh_tot_4_isx

	gen perc_toilet_good = hh_toilet_good_isx			/ hh_tot_4_isx 
	gen perc_toilet_good_med = hh_toilet_good_med_isx	/ hh_tot_4_isx
	gen perc_water_tap		= hh_water_tap_isx			/ hh_tot_4_isx 
	gen perc_elec			= hh_elec_isx				/ hh_tot_4_isx 
	gen perc_tenancy_own	= hh_tenancy_own_isx		/ hh_tot_4_isx

	merge 1:1 tower using `czones'
	assert _m!=1
	drop if _m==2
	drop _m


*** save 
	save "data_coded_bgd/census/censuspop_tower_allvars.dta", replace
