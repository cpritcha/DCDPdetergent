UPDATE retail_unit_cost
  SET brand = CASE WHEN brand = 'TD' OR brand = 'CH' THEN brand
                ELSE 'Other'
              END;


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

-- initial inventory set to make minimum unrestricted inventory zero
CREATE OR REPLACE FUNCTION disc_wtg_done() RETURNS void AS 
$BODY$
DECLARE
  cur CURSOR FOR
    SELECT r.hh_id, week, vol AS bought, dconsumption AS consumption, inv_lag
    FROM done AS r
    ORDER BY hh_id, week;

  r RECORD;

  hh_id_prev integer;

  consumption integer;
  inventory_curr integer;
  inventory_prev integer;

  bought_prev integer;
  consumption_prev integer;

BEGIN
  hh_id_prev := -1;
  
  FOR r IN cur LOOP
    IF r.hh_id = hh_id_prev THEN
      inventory_curr := CASE 
        WHEN inventory_prev -1 + bought_prev/consumption_prev <= 0 THEN 0 
        ELSE inventory_prev -1 + bought_prev/consumption_prev
      END;

      UPDATE done SET inv_lag = inventory_curr WHERE hh_id = r.hh_id AND week = r.week;
    ELSE
    
      RAISE NOTICE 'hh_id: (%), consumption: (%)', r.hh_id, r.consumption;

      hh_id_prev := r.hh_id;
      inventory_curr := r.inv_lag;
    END IF;

    bought_prev := r.bought;
    consumption_prev := r.consumption;
    inventory_prev := inventory_curr;
  END LOOP;
END
$BODY$
language plpgsql;


