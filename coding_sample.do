cd "/Users/yangyiyun/Desktop"
 
***************************************
*******create the panel dataset********
***************************************

*** Create the independent variable: Climate Finance (Source: AidData)*****  

import delimited "/Users/yangyiyun/Desktop/MPP/24fall/Thesis/Data Workshop/Financing_the_2030_Agenda_for_Sustainable_Development_Dataset_Version_1_0 3/Aggregates_Financing_the_2030_Agenda_for_Sustainable_Development_Dataset_Version_1_0.csv", clear  ///Please download the data with the link in the readme file

keep year donor_name recipient_name sdg_7_sum sdg_13_sum  /// Keep only relevant variables from the dataset  

gen sum = sdg_7_sum + sdg_13_sum  /// Create a new variable for total climate finance, measured as the sum of investments in SDG 7 (affordable and clean energy) and SDG 13 (climate action)  

collapse (sum) sum, by(recipient_name year)  /// Aggregate total funding by recipient country and year  

rename recipient_name country  
rename sum funding  /// Rename variables for clarity  

drop if strpos(country, "regional") > 0  
drop if country == "Bilateral, unspecified"  /// Remove observations where funding is allocated to unspecified or regional recipients  

save invest.dta  /// Save the dataset for future use, preserving the independent variable  

 
***Create dependent variable and control variable (source: World Bank)***

ssc install wbopendata  /// Install the wbopendata package to access World Bank data  

wbopendata, indicator(EN.GHG.ALL.LU.MT.CE.AR5; EN.GHG.ALL.MT.CE.AR5; NY.GDP.PCAP.PP.CD; EG.EGY.PRIM.PP.KD; EG.ELC.ACCS.ZS; NY.GDP.PCAP.CD; SP.POP.TOTL) clear long  /// Retrieve selected indicators from the World Bank and convert them into long-format data  

keep if year >= 2010 & year <= 2021  /// Retain data from 2010 to 2021 based on the availability of the independent variable  

rename en_ghg_all_lu_mt_ce  ghg_emi_lu
rename en_ghg_all_mt_ce ghg_emi_exlu
rename ny_gdp_pcap_pp_cd  gdp
rename ny_gdp_pcap_cd gdp_per
rename eg_egy_prim_pp_kd  energy_intensity
rename eg_elc_accs_zs elctricity_access
rename sp_pop_totl population 
///Rename the countrol variables
keep countryname year ghg_emi_lu ghg_emi_exlu gdp gdp_per energy_intensity elctricity_access population
rename countryname country
   
  **Rename countries to align country names across both datasets in preparation for merging**
replace country = "Democratic Republic of the Congo" if country == "Congo, Dem. Rep."
replace country = "Congo" if country == "Congo, Rep."
replace country = "Egypt" if country == "Egypt, Arab Rep"
replace country = "Gambia" if country == "The Gambia"
replace country = "Kyrgyzstan" if country == "Kyrgyz Republic"
replace country = "Venezuela" if country == "Venezuela, RB"
replace country = "Yemen" if country == "Yemen, Rep"
replace country = "China (People's Republic of)" if country == "China"
replace country = "Democratic People's Republic of Korea" if country == "Korea, Dem People's Rep"
replace country = "Iran" if country == "Iran, Islamic Rep"
replace country = "Lao People's Democratic Republic" if country == "Lao PDR"
replace country = "Saint Kitts and Nevis" if country == "St Kitts and Nevis"
replace country = "Saint Lucia" if country == "St Lucia"
replace country = "Saint Vincent and the Grenadines" if country == "St Vincent and the Grenadines"
replace country = "Turkiye" if country == "Turkey"
replace country = "Viet Nam" if country == "Vietnam"
replace country = "West Bank and Gaza Strip" if country == "West Bank and Gaza"

save wbdata.dta, replace
//save the dataset including independent variable and control variables(exluding corruption index)

***creating control variables (corruption) (source: TransparencyInternational)*****
import excel "/Users/yangyiyun/Desktop/MPP/24fall/Thesis/Data Workshop/corruption.xlsx", firstrow clear /// Please download the data with the link in the readme file
rename CPIScore2013 CPIscore2013
rename CPIScore2012 CPIscore2012
reshape long CPIscore, i(Country) j(year) 
rename Country country
rename CPIscore corrup
  
  **rename countries to corordinate the country name from the two data sets preparing to merge the data**
replace country = "Democratic Republic of the Congo" if country == "Congo, Dem. Rep."
replace country = "China (People's Republic of)" if country == "China"
replace country = "Democratic People's Republic of Korea" if country == "Korea, North"
replace country = "Lao People's Democratic Republic" if country == "Laos"
replace country = "Turkiye" if country == "Turkey"
replace country = "Viet Nam" if country == "Vietnam"
save corrup.dta, replace
//save the corruption perception index as a control variable

*** Merging datasets and preparing for regression analysis ***  

*** Merge investment data with World Bank data ***  
use invest.dta, clear  
merge 1:1 country year using wbdata.dta  
drop if _merge == 1  /// Drop observations that exist only in invest.dta  
drop if _merge == 2  /// Drop observations that exist only in wbdata.dta  
drop _merge  
save data_1.dta, replace  

*** Merge the combined dataset with corruption data ***  
use data_1.dta, clear  
merge 1:1 country year using corrup.dta  
replace corrup = . if _merge == 1 | _merge == 2  /// Set corruption variable to missing for unmatched observations  
drop if _merge == 2  /// Remove observations that exist only in corrup.dta  

*** Checking for missing values and reordering variables ***  
list country if missing(ghg_emi_lu)  /// The following countries have missing greenhouse gas emissions data: Egypt, Iraq, Kiribati, Kosovo, Libya, Maldives, Marshall Islands, Montenegro, Nauru, Serbia, Sierra Leone, South Sudan, West Bank and Gaza Strip  

drop if country == "Egypt" | country == "Iraq" | country == "Kiribati" | country == "Kosovo" | country == "Libya" | country == "Maldives" | country == "Marshall Islands" | country == "Montenegro" | country == "Nauru" | country == "Serbia" | country == "Sierra Leone" | country == "South Sudan" | country == "West Bank and Gaza Strip"  /// Drop countries with missing emissions data across the entire period  

save data_2.dta, replace  

*** Data transformation and variable reordering ***  
gen funding_m = funding / 1000000  
order funding_m, after(funding)  
order funding, after(corrup)  
order gdp_per, after(gdp)  

*** Checking missing values in corruption data ***  
list country year if missing(corrup)  /// Some countries have missing corruption data for several years, while others are missing data for the entire period. Countries with full-period missing values: Antigua and Barbuda, Belize, Fiji, Guinea-Bissau, Samoa, Syrian Arab Republic, Tonga, Tuvalu  

drop if country == "Barbados" | country == "Croatia" | country == "Oman" | country == "Saint Kitts and Nevis" | country == "Trinidad and Tobago"  /// Drop selected countries with substantial missing corruption data  
drop _merge
save dataset.dta  /// Final dataset ready for regression analysis  


***************************************
***county-year fixed effect analysis***
***************************************

***set the country-year panel***
use dataset.dta 
encode country, gen(country_id)
xtset country_id year

***creat the interaction term***
gen corrup_b = (missing(corrup) | corrup < 50)
gen corrup_a = (corrup > 50)

***generate regression result and export them into a word document***
ssc install outreg2  /// Install outreg2 to export regression results

/// OLS estimation with only the main independent variable (climate finance)
reg ghg_emi_exlu funding_m, robust  
outreg2 using results.doc, replace word label  

/// OLS estimation with additional control variables: GDP per capita, energy intensity, electricity access, and population
reg ghg_emi_exlu funding_m gdp_per energy_intensity elctricity_access population, robust  
outreg2 using results.doc, append word label  

/// OLS estimation with control variables and interaction terms between corruption indicators and climate finance
reg ghg_emi_exlu funding_m gdp_per energy_intensity elctricity_access population corrup_a#c.funding_m corrup_b#c.funding_m, robust  
outreg2 using results.doc, append word label  

/// Fixed Effects (FE) model without year effects
xtreg ghg_emi_exlu funding_m gdp_per energy_intensity elctricity_access population corrup_a#c.funding_m corrup_b#c.funding_m, fe  
outreg2 using results.doc, append word label  

/// OLS estimation with year fixed effects but without country fixed effects
reg ghg_emi_exlu funding_m gdp_per energy_intensity elctricity_access population corrup_a#c.funding_m corrup_b#c.funding_m i.year, robust 
outreg2 using results.doc, append word label  

/// FE model excluding corruption interaction terms but including year fixed effects
xtreg ghg_emi_exlu funding_m gdp_per energy_intensity elctricity_access population i.year, fe
outreg2 using results.doc, append word label  

/// Finalized FE model with year fixed effects and corruption interaction terms
xtreg ghg_emi_exlu funding_m gdp_per energy_intensity elctricity_access population corrup_a#c.funding_m corrup_b#c.funding_m i.year, fe  
outreg2 using results.doc, append word label  
