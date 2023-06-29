

compute_lasso_est <- function (X_base, y, w, test_loop_size=1, cv_size=5, lasso_type="Lasso", alpha = 1, splitratio = 0.8, 
                               cross_validation = TRUE, lambda = 10, debug=F) {
  
  # normalize
  X <- X_base %>%
    mutate_each(function(col) scale(col))
  
  # training/test sample split
  set.seed(2019)
  sample_split_pats <- list()
  for (i in 1:test_loop_size) {
    sample_split_pats[[i]] <- caTools::sample.split(unlist(X[, 1]), SplitRatio=splitratio)
  }
  
  # train a model and evaluate
  result_df <- data.frame(
    lambda=numeric(test_loop_size), 
    r2=numeric(test_loop_size), 
    test_r2=numeric(test_loop_size), 
    rmse=numeric(test_loop_size), 
    test_rmse=numeric(test_loop_size)
  )
  coefs_df <- data.frame(matrix(NA, test_loop_size, ncol(X)+1))
  colnames(coefs_df) <- c("intercept", colnames(X))
  
  
  set.seed(2020)
  for (i in 1:test_loop_size) {
    if (i %% 10 == 0 & debug == T) {
      print(paste("Currently executing ", i, "/", test_loop_size, " loops", sep="")) 
    }
    pat <- sample_split_pats[[i]]
    
    if (lasso_type == "Lasso") {
      
      if (cross_validation == TRUE){
        cv_result <- cv.glmnet(x=as.matrix(X[pat, , drop=FALSE]), y=unlist(y)[pat], weights = unlist(w)[pat],
                               family="gaussian", alpha=alpha, nfold=cv_size, parallel=TRUE)
        
        # cv_result <- cva.glmnet(x=as.matrix(X[pat, , drop=FALSE]), y=unlist(y)[pat], weights = unlist(w)[pat],
        #                        family="gaussian", nfold=cv_size, parallel=TRUE)
        
        lambda_min <- cv_result$lambda.min
        
      } else{
        
        lambda_min = lambda
        
      }
      
      reg <- glmnet(x=as.matrix(X[pat, , drop=FALSE]), y=unlist(y)[pat], weights = unlist(w)[pat],
                    family="gaussian", alpha=alpha, lambda=lambda_min)
      
      # compute train sample R^2
      fitted_values <- predict(reg, as.matrix(X[pat, , drop=FALSE]))
      rss <- sum((fitted_values - unlist(y)[pat]) ^ 2 * unlist(w)[pat])
      tss <- sum((unlist(y)[pat] - weighted.mean(unlist(y)[pat], w = unlist(w)[pat])) ^ 2 * unlist(w)[pat])
      r_squared <- 1 - rss/tss
      rmse <- sqrt(rss / sum(unlist(w)[pat]))
      
      # compute test sample R^2
      fitted_values <- predict(reg, as.matrix(X[!pat, , drop=FALSE]))
      rss <- sum((fitted_values - unlist(y)[!pat]) ^ 2 * unlist(w)[!pat])
      # use weighted mean from train sample
      tss <- sum((unlist(y)[!pat] -weighted.mean(unlist(y)[pat], w = unlist(w)[pat])) ^ 2 * unlist(w)[!pat])
      test_r_squared <- 1 - rss/tss
      test_rmse <- sqrt(rss / sum(unlist(w)[!pat]))
      
      
      result_df[i, ] <- c(
        lambda_min, 
        r_squared, 
        test_r_squared,
        rmse,
        test_rmse
      )
      
      coefs_df[i, ] <- (coef(reg) != 0)
    } 
    else if (lasso_type == "OLS") {
      
      reg <- lm(unlist(y)[pat] ~ ., data=X[pat, , drop=FALSE], weights = unlist(w)[pat])
      
      # compute train sample R^2
      fitted_values <- predict(reg, X[pat, , drop=FALSE], weights = unlist(w)[pat])
      rss <- sum((fitted_values - unlist(y)[pat]) ^ 2 * unlist(w)[pat])
      tss <- sum((unlist(y)[pat] - weighted.mean(unlist(y)[pat], w = unlist(w)[pat])) ^ 2 * unlist(w)[pat])
      r_squared <- 1 - rss/tss
      rmse <- sqrt(rss / sum(unlist(w)[pat]))
      
      
      # compute test sample R^2
      fitted_values <- predict(reg, X[!pat, , drop=FALSE])
      rss <- sum((fitted_values - unlist(y)[!pat]) ^ 2 * unlist(w)[!pat])
      # use weighted mean from train sample
      tss <- sum((unlist(y)[!pat] -weighted.mean(unlist(y)[pat], w = unlist(w)[pat])) ^ 2 * unlist(w)[!pat])
      test_r_squared <- 1 - rss/tss
      test_rmse <- sqrt(rss / sum(unlist(w)[!pat]))
      
      result_df[i, ] <- c(
        NA, 
        #summary(reg)$r.squared, 
        r_squared,
        test_r_squared,
        rmse,
        test_rmse
      )
      coefs_df[i, ] <- reg$coefficients
      
    } 
    else {
      print("Error")
      exit(-1)
    }
  }
  ave_vector <- colMeans(cbind(result_df, coefs_df))
  return (list(
    scores=colMeans(result_df), 
    coefs=colMeans(coefs_df)
  ))
}

### boosted regression
compute_boost_est <- function (df = dhuts.y.dest.hw, feature_start_col=19, test_loop_size=1, splitratio = 0.8, debug=F,
                               n_trees = 25, depth = 4, shrinkage = 0.001) {
  
  # training/test sample split
  set.seed(2019)
  sample_split_pats <- list()
  for (i in 1:test_loop_size) {
    sample_split_pats[[i]] <- caTools::sample.split(unlist(df[, 1]), SplitRatio=splitratio)
  }
  
  # train a model and evaluate
  result_df <- data.frame(
    r2=numeric(test_loop_size), 
    test_r2=numeric(test_loop_size), 
    rmse=numeric(test_loop_size), 
    test_rmse=numeric(test_loop_size)
  )
  coefs_df <- data.frame(matrix(NA, test_loop_size, ncol(X)+1))
  colnames(coefs_df) <- c("intercept", colnames(X))
  
  
  for (i in 1:test_loop_size) {
    if (i %% 10 == 0 & debug == T) {
      print(paste("Currently executing ", i, "/", test_loop_size, " loops", sep="")) 
    }
    pat <- sample_split_pats[[i]]
    train.data <- df[sample_split_pats[[i]],]
    test.data <- df[!sample_split_pats[[i]],]
    
    boostedtree <- gbm(mean.logy~., 
                       data = cbind(train.data[, c("mean.logy.v00.adj.dest", "logmeandistC.czone.d","ldensity.cell.hw.employment", "mean.logy"), drop=FALSE],
                                    train.data[, feature_start_col:ncol(train.data)]), 
                       weights = train.data$vol_dhuts, 
                       distribution="gaussian",  n.trees = n_trees, interaction.depth = depth, shrinkage = shrinkage)
    
    yhat_train <- predict (boostedtree ,newdata =train.data,n.trees=n_trees)
    yhat <- predict (boostedtree ,newdata =test.data,n.trees=n_trees)
    
    # training R2
    rss <- sum((yhat_train - unlist(train.data$mean.logy)) ^ 2 * unlist(train.data$vol_dhuts))
    tss <- sum((unlist(train.data$mean.logy) - mean(unlist(train.data$mean.logy), na.rm=T)) ^ 2 * unlist(train.data$vol_dhuts))
    r_squared <- 1 - rss/tss
    
    # test R2
    rss <- sum((yhat - unlist(test.data$mean.logy)) ^ 2 * unlist(test.data$vol_dhuts))
    tss <- sum((unlist(test.data$mean.logy) - mean(unlist(test.data$mean.logy), na.rm=T)) ^ 2 * unlist(test.data$vol_dhuts))
    test_r_squared <- 1 - rss/tss
    
    # store data
    result_df[i, ] <- c(
      r_squared,
      test_r_squared
    )
  }
  
  return (list(
    scores=colMeans(result_df)
  ))
}

### survey income

survey_income_ML <- function (outfile = "", expost_optimal = T, df = dhuts.y.dest.hw.noNAN, 
                              feature_start_col = 35, alpha = 1, cv_size = 5, splitratio=0.8) {
  
  ### OLS
  result_OLS_1 <- compute_lasso_est(
    X_base = cbind(df[, c("mean.logy.v00.adj.dest"), drop=FALSE]), 
    y = df[, "mean.logy"], 
    w = df[, "vol_dhuts"],
    test_loop_size=100, 
    lasso_type="OLS",
    splitratio=splitratio
  )
  
  result_OLS_2 <- compute_lasso_est(
    X_base = cbind(df[, c("area_km2_log"), drop=FALSE]), 
    y = df[, "mean.logy"], 
    w = df[, "vol_dhuts"],
    test_loop_size=100, 
    lasso_type="OLS",
    splitratio=splitratio
  )
  
  ### ML with ex-post optimal predictor
  if (expost_optimal == T){
    
    ## (1) CDR + "ldensity.cell.hw.employment"
    lambda_list <- 10^seq(-1.6, -0.1, by=0.3)
    lambda_size <- length(lambda_list)
    result_LASSO_CV_difflamb_1 <- data.frame(
      lambda=numeric(lambda_size), 
      r2=numeric(lambda_size), 
      test_r2=numeric(lambda_size), 
      rmse=numeric(lambda_size), 
      test_rmse=numeric(lambda_size)
    )
    
    for (j in 1:length(lambda_list)) {
      
      result <- compute_lasso_est(
        X_base = cbind(df[, feature_start_col:ncol(df)]),
        y = df[, "mean.logy"], 
        w = df[, "vol_dhuts"],
        test_loop_size=100, 
        cv_size=5, 
        lasso_type="Lasso",
        splitratio = splitratio,
        cross_validation = FALSE,
        lambda = lambda_list[j],
        alpha = alpha
      )
      
      result_LASSO_CV_difflamb_1[j, ] <- result$scores
      
    }
    result_LASSO_1 = result_LASSO_CV_difflamb_1[result_LASSO_CV_difflamb_1$test_r2 == max(result_LASSO_CV_difflamb_1$test_r2), ]
    # if duplicate, use the first one
    result_LASSO_1 = result_LASSO_1[1,]
    
    
    # ## (2) CDR + geo
    #   lambda_list <- 10^seq(-1.6, -0.1, by=0.3)
    #   lambda_size <- length(lambda_list)
    #   result_LASSO_CV_difflamb_2 <- data.frame(
    #     lambda=numeric(lambda_size), 
    #     r2=numeric(lambda_size), 
    #     test_r2=numeric(lambda_size)
    #   )
    #   
    #   for (j in 1:length(lambda_list)) {
    #     
    #     result <- compute_lasso_est(
    #       X_base = cbind(df[, c("logmeandistC.czone.d"), drop=FALSE], 
    #                      df[, feature_start_col:ncol(df)]),
    #       y = df[, "mean.logy"], 
    #       w = df[, "vol_dhuts"],
    #       test_loop_size=100, 
    #       cv_size=5, 
    #       lasso_type="Lasso",
    #       splitratio = 0.80,
    #       cross_validation = FALSE,
    #       lambda = lambda_list[j],
    #       alpha = alpha
    #     )
    #     
    #     result_LASSO_CV_difflamb_2[j, ] <- result$scores
    #     
    #   }
    #   result_LASSO_2 = result_LASSO_CV_difflamb_2[result_LASSO_CV_difflamb_2$test_r2 == max(result_LASSO_CV_difflamb_2$test_r2), ]
    #   # if duplicate, use the first one
    #   result_LASSO_2 = result_LASSO_2[1,]
    
    
    ## (3) CDR + geo + model
    lambda_list <- 10^seq(-1.6, -0.1, by=0.3)
    lambda_size <- length(lambda_list)
    result_LASSO_CV_difflamb_3 <- data.frame(
      lambda=numeric(lambda_size), 
      r2=numeric(lambda_size), 
      test_r2=numeric(lambda_size), 
      rmse=numeric(lambda_size), 
      test_rmse=numeric(lambda_size)
    )
    
    result_LASSO_CV_difflamb_3_coef <- data.frame(
      coef_model=numeric(lambda_size)
    )
    
    
    for (j in 1:length(lambda_list)) {
      
      result <- compute_lasso_est(
        X_base = cbind(df[, c("mean.logy.v00.adj.dest"), drop=FALSE], 
                       df[, feature_start_col:ncol(df)]),
        y = df[, "mean.logy"], 
        w = df[, "vol_dhuts"],
        test_loop_size=100, 
        cv_size=5, 
        lasso_type="Lasso",
        splitratio=splitratio,
        cross_validation = FALSE,
        lambda = lambda_list[j],
        alpha = alpha
      )
      
      result_LASSO_CV_difflamb_3[j, ] <- result$scores
      result_LASSO_CV_difflamb_3_coef[j, ] <- result$coefs["mean.logy.v00.adj.dest"]
      
    }
    result_LASSO_3 = result_LASSO_CV_difflamb_3[result_LASSO_CV_difflamb_3$test_r2 == max(result_LASSO_CV_difflamb_3$test_r2), ]
    temp_model_income_prob <- result_LASSO_CV_difflamb_3_coef[result_LASSO_CV_difflamb_3$test_r2 == max(result_LASSO_CV_difflamb_3$test_r2),]
    # if duplicate, use the first one
    result_LASSO_3 = result_LASSO_3[1,]
    temp_model_income_prob = temp_model_income_prob[1]
    
    
    
  }else{
    ## Otherwise, run cross-validation
    
    result_LASSO_1 <- compute_lasso_est(
      X_base = cbind(df[, feature_start_col:ncol(df)]),
      y = df[, "mean.logy"], 
      w = df[, "vol_dhuts"],
      test_loop_size=100, 
      cv_size=cv_size, 
      lasso_type="Lasso",
      splitratio=splitratio,
      cross_validation = TRUE,
      alpha = alpha
    )
    result_LASSO_1 = result_LASSO_1$scores
    
    # result_LASSO_2 <- compute_lasso_est(
    #   X_base = cbind(df[, c("logmeandistC.czone.d"), drop=FALSE], 
    #                  df[, feature_start_col:ncol(df)]),
    #   y = df[, "mean.logy"], 
    #   w = df[, "vol_dhuts"],
    #   test_loop_size=100, 
    #   cv_size=cv_size, 
    #   lasso_type="Lasso",
    #   splitratio = 0.80,
    #   cross_validation = TRUE,
    #   alpha = alpha
    # )
    # result_LASSO_2 = result_LASSO_2$scores
    
    
    result_LASSO_3 <- compute_lasso_est(
      X_base = cbind(df[, c("mean.logy.v00.adj.dest", "logmeandistC.czone.d"), drop=FALSE], 
                     df[, feature_start_col:ncol(df)]),
      y = df[, "mean.logy"], 
      w = df[, "vol_dhuts"],
      test_loop_size=100, 
      cv_size=cv_size, 
      lasso_type="Lasso",
      splitratio=splitratio,
      cross_validation = TRUE,
      alpha = alpha
    )
    temp_model_income_prob = result_LASSO_3$coefs["mean.logy.v00.adj.dest"]
    result_LASSO_3 = result_LASSO_3$scores
    
    
  }
  
  ## output
  lines2write <- c(
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & (1) & (2) & (3) & (4) \\\\",
    "Features & \\makecell{log Model Income \\\\ (workplace)} & log Tower Area & All CDR Features & \\makecell{(3) + log Model Income \\\\ (workplace)} \\\\",
    "\\addlinespace\\addlinespace ",
    
    sprintf("Training R$^2$ &  %1.2f & %1.2f &  %1.2f & %1.2f   \\\\",
            result_OLS_1$scores[2], result_OLS_2$scores[2], result_LASSO_1[2], result_LASSO_3[2]),
    sprintf("Training RMSE &  %1.2f & %1.2f &  %1.2f & %1.2f   \\\\",
            result_OLS_1$scores[4], result_OLS_2$scores[4], result_LASSO_1[4], result_LASSO_3[4]),
    sprintf("Test R$^2$      &  %1.2f & %1.2f &  %1.2f & %1.2f   \\\\ ",
            result_OLS_1$scores[3], result_OLS_2$scores[3], result_LASSO_1[3], result_LASSO_3[3]),
    sprintf("Test RMSE      &  %1.2f & %1.2f &  %1.2f & %1.2f   \\\\ \\addlinespace ",
            result_OLS_1$scores[5], result_OLS_2$scores[5], result_LASSO_1[5], result_LASSO_3[5]),
    sprintf("Observations    & %1.0f  & %1.0f & %1.0f & %1.0f   \\\\", 
            nrow(df), nrow(df),nrow(df),nrow(df)),
    
    # "\\addlinespace\\addlinespace",
    # sprintf("Freq. model income is selected    &  & &  & %1.2f   \\\\", temp_model_income_prob),
    
    "\\bottomrule", 
    "\\end{tabular}" 
  )
  
  
  # lines2write <- c(
  #   "\\begin{tabular}{lccc}",
  #   "\\toprule",
  #   " & (1) & (2) & (3) \\\\",
  #   "\\addlinespace\\addlinespace ",
  #   "\\multicolumn{4}{l}{{\\it (A) OLS with model income}} \\\\ \\addlinespace ",
  #   
  #   
  #   sprintf("In-Training-Sample R$^2$ &  %1.2f & %1.2f   \\\\", result_OLS_1$scores[2], result_OLS_2$scores[2]),
  #   sprintf("Out-of-Sample R$^2$      &  %1.2f & %1.2f   \\\\ \\addlinespace ", result_OLS_1$scores[3], result_OLS_2$scores[3]),
  #   "Control log distance to CBD & & X \\\\",
  #   
  #   "\\addlinespace\\addlinespace \\\\",
  #   "",
  #   "\\multicolumn{4}{l}{{\\it (B) LASSO with other features from CDR}} \\\\ \\addlinespace ",
  #   sprintf("In-Training-Sample R$^2$  &  %1.2f & %1.2f & %1.2f \\\\", 
  #           result_LASSO_1[2],
  #           result_LASSO_2[2],
  #           result_LASSO_3[2]),
  #   
  #   sprintf("Out-of-Sample R$^2$  &  %1.2f & %1.2f & %1.2f \\\\ \\addlinespace ", 
  #           result_LASSO_1[3],
  #           result_LASSO_2[3],
  #           result_LASSO_3[3]),
  #   "Control log distance to CBD & & X & X \\\\",
  #   "Control model income & & & X \\\\",
  #   sprintf("Freq. model income is selected    &  &  & %1.2f   \\\\", temp_model_income_prob),
  #   
  #   "\\bottomrule", 
  #   "\\end{tabular}" 
  # )
  
  
  fileConn <- file(outfile)
  writeLines(lines2write, fileConn)
  close(fileConn)
  
  edit_tex_file(texfile=outfile, drop_hline=T, add_resize="{0.9\\textwidth}{!}{", )
  
}


### survey income (CV)

survey_income_ML_CV <- function (outfile = "", df = dhuts.y.dest.hw.noNAN, 
                                 feature_start_col = 26, alpha = 1, splitratio = 0.5) {
  
  ### OLS
  result_OLS_2 <- compute_lasso_est(
    X_base = cbind(df[, c("mean.logy.v00.adj.dest"), drop=FALSE]), 
    y = df[, "mean.logy"], 
    w = df[, "vol_dhuts"],
    test_loop_size=100, 
    lasso_type="OLS",
    splitratio = splitratio
  )
  
  ### Expost Optimal
  lambda_list <- 10^seq(-1.6, -0.1, by=0.3)
  lambda_size <- length(lambda_list)
  result_LASSO_CV_difflamb_2 <- data.frame(
    lambda=numeric(lambda_size), 
    r2=numeric(lambda_size), 
    test_r2=numeric(lambda_size)
  )
  
  for (j in 1:length(lambda_list)) {
    
    result <- compute_lasso_est(
      X_base = cbind(df[, feature_start_col:ncol(df)]),
      y = df[, "mean.logy"], 
      w = df[, "vol_dhuts"],
      test_loop_size=100, 
      cv_size=5, 
      lasso_type="Lasso",
      splitratio = splitratio,
      cross_validation = FALSE,
      lambda = lambda_list[j],
      alpha = alpha
    )
    
    result_LASSO_CV_difflamb_2[j, ] <- result$scores
    
  }
  result_LASSO_2_optimal = result_LASSO_CV_difflamb_2[result_LASSO_CV_difflamb_2$test_r2 == max(result_LASSO_CV_difflamb_2$test_r2), ]
  
  ### CVs
  run_CV_LASSO_reg <- function(my_cv_size = cv_size){
    result_LASSO_2 <- compute_lasso_est(
      X_base = cbind(df[, feature_start_col:ncol(df)]),
      y = df[, "mean.logy"], 
      w = df[, "vol_dhuts"],
      test_loop_size=100, 
      cv_size=my_cv_size, 
      lasso_type="Lasso",
      splitratio = splitratio,
      cross_validation = TRUE,
      alpha = alpha
    )
    result_LASSO_2_out = result_LASSO_2$scores
    
  }
  
  # run
  result_LASSO_2_CV3  = run_CV_LASSO_reg(my_cv_size=3)
  result_LASSO_2_CV5  = run_CV_LASSO_reg(my_cv_size=5)
  result_LASSO_2_CV10 = run_CV_LASSO_reg(my_cv_size=10)
  result_LASSO_2_CV20 = run_CV_LASSO_reg(my_cv_size=20)
  result_LASSO_2_CVN  = run_CV_LASSO_reg(my_cv_size=nrow(df))
  
  
  ## output
  lines2write <- c(
    "\\begin{tabular}{lccccccc}",
    "\\toprule",
    "  &  (1) & (2) & (3)  & (4) & (5) & (6) & (7) \\\\",
    " & \\makecell{OLS\\\\(log Model Income)} & \\multicolumn{6}{c}{\\makecell{Elastic Net\\\\(All CDR Features)}} \\\\",
    " &  & Maximize Test R$^2$ & CV & CV  & CV  & CV  & CV \\\\",
    "\\addlinespace\\addlinespace ",
    
    "",
    sprintf("Training R$^2$  &  %1.2f & %1.2f & %1.2f  &  %1.2f & %1.2f & %1.2f  &  %1.2f \\\\", 
            result_OLS_2$scores[2], 
            result_LASSO_2_optimal[2],
            result_LASSO_2_CV3[2], result_LASSO_2_CV5[2], result_LASSO_2_CV10[2], result_LASSO_2_CV20[2], result_LASSO_2_CVN[2]),
    
    sprintf("Test R$^2$  &  %1.2f & %1.2f & %1.2f  &  %1.2f & %1.2f & %1.2f  &  %1.2f \\\\ \\addlinespace ", 
            result_OLS_2$scores[3], 
            result_LASSO_2_optimal[3],
            result_LASSO_2_CV3[3], result_LASSO_2_CV5[3], result_LASSO_2_CV10[3], result_LASSO_2_CV20[3], result_LASSO_2_CVN[3]),
    
    "\\addlinespace",
    "Number of Folds for CV &  &  & 3 & 5 & 10 & 20 & ", floor(nrow(df)*splitratio) , " \\\\ \\addlinespace",
    
    
    sprintf("Observations    & %1.0f  & %1.0f & %1.0f & %1.0f  & %1.0f & %1.0f & %1.0f   \\\\", 
            nrow(df), nrow(df),nrow(df),nrow(df), nrow(df),nrow(df),nrow(df)),
    
    "\\bottomrule", 
    "\\end{tabular}" 
  )
  
  fileConn <- file(outfile)
  writeLines(lines2write, fileConn)
  close(fileConn)
  
}


### survey income (different alpha for elastic net)
survey_income_ML_alpha <- function (outfile = "", df = dhuts.y.dest.hw.noNAN, 
                                    feature_start_col = 26, splitratio = 0.5) {
  
  ### OLS
  result_OLS_2 <- compute_lasso_est(
    X_base = cbind(df[, c("mean.logy.v00.adj.dest"), drop=FALSE]), 
    y = df[, "mean.logy"], 
    w = df[, "vol_dhuts"],
    test_loop_size=100, 
    lasso_type="OLS",
    splitratio = splitratio
  )
  
  ### Elastic net: different alphas    
  run_LASSO_reg <- function(my_alpha){
    
    ### Expost Optimal
    lambda_list <- 10^seq(-1.6, -0.1, by=0.3)
    lambda_size <- length(lambda_list)
    result_LASSO_CV_difflamb_2 <- data.frame(
      lambda=numeric(lambda_size), 
      r2=numeric(lambda_size), 
      test_r2=numeric(lambda_size)
    )
    
    for (j in 1:length(lambda_list)) {
      
      result <- compute_lasso_est(
        X_base = cbind(df[, feature_start_col:ncol(df)]),
        y = df[, "mean.logy"], 
        w = df[, "vol_dhuts"],
        test_loop_size=100, 
        lasso_type="Lasso",
        splitratio = splitratio,
        cross_validation = FALSE,
        lambda = lambda_list[j],
        alpha = my_alpha
      )
      
      result_LASSO_CV_difflamb_2[j, ] <- result$scores
      
    }
    result_LASSO_2_optimal = result_LASSO_CV_difflamb_2[result_LASSO_CV_difflamb_2$test_r2 == max(result_LASSO_CV_difflamb_2$test_r2), ]
  }
  
  ## get results
  result_LASSO_2_alpha0 <- run_LASSO_reg(my_alpha = 0)
  result_LASSO_2_alpha025 <- run_LASSO_reg(my_alpha = 0.25)
  result_LASSO_2_alpha05 <- run_LASSO_reg(my_alpha = 0.5)
  result_LASSO_2_alpha075 <- run_LASSO_reg(my_alpha = 0.75)
  result_LASSO_2_alpha1 <- run_LASSO_reg(my_alpha = 1)
  
  
  ## output
  lines2write <- c(
    "\\begin{tabular}{lcccccc}",
    "\\toprule",
    " &  (1) & (2) & (3)  & (4) & (5) & (6) \\\\",
    " & \\makecell{OLS\\\\(log Model Income)} & \\multicolumn{5}{c}{\\makecell{Elastic Net\\\\(All CDR Features)}} \\\\",
    "\\addlinespace\\addlinespace ",
    
    "",
    sprintf("Training R$^2$  &  %1.2f & %1.2f & %1.2f  &%1.2f & %1.2f & %1.2f \\\\", 
            result_OLS_2$scores[2], 
            result_LASSO_2_alpha0[2], result_LASSO_2_alpha025[2], result_LASSO_2_alpha05[2], result_LASSO_2_alpha075[2], result_LASSO_2_alpha1[2]),
    
    sprintf("Test R$^2$  &  %1.2f & %1.2f & %1.2f  &%1.2f & %1.2f & %1.2f \\\\ \\addlinespace ", 
            result_OLS_2$scores[3], 
            result_LASSO_2_alpha0[3], result_LASSO_2_alpha025[3], result_LASSO_2_alpha05[3], result_LASSO_2_alpha075[3], result_LASSO_2_alpha1[3]),
    
    "\\addlinespace",
    " \\alpha &  & 0 & 0.25 & 0.5 & 0.75 & 1 \\\\ \\addlinespace",
    
    
    sprintf("Observations    & %1.0f  & %1.0f & %1.0f & %1.0f  & %1.0f & %1.0f   \\\\", 
            nrow(df), nrow(df),nrow(df),nrow(df), nrow(df),nrow(df)),
    
    "\\bottomrule", 
    "\\end{tabular}" 
  )
  
  fileConn <- file(outfile)
  writeLines(lines2write, fileConn)
  close(fileConn)  
  
}



### nighttime lights and asset scores

residential_ML <- function (df = viirs.BGD.income, outfile = "", expost_optimal = T, outvar = "log_MEAN_VIIRS", 
                            feature_start_col = 35, alpha = 1, splitratio = 0.8, debug = F, weight_var="volume.origin") {
  
  result_OLS_1 <- compute_lasso_est(
    X_base = cbind(df[, c("res.meanlogy.v00.adj"), drop=FALSE]),
    y = df[, outvar], 
    w = df[, weight_var],#df[, "volume.origin"],
    test_loop_size=100, 
    lasso_type="OLS",
    splitratio = splitratio
  )
  
  result_OLS_2 <- compute_lasso_est(
    X_base = cbind(df[, c("area_km2_log"), drop=FALSE]),
    y = df[, outvar], 
    w = df[, weight_var],
    test_loop_size=100, 
    lasso_type="OLS",
    splitratio = splitratio
  )
  
  ### ML with ex-post optimal predictor
  if (expost_optimal == T){
    
    ## (1) CDR + "ldensity.cell.hw.employment"
    lambda_list <- 10^seq(-2, -1, by=0.5)
    lambda_size <- length(lambda_list)
    result_LASSO_CV_difflamb_1 <- data.frame(
      lambda=numeric(lambda_size), 
      r2=numeric(lambda_size), 
      test_r2=numeric(lambda_size), 
      rmse=numeric(lambda_size), 
      test_rmse=numeric(lambda_size)
    )
    
    for (j in 1:length(lambda_list)) {
      
      result <- compute_lasso_est(
        X_base = cbind(df[, feature_start_col:ncol(df)]), 
        y = df[, outvar], 
        w = df[, weight_var],
        test_loop_size=100, 
        cv_size=5, 
        lasso_type="Lasso",
        splitratio = splitratio,
        cross_validation = FALSE,
        lambda = lambda_list[j], 
        alpha = alpha,
        debug = debug
      )
      
      result_LASSO_CV_difflamb_1[j, ] <- result$scores
      
    }
    result_LASSO_1 = result_LASSO_CV_difflamb_1[result_LASSO_CV_difflamb_1$test_r2 == max(result_LASSO_CV_difflamb_1$test_r2), ]
    
    # ## (2) CDR + geo
    #   lambda_list <- 10^seq(-3, -1, by=0.5)
    #   lambda_size <- length(lambda_list)
    #   result_LASSO_CV_difflamb_2 <- data.frame(
    #     lambda=numeric(lambda_size), 
    #     r2=numeric(lambda_size), 
    #     test_r2=numeric(lambda_size)
    #   )
    #   
    #   for (j in 1:length(lambda_list)) {
    #     
    #     result <- compute_lasso_est(
    #       X_base = cbind(df[, c( "log_distCBD"), drop=FALSE], 
    #                      df[, feature_start_col:ncol(df)]), 
    #       y = df[, outvar], 
    #       w = df[, "const"],
    #       test_loop_size=100, 
    #       cv_size=5, 
    #       lasso_type="Lasso",
    #       splitratio = 0.80,
    #       cross_validation = FALSE,
    #       lambda = lambda_list[j], 
    #       alpha = alpha
    #     )
    #     
    #     result_LASSO_CV_difflamb_2[j, ] <- result$scores
    #     
    #   }
    #   result_LASSO_2 = result_LASSO_CV_difflamb_2[result_LASSO_CV_difflamb_2$test_r2 == max(result_LASSO_CV_difflamb_2$test_r2), ]
    
    
    ## (3) CDR + geo + model
    lambda_list <- 10^seq(-2, -1, by=0.5)
    lambda_size <- length(lambda_list)
    result_LASSO_CV_difflamb_3 <- data.frame(
      lambda=numeric(lambda_size), 
      r2=numeric(lambda_size), 
      test_r2=numeric(lambda_size), 
      rmse=numeric(lambda_size), 
      test_rmse=numeric(lambda_size)
    )
    
    result_LASSO_CV_difflamb_3_coef <- data.frame(
      coef_model=numeric(lambda_size)
    )
    
    
    for (j in 1:length(lambda_list)) {
      
      result <- compute_lasso_est(
        X_base = cbind(df[, c("res.meanlogy.v00.adj"), drop=FALSE], 
                       df[, feature_start_col:ncol(df)]), 
        y = df[, outvar], 
        w = df[, weight_var],
        test_loop_size=100, 
        cv_size=5, 
        lasso_type="Lasso",
        splitratio = splitratio,
        cross_validation = FALSE,
        lambda = lambda_list[j], 
        alpha = alpha,
        debug = debug
      )
      
      result_LASSO_CV_difflamb_3[j, ] <- result$scores
      result_LASSO_CV_difflamb_3_coef[j, ] <- result$coefs["res.meanlogy.v00.adj"]
      
    }
    result_LASSO_3 = result_LASSO_CV_difflamb_3[result_LASSO_CV_difflamb_3$test_r2 == max(result_LASSO_CV_difflamb_3$test_r2), ]
    temp_model_income_prob <- result_LASSO_CV_difflamb_3_coef[result_LASSO_CV_difflamb_3$test_r2 == max(result_LASSO_CV_difflamb_3$test_r2),]
    
    
    
  }else{
    ## Otherwise, run cross-validation
    
    result_LASSO_1 <- compute_lasso_est(
      X_base = cbind(df[, feature_start_col:ncol(df)]), 
      y = df[, outvar], 
      w = df[, weight_var],
      test_loop_size=100, 
      cv_size=5, 
      lasso_type="Lasso",
      splitratio = splitratio,
      cross_validation = TRUE,
      alpha = alpha,
      debug = debug
    )
    result_LASSO_1 = result_LASSO_1$scores
    
    # result_LASSO_2 <- compute_lasso_est(
    #   X_base = cbind(df[, c("log_distCBD"), drop=FALSE], 
    #                  df[, feature_start_col:ncol(df)]), 
    #   y = df[, outvar], 
    #   w = df[, "const"],
    #   test_loop_size=100, 
    #   cv_size=5, 
    #   lasso_type="Lasso",
    #   splitratio = 0.80,
    #   cross_validation = TRUE, 
    #   alpha = alpha
    # )
    # result_LASSO_2 = result_LASSO_2$scores
    
    result_LASSO_3 <- compute_lasso_est(
      X_base = cbind(df[, c("res.meanlogy.v00.adj", "log_distCBD"), drop=FALSE], 
                     df[, feature_start_col:ncol(df)]), 
      y = df[, outvar], 
      w = df[, weight_var],
      test_loop_size=100, 
      cv_size=5, 
      lasso_type="Lasso",
      splitratio = splitratio,
      cross_validation = TRUE, 
      alpha = alpha,
      debug = debug
    )
    temp_model_income_prob = result_LASSO_3$coefs["res.meanlogy.v00.adj"]
    result_LASSO_3 = result_LASSO_3$scores
    
  }
  
  ## output
  # lines2write <- c(
  #   "\\begin{tabular}{lccc}",
  #   "\\toprule",
  #   " & (1) & (2) & (3) \\\\",
  #   "\\addlinespace\\addlinespace ",
  #   "\\multicolumn{4}{l}{{\\it (A) OLS with model income}} \\\\ \\addlinespace ",
  #   
  #   
  #   sprintf("In-Training-Sample R$^2$ &  %1.2f & %1.2f   \\\\", result_OLS_1$scores[2], result_OLS_2$scores[2]),
  #   sprintf("Out-of-Sample R$^2$      &  %1.2f & %1.2f   \\\\ \\addlinespace ", result_OLS_1$scores[3], result_OLS_2$scores[3]),
  #   "Control log distance to CBD & & X \\\\",
  #   
  #   "\\addlinespace\\addlinespace \\\\",
  #   "",
  #   "\\multicolumn{4}{l}{{\\it (B) LASSO with other features from CDR}} \\\\ \\addlinespace ",
  #   sprintf("In-Training-Sample R$^2$  &  %1.2f & %1.2f & %1.2f \\\\", 
  #           result_LASSO_1[2],
  #           result_LASSO_2[2],
  #           result_LASSO_3[2]),
  #   
  #   sprintf("Out-of-Sample R$^2$  &  %1.2f & %1.2f & %1.2f \\\\ \\addlinespace ", 
  #           result_LASSO_1[3],
  #           result_LASSO_2[3],
  #           result_LASSO_3[3]),
  #   "Control log distance to CBD & & X & X \\\\",
  #   "Control model income & & & X \\\\",
  #   sprintf("Freq. model income is selected    &  &  & %1.2f   \\\\", temp_model_income_prob),
  #   
  #   "\\bottomrule", 
  #   "\\end{tabular}" 
  # )
  
  lines2write <- c( 
    "\\begin{tabular}{lcccc}",
    "\\toprule", 
    " & (1) & (2) & (3) & (4) \\\\",
    "Features & \\makecell{log Model Income \\\\ (residential)} & log Tower Area & All CDR Features & \\makecell{(3) + log Model Income \\\\ (residential)} \\\\",
    "\\addlinespace\\addlinespace ",
    
    sprintf("Training R$^2$ &  %1.2f & %1.2f &  %1.2f & %1.2f   \\\\",
            result_OLS_1$scores[2], result_OLS_2$scores[2], result_LASSO_1[2], result_LASSO_3[2]),
    sprintf("Training RMSE &  %1.2f & %1.2f &  %1.2f & %1.2f   \\\\",
            result_OLS_1$scores[4], result_OLS_2$scores[4], result_LASSO_1[4], result_LASSO_3[4]),
    sprintf("Test R$^2$      &  %1.2f & %1.2f &  %1.2f & %1.2f   \\\\ ",
            result_OLS_1$scores[3], result_OLS_2$scores[3], result_LASSO_1[3], result_LASSO_3[3]),
    sprintf("Test RMSE      &  %1.2f & %1.2f &  %1.2f & %1.2f   \\\\ \\addlinespace ",
            result_OLS_1$scores[5], result_OLS_2$scores[5], result_LASSO_1[5], result_LASSO_3[5]),

    # "\\addlinespace\\addlinespace",
    # sprintf("Freq. model income is selected    &  & &  & %1.2f   \\\\", temp_model_income_prob),
    
    sprintf("Observations    & %1.0f  & %1.0f & %1.0f & %1.0f   \\\\", 
            nrow(df), nrow(df),nrow(df),nrow(df)),
    
    "\\bottomrule", 
    "\\end{tabular}" 
  )
  
  fileConn <- file(outfile)
  writeLines(lines2write, fileConn)
  close(fileConn)
  
    edit_tex_file(texfile=outfile, drop_hline=T, add_resize="{0.9\\textwidth}{!}{", )
    
}
