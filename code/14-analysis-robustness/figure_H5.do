* This do file: Figure H5: predictive power as a function of aggregation

clear all


*** This global is set in "C:\ado\profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** Graph
*** NOTE: first run the parts below to code grid_cells_residential_income_validation.dta

	use 		 "data_coded/residential_income_grid_cells_bgd.dta", clear
	gen sample = "bgd"
	append using "data_coded/residential_income_grid_cells_slk.dta"
	replace sample = "slk" if sample == ""

	*** sq_size counts the number of Voronoi cells inside the grid cell
	* if this is =1 it means the Voronoi cell might be much larger than the grid cell
	* so, we drop these
	* without, we get much lower R^2 for 1km2 aggregation (but similar for larger cell sizes)
	drop if sq_size == 1

	twoway 	(line 		n_locations sq_size if sample == "bgd", lcolor(gs10)) ///
			(line 		n_locations sq_size if sample == "slk", lcolor(gs10) lpattern(dash)) ///
			(line 		r2 sq_size if sample == "bgd", lcolor(red) yaxis(2)) ///
			(scatter 	r2 sq_size if sample == "bgd", mcolor(red) yaxis(2)) ///
			(line  		r2 sq_size if sample == "slk", lcolor(blue) yaxis(2) lpattern(dash)) ///
			(scatter 	r2 sq_size if sample == "slk", mcolor(blue) yaxis(2)) ///
			, legend(order(1 "N location BGD" 3 "Adj R{sup:2} BGD" 2 "N location SLK" 5 "Adj R{sup:2} SLK") col(2)) ///
			yscale(alt axis(2)) yscale(alt) ///
			ylabel(, angle(zero)) ylabel(0(0.2)1, angle(zero) axis(2)) ///
			ytitle("Adj" " " "R{sup:2}", axis(2) orientation(horizontal)) ///
			ytitle("Number of" "locations", orientation(horizontal)) ///
			xtitle("Aggregation level: grid cell size (km, approx)") ///
			graphregion(color(white)) scale(1.1)

	graph set window fontface "Helvetica"	// Set graph font
	graph set eps fontface "Helvetica"
	graph display, ysize(3) xsize(4.5)

	graph export "figures/figure_H5/figure_H5_aggregation.png", replace
	graph export "figures/figure_H5/figure_H5_aggregation.pdf", replace

	
