* this do file: Code education from 2012 Sri Lanka census data, then average at tower level
* Date: 19 Oct 2019
* Author: gabriel kreindler

clear all
set more off

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

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
	import excel using "data_raw_slk/census/tabula-P4-pages-1-63.xlsx", sheet("only GN") clear firstrow

	destring code7, replace

	// 4 GNs are duplicates (8 total)
	gcollapse (sum) Total-Noschooling, by(District DS_Division GN_N id code7) fast


*** Construct variables
	rename Total total
	assert total == Primery + Secondary + GCEOL + GCEAL + Degreeandabove + Noschooling

	sum total 

	* gen 
		gen perc_noschool  = Noschooling / total
		gen perc_primary   = Primery / total
		gen perc_secondary = Secondary / total
		gen perc_level3    = GCEOL / total
		gen perc_level4    = GCEAL / total
		gen perc_degree    = Degreeandabove / total


		label var perc_noschool  "0 No Schooling"
		label var perc_primary   "1 Primary School"
		label var perc_secondary "2 Secondary School"
		label var perc_level3    "3 G.C.E. (O/L)"
		label var perc_level4    "4 G.C.E. (A/L)"
		label var perc_degree    "5 Degree and above"

		drop Noschooling Primery - Degreeandabove


*** merge tower information
	merge 1:m code7 using `gn_tower_slk'
	count if _m==1
	assert r(N) == 7
	keep if _m==3
	drop _m

***

	bys tower: gegen tower_area = sum(intersect_area)
	bys code7: gegen gn_area = sum(intersect_area)

	*** prepare weighted averages of these variables
	foreach yvar of varlist perc_* {
		replace `yvar' = intersect_area / tower_area * `yvar'
	}

	*** we reassign population
	gen total_original=total
	replace total = intersect_area / gn_area * total

	* check that total population is the same
	bys code7: gen gn1=_n==1
	
	sum total_original if gn1==1
	di %20.0fc r(sum)

	sum total
	di %20.0fc r(sum)

*** collapse at the tower level
	gcollapse (sum) perc_* total, by(tower)

 	gen perc_atleast_primary   = perc_primary + perc_secondary + perc_level3 + perc_level4 + perc_degree
 	gen perc_atleast_secondary = perc_secondary + perc_level3 + perc_level4 + perc_degree
 	gen perc_atleast_level3    = perc_level3 + perc_level4 + perc_degree
 	gen perc_atleast_level4    = perc_level4 + perc_degree
 	gen perc_atleast_degree    = perc_degree

 	rename total population

*** save
	compress 
	save "data_coded_slk/census/censuspop_tower_education.dta", replace	
