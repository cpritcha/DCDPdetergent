-- get the data into the right data types
ALTER TABLE purchhist
  ALTER COLUMN hh_id TYPE integer USING CAST(hh_id AS integer);

ALTER TABLE purchhist
  ALTER COLUMN store_id TYPE integer USING CAST(store_id AS integer);
ALTER TABLE retail
  ALTER COLUMN store_id TYPE integer USING CAST(store_id AS integer);

ALTER TABLE purchhist
  ALTER COLUMN tot_coupon_val_manu TYPE double precision USING CAST(tot_coupon_val_manu AS double precision);

UPDATE purchhist
  SET tot_coupon_val_manu = tot_coupon_val_manu/100;

ALTER TABLE upcdata
  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);

ALTER TABLE retail
  ALTER COLUMN extended_price TYPE double precision USING CAST(extended_price AS double precision);
ALTER TABLE retail
  ALTER COLUMN unit_wght TYPE double precision USING CAST(unit_wght AS double precision);
UPDATE retail SET 
  unit_wght = unit_wght/1000,
  extended_price = extended_price/100;

ALTER TABLE purchhist
  ALTER COLUMN week TYPE integer USING CAST(week AS integer);
ALTER TABLE retail
  ALTER COLUMN week TYPE integer USING CAST(week AS integer);

ALTER TABLE definitions
  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);
ALTER TABLE purchhist
  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);

ALTER TABLE purchhist
  ALTER COLUMN tot_coupon_val_store TYPE double precision USING CAST(tot_coupon_val_store AS double precision);

UPDATE purchhist SET
  tot_coupon_val_store = tot_coupon_val_store/100;

ALTER TABLE retail
  ALTER COLUMN tot_coupon_val_store TYPE double precision USING CAST(tot_coupon_val_store AS double precision); 

UPDATE retail SET
  tot_coupon_val_store = tot_coupon_val_store/100;

-- discretize the volumes

DROP TABLE IF EXISTS goods_bought;
CREATE TABLE goods_bought AS
  SELECT hh_id, week, store_id, brand, 
    sum(unit_wght*units_purch) AS vol
  FROM purchhist AS ph
  INNER JOIN definitions AS d ON d.upc_id = ph.upc_id
  WHERE unit_wght > 16
  GROUP BY hh_id, week, store_id, brand;

DROP TABLE IF EXISTS prevalent_brand;
CREATE TABLE prevalent_brand AS 
  WITH cte AS (
  SELECT *, 
    row_number() OVER 
      (PARTITION BY hh_id, week, store_id 
        ORDER BY vol DESC) AS recno
  FROM goods_bought)
SELECT hh_id, week, store_id, brand
FROM cte
WHERE recno = 1;

DROP TABLE IF EXISTS criteria_table;
CREATE TABLE criteria_table AS
  SELECT g.hh_id, g.week, g.store_id, sum(g.vol) AS vol, p.brand
  FROM goods_bought AS g
  INNER JOIN prevalent_brand AS p ON (p.hh_id, p.week, p.store_id) = (g.hh_id, g.week, g.store_id)
  GROUP BY g.hh_id, g.week, g.store_id, p.brand
  ORDER BY hh_id, g.week, p.brand, g.store_id, vol;

DROP TABLE IF EXISTS summary;
CREATE TABLE summary AS
  SELECT hh_id, week, store_id, brand, vol
  FROM criteria_table
  WHERE hh_id IN
    (SELECT hh_id
    FROM criteria_table
    GROUP BY hh_id
    HAVING max(vol) < 410 AND min(vol) > 0); -- exclude large purchasers

DROP TABLE IF EXISTS summary_summary;
CREATE TABLE summary_summary AS
  SELECT hh_id, week, brand, categorize_vol(vol) AS dvol
  FROM summary
  GROUP BY hh_id, week, brand, dvol;
--ALTER TABLE retail
--  ADD COLUMN unit_price double precision;
--ALTER TABLE retail
--  ALTER COLUMN units_purchased TYPE integer USING CAST(units_purchased AS integer);

--ALTER TABLE retail
--  ADD COLUMN unit_price_net_store_coupon double precision;
--ALTER TABLE retail
--  ADD COLUMN unit_gross_price double precision;
--ALTER TABLE retail
--  DROP COLUMN unit_price;

UPDATE retail
SET unit_price_net_store_coupon = 
  ((extended_price/units_purchased - 
        CASE 
            WHEN tot_coupon_num_store = 0 THEN 0 
            ELSE tot_coupon_val_store/tot_coupon_num_store
        END)
            /unit_wght);
UPDATE retail SET 
  unit_gross_price = extended_price/(units_purchased*unit_wght);

DROP TABLE IF EXISTS retail_unit_cost;
CREATE TABLE retail_unit_cost AS
SELECT week, u.upc_id, store_id,
  --substring(u.desc FROM '(\w*) ') AS brand,
  substring(u.desc from 1 for position(' ' in u.desc)-1) AS brand,
  floor(u.unit_wght) AS vol,
  extended_price AS price, 
  units_purchased, 
  tot_coupon_val_store,
  tot_coupon_num_store,
  unit_gross_price,
  unit_price_net_store_coupon
FROM retail AS r
INNER JOIN upcdata AS u ON u.upc_id = r.upc_id;

UPDATE retail_unit_cost
  SET brand = CASE WHEN brand = 'TD' OR brand = 'CH' THEN brand
                ELSE 'Other'
              END;

DROP TABLE IF EXISTS key_vars;
CREATE TABLE key_vars AS
SELECT hh_id, week
FROM
  (SELECT DISTINCT hh_id FROM summary) AS s,
  (SELECT * FROM generate_series(198601, 198652) year1(week)
    UNION
   SELECT * FROM generate_series(198701,198752) year2(week)
    UNION
   SELECT * FROM generate_series(198801,198834) year3(week)) AS weeks;

DROP TABLE IF EXISTS coupon_percent_by_store;
CREATE TABLE coupon_percent_by_store AS
  SELECT week, brand, store_id, 
    min(unit_gross_price) AS min_unit_gross_price, 
    min(unit_price_net_store_coupon) AS min_unit_price_net_store_coupon
  FROM retail_unit_cost
  GROUP BY brand, week, store_id;

CREATE TABLE stores_visited_by_hh AS
  SELECT DISTINCT hh_id, store_id;
  FROM purchhist;

--CREATE INDEX pk_coupon_percent ON coupon_percent (hh_id, week);
--CREATE INDEX pk_key_vars ON key_vars (hh_id, week, store_id);

DROP TABLE IF EXISTS min_unit_price_by_brand;
CREATE TABLE min_unit_price_by_brand AS
SELECT v.hh_id, v.week, 
bool_or(coupon_available_store_ch) AS coupon_available_store_ch, 
    bool_or(coupon_available_store_other) AS coupon_available_store_other, 
    bool_or(coupon_available_store_td) AS coupon_available_store_td
  FROM key_vars AS v
  INNER JOIN stores_visited_by_hh AS s ON s.hh_id = v.hh_id
  INNER JOIN (
    SELECT week, store_id, abs(min_unit_gross_price - min_unit_price_net_store_coupon) > 1e-5 AS coupon_available_store_ch
    FROM coupon_percent_by_store 
    WHERE brand = 'CH') AS c1 ON 
      (c1.week, c1.store_id) = (v.week, s.store_id)
  INNER JOIN (
    SELECT week, store_id, abs(min_unit_gross_price - min_unit_price_net_store_coupon) > 1e-5  AS coupon_available_store_other
    FROM coupon_percent_by_store
    WHERE brand = 'Other') AS c2 ON 
      (c2.week, c2.store_id) = (v.week, s.store_id)
  INNER JOIN (
    SELECT week, store_id, abs(min_unit_gross_price - min_unit_price_net_store_coupon) > 1e-5 AS coupon_available_store_td
    FROM coupon_percent_by_store
    WHERE brand = 'TD') AS c3 ON 
      (c3.week, c3.store_id) = (v.week, s.store_id)
  GROUP BY v.hh_id, v.week;

  
-- manufacturing coupons
-- is a manufacturing coupon available for anyone
DROP TABLE IF EXISTS manu_coupon_summary;
CREATE TABLE manu_coupon_summary AS
  SELECT week, brand,
    median(
      CASE
        WHEN units_purch = 0 THEN NULL
        ELSE (extended_price/units_purch/unit_wght)
      END::numeric) AS unit_gross_price, 
    median(
      (CASE
        WHEN units_purch = 0 THEN NULL
        ELSE (extended_price/units_purch/unit_wght)
      END -
      CASE 
        WHEN units_purch_val_manu = 0 THEN 0 
        ELSE tot_coupon_val_manu/units_purch_val_manu/unit_wght
      END)::numeric) AS unit_price_net_manu_coupon
  FROM purchhist AS p
  INNER JOIN definitions AS d ON d.upc_id = p.upc_id
  GROUP BY week, brand;

DROP TABLE IF EXISTS manu_coupon_available;
CREATE TABLE manu_coupon_available AS
  SELECT week, brand,  1-unit_price_net_manu_coupon/unit_gross_price > 0.2 AS sale
  FROM manu_coupon_summary;

DROP TABLE IF EXISTS min_unit_price_by_brand2;
CREATE TABLE min_unit_price_by_brand2 AS
  SELECT b.hh_id, b.week, 
    coupon_available_store_ch,
    coupon_available_store_other,
    coupon_available_store_td,
    m1.sale AS coupon_available_manu_ch,
    m2.sale AS coupon_available_manu_other, 
    m3.sale AS coupon_available_manu_td 
  FROM min_unit_price_by_brand AS b
  INNER JOIN (
    SELECT week, brand, sale
    FROM manu_coupon_available
    WHERE brand = 'CH') AS m1 ON m1.week = b.week
  INNER JOIN (
    SELECT week, brand, sale
    FROM manu_coupon_available
    WHERE brand = 'Other') AS m2 ON m2.week = b.week
  INNER JOIN (
    SELECT week, brand, sale
    FROM manu_coupon_available
    WHERE brand = 'TD') AS m3 ON m3.week = b.week;

DROP TABLE IF EXISTS min_unit_price_by_brand3;
CREATE TABLE min_unit_price_by_brand3 AS
  SELECT hh_id, week, 
    coupon_available_store_ch OR coupon_available_manu_ch AS coupon_available_ch,
    coupon_available_store_other OR coupon_available_manu_other AS coupon_available_other,
    coupon_available_store_td OR coupon_available_manu_td AS coupon_available_td
  FROM min_unit_price_by_brand2;

DROP TABLE IF EXISTS inventory1;
CREATE TABLE inventory1 AS
  SELECT hh_id, week, categorize_vol(sum(vol)) AS vol
  FROM summary
  GROUP BY hh_id, week;

DROP TABLE IF EXISTS results1;
CREATE TABLE results1 AS
  SELECT b.hh_id, b.week, COALESCE(vol, 0) AS vol, 0::double precision AS inventory, 0::integer as dweeks_to_go, coupon_available_ch, coupon_available_other, coupon_available_td
  FROM min_unit_price_by_brand3 AS b
  LEFT JOIN inventory1 AS i ON (i.hh_id, i.week) = (b.hh_id, b.week);

CREATE INDEX idx_inventory_hh_id ON inventory1 (hh_id);
CREATE INDEX idx_results1 ON results1 (hh_id, week);

UPDATE results1 SET dinventory = NULL; 
SELECT disc_inventory();

DROP TABLE IF EXISTS results_final;
CREATE TABLE results_final AS
  SELECT r.hh_id, week, 
    r.vol,
    enum_vol AS purchased,
    coupon_available_ch, 
    coupon_available_other, 
    coupon_available_td,
    inventory,
    dinventory,
    dconsumption
  FROM results1 AS r
  INNER JOIN (
    SELECT hh_id, round(consumption) AS dconsumption
    FROM (
      SELECT hh_id, sum(vol)::double precision/(SELECT COUNT(DISTINCT week) FROM key_vars) AS consumption
      FROM inventory1
      GROUP BY hh_id) AS a
    WHERE consumption > 4 AND consumption < 56.25
  ) AS i ON i.hh_id = r.hh_id
  INNER JOIN volumes AS v ON v.vol = r.vol
  WHERE r.hh_id IN (
    SELECT hh_id
    FROM shopoccasion
    GROUP BY hh_id
    HAVING COUNT(DISTINCT time4) = 29

    INTERSECT

    SELECT d.hh_id
    FROM hh_consumption AS c
    INNER JOIN hh_demog AS d ON d.hh_id = c.hh_id
    WHERE consumption/hh_size > 1.0

    INTERSECT

    SELECT hh_id
    FROM criteria_table
    GROUP BY hh_id
    HAVING max(vol) < 410 AND min(vol) > 0
  );

SELECT hh_id, week, sum(vol/consumption) - row_number() OVER (PARTITIION BY hh_id, ORDER BY week)
FROM done
ORDER BY hh_id, week
LIMIT 1000


SELECT disc_wtg();

DROP TABLE IF EXISTS results_final;
CREATE TABLE results_final AS
  SELECT r.hh_id, week, 
    r.vol,
    enum_vol AS purchased,
    coupon_available_ch, 
    coupon_available_other, 
    coupon_available_td,
    inventory,
    dinventory,
    dconsumption
  FROM results1 AS r
  INNER JOIN (
    SELECT hh_id, round(consumption)::integer AS dconsumption
    FROM (
      SELECT hh_id, sum(vol)::double precision/(SELECT COUNT(DISTINCT week) FROM key_vars) AS consumption
      FROM inventory1
      GROUP BY hh_id) AS a
    WHERE consumption > 4 AND consumption < 56.25
  ) AS i ON i.hh_id = r.hh_id
  INNER JOIN volumes AS v ON v.vol = r.vol
  WHERE r.hh_id IN (
    -- household shopped at least once every month
    SELECT hh_id
    FROM shopoccasion
    GROUP BY hh_id
    HAVING COUNT(DISTINCT time4) = 29

    INTERSECT

    -- household must consume at least 4 ounces of detergent per person per week
    SELECT d.hh_id
    FROM hh_consumption AS c
    INNER JOIN hh_demog AS d ON d.hh_id = c.hh_id
    WHERE consumption/hh_size > 4.0

    INTERSECT

    -- exclude households that bought more than 410 ounces in a week at least once 
    --  or that bought a negative amount of laundry detergent
    SELECT hh_id
    FROM criteria_table
    GROUP BY hh_id
    HAVING max(vol) < 410 AND min(vol) > 0
  );

DROP TABLE IF EXISTS done;
CREATE TABLE done AS
  SELECT *, CAST(dconsumption - 4 AS integer) AS consumption
  FROM (
    SELECT *,
      lag(dinventory,1,NULL) OVER (PARTITION BY hh_id ORDER BY week) AS inv_lag
    FROM results_final) AS a
  WHERE hh_id IN (
    SELECT hh_id
    FROM results_final
    GROUP BY hh_id
    HAVING COUNT(week) = 138);

UPDATE done SET inv_lag = dl.inv_first + 1 - vol/dconsumption 
  FROM (
    SELECT hh_id, inv_lag AS inv_first, inv_lag
    FROM done
    WHERE week = 198602
  ) AS dl 
  WHERE dl.hh_id = done.hh_id
    AND done.week = 198601;

--CREATE INDEX idx_done ON done (hh_id, week);

UPDATE done SET inv_lag = b.min_unrestricted_wtg
FROM (
  SELECT hh_id, CASE WHEN -min(unrestricted_wtg) < 0 THEN 0 ELSE -min(unrestricted_wtg) END AS min_unrestricted_wtg
  FROM (
    SELECT hh_id, week, vol, dconsumption, 
      sum(vol/dconsumption) OVER (PARTITION BY hh_id ORDER BY week) - row_number() OVER (PARTITION BY hh_id ORDER BY week) AS unrestricted_wtg
    FROM done
    ORDER BY hh_id, week
  ) AS a
  GROUP BY hh_id) AS b
WHERE done.week = 198601 AND done.hh_id = b.hh_id;


SELECT disc_wtg_done();

SELECT *
FROM done
ORDER BY hh_id, week
LIMIT 1000;

ALTER TABLE done
  ALTER COLUMN purchased TYPE integer USING CAST(purchased AS integer);

DROP TABLE IF EXISTS volumes;
CREATE TABLE volumes AS
  SELECT vol, row_number() OVER (ORDER BY vol) -1 AS enum_vol
  FROM (
    SELECT 0
    UNION
    SELECT DISTINCT categorize_vol(unit_wght) AS vol
    FROM purchhist) AS a;

CREATE TABLE brands AS
  SELECT brand, row_number() OVER (ORDER BY brand) AS enum_brand
  FROM (
    SELECT DISTINCT brand
    FROM purchhist) AS a;
