* this do file: Main hartal analysis (table 5)

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"

*** Load
	use "data_coded_bgd/flows/daily_trips_panel_hartal_coded", clear

*** SAMPLE: restrict to hartal and weekdays
	keep if inlist(date_type_igc,0,4)
	assert hartal == (date_type_igc == 4)
	rename hartal_igc hartal

	* dropping dates that are BOTH hartal and friday/saturday because it's ambiguous
	gen day = mod(date_numeric, 100)
	gen month = (date_numeric - day) / 100
	gen date = mdy(month, day, 2013)
	gen friday   = dow(date) == 5
	gen saturday = dow(date) == 6
	drop if hartal == 1 & friday == 1
	drop if hartal == 1 & saturday == 1

*** Normalize commuting outcome var relative to non-holiday non-hartal workdays
	gen commute = dest_is_work
	sum commute if date_type_igc == 0
	gen double commute_pp = commute / r(mean) 


******************
**** ANALYSIS ****
******************

	estimates clear
	*** Simple 
		eststo c1: reghdfe commute_pp hartal, ab(uid month) vce(cluster home_origin work_destination)
		sum commute_pp if e(sample) == 1 & hartal == 0
		estadd scalar control_mean = r(mean)
		estadd local uidfe = "X"


	*** With dest FE interaction
		sum dfe_adj
		gen hartal_destfe = hartal * (dfe_adj - r(mean)) / r(sd)
		eststo c2: reghdfe commute_pp hartal hartal_destfe, ab(uid month) vce(cluster home_origin work_destination)
		sum commute_pp if e(sample) == 1 & hartal == 0
		estadd scalar control_mean = r(mean)
		estadd local uidfe = "X"

*** ADD DISTANCE INTERACTIONS
		sum log_dur
		gen hartal_log_dur = hartal * (log_dur - r(mean)) / r(sd)

	*** With dest FE interaction
		eststo c3: reghdfe commute_pp hartal hartal_destfe hartal_log_dur, ab(uid month) vce(cluster home_origin work_destination)
		sum commute_pp if e(sample) == 1 & hartal == 0
		estadd scalar control_mean = r(mean)
		estadd local uidfe = "X"

	*** Test adding destination distance to CBD
		sum log_dest_dist2cbd
		gen hartal_log_d2cbd = hartal * (log_dest_dist2cbd - r(mean)) / r(sd)
		eststo c3b: reghdfe commute_pp hartal hartal_destfe hartal_log_dur hartal_log_d2cbd, ab(uid month) vce(cluster home_origin work_destination)
		sum commute_pp if e(sample) == 1 & hartal == 0
		estadd scalar control_mean = r(mean)
		estadd local uidfe = "X"
		

*** Structural equation for high/low skilled
	*** /beta_{ab}=h_{ab} & \left( \beta^H + \beta_D^H\log(D_{ab})+\beta_W^H\log(W_b^H)\right) + \\ (1-h_{ab}) & \left( \beta^L + \beta_D^L\log(D_{ab})+\beta_W^L\log(W_b^L)\right)

		*** hartal = \beta^L
		*** hartal x share_high = \beta_H - \beta^L
		gen hartal_share_high = hartal * ratio_ols_high
		gen hartal_share_low  = hartal * (1-ratio_ols_high)


		*** hartal x log_dur = \beta_D^L
		*** hartal x log_dur x share_high = \beta_D^H - \beta_D^L
		sum log_dur
		// gen hartal_log_dur = hartal * (log_dur - r(mean)) / r(sd)

		gen hartal_log_dur_share_high = hartal * (log_dur - r(mean)) / r(sd) * ratio_ols_high
		gen        log_dur_share_high =          (log_dur - r(mean)) / r(sd) * ratio_ols_high
		gen hartal_log_dur_share_low  = hartal * (log_dur - r(mean)) / r(sd) * (1-ratio_ols_high)
		gen 	   log_dur_share_low  = 		 (log_dur - r(mean)) / r(sd) * (1-ratio_ols_high)

		*** hartal x log_dfe_high x share_high = \beta_W^L
		*** hartal x log_dfe_low  x share_low  = \beta_W^H
		sum dfe_adj_high
		gen   destfe_share_high =          (dfe_adj_high - r(mean)) / r(sd) * ratio_ols_high
		gen h_destfe_share_high = hartal * (dfe_adj_high - r(mean)) / r(sd) * ratio_ols_high

		sum dfe_adj_low
		gen   destfe_share_low =          (dfe_adj_low - r(mean)) / r(sd) * (1-ratio_ols_high)
		gen h_destfe_share_low = hartal * (dfe_adj_low - r(mean)) / r(sd) * (1-ratio_ols_high)


		eststo c4: reghdfe commute_pp ///
							hartal_share_low hartal_share_high ///
							ratio_ols_high ///
							h_destfe_share_low h_destfe_share_high destfe_share_high destfe_share_low ///
							hartal_log_dur_share_low hartal_log_dur_share_high log_dur_share_low log_dur_share_high, ///
					 ab(uid month) vce(cluster home_origin work_destination)

		test hartal_share_low == hartal_share_high
		estadd scalar pval1 = r(p)
		
		test h_destfe_share_low == h_destfe_share_high
		estadd scalar pval2 = r(p)

		test hartal_log_dur_share_low == hartal_log_dur_share_high
		estadd scalar pval3 = r(p)

		sum commute_pp if e(sample) == 1 & hartal == 0
		estadd scalar control_mean = r(mean)
		estadd local uidfe = "X"


*** Write to file
	esttab c1 c2 c3 c3b c4 using "tables/table_5/main_table_heterogeneity_5.tex", ///
		replace b(%12.3f) se(%12.3f) drop(_cons ratio_ols_high log_dur_share_low log_dur_share_high destfe_share_high destfe_share_low) ///
			order(hartal hartal_share_low hartal_share_high ///
				hartal_destfe h_destfe_share_low h_destfe_share_high ///
				hartal_log_dur hartal_log_d2cbd hartal_log_dur_share_low hartal_log_dur_share_high ) ///
			coeflabels(hartal "Hartal" ///
				hartal_share_low    "\quad ($\beta^L$) \% Low Skill"  ///
				hartal_share_high   "\quad ($\beta^H$) \% High Skill"  ///
				hartal_destfe     	"\quad Dest. FE (z) " ///
				h_destfe_share_low   "\quad ($\beta_W^L$) \% Low Skill $\times$ Dest. FE Low Skill (z)" ///
				h_destfe_share_high  "\quad ($\beta_W^H$) \% High Skill $\times$ Dest. FE High Skill (z)" ///
				hartal_log_dur 		"\quad Log Duration (z)"  ///
				hartal_log_d2cbd     "\quad Log Workplace Distance to CBD (z) " ///
				hartal_log_dur_share_low  "\quad ($\beta_D^L$) \% Low Skill $\times$ Log Duration (z) "  ///
				hartal_log_dur_share_high "\quad ($\beta_D^H$) \% High Skill $\times$ Log Duration (z) "  ///
				) ///
			starlevels("$^{*}$" .10 "$^{**}$" .05 "$^{***}$" .01)  ///
			mgroups("Work Commute (\% change vs weekday)", pattern(1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
			stats(uidfe pval1 pval2 pval3 N, ///
				labels( "Commuter FE"  ///
				 		"P-value $\beta^L=\beta^H$" /// 
				 		"P-value $\beta_W^L=\beta_W^H$" ///
				 		"P-value $\beta_D^L=\beta_D^H$" "Observations") ///
				 fmt("%s" "%12.2f" "%12.2f" "%12.2f" "%8.6e")) booktabs ///
			 nonotes nomtitles
