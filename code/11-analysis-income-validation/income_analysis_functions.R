
library(readtext)
library(stringi)


## Change regression results to Conley SE
# @@@@@@@@@@@@ If weighted regression, include these variables in the main formula (not as fixed effects!!!!!) @@@@@@@@@@@@
appendConleySEs <- function(reg = reg, unit = "unit", dist_cutoff=5) {
  out = ConleySEs(reg = reg,
                  unit = unit,#"unit",
                  time = "time",
                  noFE = T, 
                  lat = "lat", lon = "lon",
                  dist_fn = "SH", dist_cutoff = dist_cutoff,
                  lag_cutoff = 5,
                  cores = 1,
                  verbose = FALSE)
  
  out <- sapply(out, function(x) diag(sqrt(x))) %>% round(3)
  
  # update regression results
  reg.new <- reg
  
  # update standard error
  # need to divide into one regressor and multiple regressors 
  if(ncol(as.matrix(out))==1){
    reg.new$cse <- out[2]
  } else{
    reg.new$cse <- out[,2]
  }
  
  
  # update p-val (just for stars)
  star <- ifelse(abs(reg.new$coefficients) - 2.57*abs(reg.new$cse) >0, 1, 0)
  star <- star + ifelse(abs(reg.new$coefficients) - 1.96*abs(reg.new$cse) >0, 1, 0)
  star <- star + ifelse(abs(reg.new$coefficients) - 1.64*abs(reg.new$cse) >0, 1, 0)
  pval.new <- ifelse(star == 3 , 0.002, 0.2)
  pval.new <- ifelse(star == 2 , 0.02, pval.new)
  pval.new <- ifelse(star == 1, 0.07, pval.new)
  
  reg.new$cpval <- pval.new
  
  reg.new
}



sample_n_groups = function(tbl, size, replace = FALSE, weight = NULL) {
  ## from: https://github.com/tidyverse/dplyr/issues/361
  # regroup when done
  grps = tbl %>% groups %>% lapply(as.character) %>% unlist
  # check length of groups non-zero
  keep = tbl %>% summarise() %>% ungroup() %>% sample_n(size, replace, weight)
  # keep only selected groups, regroup because joins change count.
  # regrouping may be unnecessary but joins do something funky to grouping variable
  tbl %>% right_join(keep, by=grps) %>% group_by_(.dots = grps)
}

############################### .
##### Reduced form regressions (individual level)

rf_regressions <- function(dhuts.y, dist_cutoff = 5, outfile=""){
  ## reduced form regressions at the individual level
  
  dhuts.y <- dhuts.y %>% 
    mutate(
      logincome_trim = log(income_trim),
      const = 1,
      unit = 1, time = 1
    ) %>% 
    left_join(czone %>% rename(destination.czone = czone), by='destination.czone') %>%
    filter(dhuts_sample_rf == 1)
    
  
  ## simple 
    est_1 <- felm(log(income_trim) ~ mean.logy.v00.adj.origdest | unit + time | 0| origin.czone + destination.czone , 
                  data=filter(dhuts.y, dhuts_sample_rf == 1 &  primary_govt == 0), keepCX=T)
  
  ## some controls
    # first, residualize log income with respect to fixed effects
    est.temp <- felm(log(income_trim) ~ 0 | origin.czone |0|0, 
                     data=filter(dhuts.y, primary_govt == 0))
    
    # merge residuals
    data.temp.4  <- cbind(filter(dhuts.y,  primary_govt == 0), data.frame(residuals(est.temp))
                          %>% rename(log.income_trim.r = log.income_trim.))
    
    # run
    est_4a <- felm(log.income_trim.r ~ 
                    mean.logy.v00.adj.origdest + lduration_intp  + log(meandistC.czone.d) + 
                    log(area.czone.d), data=data.temp.4, keepCX=T)
    
    est_4 <- felm(log(income_trim) ~ 
                    mean.logy.v00.adj.origdest + lduration_intp  + log(meandistC.czone.d) + 
                    log(area.czone.d) | origin.czone | 0 | 
                    origin.czone + destination.czone , 
                  data=filter(dhuts.y, dhuts_sample_rf == 1, primary_govt == 0), keepCX=T)
    
  ## some controls, with government 
    # first, residualize log income with respect to fixed effects
    est.temp <- felm(log(income_trim) ~ 0 | origin.czone |0|0, 
                     data=dhuts.y)
    
    # merge residuals
    data.temp.5  <- cbind(filter(dhuts.y), data.frame(residuals(est.temp))
                          %>% rename(log.income_trim.r = log.income_trim.))
    
    # run
    est_5a <- felm(log.income_trim.r ~ 
                     mean.logy.v00.adj.origdest + lduration_intp  + log(meandistC.czone.d) + 
                     log(area.czone.d) , data=data.temp.5, keepCX=T)
    
    est_5 <- felm(log(income_trim) ~ 
                    mean.logy.v00.adj.origdest + lduration_intp  + log(meandistC.czone.d) + 
                    log(area.czone.d) | origin.czone | 0 | 
                    origin.czone + destination.czone , 
                  data=filter(dhuts.y, dhuts_sample_rf == 1), keepCX=T)
    
    
  ## more controls
    # first, residualize log income with respect to fixed effects
    est.temp <- felm(log(income_trim) ~ 0 | years_missing + origin.czone + primary_code + sector_code |0|0, 
                     data=dhuts.y)
    
    # merge residuals
    data.temp.7  <- cbind(dhuts.y, data.frame(residuals(est.temp))
                        %>% rename(log.income_trim.r = log.income_trim.))
    
    est_7a <- felm(log.income_trim.r ~ 
                    mean.logy.v00.adj.origdest + lduration_intp  + log(meandistC.czone.d) + 
                    log(area.czone.d)  + male + years + level_code | 0 |0 | 
                     origin.czone + destination.czone, 
                  data=data.temp.7, keepCX=T)
    
    est_7 <- felm(log(income_trim) ~ 
                    mean.logy.v00.adj.origdest + lduration_intp  + log(meandistC.czone.d) + 
                    log(area.czone.d)  + male + years + level_code | 
                    years_missing + origin.czone + primary_code + sector_code | 
                    0 | 
                    origin.czone + destination.czone, 
                  data=filter(dhuts.y, dhuts_sample_rf == 1), keepCX=T)
    
    stargazer(est_4a, est_4, est_7a, est_7, type="text")
    # stargazer(est_1, est_4, est_7, type="text")
    
    # Conley Standard errors are too slow
    # lat + lon
    est_1 <- felm(log(income_trim) ~ 
                    mean.logy.v00.adj.origdest | unit + time | 0 | lat + lon , 
                  data=filter(dhuts.y, primary_govt == 0), keepCX=T)
    
    # already residualized: as.factor(origin.czone)
    est_4 <- felm(log.income_trim.r ~ 
                    mean.logy.v00.adj.origdest + lduration_intp  + log(meandistC.czone.d) + 
                    log(area.czone.d)  | 
                    unit + time | 0| lat + lon , 
                  data=data.temp.4, keepCX=T)
    
    est_5 <- felm(log.income_trim.r ~ 
                    mean.logy.v00.adj.origdest + lduration_intp  + log(meandistC.czone.d) + 
                    log(area.czone.d)  | 
                    unit + time | 0| lat + lon , 
                  data=data.temp.5, keepCX=T)
    
    
    # already residualized: years_missing + origin.czone + primary_code + sector_code
    #   years_missing + as.factor(origin.czone) + as.factor(sector_code) 
    #   + as.factor(primary_code)
    est_7 <- felm(log.income_trim.r ~ 
                    mean.logy.v00.adj.origdest + lduration_intp  + log(meandistC.czone.d) + 
                    log(area.czone.d)  + male + years + level_code | 
                    unit + time | 0 | lat + lon, 
                  data=data.temp.7, keepCX=T)
    
    # <- error if include in last spec (+ as.factor(primary_code) )
    
    est_1 <- appendConleySEs(est_1, dist_cutoff = dist_cutoff)
    print("Conley 1 done")

    est_4 <- appendConleySEs(est_4, dist_cutoff = dist_cutoff, verbose=T)
    print("Conley 4 done")
    
    est_5 <- appendConleySEs(est_5, dist_cutoff = dist_cutoff, verbose=T)
    print("Conley 5 done")

    est_7 <- appendConleySEs(est_7, dist_cutoff = dist_cutoff)
    print("Conley 7 done")
    
    if(outfile != ""){
      # print to file TEX
      # "log Dest. Area (weighted)", 
      output <- capture.output(
        stargazer(est_1, est_4, est_5, est_7,  omit.stat=c('rsq', 'ser'),
          covariate.labels = c("Model log Income (workplace)", "log Travel Time", 
                               "log Dest. Dist. to CBD",
                               "log Dest. Commuting Zone Area", 
                               "Male","Age", "Level of education"),
          dep.var.labels.include = FALSE, dep.var.caption = "",
          column.labels = 'log Survey Income', column.separate = c(3),
          omit.table.layout = "n", digits = 2,
          add.lines = list(c("Origin FE", "", "X", "X", "X"),
                           c("Occupation and Sector FE", "", "", "", "X"),
                           c("Government Worker", "No", "No", "Yes", "Yes")),
          omit = c("Constant"), type="latex", float = F, out=outfile, sep="")
      )

      # add resizebox, and drop hline commands // , 
      edit_tex_file(texfile=outfile, add_resize="{0.7\\textwidth}{!}{", drop_hline=T)
    }
    
    output <- stargazer(est_1, est_4, est_5, est_7, type='text', omit.stat=c('rsq', 'ser'),
              dep.var.labels   = "log Survey Income",
              covariate.labels = c("Model log Income", "log Travel Time", 
                                   "log Dest. Dist. to CBD",
                                   "log Dest. Commuting Zone Area", 
                                   "Male","Age", "Level of education", "Government job"),
              add.lines = list(c("Origin FE", "", "X", "X", "X"),
                               c("Occupation and Sector FE", "", "", "", "X"),
                               c("Government Worker", "No", "No", "Yes", "Yes")),
              omit = c("Constant"))
}

############################### .
##### R2 regressions

r2_regressions <- function(dhuts.y.dest, dist_cutoff=5, dhuts.w=1, outfile="", outfile_resid=""){
  
  # create 
  if (dhuts.w == 1){
    dhuts.y.dest <- dhuts.y.dest %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.cell_weight,
      mean.logy.dhuts.r = mean.logy.dhuts.cell_weight.r
    )}
  if (dhuts.w == 2){
    dhuts.y.dest <- dhuts.y.dest %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.census_weight, 
      mean.logy.dhuts.r = mean.logy.dhuts.census_weight.r
    )}
  if (dhuts.w == 3){
    dhuts.y.dest <- dhuts.y.dest %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.no_weight,
      mean.logy.dhuts.r = mean.logy.dhuts.no_weight.r
    )}
  
  # restrict to sample
  dhuts.y.dest <- dhuts.y.dest %>% filter(r2_sample == 1)
  
  ## Original Income:
  est1 <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                      dep = "mean.logy.dhuts", 
                                      indep = "mean.logy.v00.adj.dest", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2 <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                      dep = "mean.logy.dhuts", 
                                      indep = "ldensity.cell.hw.employment", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est3 <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                      dep = "mean.logy.dhuts", 
                                      indep = "logmeandistC.czone.d", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est4 <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                      dep = "mean.logy.dhuts", 
                                      indep = c("mean.logy.v00.adj.dest", 
                                                "ldensity.cell.hw.employment", 
                                                "logmeandistC.czone.d"), 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est5 <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                      dep = "mean.logy.dhuts", 
                                      indep = c("mean.logy.v00.adj.dest", 
                                                "ldensity.cell.hw.employment", 
                                                "logmeandistC.czone.d", 
                                                "mean.logy.v00.adj.orig"), 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)

  
  ## Residual Income:
  est1.r <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                        dep = "mean.logy.dhuts.r", 
                                        indep = "mean.logy.v00.adj.dest", 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.r <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                        dep = "mean.logy.dhuts.r", 
                                        indep = "ldensity.cell.hw.employment", 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est3.r <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                        dep = "mean.logy.dhuts.r", 
                                        indep = "logmeandistC.czone.d", 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est4.r <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                        dep = "mean.logy.dhuts.r", 
                                        indep = c("mean.logy.v00.adj.dest", 
                                                  "ldensity.cell.hw.employment", 
                                                  "logmeandistC.czone.d"), 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est5.r <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                        dep = "mean.logy.dhuts.r", 
                                        indep = c("mean.logy.v00.adj.dest", 
                                                  "ldensity.cell.hw.employment", 
                                                  "logmeandistC.czone.d", 
                                                  "mean.logy.v00.adj.orig"), 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  
  # adjusted R2 from weighted regression
  r2       <- c("Adjusted R2", round(  est1$adj.rsq, 2), round(  est2$adj.rsq, 2), round(  est3$adj.rsq, 2), round(  est4$adj.rsq, 2), round(  est5$adj.rsq, 2))
  r2_resid <- c("Adjusted R2", round(est1.r$adj.rsq, 2), round(est2.r$adj.rsq, 2), round(est3.r$adj.rsq, 2), round(est4.r$adj.rsq, 2), round(est5.r$adj.rsq, 2))
  RMSE     <- c("Root Mean Squared Error", round(  est1$RMSE, 2), round(  est2$RMSE, 2), round(  est3$RMSE, 2), round(  est4$RMSE, 2), round(  est5$RMSE, 2))
  RMSE_resid <- c("Root Mean Squared Error", round(  est1$RMSE, 2), round(  est2$RMSE, 2), round(  est3$RMSE, 2), round(  est4$RMSE, 2), round(  est5$RMSE, 2))
  
  
  print("############### MAIN REGRESSION #################")
  
  stargazer(est1, est2, est3, est4, est5,  omit.stat=c('rsq', 'ser', 'adj.rsq'),
            dep.var.labels = 'log Survey Income',
            dep.var.caption = "",
            covariate.labels = c('log Model Income (workplace)', 'log Employment Density', 'log Dist. to CBD'),
            omit.table.layout = "n",
            digits = 2,
            omit = c("Constant", "sqrt_weight"),
            add.lines = list(r2, RMSE),
            type="text", float = F, sep="")
  
  stargazer(est1.r, est2.r, est3.r, est4.r, est5.r,  omit.stat=c('rsq', 'ser', 'adj.rsq'),
            dep.var.labels = 'log Survey Income (Residual)',
            dep.var.caption = "",
            covariate.labels = c('log Model Income (workplace)', 'log Employment Density', 'log Dist. to CBD'),
            omit.table.layout = "n",
            digits = 2,
            omit = c("Constant", "sqrt_weight"),
            add.lines = list(r2_resid, RMSE_resid),
            type="text", float = F, sep="")
  
  
  if(outfile != "" & outfile_resid != ""){
    
    # original income regression
        # print to file TEX
        output <- capture.output(
          stargazer(est1, est2, est3, est4, est5,  omit.stat=c('rsq', 'ser', 'adj.rsq'),
                    dep.var.labels = 'log Survey Income (workplace)',
                    dep.var.caption = "",
                    covariate.labels = c(' $\\epsilon \\times $ log Model Income (workplace)', 'log Employment Density', 
                                         'log Dist. to CBD', ' $\\epsilon \\times $log Model Income (residential)'),
                    omit.table.layout = "n",
                    out = outfile,
                    digits = 2,
                    omit = c("Constant", "sqrt_weight"),
                    add.lines = list(r2, RMSE),
                    type="latex", float = F, sep="")
        )
      # add resizebox, and drop hline commands
      edit_tex_file(texfile=outfile, drop_hline=T) #add_resize="{1\\textwidth}{!}{", 
    
    # residual income regression
      output <- capture.output(
        stargazer(est1.r, est2.r, est3.r, est4.r, est5.r, omit.stat=c('rsq', 'ser', 'adj.rsq'),
                  dep.var.labels = 'log Survey Income (workplace, residual)',
                  dep.var.caption = "",
                  covariate.labels = c(' $\\epsilon \\times $log Model Income (workplace)', 'log Employment Density', 
                                       'log Dist. to CBD', ' $\\epsilon \\times $ log Model Income (residential)'),
                  omit.table.layout = "n",
                  out = outfile_resid,
                  digits = 2,
                  omit = c("Constant", "sqrt_weight"),
                  add.lines = list(r2_resid, RMSE_resid),
                  type="latex", float = F, sep="")
      )
      
      # add resizebox, and drop hline commands
      edit_tex_file(texfile=outfile_resid, drop_hline=T) #add_resize="{1\\textwidth}{!}{", 
      
  }
  
}


r2_regressions_4ver_pref_prod <- function(dhuts.y.dest, dist_cutoff=5, dhuts.w=1, outfile=""){
  
  # create 
  if (dhuts.w == 1){
    dhuts.y.dest <- dhuts.y.dest %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.cell_weight,
      mean.logy.dhuts.r = mean.logy.dhuts.cell_weight.r
    )}
  if (dhuts.w == 2){
    dhuts.y.dest <- dhuts.y.dest %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.census_weight, 
      mean.logy.dhuts.r = mean.logy.dhuts.census_weight.r
    )}
  if (dhuts.w == 3){
    dhuts.y.dest <- dhuts.y.dest %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.no_weight,
      mean.logy.dhuts.r = mean.logy.dhuts.no_weight.r
    )}
  
  # restrict to sample
  dhuts.y.dest <- dhuts.y.dest %>% filter(r2_sample == 1)
  
  # ## v
  # z and d neither productive
  dhuts.y.dest <- dhuts.y.dest %>% mutate(model_income = mean.logy.v00.adj.dest)
  est1 <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                      dep = "mean.logy.dhuts", 
                                      indep = "model_income", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)

  # z and d both productive
  dhuts.y.dest <- dhuts.y.dest %>% mutate(model_income = mean.logy.v11.adj.dest)
  est2 <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                      dep = "mean.logy.dhuts", 
                                      indep = "model_income", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  # z only productive
  dhuts.y.dest <- dhuts.y.dest %>% mutate(model_income = mean.logy.v10.adj.dest)
  est3 <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                      dep = "mean.logy.dhuts", 
                                      indep = "model_income", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  # d only productive
  dhuts.y.dest <- dhuts.y.dest %>% mutate(model_income = mean.logy.v01.adj.dest)
  est4 <- weighted_felm_with_ConleySE(data= dhuts.y.dest, 
                                      dep = "mean.logy.dhuts", 
                                      indep = "model_income", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  
  
  # adjusted R2 from weighted regression
  prod     <- c("$Z_{ij\\omega}$", "Preference", "Income", "Income", "Preference")
  pref     <- c("$D_{ij}$",        "Preference", "Income", "Preference", "Income")
  
  r2       <- c("Adjusted R2", round(  est1$adj.rsq, 2), round(  est2$adj.rsq, 2), round(  est3$adj.rsq, 2), round(  est4$adj.rsq, 2))
  RMSE     <- c("Root Mean Squared Error", round(  est1$RMSE, 2), round(  est2$RMSE, 2), round(  est3$RMSE, 2), round(  est4$RMSE, 2))

  
  print("############### MAIN REGRESSION #################")
  
  stargazer(est1, est2, est3, est4,  omit.stat=c('rsq', 'ser', 'adj.rsq'),
            dep.var.labels = 'log Survey Income',
            dep.var.caption = "",
            covariate.labels = c('log Model Income (workplace)'),
            omit.table.layout = "n",
            digits = 2,
            omit = c("Constant", "sqrt_weight"),
            add.lines = list(prod, pref, c(""), r2, RMSE),
            type="text", float = F, sep="")

  
  if(outfile != ""){
    
    # original income regression
    # print to file TEX
    output <- capture.output(
      stargazer(est1, est2, est3, est4,  omit.stat=c('rsq', 'ser', 'adj.rsq'),
                dep.var.labels = 'log Survey Income (workplace)',
                dep.var.caption = "",
                covariate.labels = c(' $\\epsilon \\times $ log Model Income (workplace)'),
                omit.table.layout = "n",
                out = outfile,
                digits = 2,
                omit = c("Constant", "sqrt_weight"),
                add.lines = list(prod, pref, c(""), r2, RMSE),
                type="latex", float = F, sep="")
    )
    # add resizebox, and drop hline commands
    edit_tex_file(texfile=outfile, drop_hline=T) #add_resize="{1\\textwidth}{!}{", 

  }
  
}



############################### .
##### R2 regressions - ORIGIN LEVEL

r2_regressions_origin <- function(dhuts.y.orig, 
                                  dist_cutoff=5, outfile="", outfile_resid= ""){
  
  ## Original Income:
  est1 <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                      dep = "mean.logy.dhuts.orig", 
                                      indep = "mean.logy.v00.adj.orig", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2 <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                      dep = "mean.logy.dhuts.orig", 
                                      indep = "ldensity.cell.resident", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est3 <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                      dep = "mean.logy.dhuts.orig", 
                                      indep = "logmeandistC.czone.o", 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est4 <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                      dep = "mean.logy.dhuts.orig", 
                                      indep = c("mean.logy.v00.adj.orig", 
                                                "ldensity.cell.resident", 
                                                "logmeandistC.czone.o"), 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est5 <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                      dep = "mean.logy.dhuts.orig", 
                                      indep = c("mean.logy.v00.adj.orig", 
                                                "ldensity.cell.resident", 
                                                "logmeandistC.czone.o", 
                                                "mean.logy.v00.adj.dest"), 
                                      weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  ## Residual Income:
  est1.r <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                        dep = "mean.logy.dhuts.orig.r", 
                                        indep = "mean.logy.v00.adj.orig", 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.r <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                        dep = "mean.logy.dhuts.orig.r", 
                                        indep = "ldensity.cell.resident", 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est3.r <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                        dep = "mean.logy.dhuts.orig.r", 
                                        indep = "logmeandistC.czone.o", 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est4.r <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                        dep = "mean.logy.dhuts.orig.r", 
                                        indep = c("mean.logy.v00.adj.orig", 
                                                  "ldensity.cell.resident", 
                                                  "logmeandistC.czone.o"), 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est5.r <- weighted_felm_with_ConleySE(data= dhuts.y.orig,
                                        dep = "mean.logy.dhuts.orig.r", 
                                        indep = c("mean.logy.v00.adj.orig", 
                                                  "ldensity.cell.resident", 
                                                  "logmeandistC.czone.o", 
                                                  "mean.logy.v00.adj.dest"), 
                                        weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  r2 <- c("Adjusted R2",
          round(est1$adj.rsq, 2), round(est2$adj.rsq, 2), round(est3$adj.rsq, 2), round(est4$adj.rsq, 2), round(est5$adj.rsq, 2))
  r2_resid <- c("Adjusted R2",
                round(est1.r$adj.rsq, 2), round(est2.r$adj.rsq, 2), round(est3.r$adj.rsq, 2), round(est4.r$adj.rsq, 2), round(est5.r$adj.rsq, 2))
  
  print(r2)
  
  if(outfile != "" & outfile_resid != ""){
    # print to file TEX
    
    # "log Dest. Area (weighted)", 
    output <- capture.output(
      stargazer(est1, est2, est3, est4, est5,  
                omit.stat=c('adj.rsq', 'rsq', 'ser'),
                dep.var.labels = c('log Survey Income (residential)'),
                dep.var.caption = "",
                covariate.labels = c('log Model Income (residential)', 
                                     'log Residential Density', 
                                     'log Dist. to CBD', 
                                     'log Model Income (workplace)'),
                omit.table.layout = "n",
                out = outfile,
                digits = 2,
                omit = c("Constant", "sqrt_weight"), type="latex", float = F, sep="",
                add.lines=list(r2)))
    
    # add resizebox, and drop hline commands
    edit_tex_file(texfile=outfile,  drop_hline=T) #add_resize="{1\\textwidth}{!}{",
    
    # print to file TEX
   
    output <- capture.output(
      stargazer(est1.r, est2.r, est3.r, est4.r, est5.r,   
                omit.stat=c('adj.rsq', 'rsq', 'ser'),
                dep.var.labels = c('log Survey Income (Residual)'),
                dep.var.caption = "",
                covariate.labels = c('log Model Income (residential)', 
                                     'log Residential Density', 
                                     'log Dist. to CBD', 
                                     'log Model Income (workplace)'),
                omit.table.layout = "n",
                out = outfile_resid,
                digits = 2,
                omit = c("Constant", "sqrt_weight"), type="latex", float = F, sep="",
                add.lines=list(r2_resid)))
    
    # add resizebox, and drop hline commands
    edit_tex_file(texfile=outfile_resid,  drop_hline=T) #add_resize="{1\\textwidth}{!}{",
    
    
  }
  
  print("############### Robustness: origin level #################")
  
  stargazer(est1, est2, est3, est4, est5, 
            est1.r, est2.r, est3.r, est4.r, est5.r,  
            omit.stat=c('rsq', 'ser', 'adj.rsq'),
            #dep.var.labels = c('log Survey Income', 'log Survey Income (Residual)'),
            dep.var.caption = "",
            #covariate.labels = c('log Model Income (residential)', 'log Dist. to CBD'),
            omit.table.layout = "n",
            digits = 2,
            omit = c("sqrt_weight", "Constant"), type="text", float = F, sep="",
            add.lines=list(c(r2, r2_resid)))
}


############################### .
##### R2 regressions - robustness

r2_regressions_robust <- function(dhuts.y.dest.hw, 
                                  dhuts.y.dest.exclnb, 
                                  dhuts.y.dest, 
                                  dhuts.y.dest.allo, 
                                  dhuts.w=1, dist_cutoff=5, outfile_stub=""){

  # now  = no weights
  # cell = origin czone weighted by (residential) population from cell phone
  # cen  = origin czone weighted by (residential) population from census

  if (dhuts.w == 1){
    dhuts.y.dest <- dhuts.y.dest %>% mutate(
      mean.logy.dhuts   = mean.logy.cell,
      mean.logy.dhuts.r = mean.logy.cell.r)
    
    dhuts.y.dest.hw <- dhuts.y.dest.hw %>% mutate(
      mean.logy.dhuts   = mean.logy.cell,
      mean.logy.dhuts.r = mean.logy.cell.r)
    
    dhuts.y.dest.exclnb  <- dhuts.y.dest.exclnb %>% mutate(
      mean.logy.dhuts   = mean.logy.cell,
      mean.logy.dhuts.r = mean.logy.cell.r)
    
    dhuts.y.dest.allo <- dhuts.y.dest.allo %>% mutate(
      mean.logy.dhuts   = mean.logy.cell,
      mean.logy.dhuts.r = mean.logy.cell.r)
  }
  if (dhuts.w == 2){
    dhuts.y.dest <- dhuts.y.dest %>% mutate(
      mean.logy.dhuts   =  mean.logy.cen,
      mean.logy.dhuts.r = mean.logy.cen.r)

    dhuts.y.dest.hw <- dhuts.y.dest.hw %>% mutate(
      mean.logy.dhuts   = mean.logy.cen,
      mean.logy.dhuts.r = mean.logy.cen.r)
    
    dhuts.y.dest.exclnb  <- dhuts.y.dest.exclnb %>% mutate(
      mean.logy.dhuts   = mean.logy.cen,
      mean.logy.dhuts.r = mean.logy.cen.r)
    
    dhuts.y.dest.allo <- dhuts.y.dest.allo %>% mutate(
      mean.logy.dhuts   = mean.logy.cen,
      mean.logy.dhuts.r = mean.logy.cen.r)
  }
  if (dhuts.w == 3){
    dhuts.y.dest <- dhuts.y.dest %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.no_weight,
      mean.logy.dhuts.r = mean.logy.dhuts.no_weight.r)
 
    dhuts.y.dest.hw <- dhuts.y.dest.hw %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.no_weight,
      mean.logy.dhuts.r = mean.logy.dhuts.no_weight.r)
    
    dhuts.y.dest.exclnb  <- dhuts.y.dest.exclnb %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.no_weight,
      mean.logy.dhuts.r = mean.logy.dhuts.no_weight.r)
    
    dhuts.y.dest.allo <- dhuts.y.dest.allo %>% mutate(
      mean.logy.dhuts   = mean.logy.dhuts.no_weight,
      mean.logy.dhuts.r = mean.logy.dhuts.no_weight.r)
  }
  
  # no area adjustment data -- overwrite mean.logy.v00.adj.dest
  #   with the unadjusted version, so that the latex table looks nice
  dhuts.y.dest.hw.noarea <- dhuts.y.dest.hw %>% mutate(
    mean.logy.v00.adj.dest = mean.logy.v00.dest
  )
  

  ## Daily Flows
  ## Original Income:
  est1.daily   <- weighted_felm_with_ConleySE(data= dhuts.y.dest,
                                           dep = "mean.logy.dhuts", 
                                           indep = "mean.logy.v00.adj.dest",
                                           weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.daily   <- weighted_felm_with_ConleySE(data= dhuts.y.dest,
                                           dep = "mean.logy.dhuts", 
                                           indep = c("mean.logy.v00.adj.dest", 
                                                     "ldensity.cell.hw.employment", 
                                                     "logmeandistC.czone.d", 
                                                     "mean.logy.v00.adj.orig"),
                                           weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  ## Residual Income:
  est1.daily.r   <- weighted_felm_with_ConleySE(data= dhuts.y.dest,
                                             dep = "mean.logy.dhuts.r", 
                                             indep = "mean.logy.v00.adj.dest",
                                             weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.daily.r   <- weighted_felm_with_ConleySE(data= dhuts.y.dest,
                                             dep = "mean.logy.dhuts.r", 
                                             indep = c("mean.logy.v00.adj.dest", 
                                                       "ldensity.cell.hw.employment", 
                                                       "logmeandistC.czone.d", 
                                                       "mean.logy.v00.adj.orig"),
                                             weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  ## Excl Neighboring Towers
  ## Original Income:
  est1.exclnb   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.exclnb,
                                               dep = "mean.logy.dhuts", 
                                               indep = "mean.logy.v00.adj.dest",
                                               weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.exclnb   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.exclnb,
                                               dep = "mean.logy.dhuts", 
                                               indep = c("mean.logy.v00.adj.dest", 
                                                         "ldensity.cell.hw.employment", 
                                                         "logmeandistC.czone.d", 
                                                         "mean.logy.v00.adj.orig"),
                                               weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  ## Residual Income:
  est1.exclnb.r   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.exclnb,
                                                 dep = "mean.logy.dhuts.r", 
                                                 indep = "mean.logy.v00.adj.dest",
                                                 weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.exclnb.r   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.exclnb,
                                                 dep = "mean.logy.dhuts.r", 
                                                 indep = c("mean.logy.v00.adj.dest", 
                                                           "ldensity.cell.hw.employment", 
                                                           "logmeandistC.czone.d", 
                                                           "mean.logy.v00.adj.orig"),
                                                 weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  
  ## No Area Adjustment
  ## Original Income:
  est1.noarea   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.hw.noarea,
                                               dep = "mean.logy.dhuts", 
                                               indep = "mean.logy.v00.adj.dest",
                                               weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.noarea   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.hw.noarea,
                                               dep = "mean.logy.dhuts", 
                                               indep = c("mean.logy.v00.adj.dest", 
                                                         "ldensity.cell.hw.employment", 
                                                         "logmeandistC.czone.d", 
                                                         "mean.logy.v00.adj.orig"),
                                               weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  ## Residual Income:
  est1.noarea.r   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.hw.noarea,
                                                 dep = "mean.logy.dhuts.r", 
                                                 indep = "mean.logy.v00.adj.dest",
                                                 weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.noarea.r   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.hw.noarea,
                                                 dep = "mean.logy.dhuts.r", 
                                                 indep = c("mean.logy.v00.adj.dest", 
                                                           "ldensity.cell.hw.employment", 
                                                           "logmeandistC.czone.d", 
                                                           "mean.logy.v00.adj.orig"),
                                                 weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  ## All origin locations
  ## Original Income:
  est1.allo   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.allo,
                                             dep = "mean.logy.dhuts", 
                                             indep = "mean.logy.v00.adj.dest",
                                             weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.allo   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.allo,
                                             dep = "mean.logy.dhuts", 
                                             indep = c("mean.logy.v00.adj.dest", 
                                                       "ldensity.cell.hw.employment", 
                                                       "logmeandistC.czone.d", 
                                                       "mean.logy.v00.adj.orig"),
                                             weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  ## Residual Income:
  est1.allo.r   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.allo,
                                               dep = "mean.logy.dhuts.r", 
                                               indep = "mean.logy.v00.adj.dest",
                                               weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  est2.allo.r   <- weighted_felm_with_ConleySE(data= dhuts.y.dest.allo,
                                               dep = "mean.logy.dhuts.r", 
                                               indep = c("mean.logy.v00.adj.dest", 
                                                         "ldensity.cell.hw.employment", 
                                                         "logmeandistC.czone.d", 
                                                         "mean.logy.v00.adj.orig"),
                                               weight ="vol_dhuts", dist_cutoff = dist_cutoff)
  
  # R2s
    r2 <- c("Adjusted R2",
            round(est1.daily$adj.rsq, 2)    , round(est2.daily$adj.rsq, 2),
            round(est1.exclnb$adj.rsq, 2), round(est2.exclnb$adj.rsq, 2), 
            round(est1.noarea$adj.rsq, 2), round(est2.noarea$adj.rsq, 2),
            round(est1.allo$adj.rsq, 2)  , round(est2.allo$adj.rsq, 2))
    r2_resid <- c("Adjusted R2",
                  round(est1.daily.r$adj.rsq, 2)    , round(est2.daily.r$adj.rsq, 2),
                  round(est1.exclnb.r$adj.rsq, 2), round(est2.exclnb.r$adj.rsq, 2), 
                  round(est1.noarea.r$adj.rsq, 2), round(est2.noarea.r$adj.rsq, 2),
                  round(est1.allo.r$adj.rsq, 2)  , round(est2.allo.r$adj.rsq, 2))
    
    
  if(outfile != ""){
      # for robustness table - Panel A (log income)
      outfile = paste0(outfile_stub, "panel_a.tex")
      
      
      output <- capture.output(
        stargazer(est1.daily, est2.daily, 
                  est1.exclnb, est2.exclnb, 
                  est1.noarea, est2.noarea, 
                  est1.allo, est2.allo,
                  omit.stat=c('rsq', 'ser','adj.rsq'),
                  model.numbers=FALSE,
                  column.separate = c(2,2,2,2),
                  column.labels = c("\\thead{(1) Daily \\\\ Flows}", 
                                    "\\thead{(2) Excluding \\\\ Neighboring Towers}", 
                                    "\\thead{(3) Without \\\\ Area Adjustment}",
                                    "\\thead{(4) Include \\\\ All Origins}"),
                  dep.var.labels = 'log Survey Income (workplace)',
                  dep.var.caption = "",
                  covariate.labels = c('log Model Income (workplace)', 
                                       'log Employment Density', 
                                       'log Dist. to CBD', 
                                       'log Model Income (residential)'),
                  omit.table.layout = "n",
                  out = outfile,
                  digits = 2,
                  add.lines = list(c("Geographic Controls", rep(c("", "X"), 5)), r2),
                  omit = c("Constant","sqrt_weight",  "ldensity.cell.hw.employment", "logmeandistC.czone.d", "mean.logy.v00.adj.orig"),
                  type="latex", float = F, sep=""))
    
    # add resizebox, and drop hline commands
    edit_tex_file(texfile=outfile, add_resize="{1\\textwidth}{!}{", drop_hline=T)
    
    # for robustness table - Panel B (residual log income)
    outfile = paste0(outfile_stub, "panel_b.tex")
    output <- capture.output(
      stargazer(est1.daily.r, est2.daily.r, 
                est1.exclnb.r, est2.exclnb.r,
                est1.noarea.r, est2.noarea.r, 
                est1.allo.r, est2.allo.r,
                omit.stat=c('rsq', 'ser','adj.rsq'),
                model.numbers=FALSE,
                column.separate = c(2,2,2,2),
                column.labels = c("\\thead{(1) Daily \\\\ Flows}", 
                                  "\\thead{(2) Excluding \\\\ Neighboring Towers}", 
                                  "\\thead{(3) Without \\\\ Area Adjustment}",
                                  "\\thead{(4) Include \\\\ All Origins}"),
                dep.var.labels = c('log Model Income (workplace)', 
                                   'log Employment Density', 
                                   'log Dist. to CBD', 
                                   'log Model Income (residential)'),
                dep.var.caption = "",
                covariate.labels = c('log Model Income (workplace)'),
                omit.table.layout = "n",
                out = outfile,
                digits = 2,
                add.lines = list(c("Geographic Controls", rep(c("", "X"), 5)), r2_resid),
                omit = c("Constant","sqrt_weight",  "ldensity.cell.hw.employment", "logmeandistC.czone.d", "mean.logy.v00.adj.orig"),
                
                type="latex", float = F, sep=""))
    
    # add resizebox, and drop hline commands
    edit_tex_file(texfile=outfile, add_resize="{1\\textwidth}{!}{", drop_hline=T)
  }
  
  print("############### Robustness: daily, no neighbors, no area adjustment, all origins #################")
    
  stargazer(est1.daily, est2.daily, 
            est1.exclnb, est2.exclnb, 
            est1.noarea, est2.noarea, 
            est1.allo, est2.allo,
            
            omit.stat=c('rsq', 'ser'),
            dep.var.labels = 'log Survey Income',
            dep.var.caption = "",
            covariate.labels = c('log Model Income (workplace)', 
                                 'log Employment Density', 
                                 'log Dist. to CBD', 
                                 'log Model Income (residential)'),
            omit.table.layout = "n",
            digits = 2,
            omit = c("Constant"), type="text", float = F, sep="")
  
  stargazer(est1.daily.r, est2.daily.r, 
            est1.exclnb.r, est2.exclnb.r, 
            est1.noarea.r, est2.noarea.r, 
            est1.allo.r, est2.allo.r, 
            
            omit.stat=c('rsq', 'ser'),
            dep.var.labels = 'log Survey Income (Residual)',
            dep.var.caption = "",
            covariate.labels = c('log Model Income (workplace)', 
                                 'log Employment Density', 
                                 'log Dist. to CBD', 
                                 'log Model Income (residential)'),
            omit.table.layout = "n",
            digits = 2,
            omit = c("Constant"), type="text", float = F, sep="")
  
}


############################### .
##### STRUCTURAL 

struct_regressions <- function(dhuts.y,  est.gravity, use_resid=0, r_boot = 10, outfile="", outfile_newlayout="", debug=F){
  
  ## Get distance coefficient
  tau_coeff = as.numeric(est.gravity$X_beta_log_dur[1])
  
  # use area adjusted or not?
  dhuts.y.temp <- dhuts.y %>% mutate(
    logy00_temp = mean.logy.v00.adj.origdest,
    logy01_temp = mean.logy.v01.adj.origdest,
    logy10_temp = mean.logy.v10.adj.origdest,
    logy11_temp = mean.logy.v11.adj.origdest,
    lduration_intp_x_tau_coeff = lduration_intp * tau_coeff
  )
  
  if (use_resid == 0){
    dhuts.y.temp <- dhuts.y.temp %>% mutate(
      logyoutcome = log(income_trim)
    )
  }
  if (use_resid == 1){
    dhuts.y.temp <- dhuts.y.temp %>% mutate(
      logyoutcome = logy.r
    )
  }
  
    ## Run the 4 exteme income
    est00 <- felm(logyoutcome ~ logy00_temp | 0| 0| origin.czone + destination.czone ,
                  data=filter(dhuts.y.temp, dhuts_sample_struct == 1))
    est01 <- felm(logyoutcome ~ logy01_temp | 0| 0| origin.czone + destination.czone ,
                  data=filter(dhuts.y.temp, dhuts_sample_struct == 1))
    est11 <- felm(logyoutcome ~ logy11_temp | 0| 0| origin.czone + destination.czone ,
                  data=filter(dhuts.y.temp, dhuts_sample_struct == 1))
    est10 <- felm(logyoutcome ~ logy10_temp | 0| 0| origin.czone + destination.czone ,
                  data=filter(dhuts.y.temp, dhuts_sample_struct == 1))
    
    stargazer(est00, est01, est11, est10, type='text', omit.stat='ser')
    
    ## Run the two regressions
    print("Run the two structural equations")
    # unconstrained
    est.unc <- felm(logyoutcome ~ logy10_temp + logy00_temp + lduration_intp_x_tau_coeff | 0 | 0 | 
                        origin.czone + destination.czone, data=filter(dhuts.y.temp, dhuts_sample_struct == 1))
    
    N.unc = est.unc$N
    
    # coonstrained
    est.con <- felm(logyoutcome ~ logy10_temp + logy00_temp | 0 | 0 | 
                      origin.czone + destination.czone, data=filter(dhuts.y.temp, dhuts_sample_struct == 1))
    
    N.con = est.con$N
    
    # display
    stargazer(est.unc, est.con, type='text')
    
    ### DELTA METHOD
    
      ## Without constraining alpha_d = 0
      ## Structural transformation with Delta Method
      rho1 <- est.unc$coefficients[2]
      rho2 <- est.unc$coefficients[3]
      rho3 <- est.unc$coefficients[4]
      vcm  <- est.unc$clustervcv[2:4, 2:4]
      
      ## Applying Delta method
      Nabra <- 1 / (rho1 + rho2)^2 *
          matrix(c(  -1,   -1,    0,
                     rho2, -rho1, 0,
                    -rho3, -rho3, rho1+rho2),
          nrow=3, ncol=3)
      
      # estimator and standard errors
      strest.unc <- c(1, rho1, rho3) / (rho1 + rho2)
      strstd.unc <- diag(sqrt( t(Nabra) * vcm * Nabra ))
      
      ## With constraining alpha_d = 0
      ## Storing Coefficients for Delta method
      rho1 <- est.con$coefficients[2]
      rho2 <- est.con$coefficients[3]
      vcm  <- est.con$clustervcv[2:3, 2:3]
      
      ## Applying Delta method
      Nabra <- 1 / (rho1 + rho2)^2 *
              matrix(c(-1,    -1,
                        rho2, -rho1),
                    nrow=2, ncol=2)
      # estimator and standard errors
      strest.con <- c(1, rho1) / (rho1 + rho2)
      strstd.con <- diag(sqrt( t(Nabra) * vcm * Nabra))
      
    
    ### BOOTSTRAP STANDARD ERRORS
    
      # filter and create bootstrap unit 
      dhuts.y.sample <- dhuts.y.temp %>% filter(dhuts_sample_struct == 1) %>%
                        mutate(id = origin.czone)
      
      # id = paste(origin.czone, destination.czone, sep='_')
      # id = origin.czone
      # id = destination.czone
      
      n_groups = length(unique(dhuts.y.sample$id, na.rm=T))
      
      rhos.unc = matrix(0, r_boot, 3)
      rhos.con = matrix(0, r_boot, 2)
      
      epsilons.unc = numeric(r_boot)
      alphazs.unc  = numeric(r_boot)
      alphads.unc  = numeric(r_boot)
      
      # censor reg coeffs at zero
      epsilons.unc_cen = numeric(r_boot)
      alphazs.unc_cen  = numeric(r_boot)
      alphads.unc_cen  = numeric(r_boot)
      
      # constrainted
      epsilons.con = numeric(r_boot)
      alphazs.con  = numeric(r_boot)
      
      # censor reg coeffs at zero
      epsilons.con_cen = numeric(r_boot)
      alphazs.con_cen  = numeric(r_boot)
    
      # bootstrap iterations  
      print_every_n = floor(r_boot/10)
      
      for (ib in 1:r_boot){
        if(ib %% print_every_n == 0){ 
        print(sprintf("iteration %d or %d", ib, r_boot))
          }
        
        dhuts_boot <- dhuts.y.sample %>% 
          group_by(id) %>%
          sample_n_groups(size=n_groups, replace=T)
        
          capture.output(
          est.unc <- felm(logyoutcome ~ logy10_temp + logy00_temp + lduration_intp_x_tau_coeff | 0 | 0 | 
                            origin.czone + destination.czone, data=dhuts_boot)
          )
          # save coefficients
          rhos.unc[ib,1] = rho1 = est.unc$coefficients[2]
          rhos.unc[ib,2] = rho2 = est.unc$coefficients[3]
          rhos.unc[ib,3] = rho3 = est.unc$coefficients[4]
          
          # save transformed coefficients
          epsilons.unc[ib] =    1 / (rho1 + rho2)
          alphazs.unc[ib] =  rho1 / (rho1 + rho2)
          alphads.unc[ib] =  rho3 / (rho1 + rho2)
          
          # save transformed coefficients where we censor reg coeffs at zero [better behaved]
          epsilons.unc_cen[ib] =            1 / (max(0, rho1) + max(0, rho2))
          alphazs.unc_cen[ib] =  max(0, rho1) / (max(0, rho1) + max(0, rho2))
          alphads.unc_cen[ib] =  max(0, rho3) / (max(0, rho1) + max(0, rho2))
        
          capture.output(  
          est.con <- felm(logyoutcome ~ logy10_temp + logy00_temp | 0 | 0 | 
                          origin.czone + destination.czone, data=dhuts_boot)
          )
          
          # save coefficients
          rhos.con[ib,1] = rho1 = est.con$coefficients[2]
          rhos.con[ib,2] = rho2 = est.con$coefficients[3]
          
          # save transformed coefficients
          epsilons.con[ib] =    1 / (rho1 + rho2)
          alphazs.con[ib] =  rho1 / (rho1 + rho2)
          
          # censored
          epsilons.con_cen[ib] =            1 / (max(0, rho1) + max(0, rho2))
          alphazs.con_cen[ib] =  max(0, rho1) / (max(0, rho1) + max(0, rho2))
    
      }
    
    if(debug){
      print("summary stats")
      # draw histogram of coefficients
  
      print(summary(rhos.unc[,1]))
      print(quantile(rhos.unc[,1], c(0.01, 0.05, 0.10, 0.15, 0.85, 0.90, 0.95, 0.99)) )
      print(quantile(rhos.unc[,2], c(0.01, 0.05, 0.10, 0.15, 0.85, 0.90, 0.95, 0.99)) )
      print(quantile(rhos.unc[,3], c(0.01, 0.05, 0.10, 0.15, 0.85, 0.90, 0.95, 0.99)) )
      print(quantile(epsilons.unc, c(0.01, 0.05, 0.10, 0.15, 0.85, 0.90, 0.95, 0.99)) )


    }
      
    strbootest.unc = c(stat.desc(epsilons.unc)['mean'], 
                       stat.desc(alphazs.unc)['mean'], 
                       stat.desc(alphads.unc)['mean'])
    strbootstd.unc = c(stat.desc(epsilons.unc)['std.dev'], 
                       stat.desc(alphazs.unc)['std.dev'], 
                       stat.desc(alphads.unc)['std.dev'])
    
    strbootest.unc_cen = c(stat.desc(epsilons.unc_cen)['mean'], 
                           stat.desc(alphazs.unc_cen)['mean'], 
                           stat.desc(alphads.unc_cen)['mean'])
    strbootstd.unc_cen = c(stat.desc(epsilons.unc_cen)['std.dev'], 
                           stat.desc(alphazs.unc_cen)['std.dev'], 
                           stat.desc(alphads.unc_cen)['std.dev'])
    
    strbootest.con = c(stat.desc(epsilons.con)['mean'], 
                       stat.desc(alphazs.con)['mean'])
    strbootstd.con = c(stat.desc(epsilons.con)['std.dev'], 
                       stat.desc(alphazs.con)['std.dev'])
    
    strbootest.con_cen = c(stat.desc(epsilons.con_cen)['mean'], 
                           stat.desc(alphazs.con_cen)['mean'])
    strbootstd.con_cen = c(stat.desc(epsilons.con_cen)['std.dev'], 
                           stat.desc(alphazs.con_cen)['std.dev'])

    
    ## Return structural parameters
      strstd <- cbind(strest.unc,     strstd.unc, 
                      strbootest.unc, strbootstd.unc,
                      strest.con,     strstd.con,
                      strbootest.con, strbootstd.con,
                      strbootest.unc_cen, strbootstd.unc_cen,
                      strbootest.con_cen, strbootstd.con_cen)
      
      colnames(strstd) <- c('unc.est',      'unc.stderr', 
                            'unc.est.boot', 'unc.stderr.boot', 
                            'con.est',      'con.stderr', 
                            'con.est.boot', 'con.stderr.boot',
                            'unc_cen.boot', 'unc_cen.stderr.boot',
                            'con_cen.boot', 'con_cen.stderr.boot')
      
      rownames(strstd) <- c('epsilon', 'alpha_z', 'alpha_d')
      strstd['alpha_d', c('con.est','con.stderr','con.est.boot', 'con.stderr.boot')] <- 0
    
    ## Output to text
      if (outfile != ""){
        
        lines2write <- c(
          "\\begin{tabular}{lcc}",
          "\\toprule",
          " & (1) & (2) \\\\",
          " & Full model & Constrained model ($\\alpha_d=0$) \\\\ ",
          "\\addlinespace\\addlinespace ",
          sprintf("Shock productive $\\alpha_z$ &  %1.2f  &  %1.2f  \\\\ ", strstd[2,1], strstd[2,5]),
          sprintf("                             & (%1.2f) & (%1.2f) \\\\ ", strstd[2,2], strstd[2,6]),
          sprintf("                             &  %1.2f  &  %1.2f  \\\\ ", strstd[2,3], strstd[2,7]),
          sprintf("                             & [%1.2f] & [%1.2f] \\\\ ", strstd[2,4], strstd[2,8]),
          sprintf("                             &  %1.2f  &  %1.2f  \\\\ ", strstd[2,9], strstd[2,11]),
          sprintf("                             & \\{%1.2f\\} & \\{%1.2f\\} \\\\ ", strstd[2,10], strstd[2,12]),
          "\\addlinespace ",
          sprintf("Shock distance   $\\alpha_d$ &  %1.2f  & 0 \\\\ ", strstd[3,1]),
          sprintf("                             & (%1.2f) &   \\\\ ", strstd[3,2]),
          sprintf("                             &  %1.2f  &   \\\\ ", strstd[3,3]),
          sprintf("                             & [%1.2f] &   \\\\ ", strstd[3,4]),
          sprintf("                             &  %1.2f  &   \\\\ ", strstd[3,9]),
          sprintf("                             & \\{%1.2f\\} &   \\\\ ", strstd[3,10]),
          "\\addlinespace ",
          sprintf("Shape parameter $\\epsilon$ &  %1.2f  &  %1.2f   \\\\ ", strstd[1,1], strstd[1,5]),
          sprintf("                             & (%1.2f) & (%1.2f) \\\\ ", strstd[1,2], strstd[1,6]),
          sprintf("                             &  %1.2f  &  %1.2f  \\\\ ", strstd[1,3], strstd[1,7]),
          sprintf("                             & [%1.2f] & [%1.2f] \\\\ ", strstd[1,4], strstd[1,8]),
          sprintf("                             &  %1.2f  &  %1.2f  \\\\ ", strstd[1,9], strstd[1,11]),
          sprintf("                             & \\{%1.2f\\} & \\{%1.2f\\} \\\\ ", strstd[1,10], strstd[1,12]),
          "\\addlinespace ",
          sprintf("Observations &  %s  &  %s  \\\\ ", format(N.unc, big.mark=",", trim=T),
                                                      format(N.con, big.mark=",", trim=T)),
          sprintf("Bootstrap clusters &  %s  &  %s  \\\\ ", format(n_groups, big.mark=",", trim=T),
                                                            format(n_groups, big.mark=",", trim=T)),
          "\\bottomrule", 
          "\\end{tabular}" 
        )
        
        fileConn <- file(outfile)
        writeLines(lines2write, fileConn)
        close(fileConn)
        
        
        lines2write <- c(
          "\\begin{tabular}{lccccc}",
          "\\toprule",
          " & (1) & (2) & (3) & (4) & (5) \\\\",
          " & \\multicolumn{3}{c}{Full model} & \\multicolumn{2}{c}{\\thead{Constrained model \\\\ ($\\alpha_d=0$)}} \\\\ ",
          "\\addlinespace\\addlinespace ",
          sprintf("Shock productive $\\alpha_z$ &  %1.2f  &  %1.2f  & %1.2f   &  %1.2f  & %1.2f   \\\\ ", strstd[2,1], strstd[2,3], strstd[2,9] , strstd[2,5], strstd[2,7]),
          sprintf("                             & (%1.2f) & [%1.2f] & [%1.2f] & (%1.2f) & [%1.2f] \\\\ ", strstd[2,2], strstd[2,4], strstd[2,10], strstd[2,6], strstd[2,8]),
          "\\addlinespace ",
          sprintf("Shock distance   $\\alpha_d$ &  %1.2f  &  %1.2f  &  %1.2f  & 0 & 0 \\\\ ", strstd[3,1], strstd[3,3], strstd[3,9]),
          sprintf("                             & (%1.2f) & [%1.2f] & [%1.2f] &       \\\\ ", strstd[3,2], strstd[3,4], strstd[3,10]),
          "\\addlinespace ",
          sprintf("Shape parameter $\\epsilon$  & %1.2f   & %1.2f   & %1.2f   & %1.2f   &  %1.2f  \\\\ ", strstd[1,1], strstd[1,3], strstd[1,9] , strstd[1,5], strstd[1,7]),
          sprintf("                             & (%1.2f) & [%1.2f] & [%1.2f] & (%1.2f) & [%1.2f] \\\\ ", strstd[1,2], strstd[1,4], strstd[1,10], strstd[1,6], strstd[1,8]),
          sprintf("Observations &  %s  &  %s  &  %s  &  %s  &  %s  \\\\ ", 
                  format(N.unc, big.mark=",", trim=T), format(N.unc, big.mark=",", trim=T),format(N.unc, big.mark=",", trim=T),
                  format(N.con, big.mark=",", trim=T), format(N.con, big.mark=",", trim=T)),
          sprintf("Bootstrap clusters &      &  %s  &  %s  &      &  %s  \\\\ ", 
                  format(n_groups, big.mark=",", trim=T),format(n_groups, big.mark=",", trim=T),
                  format(n_groups, big.mark=",", trim=T)),
          "\\bottomrule", 
          "\\end{tabular}" 
        )
        
        fileConn <- file(outfile_newlayout)
        writeLines(lines2write, fileConn)
        close(fileConn)
      }
      
    
      strstd
}
