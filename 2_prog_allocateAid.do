* allocAid IDA WBIDA

/* Variables needed in "`1'_disbursement.dta" to run program:
- precision_N100
- transaction_value_tot
- temp_totcoded
- Disbursementcount
- transaction_year
- ID_adm1
- ID_adm2
- ISO3  
- ADM0 
- ADM1 
- ID_1
- ID_2
- ID_0
- d_miss_ADM2
*/
********************************************************************************
//2) Prepare location weighted data with precision code (program)
********************************************************************************
cd "$data\Aid\2017_11_14_WB_test"
capture program drop allocAid
program define allocAid
	qui{
	***HELP FILE***
	/*
	First argument is reserved for name of donor
	Second argument is reserved for variable name of aid variable
	
	Required datasets:
		- `1'_disbursement.dta
		- gadm2.dta
	*/
	
	*****Generate location weighted data with precision code 1-3 (ADM2 information) for ADM2 level****
	noisily di "1) Open `i' aid dataset"
	use "`1'_disbursement.dta", clear	 
	keep if precision_N100<4

	noisily di "2) Allocate aid according to the number of locations and the general share of precison-123-locations per project for ADM2 level"
	* For instance 100 [transaction_value_tot]/8 (number of projects with precision1-4)
	gen transaction_value_loc=transaction_value_tot/temp_totcoded
	replace Disbursementcount=Disbursementcount/temp_totcoded
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			gen transaction_value_loc_`g'=transaction_value_tot_`g'/temp_totcoded
			replace Disbursementcount_`g'=Disbursementcount_`g'/temp_totcoded
		}
	}
	* Collapse on ADM2 level to aggregate all project disbursements per ADM2 region"
	collapse (sum) transaction_value_loc* Disbursementcount*, by(transaction_year ISO3  ADM0 ADM1 ADM2 ID_0 ID_1 ID_2 ID_adm1 ID_adm2)

	* Rename Variables
	renvars transaction_value_loc Disbursementcount / `2'_ADM2_LOC13 Disbursementcount_ADM213
	* WorldBank specific:
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			renvars transaction_value_loc_`g' Disbursementcount_`g' / `2'_ADM2_LOC_`g'13 Disbursementcount_ADM2_`g'13
		}
	}
	save "`1'_disbursement_ADM2_prec13.dta", replace 


	noisily di "3) Generate location weighted data with precision code 4 (Only ADM1 information) for ADM1 level"
	use "`1'_disbursement.dta", clear
	keep if (precision_N100==4)

	* Allocate aid according to the number of locations and the general share of precison-4-locations per project //
	gen transaction_value_loc=transaction_value_tot/temp_totcoded
	replace Disbursementcount=Disbursementcount/temp_totcoded
	* WorldBank specific:
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			gen transaction_value_loc_`g'=transaction_value_tot_`g'/temp_totcoded
			replace Disbursementcount_`g'=Disbursementcount_`g'/temp_totcoded
		}
	}
	collapse (sum) transaction_value_loc* Disbursementcount*, by(transaction_year ISO3 ID_0 ID_1 ADM0 ADM1 ID_adm1)
	renvars transaction_value_loc Disbursementcount / `2'_ADM1_LOC4 Disbursementcount_ADM14
	* WorldBank specific: Allocate aid over sectors
		if "`i'"=="IDA" | "`i'"=="IBRD" {
			foreach g in AX BX CX EX FX JX LX TX WX YX{
			renvars transaction_value_loc_`g' Disbursementcount_`g' / `2'_ADM1_LOC_`g'4 Disbursementcount_ADM1_`g'4
		}
	}
	save "`1'_disbursement_ADM1_prec4.dta", replace 

	noisily di "4) Prepare location weighted data with precision code 4 (ADM2 information)"
	forvalues i=1995(1)2012 {
		use "`1'_disbursement_ADM1_prec4.dta", replace
		keep if transaction_year==`i'
		merge 1:m ID_adm1 using gadm2.dta, nogen keep(1 3)
		save `i', replace
	}
	* Put yearly disbursements together
	use 1995.dta, clear
		forvalues i=1996(1)2012 {
		append using `i'.dta
		erase `i'.dta
	}
	erase 1995.dta

	* Split ADM1 level aid of precision 4 equally across corresponding ADM2 regions
	gen count=1
	bysort ID_adm1 transaction_year: egen totalcount=total(count)
	* allocate aid with prec4 to all ADM2 regions 
	gen `2'_ADM2_LOC4 =`2'_ADM1_LOC4 /totalcount
	gen Disbursementcount_ADM24=Disbursementcount_ADM14/totalcount
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			gen `2'_ADM2_LOC_`g'4 =`2'_ADM1_LOC_`g'4  /totalcount
			gen Disbursementcount_ADM2_`g'4=Disbursementcount_ADM1_`g'4/totalcount
			drop `2'_ADM1_LOC_`g'4 Disbursementcount_ADM1_`g'4
		}
	}
	drop `2'_ADM1_LOC4 Disbursementcount_ADM14
	save "`1'_disbursement_ADM2_prec4.dta", replace 



	noisily di "5) Merge data with precision code 4 and precision codes 1-3 to create location weighted aid on ADM2 level"
	use "`1'_disbursement_ADM2_prec13.dta", clear

	*	XXXXXX Lennart, 05.01.2018: In the following step we lose around 200 million of aid (0.32% of total allocated aid), which could not be attributed to regions preivously as we had no ID_0, which indicates that something with the geo-merge went wrong
	drop if ID_0==0 //No geographic information available for AID projects (Missing Aid information worth about 5bn USD)
		
	* Rename variables with precisioncode 1-3 to prepare them for merge with precisioncode 4
	renvars `2'_ADM2_LOC13 Disbursementcount_ADM213 / `2'_ADM2_LOC Disbursementcount_ADM2_LOC
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			renvars `2'_ADM2_LOC_`g'13 Disbursementcount_ADM2_`g'13 / `2'_ADM2_LOC_`g'  Disbursementcount_ADM2_LOC_`g' 
		}
	}
	* Add data with precisioncode 4:
	merge 1:1 ID_adm2 transaction_year using "`1'_Disbursement_ADM2_prec4.dta",  nogen
	* Replace missings
	replace `2'_ADM2_LOC=0 if `2'_ADM2_LOC==.
	replace `2'_ADM2_LOC4=0 if `2'_ADM2_LOC4 ==.
	* Add data up
	replace `2'_ADM2_LOC=`2'_ADM2_LOC+`2'_ADM2_LOC4 
	replace Disbursementcount_ADM2_LOC=Disbursementcount_ADM2_LOC+Disbursementcount_ADM24
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {	
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			* Replace missings
			replace `2'_ADM2_LOC_`g'=0 if `2'_ADM2_LOC_`g'==.
			replace `2'_ADM2_LOC_`g'4=0 if `2'_ADM2_LOC_`g'4 ==.
			*XXXXXX Melvin 06.01.2018: @Lennart, do we not need to set the disbursement count equal to 0 if missing?
			
			* Add data up
			replace `2'_ADM2_LOC_`g'=`2'_ADM2_LOC_`g'+`2'_ADM2_LOC_`g'4
			replace Disbursementcount_ADM2_LOC_`g'=Disbursementcount_ADM2_LOC_`g'+Disbursementcount_ADM2_`g'4
			* Clean
			drop Disbursementcount_ADM2_`g'4 `2'_ADM2_LOC_`g'4
		}
	}
	drop Disbursementcount_ADM2*4 `2'_ADM2_LOC*4
	drop d_miss_ADM2 count totalcount total
	* Labeling
	label var `2'_ADM2_LOC "Value of `1' Aid disbursements per ADM2 region(weighted by number of project locations)"
	label var Disbursementcount_ADM2_LOC " Number of non-negative `1' aid disbursements per region"
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			label var Disbursementcount_ADM2_LOC_`g' " Number of non-negative `1' aid disbursements per region in sector `g'"
			label var `2'_ADM2_LOC_`g' "Value of `1' Aid per ADM2 region in sector `g' (weighted by # of proj. locations)"
		}	
	}
	save "`1'_disbursement_ADM2.dta", replace
		
		
	noisily di "6) Generate location weighted aid on ADM1 level by collapsing ADM1 level data"
	collapse (sum) `2'_ADM2_LOC* Disbursementcount_ADM2*, by(transaction_year ISO3  ADM0 ADM1 ID_0 ID_1  ID_adm1)
	* Rename Variables
	renvars `2'_ADM2_LOC Disbursementcount_ADM2_LOC / `2'_ADM1_LOC Disbursementcount_ADM1_LOC
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			renvars `2'_ADM2_LOC_`g' Disbursementcount_ADM2_LOC_`g' / `2'_ADM1_LOC_`g' Disbursementcount_ADM1_LOC_`g'
		}
	}
	* Labeling
		label var `2'_ADM1_LOC "Value of `1' Aid disbursements per ADM1 region(weighted by number of project locations)"
		label var Disbursementcount_ADM1_LOC " Number of non-negative `1' aid disbursements per region"
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			label var Disbursementcount_ADM1_LOC_`g' " Number of non-negative `1' aid disbursements per region in sector `g'"
			label var `2'_ADM1_LOC_`g' "Value of `1' Aid per ADM1 region in sector `g' (weighted by # of proj. locations)"
		}	
	}
	save "`1'_disbursement_ADM1.dta", replace



	noisily di "7) Create balanced dataset without gaps for ADM1 and ADM2" // (assumption perfect data on aid flows, that is, if there is no data, then it is not missing but no aid at all, = 0) 
	//ADM2 level
	use "`1'_disbursement_ADM2.dta", clear
	sort ID_adm2 transaction_year
	egen ID_adm2_num = group(ID_adm2)
	//Melvin H.L. Wong: 2. tsset Geounit Jahr
	tsset ID_adm2_num transaction_year
	//Melvin H.L. Wong: 3. tsfill, full
	tsfill, full //fill out data gaps
	gen years_reverse =-transaction_year
	//Melvin H.L. Wong: 4. carryforward, countryname etc
	bysort ID_adm2_num (transaction_year): carryforward ID_adm* ADM* ISO3 ID_*, replace 
	bysort ID_adm2_num (years_reverse): carryforward ID_adm* ID_adm2 ADM* ISO3 ID_*, replace
	//Melvin H.L. Wong: 5. replace Aidvvar= 0 if Aidvar==.
	replace `2'_ADM2_LOC = 0 if `2'_ADM2_LOC ==.
	replace Disbursementcount_ADM2_LOC = 0 if Disbursementcount_ADM2_LOC ==.
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {		
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			replace `2'_ADM2_LOC_`g' = 0 if `2'_ADM2_LOC_`g' ==.
			replace Disbursementcount_ADM2_LOC_`g' = 0 if Disbursementcount_ADM2_LOC_`g'==.
		}
	}
	drop years_reverse
	order transaction_year ID_adm*
	sort ID_adm* transaction_year
	*XXXXXX Melvin 06.01.2018: Manually checked if the sum of all allocated aid equals the sum of project aid. It does.
	save "`1'_disbursement_ADM2_tsfill.dta", replace
		
	//ADM1 level
	use "`1'_disbursement_ADM1.dta", clear
	sort ID_adm1 transaction_year
	egen ID_adm1_num = group(ID_adm1)
	//Melvin H.L. Wong: 2. tsset Geounit Jahr
	tsset ID_adm1_num transaction_year
	//Melvin H.L. Wong: 3. tsfill, full
	tsfill, full //fill out data gaps
	gen years_reverse =-transaction_year
	//Melvin H.L. Wong: 4. carryforward, countryname etc
	bysort ID_adm1_num (transaction_year): carryforward ID_adm* ADM* ISO3 ID_*, replace 
	bysort ID_adm1_num (years_reverse): carryforward ID_adm* ADM* ISO3 ID_*, replace
	//Melvin H.L. Wong: 5. replace Aidvvar= 0 if Aidvar==.
	replace `2'_ADM1_LOC = 0 if `2'_ADM1_LOC ==.
	replace Disbursementcount_ADM1_LOC = 0 if Disbursementcount_ADM1_LOC ==.
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {	
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			replace `2'_ADM1_LOC_`g' = 0 if `2'_ADM1_LOC_`g' ==.
			replace Disbursementcount_ADM1_LOC_`g' = 0 if Disbursementcount_ADM1_LOC_`g'==.
		}
	}
	drop years_reverse
	order transaction_year ID_adm*
	sort ID_adm* transaction_year
	save "`1'_disbursement_ADM1_tsfill.dta", replace
	
	noisily di "8) Clean Up and delete redundant files"
	erase "`1'_disbursement_ADM1.dta"
	erase "`1'_disbursement_ADM2.dta"
	erase "`1'_disbursement_ADM2_prec13.dta"
	erase "`1'_disbursement_ADM2_prec4.dta"
	erase "`1'_disbursement_ADM1_prec4.dta"
	
	noisily di "DONE!"
	}
end
