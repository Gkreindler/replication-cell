suppressWarnings(library(ggplot2))
suppressWarnings(library(dplyr))
suppressWarnings(library(tidyr))
suppressWarnings(library(boot))
suppressWarnings(library(readstata13))
suppressWarnings(library(lfe))
suppressWarnings(library(knitr))
suppressWarnings(library(foreign))
suppressWarnings(library("readxl"))

set.seed(92373247); 

rm(list=ls())


## include functions
source(paste0(Sys.getenv("HOME"), "/Rinit/profile.R"))
setwd(BGDSLKCELLPHONE_DATA) 



## load auxiliary data

## Tower-czone correspondence
tower.BGD <- read.csv(file="data_raw_bgd/other/towers_bgd.csv")
tower.BGD <- tower.BGD %>% 
  rename(lat = latitude, lon = longitude, THAID = thaid)

## hartal and weekend list
hartal_path <- "data_raw_bgd/other/Hartal Data IGC.xlsx"
hartal_list_df <- read_excel(hartal_path, sheet = "Data")
hartal_list_df <- hartal_list_df %>% mutate(date = paste0(Year, "-", Month, "-", Day))
hartal_list <- hartal_list_df$date

weekend_holiday_path <- "data_raw_bgd/other/holiday_list_revised.csv"
weekend_holiday_list_df <- read.csv(weekend_holiday_path)
weekend_holiday_list <- weekend_holiday_list_df$date


## extracts from cell phone data

### date-tower-hour data
tower_user_info_path <- paste("data_raw_bgd/ML/tower_user_info.csv", sep="")
tower_user_info_df <- read.csv(tower_user_info_path)

## minor modification
tower_user_info_df$date_int <- tower_user_info_df$date
tower_user_info_df <- transform(tower_user_info_df, date=as.Date(as.character(date), "%Y%m%d"))
tower_user_info_df$weekday <- as.POSIXlt(tower_user_info_df$date)$wday

## count average duration
tower_user_info_df <- tower_user_info_df %>% 
  mutate(
    avg_duration = ifelse(duration_count > 0, total_duration/duration_count, NA)
  )


## define weekend and weekday data

# eliminate hartal days first
non_hartal_df <- tower_user_info_df[
  sapply(tower_user_info_df$date_int, function(x) !(x %in% hartal_list)), ]

# 0: Sunday, 4: Thursday
weekdays_list <- c(0, 1, 2, 3, 4)
weekday_index <- sapply(
  non_hartal_df$date_int, function(x) !(x %in% weekend_holiday_list)
) & sapply(
  non_hartal_df$weekday, function(x) x %in% weekdays_list
)

weekday_df <- non_hartal_df[weekday_index, ]
weekend_holiday_df <- non_hartal_df[!(weekday_index), ]

## Create covariates by iterating over hours
covariates_df <- NULL
for (h in 0:23) {
  weekday_hour_df <- weekday_df[weekday_df$hour == h, ]
  weekend_holiday_hour_df <- weekend_holiday_df[weekend_holiday_df$hour == h, ]
  
  temp_weekday_df <- weekday_hour_df %>%
    group_by(tower) %>%
    dplyr::summarize(
      totfreq = mean(totfreq, na.rm = TRUE),
      num_unique_users=mean(num_unique_users, na.rm=TRUE), 
      average_home_min=mean(average_home_min, na.rm=TRUE), 
      average_office_min=mean(average_office_min, na.rm=TRUE), 
      average_office_min=mean(total_duration, na.rm=TRUE), 
      home_count=mean(home_count, na.rm=TRUE), 
      office_count=mean(office_count, na.rm=TRUE),
      avg_duration=mean(avg_duration, na.rm=TRUE)
    )
  
  temp_weekend_df <- weekend_holiday_hour_df %>%
    group_by(tower) %>%
    dplyr::summarize(
      totfreq = mean(totfreq, na.rm = TRUE),
      num_unique_users=mean(num_unique_users, na.rm=TRUE), 
      average_home_min=mean(average_home_min, na.rm=TRUE), 
      average_office_min=mean(average_office_min, na.rm=TRUE), 
      average_office_min=mean(total_duration, na.rm=TRUE), 
      home_count=mean(home_count, na.rm=TRUE), 
      office_count=mean(office_count, na.rm=TRUE),
      avg_duration=mean(avg_duration, na.rm=TRUE)
      
    )
  
  temp_weekday_df <- temp_weekday_df %>%
    select(tower, totfreq, num_unique_users, average_home_min, average_office_min, 
           #home_count, office_count, 
           avg_duration) %>% 
    setNames(c(
      "tower", 
      paste("weekday", h, "totfreq", sep="_"), 
      paste("weekday", h, "num_unique_users", sep="_"), 
      paste("weekday", h, "average_home_min", sep="_"), 
      paste("weekday", h, "average_office_min", sep="_"), 
      # paste("weekday", h, "home_count", sep="_"), 
      # paste("weekday", h, "office_count", sep="_"), 
      paste("weekday", h, "avg_duration", sep="_")
      
    ))
  
  temp_weekend_df <- temp_weekend_df %>%
    select(tower, totfreq, num_unique_users, average_home_min, average_office_min, 
           #home_count, office_count, 
           avg_duration) %>% 
    setNames(c(
      "tower", 
      paste("weekend", h, "totfreq", sep="_"), 
      paste("weekend", h, "num_unique_users", sep="_"), 
      paste("weekend", h, "average_home_min", sep="_"), 
      paste("weekend", h, "average_office_min", sep="_"), 
      # paste("weekend", h, "home_count", sep="_"), 
      # paste("weekend", h, "office_count", sep="_"), 
      paste("weekend", h, "avg_duration", sep="_")
      
    ))
  
  if (h == 0) {
    covariates_df <- temp_weekday_df
    covariates_df <- merge(covariates_df, temp_weekend_df, by="tower", all=TRUE)
  } else {
    covariates_df <- merge(covariates_df, temp_weekday_df, by="tower", all=TRUE)
    covariates_df <- merge(covariates_df, temp_weekend_df, by="tower", all=TRUE)
  }
}

rm(temp_weekday_df, temp_weekend_df)



### tower-level data; entropy, gyration, and number of places)
tower_2_path <- paste("data_raw_bgd/ML/tower_entropy.csv", sep="")
tower_2_df <- read.csv(tower_2_path)

## modify unique towers (actual num_unique_towers is num_total_count - num_unique_towers, this is due to miscoding)
tower_2_df <- tower_2_df %>% mutate(num_unique_towers = num_total_count - num_unique_towers)

tower_2_df_temp <- tower_2_df %>% 
  reshape(varying = NULL, timevar = "home_work_dummy", idvar = "Tmax", direction = "wide", sep = "")
tower_2_df_temp <- tower_2_df_temp %>% rename(tower = Tmax)

covariates_df <- covariates_df %>% 
  left_join(tower_2_df_temp, by="tower")

### tower-level area
covariates_df <- covariates_df %>% 
  left_join(tower.BGD %>% select(tower, area_km2) %>% unique(), by="tower")


## add log of all variables
temp <- covariates_df
temp[temp==0] <- NA
covariates_df_log <- log(temp)
covariates_df_log <- covariates_df_log %>% select(-tower)
colnames(covariates_df_log) <- paste0(colnames(covariates_df_log), "_log")

covariates_df <- cbind(covariates_df, covariates_df_log)


saveRDS(covariates_df, "data_coded_bgd/ML/covariates_df_ML.Rds")