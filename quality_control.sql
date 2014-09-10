-- do weeks to go match weeks in ox
SELECT DISTINCT wks_to_g
FROM done;

-- NULL checks
-- if any NULLS need to fix
SELECT 
  COUNT(*)-COUNT(hh_id) AS null_hh_id,
  COUNT(*)-COUNT(week) AS null_week,
  COUNT(*)-COUNT(purchased) AS null_purchased,
  COUNT(*)-COUNT(inv_lag) AS null_wks_to_g,
  COUNT(*)-COUNT(dconsumption) AS null_dconsumption,
  COUNT(*)-COUNT(coupon_available_ch) AS null_cpn_ch,
  COUNT(*)-COUNT(coupon_available_other) AS null_cpn_other,
  COUNT(*)-COUNT(coupon_available_td) AS null_cpn_td
FROM done;

SELECT COUNT(inv_lag) AS cnt_wks_to_g
FROM done
WHERE inv_lag < 0;

SELECT COUNT(purchased) AS cnt_purch
FROM done
WHERE purchased NOT BETWEEN 0 AND 6; 

SELECT COUNT(dconsumption) AS cnt_dcons
FROM done
WHERE dconsumption NOT BETWEEN 0 AND 10;

SELECT COUNT(DISTINCT week)
FROM done;

-- do any households have multiple consumptions?
SELECT hh_id
FROM done
GROUP BY hh_id
HAVING COUNT(DISTINCT consumption) != 1;
