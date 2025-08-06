select * from transactions order by transaction_id desc;
CREATE SEQUENCE transactions_transaction_id_seq
START WITH 1
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;

ALTER TABLE Transactions
ALTER COLUMN transaction_id SET DEFAULT nextval('transactions_transaction_id_seq');

SELECT setval('transactions_transaction_id_seq', (SELECT MAX(transaction_id) FROM Transactions));


--Creating Trigger Function first

CREATE OR REPLACE FUNCTION update_inventory_after_detail()
RETURNS TRIGGER AS $$
DECLARE
  store INT;
BEGIN
  SELECT store_id INTO store FROM Transactions WHERE transaction_id = NEW.transaction_id;

  UPDATE Inventory
  SET inventory_level = inventory_level - NEW.quantity
  WHERE store_id = store AND product_id = NEW.product_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_inventory_after_detail
AFTER INSERT ON TransactionDetails
FOR EACH ROW
EXECUTE FUNCTION update_inventory_after_detail();






-- Testing it bu inserting a transaction detail
SELECT * FROM Inventory WHERE product_id IN (101, 102);
-- Step 1: Insert a new transaction
INSERT INTO Transactions (transaction_date, customer_id, store_id,
    payment_method_id, promotion_applied, promotion_id,
    weather_id, stockout
) VALUES (
NOW(), 1001, 5, 1, false, NULL, 1, false
);

-- Step 2: Insert transaction details
INSERT INTO TransactionDetails (transaction_id, product_id, quantity)
VALUES 
    (5001, 101, 2),
    (5001, 102, 3);

-- Step 3: Check Inventory before and after
SELECT * FROM Inventory WHERE product_id IN (101, 102);



CREATE OR REPLACE PROCEDURE insert_transaction(
    p_transaction_date TIMESTAMP,
    p_customer_id INT,
    p_store_id INT,
    p_payment_method_id INT,
    p_promotion_applied BOOLEAN,
    p_promotion_id INT,
    p_weather_id INT,
    p_stockout BOOLEAN,
    p_product_ids INT[],
    p_quantities INT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaction_id INT;
    i INT;
    v_exists INT;
BEGIN
    -- Step 1: Insert into Transactions table
    INSERT INTO Transactions (
        transaction_date, customer_id, store_id,
        payment_method_id, promotion_applied, promotion_id,
        weather_id, stockout
    ) VALUES (
        p_transaction_date, p_customer_id, p_store_id,
        p_payment_method_id, p_promotion_applied, p_promotion_id,
        p_weather_id, p_stockout
    )
    RETURNING transaction_id INTO v_transaction_id;  -- capture auto-generated transaction_id

    -- Step 2: Insert into TransactionDetails
    FOR i IN 1 .. array_length(p_product_ids, 1) LOOP

        -- Check if product exists in Inventory for that store
        SELECT COUNT(*) INTO v_exists
        FROM Inventory
        WHERE store_id = p_store_id AND product_id = p_product_ids[i];

        IF v_exists = 0 THEN
            RAISE EXCEPTION 'Product % is not available in store %', p_product_ids[i], p_store_id;
        END IF;

        -- If check passes, insert into TransactionDetails
        INSERT INTO TransactionDetails (
            transaction_id, product_id, quantity
        ) VALUES (
            v_transaction_id, p_product_ids[i], p_quantities[i]
        );

    END LOOP;
END;
$$;
CREATE OR REPLACE PROCEDURE insert_transaction(
    p_transaction_date TIMESTAMP,
    p_customer_id INT,
    p_store_id INT,
    p_payment_method_id INT,
    p_promotion_applied BOOLEAN,
    p_promotion_id INT,
    p_weather_id INT,
    p_stockout BOOLEAN,
    p_product_ids INT[],
    p_quantities INT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaction_id INT;
    missing_count INT;
BEGIN
    -- Step 1: Validate all products exist in Inventory
    SELECT COUNT(*)
    INTO missing_count
    FROM UNNEST(p_product_ids) AS pid
    WHERE NOT EXISTS (
        SELECT 1 FROM Inventory
        WHERE store_id = p_store_id AND product_id = pid
    );

    IF missing_count > 0 THEN
        RAISE EXCEPTION 'One or more products are not available in store %', p_store_id;
    END IF;

    -- Step 2: Insert into Transactions
    INSERT INTO Transactions (
        transaction_date, customer_id, store_id,
        payment_method_id, promotion_applied, promotion_id,
        weather_id, stockout
    )
    VALUES (
        p_transaction_date, p_customer_id, p_store_id,
        p_payment_method_id, p_promotion_applied, p_promotion_id,
        p_weather_id, p_stockout
    )
    RETURNING transaction_id INTO v_transaction_id;

    -- Step 3: Insert all TransactionDetails in one go
    INSERT INTO TransactionDetails (transaction_id, product_id, quantity)
    SELECT v_transaction_id, pid, qty
    FROM UNNEST(p_product_ids, p_quantities) AS t(pid, qty);

END;
$$;



CALL insert_transaction(
    NOW()::TIMESTAMP,         -- transaction_date (TIMESTAMP)
    1001::INT,                -- customer_id (INT)
    5::INT,                   -- store_id (INT)
    1::INT,                   -- payment_method_id (INT)
    TRUE::BOOLEAN,            -- promotion_applied (BOOLEAN)
    2::INT,                   -- promotion_id (INT)
    1::INT,                   -- weather_id (INT)
    FALSE::BOOLEAN,           -- stockout (BOOLEAN)
    ARRAY[101, 102]::INT[],    -- product_ids (INT ARRAY)
    ARRAY[2, 3]::INT[]         -- quantities (INT ARRAY)
);




select * from transactions order by transaction_id desc;
select * from transactiondetails order by transaction_id desc;
select * from inventory where product_id=101 or product_id = 102;

DROP TRIGGER IF EXISTS trg_update_inventory_after_transaction ON Transactions;
DROP FUNCTION IF EXISTS update_inventory_after_transaction();