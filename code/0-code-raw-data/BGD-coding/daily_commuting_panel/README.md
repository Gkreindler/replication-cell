# A. commuting panel1

Obtain commuting information for each id, each date(including holidays)

Use the data that satisfies following two conditions only: for each id and date,

* call at least one time from 05:00 to 09:49
* call at least one time from 10:00 to 14:59

## working flow

1. `CommutingPanel1.java`
	
	Get the following from CBD
	```
	userid, date, origin_ant10, origin_lon, origin_lat, destination_ant10, destination_lon, destination_lat
	```

	run from `commuting_panel_online.sh`

2. `make_userid_number_table.py`  
	
	Collect the outputs of 1. and assign an unique number for each userid
	
	* Make an conversion table between user number and userid(`userid_table.csv`)

3. `FormatCommutingInfo.java`

	Format the output of 1. 

	* replace userid with user number(defined in 2.)
	* remove year(2013) part from date expression(20130801)
	* remove lon and lat

	Output: `commuting_info.csv`
	```
	usernum, month_day, origin_ant10, destination_ant10
	```

## final output
Panel data of `userid`, `date`, `origin_ant10`, `destination_ant10`

