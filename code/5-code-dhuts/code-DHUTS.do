* This do file: code DHUTS survey data

clear all
set more off
pause on

*** This global is set in "C:/ado/profile.do" and points to the main replication folder
	cd "$cellphone_root"
	
******************
*** load DHUTS ***
******************
	import delimited using "data_raw_bgd/dhuts/s12_1.csv", clear varnames(1)

	rename taz_code_home origin_czone
	rename taz_code_office destination_czone

*** respondent sample
	* income
		destring amount, gen(income) force
		gen income_trim = income
		sum income, d
		replace income_trim = . if income >= r(p99)

		sum income_trim, d

	* primary occupation
	* 1	 Govt. Service 
	* 2	 Private Service 
	* 3	 Business 
	* 4	 Unemployed 
	* 5	 Student 
	* 6	 Housewife 
	* 7	 Agriculture / farming 
	* 8	 Others (Specify) 
		destring primary_code, replace
		tab primary_code, m
		recode primary_code (.=8)

		gen primary_govt = primary_code == 1

	* clean employed code
	* Employed		
	* 1	 Full time 	
	* 2	 Part time 	
	* 3	 Casual
	* 4	 Unemployed 	
	* 5	 Retired 	
	* 6	 Other, describe 
		tab employed
		destring employed, gen(employed_code) force
		tab employed_code, m
		replace employed_code = . if inlist(employed_code,0, 7,8,9,13,65)
		assert inrange(employed_code,1,6) | employed_code == .

		recode employed_code (.=6)

	* gender
		replace sex = trim(sex)
		assert inlist(sex,"", "F", "M")
		replace sex = "1" if sex == "M"
		replace sex = "0" if sex == "F"
		destring sex, generate(male)

	* age
		destring years, replace


	*	clean level_code (education level code)
  	*	Education Level 			
  	*	1	 Illiterate 		
  	*	2	 Primary 		
  	*	3	 SSC (High School)  		
  	*	4	 HSC or equivalent 		
  	*	5	 Graduate 		
  	*	6	 Post Graduate 		
  	*	7	 Technical  		
  	*	8	 Other, describe 
  		count if level_code == ""
  		destring level_code, replace force
  		count if level_code == .

  		replace level_code = 8 if !inrange(level_code, 1, 8)

 	* clean sector_code
 	* Industry / Sector							
 	* 1	 Cultivator (Farmer) 						
 	* 2	 Livestock 						
 	* 3	 Fishing / Forestry 						
 	* 4	 Mining & Quarrying 						
 	* 5	 Manufaturing Industry 						
 	* 6	 Manufaturing Industry other than HH 						
 	* 7	 Construction 						
 	* 8	 Trade & Commerce 				
 	* 9	 Transportation and Storage 				
 	* 10	 Communication 				
 	* 11	 Agriculturel Labour 				
 	* 12	 RMG 	
 	* 13	 Shops  	
 	* 14	Service	
 	* 15	Others
 		destring sector_code, replace 
 		replace sector_code = 15 if !inrange(sector_code, 1, 15)


 	* define analysis sample
	 	gen dhuts_sample = !inlist(primary_code,4,5,6) & !inlist(income,0,.)
		tab dhuts_sample, m

*** How many commuters into 
	count if dhuts_sample == 1 & inrange(destination_czone, 1,90)
	count if dhuts_sample == 1 & !inrange(destination_czone, 1,90) & destination_czone != .
	tab destination_czone if dhuts_sample == 1 & !inrange(destination_czone, 1,90) & destination_czone != .

*** How many government workers who otherwise qualify?  11.3%
	tab primary_govt if dhuts_sample == 1, m

	* sample
	drop if destination_czone==.
	drop if destination_czone>90
	drop if destination_czone==0
	drop if origin_czone==.
	drop if origin_czone>90
	drop if origin_czone==0

	tab dhuts_sample, m
	assert inlist(dhuts_sample,0,1)

*** SAVE
	// saveold "data/coded_bgd/coded_dhuts", replace

	gen flow_dhuts = 1 
	gcollapse (sum) flow_dhuts flow_dhuts_sample=dhuts_sample, by(origin_czone destination_czone)

*** SAVE
	save "data_coded_bgd/dhuts/coded_dhuts_czone_pairs", replace
