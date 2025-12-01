******************************************************************************************
* replication code for the empirical analysis in Household Consumption and Dispersed Information (Adams and Rojas 2024 JME)
* sce figures.do: creates figures (run "sce analysis.do" first)
******************************************************************************************
 
 //ESTIMATE COEFFICIENT DIFFERENCES BY INCOME DECILE
 
clear all 
 
 *set CD to the replication repository:
// cd "[insert here]"
 
 
use "data\sce_labor_panel.dta"


// create deciles
egen l4_sal_deciles = xtile(l4_lsal`trend') if l4_sal>0, by(date) nq(10)
replace l4_sal_deciles = 0 if l4_sal==0


local trend  _trendq2  //_trendq _us_trendq _trendq2 _us_trendq2
local demographics sex hispanic white black amindian asian pacisland
local battery i.state i.industry i.edu_cat i.age_cat `demographics'



// simple specification test:

gen decile_name = .
gen decile_coef = .
gen decile_lb = .
gen decile_ub = .

la var decile_name "Decile"
forvalues dd = 1/10{ // it's log income, i decided to drop the zeros form teh chart
	di `dd'
	reg lesal`trend' lbea_idio lbea_state`trend' if l4_sal_deciles==`dd', vce(cluster clusterid)
	lincom lbea_state`trend' - lbea_idio
	local entry = `dd'+1
	replace decile_name = `dd' in `entry'
	replace decile_coef = r(estimate) in `entry'
	local upperbound = r(estimate) + 1.96*r(se)
	local lowerbound = r(estimate) - 1.96*r(se)
	replace decile_ub = `upperbound' in `entry'
	replace decile_lb = `lowerbound' in `entry'
}



graph twoway scatter decile_coef decile_name  , sort ||  rcap decile_lb decile_ub decile_name, /*
	*/ graphregion(color(white)) plotregion(color(white)) /*
	*/ legend(label(1 "Coefficient Difference") label(2 "95% C.I.")) 
	graph export "graphs\income_decile_coefficients.png", replace



//Richer specification including fixed effects + 1 lag:

gen decile_coef_felag = .
gen decile_lb_felag = .
gen decile_ub_felag = .


forvalues dd = 1/10{
	di `dd'
	qui reg lesal`trend' lbea_idio lbea_state`trend' l4_lsal`trend' `battery'  if l4_sal_deciles==`dd' , vce(cluster clusterid)
	lincom lbea_state`trend' - lbea_idio
	local entry = `dd'+1
	replace decile_coef_felag = r(estimate) in `entry'
	local upperbound_fe = r(estimate) + 1.96*r(se)
	local lowerbound_fe = r(estimate) - 1.96*r(se)
	replace decile_ub_felag = `upperbound_fe' in `entry'
	replace decile_lb_felag = `lowerbound_fe' in `entry'
}
graph twoway scatter decile_coef_felag decile_name  , sort ||  rcap decile_lb_felag decile_ub_felag decile_name, /*
	*/ graphregion(color(white)) plotregion(color(white)) /*
	*/ legend(label(1 "Coefficient Difference") label(2 "95% C.I.")) 
	graph export "graphs\income_decile_coefficients_felag.png", replace

	