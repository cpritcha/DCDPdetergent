--ALTER TABLE retail
--  ALTER COLUMN extended_price TYPE double precision USING CAST(extended_price AS double precision);
--ALTER TABLE retail
--  ALTER COLUMN unit_wght TYPE double precision USING CAST(unit_wght AS double precision);
--UPDATE retail SET 
--  unit_wght = unit_wght/1000,
--  extended_price = extended_price/100;

--ALTER TABLE purchhist
--  ALTER COLUMN week TYPE integer USING CAST(week AS integer);
--ALTER TABLE retail
--  ALTER COLUMN week TYPE integer USING CAST(week AS integer);

--ALTER TABLE definitions
--  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);
--ALTER TABLE purchhist
--  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);

--ALTER TABLE purchhist
--  ALTER COLUMN tot_coupon_val_store TYPE double precision USING CAST(tot_coupon_val_store AS double precision);
--
--UPDATE purchhist SET
--  tot_coupon_val_store = tot_coupon_val_store/100;

--ALTER TABLE retail
--  ALTER COLUMN tot_coupon_val_store TYPE double precision USING CAST(tot_coupon_val_store AS double precision); 
--
--UPDATE retail SET
--  tot_coupon_val_store = tot_coupon_val_store/100;

CREATE OR REPLACE FUNCTION categorize_vol(vol integer) returns integer AS $BODY$
    DECLARE
        r integer;
    BEGIN
        CASE 
            WHEN vol <= 31 THEN r := 17;
            WHEN vol <= 63 THEN r := 42;
            WHEN vol <= 93 THEN r := 72;
            WHEN vol <= 150 THEN r := 127;
            WHEN vol <= 300 THEN r := 227;
            ELSE r = 400;
        END CASE;
        RETURN r;
    END
$BODY$ language plpgsql;

CREATE OR REPLACE FUNCTION categorize_vol(vol double precision) returns integer AS $BODY$
    DECLARE
        r integer;
    BEGIN
        CASE 
            WHEN vol <= 31 THEN r := 17;
            WHEN vol <= 63 THEN r := 42;
            WHEN vol <= 93 THEN r := 72;
            WHEN vol <= 150 THEN r := 127;
            WHEN vol <= 300 THEN r := 227;
            ELSE r = 400;
        END CASE;
        RETURN r;
    END
$BODY$ language plpgsql;


--ALTER TABLE purchhist
--  ALTER COLUMN store_id TYPE integer USING CAST(store_id AS integer);
--ALTER TABLE retail
--  ALTER COLUMN store_id TYPE integer USING CAST(store_id AS integer);

--ALTER TABLE purchhist
--  ALTER COLUMN tot_coupon_val_manu TYPE double precision USING CAST(tot_coupon_val_manu AS double precision);
--
--UPDATE purchhist
--  SET tot_coupon_val_manu = tot_coupon_val_manu/100;

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
--  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);
--ALTER TABLE upcdata
--  ALTER COLUMN upc_id TYPE bigint USING CAST(upc_id AS bigint);

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
  SELECT b.hh_id, b.week, COALESCE(vol, 0) AS vol, 0::double precision AS inventory, 0::integer as dinventory, coupon_available_ch, coupon_available_other, coupon_available_td
  FROM min_unit_price_by_brand3 AS b
  LEFT JOIN inventory1 AS i ON (i.hh_id, i.week) = (b.hh_id, b.week);

-- Inventory
CREATE OR REPLACE FUNCTION inventory() RETURNS void AS 
$BODY$
DECLARE
  cur CURSOR FOR
    SELECT r.hh_id, week, vol AS bought, consumption
    FROM results1 AS r
    --WHERE hh_id = 2170639
    INNER JOIN (
      SELECT hh_id, sum(vol)::double precision/(SELECT COUNT(DISTINCT week) FROM key_vars) AS consumption
      FROM inventory1
      GROUP BY hh_id
    ) AS i ON i.hh_id = r.hh_id
    ORDER BY hh_id, week;

  r RECORD;

  hh_id_prev integer;

  consumption double precision;
  inventory_curr double precision;
  inventory_prev double precision;

BEGIN
  hh_id_prev := -1;
  
  FOR r IN cur LOOP
    IF r.hh_id = hh_id_prev THEN
      inventory_curr := CASE 
        WHEN inventory_prev + r.bought - r.consumption <= 0 THEN 0 
        ELSE inventory_prev  + r.bought - r.consumption
      END;
    ELSE
    
      RAISE NOTICE 'hh_id: (%), consumption: (%)', r.hh_id, r.consumption;
      --SELECT avg(vol) INTO vol_avg FROM key_vars4 WHERE hh_id = hh_id_curr
      inventory_curr := 2*r.consumption + r.bought;
      hh_id_prev := r.hh_id;
    END IF;

    UPDATE results1 SET inventory = inventory_curr WHERE hh_id = r.hh_id AND week = r.week;
    -- WHERE CURRENT OF cur;
    inventory_prev := inventory_curr;
  END LOOP;
END
$BODY$
language plpgsql;

CREATE OR REPLACE FUNCTION disc_inventory() RETURNS void AS 
$BODY$
DECLARE
  cur CURSOR FOR
    SELECT r.hh_id, week, vol AS bought, consumption
    FROM results1 AS r
    --WHERE hh_id = 2170639
    INNER JOIN (
      -- discretized consumption
      SELECT hh_id, round(consumption/5)*5 AS consumption
      FROM (
        SELECT hh_id, sum(vol)::double precision/(SELECT COUNT(DISTINCT week) FROM key_vars) AS consumption
        FROM inventory1
        GROUP BY hh_id) AS a
      WHERE consumption > 4 AND consumption < 56.25
    ) AS i ON i.hh_id = r.hh_id
    ORDER BY hh_id, week;

  r RECORD;

  hh_id_prev integer;

  consumption double precision;
  inventory_curr double precision;
  inventory_prev double precision;

BEGIN
  hh_id_prev := -1;
  
  FOR r IN cur LOOP
    IF r.hh_id = hh_id_prev THEN
      inventory_curr := CASE 
        WHEN inventory_prev + r.bought - r.consumption <= 0 THEN 0 
        ELSE inventory_prev  + r.bought - r.consumption
      END;
    ELSE
    
      RAISE NOTICE 'hh_id: (%), consumption: (%)', r.hh_id, r.consumption;
      --SELECT avg(vol) INTO vol_avg FROM key_vars4 WHERE hh_id = hh_id_curr
      inventory_curr := 2*r.consumption + r.bought;
      hh_id_prev := r.hh_id;
    END IF;

    UPDATE results1 SET dinventory = inventory_curr WHERE hh_id = r.hh_id AND week = r.week;
    -- WHERE CURRENT OF cur;
    inventory_prev := inventory_curr;
  END LOOP;
END
$BODY$
language plpgsql;

CREATE INDEX idx_inventory_hh_id ON inventory1 (hh_id);
CREATE INDEX idx_results1 ON results1 (hh_id, week);

UPDATE results1 SET dinventory = NULL; 
SELECT disc_inventory();

DROP TABLE IF EXISTS results_final;
CREATE TABLE results_final AS
  SELECT r.hh_id, week, 
    r.vol,
    enum_vol AS purchased,
    floor(dinventory/dconsumption)::integer AS weeks_to_go,
    coupon_available_ch, 
    coupon_available_other, 
    coupon_available_td,
    inventory,
    dinventory,
    dconsumption
  FROM results1 AS r
  INNER JOIN (
    SELECT hh_id, round(consumption/5)*5 AS dconsumption
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


DROP TABLE IF EXISTS done;
CREATE TABLE done AS
  SELECT *, CAST(consumption/5 - 1 AS integer) AS consumption
  FROM (
    SELECT *,
      lag(weeks_to_go,1,3) OVER (PARTITION BY hh_id ORDER BY week) AS inv_lag
    FROM results_final) AS a;

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



CREATE OR REPLACE FUNCTION disc_wtg() RETURNS void AS 
$BODY$
DECLARE
  cur CURSOR FOR
    SELECT r.hh_id, week, vol AS bought, consumption
    FROM results1 AS r
    --WHERE hh_id = 2170639
    INNER JOIN (
      -- discretized consumption
      SELECT hh_id, round(consumption/5)*5 AS consumption
      FROM (
        SELECT hh_id, sum(vol)::double precision/(SELECT COUNT(DISTINCT week) FROM key_vars) AS consumption
        FROM inventory1
        GROUP BY hh_id) AS a
      WHERE consumption > 4 AND consumption < 56.25
    ) AS i ON i.hh_id = r.hh_id
    ORDER BY hh_id, week;

  r RECORD;

  hh_id_prev integer;

  consumption double precision;
  inventory_curr double precision;
  inventory_prev double precision;

BEGIN
  hh_id_prev := -1;
  
  FOR r IN cur LOOP
    IF r.hh_id = hh_id_prev THEN
      inventory_curr := CASE 
        WHEN inventory_prev -1 + round(r.bought/r.consumption) <= 0 THEN 0 
        ELSE inventory_prev -1 + round(r.bought/r.consumption) 
      END;
    ELSE
    
      RAISE NOTICE 'hh_id: (%), consumption: (%)', r.hh_id, r.consumption;
      --SELECT avg(vol) INTO vol_avg FROM key_vars4 WHERE hh_id = hh_id_curr
      inventory_curr := 2 + round(r.bought/r.consumption);
      hh_id_prev := r.hh_id;
    END IF;

    UPDATE results1 SET dinventory = inventory_curr WHERE hh_id = r.hh_id AND week = r.week;
    -- WHERE CURRENT OF cur;
    inventory_prev := inventory_curr;
  END LOOP;
END
$BODY$
language plpgsql;

