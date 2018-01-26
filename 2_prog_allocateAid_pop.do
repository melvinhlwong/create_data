//cd "$data\Aid\2017_11_14_WB_test"

//allocAid_pop IDA WBIDA

capture program drop allocAid_pop
program define allocAid_pop
	**********************************************************************	
	//3) Prepare population weighted data
	*************************************************************************

	/*XXXXXXXXX Melvin 16.01.2018: Recode missing ADM2 regions as ADM1 */
	use gadm2.dta, clear
	* Merge with Population data
	rename ID_adm2 rid2
	merge 1:m rid2 using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen
	renvars year rid2 isum_pop / transaction_year ID_adm2 isum_pop_ADM2

	* prepare population merge by ID_adm1 year: Expand regions by year if no adm2 region
	expand 26 if transaction_year==.
	bysort ID_adm1: replace transaction_year=1989+_n if d_miss_ADM2==1

	*XXXXXX Melvin 02.01.2018: Treat missing ADM2 regions as ADM1 region: Merge ADM1 pop if ADM2 is missing
	renvars transaction_year ID_adm1 / year rid1
	merge m:1 rid1 year using "$data\ADM\1_1_1_R_pop_GADM1.dta", keep(3) nogen keepusing(isum_pop)

	replace isum_pop_ADM2=isum_pop if d_miss_ADM2==1
	rename isum_pop isum_pop_ADM1
	renvars year rid1 / transaction_year ID_adm1

	*XXXXXX Melvin 16.01.2018: merge population data with aid data
	merge 1:m ID_adm2 transaction_year using "`1'_disbursement.dta"
	*XXXXXX Melvin 16.01.2018: get ADM1 population if there is no ADM2 region as identifier because of precision code 4
	bysort ID_adm1 transaction_year: egen temp_pop=mean(isum_pop_ADM1) //get ADM1 pop in additional column
	replace isum_pop_ADM1=temp_pop if isum_pop_ADM1==. & precision_N100==4 // add missing ADM1 pop data for precisioncode 4 projects (note: "& precision_N100==4" in code is redundant but illustrates that population data is missing for those region with precision code 4)

	/* TEST HOW MUCH AID IS LOST
	duplicates drop project_id transaction_year, force
	egen lost_aid=total(transaction_value_tot) if isum_pop_ADM1==.
	egen all_aid=total(transaction_value_tot)
	sum lost_aid all_aid
	// lost aid is 2,76 bn USD (2760 million USD) almost all of them due to imprecise geocode ("water points")
	*/



	/*
	 XXXXX Lennart 10.01.2018 Generate Population on ADM1 level to allocated aid, which was coded with precision 4 based on the approach written down above:
	 Pop weighted
	- Each of the 3 ADM2 regions coded with precision 1-3 gets Pop(i)/(Sum Pop)*4/5*X 
	- The ADM1 region coded with precision 4 gets Pop(i)/(Sum Pop)*4/5*X and this is then distributed equally among the corresponding ADM2 regions
	*/

	* XXXXX Lennart 10.01.2018 Create population for weighting of precision 4(ADM1-population) and precision3 (ADM2-population) locations
	gen wpop4=isum_pop_ADM1 if precision_N100==4
	gen wpop13=isum_pop_ADM2 if precision_N100<4
	* XXXXX Lennart 10.01.2018 Create denominator of population weights
	gen wpop=isum_pop_ADM1 if precision_N100==4
	replace wpop=isum_pop_ADM2 if precision_N100<4



	//temp_totcoded: Population of locations that are precisely coded (higher than precision level 4)
	egen pop_totcoded=total(wpop), by(project_id transaction_year)

	//temp_totcoded: Population of locations that are coded with precision 4
	egen pop_totcoded4=total(wpop4) , by(project_id transaction_year)

	//temp_totcoded: Population of locations that are precisely coded (higher than precision level 4)
	egen pop_totcoded13=total(wpop13) , by(project_id transaction_year)


	* XXXXX Lennart 10.01.2018 - Save in order to continue with allocation of precision4 and precision 1-3 aid
	save "`1'_disbursement_popweights.dta", replace


	**** Generate population weighted data with precision codes 1-3 (ADM2 information) for ADM2 level**** 
	keep if precision_N100<4
	* XXXXXXXX Lennart 10.01.2018: Allocate aid according to the population of precision-123-locations in total population of project regions //
	* For instance 100 [transaction_value_tot] * 10 mio (number of population in this specific region) [wpop] / 100 (number of population in project-regions with precision1-3) [pop_totcoded]
	gen transaction_value_pop=transaction_value_tot*(wpop/pop_totcoded)
	* XXXXX Lennart 10.01.2018: Accordingly, we also apply this weighting scheme to the disbursementcounts. @ Kai & Melvin: Do you find this sensible? Or should we apply here something like number of active projects per each region.
	replace Disbursementcount=Disbursementcount*(wpop/pop_totcoded)
	if "`i'"=="IDA" | "`i'"=="IBRD" {
	* XXXXX Lennart 10.01.2018: Repeat excercise for sectoral disbursements
		foreach g in AX BX CX EX FX JX LX TX WX YX{
		gen transaction_value_pop_`g'=transaction_value_tot_`g'*(wpop/pop_totcoded)
		replace Disbursementcount_`g'=Disbursementcount_`g'*(wpop/pop_totcoded)
		}
	}

	* Collapse on ADM2 level to aggregate all project disbursements per ADM2 region
	collapse (sum) transaction_value_pop* Disbursementcount*, by(transaction_year ID_0 ID_1 ID_2 ID_adm1 ID_adm2)

	* Rename Variables
	renvars transaction_value_pop Disbursementcount / `2'_ADM2_POP13 Disbursementcount_ADM2_POP13
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
		renvars transaction_value_pop_`g' Disbursementcount_`g' / `2'_ADM2_POP_`g'13 Disbursementcount_ADM2_POP_`g'13
		}
	}
	save "`1'_disbursement_ADM2_POP_prec13.dta", replace 


	**** Generate population weighted data with precision code 4 (Only ADM1 information) for ADM1 level**** 
	use "`1'_disbursement_popweights.dta", clear
	keep if (precision_N100==4)

	* XXXXXXXX Lennart 10.01.2018: Allocate aid according to the population of precision-123-locations in total population of project regions //
	* For instance 100 [transaction_value_tot] * 10 mio (number of population in this specific region) [wpop] / 100 (number of population in project-regions with precision1-3) [pop_totcoded]
	gen transaction_value_pop=transaction_value_tot*(wpop/pop_totcoded)
	* XXXXX Lennart 10.01.2018: Accordingly, we also apply this weighting scheme to the disbursementcounts. @ Kai & Melvin: Do you find this sensible? Or should we apply here something like number of active projects per each region.
	replace Disbursementcount=Disbursementcount*(wpop/pop_totcoded)
	* XXXXXXX Lennart 10.01.2018: Redo Excercise for sectoral disbursements
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
		gen transaction_value_pop_`g'=transaction_value_tot_`g'*(wpop/pop_totcoded)
		replace Disbursementcount_`g'=Disbursementcount_`g'*(wpop/pop_totcoded)
		}
	}
	collapse (sum) transaction_value_pop* Disbursementcount*, by(transaction_year ID_0 ID_1 ID_adm1)

	* Rename Variables
	renvars transaction_value_pop Disbursementcount / `2'_ADM1_POP4 Disbursementcount_ADM1_POP4
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
		renvars transaction_value_pop_`g' Disbursementcount_`g' / `2'_ADM1_POP_`g'4 Disbursementcount_ADM1_POP_`g'4
		}
	}
	* Save Dataset
	save "`1'_disbursement_ADM1_POP_prec4.dta", replace

	* XXXXX Lennart 11.01.2018: Due to the potential for duplicates and erroneous merges, we go with classical merge-command instead of joinby on a yearly level
	forvalues i=1995(1)2012 {
	use "`1'_disbursement_ADM1_POP_prec4.dta", clear
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

	* XXXX Lennart 11.01.2018: Merge with population data in order to allow for population weighted distribution of data
	renvars transaction_year ID_adm2 / year rid2
	merge m:1 rid2 year using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen keep(1 3)
	renvars year rid2 isum_pop / transaction_year ID_adm2 isum_pop_ADM2
	* XXXX Lennart 11.01.2018: As above, some projects might have no population data attributed. In order to not "loose" this aid, we could replace the data with 1 person per region.
	replace isum_pop_ADM2=1 if isum_pop_ADM2==. | isum_pop_ADM2==0

	* XXXX Lennart 11.01.2018: Split ADM1 level aid of precision 4 by population across corresponding ADM2 regions
	bysort transaction_year ID_adm1: egen isum_pop_ADM1=total(isum_pop_ADM2)

	* allocate aid with prec4 to all ADM2 regions 
	gen `2'_ADM2_POP4 =`2'_ADM1_POP4 *isum_pop_ADM2/isum_pop_ADM1


	* XXXXXX Lennart 11.01.2018: Analoguous to the location-weighted aid, disbursement / transaction count is split across locations with population weights.
	gen Disbursementcount_ADM2_POP4=Disbursementcount_ADM1_POP4*isum_pop_ADM2/isum_pop_ADM1
	*XXXX Lennart 11.01.2018: Redo excercise for sectoral aid
	if "`i'"=="IDA" | "`i'"=="IBRD" {
	foreach g in AX BX CX EX FX JX LX TX WX YX{
		gen `2'_ADM2_POP_`g'4 =`2'_ADM1_POP_`g'4  *isum_pop_ADM2/isum_pop_ADM1
		gen Disbursementcount_ADM2_POP_`g'4=Disbursementcount_ADM1_POP_`g'4*isum_pop_ADM2/isum_pop_ADM1
		drop `2'_ADM1_POP_`g'4 Disbursementcount_ADM1_POP_`g'4
		}
	}
	drop `2'_ADM1_POP4 Disbursementcount_ADM1_POP4
	* XXX Lennart 11.01.2018: Save File
	save "`1'_Disbursement_ADM2_POP_prec4.dta", replace 



	* XXXXXXXXXX Lennart 11.01.2018: Merge data with precision code 4 and precision codes 1-3 to create population weighted aid on ADM2 level
	use "`1'_disbursement_ADM2_POP_prec13.dta", clear

	*	XXXXXX Lennart, 11.01.2018: In the following step we drop regions for which no geographic information is available (geo-merge in GIS failed). However, this is not linked to a loss in disbursements as
	*  these regions had no aid allocated in any case as we could also not attribute population. In any case, we might want to think about fixing this, because technically these would be recipient regions.
	drop if ID_0==0 //No geographic information available for AID projects (Missing Aid information worth about 5bn USD)
		
		
	* XXXXX Lennart 11.01.2018: Rename variables with precisioncode 1-3 to prepare them for merge with precisioncode 4
	renvars `2'_ADM2_POP13 Disbursementcount_ADM2_POP13 / `2'_ADM2_POP Disbursementcount_ADM2_POP
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			renvars `2'_ADM2_POP_`g'13 Disbursementcount_ADM2_POP_`g'13 / `2'_ADM2_POP_`g'  Disbursementcount_ADM2_POP_`g' 
		}
	}
	* Add data with precisioncode 4:
	merge 1:1 ID_adm2 transaction_year using "`1'_Disbursement_ADM2_POP_prec4.dta",  nogen
	* Replace missings
	replace `2'_ADM2_POP=0 if `2'_ADM2_POP==.
	replace `2'_ADM2_POP4=0 if `2'_ADM2_POP4 ==.
	*XXXXXX Melvin 16.01.2018: Added the following line
	replace Disbursementcount_ADM2_POP4=0 if Disbursementcount_ADM2_POP4==.
	* Add data up
	replace `2'_ADM2_POP=`2'_ADM2_POP+`2'_ADM2_POP4 
	replace Disbursementcount_ADM2_POP=Disbursementcount_ADM2_POP+Disbursementcount_ADM2_POP4
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			* Replace missings
			replace `2'_ADM2_POP_`g'=0 if `2'_ADM2_POP_`g'==.
			replace `2'_ADM2_POP_`g'4=0 if `2'_ADM2_POP_`g'4 ==.
		*XXXXXX Melvin 16.01.2018: Added the following two lines
			replace Disbursementcount_ADM2_POP_`g'4=0 if Disbursementcount_ADM2_POP_`g'4==.
			replace Disbursementcount_ADM2_POP_`g'=0 if Disbursementcount_ADM2_POP_`g'==.
			* Add data up
			replace `2'_ADM2_POP_`g'=`2'_ADM2_POP_`g'+`2'_ADM2_POP_`g'4
			replace Disbursementcount_ADM2_POP_`g'=Disbursementcount_ADM2_POP_`g'+Disbursementcount_ADM2_POP_`g'4
			* Clean
			drop Disbursementcount_ADM2_POP_`g'4 `2'_ADM2_POP_`g'4
		}
	}
	drop Disbursementcount_ADM2*4 `2'_ADM2_POP*4
	drop d_miss_ADM2 count
	// merge ADM2 names
	merge m:1 ID_adm2 using gadm2_ids.dta, nogen keep(1 3)
	* Labeling
	label var `2'_ADM2_POP "Value of WB `1' Aid disbursements per ADM2 region(weighted by population of project locations)"
	label var Disbursementcount_ADM2_POP " Number of non-negative `1' aid disbursements per region"
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			label var Disbursementcount_ADM2_POP_`g' "Number of non-negative `1' aid disbursements per region in sector `g'"
			label var `2'_ADM2_POP_`g' "Value of WB `1' Aid per ADM2 region in sector `g' (weighted by pop of locations)"
		}	
	}
	save "`1'_disbursement_ADM2_POP.dta", replace
		
		
	* XXXXXXX Lennart 11.01.2018: Generate population weighted aid on ADM1 level by collapsing ADM2 level data
	collapse (sum) `2'_ADM2_POP* Disbursementcount_ADM2*, by(transaction_year ID_0 ID_1 ID_adm1)
	// merge ADM1 names
	merge m:1 ID_adm1 using gadm1_ids.dta, nogen keep(1 3)
	* Rename Variables
	renvars `2'_ADM2_POP Disbursementcount_ADM2_POP / `2'_ADM1_POP Disbursementcount_ADM1_POP
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
		renvars `2'_ADM2_POP_`g' Disbursementcount_ADM2_POP_`g' / `2'_ADM1_POP_`g' Disbursementcount_ADM1_POP_`g'
		}
	}
	* Labeling
		label var `2'_ADM1_POP "Value of WB `1' Aid disbursements per ADM1 region(weighted by population of project locations)"
		label var Disbursementcount_ADM1_POP " Number of non-negative `1' aid disbursements per region"
	if "`i'"=="IDA" | "`i'"=="IBRD" {
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			label var Disbursementcount_ADM1_POP_`g' " Number of non-negative `1' aid disbursements per region in sector `g'"
			label var `2'_ADM1_POP_`g' "Value of WB `1' Aid per ADM1 region in sector `g' (weighted by pop of  locations)"
		}	
	}
	save "`1'_disbursement_ADM1_POP.dta", replace



		****create balanced dataset without gaps (assumption perfect data on aid flows, that is, if there is no data, then it is not missing but no aid at all, = 0) 
		//ADM2 level
		use "`1'_disbursement_ADM2_POP.dta", clear
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
		replace `2'_ADM2_POP = 0 if `2'_ADM2_POP ==.
		replace Disbursementcount_ADM2_POP = 0 if Disbursementcount_ADM2_POP ==.
		if "`i'"=="IDA" | "`i'"=="IBRD" {
			foreach g in AX BX CX EX FX JX LX TX WX YX{
				replace `2'_ADM2_POP_`g' = 0 if `2'_ADM2_POP_`g' ==.
				replace Disbursementcount_ADM2_POP_`g' = 0 if Disbursementcount_ADM2_POP_`g'==.
			}
		}
		drop years_reverse
		order transaction_year ID_adm*
		sort ID_adm* transaction_year
		save "`1'_disbursement_ADM2_POP_tsfill.dta", replace
		
		//ADM1 level
		use "`1'_disbursement_ADM1_POP.dta", clear
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
		replace `2'_ADM1_POP = 0 if `2'_ADM1_POP ==.
		replace Disbursementcount_ADM1_POP = 0 if Disbursementcount_ADM1_POP ==.
		if "`i'"=="IDA" | "`i'"=="IBRD" {
			foreach g in AX BX CX EX FX JX LX TX WX YX{
				replace `2'_ADM1_POP_`g' = 0 if `2'_ADM1_POP_`g' ==.
				replace Disbursementcount_ADM1_POP_`g' = 0 if Disbursementcount_ADM1_POP_`g'==.
			}
		}
		drop years_reverse
		order transaction_year ID_adm*
		sort ID_adm* transaction_year
		save "`1'_disbursement_ADM1_POP_tsfill.dta", replace
	/* XXXXXXXX Lennart 11.01.2018: We have 100 million more total aid (0.15% of aid)  with population than with location weights. We should at least double check
	 use "`1'_disbursement_ADM1_POP_tsfill.dta", clear
	 egen total=total(`2'_ADM1_POP)
	 sum total
	 use "`1'_disbursement_ADM1_tsfill.dta", clear
	  egen total=total(`2'_ADM1_LOC)
	 sum total
	 */


		noisily di "8) Clean Up and delete redundant files"
		erase "`1'_disbursement_ADM1_POP.dta"
		erase "`1'_disbursement_ADM2_POP.dta"
		erase "`1'_Disbursement_ADM2_POP_prec4.dta"
		erase "`1'_Disbursement_ADM2_POP_prec13.dta"
		erase "`1'_Disbursement_ADM1_POP_prec4.dta"
		erase "`1'_disbursement_popweights.dta"
		erase "`1'_disbursement.dta"
end
