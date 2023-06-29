# Codes to process raw BGD cell phone data

In each folder, there is a `.sh` script that executes all the Java and Hadoop files. The paths have to be correctly adjusted to execute the code properly.

## `daily_commuting_matrix`

This code: Construct the tower-pair and day level commuting matrix.

Output: `data_raw_bgd/flows-daily-trips/commuter_matrix_YYYY_MM/`

## `daily_commuting_panel`

This code: Construct the user, tower-pair, and day level commuting matrix.

Output: `data_raw_bgd/flows-daily-trips/commuting_panel/`

## `home_work_and_ML_covariates`

This code: Construct the user-level home and work classification, as well as the covariates for machine learning

Output: 
	- `data_raw_bgd/flows-home-work/user_home_office_list.csv` (with `data_raw_bgd/home_work_panel/userid_table.csv` as converter between new user ID and original user ID)
	- `data_raw_bgd/ML/tower_entropy.csv`, `data_raw_bgd/ML/tower_user_info.csv`: covariates for machine learning
