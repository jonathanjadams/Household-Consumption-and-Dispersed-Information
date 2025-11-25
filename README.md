# Household-Consumption-and-Dispersed-Information

This repository contains replication code for the empirical analysis in _Household Consumption and Dispersed Information (2024 JME)_

## Instructions:
Clone the repository, and set your Stata directory to the repository folder.  Then run **sce analysis.do** which will pull from the data folder, and produce tables and figures in the paper folder.

## Dependencies:
 - Stata (code was tested on version 18.0)
 - Two packages:
   - ssc install egenmore
   - ssc install statastates

## Output
- tables/baselinetestsbea.tex (Table 4)
- tables/baselinetestsbea_interact_intertable (Table 5)
- tables/ferror_abs_tests (Table 6)
- tables/baselinetestsferror (Table 12)
- tables/psid_consumption_sensitivity_iv (Table 13)
- tables/psid_income_sensitivity_iv (Table 14)
- graphs/income_decile_coefficients_felag.png (Figure 7a)
- graphs/income_decile_coefficients.png (Figure 7b)
- graphs/psid_consumption_decile_coefficients_fe.png (Figure 19a)
- graphs/psid_consumption_decile_coefficients.png (Figure 19b)
