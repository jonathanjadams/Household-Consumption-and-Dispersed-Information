******************************************************************************************
* replication code for the empirical analysis in Household Consumption and Dispersed Information (Adams and Rojas 2024 JME)
* sce analysis.do: cleans SCE data, runs regressions, creates tables
******************************************************************************************


clear all

*set CD to the replication repository:
// cd "[insert here]"


// IMPORT SCE DATA

//FIRST: COMBINE CSV FILES OF MICRODATA
//(in the future, you may need to rename latest csv's from Fed's website, as they sometimes change naming schemes)

import delimited "data\FRBNY-SCE-Public-Microdata-Complete-13-16.csv", clear 
save "data\sce_public_microdata_combined.dta", replace

import delimited "data\FRBNY-SCE-Public-Microdata-Complete-17-19.csv", clear 
 append using "data\sce_public_microdata_combined.dta"
 save "data\sce_public_microdata_combined.dta", replace

 import delimited "data\frbny-sce-public-microdata-complete-20-present.csv", clear 
 append using "data\sce_public_microdata_combined.dta"
 save "data\sce_public_microdata_combined.dta", replace




//SECOND: IMPORT LABOR MODULE
import excel "data\sce-labor-microdata-public.xlsx", sheet("Data") cellrange(A2:DN26131) firstrow clear

bysort userid: egen count = count(userid)
gen year = floor(date/100)



gen month = date - year*100
gen day = 1
gen time = mdy(month,day,year)
drop month day
gen month = mofd(time)
format month %tm
order month
drop time

xtset userid month

// l3 is your current salary, while oo2e2 is expected salary 4mo from now
gen sal = l3
replace sal = 0 if sal ==.
gen esal = oo2e2
gen dsal = sal - l4.sal

bysort month: egen sal_agg = mean(sal)
gen sal_idio = sal-sal_agg

//create industry controls:
gen industry = lmind
replace industry = 20 if industry ==. & lmtype==1 //gov workers
replace industry = l12b if industry==. // unemployed: last industry
replace industry = 20 if industry ==. & l12==1 //unemployed: gov workers
replace industry = 0 if industry ==. //industry unknown


keep date userid esal sal industry

merge 1:1 date userid using "data\sce_public_microdata_combined.dta", nogen
// this dataset has stitched together all the SCE microdata files
// which are the NYFED provides separately for different time periods

gen year = floor(date/100)
gen month = date - year*100
gen day = 1
gen time = mdy(month,day,year)
drop month day
gen month = mofd(time)
format month %tm
gen quarter = qofd(time)
format quarter %tq
order month
drop time

 
xtset userid month

*generate fips code
statastates, abbreviation(_state)
drop _merge
gen geofips = state_fips*1000 //BEA, why??

*introduce state-level BEA earnings data
merge m:1 quarter geofips using "data\BEA_state_quarterly_earnings.dta", nogen

gen age = q32
encode _state, gen(state)
encode _age_cat, gen(age_cat)
encode _edu_cat, gen(edu_cat)

*demographics are only recorded for user's first observation
sort userid month
by userid: egen sex = min(q33)
replace sex = 0 if sex ==2 // now 0 is men and 1 is women
by userid: egen hispanic = min(q34)
replace hispanic = 0 if hispanic ==2 // now 0 is not hispanic and 1 is hispanic
by userid: egen white = min(q35_1)
by userid: egen black = min(q35_2)
by userid: egen amindian = min(q35_3)
by userid: egen asian = min(q35_4)
by userid: egen pacisland = min(q35_5)

drop if state==. 
drop if state_fips == .



*generating state-period identifiers
egen clusterid = group(state month) //treatment varies by state-month

//linear specification
bysort month state: egen sal_state = mean(sal)
gen sal_idio = sal-sal_state
//log specification
gen lsal = log(sal)
gen lsal_state = log(sal_state) //note: you want log of mean, not mean of logs
gen lsal_idio = log(sal)-lsal_state
gen lesal = log(esal)
reg lesal lsal_idio lsal_state

//log with BEA state-level earnings data:
gen lbea_state = log(earn_pcd)
gen lbea_idio = lsal - lbea_state
//This one uses national BEA earnings:
gen lbeaus_aggr = log(earn_pcd_us)
gen lbeaus_idio = lsal - lbeaus_aggr

xtset userid month

//create detrended variables (for the variables I'm still using in 9-2023)
//our trends are quarterly, need to make monthly observations:
reg ly_pop_us_trendq month
predict ly_pop_us_trendm
local monthlygrowth = _b[month]



local trends trendq2 us_trendq2
foreach ttt in `trends' {
gen lesal_`ttt' = lesal - f1q_ly_pop_`ttt'
la var lesal_`ttt' "Log Forecast"
gen l4_lesal_`ttt' = l4.lesal_`ttt'
la var l4_lesal_`ttt' "Lag Forecast"


gen lbea_state_`ttt' = lbea_state - ly_pop_`ttt'
la var lbea_state_`ttt' "Aggr. Log Earnings"
gen l4_lbea_state_`ttt' = l4.lbea_state_`ttt'
la var l4_lbea_state_`ttt' "Lag Aggr. Earnings"

gen lbeaus_aggr_`ttt' = lbeaus_aggr - ly_pop_`ttt'
la var lbeaus_aggr_`ttt' "Aggr. Log Earnings"
gen l4_lbeaus_aggr_`ttt' = l4.lbeaus_aggr_`ttt'
la var l4_lbeaus_aggr_`ttt' "Lag Aggr. Earnings"

gen lsal_`ttt' = lsal - ly_pop_`ttt'
la var lsal_`ttt' "Log Earnings"
gen l4_lsal_`ttt' = l4.lsal_`ttt'
la var l4_lsal_`ttt' "Lag Log Earnings"
}



gen l4_sal = l4.sal
gen l4_sal_idio=l4.sal_idio
gen l4_sal_state=l4.sal_state
gen l4_lsal = l4.lsal
gen l4_lsal_idio=l4.lsal_idio
gen l4_lsal_state=l4.lsal_state
gen l4_lbea_idio=l4.lbea_idio
gen l4_lbea_state=l4.lbea_state
gen l4_lbeaus_idio=l4.lbeaus_idio
gen l4_lbeaus_aggr=l4.lbeaus_aggr
gen l4_lesal = l4.lesal



la var sal_idio "Idiosyncratic Earnings"
la var sal_state "Aggregate Earnings"
la var lsal_idio "Idio. Log Earnings"
la var lsal_state  "Aggr. Log Earnings"
la var lbea_idio "Idio. Log Earnings"
la var lbea_state  "Aggr. Log Earnings"
la var lbeaus_idio "Idio. Log Earnings"
la var lbeaus_aggr  "Aggr. Log Earnings"
la var l4_sal "Lag Earnings"
la var l4_sal_idio "Lag Idio. Earnings"
la var l4_sal_state "Lag Aggr. Earnings"
la var l4_lsal "Lag Log Earnings"
la var l4_lsal_idio "Lag Idio. Log Earnings"
la var l4_lsal_state  "Lag Aggr. Log Earnings"
la var l4_lbea_idio "Lag Idio. Log Earnings"
la var l4_lbea_state  "Lag Aggr. Log Earnings"
la var l4_lbeaus_idio "Lag Idio. Log Earnings"
la var l4_lbeaus_aggr  "Lag Aggr. Log Earnings"
la var l4_lesal "Lag Forecast"
la var esal "Linear" //"Expected Income"
la var lesal "Log"	//"Expected Income"

save "data\sce_labor_panel.dta", replace




use "data\sce_labor_panel.dta", clear

// create percentiles
egen l4_sal_ptciles = xtile(l4_sal) if l4_sal>0, by(date) nq(100)
replace l4_sal_ptciles = 0 if l4_sal==0
la var l4_sal_ptciles "Lag Percentile"


gen ferror = .

scalar psi = (.87/.97)^(1/3) //the frequency is 4-monthly, not annual

est clear
local interactionswitch interact_no interact_yes 
local specification bea ferror 

	
foreach interswi in `interactionswitch'{
foreach speci in `specification'{
	if "`speci'" == "ferror"{
	di "forecast errors"
	local idio_var lbea_idio
	local state_var lbea_state_trendq2
	local lag_idio_var l4_lbea_idio
	local lag_state_var l4_lbea_state_trendq2
	local lag_sal_var l4_lsal_trendq2
	replace ferror = lesal_trendq2 - f4.lsal_trendq2
	local expectation_var ferror
	local lag_expectation_var l4_lesal_trendq2
	local filename testsferror	
}


if "`speci'" == "bea"{
	di "bea state earnings"
	local idio_var lbea_idio
	local state_var lbea_state_trendq2
	local lag_idio_var l4_lbea_idio
	local lag_state_var l4_lbea_state_trendq2
	local lag_sal_var l4_lsal_trendq2
	local expectation_var lesal_trendq2
	local lag_expectation_var l4_lesal_trendq2
	local filename testsbea	
}


local idio_var_us lbeaus_idio
local state_var_us lbeaus_aggr_trendq2

if "`interswi'" === "interact_no"{
di "no interactions"
local interactions
local filename `filename'
}

if "`interswi'" === "interact_yes"{
di "include interactions" //note that we include the level when including interaction:
local intervar l4_sal_ptciles 
local interactions_only c.`idio_var'#c.`intervar' c.`state_var'#c.`intervar'
local interactions  `interactions_only' `intervar' 
local interaction_diff -c.`idio_var'#c.`intervar' +c.`state_var'#c.`intervar'
local interactions_only_us c.`idio_var_us'#c.`intervar' c.`state_var_us'#c.`intervar'
local interactions_us  `interactions_only_us' `intervar'
local interaction_diff_us -c.`idio_var_us'#c.`intervar' +c.`state_var_us'#c.`intervar' 
local interaction_rename_us c.`idio_var_us'#c.`intervar' c.`idio_var'#c.`intervar'  c.`state_var_us'#c.`intervar' c.`state_var'#c.`intervar'
local filename `filename'_interact
}


local demographics sex hispanic white black amindian asian pacisland


eststo clear
eststo nocontrols: reg `expectation_var' `idio_var' `state_var' `interactions', vce(cluster clusterid)
test `idio_var' = `state_var'
estadd scalar p_diff = r(p)
local sign_wgt = sign(_b[`idio_var']-_b[`state_var'])
estadd scalar p_oneside = 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
display "Ha: b_idio>b_aggr p-value = " 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
test psi*`idio_var' = `state_var'
estadd scalar p_psi = r(p)  
estadd local statefes ""
estadd local industryfes ""
estadd local hucapfes ""
estadd local demofes ""
estadd local userfes ""
estadd local aggrlevel "State"
estadd local trendlevel "State"
estadd local regtype "OLS"
estadd scalar r2_annoying e(r2)
if "`interswi'" === "interact_yes"{
lincom `interaction_diff'
estadd scalar diff_inter_est = r(estimate)
estadd scalar diff_inter_se = r(se) 
test 0 = `interaction_diff'
estadd scalar diff_inter_p = r(p) 
}



eststo fes_state: reg `expectation_var' `idio_var' `state_var' `interactions' i.state, vce(cluster clusterid)
test `idio_var' = `state_var'
estadd scalar p_diff = r(p)
local sign_wgt = sign(_b[`idio_var']-_b[`state_var'])
estadd scalar p_oneside = 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
display "Ha: b_idio>b_aggr p-value = " 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
test psi*`idio_var' = `state_var'
estadd scalar p_psi = r(p)  
estadd local statefes "X"
estadd local industryfes ""
estadd local hucapfes ""
estadd local demofes ""
estadd local userfes ""
estadd local aggrlevel "State"
estadd local trendlevel "State"
estadd local regtype "OLS"
estadd scalar r2_annoying e(r2)
if "`interswi'" === "interact_yes"{
lincom `interaction_diff'
estadd scalar diff_inter_est = r(estimate)
estadd scalar diff_inter_se = r(se) 
test 0 = `interaction_diff'
estadd scalar diff_inter_p = r(p) 
}


eststo fes_all: reg `expectation_var' `idio_var'  `state_var' `interactions' i.state i.industry i.edu_cat i.age_cat `demographics', vce(cluster clusterid)
test `idio_var' = `state_var'
estadd scalar p_diff = r(p)
local sign_wgt = sign(_b[`idio_var']-_b[`state_var'])
estadd scalar p_oneside = 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
display "Ha: b_idio>b_aggr p-value = " 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
test psi*`idio_var' = `state_var'
estadd scalar p_psi = r(p)  
estadd local statefes "X"
estadd local industryfes "X"
estadd local hucapfes "X"
estadd local demofes "X"
estadd local userfes ""
estadd local aggrlevel "State"
estadd local trendlevel "State"
estadd local regtype "OLS"
estadd scalar r2_annoying e(r2)
if "`interswi'" === "interact_yes"{
lincom `interaction_diff'
estadd scalar diff_inter_est = r(estimate)
estadd scalar diff_inter_se = r(se) 
test 0 = `interaction_diff'
estadd scalar diff_inter_p = r(p) 
}

eststo lags_separate: reg `expectation_var' `idio_var'  `state_var' `interactions' `lag_idio_var'  `lag_state_var' i.state i.industry i.edu_cat i.age_cat `demographics', vce(cluster clusterid)
test `idio_var' = `state_var'
estadd scalar p_diff = r(p)
local sign_wgt = sign(_b[`idio_var']-_b[`state_var'])
estadd scalar p_oneside = 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
display "Ha: b_idio>b_aggr p-value = " 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
test psi*`idio_var' = `state_var'
estadd scalar p_psi = r(p)  
estadd local statefes "X"
estadd local industryfes "X"
estadd local hucapfes "X"
estadd local demofes "X"
estadd local userfes ""
estadd local aggrlevel "State"
estadd local trendlevel "State"
estadd local regtype "OLS"
estadd scalar r2_annoying e(r2)
if "`interswi'" === "interact_yes"{
lincom `interaction_diff'
estadd scalar diff_inter_est = r(estimate)
estadd scalar diff_inter_se = r(se) 
test 0 = `interaction_diff'
estadd scalar diff_inter_p = r(p) 
}


eststo lags_combined: reg `expectation_var' `idio_var'  `state_var' `interactions' `lag_sal_var' i.state i.industry i.edu_cat i.age_cat `demographics', vce(cluster clusterid)
test `idio_var' = `state_var'
estadd scalar p_diff = r(p)
local sign_wgt = sign(_b[`idio_var']-_b[`state_var'])
estadd scalar p_oneside = 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
display "Ha: b_idio>b_aggr p-value = " 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
test psi*`idio_var' = `state_var'
estadd scalar p_psi = r(p) 
estadd local statefes "X"
estadd local industryfes "X"
estadd local hucapfes "X"
estadd local demofes "X"
estadd local userfes ""
estadd local aggrlevel "State"
estadd local trendlevel "State"
estadd local regtype "OLS"
estadd scalar r2_annoying e(r2)
if "`interswi'" === "interact_yes"{
lincom `interaction_diff'
estadd scalar diff_inter_est = r(estimate)
estadd scalar diff_inter_se = r(se) 
test 0 = `interaction_diff'
estadd scalar diff_inter_p = r(p) 
}

eststo lags_com_fcast: reg `expectation_var' `idio_var'  `state_var' `interactions' `lag_sal_var' `lag_expectation_var'  i.state i.industry i.edu_cat i.age_cat `demographics', vce(cluster clusterid)
test `idio_var' = `state_var'
estadd scalar p_diff = r(p)
local sign_wgt = sign(_b[`idio_var']-_b[`state_var'])
estadd scalar p_oneside = 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
display "Ha: b_idio>b_aggr p-value = " 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
test psi*`idio_var' = `state_var'
estadd scalar p_psi = r(p)  
estadd local statefes "X"
estadd local industryfes "X"
estadd local hucapfes "X"
estadd local demofes "X"
estadd local userfes ""
estadd local aggrlevel "State"
estadd local trendlevel "State"
estadd local regtype "OLS"
estadd scalar r2_annoying e(r2)
if "`interswi'" === "interact_yes"{
lincom `interaction_diff'
estadd scalar diff_inter_est = r(estimate)
estadd scalar diff_inter_se = r(se) 
test 0 = `interaction_diff'
estadd scalar diff_inter_p = r(p) 
}



*This specification includes fixed effects, but uses nation-wide BEA income as the aggregate
eststo us_aggregate: reg `expectation_var' lbeaus_idio  lbeaus_aggr_trendq2 `interactions_us' `lag_sal_var'  i.state i.industry i.edu_cat i.age_cat `demographics', vce(cluster clusterid)
test lbeaus_idio = lbeaus_aggr_trendq2
estadd scalar p_diff = r(p)
local sign_wgt = sign(_b[lbeaus_idio]-_b[lbeaus_aggr_trendq2])
estadd scalar p_oneside = 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
display "Ha: b_idio>b_aggr p-value = " 1-ttail(r(df_r),`sign_wgt'*sqrt(r(F)))
test psi*lbeaus_idio = lbeaus_aggr_trendq2
estadd scalar p_psi = r(p)  
estadd local statefes "X"
estadd local industryfes "X"
estadd local hucapfes "X"
estadd local demofes "X"
estadd local userfes ""
estadd local aggrlevel "USA"
estadd local trendlevel "State"
estadd local regtype "OLS"
estadd scalar r2_annoying e(r2)
if "`interswi'" === "interact_yes"{
lincom `interaction_diff_us'
estadd scalar diff_inter_est = r(estimate)
estadd scalar diff_inter_se = r(se) 
test 0 = `interaction_diff_us'
estadd scalar diff_inter_p = r(p) 
}

*This specification does IV with the idiosyncratic income
eststo iv_fesall: ivregress 2sls `expectation_var'  `state_var' `interactions' i.state i.industry i.edu_cat i.age_cat `demographics' (`idio_var' = `lag_idio_var'), vce(cluster clusterid)
test `idio_var' = `state_var'
estadd scalar p_diff = r(p)
 // I couldn't get the usual test statistic to work with IV, so if the sign is right (it is), it's just r(p)/2 but in principle you want to check the sign
estadd scalar p_oneside = r(p)/2
estadd local statefes "X"
estadd local industryfes "X"
estadd local hucapfes "X"
estadd local demofes "X"
estadd local userfes ""
estadd local aggrlevel "State"
estadd local trendlevel "State"
estadd local regtype "IV"
estadd scalar r2_annoying e(r2)
if "`interswi'" === "interact_yes"{
lincom `interaction_diff'
estadd scalar diff_inter_est = r(estimate)
estadd scalar diff_inter_se = r(se) 
test 0 = `interaction_diff'
estadd scalar diff_inter_p = r(p) 
}



 *baseline regression table:
 if "`interswi'" === "interact_no"{ 
   
  estout nocontrols fes_state fes_all lags_combined lags_com_fcast lags_separate us_aggregate iv_fesall using "tables\baseline`filename'.tex" , /*
 */ cells(b(fmt(a3)) se(fmt(a3) par)) /*
 */ stats(p_oneside N r2_annoying statefes hucapfes aggrlevel regtype, fmt(3 %18.0g 3 a3 a3 a3 a3 a3 a3) /*
 */labels(`"$ H_{0}$: $\beta^{Idio}\geq\beta^{Aggr}$ p-value"'  `"Observations"' `"\(R^{2}\)"' `"State F.E."' `"Household Controls"' `"Aggregation Level"' `"Regression Type"')) /*
 */ varwidth(20) modelwidth(12) delimiter(&) end(\\) prehead(`"\begin{tabular}{l*{@E}{c}}"' `"\hline\hline \\"') posthead("\\ \hline \\") /* 
 */ prefoot("\\ \hline \\")  postfoot(`"\hline\hline"' `"\multicolumn{@span}{p{1.1\textwidth}}{\vspace*{-0.5em}\singlespace  \small \textit{Notes:} Standard errors in parentheses, clustered at the state-month level. In all cases, the dependent variable is the household-level log forecast of its 4-month-ahead annualized earnings. The reported p-value is from a one-sided test with  $ H_{A}$: $\beta^{Idio}<\beta^{Aggr}$. In the IV regression, idiosyncratic income is instrumented for by its one period lag. }\\"' `"\end{tabular}"') /* 
 */ label varlabels(_cons Constant, end("" [1em]) nolast) mlabels(none) numbers(\multicolumn{@span}{c}{( )}) /* 
 */ collabels(none)  eqlabels(, begin("\hline" "") nofirst) interaction(" $\times$ ") notype level(95) style(esttab) /* 
 */ replace keep(`idio_var' `state_var' `lag_sal_var' `lag_expectation_var' `lag_idio_var' `lag_state_var' ) rename(lbeaus_idio `idio_var' lbeaus_aggr_trendq2 `state_var' ) 
  }
 
 
 *interactions table:
 if "`interswi'" === "interact_yes"{ 
 	if "`speci'" === "bea"{
		estout nocontrols fes_state fes_all lags_combined lags_com_fcast lags_separate us_aggregate using "tables\baseline`filename'_intertable.tex" , /*
		 */ cells(b(fmt(a3)) se(fmt(a3) par)) /*
		 */ stats(diff_inter_est diff_inter_p N r2_annoying statefes hucapfes aggrlevel, fmt(3 3 %18.0g 3 a3 a3 a3 a3 a3 a3) /*
		 */labels(`"$\gamma^{Aggr}-\gamma^{Idio}$ estimate"' `"$\gamma^{Aggr}=\gamma^{Idio}$ p-value"' `"Observations"' `"\(R^{2}\)"' `"State F.E."' `"Household Controls"' `"Aggregation Level"')) /*
		 */ varwidth(20) modelwidth(12) delimiter(&) end(\\) prehead(`"\begin{tabular}{l*{@E}{c}}"' `"\hline\hline \\"') posthead("\\ \hline \\") /* 
		 */ prefoot("\\ \hline \\")  postfoot(`"\hline\hline"' `"\multicolumn{@span}{p{1.3\textwidth}}{\vspace*{-0.5em}\singlespace  \small \textit{Notes:} Standard errors in parentheses, clustered at the state-month level. In all cases, the dependent variable is the household-level log forecast of its 4-month-ahead annualized earnings.}\\"' `"\end{tabular}"') /* 
		 */ label varlabels(_cons Constant, end("" [1em]) nolast) mlabels(none) numbers(\multicolumn{@span}{c}{( )}) /* 
		 */ collabels(none)  eqlabels(, begin("\hline" "") nofirst) substitute(_ \_ "\_cons " \_cons) interaction(" $\times$ ") notype level(95) style(esttab) /*
		 */ replace keep(`idio_var' `state_var'  `lag_expectation_var' `lag_idio_var' `lag_state_var'  `interactions_only' )  rename(`idio_var_us' `idio_var' `state_var_us' `state_var' `interaction_rename_us') 
	}
 }

 
 
 }
 }

 

//EARNINGS AND INFLATION CO-FORECASTABILITY
//i.e. forecast accuracy of more/less-informed forecasters 

//use the cleaned SCE dataset
use "data\sce_labor_panel.dta", replace

//import CPI data 
merge m:1 month using "data\cpi_u_m.dta"
  
  gen f_inflation = (f12_cpi/cpi-1)*100
  gen e_inflation = q8v2part2
  
  xtset userid month

  gen ferror_inf = f_inflation-e_inflation

  gen ferror_y = f4.lsal-lesal
  
gen ferror_inf_abs = abs(ferror_inf)
  la var ferror_inf_abs "Absolute Inflation Error"
gen ferror_y_abs = abs(ferror_y)
  la var ferror_y_abs "Absolute Log Earnings Error"

  
gen l1_ferror_inf_abs = l1.ferror_inf_abs
  la var l1_ferror_inf_abs "1 Month Lag"
gen l2_ferror_inf_abs = l2.ferror_inf_abs
  la var l2_ferror_inf_abs "2 Month Lags"

  
  
local demographics sex hispanic white black amindian asian pacisland
local battery i.state i.industry i.edu_cat i.age_cat `demographics'

est clear

eststo ferror_y_inf_l0: reg ferror_y_abs ferror_inf_abs, vce(cluster clusterid)
estadd scalar r2_annoying e(r2)

eststo ferror_y_inf_l1: reg ferror_y_abs ferror_inf_abs l1_ferror_inf_abs, vce(cluster clusterid)
estadd scalar r2_annoying e(r2)

eststo ferror_y_inf_l2: reg ferror_y_abs ferror_inf_abs l1_ferror_inf_abs l2_ferror_inf_abs, vce(cluster clusterid)
estadd scalar r2_annoying e(r2)


eststo ferror_y_inf_l2_fes: reg ferror_y_abs ferror_inf_abs l1_ferror_inf_abs l2_ferror_inf_abs i.state, vce(cluster clusterid)
estadd local statefes "X"
estadd scalar r2_annoying e(r2)

eststo ferror_y_inf_l2_feall: reg ferror_y_abs ferror_inf_abs l1_ferror_inf_abs l2_ferror_inf_abs `battery', vce(cluster clusterid)
estadd local statefes "X"
estadd local hhfes "X"
estadd scalar r2_annoying e(r2)


local ferrortableregs ferror_y_inf_l0 ferror_y_inf_l1 ferror_y_inf_l2 ferror_y_inf_l2_fes ferror_y_inf_l2_feall  

local keepvars ferror_inf_abs l1_ferror_inf_abs l2_ferror_inf_abs 

 estout `ferrortableregs' using "tables\ferror_abs_tests.tex" , /*
 */ cells(b(fmt(a2)) se(fmt(a2) par)) /*
 */ stats(N r2_annoying statefes hhfes, fmt(%18.0g 3 a3 a3 a3 a3) /*
 */labels(`"Observations"' `"\(R^{2}\)"' `"State F.E."' `"Household Controls"' )) /*
 */ varwidth(20) modelwidth(12) delimiter(&) end(\\) prehead(`"\begin{tabular}{l*{@E}{c}}"' `"\hline\hline \\"') posthead("\\ \hline \\") /* 
 */ prefoot("\\ \hline \\")  postfoot(`"\hline\hline"' `"\multicolumn{@span}{p{.85\textwidth}}{\vspace*{-0.5em}\singlespace  \small \textit{Notes:} Standard errors in parentheses, clustered at the state-month level. Household controls include human capital, demographic, and age fixed effects.  In all cases, the dependent variable is the magnitude of the household forecast error of log earnings.}\\"' `"\end{tabular}"') /* 
 */ label varlabels(_cons Constant, end("" [1em]) nolast) mlabels(none) numbers(\multicolumn{@span}{c}{( )}) /* 
 */ collabels(none)  eqlabels(, begin("\hline" "") nofirst) interaction(" $\times$ ") notype level(95) style(esttab) /* 
 */ replace keep(`keepvars' ) rename(lbeaus_idio `idio_var' lbeaus_aggr_trendq2 `state_var')
 

 
  
  
  

  
