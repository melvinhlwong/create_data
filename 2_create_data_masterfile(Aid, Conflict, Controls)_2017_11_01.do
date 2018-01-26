**********************************************************************************************
* This is a master create file, which creates all the data files based on the raw data input *
**********************************************************************************************
/*


** Melvin
global data "D:\Users\wong\Dropbox\Geocoded Aid and Conflict\Data"
global dofiles "D:\Users\wong\Dropbox\Geocoded Aid and Conflict\do-files"
global rawdata "C:\Users\wong\Dropbox\Geocoded Aid and Conflict\Raw Data"

**Kai
//global data "C:\Users\gehring\Dropbox\Geocoded Aid and Conflict\Data"
//global dofiles "C:\Users\gehring\Dropbox\Geocoded Aid and Conflict\do-files"
global rawdata "C:\Users\gehring\Dropbox\Geocoded Aid and Conflict\Raw Data"

** Lennart
global data "C:\Users\lkaplan\Dropbox\Geocoded Aid and Conflict\Data"
global dofiles "C:\Users\lkaplan\Dropbox\Geocoded Aid and Conflict\do-files"
global rawdata "C:\Users\lkaplan\Dropbox\Geocoded Aid and Conflict\Raw Data"


*/
********************************************************************************
*** Define program for aid allocation using location weights
********************************************************************************
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
		
	Variables needed in "`1'_disbursement.dta" to run program:
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
	- ADM2
	- ID_1
	- ID_2
	- ID_0
	- d_miss_ADM2
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
	collapse (sum) transaction_value_loc* Disbursementcount*, by(transaction_year ID_0 ID_1 ID_adm1)
	renvars transaction_value_loc Disbursementcount / `2'_ADM1_LOC4 Disbursementcount_ADM14
	// merge ADM1 names
	merge m:1 ID_adm1 using gadm1_ids.dta, nogen keep(1 3)
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
* XXXX  Lennart 11.01.2018: In line with Melvin's command below, we replace all missing disbursementcounts
	replace Disbursementcount_ADM24=0 if Disbursementcount_ADM24==.

	* Add data up
	replace `2'_ADM2_LOC=`2'_ADM2_LOC+`2'_ADM2_LOC4 
	replace Disbursementcount_ADM2_LOC=Disbursementcount_ADM2_LOC+Disbursementcount_ADM24
	* WorldBank specific: Allocate aid over sectors
	if "`i'"=="IDA" | "`i'"=="IBRD" {	
		foreach g in AX BX CX EX FX JX LX TX WX YX{
			* Replace missings
			replace `2'_ADM2_LOC_`g'=0 if `2'_ADM2_LOC_`g'==.
			replace `2'_ADM2_LOC_`g'4=0 if `2'_ADM2_LOC_`g'4 ==.
			replace Disbursementcount_ADM2_`g'4=0 if Disbursementcount_ADM2_`g'4==.
			replace Disbursementcount_ADM2_LOC_`g'=0 if Disbursementcount_ADM2_LOC_`g'==.
*XXXXXX Melvin 06.01.2018: @Lennart, do we not need to set the disbursement count equal to 0 if missing?
* XXXX  Lennart 11.01.2018: @Melvin, you are absolutely right. We should also replace the missings for Disbursementocunts
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
	collapse (sum) `2'_ADM2_LOC* Disbursementcount_ADM2*, by(transaction_year ID_0 ID_1 ID_adm1)
	// merge ADM1 names
	merge m:1 ID_adm1 using gadm1_ids.dta, nogen keep(1 3)
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

********************************************************************************




**************************
**************************
* A: Create IDA Aid Data *
**************************
**************************
cd "$data\Aid\2017_11_14_WB"

* Prepare GADM2 regions data in order to be able to attribute Precision Code 4 (ADM1 data) to subregions

/*XXXXXXXXX Melvin 08.11.2017: Correct error in CSV file. Contained empty spaces 
which lead to incorrect import of CSV data*/
* Load GADM Data
import delim using "$data\ADM\gadm28.csv", clear
keep objectidn100 isoc3 id_0n100 name_0c75 id_1n100 name_1c75 name_2c75 id_2n100
renvars objectidn100 isoc3  name_0c75 name_1c75 name_2c75  / OBJECTID ISO3 ADM0 ADM1 ADM2 
* Generate unique identifier for each ADM region:
gen c = "c"
gen r = "r"
egen ID_adm1 = concat(c id_0n100 r id_1n100)
egen ID_adm2 = concat(c id_0n100 r id_1n100 r id_2n100)
drop c r
rename id_0n100 ID_0N100
rename id_1n100 ID_1N100
rename id_2n100 ID_2N100
label var ID_adm2 "Unique identifier for ADM2 region"

/*XXXXXXXXX Melvin 08.11.2017: Recode missing ADM2 regions as ADM1 */
gen byte d_miss_ADM2=(ADM2=="")
br if d_miss_ADM2==1
replace ADM2=ADM1 if d_miss_ADM2==1

/*XXXXXXXXX Melvin 08.11.2017: After correction of CSV file don't need this section anymore
duplicates drop OBJECTID, force
* 7 Regions are coded wrongly and are dropped
drop if ISO3==""
*/

duplicates drop ID_adm2 ID_adm1 ADM0 ADM1 ADM2, force
* drop mulitple entries due to multiple polygons for same region. ok to drop here, since we are interested in the region's existence and not single polygons comprising them.
drop OBJECTID

save gadm2.dta, replace

/* XXXXXXXXX Melvin 18.01.2018: In correspondence with Lennart:
Create file containing unique ID_adm1 AND ADM1 identifiers. Some ADM1 regions are encoded
differently which causes duplicates when collpsing by ADM1
e.g. ID_adm1=="c250r59"
*/
//generate dataset with ADM1 names
use gadm2.dta, clear
duplicates drop ID_adm1 ISO3 ADM0 ADM1, force
keep ID_adm1 ISO3 ADM0 ADM1
save gadm1_ids.dta, replace
//generate dataset with ADM2 names
use gadm2.dta, clear
duplicates drop ID_adm2 ISO3 ADM0 ADM1 ADM2, force
keep ID_adm2 ISO3 ADM0 ADM1 ADM2
save gadm2_ids.dta, replace

* Create yearly population totals
*XXXXXXXXX Melvin 30.01.2017: Population data has been updated. Major errors corrected for GAMD1 and GADM2
*XXXXXXXXX Melvin 30.01.2017: GREG population data is outstanding and has to be computed
use "$data\ADM\1_1_1_R_pop_GADM1.dta", clear
rename country isoc3
rename isum_pop isum_pop_ADM1

collapse (sum) isum_pop_ADM1, by(isoc3 year)
renvars isum_pop year / c_pop transaction_year
label var c_pop "Total Country Population"
save country_pop, replace

/*
Source of population data. Authors' own calculation based on GPW4 data
Center for International Earth Science Information Network - CIESIN - Columbia University. 2016. Gridded Population of the World, Version 4 (GPWv4): Population Count Adjusted to Match 2015 Revision of UN WPP Country Totals. Palisades, NY: NASA Socioeconomic Data and Applications Center (SEDAC). http://dx.doi.org/10.7927/H4SF2T42. Accessed 01.Jan 2017.
*/
***Prepare aid data***
import delimited using "$data\Aid\projects_ancillary.csv", clear delimiter(",") //contains sector information
* Drop duplicates as these relate only to IEG Evaluations, which we do not consider here
*XXXXXX Melvin 29.12.2017: Checked the duplicates. Ok to use duplicates drop
duplicates drop projectid, force
save ancillary.dta, replace
** Import matches from AidData-GADM spatial join (Needs to be import excel as important information are lost, if delimited (.csv) is used.) 
import excel using "$data\Aid\alg.xls", firstrow clear
rename project_idC254 projectid
merge m:1 projectid using ancillary.dta, nogen keep(1 3) //no mismatch from master (melvin 29.12.2017)
*XXXXXX Melvin 29.12.2017: @Lennart. Is this comment still relevant?
* XXXXXX Lennart 03.01.2018: @ Melvin: Moved it upwards as it is not needed here anymore.
keep mjsector* sector*pct projectid project_loC254 precision_N100 geoname_idN100 latitudeN1911 longitudeN1911 location_tC254 location_1C254 ISOC3 NAME_0C75  NAME_1C75  NAME_2C75 ID_0N100 ID_1N100 ID_2N100
*XXXXXX Melvin 29.12.2017: destring is not needed anymore
*destring, dpcomma replace
rename projectid project_id
rename latitudeN1911 latitutde
rename longitudeN1911 longitude
rename NAME_0C75 ADM0
rename NAME_1C75 ADM1
rename NAME_2C75 ADM2
rename ISOC3 ISO3
/*
The spatial join in ArcGIS does not consider if the aid loaction points match the precision
of the map provided. That is, If there are aid points with precision codes only valid for ADM1 but 
an ADM2 map is given, ArcGIS assumes that the point belongs to the underlying ADM2 region,
despite the arbitrary point setting, most likely the cetroid of the ADM1 region.

Thus, if the precision codes are only valid for ADM1, we must delete the existing
ADM2 IDs to avoid erroreneous merges later.
*/
replace ADM2="" if precision_N100>=4
replace ID_2N100=. if precision_N100>=4

*create unique region ids
gen c = "c"
gen r = "r"
egen ID_adm1 = concat(c ID_0N100 r ID_1N100)
egen ID_adm2 = concat(c ID_0N100 r ID_1N100 r ID_2N100)
/*XXXXXX Melvin 29.12.2017: Note that 512 out of 61440 obs are unmatched with countries and lost
about 250 have precision codes higher equal 4. 
Small measurement error but may be solved using nearest region algorithm.
Stata code: tab precision_N100 if ID_0N100==0
*/
drop c r
sort project_id
save "$data\Aid\2017_11_14_WB\alg.dta", replace

********************************************************************************
//1) Create yearly disbursements data discounted by information loss
********************************************************************************
/* 
(only until 2012 as we do not have disbursement data in subsequent years)
This dataset will contain the variable transaction_value_tot
which the total project aid for each year, discounted by the informtion loss due to
imprecise geo-codes.
*/
forvalues i=1995(1)2012 {
import excel "$data\Aid\IDA_IBRD_transactions.xlsx", firstrow clear
/*XXXXXX Melvin 05.01.2018 @Kai disbursements are sometimes negative. Should we drop them to avoid miscounting locations?
I checked the WorldBank transaction file for Project P000603

Jun, 2009	IDAN0310	Fees			37.788,94
Jun, 2009	IDAN0310	Repayment		78.302,85
Sep, 2009	IDAN0310	Disbursement	-92.437,99
Okt, 2009	IDAN0310	Disbursement	-39.091,19
Nov, 2009	IDAN0310	Fees			29.005,87
Nov, 2009	IDAN0310	Repayment		81.084,39
Nov, 2009	IDAN0310	Cancellations	170.268,45

Is this an error of the WB? Unlikely, as there are more than 200 Project_id containing negative disbursment amounts. What is your opinion?
*/
drop if transactionvalue<0 //4346 out of 149848 transaction coded as missing (about 3%)

renvars projectid year transactionvalue/  project_id transaction_year transaction_value
keep if financier=="IDA"
keep project_id transaction_year transaction_value
drop if transaction_year!=`i'
egen transaction_value_tot=total(transaction_value), by( project_id)  
label variable transaction_value_tot "Total value per project per year"
* Generate count variable for number of positive project disbursements
gen count=1 if transaction_value>0  
egen Disbursementcount=total(count), by(project_id transaction_year)
label var Disbursementcount "Sum of yearly positive disbursements within project" 
drop transaction_value
/*XXXXXX Melvin 29.12.2017: @Lennart, do you happen to know why some projects 
are not matched? e.g. project P008275 in the year1995 with 6 disbursments.
*/
collapse (mean) transaction_value_tot Disbursementcount, by(project_id transaction_year)

merge 1:m project_id using "$data\Aid\2017_11_14_WB\alg.dta", nogen keep(3 1)

* XXXXXXXXX Lennart 04.01.2018: The part below is to a large extent recoded. Reviewing is, hence, necessary. Thanks!
/* 
Now, allocate aid flows that do not correspond to a certain administrative area in the following way
If there are 
5 locations, where 3 are geocoded on precision level 1-3 and 1 is geocoded on precision level 4, 1 is coded less precisely
Projectsum is X
Take 4/5*X as the amount to be totally allocated, thus 1/5X is lost in the data
Location weighted
- Each of the 3 ADM2 regions coded with precision 1-3  gets 1/5*X
- The ADM1 region coded with precision 4 gets 1/5*X and this is then distributed equally amongst the corresponding ADM2 regions
Pop weighted
- Each of the 3 ADM2 regions coded with precision 1-3 gets Pop(i)/(Sum Pop)*4/5*X 
- The ADM1 region coded with precision 4 gets Pop(i)/(Sum Pop)*4/5*X and this is then distributed equally amongst the corresponding ADM2 regions

An analogous approach is applied to the disbursementcount / transaction count (e.g., the number of projectwise transactions from the IDA account to the project). Although the interpretation might not be intuitive (e.g., a project
with 2 transactions might have 10 locations, so we have a disbursementcount of 0.2), it is most closely comparable to the USD amounts. Alternatively, we could think about numbers of active projects.
Example code
gen temp_totlocation =																//Number of locations of entire project
gen temp_totcoded = 																//Number of locations that are precisely coded (higher than precision level 5)
gen temp_totcoded4 = 																//Number of locations that are precisely coded (precision level 4)
gen temp_totcoded13 = 																//Number of locations that are precisely coded (higher than precision level 4)
gen temp_projsum = temp_totcoded/temp_totlocation*transaction_value_tot				//Total amount of project amount to be allocated to different regions
*/

//temp_totlocation: Number of locations with positive project disbursements for entire project year
gen count=1
egen temp_totlocation=total(count), by(project_id transaction_year)
drop count

//temp_totcoded: Number of locations that are precisely coded (higher than precision level 4)
gen count=1 if precision_N100<=4
egen temp_totcoded=total(count), by(project_id transaction_year)
drop count

//temp_totcoded: Number of locations that are coded with precision 4
gen count=1 if precision_N100==4
egen temp_totcoded4=total(count), by(project_id transaction_year)
drop count

//temp_totcoded: Number of locations that are precisely coded (higher than precision level 4)
gen count=1 if precision_N100<4
egen temp_totcoded13=total(count), by(project_id transaction_year)
drop count

//temp_projsum: Total amount of project amount to be allocated to different regions after discounting for information loss
rename transaction_value_tot temp_value																
gen transaction_value_tot= temp_totcoded/temp_totlocation*temp_value		

* Create sectoral disbursements (& counts)
*XXXXXX Melvin 29.12.2017: @Lennart, what is the purpose of this? Could you comment the steps? e.g. why do disbursemnt count sum up?
* XXXXX Lennart 03.01.2018: @ Melvin: I now coded it as a tempfile, so the transformation stays more tracable 
forvalues g=1(1)5 {
*XXXXXX Melvin 05.01.2018: @Lennart, could you ellaborate on the following line?
gen aux`g'pct=sector`g'pct*transaction_value_tot*0.01
}
* Sum up disbursement amounts of different purposes as these are ranked by percentage share in total disbursement (e.g., sometimes education might be mjsector1 for a schooling project, but for the next project of a new apprenticeship program only mjsector2)
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen Disbursementcount_`g'=0
forvalues t=1(1)5 {
gen aux`t'=0
replace aux`t'=aux`t'pct if mjsector`t'code=="`g'"
replace Disbursementcount_`g'=Disbursementcount_`g'+Disbursementcount if mjsector`t'code=="`g'"
}
* XXXX Lennart 03.01.2018: Add all sectoral shares times total disbursement amount up as we need to go through the whole ranking (e.g., sometimes sanitation is the first sector, but sometimes only the fifth). 
gen transaction_value_tot_`g'=aux1+aux2+aux3+aux4+aux5
drop aux1 aux2 aux3 aux4 aux5
}
drop aux*
save `i'.dta, replace 
}

* Put yearly disbursements together
clear
use 1995.dta, clear
forvalues i=1996(1)2012 {
append using `i'.dta
erase `i'.dta
}
erase 1995.dta

keep if (precision_N100<=4) //note: more than 92% are coded higher than 4 at this stage
sort project_id transaction_year
save "$data\Aid\2017_11_14_WB\IDA_disbursement.dta", replace

********************************************************************************
//2) Prepare location weighted data
********************************************************************************
use "$data\Aid\2017_11_14_WB\IDA_disbursement.dta", clear

cd "$data\Aid\2017_11_14_WB" 
* Execute program to allocate IDA aid
allocAid IDA WBIDA


**********************************************************************	
//3) Prepare population weighted data
*************************************************************************
use "$data\Aid\2017_11_14_WB\IDA_disbursement.dta", replace

	* Merge with Population data
renvars transaction_year ID_adm2 / year rid2
merge m:1 rid2 year using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen keep(1 3)
renvars year rid2 isum_pop / transaction_year ID_adm2 isum_pop_ADM2

*XXXXXX Melvin 02.01.2018: Treat missing ADM2 regions as ADM1 region: Merge ADM1 pop if ADM2 is missing
renvars transaction_year ID_adm1 / year rid1
merge m:1 rid1 year using "$data\ADM\1_1_1_R_pop_GADM1.dta", keep(3) nogen keepusing(isum_pop)


************************

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
merge 1:m ID_adm2 transaction_year using "$data\Aid\2017_11_14_WB\IDA_disbursement.dta"
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
save "$data\Aid\2017_11_14_WB\IDA_disbursement_popweights.dta", replace


**** Generate population weighted data with precision codes 1-3 (ADM2 information) for ADM2 level**** 
keep if precision_N100<4
* XXXXXXXX Lennart 10.01.2018: Allocate aid according to the population of precision-123-locations in total population of project regions //
* For instance 100 [transaction_value_tot] * 10 mio (number of population in this specific region) [wpop] / 100 (number of population in project-regions with precision1-3) [pop_totcoded]
gen transaction_value_pop=transaction_value_tot*(wpop/pop_totcoded)
* XXXXX Lennart 10.01.2018: Accordingly, we also apply this weighting scheme to the disbursementcounts. @ Kai & Melvin: Do you find this sensible? Or should we apply here something like number of active projects per each region.
replace Disbursementcount=Disbursementcount*(wpop/pop_totcoded)
* XXXXX Lennart 10.01.2018: Repeat excercise for sectoral disbursements
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen transaction_value_pop_`g'=transaction_value_tot_`g'*(wpop/pop_totcoded)
replace Disbursementcount_`g'=Disbursementcount_`g'*(wpop/pop_totcoded)
}

* Collapse on ADM2 level to aggregate all project disbursements per ADM2 region
collapse (sum) transaction_value_pop* Disbursementcount*, by(transaction_year ID_0 ID_1 ID_2 ID_adm1 ID_adm2)

* Rename Variables
renvars transaction_value_pop Disbursementcount / WBAID_ADM2_POP13 Disbursementcount_ADM2_POP13
foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars transaction_value_pop_`g' Disbursementcount_`g' / WBAID_ADM2_POP_`g'13 Disbursementcount_ADM2_POP_`g'13
}
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_POP_prec13.dta", replace 


**** Generate population weighted data with precision code 4 (Only ADM1 information) for ADM1 level**** 
use "$data\Aid\2017_11_14_WB\IDA_disbursement_popweights.dta", clear
keep if (precision_N100==4)

* XXXXXXXX Lennart 10.01.2018: Allocate aid according to the population of precision-123-locations in total population of project regions //
* For instance 100 [transaction_value_tot] * 10 mio (number of population in this specific region) [wpop] / 100 (number of population in project-regions with precision1-3) [pop_totcoded]
gen transaction_value_pop=transaction_value_tot*(wpop/pop_totcoded)
* XXXXX Lennart 10.01.2018: Accordingly, we also apply this weighting scheme to the disbursementcounts. @ Kai & Melvin: Do you find this sensible? Or should we apply here something like number of active projects per each region.
replace Disbursementcount=Disbursementcount*(wpop/pop_totcoded)
* XXXXXXX Lennart 10.01.2018: Redo Excercise for sectoral disbursements
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen transaction_value_pop_`g'=transaction_value_tot_`g'*(wpop/pop_totcoded)
replace Disbursementcount_`g'=Disbursementcount_`g'*(wpop/pop_totcoded)
}

collapse (sum) transaction_value_pop* Disbursementcount*, by(transaction_year ID_0 ID_1 ID_adm1)

* Rename Variables
renvars transaction_value_pop Disbursementcount / WBAID_ADM1_POP4 Disbursementcount_ADM1_POP4
foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars transaction_value_pop_`g' Disbursementcount_`g' / WBAID_ADM1_POP_`g'4 Disbursementcount_ADM1_POP_`g'4
}
* Save Dataset
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_POP_prec4.dta", replace

* XXXXX Lennart 11.01.2018: Due to the potential for duplicates and erroneous merges, we go with classical merge-command instead of joinby on a yearly level
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_POP_prec4.dta", clear
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
gen WBAID_ADM2_POP4 =WBAID_ADM1_POP4 *isum_pop_ADM2/isum_pop_ADM1


* XXXXXX Lennart 11.01.2018: Analoguous to the location-weighted aid, disbursement / transaction count is split across locations with population weights.
gen Disbursementcount_ADM2_POP4=Disbursementcount_ADM1_POP4*isum_pop_ADM2/isum_pop_ADM1
*XXXX Lennart 11.01.2018: Redo excercise for sectoral aid
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen WBAID_ADM2_POP_`g'4 =WBAID_ADM1_POP_`g'4  *isum_pop_ADM2/isum_pop_ADM1
gen Disbursementcount_ADM2_POP_`g'4=Disbursementcount_ADM1_POP_`g'4*isum_pop_ADM2/isum_pop_ADM1
drop WBAID_ADM1_POP_`g'4 Disbursementcount_ADM1_POP_`g'4
}
drop WBAID_ADM1_POP4 Disbursementcount_ADM1_POP4
* XXX Lennart 11.01.2018: Save File
save "$data\Aid\2017_11_14_WB\IDA_Disbursement_ADM2_POP_prec4.dta", replace 



* XXXXXXXXXX Lennart 11.01.2018: Merge data with precision code 4 and precision codes 1-3 to create population weighted aid on ADM2 level
use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_POP_prec13.dta", clear

*	XXXXXX Lennart, 11.01.2018: In the following step we drop regions for which no geographic information is available (geo-merge in GIS failed). However, this is not linked to a loss in disbursements as
*  these regions had no aid allocated in any case as we could also not attribute population. In any case, we might want to think about fixing this, because technically these would be recipient regions.
drop if ID_0==0 //No geographic information available for AID projects (Missing Aid information worth about 5bn USD)
	
	
* XXXXX Lennart 11.01.2018: Rename variables with precisioncode 1-3 to prepare them for merge with precisioncode 4
renvars WBAID_ADM2_POP13 Disbursementcount_ADM2_POP13 / WBAID_ADM2_POP Disbursementcount_ADM2_POP
foreach g in AX BX CX EX FX JX LX TX WX YX{
	renvars WBAID_ADM2_POP_`g'13 Disbursementcount_ADM2_POP_`g'13 / WBAID_ADM2_POP_`g'  Disbursementcount_ADM2_POP_`g' 
}

* Add data with precisioncode 4:
merge 1:1 ID_adm2 transaction_year using "$data\Aid\2017_11_14_WB\IDA_Disbursement_ADM2_POP_prec4.dta",  nogen
* Replace missings
replace WBAID_ADM2_POP=0 if WBAID_ADM2_POP==.
replace WBAID_ADM2_POP4=0 if WBAID_ADM2_POP4 ==.
*XXXXXX Melvin 16.01.2018: Added the following line
replace Disbursementcount_ADM2_POP4=0 if Disbursementcount_ADM2_POP4==.
* Add data up
replace WBAID_ADM2_POP=WBAID_ADM2_POP+WBAID_ADM2_POP4 
replace Disbursementcount_ADM2_POP=Disbursementcount_ADM2_POP+Disbursementcount_ADM2_POP4
foreach g in AX BX CX EX FX JX LX TX WX YX{
	* Replace missings
	replace WBAID_ADM2_POP_`g'=0 if WBAID_ADM2_POP_`g'==.
	replace WBAID_ADM2_POP_`g'4=0 if WBAID_ADM2_POP_`g'4 ==.
*XXXXXX Melvin 16.01.2018: Added the following two lines
	replace Disbursementcount_ADM2_POP_`g'4=0 if Disbursementcount_ADM2_POP_`g'4==.
	replace Disbursementcount_ADM2_POP_`g'=0 if Disbursementcount_ADM2_POP_`g'==.
	* Add data up
	replace WBAID_ADM2_POP_`g'=WBAID_ADM2_POP_`g'+WBAID_ADM2_POP_`g'4
	replace Disbursementcount_ADM2_POP_`g'=Disbursementcount_ADM2_POP_`g'+Disbursementcount_ADM2_POP_`g'4
	* Clean
	drop Disbursementcount_ADM2_POP_`g'4 WBAID_ADM2_POP_`g'4
}
drop Disbursementcount_ADM2*4 WBAID_ADM2_POP*4
drop d_miss_ADM2 count
// merge ADM2 names
merge m:1 ID_adm2 using gadm2_ids.dta, nogen keep(1 3)
* Labeling
label var WBAID_ADM2_POP "Value of WB Aid disbursements per ADM2 region(weighted by population of project locations)"
label var Disbursementcount_ADM2_POP " Number of non-negative aid disbursements per region"

foreach g in AX BX CX EX FX JX LX TX WX YX{
	label var Disbursementcount_ADM2_POP_`g' "Number of non-negative aid disbursements per region in sector `g'"
	label var WBAID_ADM2_POP_`g' "Value of WB Aid per ADM2 region in sector `g' (weighted by pop of locations)"
}	

save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_POP.dta", replace
	
	
* XXXXXXX Lennart 11.01.2018: Generate population weighted aid on ADM1 level by collapsing ADM2 level data
collapse (sum) WBAID_ADM2_POP* Disbursementcount_ADM2*, by(transaction_year ID_0 ID_1 ID_adm1)
// merge ADM1 names
merge m:1 ID_adm1 using gadm1_ids.dta, nogen keep(1 3)
* Rename Variables
renvars WBAID_ADM2_POP Disbursementcount_ADM2_POP / WBAID_ADM1_POP Disbursementcount_ADM1_POP

foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM2_POP_`g' Disbursementcount_ADM2_POP_`g' / WBAID_ADM1_POP_`g' Disbursementcount_ADM1_POP_`g'
}

* Labeling
	label var WBAID_ADM1_POP "Value of WB Aid disbursements per ADM1 region(weighted by population of project locations)"
	label var Disbursementcount_ADM1_POP " Number of non-negative aid disbursements per region"

foreach g in AX BX CX EX FX JX LX TX WX YX{
	label var Disbursementcount_ADM1_POP_`g' " Number of non-negative aid disbursements per region in sector `g'"
	label var WBAID_ADM1_POP_`g' "Value of WB Aid per ADM1 region in sector `g' (weighted by pop of  locations)"
	}	
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_POP.dta", replace



	****create balanced dataset without gaps (assumption perfect data on aid flows, that is, if there is no data, then it is not missing but no aid at all, = 0) 
	//ADM2 level
	use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_POP.dta", clear
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
	replace WBAID_ADM2_POP = 0 if WBAID_ADM2_POP ==.
	replace Disbursementcount_ADM2_POP = 0 if Disbursementcount_ADM2_POP ==.
	foreach g in AX BX CX EX FX JX LX TX WX YX{
		replace WBAID_ADM2_POP_`g' = 0 if WBAID_ADM2_POP_`g' ==.
		replace Disbursementcount_ADM2_POP_`g' = 0 if Disbursementcount_ADM2_POP_`g'==.
		}
	drop years_reverse
	order transaction_year ID_adm*
	sort ID_adm* transaction_year
	save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_POP_tsfill.dta", replace
	
	//ADM1 level
	use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_POP.dta", clear
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
	replace WBAID_ADM1_POP = 0 if WBAID_ADM1_POP ==.
	replace Disbursementcount_ADM1_POP = 0 if Disbursementcount_ADM1_POP ==.
	foreach g in AX BX CX EX FX JX LX TX WX YX{
	replace WBAID_ADM1_POP_`g' = 0 if WBAID_ADM1_POP_`g' ==.
	replace Disbursementcount_ADM1_POP_`g' = 0 if Disbursementcount_ADM1_POP_`g'==.
	}
	
	drop years_reverse
	order transaction_year ID_adm*
	sort ID_adm* transaction_year
	save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_POP_tsfill.dta", replace
/* XXXXXXXX Lennart 11.01.2018: We have 100 million more total aid (0.15% of aid)  with population than with location weights. We should at least double check
 use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_POP_tsfill.dta", clear
 egen total=total(WBAID_ADM1_POP)
 sum total
 use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_tsfill.dta", clear
  egen total=total(WBAID_ADM1_LOC)
 sum total
 */


* XXXXXXXX Lennart 11.01.2018 - Clean Up and delete previously created files, which are not needed anymore
	erase "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_prec13.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_prec4.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_prec4.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_POP.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_POP.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_Disbursement_ADM2_POP_prec4.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_Disbursement_ADM2_POP_prec13.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_Disbursement_ADM1_POP_prec4.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_disbursement_popweights.dta"
	erase "$data\Aid\2017_11_14_WB\IDA_disbursement.dta"

































sssssssssssssssssssssss


/*
****************************************************
* Generate location weighted Aid in adjacent regions 
****************************************************
** ADM2
* Load adjacency matrix for ADM2 regions
import excel using "$data\ADM\adm2_neighbors.xls", firstrow clear  //This dataset was created via adjacent_adm_classification.py. We use this adjacency matrix to match each ADM region with the disbursements in adjacent ADM regions.
* Drop Adjacent Regions in other country
drop if src_Name_0C75!= nbr_NAME_0C75
rename nbr_ID_ADMC12 ID_adm2
save "$data\ADM\adm2_neighbors.dta", replace

use "$data\ADM\1_1_1_R_pop_GADM1.dta", clear
renvars year rid1 isum_pop / transaction_year ID_adm1 isum_pop_ADM1
save ADM1POP.dta, replace

use "$data\ADM\1_1_1_R_pop_GADM2.dta", clear
renvars year rid2 isum_pop / transaction_year ID_adm2 isum_pop_ADM2
save ADM2POP.dta, replace


* Merge Adjacency matrix with Aid Disbursements in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_tsfill.dta", clear // The disbursements are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the WB Aid in adjacent regions.
drop if transaction_year!=`i' 
* Mege with adjacent region
merge 1:m ID_adm2 using "$data\ADM\adm2_neighbors.dta", nogen keep(3 1)
* Merge with data on population 
merge m:1 ID_adm2 transaction_year using `ADM2POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) WBAID_ADM2* Disbursementcount* isum_pop_ADM2, by(src_ID_admC12 transaction_year)
renvars isum_pop_ADM2 src_ID_admC12 / Population_ADM2_ADJ ID_adm2
duplicates report ID_adm2
* Rename Variables to indicate that they are in the adjacent regions
renvars WBAID_ADM2 WBAID_ADM2_1loc / WBAID_ADM2_ADJ WBAID_ADM2_1loc_ADJ
rename Disbursementcount_ADM2 Disbursementcount_ADM2_ADJ
foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM2_`g' WBAID_ADM2_1loc_`g' / WBAID_ADM2_ADJ_`g'  WBAID_ADM2_1loc_ADJ_`g'
rename Disbursementcount_ADM2_`g' Disbursementcount_ADM2_ADJ_`g'
}
tempfile `i'
save `i', replace 
}
* Put yearly disbursements in adjacent regions together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'
}

keep ID_adm2 WBAID_ADM2_*ADJ* Population_ADM2_ADJ transaction_year Disbursementcount_ADM2*

* Merge Disbursement file with Disbursements in adjacent ADM2 regions
merge 1:1 ID_adm2 transaction_year using "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_tsfill.dta", nogen keep(2 3)  
* Label variables
label var Population_ADM2_ADJ "Population in all adjacent ADM2 Regions"
label var WBAID_ADM2_ADJ "World Bank aid in all adjacent ADM2 regions"
label var WBAID_ADM2_1loc_ADJ "World Bank aid allocated to only 1 project location in all adjacent ADM2 regions"
label var Disbursementcount_ADM2_ADJ "No. of non-negative WB aid disbursements in adjacent ADM2 regions"
foreach g in AX BX CX EX FX JX LX TX WX YX{
label var WBAID_ADM2_ADJ_`g' "World Bank aid in all adjacent ADM2 regions in sector `g'"
label var WBAID_ADM2_1loc_ADJ_`g' "World Bank aid allocated to only 1 project location in all adjacent ADM2 regions in sector `g'"
label var Disbursementcount_ADM2_ADJ_`g' "No. of non-negative WB aid disbursements in adjacent ADM2 regions in sector `g'"
}
* Rename Variables as location weighted
renvars WBAID_ADM2 WBAID_ADM2_ADJ / WBAID_ADM2_LOC WBAID_ADM2_LOC_ADJ
foreach x in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM2_`x' WBAID_ADM2_ADJ_`x' / WBAID_ADM2_LOC_`x' WBAID_ADM2_LOC_ADJ_`x'
}
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_adjacent.dta", replace 


** ADM1
* Load adjacency matrix for ADM1 regions
import excel using "$data\ADM\adm1_neighbors.xls", firstrow clear
renvars src_ID_0N100 src_ID_1N100  nbr_ID_0N100 nbr_ID_1N100 / src_id_0 src_id_1 nbr_id_0 nbr_id_1
*create unique region ids
gen c = "c"
gen r = "r"
egen src_ID_admC7 = concat(c src_id_0 r src_id_1)
egen nbr_ID_admC7 = concat(c nbr_id_0 r nbr_id_1)
drop c r
rename nbr_ID_admC7 ID_adm1

* Drop Adjacent Regions in other country
drop if src_Name_0C75!= nbr_NAME_0C75
save "$data\ADM\adm1_neighbors.dta", replace

* Merge Adjacency matrix with Aid Disbursements in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_tsfill.dta", clear     // The disbursements are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the WB Aid in adjacent regions.         
drop if transaction_year!=`i'
* Merge with adjacent regions						
merge 1:m ID_adm1 using "$data\ADM\adm1_neighbors.dta", nogen keep(1 3)
* Merge with population Data
merge m:1 ID_adm1 transaction_year using `ADM1POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) WBAID_ADM1* Disbursementcount* isum_pop_ADM1, by(src_ID_admC7 transaction_year)
* Rename Variables to indicate that they are in the adjacent regions
renvars isum_pop_ADM1 src_ID_admC7 / Population_ADM1_ADJ ID_adm1
renvars WBAID_ADM1 WBAID_ADM1_1loc / WBAID_ADM1_ADJ WBAID_ADM1_1loc_ADJ
rename Disbursementcount_ADM1 Disbursementcount_ADM1_ADJ
foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM1_`g' WBAID_ADM1_1loc_`g' / WBAID_ADM1_ADJ_`g'  WBAID_ADM1_1loc_ADJ_`g'
rename Disbursementcount_ADM1_`g' Disbursementcount_ADM1_ADJ_`g'
}
save `i'.dta, replace 
}
* Put yearly disbursements together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'.dta
erase `i'.dta
}
erase 1995.dta
keep ID_adm1 WBAID_ADM1_*ADJ*  Disbursementcount* transaction_year Population_ADM1_ADJ
* Merge Disbursement file with Disbursements in adjacent ADM1 regions
merge 1:m ID_adm1 transaction_year using "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_tsfill.dta", nogen keep(2 3)
* Label all variables
label var Population_ADM1_ADJ "Population in neighboring regions"
label var WBAID_ADM1_ADJ "World Bank aid in all adjacent ADM1 regions"
label var WBAID_ADM1_1loc_ADJ "World Bank aid allocated to only 1 project location in all adjacent ADM2 regions"
label var Disbursementcount_ADM1_ADJ "No. of non-negative WB aid disbursements in adjacent ADM1 regions"
foreach g in AX BX CX EX FX JX LX TX WX YX{
label var WBAID_ADM1_ADJ_`g' "World Bank aid in all adjacent ADM1 regions in sector `g'"
label var WBAID_ADM1_1loc_ADJ_`g' "World Bank aid allocated to only 1 project in all adjacent ADM1 regions in sector `g'"
label var Disbursementcount_ADM1_ADJ_`g' "No. of non-negative WB aid disbursements in adjacent ADM1 regions in sector `g'"
}
* Rename Variables as location weighted
renvars WBAID_ADM1 WBAID_ADM1_ADJ / WBAID_ADM1_LOC WBAID_ADM1_LOC_ADJ
foreach x in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM1_`x' WBAID_ADM1_ADJ_`x' / WBAID_ADM1_LOC_`x' WBAID_ADM1_LOC_ADJ_`x'
}
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_adjacent.dta", replace


****************************************************
* Generate population weighted Aid in adjacent regions 
****************************************************
** ADM2

* Merge Adjacency matrix with Aid Disbursements in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_Wpop.dta", clear // The disbursements are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the WB Aid in adjacent regions.
drop if transaction_year!=`i' 
* Mege with adjacent region
merge 1:m ID_adm2 using "$data\ADM\adm2_neighbors.dta", nogen keep(3 1)
* Merge with population Data
merge m:1 ID_adm2 transaction_year using `ADM2POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) WBAID_ADM2* Disbursementcount* isum_pop_ADM2, by(src_ID_admC12 transaction_year)
renvars isum_pop_ADM2 src_ID_admC12 / Population_ADM2_ADJ ID_adm2
duplicates report ID_adm2
* Rename Variables to indicate that they are in the adjacent regions
rename WBAID_ADM2_Wpop WBAID_ADM2_Wpop_ADJ
rename Disbursementcount_ADM2 Disbursementcount_ADM2_ADJ
foreach g in AX BX CX EX FX JX LX TX WX YX{
rename WBAID_ADM2_Wpop_`g' WBAID_ADM2_Wpop_ADJ_`g'
rename Disbursementcount_ADM2_`g' Disbursementcount_ADM2_ADJ_`g'
}
save `i'.dta, replace 
}
* Put yearly disbursements in adjacent regions together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'.dta
erase `i'.dta
}
erase 1995.dta

keep ID_adm2 WBAID_ADM2_Wpop_ADJ* transaction_year Disbursementcount_ADM2* Population_ADM2_ADJ

* Merge Disbursement file with Disbursements in adjacent ADM2 regions
merge 1:1 ID_adm2 transaction_year using "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_Wpop.dta", nogen keep(2 3)  
* Label variables
label var Population_ADM2_ADJ "Population in neighboring regions"
label var WBAID_ADM2_Wpop_ADJ "Pop. weighted World Bank aid in all adjacent ADM2 regions"
label var Disbursementcount_ADM2_ADJ "No. of non-negative WB aid disbursements in adjacent ADM2 regions"
foreach g in AX BX CX EX FX JX LX TX WX YX{
label var WBAID_ADM2_Wpop_ADJ "Pop. Weighted World Bank aid in all adjacent ADM2 regions in sector `g'"
label var Disbursementcount_ADM2_`g' "No. of non-negative WB aid disbursements in adjacent ADM2 regions in sector `g'"
}
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_Wpop_adjacent.dta", replace 


** ADM1

* Merge Adjacency matrix with Aid Disbursements in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_Wpop.dta", clear     // The disbursements are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the WB Aid in adjacent regions.         
drop if transaction_year!=`i'
* Merge with adjacent regions						
merge 1:m ID_adm1 using "$data\ADM\adm1_neighbors.dta", nogen keep(1 3)
* Merge with population Data
merge m:1 ID_adm1 transaction_year using `ADM1POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) WBAID_ADM1* Disbursementcount* isum_pop_ADM1, by(src_ID_admC7 transaction_year)
* Rename Variables to indicate that they are in the adjacent regions
rename src_ID_admC7 ID_adm1
renvars isum_pop_ADM1 WBAID_ADM1_Wpop / Population_ADM1_ADJ WBAID_ADM1_Wpop_ADJ
rename Disbursementcount_ADM1 Disbursementcount_ADM1_ADJ
foreach g in AX BX CX EX FX JX LX TX WX YX{
rename WBAID_ADM1_Wpop_`g' WBAID_ADM1_Wpop_ADJ_`g'
rename Disbursementcount_ADM1_`g' Disbursementcount_ADM1_ADJ_`g'
}
save `i'.dta, replace 
}
* Put yearly disbursements together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'.dta
erase `i'.dta
}
erase 1995.dta

keep ID_adm1 WBAID_ADM1_Wpop_ADJ*  Disbursementcount* transaction_year Population_ADM1_ADJ
* Merge Disbursement file with Disbursements in adjacent ADM1 regions
merge 1:m ID_adm1 transaction_year using "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_Wpop.dta", nogen keep(2 3)
* Label all variables
label var Population_ADM1_ADJ "Population in neighboring regions"
label var WBAID_ADM1_Wpop_ADJ "Pop. Weighted World Bank aid in all adjacent ADM1 regions"
label var Disbursementcount_ADM1_ADJ "No. of non-negative WB aid disbursements in adjacent ADM1 regions"
foreach g in AX BX CX EX FX JX LX TX WX YX{
label var WBAID_ADM1_Wpop_ADJ_`g' "Pop. Weighted World Bank aid in all adjacent ADM1 regions in sector `g'"
label var Disbursementcount_ADM1_ADJ_`g' "No. of non-negative WB aid disbursements in adjacent ADM1 regions in sector `g'"
}
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_Wpop_adjacent.dta", replace
*/

*******************************
* B: Create IBRD Finance Data *
*******************************


cd "$data\Aid\2017_11_14_WB"

*XXXXXX Melvin 09.01.2018: Copied the whole section from IDA above
* Create yearly disbursements (only until 2012 as we do not have disbursement data in subsequent years)
forvalues i=1995(1)2012 {
import excel "$data\Aid\IDA_IBRD_transactions.xlsx", firstrow clear

drop if transactionvalue<0 //4346 out of 149848 transaction coded as missing (about 3%)

renvars projectid year transactionvalue/  project_id transaction_year transaction_value
keep if financier=="IBRD"
keep project_id transaction_year transaction_value
drop if transaction_year!=`i'
egen transaction_value_tot=total(transaction_value), by( project_id)  
label variable transaction_value_tot "Total value per project per year"
* Generate count variable for number of positive project disbursements
gen count=1 if transaction_value>0  
egen Disbursementcount=total(count), by(project_id transaction_year)
label var Disbursementcount "Sum of yearly positive disbursements within project" 
drop transaction_value

collapse (mean) transaction_value_tot Disbursementcount, by(project_id transaction_year)
merge 1:m project_id using "$data\Aid\2017_11_14_WB\alg.dta", nogen keep(3 1)

//temp_totlocation: Number of locations with positive project disbursements for entire project year
gen count=1
egen temp_totlocation=total(count), by(project_id transaction_year)
drop count

//temp_totcoded: Number of locations that are precisely coded (higher than precision level 4)
gen count=1 if precision_N100<=4
egen temp_totcoded=total(count), by(project_id transaction_year)
drop count

//temp_totcoded: Number of locations that are coded with precision 4
gen count=1 if precision_N100==4
egen temp_totcoded4=total(count), by(project_id transaction_year)
drop count

//temp_totcoded: Number of locations that are precisely coded (higher than precision level 4)
gen count=1 if precision_N100<4
egen temp_totcoded13=total(count), by(project_id transaction_year)
drop count

//temp_projsum: Total amount of project amount to be allocated to different regions after discounting for information loss
rename transaction_value_tot temp_value																
gen transaction_value_tot= temp_totcoded/temp_totlocation*temp_value		

* Create sectoral disbursements (& counts)
forvalues g=1(1)5 {
gen aux`g'pct=sector`g'pct*transaction_value_tot*0.01
}
* Sum up disbursement amounts of different purposes as these are ranked by percentage share in total disbursement (e.g., sometimes education might be mjsector1 for a schooling project, but for the next project of a new apprenticeship program only mjsector2)
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen Disbursementcount_`g'=0
forvalues t=1(1)5 {
gen aux`t'=0
replace aux`t'=aux`t'pct if mjsector`t'code=="`g'"
replace Disbursementcount_`g'=Disbursementcount_`g'+Disbursementcount if mjsector`t'code=="`g'"
}
* Add all sectoral shares times total disbursement amount up as we need to go through the whole ranking (e.g., sometimes sanitation is the first sector, but sometimes only the fifth). 
gen transaction_value_tot_`g'=aux1+aux2+aux3+aux4+aux5
drop aux1 aux2 aux3 aux4 aux5
}
drop aux*
save `i'.dta, replace 
}

* Put yearly disbursements together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'.dta
erase `i'.dta
}
erase 1995.dta
keep if (precision_N100<=4)
sort project_id transaction_year
save "$data\Aid\2017_11_14_WB\IBRD_disbursement.dta", replace


* Execute program to allocate IBRD aid
allocAid IBRD WBIBRD







	
	

	

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
********************************************************************************
//Generate regional shares weighted by population in region (GADM1)
/*
Outline on how to weight aid data by population:
1. Merge pop data to each individual project id for each year
2. Create a weight (pop_i/sum_pop) BY project_id. This is important. Different
project take place at different region pairs. The pop_share has to be calculated
for each regional pairs
2a. create total population by project id, but acconting for the possibility, that
project location occur mulitple times within the same region (need to avoid double
counting of that region in the total_pop
2b. Generate a new weighted aid variable (project_value*region_share)
3. Collapse transaction value by GADM1 region
*/
********************************************************************************
use "$data\Aid\2017_11_14_WB\IBRD_disbursement.dta", clear
drop if ID_0N100==.
drop if ID_0N100==0
drop if ID_1N100==.
drop if ID_1N100==0
save "$data\Aid\2017_11_14_WB\IBRD_temp1.dta", replace   




//1. merge
use "$data\ADM\1_1_1_R_pop_GADM1.dta", clear

rename rid1 ID_adm1
rename year transaction_year
rename isum_pop isum_pop_ADM1
keep if transaction_year>=1995 & transaction_year<=2014

merge 1:m ID_adm1 transaction_year using "$data\Aid\2017_11_14_WB\IBRD_temp1.dta"      
/*
Remarks to the merge: Mismatch in using data, as no pop has been calculated for Russia (see tab ADM0 if _merge==2)
Mismatch from master, because no aid data. Non critical unmatached obs
@Melvin: Discuss. Not problematic?
MW: Technically, you are correct. Sorry, that I have not written this part out directly. If you look at the file 3_merge…..do you will see that there is always one line stating “DO NOT "drop if _merge!=3"”. If there is no aid data, the observations are dropped first. They should not be included in the aid calculation, because they never received aid (e.g. aid probability is 0). Thus, only in step 3_merge….do, the missing regions are attached back to the data set.
*/
drop if _merge!=3
drop _merge

*2a. Create a weight (pop_i/sum_pop) BY project_id without double counting of regions to distribute the non geolocated aid projects to the adm1 and 2 regions
//MW: need to check this again.
*preserve
*duplicates tag project_id transaction_year ID_adm1, gen(tag)
*drop tag
*duplicates drop project_id transaction_year ID_adm1, force //to avoid double counting of regions. @Melvin: Have you checked that this works by hand? Due to the preserve, I cannot check it. Please make sure this works correctly!

sort project_id transaction_year
bysort project_id transaction_year: egen pop_projects_ADM1=total(isum_pop_ADM1) //create total pop of regions for each project_id and year



*keep project_id transaction_year ID_adm1 pop_projects ISO3 ADM0 ADM1
*save temp2.dta, replace
*restore

//2b. Generate a new weighted aid variable (project_value*region_pop_share)
*merge m:1 project_id transaction_year ID_adm1 using "temp2.dta"
//perfect match
*drop _merge
gen WBAID_ADM1_Wpop = (transaction_value_tot*isum_pop_ADM1)/pop_projects_ADM1
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen WBAID_ADM1_Wpop_`g'=(transaction_value_tot_`g'*isum_pop_ADM1)/pop_projects_ADM1
}

//3. Collapse transaction value by GADM1 region
collapse (sum) WBAID_ADM1_Wpop* Disbursementcount*, by(ID_adm1 transaction_year)
// merge ADM1 names
merge m:1 ID_adm1 using gadm1_ids.dta, nogen keep(1 3)

* Rename and label Disbursementcounts
rename Disbursementcount Disbursementcount_ADM1
label var Disbursementcount_ADM1 "No of positive yearly disbursements  per ADM1 region"

foreach g in AX BX CX EX FX JX LX TX WX YX{
rename Disbursementcount_`g' Disbursementcount_ADM1_`g'
label var Disbursementcount_ADM1_`g' "No of positive yearly disbursements in sector `g' per ADM1 region"
}

* Add data based on precision codes 4:
merge 1:1 ID_adm1 transaction_year using IDA_disbursement_ADM1_Wpop_prec4.dta, nogen
replace WBAID_ADM1_Wpop=0 if WBAID_ADM1_Wpop==.
replace WBAID_ADM1_Wpop4=0 if WBAID_ADM1_Wpop4==.
replace WBAID_ADM1_Wpop=WBAID_ADM1_Wpop+WBAID_ADM1_Wpop4
replace Disbursementcount_ADM1=Disbursementcount_ADM1+Disbursementcount_ADM14
foreach g in AX BX CX EX FX JX LX TX WX YX{
replace WBAID_ADM1_Wpop_`g'=0 if WBAID_ADM1_Wpop_`g'==.
replace WBAID_ADM1_Wpop_`g'4=0 if WBAID_ADM1_Wpop_`g'4==.
replace WBAID_ADM1_Wpop_`g'=WBAID_ADM1_Wpop_`g'+WBAID_ADM1_Wpop_`g'4
replace Disbursementcount_ADM1_`g'=Disbursementcount_ADM1_`g'+Disbursementcount_ADM1_`g'4
drop Disbursementcount_ADM1_`g'4 WBAID_ADM1_Wpop_`g'4
}
drop Disbursementcount_ADM14 WBAID_ADM1_Wpop4



//4. fill out gaps in between data
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
replace WBAID_ADM1_Wpop = 0 if WBAID_ADM1_Wpop ==.
replace Disbursementcount_ADM1=0 if Disbursementcount_ADM1 == .
foreach g in AX BX CX EX FX JX LX TX WX YX{
	replace WBAID_ADM1_Wpop_`g' = 0 if WBAID_ADM1_Wpop_`g' ==.
	replace Disbursementcount_ADM1_`g'=0 if Disbursementcount_ADM1_`g'==.
	}
drop years_reverse ID_adm1_num
sort ID_adm* transaction_year

save "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM1_Wpop.dta", replace

erase "$data\Aid\2017_11_14_WB\IBRD_temp1.dta"

********************************************************************************
//Generate regional shares weighted by population in region (GADM2)
********************************************************************************
use "$data\Aid\2017_11_14_WB\IBRD_disbursement.dta", clear
drop if ID_0N100==.
drop if ID_0N100==0
drop if ID_1N100==.
drop if ID_1N100==0
drop if ID_2N100==.
drop if ID_2N100==0
save "$data\Aid\2017_11_14_WB\IBRD_temp1.dta", replace

//1. merge
use "$data\ADM\1_1_1_R_pop_GADM2.dta", clear

rename rid2 ID_adm2
rename year transaction_year
rename isum_pop isum_pop_ADM2
keep if transaction_year>=1995 & transaction_year<=2014

merge 1:m ID_adm2 transaction_year using "$data\Aid\2017_11_14_WB\IBRD_temp1.dta"
/*
Remarks to the merge: Mismatch in using data, as no pop has been calculated too small regions (see tab ADM0 if _merge==2)
Mismatch from master, because no aid data. Non critical unmatached obs
*/
drop if _merge!=3
drop _merge



//2a. Create a weight (pop_i/sum_pop) BY project_id without double counting of regions

sort project_id transaction_year
bysort project_id transaction_year: egen pop_projects_ADM2=total(isum_pop_ADM2) //create total pop of regions for each project_id and year

* Generate population weighted aid disbursements per project location
gen WBAID_ADM2_Wpop = (transaction_value_tot*isum_pop_ADM2)/pop_projects_ADM2
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen WBAID_ADM2_Wpop_`g' = (transaction_value_tot_`g'*isum_pop_ADM2)/pop_projects_ADM2
}
//3. Collapse transaction value by GADM1 region
collapse (sum) WBAID_ADM2_Wpop* Disbursementcount*, by(ID_adm2 transaction_year)
// merge ADM2 names
merge m:1 ID_adm2 using gadm2_ids.dta, nogen keep(1 3)

rename Disbursementcount Disbursementcount_ADM2
label var Disbursementcount_ADM2 "No of positive yearly disbursements per ADM1 region"

foreach g in AX BX CX EX FX JX LX TX WX YX{
rename Disbursementcount_`g' Disbursementcount_ADM2_`g'
label var Disbursementcount_ADM2_`g' "No of positive yearly disbursements in sector `g' per ADM1 region"
}

	* Add data with precision code 4
	merge 1:1 ID_adm2 transaction_year using IDA_disbursement_ADM2_Wpop_prec4.dta, nogen
	replace WBAID_ADM2_Wpop=0 if WBAID_ADM2_Wpop==.
	replace WBAID_ADM2_Wpop4=0 if WBAID_ADM2_Wpop4==.
	replace WBAID_ADM2_Wpop=WBAID_ADM2_Wpop+WBAID_ADM2_Wpop4
	replace Disbursementcount_ADM2=Disbursementcount_ADM2+Disbursementcount_ADM24
foreach g in AX BX CX EX FX JX LX TX WX YX{
	replace WBAID_ADM2_Wpop_`g'=0 if WBAID_ADM2_Wpop_`g'==.
	replace WBAID_ADM2_Wpop_`g'4=0 if WBAID_ADM2_Wpop_`g'4==.
		replace WBAID_ADM2_Wpop_`g'=WBAID_ADM2_Wpop_`g'+WBAID_ADM2_Wpop_`g'4
		replace Disbursementcount_ADM2_`g'=Disbursementcount_ADM2_`g'+Disbursementcount_ADM2_`g'4
		drop Disbursementcount_ADM2_`g'4 WBAID_ADM2_Wpop_`g'4
		}
	drop Disbursementcount_ADM2*4 WBAID_ADM2_Wpop*4


//4. fill out gaps in between data
sort ID_adm2 transaction_year
egen ID_adm2_num = group(ID_adm2)
//Melvin H.L. Wong: 2. tsset Geounit Jahr
tsset ID_adm2_num transaction_year
//Melvin H.L. Wong: 3. tsfill, full
tsfill, full //fill out data gaps
gen years_reverse =-transaction_year
//Melvin H.L. Wong: 4. carryforward, countryname etc
bysort ID_adm2_num (transaction_year): carryforward ID_adm* ADM* ISO3 ID_*, replace 
bysort ID_adm2_num (years_reverse): carryforward ID_adm* ADM* ISO3 ID_*, replace
//Melvin H.L. Wong: 5. replace Aidvvar= 0 if Aidvar==.
replace WBAID_ADM2_Wpop = 0 if WBAID_ADM2_Wpop ==.
replace Disbursementcount_ADM2= 0 if Disbursementcount_ADM2 ==.
foreach g in AX BX CX EX FX JX LX TX WX YX{
replace WBAID_ADM2_Wpop_`g'= 0 if WBAID_ADM2_Wpop_`g' ==.
replace Disbursementcount_ADM2_`g'=0 if Disbursementcount_ADM2_`g'==.
}	
drop years_reverse ID_adm2_num
sort ID_adm* transaction_year

save "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM2_Wpop.dta", replace



* Creat ADM1 level data
use "$data\ADM\1_1_1_R_pop_GADM1.dta", clear

rename rid1 ID_adm1
rename year transaction_year
rename isum_pop isum_pop_ADM1
keep if transaction_year>=1995 & transaction_year<=2014

merge 1:m ID_adm1 transaction_year using "$data\Aid\2017_11_14_WB\IBRD_temp1.dta"
/*
Remarks to the merge: Mismatch in using data, as no pop has been calculated too small regions (see tab ADM0 if _merge==2)
Mismatch from master, because no aid data. Non critical unmatached obs
*/
drop if _merge!=3
drop _merge



//2a. Create a weight (pop_i/sum_pop) BY project_id without double counting of regions

sort project_id transaction_year
bysort project_id transaction_year: egen pop_projects_ADM1=total(isum_pop_ADM1) //create total pop of regions for each project_id and year

* Generate population weighted aid disbursements per project location
gen WBAID_ADM1_Wpop = (transaction_value_tot*isum_pop_ADM1)/pop_projects_ADM1
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen WBAID_ADM1_Wpop_`g' = (transaction_value_tot_`g'*isum_pop_ADM1)/pop_projects_ADM1
}
//3. Collapse transaction value by GADM1 region
collapse (sum) WBAID_ADM1_Wpop* Disbursementcount*, by(ID_adm1 transaction_year)
// merge ADM1 names
merge m:1 ID_adm1 using gadm1_ids.dta, nogen keep(1 3)

rename Disbursementcount Disbursementcount_ADM1
label var Disbursementcount_ADM1 "No of positive yearly disbursements per ADM1 region"

foreach g in AX BX CX EX FX JX LX TX WX YX{
rename Disbursementcount_`g' Disbursementcount_ADM1_`g'
label var Disbursementcount_ADM1_`g' "No of positive yearly disbursements in sector `g' per ADM1 region"
}

	* Add data with precision code 4
	merge 1:1 ID_adm1 transaction_year using `Disbursement_ADM1_Wpop_prec4', nogen
	replace WBAID_ADM1_Wpop=0 if WBAID_ADM1_Wpop==.
	replace WBAID_ADM1_Wpop4=0 if WBAID_ADM1_Wpop4==.
	replace WBAID_ADM1_Wpop=WBAID_ADM1_Wpop+WBAID_ADM1_Wpop4
	replace Disbursementcount_ADM1=Disbursementcount_ADM1+Disbursementcount_ADM14
foreach g in AX BX CX EX FX JX LX TX WX YX{
	replace WBAID_ADM1_Wpop_`g'=0 if WBAID_ADM1_Wpop_`g'==.
	replace WBAID_ADM1_Wpop_`g'4=0 if WBAID_ADM1_Wpop_`g'4==.
		replace WBAID_ADM1_Wpop_`g'=WBAID_ADM1_Wpop_`g'+WBAID_ADM1_Wpop_`g'4
		replace Disbursementcount_ADM1_`g'=Disbursementcount_ADM1_`g'+Disbursementcount_ADM1_`g'4
		drop Disbursementcount_ADM1_`g'4 WBAID_ADM1_Wpop_`g'4
		}
	drop Disbursementcount_ADM1*4 WBAID_ADM1_Wpop*4


//4. fill out gaps in between data
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
replace WBAID_ADM1_Wpop = 0 if WBAID_ADM1_Wpop ==.
replace Disbursementcount_ADM1= 0 if Disbursementcount_ADM1 ==.
foreach g in AX BX CX EX FX JX LX TX WX YX{
replace WBAID_ADM1_Wpop_`g'= 0 if WBAID_ADM1_Wpop_`g' ==.
replace Disbursementcount_ADM1_`g'=0 if Disbursementcount_ADM1_`g'==.
}	
drop years_reverse ID_adm1_num
sort ID_adm* transaction_year

erase "$data\Aid\2017_11_14_WB\IBRD_temp1.dta"
 save "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM1_Wpop.dta", replace

/*
****************************************************
* Generate location weighted Aid in adjacent regions 
****************************************************
** ADM2
* Load adjacency matrix for ADM2 regions
import excel using "$data\ADM\adm2_neighbors.xls", firstrow clear  //This dataset was created via adjacent_adm_classification.py. We use this adjacency matrix to match each ADM region with the disbursements in adjacent ADM regions.
* Drop Adjacent Regions in other country
drop if src_Name_0C75!= nbr_NAME_0C75
rename nbr_ID_ADMC12 ID_adm2
save "$data\ADM\adm2_neighbors.dta", replace

use "$data\ADM\1_1_1_R_pop_GADM1.dta", clear
renvars year rid1 isum_pop / transaction_year ID_adm1 isum_pop_ADM1
save ADM1POP.dta, replace

use "$data\ADM\1_1_1_R_pop_GADM2.dta", clear
renvars year rid2 isum_pop / transaction_year ID_adm2 isum_pop_ADM2
save ADM2POP.dta, replace

* Merge Adjacency matrix with Aid Disbursements in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM2_tsfill.dta", clear // The disbursements are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the WB Aid in adjacent regions.
drop if transaction_year!=`i' 
* Mege with adjacent region
merge 1:m ID_adm2 using "$data\ADM\adm2_neighbors.dta", nogen keep(3 1)
* Merge with data on population 
merge m:1 ID_adm2 transaction_year using `ADM2POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) WBAID_ADM2* Disbursementcount* isum_pop_ADM2, by(src_ID_admC12 transaction_year)
renvars isum_pop_ADM2 src_ID_admC12 / Population_ADM2_ADJ ID_adm2
duplicates report ID_adm2
* Rename Variables to indicate that they are in the adjacent regions
renvars WBAID_ADM2 WBAID_ADM2_1loc / WBAID_ADM2_ADJ WBAID_ADM2_1loc_ADJ
rename Disbursementcount_ADM2 Disbursementcount_ADM2_ADJ
foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM2_`g' WBAID_ADM2_1loc_`g' / WBAID_ADM2_ADJ_`g'  WBAID_ADM2_1loc_ADJ_`g'
rename Disbursementcount_ADM2_`g' Disbursementcount_ADM2_ADJ_`g'
}
save `i'.dta, replace 
}
* Put yearly disbursements in adjacent regions together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'.dta
erase `i'.dta
}
erase 1995.dta

keep ID_adm2 WBAID_ADM2_*ADJ* Population_ADM2_ADJ transaction_year Disbursementcount_ADM2*

* Merge Disbursement file with Disbursements in adjacent ADM2 regions
merge 1:1 ID_adm2 transaction_year using "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM2_tsfill.dta", nogen keep(2 3)  
* Label variables
label var Population_ADM2_ADJ "Population in all adjacent ADM2 Regions"
label var WBAID_ADM2_ADJ "World Bank aid in all adjacent ADM2 regions"
label var WBAID_ADM2_1loc_ADJ "World Bank aid allocated to only 1 project location in all adjacent ADM2 regions"
label var Disbursementcount_ADM2_ADJ "No. of non-negative WB aid disbursements in adjacent ADM2 regions"
foreach g in AX BX CX EX FX JX LX TX WX YX{
label var WBAID_ADM2_ADJ_`g' "World Bank aid in all adjacent ADM2 regions in sector `g'"
label var WBAID_ADM2_1loc_ADJ_`g' "World Bank aid allocated to only 1 project location in all adjacent ADM2 regions in sector `g'"
label var Disbursementcount_ADM2_ADJ_`g' "No. of non-negative WB aid disbursements in adjacent ADM2 regions in sector `g'"
}
* Rename Variables as location weighted
renvars WBAID_ADM2 WBAID_ADM2_ADJ / WBAID_ADM2_LOC WBAID_ADM2_LOC_ADJ
foreach x in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM2_`x' WBAID_ADM2_ADJ_`x' / WBAID_ADM2_LOC_`x' WBAID_ADM2_LOC_ADJ_`x'
}
save "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM2_adjacent.dta", replace 


** ADM1
* Load adjacency matrix for ADM1 regions
import excel using "$data\ADM\adm1_neighbors.xls", firstrow clear
renvars src_ID_0N100 src_ID_1N100  nbr_ID_0N100 nbr_ID_1N100 / src_id_0 src_id_1 nbr_id_0 nbr_id_1
*create unique region ids
gen c = "c"
gen r = "r"
egen src_ID_admC7 = concat(c src_id_0 r src_id_1)
egen nbr_ID_admC7 = concat(c nbr_id_0 r nbr_id_1)
drop c r
rename nbr_ID_admC7 ID_adm1

* Drop Adjacent Regions in other country
drop if src_Name_0C75!= nbr_NAME_0C75
save "$data\ADM\adm1_neighbors.dta", replace

* Merge Adjacency matrix with Aid Disbursements in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM1_tsfill.dta", clear     // The disbursements are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the WB Aid in adjacent regions.         
drop if transaction_year!=`i'
* Merge with adjacent regions						
merge 1:m ID_adm1 using "$data\ADM\adm1_neighbors.dta", nogen keep(1 3)
* Merge with population Data
merge m:1 ID_adm1 transaction_year using `ADM1POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) WBAID_ADM1* Disbursementcount* isum_pop_ADM1, by(src_ID_admC7 transaction_year)
* Rename Variables to indicate that they are in the adjacent regions
renvars isum_pop_ADM1 src_ID_admC7 / Population_ADM1_ADJ ID_adm1
renvars WBAID_ADM1 WBAID_ADM1_1loc / WBAID_ADM1_ADJ WBAID_ADM1_1loc_ADJ
rename Disbursementcount_ADM1 Disbursementcount_ADM1_ADJ
foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM1_`g' WBAID_ADM1_1loc_`g' / WBAID_ADM1_ADJ_`g'  WBAID_ADM1_1loc_ADJ_`g'
rename Disbursementcount_ADM1_`g' Disbursementcount_ADM1_ADJ_`g'
}
save `i'.dta, replace 
}
* Put yearly disbursements together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'.dta
erase `i'.dta
}
erase 1995.dta

keep ID_adm1 WBAID_ADM1_*ADJ*  Disbursementcount* transaction_year Population_ADM1_ADJ
* Merge Disbursement file with Disbursements in adjacent ADM1 regions
merge 1:m ID_adm1 transaction_year using "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM1_tsfill.dta", nogen keep(2 3)
* Label all variables
label var Population_ADM1_ADJ "Population in neighboring regions"
label var WBAID_ADM1_ADJ "World Bank aid in all adjacent ADM1 regions"
label var WBAID_ADM1_1loc_ADJ "World Bank aid allocated to only 1 project location in all adjacent ADM2 regions"
label var Disbursementcount_ADM1_ADJ "No. of non-negative WB aid disbursements in adjacent ADM1 regions"
foreach g in AX BX CX EX FX JX LX TX WX YX{
label var WBAID_ADM1_ADJ_`g' "World Bank aid in all adjacent ADM1 regions in sector `g'"
label var WBAID_ADM1_1loc_ADJ_`g' "World Bank aid allocated to only 1 project in all adjacent ADM1 regions in sector `g'"
label var Disbursementcount_ADM1_ADJ_`g' "No. of non-negative WB aid disbursements in adjacent ADM1 regions in sector `g'"
}
* Rename Variables as location weighted
renvars WBAID_ADM1 WBAID_ADM1_ADJ / WBAID_ADM1_LOC WBAID_ADM1_LOC_ADJ
foreach x in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM1_`x' WBAID_ADM1_ADJ_`x' / WBAID_ADM1_LOC_`x' WBAID_ADM1_LOC_ADJ_`x'
}
save "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM1_adjacent.dta", replace


****************************************************
* Generate population weighted Aid in adjacent regions 
****************************************************
** ADM2

* Merge Adjacency matrix with Aid Disbursements in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM2_Wpop.dta", clear // The disbursements are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the WB Aid in adjacent regions.
drop if transaction_year!=`i' 
* Mege with adjacent region
merge 1:m ID_adm2 using "$data\ADM\adm2_neighbors.dta", nogen keep(3 1)
* Merge with population Data
merge m:1 ID_adm2 transaction_year using `ADM2POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) WBAID_ADM2* Disbursementcount* isum_pop_ADM2, by(src_ID_admC12 transaction_year)
renvars isum_pop_ADM2 src_ID_admC12 / Population_ADM2_ADJ ID_adm2
duplicates report ID_adm2
* Rename Variables to indicate that they are in the adjacent regions
rename WBAID_ADM2_Wpop WBAID_ADM2_Wpop_ADJ
rename Disbursementcount_ADM2 Disbursementcount_ADM2_ADJ
foreach g in AX BX CX EX FX JX LX TX WX YX{
rename WBAID_ADM2_Wpop_`g' WBAID_ADM2_Wpop_ADJ_`g'
rename Disbursementcount_ADM2_`g' Disbursementcount_ADM2_ADJ_`g'
}
save `i'.dta, replace 
}
* Put yearly disbursements in adjacent regions together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'.dta
erase `i'.dta
}
erase 1995.dta

keep ID_adm2 WBAID_ADM2_Wpop_ADJ* transaction_year Disbursementcount_ADM2* Population_ADM2_ADJ

* Merge Disbursement file with Disbursements in adjacent ADM2 regions
merge 1:1 ID_adm2 transaction_year using "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM2_Wpop.dta", nogen keep(2 3)  
* Label variables
label var Population_ADM2_ADJ "Population in neighboring regions"
label var WBAID_ADM2_Wpop_ADJ "Pop. weighted World Bank aid in all adjacent ADM2 regions"
label var Disbursementcount_ADM2_ADJ "No. of non-negative WB aid disbursements in adjacent ADM2 regions"
foreach g in AX BX CX EX FX JX LX TX WX YX{
label var WBAID_ADM2_Wpop_ADJ "Pop. Weighted World Bank aid in all adjacent ADM2 regions in sector `g'"
label var Disbursementcount_ADM2_`g' "No. of non-negative WB aid disbursements in adjacent ADM2 regions in sector `g'"
}
save "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM2_Wpop_adjacent.dta", replace 


** ADM1

* Merge Adjacency matrix with Aid Disbursements in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM1_Wpop.dta", clear     // The disbursements are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the WB Aid in adjacent regions.         
drop if transaction_year!=`i'
* Merge with adjacent regions						
merge 1:m ID_adm1 using "$data\ADM\adm1_neighbors.dta", nogen keep(1 3)
* Merge with population Data
merge m:1 ID_adm1 transaction_year using `ADM1POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) WBAID_ADM1* Disbursementcount* isum_pop_ADM1, by(src_ID_admC7 transaction_year)
* Rename Variables to indicate that they are in the adjacent regions
rename src_ID_admC7 ID_adm1
renvars isum_pop_ADM1 WBAID_ADM1_Wpop / Population_ADM1_ADJ WBAID_ADM1_Wpop_ADJ
rename Disbursementcount_ADM1 Disbursementcount_ADM1_ADJ
foreach g in AX BX CX EX FX JX LX TX WX YX{
rename WBAID_ADM1_Wpop_`g' WBAID_ADM1_Wpop_ADJ_`g'
rename Disbursementcount_ADM1_`g' Disbursementcount_ADM1_ADJ_`g'
}
save `i'.dta, replace 
}
* Put yearly disbursements together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'.dta
erase `i'.dta
}
erase 1995.dta

keep ID_adm1 WBAID_ADM1_Wpop_ADJ*  Disbursementcount* transaction_year Population_ADM1_ADJ
* Merge Disbursement file with Disbursements in adjacent ADM1 regions
merge 1:m ID_adm1 transaction_year using "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM1_Wpop.dta", nogen keep(2 3)
* Label all variables
label var Population_ADM1_ADJ "Population in neighboring regions"
label var WBAID_ADM1_Wpop_ADJ "Pop. Weighted World Bank aid in all adjacent ADM1 regions"
label var Disbursementcount_ADM1_ADJ "No. of non-negative WB aid disbursements in adjacent ADM1 regions"
foreach g in AX BX CX EX FX JX LX TX WX YX{
label var WBAID_ADM1_Wpop_ADJ_`g' "Pop. Weighted World Bank aid in all adjacent ADM1 regions in sector `g'"
label var Disbursementcount_ADM1_ADJ_`g' "No. of non-negative WB aid disbursements in adjacent ADM1 regions in sector `g'"
}
save "$data\Aid\2017_11_14_WB\IBRD_disbursement_ADM1_Wpop_adjacent.dta", replace
*/
**************************
**************************
* C: Create Chinese Aid Data *
**************************
**************************

cd "$data\Aid\2017_11_14_WB"



*******************
* Load Project Data
********************
import excel using "$data\Aid_China\aiddata_china_1_1_1.xlsx", sheet("1) Official Finance") firstrow clear
rename year transaction_year
save OF.dta, replace

*********************
* Load GADM-Aid Data
*********************
* Load ADM1 Data for the cases, where no ADM2 shapefile existed
import delim using "$data\Aid_China\spatial_join_adm1_chinese_aid.csv", clear
//generate local of ChinaAid countries to drop non ChinaAid countries at a later stage
levelsof id_0n100, local(ChinaAidCountries)

* Keep ID1 Identifier to merge these into ADM2 Data
keep target_fidn100 id_0n100 id_1n100 join_fidn100 isoc3 name_0c75 name_1c75
save adm1_v.dta, replace

* Load ADM2 data
import delim using "$data\Aid_China\spatial_join_adm2_chinese_aid.csv", clear
drop id_0n100 isoc3 name_0c75 id_1n100 name_1c75  //clear entries from errors if no ADM2 regions identified; otherwise missing id_0 and id_1 entries

* Merge with the ADM1 Identifiers as there are some ADM2 regions missing and in this case the ADM1 region is also not coded (This issue seems persistent for two observations, "which fall into the sea")
merge 1:1 target_fidn100 using adm1_v.dta, nogen keep(1 3)

*create dummy variable indicating if a GADM2 region is missing, thus have been replaced by GADM1 region
gen byte d_miss_ADM2=(id_2n100==0 & id_1n100!=0)

renvars project_idn100 year_n100/  project_id transaction_year

//Manuall code projects that are identified in the ocean, but are acutally precisely coded, which is >=precision4 (See protocol from 03-09-2017 last pages)
replace id_0n100= 87 if project_id==1468 & join_fidn100==-1 & id_0n100==0
replace id_1n100= 5 if project_id==1468 & join_fidn100==-1 & id_1n100==0
replace id_2n100= 72 if project_id==1468 & join_fidn100==-1 & id_2n100==0
replace isoc3= "GHA" if project_id==1468 & join_fidn100==-1
replace name_0c75= "Ghana" if project_id==1468 & join_fidn100==-1
replace name_1c75= "Greater Accra" if project_id==1468 & join_fidn100==-1
replace name_2c75= "Dangbe West" if project_id==1468 & join_fidn100==-1


replace id_0n100= 203 if project_id==2081 & join_fidn100==-1 & id_0n100==0
replace id_1n100= 17 if project_id==2081 & join_fidn100==-1 & id_1n100==0
replace id_2n100= 0 if project_id==2081 & join_fidn100==-1 & id_2n100==0
replace isoc3= "SYC" if project_id==2081 & join_fidn100==-1
replace name_0c75= "Seychelles" if project_id==2081 & join_fidn100==-1
replace name_1c75= "Les Mamelles" if project_id==2081 & join_fidn100==-1 & name_1c75==""
replace d_miss_ADM2=1 if project_id==2081

replace id_0n100= 203 if project_id==1161 & join_fidn100==-1 & id_0n100==0
replace id_1n100= 22 if project_id==1161 & join_fidn100==-1 & id_1n100==0
replace id_2n100= 0 if project_id==1161 & join_fidn100==-1 & id_2n100==0
replace isoc3= "SYC" if project_id==1161 & join_fidn100==-1
replace name_0c75= "Seychelles" if project_id==1161 & join_fidn100==-1
replace name_1c75= "Pointe Larue" if project_id==1161 & join_fidn100==-1 & name_1c75=="" & precision_n100==4
replace d_miss_ADM2=1 if project_id==1161

replace id_0n100= 118 if project_id==1291 & join_fidn100==-1 & id_0n100==0
replace id_1n100= 28 if project_id==1291 & join_fidn100==-1 & id_1n100==0
replace id_2n100= 182 if project_id==1291 & join_fidn100==-1 & id_2n100==0 // Melvin 18.01.2018: Manually looked up geocode. Likely to belong to Mombasa-Mvita region
replace isoc3= "KEN" if project_id==1291 & join_fidn100==-1
replace name_0c75= "Kenya" if project_id==1291 & join_fidn100==-1
replace name_1c75= "Mombasa" if project_id==1291 & join_fidn100==-1
replace name_2c75= "Mvita" if project_id==1291 & join_fidn100==-1


* Generate unique identifier for each ADM region:
gen c = "c"
gen r = "r"
egen ID_adm1 = concat(c id_0n100 r id_1n100)
egen ID_adm2 = concat(c id_0n100 r id_1n100 r id_2n100)
drop c r  
label var ID_adm1 "Unique identifier for ADM1 region"
label var ID_adm2 "Unique identifier for ADM2 region"

* Merge the location data (master) with actual flow data (using)
merge m:1 project_id transaction_year using OF.dta, nogen //no mismatch from master

* Clean Data 
keep id_2n100 id_1n100 id_0n100 isoc3 precision_n100 d_miss_ADM2 name_0c75 name_1c75 name_2c75 project_id transaction_year titlec254 year_uncerc254 crs_sectorn100 crs_sect_1c254 sector_comc254 statusc254 status_codn100 flowc254 donor_ag_1n100 verifiedc254 flow_classc254 flow_cla_1n100 intentc254 activec254 start_actuc254 start_planc254 end_actualc254 end_plannec254 loan_typec254 line_of_crc254 is_cofinanc254 is_ground_c254 is_offician100 ID_adm1 ID_adm2 flow sources_count amount currency deflators_used exchange_rates_used usd_defl usd_current verified_cn100
* Drop observations which only signify a pledge, but no full-fetched disbursement
drop if statusc254=="Pipeline: Pledge"

* Keep only Official Development Assistance (ODA) & Other Official Finance (OOF) flows
keep if  flow_classc254=="ODA-like" | flow_classc254=="Vague (Official Finance)" | flow_classc254=="OOF-like"

* rename data to fit program algorithm
renvars isoc3 id_0n100 id_1n100 id_2n100 precision_n100 name_0c75 name_1c75 name_2c75 / ISO3 ID_0 ID_1 ID_2 precision_N100 ADM0 ADM1 ADM2

save china_temp1.dta, replace

****next step: discount aid
use china_temp1.dta, clear
rename usd_current transaction_value_tot
drop if transaction_value==.  //963 out of 3117 obs missing (30%)

* Generate count variable for number of positive project disbursements
gen count=1 if transaction_value_tot>0
egen Disbursementcount=total(count), by(project_id transaction_year)
label var Disbursementcount "Sum of yearly positive disbursements within project" 
drop count

//temp_totlocation: Number of locations with positive project disbursements for entire project year
gen count=1
egen temp_totlocation=total(count), by(project_id transaction_year)
drop count

//temp_totcoded: Number of locations that are precisely coded (higher than precision level 4)
gen count=1 if precision_N100<=4
egen temp_totcoded=total(count), by(project_id transaction_year)
drop count

//temp_totcoded: Number of locations that are coded with precision 4
gen count=1 if precision_N100==4
egen temp_totcoded4=total(count), by(project_id transaction_year)
drop count

//temp_totcoded: Number of locations that are precisely coded (higher than precision level 4)
gen count=1 if precision_N100<4
egen temp_totcoded13=total(count), by(project_id transaction_year)
drop count

//temp_projsum: Total amount of project amount to be allocated to different regions after discounting for information loss
rename transaction_value_tot temp_value																
gen transaction_value_tot= temp_totcoded/temp_totlocation*temp_value


keep if (precision_N100<=4) //note: more than 92% are coded higher than 4 at this stage
sort project_id transaction_year
save "$data\Aid\2017_11_14_WB\China_disbursement.dta", replace


********************************************************************************
//2) Prepare location weighted data
********************************************************************************
use "$data\Aid\2017_11_14_WB\China_disbursement.dta", clear

cd "$data\Aid\2017_11_14_WB" 
* Execute program to allocate Chinese aid using location weights
allocAid China CAID

* Execute program to allocate Chinese aid using population weights
allocAid_pop China CAID


ssssssssssssssssss
























* Merge with population data
renvars ID_adm1 ID_adm2 transaction_year / rid1 rid2 year
merge m:1 rid2 year using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen keep(1 3)
rename isum_pop isum_pop_ADM2
merge m:1 rid1 year using "$data\ADM\1_1_1_R_pop_GADM1.dta", nogen keep(1 3)
rename isum_pop isum_pop_ADM1

renvars rid1 rid2 year / ID_adm1 ID_adm2 transaction_year
* Add one population in case the population data is missing or zero. The assumption would be that at least one person is living in the region in order to get a proper population weighting
*replace isum_pop=1 if isum_pop==. | isum_pop==0



*******************************************************
* Precision-Cleaning leads to loss of 2/5 of our smaple
*******************************************************
* Precision Code 1-4 (ADM1 and more precise)
gen precision=0
* Generate a counter, which is one for projects that contain information, which are coded less precise than ADM1
replace precision=1 if precision_n100>4
bysort project_id transaction_year: egen preccount=total(precision)
* Drop Projects, which contain flows that are coded less precise than ADM1, as most flows might be going to the central government
drop if preccount>0
keep if precision_n100==1 | precision_n100==2 | precision_n100==3 | precision_n100==4
drop precision preccount
save cleaned.dta, replace
save "$data\Aid\ChinaAid_projects_clean.dta", replace
/********************************************
CREATE ADM2 AID DATA
********************************************/

* Precision 1 - 3 (ADM2 and more precise)
gen precision=0
* Generate a counter, which is one for projects that contain information, which are coded less precise than ADM2
replace precision=1 if precision_n100>3
bysort project_id transaction_year: egen preccount=total(precision)
keep if (precision_n100==1 | precision_n100==2 | precision_n100==3) & preccount==0



* Location weighted Aid Disbursements
gen n=1
* Bysort and collapse by flow_classc254 as we still need to split ODA & Other Financial Flows
bysort project_id transaction_year flow_classc254: egen locations=total(n)
gen CAID_LOC123=usd_current/locations


* Population weighted Aid Disbursements
* Add one population in case the population data is missing or zero. The assumption would be that at least one person is living in the region in order to get a proper population weighting
//replace isum_pop=1 if isum_pop==. | isum_pop==0
bysort project_id transaction_year flow_classc254: egen totpop_ADM2=total(isum_pop_ADM2)
gen CAID_Wpop123_ADM2=(usd_current*isum_pop_ADM2)/totpop_ADM2

collapse (sum) CAID_Wpop123_ADM2 CAID_LOC , by(id_0n100 ID_adm2 ID_adm1 transaction_year flow_classc254)

* Distinguish official flows by type into ODA (Aid-like) and OOF (Other official finance: we still need to check if this broadly corresponds to development finance)
gen CODA_ADM2_Wpop123=CAID_Wpop123_ADM2 if flow_classc254=="ODA-like"
gen COOF_ADM2_Wpop123=CAID_Wpop123_ADM2 if flow_classc254=="Vague (Official Finance)" | flow_classc254=="OOF-like"
gen CODA_ADM2_LOC123=CAID_LOC123 if flow_classc254=="ODA-like"
gen COOF_ADM2_LOC123=CAID_LOC123 if flow_classc254=="Vague (Official Finance)" | flow_classc254=="OOF-like"

* Collapse again to get new ODA and OOF data
collapse (sum) CODA_ADM2_LOC123 CODA_ADM2_Wpop123 COOF_ADM2_Wpop123 COOF_ADM2_LOC123, by(id_0n100 ID_adm2 ID_adm1 transaction_year)	

save prec123.dta, replace

* Precision Code 4 (ADM1)
use cleaned.dta, clear
keep if  precision_n100==4
* Here we drop first the ADM2 identifiers as we would later merge the data with all underlying ADM2 regions for equal split
drop ID_adm2
* Here duplicates for each project in the same ADM1 region and the same year are dropped to avoid double counting
duplicates drop project_id year ID_adm1, force
* We do not need to clean for more precise projects, because we already excluded all less precise projects with precision code 1-3


* Here we merge the aid data from the ADM1 level with all possible ADM2 regions to achieve proportional splits across population and locations
merge m:m  ID_adm1 using `gadm2', nogen keep(1 2 3) //keep if _merge==2, to obtain full panel. Delete those countries where there is no ChinaAid data in the next step
//drop non ChinaAid countries

* Need to assume once again that some ADM1 regions are ADM2 regions as they are partly missing in our data
	replace id_2n100=0 if id_1n100!=. & id_2n100==.
	drop if id_2n100==.
	//create dummy variable indicating if a GADM2 region is missing, thus have been replaced by GADM1 region
	gen byte d_miss_ADM2=(id_2n100==0 & id_1n100!=0)
	
* Create update ID_2s
* Generate unique identifier for each ADM region:
gen c = "c"
gen r = "r"
egen ID_adm2_v = concat(c id_0n100 r id_1n100 r id_2n100)
replace ID_adm2=ID_adm2_v if ID_adm2==""
drop c r ID_adm2_v
* Merge Precision code 4 data (master) with population data (using) for population weighted aid flows
renvars transaction_year ID_adm2 / year rid2
	merge m:1 rid2 year using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen keep(1 3)
renvars year rid2 /  transaction_year ID_adm2

* Add one population in case the population data is missing or zero. The assumption would be that at least one person is living in the region in order to get a proper population weighting
//replace isum_pop=1 if isum_pop==. | isum_pop==0

* Location and Population weighted aid flows
gen count=1
sort project_id transaction_year
* Bysort and collapse by flow_classc254 as we still need to split ODA & Other Financial Flows
bysort project_id transaction_year flow_classc254: egen loc_projects=total(count)
bysort project_id transaction_year flow_classc254: egen pop_projects=total(isum_pop_ADM2) //create total pop of regions for each project_id and year
gen CAID_ADM2_Wpop4=(usd_current*isum_pop_ADM2)/pop_projects
gen CAID_ADM2_LOC4=(usd_current)/loc_projects

collapse (sum) CAID_ADM2_Wpop4 CAID_ADM2_LOC4, by(id_0n100 ID_adm2 ID_adm1 transaction_year flow_classc254)	

* Distinguish official flows by type into ODA (Aid-like) and OOF (Other official finance: we still need to check if this broadly corresponds to development finance)
gen CODA_ADM2_Wpop4=CAID_ADM2_Wpop4 if flow_classc254=="ODA-like"
gen COOF_ADM2_Wpop4=CAID_ADM2_Wpop4 if flow_classc254=="Vague (Official Finance)" | flow_classc254=="OOF-like"
gen CODA_ADM2_LOC4=CAID_ADM2_LOC4 if flow_classc254=="ODA-like"
gen COOF_ADM2_LOC4=CAID_ADM2_LOC4 if flow_classc254=="Vague (Official Finance)" | flow_classc254=="OOF-like"

* Collapse again to get new ODA and OOF data
collapse (sum) CODA_ADM2_LOC4 CODA_ADM2_Wpop4 COOF_ADM2_Wpop4 COOF_ADM2_LOC4, by(id_0n100 ID_adm2 ID_adm1 transaction_year)	

save prec4.dta, replace


**********************
* Merge Data from different Precision Codes
**********************
merge 1:1 ID_adm2 transaction_year using `prec123', nogen
//Due to merge, ID_adm1 identifier vanished. Recover them from ID_adm2
*gen temp1=regexr(ID_adm2, "c[0-9]+r[0-9]+", "") //erase part I am interested first
*gen temp2=strlen(temp1) //get character count of part I do not want
*gen temp3=strlen(ID_adm2) //get total character count
*gen temp4=temp3-temp2 //get number of characters I want to keep
*replace ID_adm1=substr(ID_adm2,1,temp4)
*drop temp*

//continue with aid data preparation
 foreach l in Wpop123 LOC123 LOC4 Wpop4{
replace CODA_ADM2_`l'=0 if CODA_ADM2_`l'==.
replace COOF_ADM2_`l'=0 if COOF_ADM2_`l'==.
}

 foreach l in Wpop LOC {
gen CODA_ADM2_`l'=CODA_ADM2_`l'123+CODA_ADM2_`l'4
gen COOF_ADM2_`l'=COOF_ADM2_`l'123+COOF_ADM2_`l'4
}
drop CODA_ADM2_LOC4 COOF_ADM2_LOC4 CODA_ADM2_Wpop4 COOF_ADM2_Wpop4 CODA_ADM2_LOC123 COOF_ADM2_LOC123 CODA_ADM2_Wpop123 COOF_ADM2_Wpop123
//drop non ChinaAid countries, but keep non Chinese-Aid regions in ChinaAid countries
gen chinaaid_country=0
foreach x in `ChinaAidCountries' {
replace chinaaid_country =1 if id_0n100==`x'
}
assert chinaaid_country==1

* TSFILL / fill out gaps in between data
sort ID_adm2 transaction_year
egen ID_adm2_num = group(ID_adm2)
// 2. tsset Geounit Jahr
tsset ID_adm2_num transaction_year
// 3. tsfill, full
tsfill, full //fill out data gaps
gen years_reverse =-transaction_year
// 4. carryforward, countryname etc
bysort ID_adm2_num (transaction_year): carryforward ID_adm* chinaaid_country id_* , replace 
bysort ID_adm2_num (years_reverse): carryforward ID_adm*  chinaaid_country id_*, replace
// 5. replace Financevar= 0 if Financevar==.
foreach g in CODA_ADM2_LOC COOF_ADM2_LOC  CODA_ADM2_Wpop COOF_ADM2_Wpop{
replace `g'= 0 if `g' ==.
}	
drop years_reverse ID_adm2_num
sort ID_adm* transaction_year

save adm2.dta, replace

/********************************************
CREATE ADM1 AID DATA
********************************************/
use cleaned.dta, clear

* Population weighted Aid Disbursements
bysort project_id transaction_year flow_classc254: egen totpop_ADM1=total(isum_pop_ADM1)
gen CAID_Wpop_ADM1=(usd_current*isum_pop_ADM1)/totpop_ADM1
* Location weighted Aid Disbursements
gen n=1
bysort project_id transaction_year flow_classc254: egen locations=total(n)
gen CAID_LOC_ADM1=usd_current/locations

collapse (sum) CAID_Wpop_ADM1 CAID_LOC_ADM1, by(ID_adm1 transaction_year flow_classc254)
* Distinguish official flows by type into ODA (Aid-like) and OOF (Other official finance: we still need to check if this broadly corresponds to development finance)
gen CODA_ADM1_Wpop=CAID_Wpop_ADM1 if flow_classc254=="ODA-like"
gen COOF_ADM1_Wpop=CAID_Wpop_ADM1 if flow_classc254=="Vague (Official Finance)" | flow_classc254=="OOF-like"
gen CODA_ADM1_LOC=CAID_LOC_ADM1 if flow_classc254=="ODA-like"
gen COOF_ADM1_LOC=CAID_LOC_ADM1 if flow_classc254=="Vague (Official Finance)" | flow_classc254=="OOF-like"

//continue with aid data preparation
 foreach l in Wpop LOC{
replace CODA_ADM1_`l'=0 if CODA_ADM1_`l'==.
replace COOF_ADM1_`l'=0 if COOF_ADM1_`l'==.
}


//dataset has now duplicates by flow_class since we divided CAID into CODA and COOF. Collapse the data on regional level to get rid o0f duplicates
collapse (sum) CODA_ADM1_Wpop COOF_ADM1_Wpop CODA_ADM1_LOC COOF_ADM1_LOC, by(ID_adm1 transaction_year)

* TSFILL / fill out gaps in between data
sort ID_adm1 transaction_year
egen ID_adm1_num = group(ID_adm1)
// 2. tsset Geounit Jahr
tsset ID_adm1_num transaction_year
// 3. tsfill, full
tsfill, full //fill out data gaps
gen years_reverse =-transaction_year
// 4. carryforward, countryname etc
bysort ID_adm1_num (transaction_year): carryforward ID_adm* , replace 
bysort ID_adm1_num (years_reverse): carryforward ID_adm* , replace
// 5. replace Financevar= 0 if Financevar==.
foreach g in CODA_ADM1_Wpop COOF_ADM1_Wpop CODA_ADM1_LOC COOF_ADM1_LOC{
replace `g'= 0 if `g' ==.
}	
drop years_reverse ID_adm1_num
sort ID_adm* transaction_year

save adm1.dta, replace
* Note: ADM2 data of location weighted aid cannot be collapsed to ADM1 data, else loss of data
/*
****************************************************
* Generate location weighted Aid in adjacent regions 
****************************************************
use "$data\ADM\1_1_1_R_pop_GADM1.dta", clear
renvars year rid1 isum_pop / transaction_year ID_adm1 isum_pop_ADM1

save ADM1POP.dta, replace

use "$data\ADM\1_1_1_R_pop_GADM2.dta", clear
renvars year rid2 isum_pop / transaction_year ID_adm2 isum_pop_ADM2

save ADM2POP.dta, replace


* Need to do this on a yearly basis to prevent odd merges
forvalues i=2000(1)2012 {
use adm2.dta, clear
keep if transaction_year==`i'
* Mege with adjacent region
merge 1:m ID_adm2 using "$data\ADM\adm2_neighbors.dta", nogen keep(3 1)
* Merge with data on population 
merge m:1 ID_adm2 transaction_year using `ADM2POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) CODA_ADM2_LOC COOF_ADM2_LOC CODA_ADM2_Wpop COOF_ADM2_Wpop isum_pop_ADM2, by(src_ID_admC12 transaction_year)
* Rename variables to indicate that they are in an adjacent region
foreach v in CODA_ADM2_LOC COOF_ADM2_LOC  CODA_ADM2_Wpop COOF_ADM2_Wpop {
rename `v' `v'_ADJ
}
renvars isum_pop_ADM2 src_ID_admC12 / Population_ADM2_ADJ ID_adm2
tempfile `i'
save ``i'', replace
}

* Put yearly disbursements in adjacent regions together
use `2000', clear
forvalues i=2001(1)2012 {
append using ``i''
}

* Label variables
label var CODA_ADM2_LOC_ADJ "Chinese ODA-like flows to adjacent regions (location weighted)"
label var CODA_ADM2_Wpop_ADJ "Chinese ODA-like flows to adjacent regions (population weighted)"
label var COOF_ADM2_LOC_ADJ "Chinese other official finance to adjacent regions (location weighted)"
label var COOF_ADM2_Wpop_ADJ "Chinese other official finance to adjacent regions (population weighted)"
label var Population_ADM2_ADJ "Population in adjacent regions"
* Merge Disbursements in adjacent regions with disbursements in specific region
merge 1:1 ID_adm2 transaction_year using `adm2', nogen 

//some regions do not receive aid, but the adjacent ones. The merge introduces missings for these regions. Code them as getting no aid.
foreach var of varlist CODA_* COOF_* {
replace `var'=0 if `var'==. 
}

save "$data\Aid\Chinese_Finance_ADM2_adjacent.dta", replace 


* ADM1 LEVEL
* Need to do this on a yearly basis to prevent odd merges
forvalues t=2000(1)2012 {
use adm1.dta, clear
keep if transaction_year==`t'
* Mege with adjacent region
merge 1:m ID_adm1 using "$data\ADM\adm1_neighbors.dta", nogen keep(1 3)
* Merge with data on population 
merge m:1 ID_adm1 transaction_year using ADM1POP.dta, nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) CODA_ADM1_LOC COOF_ADM1_LOC  CODA_ADM1_Wpop COOF_ADM1_Wpop isum_pop_ADM1, by(src_ID_admC7 transaction_year)
* Rename variables to indicate that they are in an adjacent region
foreach v in CODA_ADM1_LOC COOF_ADM1_LOC  CODA_ADM1_Wpop COOF_ADM1_Wpop {
rename `v' `v'_ADJ
}
renvars isum_pop_ADM1 src_ID_admC7 / Population_ADM1_ADJ ID_adm1

save `t'.dta, replace
}

* Put yearly disbursements in adjacent regions together
use 2000.dta, clear
forvalues t=2001(1)2012 {
append using `t'.dta
erase `t'.dta
}
erase 2000.dta
* Label variables
label var CODA_ADM1_LOC_ADJ "Chinese ODA-like flows to adjacent regions (location weighted)"
label var CODA_ADM1_Wpop_ADJ "Chinese ODA-like flows to adjacent regions (population weighted)"
label var COOF_ADM1_LOC_ADJ "Chinese other official finance to adjacent regions (location weighted)"
label var COOF_ADM1_Wpop_ADJ "Chinese other official finance to adjacent regions (population weighted)"
label var Population_ADM1_ADJ "Population in adjacent regions"
* Merge Disbursements in adjacent regions with disbursements in specific region
merge 1:1 ID_adm1 transaction_year using adm1.dta, nogen 


//some regions do not receive aid, but the adjacent ones. The merge introduces missings for these regions. Code them as getting no aid.
foreach var of varlist CODA_* COOF_* {
replace `var'=0 if `var'==. 
}

save "$data\Aid\Chinese_Finance_ADM1_adjacent.dta", replace 
*/

**************************
**************************
* D: Create Indian Aid Data *
**************************
**************************
cd "$data"

****************
* Load GADM Data for split of higher precision-codes
****************
import delim using "$data\ADM\gadm28adm2.csv", clear
keep objectidn100 isoc3 id_0n100 name_0c75 id_1n100 name_1c75 name_2c75 id_2n100
renvars objectidn100 isoc3  name_0c75 name_1c75 name_2c75  / OBJECTID ISO3 ADM0 ADM1 ADM2 
drop if ISO3==""

* Generate unique identifier for each ADM region:
gen c = "c"
gen r = "r"
egen ID_adm1 = concat(c id_0n100 r id_1n100)
egen ID_adm2 = concat(c id_0n100 r id_1n100 r id_2n100)
drop c r  id_0n100 id_1n100 id_2n100
label var ID_adm2 "Unique identifier for ADM2 region"
duplicates drop OBJECTID, force
* 7 Regions are coded wrongly and are dropped. No problem to drop here in data frame. But shapefiles are errorenous
duplicates drop ID_adm2 ID_adm1 ADM0 ADM1 ADM2, force
drop OBJECTID

save gadm2.dta, replace


* Load ADM1 Data for the cases, where no ADM2 shapefile existed
import delim using "$data\Aid_India\gis_out\i_alg2_adm1.csv", clear
//manually delete one error in raw IndianAid Data. Confirmed by Gerda Asmussen
*XXXXXXXXX 06.12.2017 Lennart: Why is it deleted and not corrected? We might have already talked about it and if it is one of those places, which fall into the water and/or drop out anyways, it should be no issue at all.
*XXXXXXXXX 29.12.2017 Melvin: Is is not a region in the water. Gerda told me that this point is wrongly coded in the raw data. The drop must remain.
drop if place_name=="Pochampally Handloom Park"
* Generate unique identifier for each ADM region:
gen c = "c"
gen r = "r"
egen ID_adm1_v = concat(c id_0 r id_1)
drop c r  
label var ID_adm1 "Unique identifier for ADM1 region"
keep target_fid ID_adm1_v join_fid id_1 id_0 name_0 iso id_1 name_1 
renvars join_fid / join_v

save adm1_v, replace


* Load ADM2 data
import delim using "$data\Aid_India\gis_out\i_alg2_adm2.csv", clear
//manually delete one error in raw IndianAid Data. Confirmed by Gerda Asmussen 
drop if place_name=="Pochampally Handloom Park"
//clear entries from errors if no ADM2 regions identified; otherwise missing id_0 and id_1 entries
drop id_0 name_0 iso id_1 name_1 
merge 1:1 target_fid using `adm1_v', nogen keep(1 3)
	//create dummy variable indicating if a GADM2 region is missing, thus have been replaced by GADM1 region
	gen byte d_miss_ADM2=(id_2==0 & id_1!=0)

renvars aiddata_pr year /  project_id transaction_year

/*
//Manuall code projects that are identified in the ocean, but are acutally precisely coded (See protocol from 03-09-2017 last pages)
* in total 40 out of 338 obs that have no region ID
* in total 16 out of 338 obs without ID and below precision 4, 3 of them have acutal disbursements
replace id_0n100= "XX" if project_id==906001106534 & join_fid==-1 & precision_ <=4 & usd_commit >0 & id_0n100==0
replace id_1n100= "XX" if project_id==906001106534 & join_fid==-1 & precision_ <=4 & usd_commit >0 & id_0n100==0
replace id_2n100= "XX" if project_id==906001106534 & join_fid==-1 & precision_ <=4 & usd_commit >0 & id_0n100==0

replace id_0n100= "XX" if project_id==906001108083 & join_fid==-1 & precision_ <=4 & usd_commit >0 & id_0n100==0
replace id_1n100= "XX" if project_id==906001108083 & join_fid==-1 & precision_ <=4 & usd_commit >0 & id_0n100==0
replace id_2n100= "XX" if project_id==906001108083 & join_fid==-1 & precision_ <=4 & usd_commit >0 & id_0n100==0

replace id_0n100= "XX" if project_id==906001108466 & join_fid==-1 & precision_ <=4 & usd_commit >0 & id_0n100==0
replace id_1n100= "XX" if project_id==906001108466 & join_fid==-1 & precision_ <=4 & usd_commit >0 & id_0n100==0
replace id_2n100= "XX" if project_id==906001108466 & join_fid==-1 & precision_ <=4 & usd_commit >0 & id_0n100==0

*/
* Generate unique identifier for each ADM region:
gen c = "c"
gen r = "r"
egen ID_adm1 = concat(c id_0 r id_1)
egen ID_adm2 = concat(c id_0 r id_1 r id_2)
drop c r  
label var ID_adm1 "Unique identifier for ADM1 region"
label var ID_adm2 "Unique identifier for ADM2 region"


* Keep only Official Development Assistance (ODA) & Other Official Finance (OOF) flows
keep if  flow_type=="ODA" | flow_type=="OOF" | flow_type=="OOF-like Export Credit"


* Merge with population data (m:1 as we did so far not collapse the project data into singular disbursements)
renvars ID_adm1 ID_adm2 transaction_year / rid1 rid2 year
merge m:1 rid2 year using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen keep(1 3)
rename isum_pop isum_pop_ADM2
merge m:1 rid1 year using "$data\ADM\1_1_1_R_pop_GADM1.dta", nogen keep(1 3)
rename isum_pop isum_pop_ADM1

renvars rid1 rid2 year / ID_adm1 ID_adm2 transaction_year
* Add one population in case the population data is missing or zero. The assumption would be that at least one person is living in the region in order to get a proper population weighting
*replace isum_pop=1 if isum_pop==. | isum_pop==0


*******************************************************
* Precision-Cleaning leads to 109 obs out of 338 left
*******************************************************
* Precision Code 1-4 (ADM1 and more precise)
gen precision_d=0
* Generate a counter, which is one for projects that contain information / flows, which are coded less precise than ADM1
replace precision_d=1 if precision_>4
bysort project_id transaction_year: egen preccount=total(precision_d)
* Drop Projects, which contain flows that are coded less precise than ADM1, as most flows might be going to the central government
drop if preccount>0
keep if precision_==1 | precision_==2 | precision_==3 | precision_==4
drop precision_d preccount

save "$data\Aid\IndiaAid_projects_clean.dta", replace

/********************************************
CREATE ADM2 AID DATA
********************************************/

* Precision 1 - 3 (ADM2 and more precise)
gen precision_d=0
* Generate a counter, which is one for projects that contain information, which are coded less precise than ADM2
replace precision_d=1 if precision_>3
bysort project_id transaction_year: egen preccount=total(precision_d)
* Drop Projects, which contain flows that are coded less precise than ADM2, as most flows might be going to the central government
keep if (precision_==1 | precision_==2 | precision_==3) & preccount==0



* Location weighted Aid Disbursements
gen n=1
* Bysort and collapse by flow_type as we still need to split ODA & Other Financial Flows
bysort project_id transaction_year flow_type: egen locations=total(n)
gen IAID_LOC123=usd_commit/locations
//note: there are only 7 disbursement locations


* Population weighted Aid Disbursements
* Add one population in case the population data is missing or zero. The assumption would be that at least one person is living in the region in order to get a proper population weighting
//replace isum_pop=1 if isum_pop==. | isum_pop==0
bysort project_id transaction_year flow_type: egen totpop_ADM2=total(isum_pop_ADM2)
gen IAID_Wpop123_ADM2=(usd_commit*isum_pop_ADM2)/totpop_ADM2

collapse (sum) IAID_Wpop123_ADM2 IAID_LOC , by(id_0 ID_adm2 ID_adm1 transaction_year flow_type)
* Distinguish official flows by type into ODA (Aid-like) and OOF (Other official finance: we still need to check if this broadly corresponds to development finance)
gen IODA_ADM2_Wpop123=IAID_Wpop123_ADM2 if flow_type=="ODA"
gen IOOF_ADM2_Wpop123=IAID_Wpop123_ADM2 if flow_type=="OOF" | flow_type=="OOF-like Export Credit"
gen IODA_ADM2_LOC123=IAID_LOC123 if flow_type=="ODA"
gen IOOF_ADM2_LOC123=IAID_LOC123 if flow_type=="OOF" | flow_type=="OOF-like Export Credit"


* Collapse again to get new ODA and OOF data
collapse (sum) IODA_ADM2_LOC123 IODA_ADM2_Wpop123 IOOF_ADM2_Wpop123 IOOF_ADM2_LOC123, by(id_0 ID_adm2 ID_adm1 transaction_year)	
tempfile prec123
save `prec123', replace

* Precision Code 4 (ADM1)
use `cleaned', clear
keep if  precision_==4
* Here we drop first the ADM2 identifiers as we would later merge the data with all underlying ADM2 regions for equal split
drop ID_adm2
* Here duplicates for each project in the same ADM1 region and the same year are dropped to avoid double counting
duplicates drop project_id transaction_year ID_adm1, force
* We do not need to clean for more precise projects, because we already excluded all less precise projects with precision code 1-3


* XXXX 06.12.2017 Lennart: Usually m:m merges are slightly problematic as they often do not merge all the possible observations. However, here it seems suitable. Do all agree?
* Here we merge the aid data from the ADM1 level with all possible ADM2 regions to achieve proportional splits across population and locations
merge m:m  ID_adm1 using `gadm2', nogen keep(1 3) //drop if _merge==2 as not aid data but only geographic data

* Create updated ID_2s
* Generate unique identifier for each ADM region:
gen c = "c"
gen r = "r"
egen ID_adm2_v = concat(c id_0 r id_1 r id_2)
* XXXX 06.12.2017 Lennart:  This line is not needed anymore, potentially as we drop region ""Pochampally Handloom Park""
* replace ID_adm2=ID_adm2_v if ID_adm2==""
drop c r ID_adm2_v
* Merge Precision code 4 data (master) with population data (using) for population weighted aid flows
renvars transaction_year ID_adm2 / year rid2
	merge m:1 rid2 year using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen keep(1 3)
renvars year rid2 /  transaction_year ID_adm2

* Add one population in case the population data is missing or zero. The assumption would be that at least one person is living in the region in order to get a proper population weighting
//replace isum_pop=1 if isum_pop==. | isum_pop==0

* Location and Population weighted aid flows
gen count=1
sort project_id transaction_year
* Bysort and collapse by flow_type as we still need to split ODA & Other Financial Flows
bysort project_id transaction_year flow_type: egen loc_projects=total(count)
bysort project_id transaction_year flow_type: egen pop_projects=total(isum_pop_ADM2) //create total pop of regions for each project_id and year
gen IAID_ADM2_Wpop4=(usd_commit*isum_pop_ADM2)/pop_projects
gen IAID_ADM2_LOC4=(usd_commit)/loc_projects
collapse (sum) IAID_ADM2_Wpop4 IAID_ADM2_LOC4, by(id_0 ID_adm2 ID_adm1 transaction_year flow_type)	
* Distinguish official flows by type into ODA (Aid-like) and OOF (Other official finance: we still need to check if this broadly corresponds to development finance)
gen IODA_ADM2_Wpop4=IAID_ADM2_Wpop4 if flow_type=="ODA"
gen IOOF_ADM2_Wpop4=IAID_ADM2_Wpop4 if flow_type=="OOF" | flow_type=="OOF-like Export Credit"
gen IODA_ADM2_LOC4=IAID_ADM2_LOC4 if flow_type=="ODA"
gen IOOF_ADM2_LOC4=IAID_ADM2_LOC4 if flow_type=="OOF" | flow_type=="OOF-like Export Credit"

* Collapse again to get new ODA and OOF data
collapse (sum) IODA_ADM2_LOC4 IODA_ADM2_Wpop4 IOOF_ADM2_Wpop4 IOOF_ADM2_LOC4, by(id_0 ID_adm2 ID_adm1 transaction_year)	

save prec4.dta, replace


**********************
* Merge Data from different Precision Codes
**********************
merge 1:1 ID_adm2 transaction_year using `prec123', nogen
*XXXX 06.12.2017 Lennart: Could we drop this part from our do-file?
//Due to merge, ID_adm1 identifier vanished. Recover them from ID_adm2
*gen temp1=regexr(ID_adm2, "c[0-9]+r[0-9]+", "") //erase part I am interested first
*gen temp2=strlen(temp1) //get character count of part I do not want
*gen temp3=strlen(ID_adm2) //get total character count
*gen temp4=temp3-temp2 //get number of characters I want to keep
*replace ID_adm1=substr(ID_adm2,1,temp4)
*drop temp*

//continue with aid data preparation by setting missings to zero in order to be able to add steps up
 foreach l in Wpop123 LOC123 LOC4 Wpop4{
replace IODA_ADM2_`l'=0 if IODA_ADM2_`l'==.
replace IOOF_ADM2_`l'=0 if IOOF_ADM2_`l'==.
}

 foreach l in Wpop LOC {
gen IODA_ADM2_`l'=IODA_ADM2_`l'123+IODA_ADM2_`l'4
gen IOOF_ADM2_`l'=IOOF_ADM2_`l'123+IOOF_ADM2_`l'4
}
drop IODA_ADM2_LOC4 IOOF_ADM2_LOC4 IODA_ADM2_Wpop4 IOOF_ADM2_Wpop4 IODA_ADM2_LOC123 IOOF_ADM2_LOC123 IODA_ADM2_Wpop123 IOOF_ADM2_Wpop123

* TSFILL / fill out gaps in between data
sort ID_adm2 transaction_year
egen ID_adm2_num = group(ID_adm2)
// 2. tsset Geounit Jahr
tsset ID_adm2_num transaction_year
// 3. tsfill, full
tsfill, full //fill out data gaps
gen years_reverse =-transaction_year
// 4. carryforward, countryname etc
bysort ID_adm2_num (transaction_year): carryforward ID_adm* id_*, replace 
bysort ID_adm2_num (years_reverse): carryforward ID_adm* id_*, replace
// 5. replace Financevar= 0 if Financevar==.
foreach g in IODA_ADM2_LOC IOOF_ADM2_LOC  IODA_ADM2_Wpop IOOF_ADM2_Wpop{
replace `g'= 0 if `g' ==.
}	
drop years_reverse ID_adm2_num
sort ID_adm* transaction_year

save adm2.dta, replace

/********************************************
CREATE ADM1 AID DATA
********************************************/
use cleaned.dta, clear

* Population weighted Aid Disbursements
bysort project_id transaction_year flow_type: egen totpop_ADM1=total(isum_pop_ADM1)
gen IAID_Wpop_ADM1=(usd_commit*isum_pop_ADM1)/totpop_ADM1
* Location weighted Aid Disbursements
gen n=1
bysort project_id transaction_year flow_type: egen locations=total(n)
gen IAID_LOC_ADM1=usd_commit/locations

collapse (sum) IAID_Wpop_ADM1 IAID_LOC_ADM1, by(ID_adm1 transaction_year flow_type)
* Distinguish official flows by type into ODA (Aid-like) and OOF (Other official finance: we still need to check if this broadly corresponds to development finance)
gen IODA_ADM1_Wpop=IAID_Wpop_ADM1 if flow_type=="ODA"
gen IOOF_ADM1_Wpop=IAID_Wpop_ADM1 if flow_type=="OOF" | flow_type=="OOF-like Export Credit"
gen IODA_ADM1_LOC=IAID_LOC_ADM1 if flow_type=="ODA"
gen IOOF_ADM1_LOC=IAID_LOC_ADM1 if flow_type=="OOF" | flow_type=="OOF-like Export Credit"

//continue with aid data preparation by setting missings to zero in order to be able to collapse correctly
 foreach l in Wpop LOC{
replace IODA_ADM1_`l'=0 if IODA_ADM1_`l'==.
replace IOOF_ADM1_`l'=0 if IOOF_ADM1_`l'==.
}

//dataset has now duplicates by flow_class since we divided IAID into IODA and IOOF. Collapse the data on regional level to get rid o0f duplicates
collapse (sum) IODA_ADM1_Wpop IOOF_ADM1_Wpop IODA_ADM1_LOC IOOF_ADM1_LOC, by(ID_adm1 transaction_year)

* TSFILL / fill out gaps in between data
sort ID_adm1 transaction_year
egen ID_adm1_num = group(ID_adm1)
// 2. tsset Geounit Jahr
tsset ID_adm1_num transaction_year
// 3. tsfill, full
tsfill, full //fill out data gaps
gen years_reverse =-transaction_year
// 4. carryforward, countryname etc
bysort ID_adm1_num (transaction_year): carryforward ID_adm* , replace 
bysort ID_adm1_num (years_reverse): carryforward ID_adm* , replace
// 5. replace Financevar= 0 if Financevar==.
foreach g in IODA_ADM1_Wpop IOOF_ADM1_Wpop IODA_ADM1_LOC IOOF_ADM1_LOC{
replace `g'= 0 if `g' ==.
}	
drop years_reverse ID_adm1_num
sort ID_adm* transaction_year

save adm1.dta, replace
* Note: ADM2 data of location weighted aid cannot be collapsed to ADM1 data, else loss of data
* XXXXXXXXXXX 06.12.2017 Lennart: Is this due to missing ADM2 data (white polygons) or something else? Otherwise we should discuss this point for the further cleaning process as it might be also relevant for other data.
/*
****************************************************
* Generate location weighted Aid in adjacent regions 
****************************************************
use "$data\ADM\1_1_1_R_pop_GADM1.dta", clear
renvars year rid1 isum_pop / transaction_year ID_adm1 isum_pop_ADM1
save ADM1POP.dta, replace

use "$data\ADM\1_1_1_R_pop_GADM2.dta", clear
renvars year rid2 isum_pop / transaction_year ID_adm2 isum_pop_ADM2
tempfile ADM2POP
save ADM2POP.dta, replace


* Need to do this on a yearly basis to prevent odd merges
use `adm2', clear
levelsof transaction_year, local(T)
foreach i in `T' {
use `adm2', clear
keep if transaction_year==`i'
* Mege with adjacent region
merge 1:m ID_adm2 using "$data\ADM\adm2_neighbors.dta", nogen keep(3 1)
* Merge with data on population 
merge m:1 ID_adm2 transaction_year using `ADM2POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) IODA_ADM2_LOC IOOF_ADM2_LOC  IODA_ADM2_Wpop IOOF_ADM2_Wpop isum_pop_ADM2, by(src_ID_admC12 transaction_year)
* Rename variables to indicate that they are in an adjacent region
foreach v in IODA_ADM2_LOC IOOF_ADM2_LOC  IODA_ADM2_Wpop IOOF_ADM2_Wpop {
rename `v' `v'_ADJ
}
renvars isum_pop_ADM2 src_ID_admC12 / Population_ADM2_ADJ ID_adm2
save `i'.dta, replace
}

* Put yearly disbursements in adjacent regions together (here only 2010 is used as we do not have any aid disbursements in previous years 
* XXXXXXXXXXX 06.12.2017 Lennart: We need to discuss if we take Indian aid into account for main analyses. If we would really do this, we should also consider using the complete conflict sample (so far we use only data up to 2012 as we focus on WB aid).
use `2010', clear
forvalues t=2011(1)2014 {
append using `t'
erase `i'.dta
}
erase 2010.dta
* Label variables
label var IODA_ADM2_LOC_ADJ "Indian ODA-like flows to adjacent regions (location weighted)"
label var IODA_ADM2_Wpop_ADJ "Indian ODA-like flows to adjacent regions (population weighted)"
label var IOOF_ADM2_LOC_ADJ "Indian other official finance to adjacent regions (location weighted)"
label var IOOF_ADM2_Wpop_ADJ "Indian other official finance to adjacent regions (population weighted)"
label var Population_ADM2_ADJ "Population in adjacent regions"
* Merge Disbursements in adjacent regions with disbursements in specific region
merge 1:1 ID_adm2 transaction_year using `adm2', nogen 

//some regions do not receive aid, but the adjacent ones. The merge introduces missings for these regions. Code them as getting no aid.
foreach var of varlist IODA_* IOOF_* {
replace `var'=0 if `var'==. 
}
save "$data\Aid\Indian_Finance_ADM2_adjacent.dta", replace 


* ADM1 LEVEL
* Need to do this on a yearly basis to prevent odd merges
use adm1.dta, clear
levelsof transaction_year, local(T)
foreach t in `T' {
use `adm1', clear
keep if transaction_year==`t'
* Mege with adjacent region
merge 1:m ID_adm1 using "$data\ADM\adm1_neighbors.dta", nogen keep(1 3)
* Merge with data on population 
merge m:1 ID_adm1 transaction_year using `ADM1POP', nogen keep(3 1)
* Collapse to get sum of WB aid (projects) in adjacent regions
collapse (sum) IODA_ADM1_LOC IOOF_ADM1_LOC  IODA_ADM1_Wpop IOOF_ADM1_Wpop isum_pop_ADM1, by(src_ID_admC7 transaction_year)
* Rename variables to indicate that they are in an adjacent region
foreach v in IODA_ADM1_LOC IOOF_ADM1_LOC  IODA_ADM1_Wpop IOOF_ADM1_Wpop {
rename `v' `v'_ADJ
}
renvars isum_pop_ADM1 src_ID_admC7 / Population_ADM1_ADJ ID_adm1
save `i'.dta, replace
}

* Put yearly disbursements in adjacent regions together

use 2010.dta, clear

* XXXXXXXXXXX 06.12.2017 Lennart: We need to discuss if we take Indian aid into account for main analyses. If we would really do this, we should also consider using the complete conflict sample (so far we use only data up to 2012 as we focus on WB aid).
forvalues t=2011(1)2014 {
append using `i'.dta
erase `i'.dta
}
erase 2010.dta
* Label variables
label var IODA_ADM1_LOC_ADJ "Indian ODA-like flows to adjacent regions (location weighted)"
label var IODA_ADM1_Wpop_ADJ "Indian ODA-like flows to adjacent regions (population weighted)"
label var IOOF_ADM1_LOC_ADJ "Indian other official finance to adjacent regions (location weighted)"
label var IOOF_ADM1_Wpop_ADJ "Indian other official finance to adjacent regions (population weighted)"
label var Population_ADM1_ADJ "Population in adjacent regions"
* Merge Disbursements in adjacent regions with disbursements in specific region
merge 1:1 ID_adm1 transaction_year using `adm1', nogen 

//some regions do not receive aid, but the adjacent ones. The merge introduces missings for these regions. Code them as getting no aid.
foreach var of varlist IODA_* IOOF_* {
replace `var'=0 if `var'==. 
}


save "$data\Aid\Indian_Finance_ADM1_adjacent.dta", replace 
*/



***************************
***************************
* E: Create Conflict Data *
***************************
***************************
cd "$data"

*** Prepare population data for population weighted distribution of ADM1 level aid
* Load GADM Data
import delim using "$data\ADM\gadm28adm2.csv", clear
keep objectidn100 isoc3 id_0n100 name_0c75 id_1n100 name_1c75 name_2c75 id_2n100
renvars objectidn100 isoc3  name_0c75 name_1c75 name_2c75  / OBJECTID ISO3 ADM0 ADM1 ADM2 
* Generate unique identifier for each ADM region:
gen c = "c"
gen r = "r"
egen ID_adm1 = concat(c id_0n100 r id_1n100)
egen ID_adm2 = concat(c id_0n100 r id_1n100 r id_2n100)
drop c r  id_0n100 
renvars id_1n100 id_2n100 / id_1 id_2
label var ID_adm2 "Unique identifier for ADM2 region"
duplicates drop OBJECTID, force
* 7 Regions are coded wrongly and are dropped
drop if ISO3==""
duplicates drop ID_adm2 ID_adm1 ADM0 ADM1 ADM2, force
drop OBJECTID

save gadm2.dta, replace

* Create yearly population totals
rename ID_adm2 rid2
merge 1:m rid2 using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen
rename rid2 ID_adm2
collapse (sum) isum_pop, by(ADM0 year ISO3)
renvars isum_pop year / c_pop transaction_year
label var c_pop "Total Country Population"

save country_pop.dta, replace


*** Load ACD2EPR Data as a tempfile to create ethnic conflict indicators
import delim using "$rawdata\ACD2EPR\ACD2EPR-2014-1.csv", clear delimiter(";")
rename dyadid dyad_dset_n100

* Transform ACD2EPR into a Panel
drop if from>2013
drop if to<1995
gen transaction_year=1995
gen id=_n
xtset id transaction_year
tsappend, add(17)
bysort id: carryforward statename dyad_dset_n100 gwid sideb sideb_id group gwgroupid from to claim recruitment support, replace
drop if from>transaction_year
drop if to<transaction_year
collapse (max) claim recruitment support, by(transaction_year dyad_dset_n100)

save ACD2EPR.dta, replace

* Import UCDP data
import delim using "$data\Conflict data\UCDP GED\ucdp_loc_gadm_cleaned_20171031.csv", clear delimiter(";")
* Keep all types of violence (1= State involved; 2 = Only non-state actors involved; 3 = Violence against civilians both by state and non-state actors)
keep if type_of_vi==1 | type_of_vi==2 | type_of_vi==3
* drop events, which took place in airspace or in international waters
drop if where_prec>4 // For all other data at least country should be available
tab best_est if country==""
* Lennart: We should decide, which variables we really need (e.g., priogrid_gid )
keep year where_prec active_yea adm_1 adm_2 country best_est   isoc3 name_0c75 name_1c75 name_2c75 id_* dyad_dset_n100  dyad_name type_of_vi


*Create best_est variables by type of violence
foreach var in best_est_t1 best_est_t2 best_est_t3g best_est_t3ng{
gen `var'=0
}
gen gvmt=0
replace gvmt=1 if strpos( dyad_name , "Government")
replace best_est_t1=best_estn100 if type_of_vi==1
replace best_est_t2=best_estn100 if type_of_vi==2
replace best_est_t3g=best_estn100 if type_of_vi==3 & gvmt==1
replace best_est_t3ng=best_estn100 if type_of_vi==3 & gvmt==0


* Renaming
rename year transaction_year
* Lennart: For 8,972  observations the iso-code from GED!= iso-code from GADM --> Mostly due to cases like Soviet Union vs Russia or Israel vs. Palestine, but need to double check. I would suggest ISO Codes from GADM
renvars iso name_0c75 name_1c75 name_2c75 adm_1  adm_2 dyad_namec254  / ISO3 ADM0 ADM1 ADM2 ADM1_UCDP ADM2_UCDP dyad_name 


*create unique region ids
gen c = "c"
gen r = "r"
egen ID_adm1 = concat(c id_0 r id_1)
egen ID_adm2 = concat(c id_0 r id_1 r id_2)

drop c r

* Drop some observations, which miss years
destring best_est* transaction_year, replace

*Merge with Indicators on ethnic conflict characteristics
merge m:1 dyad_dset_n100 transaction_year using `ACD2EPR', nogen keep(1 3)
* Replace missings with zeroes assuming that the dataset is comprehensive @ Kai and Melvin: Does this makes sense?
replace claim=0 if claim==. 
replace recruitment=0 if recruitment==.
replace support=0 if support==.
gen ethnic=0
replace ethnic=1 if claim>0 & recruitment>0 & support>0
tempfile brdprec1234
save `brdprec1234', replace

keep if where_prec==4

save brdprec4.dta, replace


* Prepare location weighted data with precision code 4 (ADM2 information)
use brdprec4.dta, replace
gen count=1
bysort ID_adm1 transaction_year: egen incidence_adm14=total(count)



collapse (sum) best_est*  (mean) incidence_adm14, by(transaction_year ISO3 ADM0 ADM1 ID_adm1 ethnic)

renvars best_estn100 best_est_t1 best_est_t2 best_est_t3g best_est_t3ng / best_est_adm14 best_est_t1_adm14 best_est_t2_adm14 best_est_t3g_adm14 best_est_t3ng_adm14 

joinby ID_adm1 using gadm2.dta, update
//create missing id variables after joining datasets
gen c = "c"
gen r = "r"
drop ID_adm2
egen ID_adm2 = concat(c ID_0N100 r ID_1N100 r ID_2N100)
drop c r

gen count=1
bysort ID_adm1 transaction_year: egen count1=total(count)
replace count1=0 if count1==.
foreach g in best_est_adm14 best_est_t1_adm14 best_est_t2_adm14 best_est_t3g_adm14 best_est_t3ng_adm14  incidence_adm14{
replace `g'=`g'/count1
replace `g'=round(`g')
}

renvars best_est_adm14 best_est_t1_adm14 best_est_t2_adm14 best_est_t3g_adm14 best_est_t3ng_adm14   incidence_adm14 / best_est_adm24 best_est_t1_adm24 best_est_t2_adm24 best_est_t3g_adm24 ///
best_est_t3ng_adm24 incidence_adm24 
keep best_est_adm24  best_est_t1_adm24 best_est_t2_adm24 best_est_t3g_adm24 best_est_t3ng_adm24  incidence_adm24 transaction_year ISO3 ADM0 ADM1 ID_adm1 ID_adm2 ethnic

save Conflict_ADM2_prec4.dta, replace 

* Prepare population weighted data with precision code 4 (ADM2 information)
use brdprec4.dta, replace
gen count=1
bysort ID_adm1 transaction_year: egen incidence_adm14=total(count)
collapse (sum) best_est* (mean) incidence_adm14, by(transaction_year ISO3 ADM0 ADM1 ID_adm1 ethnic)

renvars best_estn100 best_est_t1 best_est_t2 best_est_t3g best_est_t3ng / best_est_adm14 best_est_t1_adm14 best_est_t2_adm14 best_est_t3g_adm14 best_est_t3ng_adm14 

joinby ID_adm1 using gadm2.dta, update
//create missing id variables after joining datasets
gen c = "c"
gen r = "r"
drop ID_adm2
egen ID_adm2 = concat(c ID_0N100 r ID_1N100 r ID_2N100)
drop c r

* Need to assume once again that some ADM1 regions are ADM2 regions as they are missing in our data
	replace id_2=0 if id_1!=. & id_2==. //save one observation where there is actually one obs with project side for adm1 region    @Melvin: Keine Änderungen werden angezeigt??? //MW: Possible explanation; Lennart changed disbursement.dta. Previously only projects with code "C" instead of "D" where included.
	drop if id_2==. //there are a lot of them without data on location  KG: @Melvin: A lot? Stata says 63? Komisch dass ich in dem TempFile die ID_2 Variable nicht sehe? Oder wird das nicht angezeigt? Ich sehe nur ID_adm2 ID_2N100
	  
	//create dummy variable indicating if a GADM2 region is missing, thus have been replaced by GADM1 region
	gen byte d_miss_ADM2=(id_2==0 & id_1!=0)

* Merge with Population data
renvars transaction_year ID_adm2 / year rid2
merge m:1 rid2 year using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen
renvars year rid2 /  transaction_year ID_adm2

* Create Incidence Count
bysort ID_adm1 ethnic transaction_year: egen pop_adm1=sum(isum_pop)
gen incidence_adm24=(incidence_adm14*isum_pop)/pop_adm1
replace incidence_adm24=round(incidence_adm24,1)
* Weight Aid
foreach var in best_est_adm  best_est_t1_adm best_est_t2_adm best_est_t3g_adm best_est_t3ng_adm {
gen `var'24=(`var'14*isum_pop)/pop_adm1
replace `var'24=round(`var'24,1)
}
keep best_est_adm24 best_est_t1_adm24 best_est_t2_adm24 best_est_t3g_adm24 best_est_t3ng_adm24 incidence_adm24 transaction_year ISO3 ADM0 ADM1 ID_adm1 ID_adm2 ethnic

save Conflict_Wpop_ADM2_prec4.dta, replace 

use brdprec1234.dta, clear
keep if where_prec==1 | where_prec==2 | where_prec==3

********************************************************************************
//Generate yearly regional totals
********************************************************************************
* Prepare a count variable for yearly conflict incidences
gen count=1
bysort ID_adm2 transaction_year ethnic: egen incidence_adm2=total(count)


* Here we loose information on whether it was an active year of an ongoing conflict and the type of violence. This needs to be discussed in the group, whether we can miss these variables
* Some regions miss ADM2 codes. Here we should check if these are similar countries like in the Aid-GADM merge (e.g., Cape Verde, Macedonia, Armenia...)
collapse (sum) best_est* (mean) incidence_adm2, by(ADM0 ADM1 ADM2  ISO3 transaction_year ID_adm1 ID_adm2 ethnic)
renvars best_estn100   best_est_t1 best_est_t2 best_est_t3g best_est_t3ng \ best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2
merge 1:1 ID_adm2 transaction_year ethnic using Conflict_ADM2_prec4.dta, nogen keep(1 3)
* Replace zeroes
foreach var in best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2 best_est_adm24 best_est_t1_adm24 best_est_t2_adm24 best_est_t3g_adm24 ///
best_est_t3ng_adm24 incidence_adm24 {
replace `var'=0 if `var'==.
}
* Add up BRDs
foreach v in best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2{
replace `v' = `v'+ `v'4
}

drop  best_est_adm24 best_est_t1_adm24 best_est_t2_adm24 best_est_t3g_adm24 best_est_t3ng_adm24 incidence_adm24 
reshape wide best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2 , i(ADM0 ADM1 ADM2  ISO3 transaction_year ID_adm1 ID_adm2) j(ethnic)
renvars  best_est_adm20 best_est_t1_adm20 best_est_t2_adm20 best_est_t3g_adm20 best_est_t3ng_adm20 incidence_adm20 ///
  \ best_est_adm2_nonethnic best_est_t1_adm2_nonethnic best_est_t2_adm2_nonethnic best_est_t3g_adm2_nonethnic best_est_t3ng_adm2_nonethnic incidence_adm2_nonethnic
renvars  best_est_adm21 best_est_t1_adm21 best_est_t2_adm21 best_est_t3g_adm21 best_est_t3ng_adm21 incidence_adm21 ///
  \ best_est_adm2_ethnic best_est_t1_adm2_ethnic best_est_t2_adm2_ethnic best_est_t3g_adm2_ethnic best_est_t3ng_adm2_ethnic incidence_adm2_ethnic


* Fill Up missings as we assume that our dataset is comprehensive
foreach e in ethnic nonethnic{
foreach v in best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2{
replace `v'_`e'=0 if best_est_adm2_`e'==.  
}
}



sum best* 
duplicates tag ISO3 ADM1 transaction_year, gen(tag)
drop if tag>1 & ADM2==""
drop tag


	//drop if ID_2n100==0 
	replace ID_adm2="ADM2 Missing" if ID_adm1!="" & ID_adm2=="c0r0r0" //save one observation where there is actually one obs with project side for adm1 region  
	drop if ID_adm2=="c0r0r0" 
	drop if ID_adm1=="c0r0"
	
	//create dummy variable indicating if a GADM2 region is missing, thus have been replaced by GADM1 region
	gen byte d_miss_ADM2=(ID_adm2=="ADM2 Missing" & ID_adm1!="")

destring transaction_year, replace
	****create balanced dataset without gaps (assumption perfect data on conflict occurence, that is, if there is no data, then it is not missing but no conflict at all, = 0) 
	//ADM2 level
	sort ID_adm1 transaction_year
	egen ID_adm2_num = group(ID_adm2)
	//2. tsset Geounit Jahr
	tsset ID_adm2_num transaction_year
	// 3. tsfill, full
	tsfill, full //fill out data gaps
	gen years_reverse =-transaction_year
	// 4. carryforward, countryname etc
	bysort ID_adm2_num (transaction_year): carryforward ID_adm* ADM* ISO3 ID_* d_miss_ADM2, replace 
	bysort ID_adm2_num (years_reverse): carryforward ID_adm*  ADM* ISO3 ID_* d_miss_ADM2, replace
	// 5. replace Conflictvar= 0 if Conflictvar==.
foreach e in ethnic nonethnic{
foreach v in best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2{
replace `v'_`e'=0 if `v'_`e'==.  
}
}
	drop years_reverse
	order transaction_year ID_adm*
	sort ID_adm* transaction_year
	* Calculate ADM1 level battle related deaths
	foreach e in ethnic nonethnic{
	foreach v in best_est_adm best_est_t1_adm best_est_t2_adm best_est_t3g_adm best_est_t3ng_adm incidence_adm{

bysort ID_adm1 transaction_year: egen `v'1_`e'=total(`v'2_`e')
}
}
* Generate Totals of ethnic and non-ethnic conflicts
foreach t in best_est_adm best_est_t1_adm best_est_t2_adm best_est_t3g_adm best_est_t3ng_adm incidence_adm {
foreach v in 1 2{
gen `t'`v'=`t'`v'_ethnic+`t'`v'_nonethnic
label var `t'`v' "Overall casulaties/incidences per ADM`v' region per year"
}
}


	save "$data\Conflict Data\UCDP_GED_ADM2_tsfill(Ethnic vs Non-Ethnic).dta", replace

	
use `brdprec1234', clear
keep if where_prec==1 | where_prec==2 | where_prec==3

********************************************************************************
//Generate yearly regional totals
********************************************************************************
* Prepare a count variable for yearly conflict incidences
gen count=1
bysort ID_adm2 transaction_year ethnic: egen incidence_adm2=total(count)


* Here we loose information on whether it was an active year of an ongoing conflict and the type of violence. This needs to be discussed in the group, whether we can miss these variables
* Some regions miss ADM2 codes. Here we should check if these are similar countries like in the Aid-GADM merge (e.g., Cape Verde, Macedonia, Armenia...)
collapse (sum) best_est* (mean) incidence_adm2, by(ADM0 ADM1 ADM2  ISO3 transaction_year ID_adm1 ID_adm2 ethnic)
renvars best_estn100   best_est_t1 best_est_t2 best_est_t3g best_est_t3ng \ best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2
merge 1:1 ID_adm2 transaction_year ethnic using `Conflict_Wpop_ADM2_prec4', nogen keep(1 3)
* Replace zeroes
foreach var in best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2 best_est_adm24 best_est_t1_adm24 best_est_t2_adm24 best_est_t3g_adm24 ///
best_est_t3ng_adm24 incidence_adm24 {
replace `var'=0 if `var'==.
}
* Add up BRDs
foreach v in best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2{
replace `v' = `v'+ `v'4
}

drop  best_est_adm24 best_est_t1_adm24 best_est_t2_adm24 best_est_t3g_adm24 best_est_t3ng_adm24 incidence_adm24 
reshape wide best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2 , i(ADM0 ADM1 ADM2  ISO3 transaction_year ID_adm1 ID_adm2) j(ethnic)
renvars  best_est_adm20 best_est_t1_adm20 best_est_t2_adm20 best_est_t3g_adm20 best_est_t3ng_adm20 incidence_adm20 ///
  \ best_est_adm2_nonethnic best_est_t1_adm2_nonethnic best_est_t2_adm2_nonethnic best_est_t3g_adm2_nonethnic best_est_t3ng_adm2_nonethnic incidence_adm2_nonethnic
renvars  best_est_adm21 best_est_t1_adm21 best_est_t2_adm21 best_est_t3g_adm21 best_est_t3ng_adm21 incidence_adm21 ///
  \ best_est_adm2_ethnic best_est_t1_adm2_ethnic best_est_t2_adm2_ethnic best_est_t3g_adm2_ethnic best_est_t3ng_adm2_ethnic incidence_adm2_ethnic


* Fill Up missings as we assume that our dataset is comprehensive
foreach e in ethnic nonethnic{
foreach v in best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2{
replace `v'_`e'=0 if best_est_adm2_`e'==.  
}
}


sum best* 
duplicates tag ISO3 ADM1 transaction_year, gen(tag)
drop if tag>1 & ADM2==""
drop tag


	//drop if ID_2n100==0 
	replace ID_adm2="ADM2 Missing" if ID_adm1!="" & ID_adm2=="c0r0r0" //save one observation where there is actually one obs with project side for adm1 region  
	drop if ID_adm2=="c0r0r0" 
	drop if ID_adm1=="c0r0"
	
	//create dummy variable indicating if a GADM2 region is missing, thus have been replaced by GADM1 region
	gen byte d_miss_ADM2=(ID_adm2=="ADM2 Missing" & ID_adm1!="")

destring transaction_year, replace
	****create balanced dataset without gaps (assumption perfect data on conflict occurence, that is, if there is no data, then it is not missing but no conflict at all, = 0) 
	//ADM2 level
	sort ID_adm1 transaction_year
	egen ID_adm2_num = group(ID_adm2)
	//2. tsset Geounit Jahr
	tsset ID_adm2_num transaction_year
	// 3. tsfill, full
	tsfill, full //fill out data gaps
	gen years_reverse =-transaction_year
	// 4. carryforward, countryname etc
	bysort ID_adm2_num (transaction_year): carryforward ID_adm* ADM* ISO3 ID_* d_miss_ADM2, replace 
	bysort ID_adm2_num (years_reverse): carryforward ID_adm*  ADM* ISO3 ID_* d_miss_ADM2, replace
	// 5. replace Conflictvar= 0 if Conflictvar==.
foreach e in ethnic nonethnic{
foreach v in best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2{
replace `v'_`e'=0 if `v'_`e'==.  
}
}
	drop years_reverse
	order transaction_year ID_adm*
	sort ID_adm* transaction_year
	* Calculate ADM1 level battle related deaths
	foreach e in ethnic nonethnic{
	foreach v in best_est_adm best_est_t1_adm best_est_t2_adm best_est_t3g_adm best_est_t3ng_adm incidence_adm{

bysort ID_adm1 transaction_year: egen `v'1_`e'=total(`v'2_`e')
}
}
* Generate Totals of ethnic and non-ethnic conflicts
foreach t in best_est_adm best_est_t1_adm best_est_t2_adm best_est_t3g_adm best_est_t3ng_adm incidence_adm {
foreach v in 1 2{
gen `t'`v'=`t'`v'_ethnic+`t'`v'_nonethnic
label var `t'`v' "Overall casulaties/incidences per ADM`v' region per year"
}
}


	save "$data\Conflict Data\UCDP_GED_ADM2_Wpop_tsfill(Ethnic vs Non-Ethnic).dta", replace
	
	


***************************
* Generate Conflict in adjacent regions 

** ADM2
* Load adjacency matrix for ADM2 regions
import excel using "$data\ADM\adm2_neighbors.xls", firstrow clear  //This dataset was created via adjacent_adm_classification.py. We use this adjacency matrix to match each ADM region with the battle related deaths in adjacent ADM regions.
* Drop Adjacent Regions in other country
drop if src_Name_0C75!= nbr_NAME_0C75
rename nbr_ID_ADMC12 ID_adm2
save "$data\ADM\adm2_neighbors.dta", replace

* Merge Adjacency matrix with conflict in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Conflict Data\UCDP_GED_ADM2_tsfill(Ethnic vs Non-Ethnic).dta", clear // The battle related deaths are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the conflict casualties in adjacent regions.
drop if transaction_year!=`i'
merge 1:m ID_adm2 using "$data\ADM\adm2_neighbors.dta", nogen keep(3 1)
* Collapse to get sum of battle related deaths in adjacent regions
collapse (sum) best_est*adm2* incidence*adm2* , by(src_ID_admC12  transaction_year)
rename src_ID_admC12 ID_adm2
duplicates report ID_adm2
* Rename sums for adjacent regions
renvars best_est_adm2 best_est_t1_adm2 best_est_t2_adm2 best_est_t3g_adm2 best_est_t3ng_adm2 incidence_adm2  /// 
/ best_est_adm2_adj best_est_t1_adm2_adj best_est_t2_adm2_adj best_est_t3g_adm2_adj best_est_t3ng_adm2_adj incidence_adm2_adj
foreach e in ethnic nonethnic{
renvars best_est_adm2_`e' best_est_t1_adm2_`e' best_est_t2_adm2_`e' best_est_t3g_adm2_`e' best_est_t3ng_adm2_`e' incidence_adm2_`e'  /// 
/ best_est_adm2_adj_`e' best_est_t1_adm2_adj_`e' best_est_t2_adm2_adj_`e' best_est_t3g_adm2_adj_`e' best_est_t3ng_adm2_adj_`e' incidence_adm2_adj_`e'
}
keep ID_adm2 best_est*_adm2_adj* transaction_year  incidence_adm2_adj*
tempfile `i'
save `i', replace 
}
* Put yearly battle related deaths together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'

}

* Merging the battle related deaths in adjacent regions with the initial file on battle related deaths in regions itself
merge 1:1 ID_adm2 transaction_year using "$data\Conflict Data\UCDP_GED_ADM2_tsfill(Ethnic vs Non-Ethnic).dta", nogen keep(2 3)  


foreach v in best_est_adm2_adj best_est_t1_adm2_adj best_est_t2_adm2_adj best_est_t3g_adm2_adj best_est_t3ng_adm2_adj incidence_adm2_adj{
label var `v' "Battle related death in all adjacent administrative regions (best estimate)"
replace `v'=0 if `v'==.
foreach e in ethnic nonethnic{
label var `v'_`e' "Battle related death in all adjacent administrative regions (best estimate) from `e' war"
* Replace missings (Given the assumption that our dataset is comprehensive)
replace `v'_`e'=0 if `v'_`e'==.
}
}
tempfile ADM2adj
save `ADM2adj', replace 


** ADM1
* Load adjacency matrix for ADM1 regions
import excel using "$data\ADM\adm1_neighbors.xls", firstrow clear
renvars src_ID_0N100 src_ID_1N100  nbr_ID_0N100 nbr_ID_1N100 / src_id_0 src_id_1 nbr_id_0 nbr_id_1
*create unique region ids
gen c = "c"
gen r = "r"
egen src_ID_admC7 = concat(c src_id_0 r src_id_1)
egen nbr_ID_admC7 = concat(c nbr_id_0 r nbr_id_1)
drop c r
rename nbr_ID_admC7 ID_adm1
* Drop Adjacent Regions in other country
drop if src_Name_0C75!= nbr_NAME_0C75


save "$data\ADM\adm1_neighbors.dta", replace

* Merge Adjacency matrix with conflict in adjacent regions
forvalues i=1995(1)2012 {
use "$data\Conflict Data\UCDP_GED_ADM2_tsfill(Ethnic vs Non-Ethnic).dta", clear // The battle related deaths are matched in this step with the adjacent regions. Afterwards we collapse to receive the sum of the conflict casualties in adjacent regions.
drop if transaction_year!=`i'
collapse (mean) best_est*_adm1* incidence_adm1* , by(ID_adm1 transaction_year)
merge 1:m ID_adm1 using "$data\ADM\adm1_neighbors.dta", nogen keep(3 1)
* Collapse to get sum of battle related deaths in adjacent regions
collapse (sum) best_est*_adm1* incidence_adm1* , by(src_ID_admC7 transaction_year)
rename src_ID_admC7  ID_adm1
duplicates report ID_adm1
* Rename Sums to indicate that they are based on adjacent regions
renvars best_est_adm1 best_est_t1_adm1 best_est_t2_adm1 best_est_t3g_adm1 best_est_t3ng_adm1 incidence_adm1  /// 
/ best_est_adm1_adj best_est_t1_adm1_adj best_est_t2_adm1_adj best_est_t3g_adm1_adj best_est_t3ng_adm1_adj incidence_adm1_adj
foreach e in ethnic nonethnic{
renvars best_est_adm1_`e' best_est_t1_adm1_`e' best_est_t2_adm1_`e' best_est_t3g_adm1_`e' best_est_t3ng_adm1_`e' incidence_adm1_`e'  /// 
/ best_est_adm1_adj_`e' best_est_t1_adm1_adj_`e' best_est_t2_adm1_adj_`e' best_est_t3g_adm1_adj_`e' best_est_t3ng_adm1_adj_`e' incidence_adm1_adj_`e'
}

keep ID_adm1 best_est*_adm1_adj*  incidence_adm1_adj* transaction_year
tempfile `i'
save `i', replace 
}
* Put yearly battle related deaths together
clear
use 1995
forvalues i=1996(1)2012 {
append using `i'

}

* Merging the battle related deaths in adjacent regions with the initial file on battle related deaths in regions itself
merge 1:m ID_adm1 transaction_year using `ADM2adj', nogen keep(2 3)  
* Provide Labels and Replace Missings
foreach v in best_est_adm1_adj best_est_t1_adm1_adj best_est_t2_adm1_adj best_est_t3g_adm1_adj best_est_t3ng_adm1_adj incidence_adm1_adj{
label var `v' "Battle related death in all adjacent administrative regions (best estimate)"
replace `v'=0 if `v'==.
foreach e in ethnic nonethnic{
label var `v'_`e' "Battle related death in all adjacent administrative regions (best estimate) from `e' war"
* Replace missings (Given the assumption that our dataset is comprehensive)
replace `v'_`e'=0 if `v'_`e'==.
}
}
save "$data\Conflict Data\UCDP_GED_ADM2_tsfill_adjacent(Ethnic vs Non-Ethnic).dta", replace



**********************
**********************
* F: Create Controls *
**********************
**********************


* Prepare Night Light Data on the ADM1 level
cd "$rawdata\Control variables soil and nightlight and elevation\processed_light\adm1"
foreach i in F121995 F121996 F121997 F121998 F121999 F141997 F141998 F141999 F142000 F142001 F142002 F142003 F152000 F152001 F152002 F152003 F152004 F152005 F152006 F152007 F162004 F162005 F162006 F162007 F162008 F162009 F182010 F182011 F182012 F182013 {
import excel using "`i'.xls", firstrow clear
gen transaction_year=substr("`i'",4,7)
destring transaction_year, replace
tempfile `i'
save `i', replace 
}

foreach i in F121995 F121996 F121997 F121998 F121999 F141997 F141998 F141999 F142000 F142001 F142002 F142003 F152000 F152001 F152002 F152003 F152004 F152005 F152006 F152007 F162004 F162005 F162006 F162007 F162008 F162009 F182010 F182011 F182012 {
append using `i'
}
collapse (mean) MEAN AREA, by (OBJECTID transaction_year)
drop if transaction_year>2012 | transaction_year<1995
tempfile ADM1NLIGHTS
save "$data\dataprocessed\ADM1NLIGHTS.dta", replace



* Prepare Night Light Data on the ADM2 level
cd "$rawdata\Control variables soil and nightlight and elevation\processed_light\adm2"
foreach i in F121995 F121996 F121997 F121998 F121999 F141997 F141998 F141999 F142000 F142001 F142002 F142003 F152000 F152001 F152002 F152003 F152004 F152005 F152006 F152007 F162004 F162005 F162006 F162007 F162008 F162009 F182010 F182011 F182012 F182013 {
import excel using "`i'.xls", firstrow clear
gen transaction_year=substr("`i'",4,7)
destring transaction_year, replace
tempfile `i'
save `i', replace 
}

foreach i in F121995 F121996 F121997 F121998 F121999 F141997 F141998 F141999 F142000 F142001 F142002 F142003 F152000 F152001 F152002 F152003 F152004 F152005 F152006 F152007 F162004 F162005 F162006 F162007 F162008 F162009 F182010 F182011 F182012 {
append using `i'
}
collapse (mean) MEAN AREA, by (OBJECTID transaction_year)
drop if transaction_year>2012 | transaction_year<1995
tempfile ADM2NLIGHTS
save "$data\dataprocessed\ADM2NLIGHTS.dta", replace


*xxxxxxxxxx Melvin 14.11.2017: Clean up folder and erase temp file
erase gadm2.dta
erase country_pop.dta
erase IDA_disbursement_ADM1_prec4.dta
erase IDA_disbursement_ADM2_prec4.dta
erase IDA_disbursement_ADM1_Wpop_prec4.dta
erase IDA_disbursement_ADM2_Wpop_prec4.dta
erase ADM1POP.dta
erase ADM2POP.dta
erase ancillary.dta
erase OF.dta
erase adm1_v.dta.dta
erase cleaned.dta
erase prec123.dta
erase prec4.dta
erase adm2.dta
erase adm1.dta
erase adm1_v.dta
erase ACD2EPR.dta
erase brdprec4.dta
erase Conflict_ADM2_prec4.dta
erase Conflict_Wpop_ADM2_prec4.dta
erase brdprec1234.dta, clear
