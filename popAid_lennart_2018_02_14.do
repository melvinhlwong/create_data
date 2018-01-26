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
//2) Prepare location weighted data with precision code
********************************************************************************
*****Generate location weighted data with precision code 1-3 (ADM2 information) for ADM2 level****
use "$data\Aid\2017_11_14_WB\IDA_disbursement.dta", clear
 
keep if precision_N100<4

* XXXXXXXX Lennart 04.01.2018: Allocate aid according to the number of locations and the general share of precison-123-locations per project //
* For instance 100 [transaction_value_tot] / 3 (number of projects coded with precision 1-3) [totalcount] * 3/8 (number of projects with precision1-3/number of projects with precision1-4) [temp_totcoded4/temp_totcoded]
/*XXXXXX Melvin 05.01.2018: @Lennart, why is transaction_value_loc not just transaction_value_tot/totalcount 
(total number of projects with prec13 AND prec4), but additionally multiplied by (temp_totcoded13/temp_totcoded)?
In fact, transaction_value_loc are the same for a project ID and year when comparing keeping precision<4 and ==4
e.g. br project_id transaction_year temp_value precision_N100  transaction_value_tot transaction_value_loc if project_id=="P000603"
*/
*XXXXXX Melvin 05.01.2018: @Lennart totalcount and temp_totcoded13 are always the same and will always cancel each other out. Hence, transaction_value_loc is de facto transaction_value_tot/temp_totcoded
*XXXXXX Melvin 05.01.2018: deleted and changed after correspondence with Lennart
gen transaction_value_loc=transaction_value_tot/temp_totcoded
* XXX Lennart 04.01.2018: Apply this allocation scheme to the disbursementcount
replace Disbursementcount=Disbursementcount/temp_totcoded
* XXXXXXX Lennart 04.01.2018: Redo Excercise for sectoral disbursements
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen transaction_value_loc_`g'=transaction_value_tot_`g'/temp_totcoded
replace Disbursementcount_`g'=Disbursementcount_`g'/temp_totcoded
}

*XXXXXX Melvin 05.01.2018: @Lennart, is this collapse correct? There are some regions where ID_2 is "." 
* Collapse on ADM2 level to aggregate all project disbursements per ADM2 region
collapse (sum) transaction_value_loc* Disbursementcount*, by(transaction_year ISO3  ADM0 ADM1 ADM2 ID_0 ID_1 ID_2 ID_adm1 ID_adm2)

* Rename Variables
renvars transaction_value_loc Disbursementcount / WBAID_ADM2_LOC13 Disbursementcount_ADM213
foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars transaction_value_loc_`g' Disbursementcount_`g' / WBAID_ADM2_LOC_`g'13 Disbursementcount_ADM2_`g'13
}
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_prec13.dta", replace 


**** Generate location weighted data with precision code 4 (Only ADM1 information) for ADM1 level**** 
use "$data\Aid\2017_11_14_WB\IDA_disbursement.dta", clear
keep if (precision_N100==4)

* XXXXXXXX Lennart 04.01.2018: Allocate aid according to the number of locations and the general share of precison-4-locations per project //
* For instance 100 [transaction_value_tot] / 5 (number of projects coded with precision 4) [totalcount] * 5/8 (number of projects with precision4/number of projects with precision1-4) [temp_totcoded4/temp_totcoded]
*XXXXXX Melvin 05.01.2018: @Lennart totalcount and temp_totcoded4 are always the same and will always cancel each other out. Hence, transaction_value_loc is de facto transaction_value_tot/temp_totcoded
*XXXXXX Melvin 05.01.2018: deleted and changed after correspondence with Lennart
gen transaction_value_loc=transaction_value_tot/temp_totcoded
*XXXXXX Melvin 29.12.2017: @Lennart, what is the purpose of this new disbursement count (general and for the sectors)?
* XXXXXXXX Lennart 04.01.2018: @ Melvin, this is also a location weighted allocation of disbursementcounts. This corresponds most closely to the approach for the amounts. We could discuss if this is meaningful.
replace Disbursementcount=Disbursementcount/temp_totcoded
* XXXXXXX Lennart 04.01.2018: Redo Excercise for sectoral disbursements
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen transaction_value_loc_`g'=transaction_value_tot_`g'/temp_totcoded
replace Disbursementcount_`g'=Disbursementcount_`g'/temp_totcoded
}

collapse (sum) transaction_value_loc* Disbursementcount*, by(transaction_year ISO3 ID_0 ID_1 ADM0 ADM1 ID_adm1)
* Round Disbursementcounts to full numbers
*XXXXXX Melvin 29.12.2017: @Lennart, this creates an error, I guess. The disbursement count for ALB in 1995 is rounded from 0.111 to 0
*XXXXXX Lennart 04.01.2018: @ Kai & Melvin - After correspondence with Melvin, I deleted the rounding. Otherwise, we might face a lot of zeros. The unintuitive interpretation of fractional transactions/disbursements is still sensical from a statistical point of view.
renvars transaction_value_loc Disbursementcount / WBAID_ADM1_LOC4 Disbursementcount_ADM14
foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars transaction_value_loc_`g' Disbursementcount_`g' / WBAID_ADM1_LOC_`g'4 Disbursementcount_ADM1_`g'4
}
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_prec4.dta", replace 

* Prepare location weighted data with precision code 4 (ADM2 information)
/*
*XXXXXX Melvin 29.12.2017: @Lennart,what is the advantage of joinby? It creates more observations here
* XXXXXXX Lennart 04.01.2018: @Melvin, joinby offers the option to merge also if identifiers are non-unique (e.g., panel of ADM1 regions with cross-section of ADM2 regions). But this comes with some risks of duplicates and lost data. //
* XXXXXXX Lennart 04.01.2018: Hence, we stick now to cross-sectional merges, which are repeated across years. This part would then be obsolete and could be deleted.
joinby ID_adm1 using gadm2.dta
/*XXXXXX Melvin 29.12.2017: The following section is redundant now
* Need to assume once again that some ADM1 regions are ADM2 regions as they are missing in our data
	replace ID_2=0 if ID_1!=. & ID_2==. //save one observation where there is actually one obs with project side for adm1 region    @Melvin: Keine Änderungen werden angezeigt??? //MW: Possible explanation; Lennart changed disbursement.dta. Previously only projects with code "C" instead of "D" where included.
	drop if ID_2==. //there are a lot of them without data on location  KG: @Melvin: A lot? Stata says 63? Komisch dass ich in dem TempFile die ID_2 Variable nicht sehe? Oder wird das nicht angezeigt? Ich sehe nur ID_adm2 ID_2N100
	  
	//create dummy variable indicating if a GADM2 region is missing, thus have been replaced by GADM1 region
	gen byte missing_GADM2=(ID_2==0 & ID_1!=0)
*/
*/
* XXXXX Lennart 04.01.2018: Due to the potential for duplicates and erroneous merges, we go with classical merge-command instead of joinby on a yearly level
forvalues i=1995(1)2012 {
use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_prec4.dta", replace
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

* XXXX Lennart 04.01.2018: Split ADM1 level aid of precision 4 equally across corresponding ADM2 regions
gen count=1
bysort ID_adm1 transaction_year: egen totalcount=total(count)

* allocate aid with prec4 to all ADM2 regions 
gen WBAID_ADM2_LOC4 =WBAID_ADM1_LOC4 /totalcount
*XXXXXX Melvin 29.12.2017: @Lennart, same comment:what is the purpose of this? Could you comment the steps? e.g. why do disbursemnt count sum up?
* XXXXXX Lennart 04.01.2018: @ Melvin: This is to distribute the disbursement / transaction count analogously to the aid amounts.
gen Disbursementcount_ADM24=Disbursementcount_ADM14/totalcount
foreach g in AX BX CX EX FX JX LX TX WX YX{
gen WBAID_ADM2_LOC_`g'4 =WBAID_ADM1_LOC_`g'4  /totalcount
gen Disbursementcount_ADM2_`g'4=Disbursementcount_ADM1_`g'4/totalcount
drop WBAID_ADM1_LOC_`g'4 Disbursementcount_ADM1_`g'4
}
drop WBAID_ADM1_LOC4 Disbursementcount_ADM14
*XXXXXX Melvin 29.12.2017: @Lennart, same as above. rounding error?
* XXXXXXX Lennart 04.01.2018: @Melvin, in line with the previous comments, I deleted the parts on rounding.
save "$data\Aid\2017_11_14_WB\IDA_Disbursement_ADM2_prec4.dta", replace 



* XXXXXXXXXX Lennart 04.01.2018: Merge data with precision code 4 and precision codes 1-3 to create location weighted aid on ADM2 level
use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_prec13.dta", clear

*	collapse (sum) transaction_value_adm2 (max) missing_GADM2, by(ID_adm2 transaction_year ID_adm1 ADM0 ADM1 ADM2 ID_1N100 ID_0N100 ID_2N100 ISO3) // @ Melvin: Shouldn't we drop duplicates of project_ids here as we already summed up the values for different locations of one project. I am not sure, but would be better to double check.
*	XXXXXX Lennart, 05.01.2018: In the following step we lose around 200 million of aid (0.32% of total allocated aid), which could not be attributed to regions preivously as we had no ID_0, which indicates that something with the geo-merge went wrong
drop if ID_0==0 //No geographic information available for AID projects (Missing Aid information worth about 5bn USD)
	
	
* XXXXX Lennart 04.01.2018: Rename variables with precisioncode 1-3 to prepare them for merge with precisioncode 4
renvars WBAID_ADM2_LOC13 Disbursementcount_ADM213 / WBAID_ADM2_LOC Disbursementcount_ADM2_LOC
foreach g in AX BX CX EX FX JX LX TX WX YX{
	renvars WBAID_ADM2_LOC_`g'13 Disbursementcount_ADM2_`g'13 / WBAID_ADM2_LOC_`g'  Disbursementcount_ADM2_LOC_`g' 
}

* Add data with precisioncode 4:
merge 1:1 ID_adm2 transaction_year using "$data\Aid\2017_11_14_WB\IDA_Disbursement_ADM2_prec4.dta",  nogen
* Replace missings
replace WBAID_ADM2_LOC=0 if WBAID_ADM2_LOC==.
replace WBAID_ADM2_LOC4=0 if WBAID_ADM2_LOC4 ==.
	* XXXX  Lennart 11.01.2018: In line with Melvin's command below, we replace all missing disbursementcounts
replace Disbursementcount_ADM24=0 if Disbursementcount_ADM24==.
* Add data up
replace WBAID_ADM2_LOC=WBAID_ADM2_LOC+WBAID_ADM2_LOC4 
replace Disbursementcount_ADM2_LOC=Disbursementcount_ADM2_LOC+Disbursementcount_ADM24
foreach g in AX BX CX EX FX JX LX TX WX YX{
	* Replace missings
	replace WBAID_ADM2_LOC_`g'=0 if WBAID_ADM2_LOC_`g'==.
	replace WBAID_ADM2_LOC_`g'4=0 if WBAID_ADM2_LOC_`g'4 ==.
	replace Disbursementcount_ADM2_`g'4=0 if Disbursementcount_ADM2_`g'4==.
	replace Disbursementcount_ADM2_LOC_`g'=0 if Disbursementcount_ADM2_LOC_`g'==.
	*XXXXXX Melvin 06.01.2018: @Lennart, do we not need to set the disbursement count equal to 0 if missing?
	* XXXX  Lennart 11.01.2018: @Melvin, you are absolutely right. We should also replace the missings for Disbursementocunts
	* Add data up
	replace WBAID_ADM2_LOC_`g'=WBAID_ADM2_LOC_`g'+WBAID_ADM2_LOC_`g'4
	replace Disbursementcount_ADM2_LOC_`g'=Disbursementcount_ADM2_LOC_`g'+Disbursementcount_ADM2_`g'4
	* Clean
	drop Disbursementcount_ADM2_`g'4 WBAID_ADM2_LOC_`g'4
}
drop Disbursementcount_ADM2*4 WBAID_ADM2_LOC*4
drop d_miss_ADM2 count totalcount total
* Labeling
label var WBAID_ADM2_LOC "Value of WB Aid disbursements per ADM2 region(weighted by number of project locations)"
label var Disbursementcount_ADM2_LOC " Number of non-negative aid disbursements per region"

foreach g in AX BX CX EX FX JX LX TX WX YX{
	label var Disbursementcount_ADM2_LOC_`g' " Number of non-negative aid disbursements per region in sector `g'"
	label var WBAID_ADM2_LOC_`g' "Value of WB Aid per ADM2 region in sector `g' (weighted by # of proj. locations)"
}	
	
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2.dta", replace
	
	
* XXXXXXX Lennart 04.01.2018: Generate location weighted aid on ADM1 level by collapsing ADM2 level data
collapse (sum) WBAID_ADM2_LOC* Disbursementcount_ADM2*, by(transaction_year ISO3  ADM0 ADM1 ID_0 ID_1  ID_adm1)
* Rename Variables
renvars WBAID_ADM2_LOC Disbursementcount_ADM2_LOC / WBAID_ADM1_LOC Disbursementcount_ADM1_LOC

foreach g in AX BX CX EX FX JX LX TX WX YX{
renvars WBAID_ADM2_LOC_`g' Disbursementcount_ADM2_LOC_`g' / WBAID_ADM1_LOC_`g' Disbursementcount_ADM1_LOC_`g'
}

* Labeling
	label var WBAID_ADM1_LOC "Value of WB Aid disbursements per ADM1 region(weighted by number of project locations)"
	label var Disbursementcount_ADM1_LOC " Number of non-negative aid disbursements per region"

foreach g in AX BX CX EX FX JX LX TX WX YX{
	label var Disbursementcount_ADM1_LOC_`g' " Number of non-negative aid disbursements per region in sector `g'"
	label var WBAID_ADM1_LOC_`g' "Value of WB Aid per ADM1 region in sector `g' (weighted by # of proj. locations)"
	}	
*XXXXXX Melvin 06.01.2018: Manually checked if the sum of all allocated aid equals the sum of project aid. It does.
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1.dta", replace



	****create balanced dataset without gaps (assumption perfect data on aid flows, that is, if there is no data, then it is not missing but no aid at all, = 0) 
	//ADM2 level
	use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2.dta", clear
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
	replace WBAID_ADM2_LOC = 0 if WBAID_ADM2_LOC ==.
	replace Disbursementcount_ADM2_LOC = 0 if Disbursementcount_ADM2_LOC ==.
	foreach g in AX BX CX EX FX JX LX TX WX YX{
		replace WBAID_ADM2_LOC_`g' = 0 if WBAID_ADM2_LOC_`g' ==.
		replace Disbursementcount_ADM2_LOC_`g' = 0 if Disbursementcount_ADM2_LOC_`g'==.
		}
	drop years_reverse
	order transaction_year ID_adm*
	sort ID_adm* transaction_year
	save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_tsfill.dta", replace
	
	//ADM1 level
	use "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1.dta", clear
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
	replace WBAID_ADM1_LOC = 0 if WBAID_ADM1_LOC ==.
	replace Disbursementcount_ADM1_LOC = 0 if Disbursementcount_ADM1_LOC ==.
	foreach g in AX BX CX EX FX JX LX TX WX YX{
	replace WBAID_ADM1_LOC_`g' = 0 if WBAID_ADM1_LOC_`g' ==.
	replace Disbursementcount_ADM1_LOC_`g' = 0 if Disbursementcount_ADM1_LOC_`g'==.
	}
	
	drop years_reverse
	order transaction_year ID_adm*
	sort ID_adm* transaction_year
	save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM1_tsfill.dta", replace


**********************************************************************	
	* XXXXXX Lennart 10.01.2018 - Prepare population weighted data
*************************************************************************
use "$data\Aid\2017_11_14_WB\IDA_disbursement.dta", replace

	* Merge with Population data
renvars transaction_year ID_adm2 / year rid2
merge m:1 rid2 year using "$data\ADM\1_1_1_R_pop_GADM2.dta", nogen keep(1 3)
renvars year rid2 isum_pop / transaction_year ID_adm2 isum_pop_ADM2
/*
 XXXXX Lennart 10.01.2018 Generate Population on ADM1 level to allocated aid, which was coded with precision 4 based on the approach written down above:
 Pop weighted
- Each of the 3 ADM2 regions coded with precision 1-3 gets Pop(i)/(Sum Pop)*4/5*X 
- The ADM1 region coded with precision 4 gets Pop(i)/(Sum Pop)*4/5*X and this is then distributed equally among the corresponding ADM2 regions
*/

/*  XXXXX Lennart 11.01.2018: One issue is here that we still face regions, which do not have population data. This leads to a loss of 1480 Mio USD, if we do not take care of it and is described in the following 4 lines:
bysort transaction_year project_id: egen total_proj_pop=total(isum_pop_ADM2)
duplicates drop project_id transaction_year, force
egen lost_aid=total(transaction_value_tot) if total_proj_pop==0
XXXXX Lennart 11.01.2018: My suggestion would be to set the population to 1 in order to not loose those observations, which is done subsequently. @ Melvin & Kai: Do you have other suggestions? 
*/
* XXXXXX Lennart 11.01.2018: Replace missing population data in order to distribute aid also to regions, which do not have population counts. 
* XXXXXX Lennart 11.01.2018:@ Melvin & Kai: Here we do it both for the projects with and without pop-data. We could also do it just for the projects without any population data.
replace isum_pop_ADM2=1 if isum_pop_ADM2==. | isum_pop_ADM2==0
* Gen Population on ADM1 level
bysort transaction_year ID_adm1: egen isum_pop_ADM1=total(isum_pop_ADM2)

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
collapse (sum) transaction_value_pop* Disbursementcount*, by(transaction_year ISO3  ADM0 ADM1 ADM2 ID_0 ID_1 ID_2 ID_adm1 ID_adm2)

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

collapse (sum) transaction_value_pop* Disbursementcount*, by(transaction_year ISO3 ID_0 ID_1 ADM0 ADM1 ID_adm1)

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
replace Disbursementcount_ADM2_POP4=0 if Disbursementcount_ADM2_POP4==.
* Add data up
replace WBAID_ADM2_POP=WBAID_ADM2_POP+WBAID_ADM2_POP4 
replace Disbursementcount_ADM2_POP=Disbursementcount_ADM2_POP+Disbursementcount_ADM2_POP4
foreach g in AX BX CX EX FX JX LX TX WX YX{
	* Replace missings
	replace WBAID_ADM2_POP_`g'=0 if WBAID_ADM2_POP_`g'==.
	replace WBAID_ADM2_POP_`g'4=0 if WBAID_ADM2_POP_`g'4 ==.	
	* Add data up
	replace WBAID_ADM2_POP_`g'=WBAID_ADM2_POP_`g'+WBAID_ADM2_POP_`g'4
	replace Disbursementcount_ADM2_POP_`g'=Disbursementcount_ADM2_POP_`g'+Disbursementcount_ADM2_POP_`g'4
	* Clean
	drop Disbursementcount_ADM2_POP_`g'4 WBAID_ADM2_POP_`g'4
}
drop Disbursementcount_ADM2*4 WBAID_ADM2_POP*4
drop d_miss_ADM2 count
* Labeling
label var WBAID_ADM2_POP "Value of WB Aid disbursements per ADM2 region(weighted by population of project locations)"
label var Disbursementcount_ADM2_POP " Number of non-negative aid disbursements per region"

foreach g in AX BX CX EX FX JX LX TX WX YX{
	label var Disbursementcount_ADM2_POP_`g' "Number of non-negative aid disbursements per region in sector `g'"
	label var WBAID_ADM2_POP_`g' "Value of WB Aid per ADM2 region in sector `g' (weighted by pop of locations)"
}	
	
save "$data\Aid\2017_11_14_WB\IDA_disbursement_ADM2_POP.dta", replace
	
	
* XXXXXXX Lennart 11.01.2018: Generate population weighted aid on ADM1 level by collapsing ADM2 level data
collapse (sum) WBAID_ADM2_POP* Disbursementcount_ADM2*, by(transaction_year ISO3  ADM0 ADM1 ID_0 ID_1  ID_adm1)
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
