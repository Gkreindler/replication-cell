#================================================================ 
## Conley Standard Errors
## Date: August 21, 2017
## Vectorized Code using Rcpp
## !!!! Taken from https://github.com/darinchristensen/conley-se/blob/master/code/conley.R . Cite or acknowledge if we end up using this.
#================================================================ 

source(paste0(Sys.getenv("HOME"), "/Rinit/profile.R"))


pkgs <- c("data.table", "lfe", "geosphere", "Rcpp", "RcppArmadillo")
invisible(sapply(pkgs, require, character.only = TRUE))
sourceCpp(paste0(BGDSLKCELLPHONE_CODE, "util/cpp-functions.cpp"))

## Run weighted regression and append Conley SE
# @@@@@@@@@@@@@@@@@@@@@ Adjusted R-squared obtained separately. @@@@@@@@@@@@@@@@@@@@@@
weighted_felm_with_ConleySE <- function(data, dep, indep, weight, conleySE = T, dist_cutoff = 5){
  
  ## prepare variables
    # Update weight
    data[, 'weight'] = data[, weight]
    data <- data %>% mutate(sqrt_weight = sqrt(weight))
    
    # Normalize outcome variable
    dep_w = paste0(dep, "_w")
    data[, dep_w] = data[, dep] * sqrt(data$weight)

    # Normalize independant variable
    indep_w = paste0(indep, "_w")
    for (i in 1:length(indep)){
      data[, indep_w[i]] = data[, indep[i]] * sqrt(data$weight)
    }
    
  ## run manually weighted regression
    str = toString(indep_w)
    str = gsub(",", " +", str)
    str = paste0(dep_w, " ~ ", str, " + sqrt_weight + 0 |0|0|lat+lon")
    est <- felm(data= data, as.formula(str), keepCX=T)
    #stargazer(est, type='text')

  ## append Conley SE
    if(conleySE == T){
      est   <- appendConleySEs(est, dist_cutoff = dist_cutoff)
    }
    
    
  ## run original weighted regression (for obtaining R2)
    str = toString(indep)
    str = gsub(",", " +", str)
    str = paste0(dep, " ~ ", str, " |0|0|lat+lon")
    est.originalweight <- felm(data= data, as.formula(str), weights=data$weight)

    # sanity check: If the coefficient is different from weighted regression, something is wrong.
    stopifnot(floor(coef(est)[indep_w[1]]*1000) == floor(coef(est.originalweight)[indep[1]]*1000))
    
    # obtain R2
    est$adj.rsq <- as.numeric(summary(est.originalweight)$adj.r.squared)
    
    # obtain RSME
    RSS <- sum(est.originalweight$residuals^2 * est.originalweight$weights)
    MSE <- RSS / sum(est.originalweight$weights)
    est$RMSE <- sqrt(MSE)

  return(est)
}


## Change regression results to Conley SE
# @@@@@@@@@@@@ If weighted regression, include these variables in the main formula (not as fixed effects!!!!!) @@@@@@@@@@@@
appendConleySEs <- function(reg = reg, unit = "unit", dist_cutoff=5, cores=1, verbose=FALSE) {
  out = ConleySEs(reg = reg,
                  unit = unit,#"unit",
                  time = "time",
                  noFE = T, 
                  lat = "lat", lon = "lon",
                  dist_fn = "SH", dist_cutoff = dist_cutoff,
                  lag_cutoff = 5,
                  cores = cores,
                  verbose = verbose)
  
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


################# Original Code #################
ConleySEs <- function(reg,
                      unit, time, lat, lon,
                      noFE = F, # noFE: added by YM. If noFE, unit and time are not included in felm as fixed effects.
                      kernel = "bartlett", dist_fn = "Haversine",
                      dist_cutoff = 500, lag_cutoff = 5,
                      lat_scale = 111, verbose = FALSE, cores = 1, balanced_pnl = FALSE) {

  source(paste0(Sys.getenv("HOME"), "/Rinit/profile.R"))

    
  Fac2Num <- function(x) {as.numeric(as.character(x))}
  source(paste0(BGDSLKCELLPHONE_CODE, "util/iterate-obs-function.R"), local = TRUE)
  if(cores > 1) {
    invisible(library(parallel))

    ## To install parallelsugar
    # https://www.r-bloggers.com/parallelsugar-an-implementation-of-mclapply-for-windows/
    #   
    # install.package(devtools)
    # library(devtools)
    # install_github('nathanvan/parallelsugar')
    # library(parallelsugar)
    # suppressWarnings(library(parallelsugar))
  }
  
  if(class(reg) == "felm") {
    Xvars <- rownames(reg$coefficients)
    
    if(noFE == F){
      dt = data.table(reg$cY, reg$cX,
                      fe1 = Fac2Num(reg$fe[[1]]),
                      fe2 = Fac2Num(reg$fe[[2]]),
                      coord1 = Fac2Num(reg$clustervar[[1]]),
                      coord2 = Fac2Num(reg$clustervar[[2]]))
      setnames(dt,
               c("fe1", "fe2", "coord1", "coord2"),
               c(names(reg$fe), names(reg$clustervar)
               ))
      
    }else{
      dt = data.table(reg$cY, reg$cX,
                      fe1 = 1,
                      fe2 = 1,
                      coord1 = Fac2Num(reg$clustervar[[1]]),
                      coord2 = Fac2Num(reg$clustervar[[2]]))
      setnames(dt,
               c("fe1", "fe2", "coord1", "coord2"),
               c("unit", "time", names(reg$clustervar)
               ))
      
    }
    dt = dt[, e := as.numeric(reg$residuals)]
    
  } else {
    message("Model class not recognized.")
    break
  }
  
  n <- nrow(dt)
  k <- length(Xvars)
  
  # Renaming variables:
  orig_names <- c(unit, time, lat, lon)
  new_names <- c("unit", "time", "lat", "lon")
  setnames(dt, orig_names, new_names)
  
  # Empty Matrix:
  XeeX <- matrix(nrow = k, ncol = k, 0)
  
  #================================================================ 
  # Correct for spatial correlation:
  timeUnique <- unique(dt[, time])
  Ntime <- length(timeUnique)
  setkey(dt, time)
  
  if(verbose){message("Starting to loop over time periods...")}
  
  if(balanced_pnl){
    sub_dt <- dt[time == timeUnique[1]]
    lat <- sub_dt[, lat]; lon <- sub_dt[, lon]; rm(sub_dt)
    
    if(balanced_pnl & verbose){message("Computing Distance Matrix...")}
    
    d <- DistMat(cbind(lat, lon), cutoff = dist_cutoff, kernel, dist_fn)
    rm(list = c("lat", "lon"))
  }
  
  if(cores == 1) {
    XeeXhs <- lapply(timeUnique, function(t) iterateObs(sub_index = t,
                                                        type = "spatial", cutoff = dist_cutoff))
  } else {
    XeeXhs <- mclapply(timeUnique, function(t) iterateObs(sub_index = t,
                                                          type = "spatial", cutoff = dist_cutoff), mc.cores = cores)
  }
  
  if(balanced_pnl){rm(d)}
  
  # First Reduce:
  XeeX <- Reduce("+",  XeeXhs)
  
  # Generate VCE for only cross-sectional spatial correlation:
  if(verbose){message("Inverting matrix...")}
  X <- as.matrix(dt[, eval(Xvars), with = FALSE])
  invXX <- solve(t(X) %*% X) * n
  
  V_spatial <- invXX %*% (XeeX / n) %*% invXX / n
  
  V_spatial <- (V_spatial + t(V_spatial)) / 2
  
  if(verbose) {message("Computed Spatial VCOV.")}
  
  #================================================================ 
  # Correct for serial correlation:
  panelUnique <- unique(dt[, unit])
  Npanel <- length(panelUnique)
  setkey(dt, unit)
  
  if(verbose){message("Starting to loop over units...")}
  
  if(cores == 1) {
    XeeXhs <- lapply(panelUnique, function(t) iterateObs(sub_index = t,
                                                         type = "serial", cutoff = lag_cutoff))
  } else {
    XeeXhs <- mclapply(panelUnique,function(t) iterateObs(sub_index = t,
                                                          type = "serial", cutoff = lag_cutoff), mc.cores = cores)
  }
  
  XeeX_serial <- Reduce("+",  XeeXhs)
  
  XeeX <- XeeX + XeeX_serial
  
  V_spatial_HAC <- invXX %*% (XeeX / n) %*% invXX / n
  V_spatial_HAC <- (V_spatial_HAC + t(V_spatial_HAC)) / 2
  
  return_list <- list(
    "OLS" = reg$vcv,
    "Spatial" = V_spatial,
    "Spatial_HAC" = V_spatial_HAC)
  return(return_list)
}
