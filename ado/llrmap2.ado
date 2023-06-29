capture program drop llrmap2

program define llrmap2
** compute LLR on a map ONLY at observed points

set seed 12345

* syntax yvar longvar latvar hvar [if] , bw(real)
syntax varlist(min=4 max=4) [if] , bw(real) 

 tokenize `varlist'
 local yvar "`1'"
 local lat  "`2'"
 local long "`3'"
 local h    "`4'"	 

 gen id = _n
 
preserve
	* reduce observations according to [if]
	if "`if'" != "" {
		qui keep `if'
	} 
	
	* (variable) bandwidth
	gen bandwidth_h=`h'*`bw'
	
	* 
	gen kz=.
	gen z1=.
	gen z2=.
	
	local nobs  = _N
	
	gen yhat=.
	gen yse =.
	
	* loop through observations
	qui forv i=1/`nobs'{
		noi di "Observation `i' of `nobs'"
			
		* define kernel values at (xlat, xlong)
			replace kz=.
			replace z1=.
			replace z2=.

		* Absolute value of x - x(i), divided by the bandwidth 
			replace z1 = (`lat'  -  `lat'[`i'])/bandwidth_h	
			replace z2 = (`long' - `long'[`i'])/bandwidth_h
			
		* Observation i gets the following quartic kernel weight 
			// replace kz = (15*15/(16*16))*((1 - z1^2)*(1 - z2^2))^2 if z1<=1 & z2<=1   // multiplicative, not weighted properly
			replace kz = /*3/_pi*/ (1-z1^2-z2^2)^2/bandwidth_h if z1^2+z2^2<1
			
			count if kz~=. & _n<=`nobs'
			if(r(N)>5){
				** run regression **
					qui reg `yvar' /*`lat' `lon'*/ [aw=kz] if kz~=., robust 
				
				* predicted value at xlat xlong					
					cap drop yhat_temp
					predict  yhat_temp in `i', xb

					cap drop yse_temp
					predict  yse_temp in `i', stdp
					
					replace yhat = yhat_temp in `i'
					replace yse  =  yse_temp in `i'
			}
			else{
				** Double the kernel!
				* define kernel values at (xlat, xlong)
					replace kz=.
					replace z1=.
					replace z2=.

				* Absolute value of x - x(i), divided by the bandwidth 
					replace z1 = (`lat'  -  `lat'[`i'])/bandwidth_h	* 0.5
					replace z2 = (`long' - `long'[`i'])/bandwidth_h * 0.5
					
				* Observation i gets the following quartic kernel weight 
					replace kz = /*3/_pi*/ (1-z1^2-z2^2)^2/bandwidth_h if z1^2+z2^2<1
					
					count if kz~=. & _n<=`nobs'
					if(r(N)>5){
						** run regression **
							qui reg `yvar' /*`lat' `lon'*/ [aw=kz] if kz~=., robust 
						
						* predicted value at xlat xlong					
							cap drop yhat_temp
							predict  yhat_temp in `i', xb

							cap drop yse_temp
							predict  yse_temp in `i', stdp
							
							replace yhat = yhat_temp in `i'
							replace yse  =  yse_temp in `i'
					}
			}
		

	}
 
	keep  id yhat yse
	rename yhat `yvar'_hat 
	rename yse  `yvar'_se
	tempfile estimates
	save	`estimates'
restore

 merge 1:1 id using `estimates'
 assert _m!=2
 drop _m id
 
end

