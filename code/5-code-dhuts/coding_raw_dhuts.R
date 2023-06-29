# This code: Code raw DHUTS data

### Set-up

suppressWarnings(library(ggplot2))
suppressWarnings(library(dplyr))
suppressWarnings(library(tidyr))
suppressWarnings(library(boot))
suppressWarnings(library(readstata13))
suppressWarnings(library(stargazer))
suppressWarnings(library(lfe))
suppressWarnings(library(knitr))
suppressWarnings(library(geosphere))
suppressWarnings(library(Hmisc))
suppressWarnings(library(pastecs))
suppressWarnings(library(foreign))


set.seed(92373247); 

rm(list=ls())

## include functions
source(paste0(Sys.getenv("HOME"), "/Rinit/profile.R"))
knitr::opts_knit$set(root.dir = BGDSLKCELLPHONE_DATA) 


# load data
## DHUTS
dhuts <- read.csv(file = 'data_raw_bgd/dhuts/s12_1.csv', header=T)

# clean variables
dhuts <- dhuts %>% 
  mutate(
    income = as.numeric(as.character(amount)),
    income_trim = ifelse(income < as.numeric(quantile(income, prob = c(0.99), na.rm=T)), income, NA),
    employed_code = as.numeric(as.character(employed)),
    level_code = as.numeric(as.character(level_code))
  )

# clean primary_code (primary occupation code)
# Occupation	
# 1	 Govt. Service 
# 2	 Private Service 
# 3	 Business 
# 4	 Unemployed 
# 5	 Student 
# 6	 Housewife 
# 7	 Agriculture / farming 
# 8	 Others (Specify) 
table(dhuts$primary_code, useNA="always")
dhuts$primary_code[is.na(dhuts$primary_code)] <- 8
dhuts$primary_govt = dhuts$primary_code == 1


# clean employed code
# Employed		
# 1	 Full time 	
# 2	 Part time 	
# 3	 Casual
# 4	 Unemployed 	
# 5	 Retired 	
# 6	 Other, describe
table(dhuts$employed_code, useNA="always")
dhuts$employed_code[dhuts$employed_code >= 7] <- NA
dhuts$employed_code[dhuts$employed_code == 0] <- NA
dhuts$employed_code[is.na(dhuts$employed_code)] <- 6
table(dhuts$employed_code, useNA="always")

# excluding unemployed, students and homemakers
table(dhuts$employed_code[!(dhuts$primary_code %in% c(4,5,6))], useNA="always")

# How many employed_code = NA have meaningful data?
# View(subset(dhuts, is.na(employed_code) , select=sample_no:employed_code))
sum(!(dhuts$income[is.na(dhuts$employed_code)] %in% c(0,NA))) # only 92 entries

# Include 6=Other! (903 observations with income data)
# View(subset(dhuts, employed_code==6 & !(dhuts$primary_code %in% c(4,5,6)), select=sample_no:employed_code))
sum(dhuts$employed_code==6 & !(dhuts$income %in% c(0,NA)) & !is.na(dhuts$taz_code_office), na.rm=TRUE)     # 711 entries

# Include 5=Retired
# View(subset(dhuts, employed_code==5 & !(dhuts$primary_code %in% c(4,5,6)), select=sample_no:employed_code))
sum(dhuts$employed_code==5 & !(dhuts$income %in% c(0,NA)) & !is.na(dhuts$taz_code_office), na.rm=TRUE)     # 393 entries

# clean "sex" and recode sex = 1 iff female
table(dhuts$sex, useNA="always")
dhuts <- dhuts %>% mutate( 
  male = ifelse(trimws(sex) == "M", 1, ifelse(trimws(sex) == "F", 0, NA)),
  male_missing = is.na(male)
)
table(dhuts$male, useNA="always")
table(dhuts$male_missing, useNA="always")

# clean "years"
# Education Level 			
# 1	 Illiterate 		
# 2	 Primary 		
# 3	 SSC (High School)  		
# 4	 HSC or equivalent 		
# 5	 Graduate 		
# 6	 Post Graduate 		
# 7	 Technical  		
# 8	 Other, describe 		
table(dhuts$years, useNA="always")
dhuts$years_missing = as.numeric(is.na(dhuts$years))


# clean level_code (education level code)
# Education Level 			
# 1	 Illiterate 		
# 2	 Primary 		
# 3	 SSC (High School)  		
# 4	 HSC or equivalent 		
# 5	 Graduate 		
# 6	 Post Graduate 		
# 7	 Technical  		
# 8	 Other, describe 		
table(dhuts$level_code, useNA="always")
dhuts$level_code[!(dhuts$level_code %in% c(1,2,3,4,5,6,7,8))] = 8
table(dhuts$level_code, useNA="always")



# clean sector_code
# Industry / Sector							
# 1	 Cultivator (Farmer) 						
# 2	 Livestock 						
# 3	 Fishing / Forestry 						
# 4	 Mining & Quarrying 						
# 5	 Manufaturing Industry 						
# 6	 Manufaturing Industry other than HH 						
# 7	 Construction 						
# 8	 Trade & Commerce 				
# 9	 Transportation and Storage 				
# 10	 Communication 				
# 11	 Agriculturel Labour 				
# 12	 RMG 	
# 13	 Shops  	
# 14	Service	
# 15	Others	
table(dhuts$sector_code, useNA="always")
dhuts$sector_code[! (dhuts$sector_code %in% 1:15)] = 16

## income range
table(dhuts$amount_code, useNA="always")
# Income Range (Tk/month)	
#  1     Less than 1,500 	
#  2     1,500 to 1,999 	
#  3     2,000 to 2,999 	
#  4     3,000 to 4,999 	
#  5     5,000 to 9,999 	
#  6     10,000 to 29,999 	
#  7     30,000 to 49,999 	
#  8     50,000 to 59,999 	
#  9     60,000 and above 	
dhuts$income_cat = 750
dhuts$income_cat[dhuts$amount_code == 2 ] = 1750
dhuts$income_cat[dhuts$amount_code == 3 ] = 2500
dhuts$income_cat[dhuts$amount_code == 4 ] = 4000
dhuts$income_cat[dhuts$amount_code == 5 ] = 7500
dhuts$income_cat[dhuts$amount_code == 6 ] = 20000
dhuts$income_cat[dhuts$amount_code == 7 ] = 40000
dhuts$income_cat[dhuts$amount_code == 8 ] = 55000
dhuts$income_cat[dhuts$amount_code == 9 ] = 75000
dhuts$income_cat[is.na(dhuts$amount_code)] = NA

plot(x=dhuts$income_cat, y=dhuts$income_trim)

## very similar
# linearMod = lm(income_trim ~ income_cat, data=dhuts)
# stargazer(linearMod, type="text", omit.stat='ser')
# summary(linearMod) 

## Define analysis sample
employment_codes = c(1,2,3)
dhuts$dhuts_sample = !(dhuts$primary_code %in% c(4,5,6)) & !(dhuts$income_trim %in% c(0,NA))

## Print Stats
table(dhuts$dhuts_sample)

sum(!(dhuts$income_trim %in% c(0,NA)), na.rm=TRUE)
sum(!(dhuts$income_trim %in% c(0,NA)) & !(dhuts$primary_code %in% c(4,5,6)) & !is.na(dhuts$taz_code_home) & !is.na(dhuts$taz_code_office), na.rm=TRUE)

sum(dhuts$dhuts_sample == 1 & dhuts$primary_govt == 0 & !is.na(dhuts$taz_code_home) & !is.na(dhuts$taz_code_office), na.rm=TRUE)
sum(dhuts$dhuts_sample == 1 & dhuts$primary_govt == 0 & (dhuts$taz_code_home %in% 1:90) & !is.na(dhuts$taz_code_office), na.rm=TRUE)
sum(dhuts$dhuts_sample == 1 & dhuts$primary_govt == 0 & (dhuts$taz_code_home %in% 1:90) & (dhuts$taz_code_office %in% 1:90), na.rm=TRUE)

table(dhuts$taz_code_home)
unique(dhuts$taz_code_home)

table(dhuts[dhuts$dhuts_sample == 1,]$sex)

# save to file
saveRDS(dhuts,"data_coded_bgd/dhuts/coded_dhuts.rds")
