# General Directions for coding Google Travel Times


## Procedure and code notes
We randomly sampled 90,000 pairs of towers in each country and extracted travel times from Google Maps for these towers. We then use an interpolation algorithm (using travel times between nearby origin towers and nearby destination towers) to compute travel time for all tower pairs.

- the java code interpolates *delay* (time divided by distance, which is the inverse of speed). We expect this to be more stable across space compared to travel time, which is strongly related to straight line distance
- for pairs of towers between which we already have the Google Maps travel time, that is not included in the interpolation (for a leave-out validation exercise cited in the paper)


## SLK
First run 
`1-travel-time-coding\process googlemap data before interpolation SLK.do`
Inputs:
- `data_raw_slk\other\towers_cordinates.dta`
- `data_raw_slk\other\140806_tower_pop.dta`
- `data_raw_slk\travel-times\random 90000 tower pair within 50km - base.csv`
- `data_raw_slk\travel-times\random 90000 tower pair within 50km - google prediction.csv`

Outputs (in `data_coded_slk\travel-times\`):
-`all tower pair within 50km before interpolation.csv`
-`random 90000 towe pair within 50km - google prediction before interpolation.csv`

Then run (in Java)
`1-travel-time-coding\googlemap_interpolate\src\interpolate\GoogleMapInterpolateSLK.java`
This will interpolate duration, duration_in_traffic, distance_in_traffic to all tower pairs with positive commuting flows within 50 km.
- Bandwidth is set to be 0.1 km.

Inputs:
-`all tower pair within 50km before interpolation.csv`
-`random 90000 towe pair within 50km - google prediction before interpolation.csv`

Outputs:
-`all tower pair within 50 km after interpolation.csv`
	- orig: origin tower code
	- dest: destination tower code
	- sldist: straight line distance (km)
	- duration_in_traffic_orig: original duration of travel time in traffic (sec). If not directly extracted from GoogleMapAPI, set to be 0.
	- duration_in_traffic_intp: interpolated. 
	- duration_orig: original duration of travel time without traffic (sec).
	- duration_intp: interpolated above.	
	- distance_orig: original distance traveled (m)
	- distance_intp: interpolated above.

-`all tower pair within 50 km after interpolation auxiliary.csv`


## BGD
First run 
`1-travel-time-coding\process googlemap data before interpolation BGD.do`
Inputs:
- `data_raw_bgd\other\antenna and tower coordinates.dta`
- `data_raw_bgd\travel-times\random pair 90000 - google prediction.csv`
- `data_raw_bgd\travel-times\random pair 90000 for googlemap API BGD.csv`

Outputs (in `data_coded_bgd\travel-times\`):
-`all tower pair in Dhaka before interpolation.csv`
-`random tower pair - google prediction before interpolation.csv`

Then run (in Java)
`1-travel-time-coding\googlemap_interpolate\src\interpolate\GoogleMapInterpolateBGD.java`
This will interpolate duration, duration_in_traffic, distance_in_traffic to all tower pairs with positive commuting flows within 50 km.
- Bandwidth is set to be 0.03 km due to higher density of towers than SLK.

Inputs:
-`all tower pair within 50km before interpolation.csv`
-`random 90000 towe pair within 50km - google prediction before interpolation.csv`

Outputs:
-`all tower pair in Dhaka after interpolation.csv`
	- orig: origin tower code
	- dest: destination tower code
	- sldist: straight line distance (km)
	- duration_orig: original duration of travel time without traffic (sec).
	- duration_intp: interpolated above.	
	- distance_orig: original distance traveled (m)
	- distance_intp: interpolated above.
-`all tower pair in Dhaka after interpolation auxiliary.csv`


## Data on Google Maps API queries
SLK:
- Set of origin and destinations of randomly selected 90000 tower pairs within 50 kms.
- Feed into Googlemap API query (Extracted around  20 Jun 2016, for departure time  26 Aug 2016 08:00:00).
BGD:
- The prediction of traffic is set at: 2/28/2017  12:00:00 PM
