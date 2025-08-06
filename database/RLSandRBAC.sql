--Enabling RLS on all the tables that Contain store_id
ALTER TABLE Transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE Inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE DemandForecast ENABLE ROW LEVEL SECURITY;
-- You can enable more if needed


-- Store user for store_id = 1
CREATE ROLE store_user_1 LOGIN PASSWORD 'store1pass';

-- Store user for store_id = 2
CREATE ROLE store_user_2 LOGIN PASSWORD 'store2pass';


GRANT SELECT, INSERT, UPDATE, DELETE ON Transactions TO store_user_1;
GRANT SELECT, INSERT, UPDATE, DELETE ON Inventory TO store_user_1;
GRANT SELECT, INSERT, UPDATE, DELETE ON DemandForecast TO store_user_1;

-- Repeat for store_user_2...
GRANT SELECT, INSERT, UPDATE, DELETE ON Transactions TO store_user_2;
GRANT SELECT, INSERT, UPDATE, DELETE ON Inventory TO store_user_2;
GRANT SELECT, INSERT, UPDATE, DELETE ON DemandForecast TO store_user_2;





CREATE POLICY rls_transactions_1 ON Transactions
FOR ALL
TO store_user_1
USING (store_id = 1)
WITH CHECK (store_id = 1);


CREATE POLICY rls_inventory_1 ON Inventory
FOR ALL
TO store_user_1
USING (store_id = 1)
WITH CHECK (store_id = 1);


CREATE POLICY rls_forecast_1 ON DemandForecast
FOR ALL
TO store_user_1
USING (store_id = 1)
WITH CHECK (store_id = 1);


CREATE POLICY rls_transactions_2 ON Transactions
FOR ALL
TO store_user_2
USING (store_id = 2)
WITH CHECK (store_id = 2);


CREATE POLICY rls_inventory_2 ON Inventory
FOR ALL
TO store_user_2
USING (store_id = 2)
WITH CHECK (store_id = 2);


CREATE POLICY rls_forecast_2 ON DemandForecast
FOR ALL
TO store_user_2
USING (store_id = 2)
WITH CHECK (store_id = 2);




CREATE ROLE adminlog LOGIN PASSWORD 'adminpass';


GRANT SELECT, INSERT, UPDATE, DELETE ON Transactions TO adminlog;
GRANT SELECT, INSERT, UPDATE, DELETE ON Inventory TO adminlog;
GRANT SELECT, INSERT, UPDATE, DELETE ON DemandForecast TO adminlog;
-- Add more if needed

CREATE POLICY rls_transactions_admin ON Transactions
FOR ALL
TO adminlog
USING (true)
WITH CHECK (true);

CREATE POLICY rls_inventory_admin ON Inventory
FOR ALL
TO adminlog
USING (true)
WITH CHECK (true);

CREATE POLICY rls_forecast_admin ON DemandForecast
FOR ALL
TO adminlog
USING (true)
WITH CHECK (true);