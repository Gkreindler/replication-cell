
library(readtext)
library(stringi)

unique_id <- function(x, ...) {
  
  # dplyr function to check if column is unique ID
  
  id_set <- x %>% select(...)
  id_set_dist <- id_set %>% distinct
  if (nrow(id_set) == nrow(id_set_dist)) {
    TRUE
  } else {
    non_unique_ids <- id_set %>% 
      filter(id_set %>% duplicated()) %>% 
      distinct()
    suppressMessages(
      inner_join(non_unique_ids, x) %>% arrange(...)
    )
  }
}


############################### .
##### INCOME CODING 

income_coding <- function(commuting, est.gravity, debug=F){
  
  # Compute (model) income measures
  # input: (a) commuting flows, (b) gravity estimates
  # this function 
  #   - keeps the sample of O-D tower pairs with sample_income_coding == 1
  #   - merges the origin and destination FEs from the gravity equation
  #   - creates variables for different income measures (v_ij)
  
  ## Distance coefficient
  tau_coeff = as.numeric(est.gravity$X_beta_log_dur[1])
    #as.numeric(coef(est.gravity)['log(duration_intp)'])
  print("Tau coeff")
  print(tau_coeff)
  print("=========")
  
  ## Fixed effects -- method for PPML
      gravity.dfe <- est.gravity %>% select(destination, DFE) %>% rename(destfe = DFE)
      gravity.dfe <- gravity.dfe %>% mutate(destination = as.numeric(as.character(destination)))

  ## coefficients 
            
  ## sample restriction ##
  if (debug){
    a <- readline(prompt="Check number of missing origin and destination FEs and press any key to continue")
  }
  commuting <- commuting %>% filter(sample_income_coding == 1)
  
  commuting <- commuting %>% select(origin, destination, lat_o, lon_o, lat_d, lon_d, 
                                    km2_tower_d, km2_tower_o, duration_intp, volume, 
                                    contains("origin.czone"), contains("destination.czone"))
  
  # merge estimated fixed effects from the gravity equation
  commuting <- commuting %>%
    left_join(gravity.dfe, by="destination")
  
  # # no missing values (only a single tower)
  missing_d = commuting %>% 
    filter(is.na(destfe)) %>% 
    select(destination) %>% 
    unique() %>% 
    nrow()
  
  print("==================")
  print(paste0("N missing dest FE: ", missing_d))
  print("==================")

  ## Drop observations where the destination fixed effect was not estimated
    commuting <- commuting %>% filter(!is.na(destfe))

  ## Construct income measures
    commuting <- commuting %>% 
      group_by(origin) %>%
      mutate(
        # log duration replacing -Inf by 0 when duration == 0
        # ldurintp = ifelse(duration_intp == 0, NA, log(duration_intp)),
        ldurintp = ifelse(duration_intp < 180, log(180), log(duration_intp)),
        
        # z and d both productive
        logy.v11     = log(sum(exp(destfe                     + tau_coeff * ldurintp), na.rm=T)),
        logy.v11.adj = log(sum(exp(destfe  - log(km2_tower_d) + tau_coeff * ldurintp), na.rm=T))
      )  %>%
      ungroup() %>%
      mutate(
        ldurintp = ifelse(duration_intp < 180, log(180), log(duration_intp)),
        
        # z and d neither productive
        logy.v00     = destfe,
        logy.v00.adj = destfe - log(km2_tower_d),
        
        # d only productive
        logy.v01     = destfe                    + tau_coeff * ldurintp,
        logy.v01.adj = destfe - log(km2_tower_d) + tau_coeff * ldurintp,
        
        # z only productive
        logy.v10     = logy.v11     - tau_coeff * ldurintp,
        logy.v10.adj = logy.v11.adj - tau_coeff * ldurintp
      )
  
  commuting
}

############################### .
##### COLLAPSE CZONE LEVEL


collapse_czone <- function(commuting.BGD, czone, dhuts){
  
  ## Merge cell phone data with DHUTS and collapse income measures at czone x czone level
  
  commuting.BGD.czone <- commuting.BGD %>% 
    
    filter(sample_income_czone == 1) %>%

    # add other czones from 1:90 as "0"    
    mutate(
      origin.czone = ifelse(is.na(origin.czone), 0, origin.czone),
      destination.czone = ifelse(is.na(destination.czone), 0, destination.czone)
    ) %>% 
    
    group_by(origin.czone, destination.czone) %>% 
    
    # take weighted average
    dplyr::summarize(
      logy.v00.wm = weighted.mean(logy.v00, w=volume, na.rm=T),
      logy.v01.wm = weighted.mean(logy.v01, w=volume, na.rm=T),
      logy.v11.wm = weighted.mean(logy.v11, w=volume, na.rm=T),
      logy.v10.wm = weighted.mean(logy.v10, w=volume, na.rm=T),
      
      logy.v00.wm.adj = weighted.mean(logy.v00.adj, w=volume, na.rm=T),
      logy.v01.wm.adj = weighted.mean(logy.v01.adj, w=volume, na.rm=T),
      logy.v11.wm.adj = weighted.mean(logy.v11.adj, w=volume, na.rm=T),
      logy.v10.wm.adj = weighted.mean(logy.v10.adj, w=volume, na.rm=T),
      
      log_km2_d.wm =  weighted.mean(log(km2_tower_d), w=volume, na.rm=T),
      log_km2_o.wm =  weighted.mean(log(km2_tower_o), w=volume, na.rm=T),
      
      # log duration bounded from below (otherwise get -Infty when using full sample)
      # lduration_intp     = weighted.mean(log(duration_intp), w=volume, na.rm=T),
      lduration_intp = weighted.mean(ldurintp, w=volume, na.rm=T),
      
      merge = 1
    )
  
  ## Merge income data in the DHUTS data
  czone_orig <- czone %>% select(czone, area.czone, meandistC.czone) %>% 
                rename(origin.czone = czone, 
                       area.czone.o = area.czone, 
                       meandistC.czone.o = meandistC.czone)
  czone_dest <- czone %>% select(czone, area.czone, meandistC.czone) %>% 
                rename(destination.czone = czone, 
                       area.czone.d = area.czone, 
                       meandistC.czone.d = meandistC.czone)
  
  # no longer necessary
  # rename(dhuts, 
  #        origin.czone = taz_code_home, 
  #        destination.czone = taz_code_office)
  
  dhuts.gravityresult <- dhuts %>% 
    # code czones not from 1:90 as "0"
    mutate(origin.czone      = ifelse(is.na(origin.czone)      |      origin.czone > 90, 0, origin.czone),
           destination.czone = ifelse(is.na(destination.czone) | destination.czone > 90, 0, destination.czone)) %>% 
    left_join(commuting.BGD.czone, by=c("origin.czone", "destination.czone")) 
  
  join_outcome <- dhuts.gravityresult %>% 
    mutate(
      merge = ifelse(is.na(merge), 0, merge)
    ) %>%
    summarise( 
      merged = sum(merge),
      not_merged = sum(1-merge))
  
  print(join_outcome)
  # stopifnot(join_outcome$not_merged <= 3)
    
  # check no missing values
  # stopifnot(dhuts.gravityresult %>% filter(is.na(logy.v00.wm)) %>% nrow() <= 3)
  dhuts.gravityresult <- dhuts.gravityresult %>% filter(!is.na(logy.v00.wm)) 
  
  # only keep origin and destination czones within DCC
  dhuts.gravityresult <- dhuts.gravityresult %>%
                         filter(origin.czone != 0 & destination.czone != 0)
  
  # Return
  dhuts.gravityresult
  
}

############################### .
##### RESIDENTIAL INCOME CODING 

# For nighttime lights: compute residential income and merge it to viirs
residential_income_coding <- function(commuting, est.gravity, viirs, epsilon = 6){
  
  # our main measure is the empirical average of area-adjusted destination FEs
  #   weighting by commuting volume
  # 
  # res.meanlogy.v00 is:
  #   AVERAGE log(wage_j) over all possible destinations j, weighed by volume
  
  # sample restriction
  commuting <- commuting %>% filter(sample_income_coding == 1)

  
  # generate income measures
  commuting.y <- income_coding(commuting, est.gravity)

  ## compute destination wages
  commuting.y.destination <- commuting.y %>%
    group_by(destination, km2_tower_d, logy.v00, logy.v00.adj, destfe) %>%
    summarise(
      volume.destination=sum(volume, na.rm=T)
    ) %>% ungroup()
  
  ## compute residential income
  commuting.y.origin <- commuting.y %>%
    group_by(origin, km2_tower_o) %>%
    summarise(
      
      res.totaly.v00     = sum(exp(logy.v00    /epsilon) * volume, na.rm=T),
      res.totaly.v00.adj = sum(exp(logy.v00.adj/epsilon) * volume, na.rm=T),
      res.meanlogy.v00     = weighted.mean(logy.v00    , w= volume, na.rm=T),
      res.meanlogy.v00.adj = weighted.mean(logy.v00.adj, w= volume, na.rm=T),
      volume.origin=sum(volume, na.rm=T)
    ) %>% ungroup() %>% 
    mutate(
      res.logy.v00     = log(res.totaly.v00    /volume.origin),
      res.logy.v00.adj = log(res.totaly.v00.adj/volume.origin),
      res.logy.v00.perarea     = log(res.totaly.v00    /km2_tower_o),
      res.logy.v00.adj.perarea = log(res.totaly.v00.adj/km2_tower_o)
    )
  
  commuting.y.destination <- commuting.y.destination %>% 
              rename(tower = destination) %>%
              left_join(commuting.y.origin %>% rename(tower = origin), by='tower')
  
  if(length(commuting.y.destination$tower) != length(unique(commuting.y.destination$tower))) break

  ## combine datasets
  viirs <- viirs %>% 
    left_join(commuting.y.destination, by='tower')
  
  # how many missing values?
  print("Missing values due to res.meanlogy.v00:")
  print(viirs %>% filter(is.na(res.meanlogy.v00)) %>% nrow())
  
  viirs
  
}
