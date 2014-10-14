-- get the data into the right data types
ALTER TABLE purchhist
  ALTER COLUMN hh_id TYPE integer USING CAST(hh_id AS integer);
ALTER TABLE purchhist
  ALTER COLUMN store_id TYPE integer USING CAST(store_id AS integer);
ALTER TABLE retail
  ALTER COLUMN store_id TYPE integer USING CAST(store_id AS integer);
ALTER TABLE purchhist
  ALTER COLUMN tot_coupon_val_manu TYPE double precision USING CAST(tot_coupon_val_manu AS double precision);
ALTER TABLE purchhist
  ALTER COLUMN week TYPE integer USING CAST(week AS integer);
ALTER TABLE purchhist
  ALTER COLUMN unit_wght TYPE integer USING CAST(unit_wght AS integer);
ALTER TABLE purchhist
  ALTER COLUMN units_purch TYPE integer USING CAST(units_purch AS integer);
ALTER TABLE purchhist
  ALTER COLUMN tot_coupon_val_store TYPE double precision USING CAST(tot_coupon_val_store AS double precision);
ALTER TABLE purchhist
  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);
ALTER TABLE purchhist
  ALTER COLUMN units_purch_val_manu TYPE integer USING CAST(units_purch_val_manu AS integer);
ALTER TABLE purchhist
  ALTER COLUMN extended_price TYPE double precision USING CAST(extended_price AS double precision);

UPDATE purchhist SET 
  tot_coupon_val_manu = tot_coupon_val_manu/100,
  tot_coupon_val_store = tot_coupon_val_store/100, 
  unit_wght = unit_wght/1000,
  extended_price = extended_price/100,
  units_purch = units_purch/100;

ALTER TABLE upcdata
  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);
ALTER TABLE upcdata
  ALTER COLUMN unit_wght TYPE integer USING CAST(unit_wght AS integer);
UPDATE upcdata SET 
  unit_wght = unit_wght/1000;
ALTER TABLE upcdata
  ADD COLUMN brand text;
UPDATE upcdata
  SET brand = substring("desc",'\w+');
UPDATE upcdata 
SET brand = 
  CASE WHEN 
    brand <> 'CTL' AND 
    brand <> 'JIF' AND
    brand <> 'PETER' AND 
    brand <> 'SKIPPY'
    THEN 'OTHER'
  ELSE brand END;

ALTER TABLE retail
  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);
ALTER TABLE retail
  ALTER COLUMN week TYPE integer USING CAST(week AS integer);
ALTER TABLE retail
  ALTER COLUMN extended_price TYPE double precision USING CAST(extended_price AS double precision);
ALTER TABLE retail
  ALTER COLUMN tot_coupon_val_store TYPE double precision USING CAST(tot_coupon_val_store AS double precision); 

ALTER TABLE retail
  ADD COLUMN unit_price_net_store_coupon double precision;
ALTER TABLE retail
  ADD COLUMN unit_gross_price double precision;


UPDATE retail SET 
  unit_wght = unit_wght/1000,
  extended_price = extended_price/100;
UPDATE retail SET
  tot_coupon_val_store = tot_coupon_val_store/100;

-- discretize the volumes

DROP TABLE IF EXISTS goods_bought;
CREATE TABLE goods_bought AS
  SELECT hh_id, week, store_id, brand, 
    sum(ph.unit_wght*ph.units_purch) AS vol
  FROM purchhist AS ph
  INNER JOIN upcdata AS d ON d.upc_id = ph.upc_id
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

--SELECT *
--FROM criteria_table
--ORDER BY vol desc
--LIMIT 1000;

DROP TABLE IF EXISTS summary;
CREATE TABLE summary AS
  SELECT hh_id, week, store_id, brand, vol
  FROM criteria_table
  WHERE hh_id IN
    (SELECT hh_id
    FROM criteria_table
    GROUP BY hh_id
    HAVING max(vol) < 81 AND min(vol) > 7); -- exclude large purchasers 9201/9341

DROP TABLE IF EXISTS summary_summary;
CREATE TABLE summary_summary AS
  SELECT hh_id, week, brand, categorize_vol(vol) AS dvol
  FROM summary
  GROUP BY hh_id, week, brand, dvol;

UPDATE retail
SET unit_price_net_store_coupon = 
  ((extended_price::double precision/units_purchased - 
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
  brand,
  floor(u.unit_wght) AS vol,
  extended_price AS price, 
  units_purchased, 
  tot_coupon_val_store,
  tot_coupon_num_store,
  unit_gross_price,
  unit_price_net_store_coupon
FROM retail AS r
INNER JOIN upcdata AS u ON u.upc_id = r.upc_id;

DROP TABLE IF EXISTS key_vars;
CREATE TABLE key_vars AS
SELECT hh_id, week
FROM
  (SELECT DISTINCT hh_id FROM summary) AS s,
  (SELECT * FROM generate_series(198625, 198652) year1(week)
    UNION
   SELECT * FROM generate_series(198701,198723) year2(week)) AS weeks;

DROP TABLE IF EXISTS coupon_percent_by_store;
CREATE TABLE coupon_percent_by_store AS
  SELECT week, brand, store_id, 
    min(unit_gross_price) AS min_unit_gross_price, 
    min(unit_price_net_store_coupon) AS min_unit_price_net_store_coupon
  FROM retail_unit_cost
  GROUP BY brand, week, store_id;

DROP TABLE IF EXISTS stores_visited_by_hh;
CREATE TABLE stores_visited_by_hh AS
  SELECT DISTINCT hh_id, store_id
  FROM purchhist;

DROP TABLE IF EXISTS key_vars_stores;
CREATE TABLE key_vars_stores AS
  SELECT k.hh_id, week, store_id
  FROM key_vars AS k
  INNER JOIN stores_visited_by_hh AS s ON s.hh_id = k.hh_id;

CREATE INDEX pk_coupon_percent ON coupon_percent_by_store (week, store_id);
CREATE INDEX pk_key_vars_store ON key_vars_stores (week, store_id);

DROP TABLE IF EXISTS min_unit_price_by_brand;
CREATE TABLE min_unit_price_by_brand AS
SELECT v.hh_id, v.week, 
    bool_or(coupon_available_store_ctl) AS coupon_available_store_ctl, 
    bool_or(coupon_available_store_jif) AS coupon_available_store_jif, 
    bool_or(coupon_available_store_skippy) AS coupon_available_store_skippy,
    bool_or(coupon_available_store_peter) AS coupon_available_store_peter,
    bool_or(coupon_available_store_other) AS coupon_available_store_other
  FROM key_vars_stores AS v
  INNER JOIN (
    SELECT week, store_id, abs(min_unit_gross_price - min_unit_price_net_store_coupon) > 1e-5 AS coupon_available_store_ctl
    FROM coupon_percent_by_store 
    WHERE brand = 'CTL') AS c1 ON 
      (c1.week, c1.store_id) = (v.week, v.store_id)
  INNER JOIN (
    SELECT week, store_id, abs(min_unit_gross_price - min_unit_price_net_store_coupon) > 1e-5 AS coupon_available_store_jif
    FROM coupon_percent_by_store 
    WHERE brand = 'JIF') AS c2 ON 
      (c2.week, c2.store_id) = (v.week, v.store_id)
  INNER JOIN (
    SELECT week, store_id, abs(min_unit_gross_price - min_unit_price_net_store_coupon) > 1e-5 AS coupon_available_store_skippy
    FROM coupon_percent_by_store 
    WHERE brand = 'SKIPPY') AS c3 ON 
      (c3.week, c3.store_id) = (v.week, v.store_id)
  INNER JOIN (
    SELECT week, store_id, abs(min_unit_gross_price - min_unit_price_net_store_coupon) > 1e-5  AS coupon_available_store_peter
    FROM coupon_percent_by_store
    WHERE brand = 'PETER') AS c4 ON 
      (c4.week, c4.store_id) = (v.week, v.store_id)
  INNER JOIN (
    SELECT week, store_id, abs(min_unit_gross_price - min_unit_price_net_store_coupon) > 1e-5 AS coupon_available_store_other
    FROM coupon_percent_by_store
    WHERE brand = 'OTHER') AS c5 ON 
      (c5.week, c5.store_id) = (v.week, v.store_id)
  GROUP BY v.hh_id, v.week;

-- manufacturing coupons
-- is a manufacturing coupon available for anyone
DROP TABLE IF EXISTS manu_coupon_summary;
CREATE TABLE manu_coupon_summary AS
  SELECT week, brand,
    median(
      CASE
        WHEN units_purch = 0 THEN NULL
        ELSE (extended_price/units_purch/p.unit_wght)
      END::numeric) AS unit_gross_price, 
    median(
      (CASE
        WHEN units_purch = 0 THEN NULL
        ELSE (extended_price/units_purch/p.unit_wght)
      END -
      CASE 
        WHEN units_purch_val_manu = 0 THEN 0 
        ELSE tot_coupon_val_manu/units_purch_val_manu/p.unit_wght
      END)::numeric) AS unit_price_net_manu_coupon
  FROM purchhist AS p
  INNER JOIN upcdata AS d ON d.upc_id = p.upc_id
  GROUP BY week, brand;

DROP TABLE IF EXISTS manu_coupon_available;
CREATE TABLE manu_coupon_available AS
  SELECT week, brand,  1-unit_price_net_manu_coupon/unit_gross_price > 0.05 AS sale
  FROM manu_coupon_summary;

DROP TABLE IF EXISTS min_unit_price_by_brand2;
CREATE TABLE min_unit_price_by_brand2 AS
  SELECT b.hh_id, b.week, 
    coupon_available_store_ctl,
    coupon_available_store_jif,
    coupon_available_store_peter,
    coupon_available_store_skippy,
    coupon_available_store_other,
    m1.sale AS coupon_available_manu_ctl,
    m2.sale AS coupon_available_manu_jif, 
    m3.sale AS coupon_available_manu_peter, 
    m4.sale AS coupon_available_manu_skippy, 
    m5.sale AS coupon_available_manu_other
  FROM min_unit_price_by_brand AS b
  INNER JOIN (
    SELECT week, brand, sale
    FROM manu_coupon_available
    WHERE brand = 'CTL') AS m1 ON m1.week = b.week
  INNER JOIN (
    SELECT week, brand, sale
    FROM manu_coupon_available
    WHERE brand = 'JIF') AS m2 ON m2.week = b.week
  INNER JOIN (
    SELECT week, brand, sale
    FROM manu_coupon_available
    WHERE brand = 'PETER') AS m3 ON m3.week = b.week
  INNER JOIN (
    SELECT week, brand, sale
    FROM manu_coupon_available
    WHERE brand = 'SKIPPY') AS m4 ON m4.week = b.week
  INNER JOIN (
    SELECT week, brand, sale
    FROM manu_coupon_available
    WHERE brand = 'OTHER') AS m5 ON m5.week = b.week;

DROP TABLE IF EXISTS min_unit_price_by_brand3;
CREATE TABLE min_unit_price_by_brand3 AS
  SELECT hh_id, week, 
    coupon_available_store_ctl OR coupon_available_manu_ctl AS coupon_available_ctl,
    coupon_available_store_jif OR coupon_available_manu_jif AS coupon_available_jif,
    coupon_available_store_peter OR coupon_available_manu_peter AS coupon_available_peter,
    coupon_available_store_skippy OR coupon_available_manu_skippy AS coupon_available_skippy,
    coupon_available_store_other OR coupon_available_manu_other AS coupon_available_other
  FROM min_unit_price_by_brand2;

DROP TABLE IF EXISTS inventory1;
CREATE TABLE inventory1 AS
  SELECT hh_id, week, categorize_vol(sum(vol)) AS vol
  FROM summary
  GROUP BY hh_id, week;

DROP TABLE IF EXISTS results1;
CREATE TABLE results1 AS
  SELECT b.hh_id, b.week, COALESCE(vol, 0) AS vol, 0::double precision AS inventory, 0::integer as dweeks_to_go, 
    coupon_available_ctl, coupon_available_jif, coupon_available_peter, coupon_available_skippy, coupon_available_other
  FROM min_unit_price_by_brand3 AS b
  LEFT JOIN inventory1 AS i ON (i.hh_id, i.week) = (b.hh_id, b.week);

CREATE INDEX idx_inventory_hh_id ON inventory1 (hh_id);
CREATE INDEX idx_results1 ON results1 (hh_id, week);

--UPDATE results1 SET dinventory = NULL; 
--SELECT disc_inventory();
DROP TABLE IF EXISTS hh_consumption;
CREATE TABLE hh_consumption AS
  SELECT hh_id, sum(vol)::double precision/(SELECT COUNT(DISTINCT week) FROM key_vars) AS consumption
  FROM inventory1
  GROUP BY hh_id;

DROP TABLE IF EXISTS volumes;
CREATE TABLE volumes AS
  SELECT vol, row_number() OVER (ORDER BY vol) -1 AS enum_vol
  FROM (
    SELECT 0 AS vol
    UNION
    SELECT DISTINCT categorize_vol(unit_wght) AS vol
    FROM purchhist) AS a;

DROP TABLE IF EXISTS brands;
CREATE TABLE brands AS
  SELECT brand, row_number() OVER (ORDER BY brand) AS enum_brand
  FROM (
    SELECT DISTINCT brand
    FROM upcdata) AS a;

DROP TABLE IF EXISTS results_final;
CREATE TABLE results_final AS
  SELECT r.hh_id, week, 
    r.vol,
    enum_vol AS purchased,
    coupon_available_ctl, 
    coupon_available_jif, 
    coupon_available_peter,
    coupon_available_skippy,
    coupon_available_other,
    dconsumption
  FROM results1 AS r
  INNER JOIN (
    SELECT hh_id, round(consumption) AS dconsumption
    FROM (
      SELECT hh_id, sum(vol)::double precision/(SELECT COUNT(DISTINCT week) FROM key_vars) AS consumption
      FROM inventory1
      GROUP BY hh_id) AS a
    --WHERE consumption > 4 AND consumption < 56.25
  ) AS i ON i.hh_id = r.hh_id
  INNER JOIN volumes AS v ON v.vol = r.vol
  WHERE r.hh_id IN (
    SELECT hh_id
    FROM shopoccasion
    GROUP BY hh_id
    HAVING COUNT(DISTINCT time4) = 13

    INTERSECT

    SELECT d.hh_id
    FROM hh_consumption AS c
    INNER JOIN hh_demog AS d ON d.hh_id = c.hh_id
    WHERE consumption/hh_size > 0.5

    INTERSECT

    SELECT hh_id
    FROM criteria_table
    GROUP BY hh_id
    HAVING max(vol) < 81 AND min(vol) > 7
  );

--SELECT hh_id, week, sum(vol/consumption) - row_number() OVER (PARTITION BY hh_id ORDER BY week)
--FROM done
--ORDER BY hh_id, week
--LIMIT 1000
--
--SELECT disc_wtg();

DROP TABLE IF EXISTS done;
CREATE TABLE done AS
  SELECT *, CAST(dconsumption - 1 AS integer) AS consumption
  FROM (
    SELECT *, NULL::integer inv_lag
    FROM results_final) AS a;
--  WHERE hh_id IN (
--    SELECT hh_id
--    FROM results_final
--    GROUP BY hh_id
--    HAVING COUNT(week) = 138);

--UPDATE done SET inv_lag = dl.inv_first + 1 - vol/dconsumption 
--  FROM (
--    SELECT hh_id, inv_lag AS inv_first, inv_lag
--    FROM done
--    WHERE week = 198626
--  ) AS dl 
--  WHERE dl.hh_id = done.hh_id
--    AND done.week = 198625;

CREATE INDEX idx_done ON done (hh_id, week);

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
WHERE done.week = 198625 AND done.hh_id = b.hh_id;

SELECT disc_wtg_done();

DROP TABLE IF EXISTS done_no_outlier;
CREATE TABLE done_no_outlier AS
SELECT *
FROM done
WHERE hh_id IN (
  SELECT hh_id
  FROM done
  GROUP BY hh_id
  HAVING COUNT(CASE WHEN vol = 0 THEN NULL ELSE vol END) > 2);
