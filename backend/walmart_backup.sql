--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: insert_transaction(timestamp without time zone, integer, integer, integer, boolean, integer, integer, boolean, integer[], integer[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insert_transaction(IN p_transaction_date timestamp without time zone, IN p_customer_id integer, IN p_store_id integer, IN p_payment_method_id integer, IN p_promotion_applied boolean, IN p_promotion_id integer, IN p_weather_id integer, IN p_stockout boolean, IN p_product_ids integer[], IN p_quantities integer[])
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


ALTER PROCEDURE public.insert_transaction(IN p_transaction_date timestamp without time zone, IN p_customer_id integer, IN p_store_id integer, IN p_payment_method_id integer, IN p_promotion_applied boolean, IN p_promotion_id integer, IN p_weather_id integer, IN p_stockout boolean, IN p_product_ids integer[], IN p_quantities integer[]) OWNER TO postgres;

--
-- Name: insert_transaction(integer, timestamp without time zone, integer, integer, integer, boolean, integer, integer, boolean, integer[], integer[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insert_transaction(IN p_transaction_id integer, IN p_transaction_date timestamp without time zone, IN p_customer_id integer, IN p_store_id integer, IN p_payment_method_id integer, IN p_promotion_applied boolean, IN p_promotion_id integer, IN p_weather_id integer, IN p_stockout boolean, IN p_product_ids integer[], IN p_quantities integer[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INT;
BEGIN
    -- Insert into Transactions
    INSERT INTO Transactions (
        transaction_id, transaction_date, customer_id, store_id,
        payment_method_id, promotion_applied, promotion_id,
        weather_id, stockout
    ) VALUES (
        p_transaction_id, p_transaction_date, p_customer_id, p_store_id,
        p_payment_method_id, p_promotion_applied, p_promotion_id,
        p_weather_id, p_stockout
    );

    -- Loop through product_ids and insert into TransactionDetails
    FOR i IN 1 .. array_length(p_product_ids, 1) LOOP
        INSERT INTO TransactionDetails (
            transaction_id, product_id, quantity
        ) VALUES (
            p_transaction_id, p_product_ids[i], p_quantities[i]
        );
    END LOOP;
END;
$$;


ALTER PROCEDURE public.insert_transaction(IN p_transaction_id integer, IN p_transaction_date timestamp without time zone, IN p_customer_id integer, IN p_store_id integer, IN p_payment_method_id integer, IN p_promotion_applied boolean, IN p_promotion_id integer, IN p_weather_id integer, IN p_stockout boolean, IN p_product_ids integer[], IN p_quantities integer[]) OWNER TO postgres;

--
-- Name: update_inventory_after_detail(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_inventory_after_detail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  store INT;
BEGIN
  SELECT store_id INTO store FROM Transactions WHERE transaction_id = NEW.transaction_id;

  UPDATE Inventory
  SET inventory_level = inventory_level - NEW.quantity
  WHERE store_id = store AND product_id = NEW.product_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_inventory_after_detail() OWNER TO postgres;

--
-- Name: update_inventory_after_sale(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_inventory_after_sale() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE Inventory
  SET inventory_level = inventory_level - NEW.quantity
  WHERE store_id = (
    SELECT store_id FROM Transactions
    WHERE transaction_id = NEW.transaction_id
  )
  AND product_id = NEW.product_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_inventory_after_sale() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categories (
    category_id integer NOT NULL,
    category_name character varying(50)
);


ALTER TABLE public.categories OWNER TO postgres;

--
-- Name: categories_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.categories_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categories_category_id_seq OWNER TO postgres;

--
-- Name: categories_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.categories_category_id_seq OWNED BY public.categories.category_id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    customer_id integer NOT NULL,
    age integer,
    gender character varying(10),
    income numeric(10,2),
    loyalty_level character varying(20)
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- Name: demandforecast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.demandforecast (
    forecast_date date NOT NULL,
    store_id integer NOT NULL,
    product_id integer NOT NULL,
    forecasted_demand integer,
    actual_demand integer
);


ALTER TABLE public.demandforecast OWNER TO postgres;

--
-- Name: inventory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory (
    store_id integer NOT NULL,
    product_id integer NOT NULL,
    inventory_level integer
);


ALTER TABLE public.inventory OWNER TO postgres;

--
-- Name: paymentmethods; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.paymentmethods (
    method_id integer NOT NULL,
    method_name character varying(50)
);


ALTER TABLE public.paymentmethods OWNER TO postgres;

--
-- Name: paymentmethods_method_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.paymentmethods_method_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.paymentmethods_method_id_seq OWNER TO postgres;

--
-- Name: paymentmethods_method_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.paymentmethods_method_id_seq OWNED BY public.paymentmethods.method_id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    product_id integer NOT NULL,
    product_name character varying(100),
    category_id integer,
    supplier_id integer,
    unit_price numeric(10,2),
    reorder_point integer,
    reorder_quantity integer
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: promotionapplications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.promotionapplications (
    transaction_id integer NOT NULL,
    promotion_id integer NOT NULL
);


ALTER TABLE public.promotionapplications OWNER TO postgres;

--
-- Name: promotions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.promotions (
    promotion_id integer NOT NULL,
    promotion_type character varying(50)
);


ALTER TABLE public.promotions OWNER TO postgres;

--
-- Name: promotions_promotion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.promotions_promotion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.promotions_promotion_id_seq OWNER TO postgres;

--
-- Name: promotions_promotion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.promotions_promotion_id_seq OWNED BY public.promotions.promotion_id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stores (
    store_id integer NOT NULL,
    location character varying(100)
);


ALTER TABLE public.stores OWNER TO postgres;

--
-- Name: transactiondetails; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transactiondetails (
    transaction_id integer NOT NULL,
    product_id integer NOT NULL,
    quantity integer
);


ALTER TABLE public.transactiondetails OWNER TO postgres;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.transactions_transaction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transactions_transaction_id_seq OWNER TO postgres;

--
-- Name: transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transactions (
    transaction_id integer DEFAULT nextval('public.transactions_transaction_id_seq'::regclass) NOT NULL,
    transaction_date timestamp without time zone,
    customer_id integer,
    store_id integer,
    payment_method_id integer,
    promotion_applied boolean,
    promotion_id integer,
    weather_id integer,
    stockout boolean
);


ALTER TABLE public.transactions OWNER TO postgres;

--
-- Name: weather; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.weather (
    weather_id integer NOT NULL,
    weather_conditions character varying(50)
);


ALTER TABLE public.weather OWNER TO postgres;

--
-- Name: weather_weather_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.weather_weather_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.weather_weather_id_seq OWNER TO postgres;

--
-- Name: weather_weather_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.weather_weather_id_seq OWNED BY public.weather.weather_id;


--
-- Name: categories category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories ALTER COLUMN category_id SET DEFAULT nextval('public.categories_category_id_seq'::regclass);


--
-- Name: paymentmethods method_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paymentmethods ALTER COLUMN method_id SET DEFAULT nextval('public.paymentmethods_method_id_seq'::regclass);


--
-- Name: promotions promotion_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.promotions ALTER COLUMN promotion_id SET DEFAULT nextval('public.promotions_promotion_id_seq'::regclass);


--
-- Name: weather weather_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.weather ALTER COLUMN weather_id SET DEFAULT nextval('public.weather_weather_id_seq'::regclass);


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categories (category_id, category_name) FROM stdin;
1	Electronics
2	Appliances
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customers (customer_id, age, gender, income, loyalty_level) FROM stdin;
2824	29	Other	98760.83	Silver
1409	34	Other	69781.93	Gold
5506	69	Other	77373.10	Platinum
5012	47	Other	33383.04	Silver
4657	70	Female	108999.41	Bronze
3286	40	Male	31779.77	Bronze
2679	54	Female	75813.17	Platinum
9935	57	Female	115784.29	Silver
2424	64	Other	77392.78	Platinum
7912	24	Male	44787.70	Bronze
1520	67	Male	101268.72	Platinum
1488	25	Female	52253.32	Silver
2535	49	Female	22027.62	Bronze
4582	30	Female	65337.53	Gold
4811	54	Male	81043.27	Bronze
9279	20	Male	55162.40	Silver
1434	68	Female	84105.52	Silver
4257	43	Other	28754.82	Platinum
9928	44	Male	65975.21	Bronze
7873	38	Other	106725.94	Platinum
4611	21	Male	77489.83	Silver
8359	65	Other	86773.84	Gold
5557	43	Female	90816.55	Bronze
1106	50	Female	57698.63	Gold
3615	51	Male	44320.68	Gold
7924	58	Female	110254.19	Platinum
6574	64	Male	23520.55	Gold
5552	50	Male	45558.46	Gold
3547	41	Female	77669.59	Bronze
4527	47	Female	111298.17	Bronze
6514	63	Male	116645.94	Platinum
2674	45	Other	60397.59	Gold
2519	67	Male	71524.97	Silver
7224	20	Female	53675.06	Gold
2584	29	Other	46591.75	Bronze
6881	47	Female	46110.47	Bronze
6635	30	Male	84317.95	Bronze
5333	25	Other	99864.97	Platinum
1711	45	Male	102848.17	Gold
8527	19	Male	52485.34	Gold
9785	33	Other	35558.79	Bronze
3045	40	Female	52420.13	Gold
7201	21	Male	60290.79	Silver
2291	27	Male	40580.96	Gold
5803	62	Female	106546.53	Platinum
6925	37	Male	67684.91	Bronze
4150	39	Female	44829.51	Gold
2139	18	Male	113713.11	Bronze
1750	43	Female	24183.49	Silver
4733	70	Other	92852.30	Platinum
5741	30	Male	47241.60	Platinum
2307	26	Female	29909.45	Bronze
4814	65	Male	86761.58	Bronze
2654	47	Other	101221.71	Gold
7227	68	Other	35157.70	Silver
5554	21	Other	48442.51	Silver
8428	62	Male	85217.95	Platinum
6977	62	Male	56597.14	Silver
3664	61	Male	94487.48	Silver
7065	40	Male	103118.84	Silver
6820	27	Female	118178.00	Bronze
4432	35	Female	110883.10	Silver
5374	23	Female	83341.85	Silver
2169	60	Female	100745.24	Bronze
3803	45	Female	100375.50	Bronze
9751	56	Female	79297.40	Platinum
5010	70	Male	21194.58	Gold
3677	34	Male	20389.64	Bronze
8573	67	Other	28977.08	Bronze
7216	67	Male	78767.52	Platinum
5422	58	Other	33420.16	Gold
4598	65	Female	68810.22	Silver
6313	38	Other	92249.17	Silver
1916	45	Female	30211.00	Platinum
4752	37	Male	69504.20	Silver
1525	42	Other	85658.97	Gold
6168	52	Female	29772.04	Silver
7572	44	Other	58641.91	Silver
5386	42	Male	61610.34	Silver
2084	47	Male	61760.44	Platinum
4456	43	Male	43640.61	Platinum
6155	67	Other	24442.75	Bronze
4483	58	Female	23721.97	Silver
9179	60	Male	46071.30	Gold
7482	64	Male	89027.25	Platinum
8517	63	Male	84024.27	Platinum
3340	34	Other	67483.34	Silver
5339	44	Male	96546.69	Gold
3287	57	Female	65593.93	Gold
5040	25	Female	56737.81	Silver
9830	35	Male	45523.24	Gold
5304	28	Male	57373.83	Platinum
8019	63	Male	43939.60	Silver
7543	50	Female	52116.97	Silver
6930	37	Male	94210.23	Silver
4593	18	Other	62801.49	Platinum
3266	19	Other	36535.42	Gold
9348	18	Male	35234.93	Platinum
9085	18	Other	73542.56	Silver
2489	62	Other	90900.00	Silver
1771	25	Male	65819.84	Silver
2796	31	Female	112414.59	Silver
3504	66	Male	58700.64	Gold
3621	46	Other	25639.26	Silver
7916	34	Other	68695.94	Silver
2040	30	Female	98228.07	Platinum
7304	46	Other	110199.45	Bronze
7252	50	Male	77716.11	Silver
8668	35	Male	77554.84	Silver
9669	49	Other	111413.58	Silver
5119	64	Other	29122.87	Silver
1188	24	Female	35413.35	Platinum
2876	19	Female	30786.94	Gold
9797	66	Other	42643.65	Platinum
5371	48	Female	75488.31	Bronze
6573	33	Other	56879.25	Platinum
2827	50	Other	49753.83	Gold
5808	69	Female	74406.83	Silver
8123	29	Female	106832.71	Gold
3591	30	Female	82217.52	Gold
8433	29	Other	111854.79	Bronze
1053	27	Other	25671.78	Platinum
5315	38	Female	51082.58	Silver
9201	64	Male	70959.07	Bronze
3927	60	Male	80543.74	Bronze
9317	61	Female	60161.34	Bronze
2743	52	Male	63473.08	Silver
5889	62	Female	75207.75	Gold
4258	32	Female	56894.87	Gold
7126	45	Female	79753.13	Silver
3646	67	Female	51389.78	Platinum
9837	67	Female	57783.41	Silver
9689	28	Female	90105.00	Gold
1009	59	Other	76606.52	Platinum
6310	64	Female	66682.07	Gold
9005	27	Female	66238.35	Silver
1319	31	Female	56856.21	Silver
2832	64	Male	111403.54	Silver
6947	33	Other	96304.22	Silver
6038	35	Male	36043.99	Bronze
4923	39	Female	49173.07	Silver
1949	20	Female	24539.99	Platinum
4946	25	Female	28190.16	Gold
2290	39	Male	89770.37	Bronze
2403	35	Male	33350.36	Bronze
8962	25	Other	81236.98	Silver
2133	48	Male	108231.74	Silver
9727	49	Male	22535.55	Platinum
3060	43	Female	28950.99	Platinum
3103	41	Male	22562.55	Platinum
8787	47	Other	63045.29	Gold
3705	52	Female	79357.58	Bronze
5342	44	Female	101034.98	Gold
9645	70	Female	37066.31	Gold
7932	45	Other	29824.29	Gold
4470	23	Female	94545.43	Gold
9835	20	Male	65901.28	Gold
4295	62	Male	97701.81	Gold
6107	59	Male	24212.73	Gold
7537	21	Male	50055.95	Gold
7118	20	Female	45576.11	Silver
8177	19	Female	38742.96	Platinum
9479	40	Male	71780.79	Silver
8397	56	Other	33742.98	Platinum
2982	23	Female	116494.73	Silver
5061	25	Male	119683.28	Platinum
4681	51	Male	87321.53	Silver
2049	42	Other	74755.10	Silver
6539	28	Male	55945.55	Silver
1344	59	Female	65556.17	Silver
4770	64	Other	71207.10	Gold
4608	35	Other	41100.58	Silver
1117	49	Female	31038.42	Silver
2163	56	Male	91524.12	Platinum
1964	66	Other	116021.02	Gold
4750	33	Female	34905.07	Gold
2104	57	Male	23947.58	Platinum
1514	31	Other	90287.74	Silver
6413	58	Male	42589.54	Platinum
2160	31	Other	69302.30	Gold
9423	37	Other	83750.79	Bronze
4899	50	Male	59019.46	Silver
5562	60	Other	26869.44	Silver
8953	54	Female	64463.75	Bronze
4510	23	Female	45405.78	Bronze
9834	36	Female	69737.39	Platinum
3167	21	Female	110989.62	Gold
8744	26	Other	79231.86	Silver
4981	43	Male	40886.39	Bronze
8749	55	Male	106697.19	Silver
7669	59	Male	88273.32	Platinum
4119	61	Female	110771.56	Gold
2545	42	Male	36305.81	Gold
2588	32	Female	73351.25	Platinum
8062	23	Other	106825.17	Platinum
6804	38	Male	100867.48	Platinum
7939	62	Other	52361.73	Gold
7735	40	Female	93687.81	Platinum
8651	58	Other	77054.14	Bronze
1887	40	Male	31992.35	Gold
2612	61	Female	47025.32	Platinum
1993	51	Male	116942.59	Bronze
7596	21	Male	44814.49	Platinum
6559	59	Male	112957.40	Bronze
2790	19	Female	48893.13	Gold
5073	50	Female	74760.35	Bronze
4139	48	Other	32715.51	Silver
4116	41	Female	48691.07	Silver
9786	49	Male	20227.76	Silver
8350	67	Male	74056.89	Silver
3296	39	Other	49416.81	Gold
4006	39	Male	93061.53	Silver
5563	24	Other	62618.67	Gold
8579	62	Female	46314.37	Gold
5092	31	Female	31883.62	Bronze
2235	25	Female	114237.50	Bronze
8260	50	Other	50025.35	Silver
2604	66	Female	35420.81	Gold
1828	32	Male	94646.18	Gold
9856	65	Male	108563.87	Bronze
1241	64	Other	24980.69	Bronze
2528	53	Female	106667.98	Silver
4872	26	Female	58170.28	Gold
3724	30	Other	39210.51	Bronze
7658	49	Female	98119.81	Bronze
8956	21	Other	53195.81	Silver
8886	60	Male	68578.00	Platinum
4502	65	Female	88290.41	Silver
7570	52	Female	30091.28	Silver
1960	35	Female	115634.82	Bronze
3697	35	Female	115713.39	Silver
7209	34	Other	72918.11	Silver
1035	42	Female	20099.92	Bronze
7396	52	Other	62802.80	Bronze
5345	58	Other	77281.19	Platinum
8454	38	Male	72058.20	Silver
5673	19	Female	53231.91	Silver
7930	24	Other	54720.84	Silver
8973	60	Other	82744.22	Platinum
3536	30	Other	109700.76	Bronze
4111	58	Other	86032.59	Platinum
5861	52	Female	38089.19	Platinum
4566	23	Male	111420.27	Platinum
1958	33	Other	58896.99	Platinum
9883	50	Male	43893.25	Silver
1998	41	Other	24591.47	Bronze
6138	63	Male	106639.86	Platinum
1936	61	Other	45423.70	Bronze
1821	37	Female	61091.13	Platinum
8811	24	Other	70236.31	Gold
9238	53	Female	26153.66	Platinum
9701	37	Other	75277.64	Silver
3579	29	Male	114717.79	Platinum
1931	57	Female	59638.42	Gold
9320	32	Other	43541.37	Platinum
2312	28	Other	51284.22	Bronze
4044	43	Other	55543.93	Silver
2122	65	Other	102411.14	Gold
2113	35	Female	43718.21	Bronze
4853	38	Other	50797.43	Bronze
7615	47	Male	23016.09	Bronze
2964	20	Other	65778.27	Silver
5033	22	Other	56278.71	Gold
1651	48	Other	83446.58	Silver
2343	69	Male	87655.27	Silver
7868	46	Female	32447.93	Gold
9565	33	Other	47593.10	Bronze
6183	32	Female	108535.45	Silver
5272	49	Female	78947.85	Silver
4346	60	Male	22056.86	Platinum
6147	20	Other	82969.26	Gold
4910	22	Male	62781.50	Silver
5351	21	Female	44463.72	Silver
7484	45	Female	74393.35	Platinum
3144	41	Male	49914.72	Gold
5915	30	Female	35459.42	Platinum
8491	43	Female	30261.81	Silver
6180	20	Male	22882.77	Silver
2188	40	Male	54582.67	Bronze
1152	36	Other	95234.70	Bronze
8508	68	Female	71955.25	Silver
2638	64	Female	82805.84	Bronze
2200	70	Female	103382.84	Platinum
9808	54	Male	97877.09	Gold
4492	49	Male	48771.41	Silver
9288	23	Female	22630.66	Silver
3170	48	Other	110677.56	Silver
6718	54	Other	83469.40	Platinum
2127	32	Other	41295.66	Bronze
5002	23	Male	82022.89	Bronze
7054	58	Other	61080.97	Platinum
5669	20	Other	63702.21	Platinum
3584	52	Female	112477.58	Gold
8179	27	Other	50989.92	Bronze
9900	42	Female	32428.51	Bronze
5956	28	Male	57595.31	Gold
9666	59	Male	25386.35	Bronze
1128	59	Female	94243.61	Platinum
5905	48	Other	69297.55	Gold
2697	47	Other	116334.25	Gold
3200	38	Other	104977.68	Platinum
2891	67	Male	46094.60	Silver
2753	64	Female	53642.89	Silver
3546	56	Male	49577.45	Platinum
5462	56	Other	61627.13	Gold
5616	63	Other	38617.07	Platinum
4450	57	Female	42203.45	Silver
6617	65	Male	28062.22	Platinum
4335	18	Other	118750.33	Bronze
5325	45	Female	118889.25	Bronze
9280	62	Male	41161.22	Bronze
9004	19	Male	89805.81	Bronze
5114	37	Other	88610.30	Gold
1832	25	Male	91842.84	Platinum
2512	50	Female	75531.43	Bronze
5533	57	Male	116422.23	Silver
1722	70	Other	24069.22	Silver
1058	42	Male	74270.48	Platinum
6464	18	Female	67128.74	Bronze
3143	57	Female	112864.42	Bronze
5291	41	Male	116683.06	Gold
3647	42	Other	111545.68	Silver
8239	43	Female	22609.52	Bronze
8007	24	Male	23361.28	Silver
1158	23	Male	64614.00	Gold
2232	65	Male	115675.81	Silver
3442	53	Female	80139.34	Bronze
9938	29	Other	102177.08	Bronze
1590	53	Male	29406.46	Gold
7049	54	Male	77136.61	Silver
3426	26	Female	60294.60	Silver
8041	23	Other	97493.09	Bronze
3088	63	Female	65288.50	Silver
1685	19	Female	21085.85	Bronze
6050	48	Other	112509.32	Gold
6974	38	Male	106220.95	Gold
1653	50	Female	114144.79	Silver
6862	45	Female	70933.93	Silver
4441	37	Male	70705.68	Silver
5088	32	Female	113094.12	Platinum
2684	41	Male	102283.76	Bronze
6794	53	Female	113813.65	Platinum
3532	33	Male	23247.89	Bronze
4878	19	Other	74292.80	Bronze
3662	55	Male	42515.65	Platinum
3900	49	Other	73241.62	Silver
7755	38	Female	86383.31	Silver
1406	32	Other	69038.02	Silver
3938	30	Female	98849.01	Bronze
6442	62	Male	80636.41	Silver
7745	42	Other	24458.96	Bronze
5065	30	Other	104473.09	Bronze
3608	34	Other	55993.41	Gold
2771	55	Male	39924.06	Bronze
7267	26	Other	79592.57	Bronze
1634	50	Male	47940.47	Platinum
8711	58	Male	116305.90	Bronze
4644	55	Female	71666.35	Platinum
4269	44	Other	72116.57	Gold
8541	55	Male	67845.38	Platinum
6728	24	Male	44522.13	Bronze
6000	51	Other	107570.14	Gold
4728	61	Female	44813.85	Silver
4652	43	Male	51655.92	Bronze
1387	25	Male	41467.30	Platinum
4164	60	Female	68714.59	Platinum
7528	48	Female	117961.14	Platinum
6378	38	Female	92165.87	Platinum
5564	59	Other	21269.13	Silver
2137	43	Male	101915.84	Bronze
5573	52	Male	53625.25	Bronze
6753	45	Male	43217.33	Bronze
9346	31	Male	113623.19	Gold
7548	34	Male	72120.57	Gold
6425	60	Female	35279.11	Bronze
1452	35	Other	21771.30	Gold
2889	69	Other	40447.09	Silver
5279	55	Other	103993.75	Silver
3925	42	Other	23529.40	Silver
5349	35	Male	21091.14	Platinum
1626	60	Female	111284.36	Gold
2776	61	Female	80831.71	Silver
8119	28	Other	57962.56	Silver
6663	29	Female	73592.65	Platinum
6139	19	Male	110519.57	Bronze
8149	44	Male	59864.42	Gold
9379	69	Female	104515.68	Platinum
2894	70	Male	69120.11	Silver
7311	67	Male	70749.52	Gold
4114	54	Other	52328.47	Bronze
5173	66	Male	56419.90	Platinum
1727	54	Other	55391.97	Platinum
8144	60	Other	54561.26	Silver
1027	27	Female	82594.75	Silver
9518	39	Female	29197.65	Silver
9821	67	Male	90406.07	Silver
4228	39	Male	109874.54	Platinum
6967	51	Male	104831.41	Gold
8066	67	Other	112502.94	Bronze
2146	33	Other	113563.12	Gold
6409	21	Female	29168.53	Gold
6143	18	Other	35921.82	Gold
3041	30	Female	99133.70	Silver
5920	69	Male	33855.02	Bronze
9308	40	Other	50567.84	Platinum
6067	52	Male	61189.89	Gold
7691	21	Other	67747.64	Silver
6344	60	Other	90639.14	Platinum
7592	62	Female	102723.54	Bronze
5844	63	Other	82942.58	Bronze
3085	53	Male	89907.00	Platinum
4143	67	Female	28682.20	Bronze
7888	47	Male	70127.23	Platinum
7211	41	Other	25335.83	Platinum
3851	43	Female	108727.87	Platinum
5930	58	Female	84423.47	Silver
7653	33	Female	59302.86	Bronze
9977	34	Female	47553.37	Platinum
1006	65	Other	30309.71	Silver
5978	36	Male	112705.30	Platinum
5700	57	Male	85637.68	Silver
4443	24	Other	67656.50	Silver
8043	64	Male	104478.07	Gold
6279	20	Male	119736.53	Platinum
8618	50	Male	79264.04	Gold
8238	51	Male	114396.41	Gold
8244	40	Female	46591.24	Silver
4501	32	Female	57188.06	Platinum
9375	36	Female	69165.68	Silver
8752	53	Male	94460.20	Bronze
3780	52	Other	29022.58	Platinum
2389	33	Other	68833.49	Bronze
5649	23	Female	78417.70	Bronze
9445	56	Male	27017.83	Silver
6491	66	Female	56274.17	Bronze
2530	29	Male	43089.54	Bronze
4848	46	Male	37490.94	Silver
6085	64	Female	55812.19	Gold
4680	28	Other	54406.42	Platinum
4262	46	Male	42399.24	Silver
3414	69	Female	40837.16	Silver
1400	46	Female	39790.98	Silver
1757	50	Other	45734.44	Silver
5011	68	Male	104813.77	Gold
8784	31	Female	74667.64	Platinum
2193	36	Female	80788.52	Silver
8461	21	Female	81764.80	Silver
7790	49	Female	22521.98	Gold
4185	55	Male	103110.94	Silver
7291	61	Other	95293.26	Silver
9099	58	Other	112421.17	Silver
7547	69	Other	36849.66	Gold
4997	30	Female	37696.88	Silver
3417	26	Other	111372.40	Silver
1090	50	Male	27226.32	Platinum
2746	23	Other	33254.57	Gold
7965	53	Other	66218.71	Bronze
4585	23	Female	99192.41	Bronze
3881	42	Male	58911.71	Bronze
9486	60	Female	59786.76	Gold
8611	48	Other	108029.95	Gold
1822	23	Other	57323.78	Silver
5082	49	Male	78218.42	Silver
2988	46	Male	117644.71	Bronze
8478	60	Male	67085.81	Gold
3184	24	Female	67234.55	Platinum
8612	25	Female	49832.98	Platinum
9702	18	Male	29714.14	Gold
6198	32	Other	93188.58	Platinum
8251	36	Female	51064.12	Platinum
9270	20	Other	48703.83	Platinum
7991	29	Other	29346.53	Bronze
9976	21	Male	117281.31	Platinum
8305	49	Female	37541.52	Bronze
3607	32	Male	98932.78	Silver
8777	45	Male	45350.15	Gold
8373	22	Female	110028.22	Bronze
5246	49	Other	83130.31	Platinum
5050	37	Female	27778.84	Gold
5543	38	Other	90979.99	Silver
9540	47	Female	45620.72	Gold
8939	66	Other	85937.11	Silver
4919	34	Other	108653.29	Bronze
5499	24	Female	118260.82	Bronze
8206	48	Female	67284.99	Gold
2269	58	Other	92364.54	Silver
5681	57	Female	104926.48	Silver
4841	22	Male	87149.49	Bronze
5451	50	Male	40259.02	Silver
6502	35	Male	67987.98	Bronze
6238	58	Male	63666.78	Platinum
9849	51	Female	83058.31	Platinum
2320	18	Other	72495.46	Gold
3267	19	Female	49459.72	Platinum
3471	68	Female	78817.98	Platinum
4788	21	Other	104912.74	Bronze
7275	19	Male	82851.02	Silver
3503	66	Male	110070.54	Platinum
4505	18	Male	79925.97	Platinum
2052	70	Other	27534.67	Gold
7797	23	Male	35275.01	Gold
7678	32	Female	107303.81	Bronze
6421	33	Female	88995.17	Bronze
9890	21	Female	88785.28	Platinum
8633	61	Male	32690.38	Platinum
7812	58	Female	107982.16	Platinum
2020	28	Male	50854.05	Bronze
4388	64	Female	50647.53	Silver
7883	25	Other	84532.89	Gold
7381	35	Male	98946.43	Platinum
1320	70	Other	20318.78	Platinum
7232	53	Other	66560.61	Gold
8814	55	Female	107348.51	Platinum
1096	19	Female	41100.73	Platinum
6763	34	Female	109201.01	Platinum
5892	18	Female	80343.08	Gold
7389	23	Male	72138.00	Platinum
7865	23	Other	24644.02	Silver
9818	64	Other	105488.62	Platinum
9947	70	Male	71396.73	Gold
4613	33	Female	90436.32	Bronze
8999	68	Female	104115.94	Silver
4595	67	Female	111041.81	Silver
5471	59	Female	74663.35	Platinum
8140	54	Other	94945.08	Platinum
1475	24	Male	49216.83	Platinum
7371	40	Other	64580.14	Gold
6507	60	Male	86524.92	Silver
7624	58	Other	47769.17	Gold
3704	53	Male	110957.87	Gold
8657	64	Male	114400.99	Gold
3091	22	Female	58987.95	Platinum
1441	27	Other	85888.31	Silver
7455	47	Female	58294.16	Gold
1444	67	Female	68095.41	Gold
2375	49	Male	76927.30	Platinum
8022	27	Other	105133.06	Silver
3223	35	Female	76765.74	Bronze
8564	36	Male	44940.27	Bronze
3977	33	Male	28307.31	Bronze
1823	59	Other	27033.87	Silver
5262	46	Other	97774.68	Platinum
6363	44	Female	36540.84	Silver
4467	36	Male	27401.87	Gold
8449	38	Female	106387.12	Silver
6355	42	Female	73113.93	Bronze
6529	22	Other	55111.89	Silver
5558	64	Female	55540.15	Silver
7906	65	Male	74054.17	Gold
5133	37	Male	27226.42	Silver
2341	45	Female	39540.87	Bronze
8705	53	Male	99783.06	Gold
1317	54	Female	92818.70	Platinum
1853	41	Other	58420.44	Silver
6733	62	Female	70821.63	Gold
4673	58	Other	75265.86	Silver
2124	52	Female	37306.97	Bronze
1659	65	Male	34814.39	Platinum
1508	30	Female	113874.35	Bronze
5051	31	Other	30112.05	Gold
4266	43	Female	44639.93	Platinum
1333	39	Other	78566.30	Silver
3496	57	Other	91031.30	Platinum
4908	66	Other	37265.67	Platinum
3068	46	Other	92008.65	Platinum
8758	37	Other	77537.62	Silver
2874	49	Other	99568.46	Bronze
4571	20	Male	56159.70	Bronze
8619	58	Male	21927.14	Silver
5198	55	Male	27996.76	Bronze
7043	24	Female	60212.85	Silver
3749	36	Male	85907.53	Bronze
3683	47	Male	103315.31	Silver
6096	65	Male	28662.81	Silver
1420	25	Female	41459.27	Platinum
6111	56	Female	35834.75	Platinum
7149	29	Female	66982.41	Bronze
7498	62	Other	104951.43	Bronze
4249	61	Female	38802.10	Bronze
2245	56	Other	71111.79	Silver
4978	66	Other	49253.53	Bronze
2669	18	Male	47739.87	Gold
5941	50	Male	114864.46	Silver
2983	68	Male	63893.82	Silver
1672	32	Other	63823.13	Silver
6688	32	Female	47570.21	Gold
9728	51	Female	54332.66	Bronze
8018	26	Male	47388.31	Gold
7071	65	Male	103102.25	Gold
2129	42	Female	57409.91	Gold
9289	40	Male	85014.11	Bronze
6590	45	Female	119880.95	Platinum
1207	25	Other	64159.16	Silver
7882	54	Female	114715.85	Platinum
9031	48	Other	95767.51	Bronze
2729	52	Other	39378.23	Bronze
8102	58	Female	26718.32	Bronze
6934	69	Other	53869.42	Platinum
8532	67	Female	118418.40	Silver
3506	55	Male	104102.27	Bronze
8135	42	Male	65555.77	Gold
3885	52	Male	56886.99	Gold
9548	22	Male	73068.72	Gold
5425	26	Other	115840.87	Bronze
9817	42	Other	57156.41	Platinum
8921	43	Other	76343.24	Platinum
8616	44	Male	62070.37	Platinum
8136	61	Other	113169.31	Platinum
5397	57	Male	116832.22	Gold
6280	55	Male	98130.79	Platinum
5022	25	Other	53576.28	Silver
2419	42	Female	87282.45	Bronze
5569	64	Male	29296.03	Platinum
8385	54	Other	63855.10	Gold
4995	54	Male	98313.58	Bronze
8613	28	Male	58689.08	Platinum
6511	63	Female	96835.55	Bronze
1470	47	Male	63417.24	Silver
9098	46	Male	109063.65	Platinum
6325	61	Male	68016.95	Gold
3979	19	Male	29304.51	Gold
8988	61	Other	113829.76	Platinum
4475	50	Other	111117.48	Silver
6813	69	Female	36014.30	Platinum
5232	58	Other	116831.38	Bronze
6576	45	Male	101563.47	Gold
5581	62	Other	32551.30	Silver
5526	68	Female	116279.13	Bronze
1166	42	Female	99503.73	Gold
9464	40	Male	99916.32	Bronze
4130	47	Female	53063.66	Gold
2402	68	Male	114626.48	Silver
4954	36	Male	76423.55	Silver
4937	45	Female	58443.37	Platinum
8800	41	Other	99255.88	Bronze
9041	56	Other	107877.95	Bronze
8342	46	Female	29848.38	Bronze
1282	46	Male	86182.01	Gold
2524	60	Other	98183.24	Gold
5820	38	Male	46808.40	Gold
4630	56	Female	21048.17	Bronze
7625	47	Female	71902.14	Platinum
4986	49	Female	92634.18	Silver
6016	45	Other	71772.82	Gold
7046	48	Female	100810.22	Platinum
8753	31	Other	21355.46	Platinum
9698	62	Male	86310.63	Silver
6632	60	Female	47321.03	Silver
7971	68	Female	35950.39	Bronze
6419	69	Other	98119.52	Silver
6764	58	Female	107572.86	Silver
8434	50	Other	96093.26	Gold
5438	19	Other	59787.57	Gold
6023	20	Female	30701.13	Silver
5118	47	Other	81330.92	Silver
4777	38	Male	23729.62	Platinum
2976	20	Other	82944.27	Bronze
4155	64	Other	66304.28	Platinum
6169	70	Female	74193.64	Silver
2958	44	Other	79155.86	Bronze
9779	51	Other	52914.17	Silver
4033	26	Female	77615.53	Platinum
4138	30	Other	27975.90	Platinum
4545	59	Male	30070.31	Bronze
8933	64	Male	75598.81	Silver
5530	33	Other	69957.37	Bronze
9595	67	Other	117647.48	Platinum
5636	48	Female	86354.06	Bronze
2647	33	Female	72339.39	Platinum
4180	32	Female	71932.17	Silver
5853	54	Other	27649.43	Platinum
4727	33	Female	64765.94	Silver
6912	35	Male	46092.45	Platinum
3939	47	Other	78455.08	Platinum
5952	67	Male	88118.47	Bronze
1231	36	Other	62227.15	Silver
3073	23	Female	62360.64	Platinum
5494	60	Female	52055.05	Platinum
1745	64	Male	67212.20	Platinum
1893	29	Female	87551.28	Bronze
5786	45	Female	72596.23	Platinum
9042	53	Female	69226.17	Gold
2680	50	Male	103015.58	Platinum
1200	43	Other	73496.21	Platinum
5658	70	Male	31824.75	Bronze
8690	39	Male	62546.03	Bronze
8843	46	Other	37789.81	Gold
8216	21	Other	40130.69	Gold
6582	46	Other	75667.20	Silver
4020	33	Other	113136.98	Bronze
1841	59	Other	56767.19	Gold
5136	70	Female	85474.49	Silver
8827	52	Male	56590.89	Gold
2869	41	Female	81196.20	Gold
2070	34	Female	100831.73	Bronze
7565	43	Female	26598.75	Platinum
9056	18	Male	106130.26	Bronze
2213	65	Male	114791.03	Gold
1878	65	Female	48845.00	Bronze
3485	66	Male	89953.43	Silver
3444	41	Other	86647.82	Platinum
2395	23	Other	59896.57	Platinum
5066	47	Male	98514.85	Silver
2940	31	Male	75755.96	Silver
7818	26	Female	28944.26	Gold
4697	22	Female	74321.67	Gold
9561	33	Other	84102.52	Gold
8381	18	Female	87840.81	Gold
8253	58	Other	96873.57	Bronze
5871	39	Male	69017.37	Gold
8025	50	Female	104404.74	Gold
6003	69	Other	68992.74	Bronze
1986	46	Female	47183.58	Bronze
2625	61	Female	118829.51	Platinum
4404	53	Male	75949.60	Platinum
4457	55	Female	52038.25	Bronze
5335	28	Other	89768.63	Silver
2330	69	Female	81481.24	Platinum
3573	58	Other	60377.70	Silver
4929	50	Other	61132.32	Gold
3847	51	Male	57450.74	Bronze
2229	18	Male	85885.22	Bronze
3564	28	Other	89582.68	Platinum
1043	63	Other	58064.36	Bronze
7693	67	Female	51646.26	Platinum
8699	28	Female	39201.53	Bronze
5771	55	Female	118773.76	Silver
1534	60	Other	117357.53	Silver
4792	70	Female	96075.93	Silver
5720	40	Female	48722.76	Platinum
5632	39	Female	38435.05	Silver
8438	67	Female	58497.71	Gold
2166	66	Male	39637.38	Gold
4824	70	Male	85408.74	Silver
5334	49	Female	87101.74	Bronze
4241	43	Female	78781.10	Gold
2880	66	Other	29508.92	Silver
9922	31	Other	41986.66	Silver
4683	21	Other	109721.72	Platinum
3441	50	Female	83425.40	Gold
5352	51	Other	101912.11	Gold
3330	52	Male	66398.14	Gold
1977	49	Female	62243.15	Bronze
3718	70	Male	117893.46	Platinum
6039	61	Female	54764.18	Gold
5728	20	Male	82564.39	Gold
8195	46	Male	36835.83	Platinum
3037	56	Other	47090.59	Bronze
8679	64	Male	83013.48	Gold
5982	55	Female	26201.83	Silver
7594	64	Female	42117.80	Platinum
5460	22	Female	96025.17	Bronze
9199	62	Male	100855.29	Gold
9847	61	Other	73603.95	Bronze
9090	56	Male	87689.87	Gold
8172	68	Male	38910.00	Platinum
2317	64	Female	40300.35	Platinum
8078	44	Other	49549.41	Bronze
5102	30	Female	114743.26	Gold
1423	61	Female	25133.68	Bronze
2496	60	Male	20261.51	Platinum
1339	23	Other	89912.39	Platinum
5415	40	Other	38396.98	Bronze
3870	36	Male	34421.17	Silver
8708	32	Other	76325.25	Gold
9502	67	Male	36046.98	Platinum
8245	37	Male	54954.28	Bronze
3973	57	Female	98386.64	Bronze
8141	23	Female	91101.65	Silver
2494	70	Male	62583.46	Silver
8700	49	Female	31877.82	Gold
6700	37	Other	20554.34	Platinum
7690	47	Female	76540.52	Bronze
6460	18	Female	105645.95	Gold
6260	58	Female	39928.00	Platinum
2713	52	Other	91572.64	Bronze
3634	36	Female	32941.58	Platinum
6403	52	Other	100193.30	Platinum
7744	65	Female	99734.10	Gold
9117	43	Male	24017.84	Platinum
5722	49	Male	59690.08	Gold
7561	25	Female	56860.18	Bronze
1601	25	Other	47418.97	Bronze
8451	63	Other	78192.01	Bronze
2442	46	Other	21490.25	Silver
6153	66	Male	113810.89	Bronze
5135	67	Male	69776.61	Platinum
6296	28	Female	116324.70	Platinum
2899	36	Female	44050.58	Platinum
7622	57	Male	52364.94	Gold
9431	51	Female	44174.99	Platinum
1018	58	Female	97528.30	Bronze
9889	38	Female	57448.99	Gold
8569	55	Other	98837.67	Platinum
7770	42	Female	88899.91	Bronze
1888	33	Other	26075.79	Bronze
4073	34	Other	70661.19	Platinum
9494	30	Other	90327.42	Gold
6927	45	Male	40374.63	Platinum
9167	41	Other	91802.28	Bronze
8242	68	Other	76072.41	Silver
1845	64	Male	33874.71	Gold
5375	57	Other	32301.67	Platinum
9998	34	Male	64213.42	Silver
3146	24	Other	108687.53	Gold
5719	44	Male	47826.65	Platinum
8178	27	Female	77893.40	Gold
8941	58	Other	61974.46	Bronze
2989	62	Other	34896.48	Silver
1472	67	Male	49856.36	Gold
4920	62	Female	64594.51	Bronze
3594	67	Male	82010.55	Platinum
6091	43	Female	28431.87	Silver
1224	47	Other	78433.89	Bronze
7684	29	Other	27030.96	Silver
2527	35	Other	110769.13	Platinum
2858	50	Other	41222.07	Gold
8560	56	Male	89378.15	Silver
2924	42	Other	72302.78	Silver
3522	28	Male	113935.24	Gold
9165	53	Male	23571.50	Platinum
5781	60	Other	95513.06	Gold
9337	49	Male	64741.73	Platinum
5479	21	Other	20153.56	Platinum
7807	23	Female	89280.90	Gold
8905	63	Other	73064.78	Bronze
8736	33	Other	73763.24	Silver
4993	27	Other	91041.37	Platinum
8483	24	Female	118908.07	Bronze
3369	41	Female	77829.69	Gold
7284	43	Other	76250.22	Bronze
4122	45	Female	106512.50	Gold
9327	46	Female	68820.92	Gold
3236	21	Female	96707.15	Platinum
2143	22	Other	114139.99	Silver
7798	57	Other	23902.09	Bronze
6568	22	Female	26909.20	Bronze
9318	50	Male	86756.31	Silver
5377	47	Male	109339.06	Platinum
1042	25	Male	50016.64	Silver
5634	47	Female	37288.90	Bronze
5891	25	Male	46748.65	Platinum
9022	18	Other	44871.58	Bronze
3434	35	Male	24442.95	Gold
8316	68	Male	115499.08	Bronze
9824	39	Female	82063.44	Bronze
8935	63	Other	41712.98	Silver
6654	57	Female	34268.19	Bronze
6446	54	Female	22164.49	Silver
9903	69	Male	41479.98	Bronze
7180	56	Other	60396.22	Gold
8460	28	Other	85312.96	Gold
6272	63	Male	46402.01	Bronze
4090	20	Female	23522.45	Silver
4912	48	Other	78867.92	Platinum
7274	69	Female	119899.27	Silver
4826	23	Other	54067.54	Platinum
7730	51	Male	97589.71	Silver
1715	56	Other	93356.10	Bronze
6213	53	Other	34700.85	Silver
7246	19	Other	78922.90	Gold
7325	27	Male	41524.31	Platinum
3492	29	Other	89182.38	Bronze
9115	23	Male	71407.70	Platinum
1606	33	Female	32195.08	Bronze
9229	53	Other	43717.69	Gold
6439	55	Other	47856.40	Silver
2644	59	Other	22933.58	Bronze
8213	43	Other	65692.62	Silver
2633	20	Female	50176.82	Gold
9617	38	Female	74122.96	Silver
8486	20	Male	75072.51	Silver
1251	30	Female	41723.29	Silver
3361	37	Female	24190.51	Silver
7717	42	Male	53052.90	Bronze
3529	24	Other	119074.51	Bronze
2225	58	Male	54526.78	Gold
8692	23	Other	98984.34	Silver
6546	33	Other	33201.94	Bronze
7512	36	Female	69407.13	Bronze
2315	23	Other	55812.98	Gold
6383	48	Other	108827.01	Gold
9742	63	Other	74461.33	Platinum
7226	34	Other	90981.25	Platinum
6188	23	Other	71844.41	Bronze
8994	35	Female	119926.42	Gold
9864	44	Other	29681.62	Silver
1588	40	Male	115994.54	Bronze
2121	41	Male	48014.20	Silver
4846	37	Female	75163.28	Bronze
5708	38	Female	90119.10	Platinum
2480	69	Female	85548.66	Gold
8110	29	Male	45827.53	Silver
2646	31	Male	37072.51	Gold
8269	39	Male	37098.80	Silver
3725	41	Female	73724.11	Silver
5906	55	Female	117047.84	Gold
1474	22	Male	45396.80	Gold
1753	44	Female	101666.46	Bronze
6314	68	Female	20831.93	Silver
1919	66	Male	60756.32	Silver
5806	37	Male	115981.27	Platinum
6873	65	Male	29359.02	Gold
7141	57	Other	89654.68	Silver
8056	23	Other	104334.15	Bronze
3385	40	Female	90039.40	Bronze
5000	59	Other	68539.81	Platinum
7751	43	Other	56181.98	Bronze
3950	30	Male	101820.60	Gold
3785	19	Other	74484.84	Platinum
3868	62	Female	100107.94	Platinum
2293	30	Male	111458.12	Gold
4945	30	Male	60724.40	Platinum
9153	32	Male	99364.57	Silver
3344	50	Other	111230.18	Bronze
4804	44	Male	46988.95	Bronze
8555	63	Female	22549.66	Silver
5161	37	Female	27018.71	Bronze
8529	50	Other	86842.40	Bronze
5183	43	Female	101047.22	Platinum
1153	39	Male	35696.91	Bronze
8622	19	Male	83681.21	Platinum
5712	21	Other	90385.55	Silver
9955	46	Other	119141.03	Silver
3588	36	Male	103389.03	Silver
2210	34	Male	30508.93	Gold
8237	31	Male	89065.97	Bronze
6661	38	Female	25277.94	Bronze
5901	29	Other	59722.44	Bronze
7951	69	Other	94014.99	Platinum
5097	38	Male	22297.53	Silver
8484	59	Female	113776.70	Bronze
5949	18	Female	59980.81	Bronze
4263	22	Male	84931.23	Platinum
7302	54	Male	92037.72	Bronze
8916	23	Male	60870.34	Platinum
2747	44	Other	38114.92	Silver
4886	41	Other	57664.94	Silver
7248	32	Female	47124.63	Bronze
5847	34	Other	21855.98	Gold
5837	47	Other	24715.67	Bronze
1359	19	Other	39491.89	Platinum
5497	43	Other	26776.41	Silver
1132	59	Other	23477.41	Bronze
1803	45	Female	79148.40	Bronze
9138	57	Male	48123.72	Platinum
5689	45	Female	41435.97	Platinum
6772	58	Male	94704.12	Bronze
4588	67	Other	119318.06	Gold
4115	61	Female	20422.58	Platinum
5106	48	Male	54403.72	Gold
3240	49	Other	63556.52	Gold
2591	50	Male	73110.14	Silver
1645	58	Male	59057.12	Gold
6061	24	Other	34807.05	Bronze
8222	70	Female	77323.29	Bronze
1546	31	Female	59381.53	Silver
3153	22	Male	112490.45	Platinum
2476	37	Female	37288.64	Bronze
5835	68	Other	47707.83	Platinum
6352	39	Male	119914.10	Bronze
3877	35	Other	98133.61	Silver
4289	35	Female	100377.81	Platinum
3165	53	Other	87494.93	Platinum
6994	35	Other	106145.06	Silver
9697	67	Male	76940.25	Gold
9221	55	Male	23708.12	Gold
5465	22	Female	111444.54	Silver
3695	61	Female	50869.70	Bronze
5210	70	Other	58930.28	Platinum
8894	38	Male	21733.22	Bronze
6549	40	Female	113109.83	Platinum
2886	19	Male	93149.46	Bronze
8673	54	Other	67552.96	Gold
2233	19	Other	77676.50	Silver
3306	60	Other	27617.25	Bronze
4696	34	Male	63634.13	Gold
7511	30	Male	67688.18	Silver
6992	40	Female	48157.11	Silver
2479	65	Other	34816.51	Bronze
7464	66	Other	82694.94	Bronze
1228	22	Female	45424.84	Gold
5332	51	Other	115222.59	Gold
9791	35	Other	29926.15	Silver
3024	20	Female	22473.66	Silver
7038	31	Other	97338.52	Platinum
5295	56	Other	106345.43	Platinum
7242	27	Male	116563.11	Platinum
7086	56	Other	86355.71	Bronze
2775	63	Other	102133.01	Platinum
4830	34	Female	79753.34	Platinum
8724	58	Female	102588.54	Bronze
1410	64	Other	20999.50	Bronze
6374	43	Other	25730.53	Gold
4626	41	Female	71761.54	Platinum
2035	24	Male	42168.64	Bronze
8606	67	Male	76371.95	Bronze
5951	31	Male	37294.52	Bronze
7689	27	Male	31452.88	Bronze
2911	47	Male	94669.47	Silver
3290	23	Female	92721.13	Bronze
1742	21	Other	34297.51	Platinum
1609	20	Female	68946.62	Silver
5986	37	Male	61608.60	Platinum
9071	57	Female	109968.63	Platinum
2902	59	Other	86547.90	Platinum
2592	55	Other	76889.12	Gold
9807	29	Female	32781.54	Platinum
3222	45	Male	89522.32	Bronze
7367	67	Other	99837.09	Gold
8432	67	Female	95975.47	Gold
7078	35	Male	62116.25	Platinum
9850	66	Female	108357.87	Silver
7866	33	Male	24956.18	Bronze
3531	51	Male	22828.13	Silver
2622	66	Male	110569.53	Bronze
9017	48	Female	90582.01	Silver
7686	63	Female	56004.83	Platinum
5583	19	Other	36303.77	Gold
1536	64	Male	31720.10	Bronze
7070	57	Female	42209.32	Platinum
4559	53	Male	48084.25	Platinum
8264	24	Male	103243.89	Platinum
8285	54	Male	90318.68	Silver
4868	69	Other	89357.37	Platinum
6942	28	Other	62892.50	Silver
2627	59	Female	60824.17	Platinum
7018	19	Male	59458.29	Silver
9920	41	Other	80351.72	Gold
6876	21	Female	27949.85	Bronze
1992	56	Female	70060.95	Platinum
7523	24	Male	104069.36	Silver
5520	42	Female	33945.94	Gold
4109	31	Male	112037.59	Silver
3001	33	Other	58566.32	Bronze
8450	54	Other	44100.55	Silver
2501	61	Female	113402.11	Bronze
1349	27	Other	83665.80	Bronze
4990	70	Other	47318.52	Bronze
3063	69	Female	66757.72	Silver
4362	43	Male	109463.60	Silver
4394	38	Male	61857.77	Platinum
4538	55	Other	57868.64	Bronze
4817	32	Female	62207.51	Silver
1046	45	Male	100440.91	Bronze
5542	41	Female	116421.53	Silver
3370	49	Female	91442.39	Gold
3129	65	Other	41974.07	Bronze
3858	25	Other	111689.10	Bronze
2801	62	Male	96440.77	Bronze
1422	56	Other	98457.31	Bronze
3159	28	Other	115521.90	Silver
1243	63	Female	110954.01	Bronze
6869	36	Female	41250.56	Gold
4898	54	Other	50175.64	Gold
6304	65	Male	34181.37	Silver
1258	24	Male	31060.71	Platinum
3854	26	Female	119369.94	Gold
5347	50	Female	45585.23	Platinum
1858	67	Other	55314.30	Silver
3076	65	Female	90174.16	Gold
7897	67	Other	107224.53	Gold
9619	31	Female	48369.45	Silver
2862	18	Female	119799.00	Gold
2041	19	Female	89118.24	Gold
8802	45	Other	33320.59	Platinum
8344	29	Other	50616.43	Bronze
6931	33	Female	29508.51	Platinum
9408	66	Male	21632.22	Platinum
2786	52	Other	77219.41	Silver
8405	25	Male	39164.90	Silver
9254	50	Female	114434.16	Bronze
4629	31	Other	24290.27	Bronze
1710	59	Female	25277.88	Silver
9543	57	Female	104278.78	Platinum
8504	35	Other	81814.91	Platinum
1510	41	Male	76054.82	Silver
1996	25	Male	62246.84	Platinum
8847	44	Male	27554.79	Gold
7580	49	Other	49282.75	Platinum
7984	54	Female	78125.63	Bronze
2768	23	Male	52268.29	Bronze
9032	49	Other	86610.76	Gold
8267	46	Other	73693.00	Bronze
2204	43	Other	42689.98	Bronze
2323	25	Male	61273.82	Platinum
6277	61	Male	40450.52	Platinum
3430	63	Female	65728.27	Silver
2076	54	Other	95174.31	Silver
3067	45	Male	23636.64	Platinum
5505	18	Male	65882.75	Silver
9984	49	Other	73890.86	Platinum
6327	57	Other	96560.72	Bronze
7240	69	Other	29123.81	Gold
9692	23	Female	74292.38	Gold
5831	24	Male	69793.80	Platinum
9282	27	Female	110178.38	Gold
8048	57	Other	53190.16	Gold
2624	27	Female	85787.48	Platinum
4522	32	Female	119894.98	Silver
8046	63	Male	47238.60	Bronze
8398	38	Other	116234.09	Bronze
4743	54	Male	31226.03	Bronze
7779	25	Female	111075.47	Silver
6553	33	Other	117711.53	Platinum
8430	64	Male	23736.66	Platinum
7532	31	Female	92527.49	Platinum
7815	41	Other	80761.38	Gold
2557	31	Other	49833.86	Silver
6120	23	Male	116865.67	Platinum
7992	41	Other	34927.32	Gold
5176	40	Female	86526.85	Bronze
7132	45	Male	76093.83	Gold
3500	28	Female	78570.40	Bronze
8770	63	Male	20257.97	Silver
2099	66	Other	39120.34	Gold
2398	47	Female	34490.55	Silver
8075	26	Other	103636.84	Platinum
2582	63	Male	55987.66	Gold
7105	37	Female	111042.63	Silver
3131	40	Female	55678.59	Platinum
1982	62	Female	81421.58	Gold
6400	58	Male	111317.92	Gold
3002	19	Other	56837.65	Platinum
6793	35	Male	111301.04	Bronze
7929	63	Female	27010.86	Bronze
1842	62	Female	89450.44	Gold
6119	54	Female	59142.20	Platinum
6761	34	Female	52265.31	Gold
9313	35	Female	57907.85	Platinum
4485	68	Female	24606.98	Silver
3535	46	Female	74588.27	Gold
8900	60	Male	30917.48	Gold
4674	49	Other	67039.50	Gold
2773	23	Female	20028.81	Silver
6736	66	Other	32983.52	Silver
7022	45	Male	24422.99	Silver
2882	53	Female	44887.08	Gold
4705	52	Other	40109.30	Silver
8030	60	Other	39976.90	Silver
1430	57	Other	27080.15	Bronze
5381	52	Male	48694.49	Bronze
3955	22	Other	89541.51	Silver
5477	52	Male	82232.71	Gold
6062	59	Other	66974.33	Silver
6567	26	Male	35606.06	Platinum
6751	36	Male	27059.65	Bronze
1100	36	Male	61842.00	Gold
3972	42	Male	27325.84	Bronze
3347	53	Female	103436.07	Bronze
7566	28	Male	118709.11	Bronze
2140	70	Male	32065.64	Silver
3324	24	Male	26319.85	Silver
1502	43	Male	106438.47	Gold
2503	30	Female	105958.23	Bronze
9691	42	Other	109750.85	Gold
4524	26	Other	60841.98	Silver
7163	56	Other	69864.84	Bronze
7878	49	Other	37773.72	Bronze
6585	31	Male	69362.37	Bronze
3578	51	Female	67821.33	Bronze
7062	45	Other	37300.69	Platinum
6105	59	Other	57488.95	Platinum
2391	59	Other	96400.43	Bronze
1861	62	Other	45742.39	Silver
3549	60	Other	24157.92	Silver
1815	59	Female	52576.34	Gold
2336	46	Other	78403.92	Gold
5458	32	Male	59727.24	Bronze
8259	27	Male	66136.68	Bronze
7947	63	Male	28800.68	Bronze
8957	28	Male	86418.97	Platinum
7785	26	Female	40290.62	Bronze
5475	26	Female	106187.17	Silver
4531	34	Other	97843.13	Gold
9394	28	Other	117025.76	Bronze
2864	45	Other	109754.77	Bronze
6655	30	Male	38465.66	Platinum
2816	53	Female	90842.32	Gold
5640	64	Other	58118.85	Platinum
8972	31	Female	89713.87	Platinum
9633	43	Other	32813.74	Platinum
6053	50	Other	80464.81	Platinum
1744	65	Female	116001.59	Silver
4612	23	Other	112207.96	Platinum
7475	28	Male	100545.20	Gold
1897	39	Male	117290.31	Platinum
1125	34	Male	27826.92	Platinum
4349	24	Other	42699.19	Silver
5938	36	Male	47598.35	Bronze
4460	39	Other	106005.42	Platinum
3248	26	Other	21446.70	Silver
5186	51	Other	58402.42	Bronze
5742	67	Male	27687.98	Platinum
6375	49	Other	114708.31	Silver
2965	70	Male	61909.06	Bronze
1126	52	Male	31285.09	Silver
9149	35	Male	33112.06	Platinum
8055	48	Male	54320.97	Bronze
3878	40	Male	118539.21	Bronze
3116	57	Female	47522.37	Platinum
7229	18	Male	75788.79	Gold
9725	35	Other	45778.67	Platinum
9196	47	Female	41986.48	Silver
6802	36	Female	40009.14	Platinum
2180	62	Female	110752.28	Silver
7505	23	Other	22784.45	Gold
1693	46	Male	49622.94	Gold
8147	45	Other	30902.24	Platinum
1307	37	Other	40207.86	Platinum
2275	35	Male	56947.12	Gold
6129	35	Other	41111.38	Platinum
8033	22	Female	89395.26	Silver
7626	18	Other	115216.97	Bronze
7843	40	Female	110850.29	Bronze
5743	47	Other	47531.82	Bronze
2887	55	Other	107102.75	Silver
7636	37	Male	55014.29	Gold
1341	60	Male	70141.31	Gold
6321	64	Male	87363.69	Silver
3815	20	Other	64835.86	Gold
8538	42	Male	54983.64	Platinum
6928	62	Other	56752.04	Platinum
2443	38	Male	34195.73	Gold
8155	29	Male	115860.16	Gold
2734	66	Female	46091.01	Platinum
8138	31	Female	70626.53	Gold
7560	29	Other	75857.96	Silver
9584	55	Female	117056.62	Bronze
2288	33	Other	110754.30	Silver
6083	26	Other	28821.96	Bronze
6562	35	Male	39872.36	Gold
6456	35	Other	54036.48	Bronze
3754	60	Male	72118.11	Silver
2251	52	Male	80977.73	Platinum
9363	66	Male	112250.91	Silver
2868	32	Other	20453.19	Silver
9693	35	Male	101200.80	Silver
9355	64	Other	24191.21	Silver
4176	41	Male	93764.33	Bronze
6724	25	Other	26183.64	Gold
6752	54	Other	106572.73	Platinum
3419	55	Male	76562.16	Bronze
4871	41	Male	115572.02	Gold
3399	18	Male	51375.89	Platinum
5193	66	Male	117828.34	Gold
4232	53	Female	44832.42	Bronze
3842	59	Other	62607.91	Platinum
2234	56	Other	29782.30	Gold
3902	46	Male	112252.91	Bronze
9095	48	Other	95637.93	Bronze
8601	38	Female	94039.94	Platinum
8354	69	Male	94861.68	Platinum
6295	34	Female	88984.92	Bronze
6179	49	Other	59652.67	Platinum
3473	26	Male	40425.66	Bronze
8205	63	Female	77735.33	Gold
2118	52	Female	53402.72	Bronze
8682	68	Other	68938.73	Gold
5961	65	Male	27944.92	Platinum
5500	38	Other	28350.75	Platinum
1920	60	Female	39685.79	Bronze
6766	46	Female	91064.78	Bronze
9312	19	Female	80789.62	Gold
2215	45	Male	99856.83	Silver
8565	29	Other	81799.66	Gold
8404	40	Female	77003.53	Bronze
1616	68	Other	36118.40	Platinum
1932	63	Male	64493.60	Silver
7041	18	Other	37018.16	Platinum
5703	24	Male	102663.87	Bronze
2257	63	Other	97223.21	Silver
9307	29	Male	73259.38	Bronze
7299	29	Female	71122.92	Gold
8581	19	Other	96845.33	Bronze
8368	30	Other	56795.10	Silver
4084	60	Female	82492.13	Silver
6267	46	Other	100787.55	Silver
8792	46	Male	21373.89	Silver
9214	25	Other	25376.01	Platinum
2013	57	Male	66465.67	Bronze
2695	53	Male	66478.66	Bronze
6626	48	Other	21864.43	Bronze
2381	28	Other	48058.09	Bronze
9266	36	Female	27866.21	Silver
3827	51	Other	43974.49	Bronze
1641	34	Other	69956.37	Platinum
5059	55	Other	117563.26	Silver
8199	45	Female	104665.25	Platinum
9586	25	Other	99394.61	Bronze
9564	40	Other	46813.78	Platinum
3600	29	Other	94606.93	Platinum
6962	51	Other	112964.49	Bronze
7108	66	Male	43178.88	Platinum
7347	61	Other	24441.32	Platinum
7697	33	Male	74630.10	Bronze
6543	18	Male	51227.24	Platinum
1857	38	Male	95771.21	Silver
6482	66	Male	44778.03	Platinum
2079	45	Other	99942.45	Platinum
6401	53	Other	86641.19	Platinum
2548	26	Other	101637.14	Bronze
7333	64	Other	99759.91	Gold
5655	21	Other	58937.76	Bronze
5128	53	Male	59202.32	Platinum
3463	21	Male	34496.88	Silver
6461	50	Female	62227.57	Platinum
2335	29	Male	74279.11	Gold
3317	19	Male	34761.39	Platinum
6731	64	Male	82018.61	Bronze
6082	48	Other	79956.67	Bronze
7421	59	Male	78527.19	Platinum
3112	50	Other	67025.72	Silver
2388	18	Other	89830.71	Silver
6072	56	Female	70229.62	Bronze
7171	50	Female	85724.15	Silver
6381	50	Other	47861.03	Platinum
3093	29	Female	99031.74	Bronze
9624	28	Other	100468.17	Silver
2531	20	Male	61962.84	Bronze
7937	55	Male	87987.34	Gold
9331	70	Male	100566.94	Bronze
1298	40	Female	86376.28	Bronze
6940	29	Female	84903.41	Platinum
6060	58	Male	103887.99	Silver
3953	25	Male	74248.81	Platinum
4509	18	Other	70438.98	Silver
6598	59	Other	102546.92	Bronze
8967	63	Male	56059.41	Platinum
4145	69	Female	38297.35	Platinum
4711	55	Female	79743.54	Silver
3253	35	Female	79712.47	Gold
3538	67	Male	51057.03	Silver
2264	27	Female	71623.02	Gold
5846	30	Male	101973.38	Silver
2657	58	Female	37658.24	Platinum
9843	61	Male	49483.93	Platinum
9626	34	Female	117104.96	Bronze
1618	49	Other	48461.67	Platinum
6517	54	Female	103421.10	Gold
3147	23	Male	109308.47	Bronze
7172	31	Female	66060.61	Gold
3527	21	Other	32493.55	Gold
3658	64	Female	93315.44	Gold
3962	28	Other	54761.89	Bronze
3712	49	Female	28065.84	Silver
8170	67	Female	83405.65	Bronze
7731	26	Female	78735.48	Bronze
6968	55	Male	31065.43	Silver
4891	55	Male	92357.68	Platinum
8277	18	Male	59926.36	Platinum
5668	28	Other	51021.52	Silver
8355	38	Male	64542.26	Platinum
4833	23	Other	36078.88	Bronze
9749	19	Other	29646.55	Bronze
4918	18	Other	74238.06	Gold
6070	68	Male	119739.94	Gold
8684	61	Male	106284.27	Platinum
4178	28	Male	24337.01	Platinum
7026	28	Other	97341.42	Bronze
8218	48	Male	99734.87	Gold
7256	69	Male	75659.11	Bronze
9239	26	Other	116792.59	Silver
9641	41	Male	28802.80	Gold
7859	47	Male	79152.28	Silver
3655	54	Female	57700.75	Silver
4271	68	Other	67178.08	Bronze
5096	50	Other	71200.24	Silver
1854	51	Other	74603.13	Platinum
8873	33	Female	88270.15	Platinum
7081	39	Other	71614.41	Gold
9452	57	Male	111513.83	Bronze
3042	62	Male	37060.91	Gold
5670	69	Female	64217.07	Bronze
2374	65	Male	31724.99	Bronze
3626	60	Male	100661.66	Silver
5469	34	Other	104615.57	Platinum
8361	31	Other	46463.25	Bronze
9410	28	Male	52596.94	Bronze
8167	68	Male	117636.02	Silver
2502	20	Female	112626.92	Silver
4637	32	Male	106704.37	Platinum
8391	29	Female	80784.93	Platinum
6727	28	Other	57257.27	Gold
1436	37	Other	36117.95	Platinum
1872	53	Male	87429.94	Silver
7495	18	Male	67740.06	Silver
9224	59	Male	50580.22	Platinum
4862	48	Male	111169.34	Platinum
7326	59	Female	101079.71	Silver
2337	20	Other	112972.89	Silver
7142	18	Female	115789.41	Platinum
4678	32	Female	95047.76	Gold
1461	48	Male	94367.75	Silver
6221	67	Other	59153.64	Platinum
2623	52	Female	32413.70	Platinum
6493	24	Female	70370.71	Platinum
3392	49	Female	98355.71	Platinum
3254	24	Other	66929.92	Silver
1627	68	Other	50306.23	Bronze
8740	21	Female	36403.71	Gold
3273	42	Male	106338.57	Silver
8685	52	Other	96366.51	Silver
8349	38	Female	85591.15	Gold
1086	27	Female	36308.37	Silver
2298	36	Other	22262.17	Platinum
1311	42	Other	98611.93	Gold
4533	50	Other	93272.35	Gold
3449	50	Male	33730.06	Bronze
9991	53	Other	112780.26	Platinum
9647	68	Female	41899.53	Bronze
7934	55	Male	105708.10	Platinum
2821	41	Other	56812.89	Silver
4893	54	Female	44023.90	Platinum
5934	28	Male	97054.60	Platinum
2996	61	Other	81712.36	Gold
1782	21	Female	85846.50	Platinum
4906	52	Female	118650.72	Gold
8489	25	Other	53104.94	Bronze
2029	40	Other	82244.67	Gold
9189	67	Male	110024.00	Gold
9782	29	Male	115869.57	Bronze
1269	26	Other	83399.01	Silver
9443	59	Female	90214.92	Bronze
4963	50	Male	57432.63	Bronze
3352	44	Male	46463.46	Platinum
5772	42	Other	56602.58	Platinum
8032	20	Male	70642.48	Platinum
1025	19	Other	66590.06	Bronze
6780	54	Other	43296.51	Silver
4941	55	Male	96539.24	Platinum
7825	57	Female	79535.21	Silver
4068	63	Other	99009.14	Gold
9576	62	Male	86661.22	Bronze
6908	36	Male	71282.90	Silver
2108	54	Male	71742.77	Gold
9618	35	Female	51436.62	Platinum
9914	25	Female	113090.01	Bronze
9316	67	Male	36950.02	Bronze
7397	25	Female	63887.64	Bronze
8702	41	Other	98670.89	Platinum
1713	55	Male	38204.25	Bronze
7338	21	Female	83069.72	Bronze
7116	33	Male	99322.55	Platinum
5155	43	Female	48347.27	Gold
1266	36	Male	76030.34	Gold
6850	50	Other	51966.40	Bronze
2106	64	Other	51434.60	Silver
6649	49	Male	48488.46	Platinum
4950	33	Male	35774.67	Silver
2698	48	Female	23803.98	Silver
6447	26	Other	49442.95	Platinum
3185	62	Female	117726.71	Silver
1726	40	Male	92510.55	Silver
9945	61	Female	37778.95	Gold
8840	19	Female	80040.38	Silver
3986	66	Male	85684.88	Silver
3209	24	Other	108037.43	Silver
2033	27	Female	76322.87	Platinum
8498	38	Other	64793.24	Bronze
1605	56	Other	44846.93	Silver
5807	54	Other	56606.25	Platinum
4302	45	Other	106518.88	Gold
1717	50	Female	43570.24	Platinum
4268	35	Other	22860.09	Silver
1686	51	Male	83187.55	Gold
6170	62	Female	94637.31	Bronze
6080	31	Other	34611.88	Platinum
9444	35	Male	25116.12	Silver
7524	66	Female	82641.34	Platinum
9897	32	Male	64043.45	Gold
8756	62	Male	80841.65	Gold
5150	26	Female	105949.73	Gold
1599	54	Female	55384.81	Platinum
4131	61	Male	119097.36	Bronze
5687	62	Male	107529.85	Silver
6848	46	Other	67699.68	Silver
1783	52	Female	63017.13	Bronze
6438	60	Other	33256.97	Platinum
5476	45	Other	108388.00	Bronze
3039	58	Female	84913.06	Bronze
7029	49	Female	31940.01	Gold
8159	22	Male	105366.25	Platinum
7553	39	Female	32626.13	Gold
8204	37	Male	107560.39	Bronze
7334	60	Male	89072.52	Bronze
6554	29	Male	83530.66	Platinum
4060	69	Other	103779.48	Platinum
9129	70	Other	46994.89	Gold
9151	64	Female	75750.43	Bronze
9507	54	Male	69682.22	Platinum
5369	62	Male	101657.74	Platinum
2353	66	Male	25090.61	Gold
7955	39	Other	84294.83	Silver
3956	56	Other	115578.48	Platinum
9937	66	Other	71651.44	Gold
5813	38	Male	86782.53	Bronze
6262	69	Male	25390.34	Gold
2311	23	Male	71135.97	Bronze
6372	68	Male	102780.80	Platinum
5843	55	Male	88083.48	Gold
6021	37	Female	53357.19	Platinum
7981	60	Female	110786.61	Gold
3730	59	Male	21985.94	Gold
8272	49	Male	42638.00	Platinum
6759	21	Male	96491.34	Silver
8325	20	Male	73142.86	Silver
6776	23	Female	53200.05	Gold
8126	56	Other	52576.67	Bronze
5498	69	Male	38638.88	Platinum
1939	23	Male	71423.81	Gold
7655	59	Male	93382.10	Gold
6952	63	Female	64611.79	Bronze
9406	65	Male	66214.08	Gold
3339	41	Other	44590.56	Gold
1570	32	Other	20005.34	Gold
2101	70	Female	76087.64	Bronze
4866	32	Male	99598.51	Platinum
7001	40	Other	37258.08	Bronze
6933	57	Other	72813.79	Bronze
7272	27	Male	22805.24	Silver
1530	25	Male	43560.38	Silver
3513	58	Other	28874.50	Silver
8371	48	Female	28641.39	Platinum
7077	29	Male	78826.01	Gold
7095	30	Female	87152.61	Platinum
8273	35	Male	89254.15	Platinum
2259	18	Female	64490.06	Silver
3255	39	Male	53869.54	Platinum
9674	66	Female	104496.07	Platinum
7012	58	Male	118839.56	Silver
7521	23	Female	80382.42	Gold
6150	41	Female	24972.97	Silver
5566	38	Male	46734.96	Gold
5089	52	Other	86098.25	Bronze
1424	52	Other	100184.73	Bronze
4048	59	Male	89215.56	Gold
9176	45	Other	86000.93	Bronze
9482	44	Other	27179.06	Platinum
7340	33	Other	37363.05	Gold
2929	70	Other	52035.22	Platinum
5288	25	Other	99981.59	Bronze
5264	60	Male	116814.44	Gold
8311	59	Female	30637.71	Platinum
4515	35	Female	52485.78	Silver
5678	60	Other	104639.80	Bronze
9047	32	Female	82594.87	Bronze
4279	52	Female	38238.24	Silver
3009	47	Other	107984.29	Platinum
8406	25	Female	114761.84	Platinum
3828	22	Other	76014.07	Gold
8292	39	Female	87956.75	Bronze
2438	37	Other	38450.52	Silver
6236	27	Male	31354.75	Silver
6692	25	Male	75246.30	Platinum
2063	25	Male	31452.15	Platinum
9882	62	Male	112461.22	Platinum
5757	51	Female	109379.69	Bronze
5914	66	Male	117436.52	Gold
3580	50	Male	109431.24	Gold
3852	57	Male	79451.31	Gold
6922	69	Other	39057.14	Platinum
9335	39	Other	27456.46	Bronze
4292	56	Other	83554.29	Bronze
3275	63	Male	103910.27	Silver
9094	57	Male	100382.15	Gold
7044	63	Other	106664.78	Platinum
3126	38	Male	99213.56	Silver
2412	60	Female	25477.35	Gold
2077	55	Male	101466.31	Gold
8842	48	Other	99761.30	Gold
9612	31	Male	68023.82	Silver
7708	43	Other	94175.60	Bronze
2208	59	Other	41685.51	Silver
3053	42	Male	105785.70	Bronze
6194	45	Other	96727.71	Bronze
8372	53	Other	66753.56	Bronze
8632	25	Other	85727.66	Silver
9476	35	Female	76067.34	Gold
6644	32	Other	26153.55	Gold
3102	23	Male	96262.66	Silver
3981	31	Other	62799.21	Gold
3114	68	Other	112956.53	Silver
8088	46	Female	91690.26	Silver
1907	19	Female	61977.67	Bronze
3034	66	Male	22797.70	Silver
9488	65	Male	29549.08	Platinum
3507	18	Male	74039.41	Platinum
3653	54	Other	22199.63	Bronze
6286	52	Male	89774.37	Platinum
4694	21	Other	29725.57	Gold
6669	25	Other	49391.79	Platinum
9501	70	Female	48045.13	Platinum
5653	24	Other	65433.68	Bronze
2292	18	Female	22028.01	Bronze
5105	44	Female	40214.12	Silver
4216	33	Female	71615.75	Gold
5496	53	Other	76515.47	Gold
3050	28	Female	95471.01	Bronze
9740	35	Male	42512.13	Bronze
9234	33	Male	93867.67	Silver
3762	28	Male	106420.54	Bronze
3526	42	Other	63324.71	Bronze
3804	40	Other	55091.22	Gold
6531	67	Male	86954.88	Bronze
1674	34	Female	35630.36	Silver
1464	54	Male	49030.57	Platinum
5336	38	Female	113154.68	Gold
4453	23	Female	27892.24	Gold
1496	50	Other	102363.95	Platinum
9159	56	Other	30398.40	Platinum
5745	60	Male	74916.44	Gold
8912	25	Other	102193.95	Bronze
5873	49	Male	52794.29	Silver
2195	59	Other	67172.17	Platinum
1981	60	Female	73679.23	Gold
3589	39	Female	104954.22	Platinum
8202	38	Female	92610.17	Bronze
7809	22	Male	115045.10	Bronze
8609	56	Male	70060.18	Gold
4342	25	Other	52385.41	Silver
3353	36	Other	112591.09	Bronze
6121	33	Male	116927.16	Gold
6231	43	Female	119323.13	Bronze
6658	55	Female	46837.66	Gold
3142	68	Other	71072.75	Platinum
9437	59	Male	63907.63	Bronze
2739	31	Male	116081.65	Silver
6228	35	Other	105207.03	Platinum
4960	41	Female	107815.95	Silver
8642	56	Male	81950.92	Bronze
3007	63	Other	69164.62	Bronze
5382	34	Female	86588.70	Silver
8366	52	Other	62895.27	Silver
3308	31	Male	38042.74	Bronze
2586	19	Female	83213.95	Gold
1829	36	Male	79437.74	Gold
5754	57	Male	45289.50	Platinum
7293	35	Female	45677.17	Silver
7850	21	Female	100419.28	Platinum
5067	51	Male	84826.54	Platinum
3616	20	Other	117639.61	Bronze
6364	56	Other	45500.15	Silver
6123	22	Female	41766.64	Gold
4110	20	Other	66289.50	Gold
3610	18	Male	89485.35	Gold
9163	44	Male	50893.83	Gold
9433	55	Other	65457.13	Platinum
8648	38	Male	103079.12	Gold
9171	43	Other	46223.18	Silver
6055	57	Other	79608.79	Platinum
9148	52	Other	91950.23	Gold
1379	23	Male	93515.39	Platinum
2475	56	Male	36863.64	Bronze
7442	52	Female	95031.95	Bronze
9281	62	Male	25835.14	Gold
4944	30	Other	67429.42	Silver
6781	23	Other	98433.91	Gold
1797	43	Female	85562.33	Silver
5609	55	Male	112066.37	Bronze
9108	66	Male	23161.77	Bronze
8710	28	Female	119886.90	Bronze
9793	69	Male	75615.91	Bronze
1133	42	Other	21309.34	Platinum
2761	36	Male	27506.20	Silver
8060	19	Other	27625.62	Silver
3194	66	Female	44992.81	Gold
7606	63	Male	26733.29	Silver
6995	21	Female	71068.34	Platinum
1741	46	Female	98509.16	Bronze
7563	40	Male	109519.01	Gold
1838	18	Other	91184.50	Bronze
4189	39	Female	73968.21	Bronze
6939	54	Male	89507.31	Bronze
7329	54	Male	25502.48	Gold
9261	19	Female	31081.14	Silver
8378	59	Male	48488.57	Bronze
5582	45	Other	20326.81	Silver
2946	35	Other	85464.07	Bronze
3108	19	Male	46768.88	Platinum
7453	25	Male	45301.86	Bronze
7114	21	Female	51592.52	Bronze
6555	42	Other	107711.05	Platinum
6990	46	Male	97468.08	Platinum
3363	25	Female	104306.51	Gold
4261	21	Other	33414.45	Platinum
9341	54	Female	60594.02	Bronze
7576	24	Other	33387.30	Gold
9193	46	Male	117323.52	Gold
1637	41	Female	88029.12	Silver
3245	24	Male	53181.72	Silver
8761	69	Male	28650.35	Platinum
9508	69	Male	76826.52	Platinum
8487	38	Male	56226.48	Gold
3440	56	Other	88626.79	Platinum
9446	28	Female	98619.59	Bronze
6373	52	Female	109839.27	Gold
6218	42	Male	72533.80	Platinum
7438	31	Other	27085.57	Bronze
5902	64	Other	54143.21	Gold
9311	36	Female	100553.04	Bronze
9351	55	Other	37262.33	Gold
9721	35	Female	107794.84	Bronze
9025	40	Other	21094.88	Gold
5911	62	Other	20015.78	Platinum
8780	40	Other	73311.68	Bronze
1272	63	Female	71238.43	Silver
7035	52	Male	94867.84	Silver
6427	30	Male	85274.51	Platinum
2795	56	Female	111878.36	Platinum
7824	30	Male	84215.30	Silver
6040	23	Other	49837.56	Gold
8775	41	Other	50830.10	Bronze
5350	64	Male	65785.16	Silver
8871	64	Female	70707.27	Silver
3793	63	Female	52593.30	Bronze
9589	39	Male	115141.06	Platinum
3421	54	Other	116461.42	Silver
4968	33	Female	88485.48	Silver
1517	34	Other	27818.29	Bronze
2800	47	Male	95539.99	Silver
4125	50	Other	76369.02	Gold
1310	24	Other	55501.39	Platinum
8225	68	Other	73629.23	Platinum
7861	67	Male	24490.47	Platinum
3481	44	Female	113132.47	Platinum
7765	51	Other	40081.96	Platinum
4340	53	Male	66343.97	Bronze
7723	50	Other	106167.98	Platinum
8726	25	Female	105114.21	Bronze
3262	48	Female	118091.83	Bronze
9498	58	Other	92226.02	Bronze
4397	69	Other	43684.45	Bronze
8837	65	Female	65130.69	Silver
9609	53	Other	28840.43	Platinum
7173	42	Other	20935.32	Platinum
6140	63	Female	37000.15	Silver
3837	58	Other	103336.34	Silver
8531	60	Other	89035.05	Gold
9734	33	Male	39319.84	Gold
6608	29	Other	65459.63	Gold
9950	21	Other	85930.72	Bronze
5331	56	Male	78052.98	Platinum
8932	47	Female	40842.23	Bronze
5038	58	Male	51368.55	Gold
5571	70	Female	89462.67	Silver
5890	31	Other	54695.10	Gold
4684	19	Other	26802.48	Bronze
5876	49	Female	49564.78	Platinum
5735	58	Male	47408.20	Bronze
4396	67	Female	86431.49	Bronze
9011	51	Female	69488.05	Bronze
8861	47	Male	63158.09	Gold
6714	65	Other	105054.92	Platinum
5480	45	Other	33434.87	Bronze
5715	26	Male	78764.20	Gold
9899	63	Female	101252.86	Silver
7220	29	Male	113628.86	Gold
5758	52	Other	116839.82	Gold
1689	25	Male	34445.04	Platinum
2294	59	Other	94845.62	Bronze
6674	65	Other	24697.08	Platinum
8247	63	Other	57778.14	Silver
5201	57	Male	97257.43	Platinum
8849	59	Other	88166.43	Gold
4310	28	Other	117952.25	Silver
5442	46	Female	56348.11	Silver
5450	47	Female	51812.62	Platinum
3249	44	Male	85828.08	Silver
2789	24	Male	88689.42	Gold
4972	24	Female	97031.57	Bronze
1831	52	Male	45175.20	Gold
9700	19	Male	56854.56	Silver
1860	35	Male	60628.88	Gold
2641	37	Male	91613.92	Bronze
7771	26	Other	60647.19	Platinum
6411	34	Male	91526.42	Gold
8739	42	Male	33097.97	Bronze
3252	45	Male	47122.09	Gold
1084	68	Other	59234.14	Silver
3587	62	Male	23010.36	Silver
7666	68	Other	101870.34	Bronze
8793	19	Male	68585.39	Gold
8822	21	Male	20757.96	Gold
4267	34	Other	74783.33	Bronze
5706	60	Male	66955.02	Platinum
5676	69	Male	99564.87	Gold
1969	40	Other	103914.15	Bronze
2465	56	Female	40929.25	Gold
9767	44	Female	65572.78	Platinum
1611	38	Female	117582.91	Silver
7846	23	Other	105237.92	Silver
3880	29	Female	94014.17	Gold
1595	39	Other	101623.58	Platinum
7504	34	Female	101588.36	Silver
9116	37	Male	37988.41	Silver
4052	40	Male	58444.08	Bronze
1613	37	Male	72245.85	Silver
1151	69	Female	96831.36	Silver
5888	46	Other	38131.53	Gold
2758	54	Female	42885.27	Bronze
6489	60	Other	36910.89	Bronze
5662	69	Other	76377.68	Platinum
8444	40	Female	25873.16	Platinum
9901	23	Male	100801.74	Bronze
9590	56	Male	37013.25	Gold
9092	43	Female	74216.72	Gold
3198	22	Male	93830.06	Silver
5470	57	Other	20298.93	Silver
4159	19	Female	85434.62	Bronze
2845	22	Female	91570.95	Platinum
6417	60	Female	86086.37	Gold
8518	34	Other	72709.55	Bronze
5215	19	Male	53181.20	Bronze
4050	62	Male	70636.41	Gold
1230	55	Other	80538.29	Silver
6523	19	Male	98334.47	Bronze
5833	39	Other	43921.87	Silver
3875	59	Other	82349.25	Silver
7643	37	Other	87124.43	Platinum
9442	54	Female	42944.60	Platinum
2421	28	Male	112115.99	Platinum
7567	59	Female	49734.20	Silver
2562	65	Other	29495.13	Gold
4027	41	Male	80499.67	Gold
3303	27	Other	119561.19	Bronze
6301	44	Other	89112.02	Bronze
5064	40	Other	97894.42	Bronze
1111	33	Other	61629.92	Silver
4858	57	Male	48321.41	Silver
8319	47	Male	61469.38	Gold
5947	69	Female	50922.81	Silver
1187	65	Female	96587.76	Silver
5285	31	Male	114356.28	Bronze
6890	68	Female	49119.05	Platinum
2017	68	Female	60472.51	Platinum
2936	61	Male	41572.86	Platinum
8625	21	Other	62479.24	Gold
6026	47	Female	86015.20	Gold
7642	42	Other	58658.78	Platinum
9233	65	Female	95381.36	Platinum
6095	43	Male	104332.73	Bronze
2923	49	Other	68691.06	Platinum
7021	62	Other	42075.41	Silver
4618	27	Female	64063.24	Silver
4590	34	Male	21586.94	Gold
3188	59	Male	117645.84	Platinum
8834	37	Male	108269.47	Silver
3509	29	Male	46576.12	Gold
7121	33	Other	33268.29	Platinum
7813	24	Male	110974.43	Bronze
8714	38	Male	107363.08	Bronze
9806	48	Female	59465.57	Silver
4578	55	Male	57490.57	Bronze
5054	55	Female	87423.21	Bronze
9653	40	Male	52596.56	Silver
2279	53	Other	20643.52	Gold
2838	22	Female	33176.85	Gold
2011	24	Male	75916.41	Gold
9972	26	Male	78150.22	Bronze
4312	41	Female	25213.07	Silver
9792	66	Female	108022.75	Platinum
3455	21	Other	70206.81	Gold
9525	46	Male	35036.64	Gold
2904	32	Female	52950.54	Gold
4365	45	Other	21782.53	Silver
9008	32	Male	95506.51	Silver
9361	20	Male	64467.60	Gold
8298	61	Other	66193.30	Silver
1911	69	Other	35152.24	Silver
8429	57	Male	103459.29	Platinum
3161	44	Male	62370.00	Bronze
9409	65	Male	119322.48	Silver
7806	50	Other	59152.56	Bronze
1945	24	Other	47888.04	Gold
8575	54	Female	51510.47	Gold
6049	26	Other	106080.55	Bronze
1356	27	Female	89642.06	Bronze
7487	47	Other	98665.91	Gold
5169	25	Other	117379.03	Platinum
1049	66	Other	28932.64	Silver
4570	67	Male	52474.30	Platinum
2196	44	Female	23580.21	Silver
7941	28	Other	98862.68	Gold
2044	56	Female	47103.34	Silver
9866	59	Male	26740.74	Bronze
1987	32	Other	49121.03	Silver
2130	40	Other	58887.86	Bronze
8734	29	Other	26752.74	Platinum
1519	44	Other	109653.13	Platinum
7698	23	Female	78454.94	Gold
3948	47	Male	115913.29	Bronze
3218	58	Female	34298.22	Bronze
7887	46	Other	26516.26	Silver
7135	29	Female	80282.47	Platinum
7266	44	Other	105238.35	Platinum
8348	39	Male	34176.19	Bronze
7184	39	Other	29274.07	Bronze
7154	50	Other	32258.88	Platinum
2314	22	Female	61895.09	Silver
3178	26	Female	78503.73	Gold
6697	68	Female	70514.20	Bronze
2943	45	Male	105808.85	Gold
3924	24	Other	91335.42	Platinum
9802	30	Other	100014.66	Gold
7439	39	Male	34031.77	Gold
9664	59	Other	22709.80	Bronze
3086	68	Male	26769.83	Bronze
4648	34	Male	63702.85	Bronze
1056	26	Female	74127.57	Gold
1372	70	Male	107648.77	Gold
8585	18	Male	66260.37	Bronze
7948	60	Other	33407.46	Silver
9715	53	Female	52614.56	Silver
7214	26	Female	29159.98	Platinum
4762	31	Male	78502.22	Gold
5055	30	Male	60804.35	Silver
8546	59	Male	45365.65	Silver
6671	67	Female	108133.56	Silver
3541	26	Female	42811.85	Platinum
5516	59	Female	104310.57	Silver
4088	58	Male	50370.19	Gold
2848	21	Other	116833.34	Gold
1527	21	Male	44177.42	Gold
1256	38	Male	34360.67	Silver
4943	61	Male	57199.42	Silver
4376	32	Female	112010.94	Gold
2102	20	Female	76710.89	Platinum
2653	35	Female	86820.32	Platinum
1550	64	Other	44575.07	Gold
8314	43	Female	94748.67	Gold
5009	64	Female	106327.84	Silver
1724	37	Other	43956.98	Silver
7590	19	Other	54359.93	Gold
8191	67	Male	98807.68	Silver
4839	47	Female	28027.85	Platinum
1924	67	Female	36528.85	Silver
3295	63	Female	48212.75	Silver
9255	68	Female	48075.03	Platinum
5739	41	Other	62852.77	Platinum
4836	32	Male	29235.10	Bronze
6224	32	Other	103933.06	Platinum
6253	25	Male	23492.50	Gold
4881	66	Other	116888.12	Gold
5944	22	Female	111139.32	Silver
4621	36	Male	94330.29	Gold
7775	62	Male	105712.11	Gold
5923	50	Other	99296.46	Gold
5508	32	Other	29156.49	Platinum
3869	44	Other	91565.80	Platinum
7999	29	Female	77392.77	Bronze
9120	65	Female	74196.35	Gold
1768	53	Female	52422.93	Gold
6642	47	Male	119745.46	Silver
7244	39	Other	119088.84	Gold
9592	30	Other	97357.34	Gold
6222	61	Female	49893.93	Gold
7821	24	Other	21733.16	Gold
7688	67	Male	27685.09	Bronze
5913	34	Female	67958.09	Silver
7167	52	Male	56308.60	Gold
4012	33	Other	25692.21	Platinum
9813	33	Male	42720.29	Platinum
4948	36	Male	95228.15	Gold
4692	54	Female	40280.08	Gold
5927	27	Female	84614.95	Gold
3365	25	Female	37680.36	Silver
8586	40	Other	26560.24	Bronze
1944	27	Female	36605.96	Bronze
7761	70	Female	86063.15	Bronze
9683	55	Female	58719.43	Bronze
3196	44	Female	29750.68	Silver
7363	34	Other	114312.63	Silver
5177	51	Other	80299.65	Silver
4331	47	Male	27953.76	Bronze
2295	22	Male	52787.04	Bronze
8369	42	Female	91397.59	Platinum
7079	42	Female	26676.30	Platinum
2514	30	Male	28072.36	Silver
9775	59	Male	85245.93	Gold
4120	57	Female	82507.57	Bronze
1844	31	Other	44013.32	Platinum
5398	63	Male	100496.23	Silver
7179	21	Female	74631.56	Bronze
1647	31	Female	40681.97	Bronze
2192	26	Male	24511.51	Silver
4082	28	Female	58630.80	Silver
4555	24	Male	99648.02	Silver
8854	45	Female	84988.23	Bronze
4422	66	Male	101676.02	Silver
6455	53	Male	99919.19	Platinum
5967	63	Male	78938.40	Gold
4113	20	Male	55867.78	Bronze
2922	47	Male	66106.93	Bronze
8846	18	Female	66803.80	Platinum
4974	24	Male	116934.84	Gold
4350	50	Other	56749.81	Platinum
4921	23	Other	94381.42	Bronze
6269	62	Female	113207.52	Gold
5637	70	Other	111671.40	Gold
7236	39	Male	84344.29	Gold
8639	39	Male	22163.58	Bronze
9743	49	Female	79029.68	Gold
6886	34	Male	50802.19	Silver
6892	61	Male	116843.47	Platinum
9401	23	Male	53750.66	Platinum
9147	26	Male	119043.65	Platinum
8635	69	Male	94426.34	Gold
2615	66	Male	39303.79	Bronze
6246	24	Female	78440.14	Silver
4328	29	Female	89414.81	Silver
7073	24	Other	39332.60	Platinum
6126	52	Female	43663.54	Silver
7781	52	Female	22331.98	Silver
1749	30	Female	79322.20	Silver
4625	62	Female	106448.90	Silver
3390	30	Female	117482.05	Silver
1265	36	Other	93194.81	Platinum
7841	59	Other	91409.52	Platinum
5836	22	Male	33513.56	Gold
3497	48	Female	57447.62	Gold
4214	54	Female	49035.26	Gold
6404	63	Female	106594.26	Platinum
4768	22	Male	90645.02	Gold
7223	55	Female	100923.95	Silver
5026	37	Male	36906.93	Bronze
9180	35	Male	54112.33	Gold
6530	62	Female	106671.54	Gold
5216	63	Male	27109.14	Gold
9037	58	Male	43505.25	Platinum
8550	41	Female	59203.91	Silver
3756	48	Male	40264.75	Silver
6770	45	Male	55112.19	Gold
3773	65	Other	51529.78	Platinum
3293	42	Other	97419.64	Bronze
9954	55	Female	105676.37	Platinum
9000	66	Female	43519.43	Silver
4015	63	Male	93452.52	Bronze
1962	27	Male	41355.87	Platinum
1554	30	Other	29953.96	Platinum
2217	44	Male	109604.69	Silver
1794	46	Female	110099.32	Gold
1104	24	Other	30789.11	Silver
7756	24	Other	32384.62	Silver
4791	25	Female	44412.72	Bronze
3474	26	Female	40663.51	Platinum
1149	20	Other	118527.18	Silver
4583	32	Male	103085.74	Platinum
9285	37	Female	66937.36	Silver
8471	41	Male	88817.86	Gold
1990	48	Other	38040.96	Platinum
8993	35	Female	114525.31	Bronze
1257	25	Male	94127.25	Silver
1108	58	Male	57043.18	Bronze
9719	46	Other	83208.14	Bronze
7739	39	Female	94004.22	Gold
1194	42	Female	35183.50	Bronze
1274	40	Male	101360.42	Platinum
9673	69	Other	27659.72	Gold
5501	57	Female	71655.90	Silver
9777	64	Male	22996.42	Silver
5697	29	Female	77239.71	Silver
1280	31	Female	41604.12	Platinum
9228	18	Male	93085.04	Silver
8054	21	Other	70737.20	Gold
3937	26	Other	78475.08	Gold
2578	36	Other	41894.39	Bronze
9591	29	Male	24670.88	Platinum
3439	26	Female	85258.10	Gold
4144	46	Female	71627.27	Platinum
9625	23	Male	84916.71	Silver
6807	42	Male	84483.43	Bronze
5379	37	Female	76225.99	Gold
7502	32	Male	119206.60	Silver
7112	60	Male	112866.98	Platinum
7652	64	Female	36172.25	Platinum
8520	30	Female	105841.97	Platinum
4984	65	Female	102271.62	Platinum
4700	69	Male	71016.06	Bronze
7640	56	Other	83583.49	Platinum
7213	57	Other	74560.08	Platinum
8798	46	Other	40392.81	Bronze
1154	65	Female	119694.21	Platinum
3807	28	Other	100759.55	Platinum
2354	22	Female	110668.41	Bronze
8109	22	Female	118427.36	Platinum
1697	28	Other	76105.78	Silver
4764	46	Male	56234.19	Silver
4463	66	Male	74275.05	Gold
8790	18	Female	119100.81	Platinum
5441	68	Female	65191.19	Silver
1762	57	Male	85899.14	Silver
2218	61	Male	102018.96	Silver
5593	55	Female	63563.71	Gold
1539	64	Female	60785.51	Bronze
6152	44	Female	25147.61	Gold
3362	45	Other	47337.71	Silver
7525	58	Female	112807.39	Platinum
2260	34	Male	85608.47	Silver
5903	26	Female	113501.89	Gold
3661	21	Female	72964.47	Silver
4939	58	Male	118502.05	Platinum
7375	63	Female	92164.48	Gold
6435	68	Other	47334.45	Bronze
7288	25	Female	89056.22	Gold
3292	64	Other	114655.57	Platinum
2284	67	Male	78376.93	Platinum
9204	23	Female	88639.11	Platinum
6666	49	Male	67179.83	Gold
1879	66	Male	108071.02	Gold
2600	62	Male	77681.26	Gold
8161	33	Female	100751.81	Bronze
4803	22	Other	110722.90	Silver
6580	22	Male	34490.18	Bronze
7499	20	Male	102834.27	Bronze
6347	57	Other	35295.10	Silver
1485	25	Male	109660.71	Silver
5478	19	Other	46361.43	Bronze
9038	67	Other	23697.43	Platinum
4737	34	Other	50117.35	Gold
6829	43	Male	58686.60	Gold
7150	20	Female	77657.23	Bronze
4043	70	Female	101490.05	Gold
2404	29	Other	39022.72	Silver
5839	59	Other	87312.97	Gold
5037	20	Female	95439.41	Silver
2344	55	Male	82283.08	Silver
5390	39	Other	55708.43	Gold
7225	42	Male	61658.00	Silver
7383	52	Other	114741.83	Bronze
6909	43	Other	98022.66	Silver
2745	63	Male	103489.88	Bronze
2499	40	Other	73877.54	Platinum
1085	23	Female	45214.73	Silver
8286	30	Female	47721.44	Platinum
6896	53	Other	44167.18	Bronze
5419	56	Other	65467.69	Silver
2430	48	Female	85191.81	Bronze
4070	61	Male	37235.76	Silver
8061	58	Female	61659.33	Silver
8353	29	Other	41783.49	Silver
9395	26	Other	54458.31	Bronze
7685	47	Male	64493.97	Gold
2692	67	Male	70679.71	Silver
2468	67	Other	112144.49	Silver
6798	51	Other	55936.34	Bronze
6315	70	Female	79313.83	Silver
1202	29	Female	28687.71	Platinum
7353	18	Other	62391.74	Silver
2387	28	Female	57315.88	Platinum
4977	39	Male	86742.67	Bronze
9537	68	Male	113434.59	Gold
3778	31	Other	25865.10	Silver
7237	29	Female	89364.65	Silver
3777	37	Female	100085.92	Platinum
3274	35	Other	91223.25	Silver
5405	51	Other	67059.43	Bronze
5933	52	Female	24913.64	Platinum
9079	19	Other	31636.00	Bronze
2036	67	Male	21418.02	Bronze
3739	44	Other	37589.74	Gold
8121	56	Male	85870.44	Platinum
5521	70	Other	102625.76	Bronze
7899	64	Female	53939.58	Bronze
6916	47	Female	112168.90	Silver
5123	48	Male	72102.07	Bronze
9123	43	Other	37362.35	Gold
4203	38	Other	108826.79	Silver
8501	37	Male	78726.37	Platinum
2752	31	Other	100265.22	Platinum
3219	54	Female	56222.23	Silver
5991	40	Other	79555.26	Bronze
1110	56	Male	50089.57	Platinum
7483	28	Other	41447.46	Gold
6443	53	Female	21858.04	Platinum
6399	24	Female	73408.15	Silver
8212	34	Male	101177.87	Platinum
6484	45	Other	48772.56	Gold
3230	66	Other	91316.69	Bronze
5922	22	Other	59490.27	Bronze
4290	59	Female	73312.69	Bronze
8848	67	Female	69574.37	Silver
3910	39	Other	94796.70	Platinum
5775	34	Male	32998.24	Platinum
9044	47	Female	85138.24	Platinum
4971	34	Male	99588.90	Gold
6339	55	Female	79840.69	Gold
7161	63	Male	87925.68	Silver
5592	61	Female	83532.30	Silver
7437	22	Male	111132.05	Bronze
6980	22	Male	78094.54	Platinum
2865	43	Female	67642.97	Silver
4273	20	Female	114087.41	Platinum
9939	64	Female	43403.50	Bronze
3947	50	Male	98635.23	Gold
1440	34	Female	42075.15	Bronze
8563	61	Male	55517.99	Gold
4434	69	Other	81582.27	Bronze
8183	47	Other	106053.69	Gold
5773	52	Female	23503.46	Platinum
7703	25	Other	62377.61	Silver
3280	28	Other	45079.18	Silver
4965	28	Other	113308.25	Bronze
5139	31	Other	76662.87	Platinum
3525	59	Male	88206.25	Platinum
7176	35	Male	53796.43	Bronze
2211	61	Female	98944.42	Bronze
8357	35	Female	31020.04	Silver
8851	58	Male	117454.89	Platinum
9755	69	Other	40659.95	Gold
9300	36	Male	101545.19	Platinum
7853	35	Male	114435.09	Bronze
9907	47	Other	49098.31	Gold
1602	68	Female	108792.07	Bronze
9796	60	Male	28923.13	Bronze
2392	68	Female	96675.81	Silver
2791	37	Female	92515.87	Bronze
6816	37	Other	68682.44	Gold
1725	40	Other	114162.25	Gold
6432	60	Other	29659.83	Bronze
8052	43	Other	117948.72	Bronze
2735	67	Other	55618.06	Silver
1172	57	Female	94499.12	Gold
5239	65	Other	34526.74	Bronze
9366	37	Female	102621.77	Platinum
9499	39	Female	24858.66	Bronze
8303	62	Male	72072.16	Silver
7129	34	Female	51986.35	Silver
7408	29	Female	107016.77	Platinum
3469	41	Male	40803.15	Silver
6651	47	Other	28374.43	Bronze
1402	26	Other	64493.80	Platinum
8909	57	Male	115683.30	Silver
2712	65	Male	72018.00	Platinum
5840	55	Other	90629.23	Bronze
2406	34	Male	66968.71	Gold
2901	26	Male	71434.21	Silver
3321	42	Male	74801.55	Gold
6707	63	Other	61879.91	Platinum
6110	21	Female	116631.77	Bronze
6620	48	Female	57177.98	Silver
4389	32	Female	21850.94	Platinum
6706	55	Female	61951.24	Silver
8801	23	Female	107482.77	Silver
2599	35	Male	37298.14	Bronze
8412	52	Other	42685.72	Bronze
6225	26	Female	50341.30	Silver
2100	46	Other	27957.95	Bronze
5919	43	Female	70933.37	Silver
1732	68	Female	29186.92	Gold
2885	36	Female	76522.45	Platinum
1370	60	Male	101052.08	Silver
3692	67	Female	74972.52	Gold
4996	26	Male	27457.72	Bronze
9454	31	Female	70308.34	Silver
3623	56	Other	66316.95	Gold
6422	40	Other	84673.01	Silver
7985	38	Male	115444.47	Bronze
8570	34	Male	99131.53	Bronze
4798	41	Other	108462.19	Gold
4022	58	Male	95007.24	Silver
4053	27	Other	78993.73	Platinum
8080	39	Other	72571.32	Platinum
7481	64	Other	94008.19	Bronze
1478	54	Female	76035.52	Platinum
8365	25	Other	61495.30	Bronze
8037	31	Other	41892.42	Silver
7370	46	Other	40992.50	Silver
1072	29	Male	79618.58	Silver
4519	18	Male	63216.19	Silver
4371	70	Female	57112.63	Silver
5560	44	Other	93377.06	Gold
2025	68	Male	73199.56	Gold
2667	47	Female	89245.32	Gold
4063	58	Female	83679.26	Silver
6993	60	Other	95904.96	Silver
6340	31	Other	51734.27	Bronze
8496	57	Female	116520.52	Platinum
2867	61	Female	103781.09	Bronze
5298	47	Female	48555.59	Platinum
9019	53	Male	66085.11	Silver
9646	19	Female	51122.84	Bronze
6134	33	Male	89236.38	Gold
7431	57	Other	38505.23	Platinum
2871	64	Other	46412.56	Platinum
3826	53	Other	32392.71	Platinum
6131	63	Other	64219.75	Silver
2931	48	Female	32804.82	Bronze
2916	54	Male	30313.38	Platinum
3999	25	Male	34501.89	Silver
3316	56	Male	55459.04	Bronze
9369	23	Female	113717.27	Silver
7364	66	Female	96315.01	Bronze
7852	60	Female	103075.09	Gold
3258	68	Other	63893.49	Silver
7286	58	Female	78910.90	Bronze
7931	55	Male	79160.70	Bronze
9804	28	Female	22025.07	Bronze
3838	51	Other	87800.33	Gold
3733	61	Other	45048.52	Bronze
5732	70	Female	111731.62	Platinum
3298	23	Male	74051.35	Gold
4065	50	Other	110358.29	Gold
6154	64	Other	28379.33	Gold
8389	31	Male	59479.98	Silver
6882	38	Female	44354.70	Bronze
1157	18	Female	76348.01	Gold
4196	57	Female	59848.35	Gold
7290	50	Male	32759.63	Gold
9109	52	Male	65175.81	Bronze
9006	41	Female	23747.84	Gold
3740	20	Other	21556.61	Silver
1505	50	Female	100534.05	Bronze
5785	40	Female	98268.09	Silver
1535	24	Other	79690.72	Platinum
5503	61	Male	68629.12	Silver
5729	44	Male	65911.04	Silver
3755	26	Male	90998.32	Silver
8492	47	Male	26907.81	Platinum
2854	43	Other	111383.49	Bronze
5389	58	Female	88714.65	Silver
9898	44	Female	77230.42	Gold
7010	28	Male	102266.50	Silver
9880	22	Male	76620.78	Gold
1681	48	Other	38729.31	Bronze
8231	63	Male	112354.70	Platinum
9951	66	Male	87315.93	Bronze
4580	43	Male	39468.42	Bronze
2677	61	Female	23204.59	Gold
5877	63	Male	105186.47	Silver
1528	29	Male	69390.99	Bronze
5305	32	Female	24153.70	Gold
6711	70	Male	105016.95	Gold
2425	50	Male	68689.95	Silver
8193	25	Female	88007.63	Gold
4882	35	Other	79921.09	Bronze
4438	41	Other	38294.00	Platinum
6744	44	Female	21637.82	Bronze
8015	70	Male	85890.82	Silver
3719	40	Other	92892.54	Bronze
3281	23	Other	71155.36	Bronze
4385	63	Male	43452.58	Platinum
4390	35	Male	117545.03	Bronze
1972	55	Other	44331.40	Bronze
6747	56	Male	27033.17	Gold
9720	46	Male	21317.40	Bronze
5605	39	Female	110512.86	Bronze
9827	31	Female	38923.83	Silver
3758	59	Other	107931.97	Bronze
6302	20	Male	48047.52	Silver
5794	22	Other	70710.02	Platinum
5740	36	Female	39092.51	Bronze
5380	34	Male	80954.59	Bronze
9428	42	Male	99023.85	Bronze
2560	65	Male	34989.53	Platinum
3221	31	Other	116684.75	Bronze
7743	33	Female	57849.12	Bronze
1971	52	Female	97537.12	Silver
3078	38	Female	107483.27	Platinum
3174	38	Male	112618.21	Gold
5090	36	Female	61116.78	Platinum
3396	39	Other	108516.46	Platinum
7434	23	Female	34454.74	Silver
3329	59	Female	93507.98	Silver
5402	27	Female	22246.52	Bronze
7786	26	Other	50513.14	Platinum
7146	22	Other	58195.53	Silver
2237	61	Male	106449.83	Gold
2525	69	Female	102983.76	Silver
7600	51	Female	48794.44	Gold
9447	59	Other	107268.73	Gold
8996	24	Other	109456.29	Gold
6362	31	Male	77812.21	Platinum
1040	23	Female	46206.93	Gold
2526	26	Male	48684.06	Platinum
8511	21	Other	20737.93	Bronze
2037	56	Female	119471.80	Platinum
9756	33	Female	93562.76	Bronze
7516	21	Other	42446.15	Gold
4568	53	Female	99800.45	Gold
8039	54	Male	42087.92	Platinum
9105	57	Other	117523.19	Platinum
5399	63	Other	116867.59	Gold
6289	32	Other	106451.59	Silver
5646	19	Male	105079.24	Silver
6533	54	Other	48427.77	Silver
9967	62	Male	87619.72	Gold
3139	27	Female	85943.11	Platinum
8951	59	Other	26013.90	Platinum
6631	29	Male	32274.77	Silver
1793	27	Male	111034.25	Bronze
1752	63	Female	66127.00	Bronze
2631	20	Male	111885.05	Gold
3035	37	Male	73544.00	Silver
8230	69	Other	102685.19	Platinum
8479	49	Female	98245.22	Silver
1011	45	Other	99408.48	Gold
8009	44	Other	60303.79	Silver
4314	68	Other	96996.71	Bronze
5945	46	Female	42288.60	Platinum
3604	20	Male	88710.65	Silver
5489	70	Other	53662.48	Bronze
2529	69	Other	82734.75	Gold
6905	70	Other	51483.72	Silver
2350	43	Female	37580.34	Bronze
7092	51	Other	35102.09	Bronze
3711	30	Other	68477.67	Gold
1848	62	Other	28587.35	Silver
7493	53	Other	105513.80	Bronze
6005	28	Other	99677.29	Platinum
2559	63	Male	58421.86	Bronze
1017	44	Male	37731.69	Platinum
4496	46	Female	38389.20	Silver
8812	36	Male	46907.48	Silver
2276	21	Male	85193.08	Silver
9510	60	Other	119685.07	Bronze
8291	18	Male	28407.67	Gold
6629	48	Other	39075.18	Platinum
2975	49	Male	73447.38	Platinum
7919	32	Male	108792.22	Silver
8826	62	Female	73743.12	Silver
4751	55	Female	88738.38	Platinum
7276	60	Other	47775.89	Platinum
2463	44	Other	119870.75	Silver
2678	29	Male	77234.78	Bronze
2690	41	Female	43079.92	Gold
6133	60	Other	115491.09	Gold
3246	55	Female	63881.42	Silver
7270	19	Other	78673.21	Gold
3181	64	Female	37526.24	Silver
2120	27	Male	96031.53	Bronze
1138	31	Other	90759.52	Platinum
3688	41	Male	73023.29	Silver
8210	39	Male	85807.27	Gold
4490	21	Female	49980.03	Platinum
3480	25	Female	88140.96	Platinum
8248	39	Male	32115.77	Platinum
2420	34	Male	58349.82	Bronze
3017	45	Other	51774.97	Silver
8035	42	Male	32119.47	Bronze
5537	47	Other	108132.49	Platinum
2380	21	Other	47413.61	Silver
1439	58	Other	116832.34	Gold
5942	39	Female	32387.29	Silver
4366	45	Male	33649.12	Platinum
7418	31	Male	106893.05	Silver
5842	58	Male	94494.68	Gold
1894	23	Other	77711.48	Silver
7322	29	Other	44471.20	Bronze
2847	29	Female	39470.05	Platinum
4949	25	Male	93947.11	Platinum
9185	22	Male	92122.77	Platinum
9655	64	Male	32107.32	Bronze
1197	34	Male	76908.84	Silver
6185	39	Male	33574.48	Gold
3162	66	Female	91672.81	Bronze
7337	62	Other	51469.48	Bronze
7895	49	Male	108712.22	Gold
6986	29	Male	70728.03	Silver
3830	40	Other	118105.01	Bronze
8717	41	Female	69490.97	Silver
1273	32	Other	37206.46	Bronze
1225	24	Other	46878.45	Silver
4534	69	Other	81760.72	Platinum
1652	65	Female	59256.35	Silver
7520	59	Male	89042.59	Platinum
5693	67	Male	102288.79	Platinum
9209	53	Male	78073.06	Silver
3501	42	Female	119997.52	Gold
5546	70	Female	99044.81	Gold
2369	56	Other	101306.78	Bronze
6077	36	Female	105597.56	Platinum
9377	41	Other	28880.19	Platinum
4329	18	Other	49329.81	Silver
3545	40	Male	85295.84	Silver
9788	51	Male	44681.25	Silver
6353	70	Female	52366.96	Gold
7401	31	Other	32060.10	Silver
2083	64	Female	85258.37	Platinum
6081	43	Other	84766.36	Gold
4909	47	Other	32216.48	Gold
1948	28	Male	105827.64	Platinum
5005	27	Female	66832.36	Gold
8118	50	Male	73732.60	Platinum
2900	36	Male	28669.13	Bronze
1901	55	Female	22155.07	Silver
2956	55	Female	94729.55	Gold
1185	64	Female	54779.32	Gold
3684	70	Male	100185.42	Gold
9133	52	Male	40900.44	Silver
6680	58	Other	31397.00	Bronze
9568	53	Female	63500.85	Gold
9474	64	Male	64587.14	Bronze
5247	63	Other	25184.74	Platinum
3735	63	Other	86767.45	Gold
3079	42	Male	112431.43	Silver
5403	50	Female	113904.52	Platinum
2934	55	Female	116204.34	Silver
1480	51	Male	87426.50	Platinum
6488	18	Female	110202.27	Bronze
8034	24	Male	75983.13	Platinum
5456	19	Male	33717.62	Gold
9582	43	Male	22737.81	Silver
2046	58	Female	46236.67	Silver
5308	61	Male	54793.65	Gold
2262	39	Male	115230.95	Silver
9128	67	Male	84765.09	Gold
8457	64	Other	22968.88	Silver
9368	29	Other	22563.20	Silver
6900	51	Female	74707.73	Gold
1908	40	Other	83187.71	Gold
3734	37	Female	39046.62	Silver
7024	64	Female	96669.20	Silver
3577	30	Other	34508.73	Bronze
5179	20	Other	88959.71	Bronze
2685	38	Female	76311.33	Platinum
4742	60	Female	65561.15	Bronze
9336	31	Female	57325.04	Platinum
1721	45	Male	90295.56	Platinum
1201	24	Female	25137.27	Bronze
5006	34	Other	119874.85	Bronze
8729	24	Male	55077.22	Silver
6963	45	Other	88766.23	Silver
3458	32	Male	91677.33	Gold
3932	59	Female	108035.28	Silver
1579	46	Female	62563.83	Gold
7870	19	Other	114612.35	Gold
7819	49	Male	100765.28	Gold
6241	34	Female	109029.28	Bronze
5444	63	Male	51070.94	Silver
9225	60	Other	54815.56	Platinum
1862	70	Female	77652.32	Bronze
4656	40	Female	99782.51	Bronze
9450	21	Male	44807.12	Silver
7568	59	Male	50949.61	Platinum
8620	36	Male	65461.05	Silver
5625	69	Other	24350.88	Silver
6090	68	Other	86764.64	Silver
2415	46	Other	75614.72	Bronze
1130	57	Female	70957.10	Bronze
4287	56	Other	103987.19	Silver
5777	46	Other	102745.93	Silver
5979	48	Other	77436.33	Silver
8600	53	Male	102539.62	Gold
7033	50	Other	91164.38	Bronze
9083	23	Other	115316.76	Gold
4201	21	Male	33647.43	Silver
5016	50	Other	74311.47	Silver
3466	41	Male	54463.47	Silver
7718	24	Male	21399.17	Platinum
1391	40	Male	60335.92	Platinum
9872	56	Female	106400.25	Silver
6675	19	Male	98562.95	Gold
1023	34	Female	88600.51	Silver
7164	28	Other	30027.78	Gold
2703	36	Male	94847.21	Gold
4361	53	Other	32999.97	Bronze
9680	66	Other	54245.30	Gold
4902	46	Female	74069.58	Gold
9061	36	Female	82291.04	Gold
3332	20	Other	21314.58	Platinum
5584	37	Female	53232.70	Platinum
1719	67	Male	80984.62	Platinum
9515	49	Male	63887.32	Silver
7767	24	Other	26498.19	Silver
7102	34	Female	110031.86	Platinum
2565	50	Female	94234.97	Bronze
3187	68	Male	97583.43	Silver
7461	51	Other	87720.58	Platinum
2226	47	Female	104342.08	Gold
3141	54	Female	60021.14	Gold
4879	66	Other	71322.80	Platinum
5778	40	Other	51361.68	Bronze
5276	68	Male	44382.63	Gold
6161	22	Other	47061.81	Silver
6345	62	Female	42532.16	Gold
6211	43	Female	74443.10	Bronze
8417	57	Other	101815.15	Silver
5455	55	Female	22091.72	Gold
4827	28	Female	83684.95	Gold
2223	26	Other	61749.64	Platinum
4321	55	Other	65370.50	Platinum
2785	59	Male	39721.99	Silver
2731	47	Male	118127.30	Platinum
3693	58	Other	37630.11	Silver
6145	20	Other	54084.52	Platinum
7660	58	Female	35275.20	Bronze
2978	22	Male	84266.43	Bronze
9780	43	Other	60009.59	Silver
6870	53	Other	53802.18	Bronze
4401	51	Female	72359.49	Silver
6051	61	Female	45821.99	Platinum
8591	18	Female	25179.89	Bronze
5341	37	Female	73711.30	Gold
2481	48	Female	55645.79	Bronze
3582	43	Other	81610.66	Platinum
5984	62	Male	56459.82	Platinum
1660	33	Male	78392.92	Bronze
6370	18	Male	45706.36	Platinum
6828	55	Female	23473.51	Bronze
7492	37	Male	118845.59	Bronze
9412	48	Male	49665.75	Silver
1802	67	Male	90771.91	Platinum
5896	59	Male	86848.13	Bronze
3848	24	Other	106685.37	Platinum
1509	37	Female	90457.96	Silver
8408	38	Male	93199.70	Gold
5093	59	Female	99451.96	Gold
2551	69	Male	95493.42	Platinum
1195	37	Other	80259.08	Silver
2010	26	Other	38257.71	Silver
4641	47	Other	72630.30	Silver
4246	49	Other	29789.90	Bronze
7098	47	Male	89686.09	Platinum
2376	35	Male	105341.01	Bronze
5240	24	Female	112907.91	Platinum
2228	45	Male	78366.93	Platinum
1357	39	Male	110368.80	Bronze
2056	33	Male	110927.34	Platinum
4239	67	Other	38374.40	Bronze
8265	46	Male	71365.98	Gold
3110	35	Other	34064.95	Bronze
2506	44	Other	83562.62	Gold
1699	66	Male	65904.85	Gold
8552	46	Male	107319.17	Bronze
3752	39	Male	115031.86	Gold
8096	70	Male	110701.81	Gold
7471	44	Other	109013.90	Gold
1483	61	Other	61033.39	Platinum
7990	24	Other	105215.59	Bronze
3831	42	Male	81512.76	Gold
6799	36	Female	52077.15	Silver
4517	33	Female	84668.55	Gold
4066	43	Other	22324.25	Bronze
5585	59	Female	107019.28	Silver
8307	63	Other	117243.91	Gold
3435	25	Female	73146.01	Platinum
1567	24	Female	87397.66	Gold
9173	51	Other	63426.98	Bronze
7750	41	Female	74633.15	Bronze
1999	69	Female	70624.16	Platinum
2437	41	Other	111811.94	Silver
9614	45	Other	54773.98	Silver
6883	53	Female	107549.43	Platinum
8859	28	Male	58114.27	Gold
9921	38	Other	44463.12	Gold
8940	44	Other	30529.20	Silver
6636	58	Female	28352.02	Silver
9231	33	Other	117842.44	Platinum
5430	65	Other	103820.26	Bronze
3946	31	Other	59019.40	Platinum
1427	29	Other	109096.62	Bronze
5602	25	Other	87996.13	Gold
1959	23	Female	102046.09	Silver
8728	19	Female	101253.09	Silver
6856	60	Female	78096.14	Silver
4813	69	Male	107234.95	Platinum
2640	51	Female	59643.44	Silver
5060	30	Other	49531.93	Platinum
4951	62	Male	65845.07	Silver
5366	25	Other	109558.71	Platinum
4594	54	Other	52951.66	Bronze
3846	22	Female	29176.43	Silver
4875	22	Other	117571.41	Gold
6210	21	Male	110914.36	Bronze
6878	23	Male	119753.86	Platinum
1462	23	Other	54020.56	Bronze
3328	26	Other	34554.25	Gold
9064	69	Male	92190.05	Gold
6063	59	Male	58309.49	Bronze
3876	47	Female	34866.27	Silver
9035	69	Female	95464.38	Gold
1621	37	Female	107011.72	Platinum
2478	47	Male	46204.94	Silver
4584	53	Other	100735.62	Silver
1326	23	Male	108707.84	Bronze
8831	61	Male	56395.33	Silver
4300	45	Other	110198.44	Platinum
3137	24	Male	60199.63	Bronze
3907	69	Male	41262.68	Gold
1975	26	Female	54030.92	Bronze
3420	67	Male	64761.56	Gold
3320	50	Female	28423.33	Platinum
2817	21	Male	62242.83	Platinum
9622	29	Other	102360.34	Gold
6978	65	Female	65958.18	Silver
7120	29	Male	42547.40	Gold
2655	38	Male	38367.53	Silver
6285	52	Male	112918.92	Bronze
3235	27	Other	42659.84	Bronze
8157	67	Other	62309.51	Gold
8982	48	Female	111746.51	Platinum
6846	50	Male	54466.08	Bronze
3872	65	Male	72681.28	Gold
7199	49	Female	119923.77	Silver
5825	55	Male	48443.23	Silver
3911	47	Other	48969.86	Bronze
1029	51	Female	69974.57	Platinum
7415	59	Other	41581.26	Platinum
3983	41	Other	61470.96	Silver
4619	35	Other	31577.24	Silver
2705	64	Other	115558.10	Bronze
3304	44	Female	114310.54	Silver
2274	36	Female	97250.43	Gold
6682	39	Female	41471.93	Silver
6234	35	Female	94651.11	Gold
3750	29	Male	53478.60	Platinum
2453	61	Male	40490.76	Bronze
6500	37	Male	113088.61	Gold
8317	61	Male	103960.19	Silver
1186	47	Other	97990.46	Gold
4435	29	Male	87246.93	Bronze
2110	57	Female	86354.72	Silver
6742	24	Female	112061.59	Platinum
5205	58	Other	81096.61	Platinum
2770	38	Female	108651.91	Silver
1020	70	Female	82768.31	Gold
1788	68	Other	83751.94	Gold
7323	60	Other	82766.21	Bronze
7875	43	Male	71125.12	Silver
7783	45	Other	50151.60	Bronze
9078	56	Female	98842.90	Gold
7204	58	Female	69400.49	Platinum
6754	26	Other	20621.93	Gold
9946	18	Male	72301.56	Silver
2661	67	Other	105577.74	Silver
8855	62	Other	110167.88	Silver
4695	29	Male	50587.95	Platinum
8393	47	Other	22564.69	Gold
2207	27	Male	105195.35	Platinum
1547	26	Male	107646.86	Gold
1328	66	Male	36894.56	Bronze
5278	33	Female	73735.54	Silver
2715	62	Female	63103.91	Bronze
6600	64	Other	69932.48	Bronze
3787	51	Other	111564.74	Platinum
7151	59	Female	116795.28	Platinum
3636	46	Male	34172.91	Gold
9962	50	Other	61010.20	Gold
6536	62	Other	53662.90	Bronze
1507	31	Male	65704.72	Platinum
3703	37	Female	25587.32	Bronze
8113	66	Other	111293.39	Silver
1877	35	Male	24427.97	Platinum
2659	40	Female	68858.09	Silver
6424	32	Male	35876.08	Gold
4367	55	Female	88060.40	Silver
4112	46	Male	95776.34	Silver
7705	41	Male	112707.15	Gold
5346	53	Male	61351.43	Platinum
5612	29	Male	91249.10	Gold
5872	54	Other	61213.32	Silver
2571	19	Other	65953.70	Bronze
1813	62	Female	63248.25	Bronze
9043	50	Female	100175.54	Gold
3516	64	Female	118982.53	Bronze
6911	42	Male	31820.35	Platinum
1062	62	Male	45514.85	Platinum
8005	56	Male	109791.04	Gold
2435	50	Female	35779.51	Gold
8869	26	Female	91337.78	Gold
2589	37	Other	32718.01	Silver
1421	35	Other	39577.51	Bronze
3798	27	Other	78213.66	Bronze
2342	51	Male	112737.38	Platinum
2892	44	Male	37429.45	Platinum
6052	62	Female	88912.86	Platinum
8715	60	Female	28734.29	Bronze
9013	42	Male	63048.28	Platinum
2493	63	Male	110838.81	Bronze
7349	57	Male	50125.31	Bronze
4029	36	Female	72531.24	Bronze
7249	61	Male	77828.63	Bronze
7052	61	Male	110483.66	Bronze
4056	36	Other	54019.69	Platinum
1731	47	Other	71283.11	Gold
5313	56	Female	27100.05	Platinum
4706	47	Female	21691.47	Gold
5400	38	Female	119489.61	Gold
2009	23	Female	42109.16	Bronze
3476	40	Female	43900.23	Gold
9871	56	Male	68330.15	Silver
7782	28	Female	54018.27	Bronze
7342	19	Male	103494.31	Gold
7858	45	Other	98107.60	Bronze
9773	19	Female	28665.88	Gold
8779	52	Other	73556.23	Silver
4860	67	Other	74308.83	Platinum
8803	69	Male	58547.35	Bronze
7468	61	Female	38275.56	Silver
1568	51	Male	119433.41	Bronze
9226	27	Male	74751.45	Platinum
9467	18	Other	80487.47	Silver
3415	61	Other	61669.32	Gold
2970	19	Other	77200.14	Silver
3832	61	Male	104244.16	Silver
3738	58	Other	21345.34	Bronze
4471	29	Other	74253.50	Gold
4157	56	Female	111020.87	Platinum
7936	18	Female	58490.87	Silver
2283	44	Female	75530.32	Platinum
8133	58	Male	85594.18	Platinum
4308	48	Other	22826.28	Silver
3422	64	Female	45856.25	Gold
5225	68	Male	100689.99	Silver
2097	26	Other	29766.89	Bronze
7358	35	Female	59601.45	Gold
7510	45	Other	83592.82	Platinum
6343	38	Male	118615.80	Gold
5525	58	Other	29769.68	Silver
9514	38	Male	99962.28	Silver
8506	30	Female	59737.23	Gold
7874	27	Other	39382.02	Gold
2843	27	Male	113561.55	Gold
3451	28	Female	100895.11	Silver
3428	25	Other	98196.69	Gold
2730	50	Female	49074.52	Platinum
6633	57	Other	20609.03	Silver
7732	19	Other	104505.25	Bronze
5327	31	Other	67847.39	Platinum
8955	38	Male	106938.11	Gold
8750	70	Male	78267.43	Silver
3821	70	Other	68479.66	Platinum
5512	31	Male	72994.79	Silver
7602	67	Other	119458.68	Bronze
3356	29	Female	98202.35	Silver
7581	63	Other	104959.43	Silver
1635	27	Female	36926.20	Silver
6431	28	Other	44382.63	Silver
4892	49	Female	65980.08	Silver
1807	27	Other	102681.79	Platinum
8785	32	Other	73846.26	Bronze
1331	26	Female	76807.88	Silver
6535	35	Male	42994.02	Platinum
5965	22	Male	86941.57	Bronze
6094	67	Male	95633.93	Silver
9054	21	Male	88627.34	Bronze
2609	51	Female	53665.25	Bronze
4734	31	Other	111668.17	Gold
3201	53	Other	110547.29	Silver
6257	60	Other	54192.36	Bronze
5414	23	Male	93459.80	Bronze
7828	34	Other	110682.20	Gold
2462	66	Male	40224.54	Bronze
4079	52	Male	26218.35	Bronze
7671	56	Female	52238.36	Platinum
8937	35	Male	59581.28	Platinum
9462	52	Female	96638.31	Gold
2075	31	Other	102999.70	Silver
6097	61	Other	56776.47	Platinum
9303	30	Female	84011.77	Platinum
7609	26	Female	62460.03	Silver
4158	45	Male	28379.99	Platinum
4288	66	Female	39540.18	Gold
5087	25	Female	78538.36	Silver
1541	56	Male	42857.96	Silver
6904	46	Other	39678.56	Silver
5488	20	Other	119386.92	Bronze
8605	63	Other	55206.72	Gold
9275	24	Other	75091.42	Silver
7503	67	Male	44988.98	Silver
3029	50	Female	77111.04	Bronze
1500	43	Male	83436.94	Platinum
8308	33	Male	25995.63	Bronze
3909	59	Male	31449.01	Platinum
6730	46	Male	104148.06	Gold
6640	66	Other	44241.87	Gold
3679	62	Other	40425.42	Silver
5237	38	Other	119514.90	Platinum
1449	29	Female	40115.94	Platinum
3669	34	Male	105299.22	Gold
4511	40	Female	46188.30	Bronze
4688	40	Male	56963.64	Silver
4387	70	Male	64682.94	Silver
5408	37	Other	97441.27	Silver
7709	34	Female	37302.45	Platinum
1145	27	Female	51009.57	Gold
8767	48	Male	32877.43	Bronze
4666	34	Male	57989.32	Platinum
6004	57	Male	81134.29	Bronze
5511	61	Female	96651.87	Silver
7943	58	Male	98798.59	Silver
7168	57	Female	86369.94	Bronze
6713	49	Male	64904.58	Silver
4575	67	Female	60138.01	Bronze
8646	34	Female	99835.83	Silver
5950	28	Female	52733.94	Platinum
9530	29	Male	96342.55	Gold
7506	60	Female	109065.29	Platinum
2676	39	Male	87565.73	Bronze
1120	57	Female	25010.82	Platinum
9380	61	Male	59829.98	Platinum
7131	46	Female	78454.89	Silver
5631	30	Female	25565.05	Silver
8892	49	Male	87351.45	Bronze
2045	34	Other	58563.37	Bronze
6509	50	Male	74914.85	Bronze
5529	69	Female	63615.99	Gold
5536	59	Female	42782.50	Gold
5895	51	Female	118390.61	Gold
4086	31	Female	78610.61	Platinum
3456	68	Other	42587.70	Gold
9475	46	Male	56397.33	Gold
1930	32	Other	69280.41	Bronze
7620	27	Male	27100.91	Silver
1417	66	Other	106066.70	Bronze
5250	60	Other	62570.07	Platinum
7857	18	Male	44588.46	Gold
7628	59	Female	21888.82	Bronze
7361	68	Female	87889.75	Platinum
1578	53	Female	28110.24	Silver
6622	18	Female	87261.68	Silver
4643	58	Other	104400.44	Gold
9759	47	Other	88518.68	Silver
8794	49	Male	41305.22	Silver
5918	65	Other	109045.17	Platinum
3967	42	Male	62727.41	Silver
8713	41	Male	118533.57	Platinum
3096	50	Female	74248.69	Platinum
6499	51	Other	39772.64	Platinum
4659	64	Male	32793.46	Silver
6031	64	Other	60034.96	Bronze
7889	65	Other	70761.92	Gold
6428	38	Female	81019.00	Gold
7089	47	Other	93037.81	Silver
5269	32	Female	94582.61	Bronze
5817	32	Male	47455.28	Platinum
8598	32	Male	49185.37	Silver
8709	32	Other	53009.38	Silver
4187	67	Male	63080.22	Gold
2963	20	Other	93462.10	Gold
7253	29	Other	78472.20	Silver
7768	64	Female	51244.58	Silver
1885	65	Female	44637.56	Gold
3470	55	Other	57746.88	Bronze
3250	36	Other	75041.29	Silver
4281	68	Other	72809.57	Gold
6614	61	Female	43371.04	Silver
7704	21	Other	117278.24	Platinum
3346	45	Male	117582.04	Platinum
3954	64	Female	113663.95	Gold
2324	36	Other	117124.28	Gold
6449	47	Female	93561.06	Silver
3897	42	Other	73096.77	Bronze
1950	24	Male	25445.73	Bronze
1077	57	Male	22633.14	Bronze
5481	47	Female	67184.66	Gold
4430	65	Female	44006.16	Gold
3595	25	Other	65297.72	Bronze
9021	27	Male	69411.56	Bronze
3120	61	Male	104899.88	Platinum
8105	20	Other	46875.31	Platinum
8029	58	Male	72481.39	Platinum
8821	43	Male	105234.73	Gold
7280	27	Female	57201.73	Platinum
1076	35	Other	65095.84	Platinum
9745	20	Other	109969.82	Platinum
1293	34	Female	115025.46	Platinum
1067	60	Female	82867.85	Bronze
5076	26	Male	37195.19	Platinum
4707	66	Female	24698.96	Bronze
6641	47	Female	46650.25	Platinum
6113	38	Female	105739.59	Gold
2682	25	Male	97614.55	Bronze
9246	63	Other	65524.40	Platinum
6015	33	Other	100110.65	Gold
3736	46	Other	84863.69	Platinum
2069	27	Female	46398.99	Silver
5885	23	Male	71104.77	Silver
5764	48	Male	20659.57	Bronze
8469	64	Male	31995.69	Gold
9524	62	Female	96070.59	Platinum
9587	19	Female	62557.41	Gold
3192	46	Male	97153.92	Silver
6615	38	Other	66873.63	Bronze
6885	39	Other	113961.83	Platinum
4087	39	Female	119975.32	Gold
3701	62	Other	42933.67	Platinum
1313	47	Female	78993.97	Platinum
4675	36	Female	96646.27	Gold
3149	48	Male	65143.58	Bronze
9267	25	Other	20893.98	Silver
3768	20	Female	22883.69	Gold
7006	47	Male	45211.67	Platinum
1612	63	Other	67908.18	Platinum
7147	37	Male	78998.07	Platinum
5190	37	Other	43967.06	Silver
9761	34	Male	118034.59	Silver
1796	62	Male	95022.51	Platinum
1785	56	Female	53553.05	Platinum
1323	56	Female	105552.10	Silver
1790	68	Male	107749.11	Platinum
2897	50	Female	78478.26	Platinum
8279	20	Male	83192.09	Silver
7230	68	Other	88189.24	Bronze
9966	49	Male	96390.42	Gold
5140	25	Male	84534.99	Platinum
8772	62	Female	20828.67	Platinum
3508	43	Other	93117.67	Platinum
5423	50	Female	119829.87	Platinum
3247	21	Female	58725.39	Silver
7862	33	Male	70279.73	Gold
2718	19	Female	45768.07	Bronze
9381	69	Other	101470.35	Bronze
2928	28	Male	113354.41	Bronze
2741	54	Male	118304.19	Platinum
9154	26	Female	26182.18	Gold
4254	32	Female	83019.18	Silver
4272	61	Other	100260.85	Silver
9571	64	Female	54802.64	Bronze
4304	18	Male	33113.44	Silver
6864	18	Other	37152.08	Platinum
7713	53	Other	71466.90	Silver
3627	32	Other	78033.85	Bronze
9980	25	Male	20665.63	Platinum
9132	52	Female	64813.57	Platinum
4402	48	Male	52635.17	Platinum
8875	69	Female	37290.23	Silver
6416	25	Male	85082.27	Silver
4842	67	Male	77308.52	Silver
1044	38	Female	29776.53	Gold
1208	63	Female	91219.53	Bronze
2458	38	Male	54656.67	Silver
2809	68	Other	108881.77	Platinum
3443	19	Other	72055.27	Silver
9383	30	Other	92938.33	Silver
5192	30	Male	113340.25	Bronze
4787	21	Female	104560.71	Silver
5850	32	Other	93321.56	Bronze
1820	30	Female	69897.07	Gold
2635	66	Other	75165.89	Bronze
3862	41	Male	65257.26	Gold
1646	35	Other	51220.02	Bronze
5760	31	Female	114066.08	Silver
6901	24	Male	87068.31	Bronze
7979	33	Other	52690.01	Bronze
2898	46	Other	61137.43	Bronze
2556	65	Other	107970.72	Platinum
1751	32	Male	61156.38	Platinum
6384	54	Other	112388.85	Gold
6857	41	Male	38023.57	Silver
8171	68	Male	96785.56	Silver
5395	62	Male	110743.27	Platinum
2522	19	Female	93444.24	Gold
3996	35	Male	93668.98	Bronze
7557	58	Female	68055.20	Gold
5453	52	Other	59108.92	Platinum
7319	24	Female	110151.73	Silver
8835	67	Female	62652.23	Gold
7909	57	Other	97891.34	Bronze
3732	52	Male	41891.92	Bronze
2852	49	Male	34520.69	Bronze
3171	62	Other	29645.76	Bronze
3611	54	Other	91692.47	Gold
2699	54	Other	47727.92	Silver
7816	47	Male	76172.14	Bronze
8908	32	Other	28203.79	Silver
3969	62	Female	68249.35	Bronze
7221	29	Other	77797.42	Platinum
6875	59	Other	70718.25	Platinum
3140	26	Female	109895.09	Platinum
8914	48	Female	88934.73	Platinum
8997	51	Female	30129.20	Bronze
2850	20	Other	87838.50	Platinum
7738	57	Other	26632.60	Platinum
8220	55	Other	79433.72	Gold
5286	33	Female	68085.67	Silver
6148	69	Other	61897.24	Silver
9598	60	Female	102907.60	Silver
4669	54	Female	107280.92	Silver
6542	52	Other	73316.74	Bronze
9504	43	Other	83134.33	Bronze
9570	31	Other	71104.65	Platinum
8091	24	Female	68497.12	Platinum
5072	58	Male	22763.41	Platinum
8895	20	Other	79221.04	Bronze
6664	44	Male	21126.05	Silver
7305	29	Female	36440.52	Bronze
1190	45	Male	22031.80	Platinum
3571	47	Male	64570.36	Platinum
9283	53	Female	119335.50	Silver
8688	44	Female	35233.85	Gold
3709	20	Female	116027.30	Silver
9055	32	Other	39011.50	Gold
1824	22	Female	91325.68	Silver
9305	54	Male	29787.47	Platinum
7203	34	Male	54393.34	Platinum
7607	52	Female	59055.11	Bronze
4850	43	Other	94452.79	Silver
8521	20	Female	104637.60	Silver
8341	59	Other	26464.33	Silver
9166	62	Female	31901.13	Silver
8324	57	Female	86978.36	Gold
6178	52	Female	119193.15	Bronze
2944	65	Female	64155.81	Silver
1291	70	Male	58383.51	Platinum
2681	34	Male	31630.12	Gold
1587	35	Female	72361.10	Platinum
9996	55	Other	79391.95	Platinum
1002	22	Other	60155.52	Bronze
5990	52	Female	110264.84	Gold
9328	40	Male	71144.41	Platinum
8474	20	Female	98087.60	Platinum
6584	24	Female	29342.56	Bronze
6953	39	Other	94713.16	Bronze
1889	34	Male	26549.08	Silver
8445	28	Female	43051.08	Platinum
8751	67	Female	97285.43	Silver
8414	38	Female	88426.93	Bronze
2596	47	Other	33060.33	Platinum
4633	32	Male	84112.28	Silver
6592	65	Other	86815.01	Bronze
6818	24	Male	108690.86	Bronze
5783	50	Other	42469.94	Bronze
9973	65	Other	86169.27	Bronze
9552	20	Female	109756.50	Silver
7125	51	Male	74218.15	Bronze
3689	39	Other	83999.62	Silver
9067	50	Female	57470.31	Gold
3301	37	Male	50538.77	Silver
5166	19	Female	70907.21	Bronze
4209	26	Other	51504.49	Gold
4072	28	Other	113195.06	Platinum
4532	48	Female	49954.45	Silver
8488	69	Other	96133.63	Gold
2765	62	Other	37918.78	Silver
1761	28	Male	112605.66	Bronze
3018	25	Female	86973.19	Gold
8493	40	Male	51583.23	Platinum
9260	28	Male	95004.23	Gold
3205	49	Other	60932.95	Platinum
9172	67	Other	76054.60	Bronze
1071	64	Female	27619.11	Gold
1795	27	Other	119919.78	Silver
3903	62	Male	50668.34	Silver
3845	35	Male	28713.20	Gold
2696	36	Female	99583.50	Platinum
6273	64	Other	40278.43	Silver
9259	42	Female	40371.87	Silver
5482	28	Other	103940.95	Silver
7518	44	Other	72045.01	Gold
5819	46	Female	49921.94	Gold
8419	66	Male	48654.98	Bronze
3263	68	Female	26014.39	Platinum
7762	55	Other	116501.51	Silver
9393	46	Female	22389.67	Bronze
5897	26	Female	49664.35	Silver
9975	47	Male	99624.28	Platinum
4560	47	Other	81018.49	Gold
4291	25	Male	30914.91	Platinum
6657	50	Other	67650.97	Platinum
3173	62	Female	86803.30	Silver
3913	35	Male	62800.20	Platinum
9888	19	Female	90473.40	Platinum
6281	40	Female	91152.47	Bronze
2890	30	Other	102698.91	Gold
6771	62	Female	36317.31	Platinum
8870	37	Female	114512.99	Platinum
7839	43	Other	27929.06	Gold
9747	64	Other	36772.79	Silver
5684	39	Female	98965.86	Bronze
7920	58	Male	51313.05	Platinum
1209	46	Other	87499.05	Silver
2744	66	Female	22736.45	Platinum
1414	66	Other	32020.48	Platinum
3381	57	Other	35783.10	Bronze
1869	42	Female	48597.00	Bronze
1927	68	Other	119769.68	Bronze
4275	52	Other	57261.73	Gold
5695	62	Male	86421.62	Gold
2016	45	Female	60549.58	Gold
1529	50	Other	35329.98	Silver
8415	24	Male	35624.15	Gold
9370	43	Female	56708.32	Bronze
1769	28	Other	84276.35	Gold
7251	57	Male	83735.43	Silver
6122	23	Other	38964.34	Platinum
1881	66	Other	117124.28	Silver
1212	49	Female	63984.61	Silver
5117	48	Other	26711.19	Platinum
4327	66	Female	25107.75	Platinum
7025	67	Female	112110.27	Platinum
4218	38	Other	107930.02	Platinum
4170	33	Female	68357.94	Silver
3906	56	Female	70763.87	Bronze
2220	18	Female	72850.10	Platinum
9418	23	Female	97522.68	Bronze
2955	68	Female	65310.91	Bronze
1665	19	Other	40586.92	Gold
8020	20	Male	29300.91	Platinum
5572	48	Other	30282.45	Bronze
5329	62	Female	84703.28	Platinum
5178	33	Female	107550.47	Silver
1092	25	Male	75631.62	Silver
6415	51	Other	105371.96	Silver
8640	28	Female	89653.80	Platinum
1654	44	Other	30689.89	Silver
3518	31	Other	26258.38	Platinum
1833	58	Other	104193.44	Gold
6866	55	Female	68769.86	Platinum
2194	52	Male	52902.29	Silver
6207	49	Male	99681.43	Bronze
9608	61	Female	96130.33	Bronze
4603	65	Female	55942.23	Bronze
9529	31	Male	31957.23	Bronze
2117	29	Female	83056.50	Silver
9276	29	Female	62933.67	Platinum
7814	21	Female	40538.51	Silver
9798	50	Male	25703.05	Platinum
4624	32	Male	27903.49	Gold
4495	57	Female	105802.67	Bronze
6437	61	Male	118676.12	Silver
5809	48	Female	20956.87	Silver
4579	34	Other	24885.36	Silver
1144	41	Male	90689.12	Gold
2879	34	Female	26997.46	Platinum
6668	60	Other	77127.74	Silver
8301	62	Other	49139.64	Gold
4994	64	Male	52851.67	Platinum
6258	67	Male	53920.63	Silver
2857	48	Male	100998.11	Platinum
5203	46	Male	64420.17	Silver
9851	51	Male	20413.41	Gold
5633	49	Other	74193.05	Silver
1404	63	Female	61696.06	Platinum
9468	56	Other	113753.76	Platinum
7143	29	Male	26325.27	Silver
9426	36	Female	118313.00	Bronze
8300	69	Female	40525.54	Gold
8975	46	Other	28229.03	Silver
1718	70	Other	34172.96	Platinum
5856	61	Male	106053.88	Platinum
4154	64	Male	83339.12	Silver
6248	61	Male	37334.03	Silver
9419	47	Male	67085.96	Bronze
2349	70	Female	116482.06	Silver
2572	22	Female	39409.60	Silver
3742	47	Other	118539.96	Bronze
9814	37	Other	62355.21	Bronze
9736	19	Other	110133.98	Silver
2072	43	Male	106755.78	Platinum
7950	46	Male	29282.23	Bronze
2702	54	Female	34562.85	Silver
4368	67	Female	88540.94	Bronze
9810	54	Other	94758.58	Gold
8130	65	Male	108318.30	Bronze
2181	34	Other	110392.79	Platinum
3519	26	Female	90166.35	Silver
1389	18	Other	118184.36	Silver
8523	61	Other	119818.05	Platinum
6434	67	Female	32881.30	Bronze
1620	42	Male	58770.41	Silver
2433	25	Male	36237.04	Silver
3916	45	Other	118540.34	Bronze
5127	56	Male	119179.49	Gold
2154	52	Other	43210.46	Gold
4729	28	Other	34146.77	Gold
7357	42	Other	101919.78	Bronze
8094	53	Male	90485.29	Silver
1276	38	Female	119961.41	Platinum
2938	56	Male	30957.03	Gold
9762	31	Female	75098.04	Bronze
2189	51	Male	74324.77	Silver
6860	67	Male	39209.31	Silver
2738	54	Other	39185.86	Silver
5748	19	Other	54914.77	Platinum
5937	56	Other	70457.13	Bronze
2417	22	Female	87358.39	Bronze
7473	29	Female	64661.96	Gold
1504	23	Male	111850.95	Platinum
8765	28	Male	106166.00	Gold
3561	43	Male	72946.48	Gold
4602	38	Female	53127.41	Bronze
3234	69	Female	81965.60	Bronze
7406	63	Female	32456.55	Gold
9941	68	Other	72071.86	Silver
5832	53	Other	73378.08	Silver
3360	25	Other	92377.63	Gold
5883	41	Female	41335.24	Silver
7113	45	Other	32044.47	Silver
1182	48	Female	69157.83	Silver
3019	20	Male	33012.68	Gold
1684	29	Male	71879.57	Bronze
1082	42	Male	84309.16	Bronze
7456	28	Male	42505.35	Bronze
9800	28	Other	38308.93	Silver
9970	63	Male	89954.59	Bronze
2394	38	Male	65742.96	Gold
5992	66	Female	50618.82	Silver
4469	56	Other	67227.34	Gold
7760	30	Other	57245.23	Bronze
9397	30	Female	51889.71	Silver
3333	38	Other	100579.19	Bronze
3637	44	Female	22688.32	Bronze
4014	26	Female	112643.38	Platinum
4617	69	Other	88918.97	Platinum
4183	50	Female	55188.48	Silver
2877	36	Female	38289.40	Gold
3971	36	Male	118016.81	Platinum
1891	32	Other	112096.65	Bronze
9992	49	Male	62101.59	Platinum
8557	61	Male	103407.66	Bronze
2198	29	Other	24056.39	Platinum
5762	69	Other	67681.21	Gold
2103	52	Male	99654.67	Platinum
5107	29	Male	35814.57	Bronze
2608	50	Female	84096.88	Silver
4234	34	Male	78387.02	Bronze
6420	64	Other	47742.11	Gold
6851	24	Female	30514.87	Platinum
3100	28	Other	89005.86	Silver
2639	62	Female	67197.35	Platinum
5671	26	Male	75099.79	Silver
6206	34	Male	95085.77	Bronze
8960	33	Female	93964.49	Platinum
8383	29	Other	88846.48	Platinum
6379	20	Female	111522.03	Platinum
6008	54	Female	20054.67	Silver
6971	52	Female	115183.25	Gold
6182	28	Other	95086.19	Silver
8017	50	Male	50381.72	Platinum
1079	59	Other	48196.32	Platinum
8145	48	Female	65474.65	Gold
6889	43	Female	59649.14	Bronze
8863	45	Male	54528.49	Bronze
8583	69	Female	65101.75	Platinum
8296	60	Female	45570.46	Silver
6877	47	Male	47397.56	Silver
8978	31	Male	92362.71	Gold
2783	19	Male	32040.44	Silver
3879	30	Female	111742.20	Gold
5597	49	Other	79157.86	Bronze
5312	35	Female	109667.38	Bronze
2252	21	Female	61633.91	Platinum
1305	57	Other	107518.09	Gold
9309	31	Other	26013.10	Silver
1511	48	Male	29639.77	Platinum
7637	40	Other	34379.20	Platinum
1600	31	Other	100657.27	Platinum
9904	44	Other	106363.13	Silver
9842	61	Male	94446.64	Bronze
7430	51	Female	70800.34	Silver
4658	25	Other	77586.41	Platinum
5767	37	Other	43608.00	Bronze
3193	65	Male	119540.29	Bronze
9210	24	Female	67216.67	Gold
9362	63	Female	113894.94	Platinum
2483	56	Other	86350.10	Bronze
7500	65	Male	23512.45	Gold
6961	42	Male	40532.17	Bronze
9227	49	Male	106178.77	Bronze
1173	54	Male	46951.60	Bronze
4913	57	Other	77473.27	Bronze
3717	24	Female	103330.83	Gold
3299	36	Other	33025.25	Bronze
8310	70	Male	103662.88	Platinum
3935	22	Male	58024.59	Platinum
3395	57	Male	32635.79	Gold
1662	50	Other	92015.11	Platinum
8989	35	Male	79975.08	Platinum
4796	57	Other	44365.45	Platinum
4834	33	Other	97679.73	Gold
1701	68	Female	80911.98	Silver
9485	39	Other	52759.50	Gold
6918	23	Male	99731.98	Bronze
8695	34	Other	52810.39	Platinum
8448	20	Other	30340.71	Silver
1760	41	Male	78541.78	Silver
6309	52	Female	60914.27	Gold
2691	36	Female	26069.77	Silver
9542	66	Male	113424.81	Gold
5314	40	Other	98365.23	Gold
9918	58	Male	36119.00	Silver
6985	62	Female	85679.45	Platinum
9465	21	Other	118860.12	Platinum
5121	24	Female	79920.82	Gold
7165	21	Other	68545.86	Bronze
4651	47	Other	30489.71	Gold
9460	41	Female	113648.70	Platinum
7649	29	Male	82873.27	Gold
6653	46	Female	34929.17	Silver
8976	63	Female	108638.77	Bronze
8898	70	Male	66122.58	Platinum
9222	57	Female	46208.89	Silver
3276	48	Female	75799.43	Silver
8207	28	Female	75777.52	Gold
3713	26	Female	51147.25	Platinum
2263	48	Male	56351.12	Bronze
9430	68	Other	41221.19	Platinum
5600	64	Female	98358.46	Silver
4465	60	Male	91929.10	Platinum
3461	63	Male	56253.95	Silver
4062	38	Male	105850.99	Gold
4773	39	Male	49896.47	Silver
7793	57	Other	94547.25	Silver
6410	33	Female	88969.49	Bronze
2856	63	Male	78940.44	Gold
8889	69	Male	33040.54	Silver
8844	25	Other	73455.35	Bronze
4452	28	Female	98987.49	Gold
3641	66	Female	66184.24	Silver
1367	48	Male	79311.37	Bronze
4992	28	Male	45214.63	Silver
1706	41	Male	30504.29	Bronze
3095	35	Male	101636.57	Gold
3639	36	Female	74819.43	Silver
3207	61	Female	75143.93	Platinum
9399	67	Other	33730.25	Bronze
1642	54	Other	75220.15	Platinum
3406	69	Male	108777.83	Silver
5231	58	Male	55257.49	Gold
3949	18	Female	112769.59	Platinum
5644	46	Male	102297.50	Gold
4548	38	Female	88566.45	Platinum
8723	26	Male	63914.55	Platinum
8891	39	Other	89364.40	Bronze
3794	34	Male	54703.07	Silver
3338	48	Other	102661.74	Bronze
3747	57	Male	30028.29	Silver
4765	49	Female	104695.61	Platinum
7196	51	Other	40433.46	Gold
7315	30	Other	36099.30	Silver
3166	54	Male	22174.63	Silver
2778	18	Female	49230.47	Silver
1271	46	Other	37790.80	Silver
4315	38	Female	62004.70	Gold
9263	44	Other	37198.40	Gold
7877	30	Male	117267.47	Platinum
3450	52	Other	44039.77	Bronze
2577	18	Male	98024.56	Bronze
8796	45	Female	50523.15	Gold
1639	29	Male	28237.71	Gold
9706	43	Male	106045.27	Gold
2925	48	Other	70313.63	Bronze
8901	37	Other	112375.14	Platinum
3135	18	Male	79671.47	Bronze
1019	62	Male	95093.52	Gold
8069	55	Female	88715.79	Gold
9553	20	Male	37664.12	Bronze
7892	47	Male	51201.78	Gold
7068	31	Male	79629.75	Silver
8028	26	Female	107809.00	Gold
4759	28	Female	75917.12	Gold
8899	57	Female	43091.19	Bronze
5170	52	Male	98316.81	Bronze
8817	18	Other	28514.18	Platinum
4809	31	Female	98365.77	Platinum
2373	43	Female	66274.03	Bronze
5641	22	Other	78156.57	Gold
9908	36	Male	84534.14	Bronze
7695	58	Other	38452.93	Gold
5223	60	Male	66823.03	Platinum
4096	67	Other	39719.46	Bronze
1089	40	Female	43410.07	Bronze
1116	37	Male	61539.58	Bronze
2930	19	Male	42253.41	Silver
7144	29	Female	104195.16	Platinum
6175	23	Other	24862.62	Gold
6935	41	Other	28866.62	Platinum
7980	19	Male	111783.67	Platinum
5281	38	Other	21657.34	Bronze
9783	65	Male	41245.26	Bronze
5514	53	Female	76146.26	Gold
4337	22	Male	102474.60	Bronze
8904	35	Other	36645.85	Silver
3928	54	Female	33620.60	Platinum
8925	69	Male	94638.15	Gold
5157	26	Female	95781.14	Silver
6024	52	Other	99162.47	Bronze
7522	38	Male	114422.35	Platinum
2951	43	Male	29513.78	Gold
3650	26	Other	83873.07	Gold
2642	26	Female	53258.43	Silver
4513	55	Female	110791.22	Silver
7562	40	Other	54801.71	Gold
6544	22	Female	25122.89	Platinum
1852	23	Other	78908.43	Gold
3633	60	Female	77662.50	Gold
2492	37	Male	66150.48	Silver
8727	58	Other	22812.88	Gold
2444	30	Female	82777.71	Silver
5310	57	Other	89373.58	Gold
7075	52	Male	105222.52	Silver
7296	40	Male	90013.56	Bronze
7564	52	Male	30727.75	Platinum
9536	34	Male	102628.09	Gold
1941	20	Female	54357.71	Platinum
3871	48	Male	103916.10	Gold
8192	60	Female	36656.20	Silver
1175	68	Female	70366.23	Silver
9489	32	Male	113285.60	Platinum
5685	39	Female	25997.04	Platinum
4190	60	Male	72129.57	Bronze
9364	24	Male	100208.52	Silver
9451	49	Male	39511.76	Gold
4795	41	Other	25498.44	Platinum
3776	56	Other	68501.84	Platinum
6893	23	Other	63882.37	Bronze
1004	28	Male	48424.97	Bronze
2422	22	Other	69285.19	Gold
7544	52	Other	30747.02	Silver
6785	61	Female	29324.68	Platinum
7474	70	Male	47585.89	Platinum
2477	22	Female	32089.08	Bronze
5661	66	Female	69481.78	Platinum
6703	34	Male	95185.20	Silver
6693	46	Male	26421.36	Gold
7618	67	Female	92279.22	Platinum
5277	44	Male	79614.78	Gold
3867	39	Other	101654.58	Gold
7670	21	Male	66757.03	Gold
9294	51	Female	107589.15	Platinum
2185	63	Other	94504.43	Platinum
9243	56	Female	50117.58	Gold
5821	56	Other	106731.18	Bronze
6570	49	Male	81410.95	Bronze
2917	41	Female	81766.81	Gold
5222	50	Male	38319.89	Silver
5098	38	Other	39291.31	Platinum
8254	30	Male	93198.65	Silver
7178	48	Female	92107.05	Platinum
8923	55	Other	67647.36	Bronze
4985	56	Other	21350.72	Bronze
6565	60	Other	97354.54	Gold
8548	52	Other	105060.40	Platinum
1448	50	Male	109372.17	Bronze
8896	23	Other	75065.46	Gold
5224	63	Other	62171.35	Platinum
7269	50	Other	57714.00	Gold
4610	58	Other	104120.76	Gold
4767	20	Other	104355.30	Gold
6172	57	Other	118555.44	Gold
7757	43	Other	113559.53	Platinum
9776	24	Other	53058.59	Bronze
1159	54	Female	75263.10	Platinum
2523	53	Male	28486.41	Gold
7536	46	Female	118174.54	Bronze
6603	36	Male	64250.85	Silver
8807	63	Female	119699.28	Bronze
6142	48	Other	63340.90	Gold
6792	30	Male	33178.64	Silver
3994	23	Male	105090.22	Silver
9175	58	Other	30341.33	Silver
4847	50	Male	37254.49	Platinum
5348	38	Male	44988.73	Silver
4755	38	Male	112101.51	Gold
4322	47	Other	93386.11	Platinum
5091	36	Female	43402.43	Silver
6833	48	Male	59052.53	Bronze
3555	61	Male	34394.61	Platinum
2285	43	Male	102956.22	Silver
1692	58	Male	113105.92	Platinum
6167	65	Male	108995.83	Gold
9066	39	Male	111913.74	Silver
9374	60	Female	51761.77	Silver
5591	30	Other	46061.46	Platinum
4638	52	Other	51467.56	Bronze
3101	68	Male	94646.19	Gold
9613	44	Male	72489.34	Gold
7933	36	Other	45851.90	Platinum
8836	66	Female	112644.61	Bronze
9859	64	Male	43697.76	Bronze
1533	32	Female	79072.65	Platinum
9232	28	Male	48070.77	Platinum
6689	47	Male	94529.41	Silver
7450	63	Other	36814.35	Bronze
3863	41	Male	59885.61	Silver
8490	37	Other	61406.28	Platinum
2972	23	Other	41667.29	Silver
9490	22	Other	109382.51	Bronze
8537	64	Male	29577.41	Gold
6171	70	Male	116450.28	Platinum
1137	38	Male	72230.52	Silver
1193	45	Female	91457.80	Silver
2650	48	Male	43321.58	Bronze
6331	47	Other	47929.88	Platinum
6924	21	Female	90058.14	Platinum
5254	23	Male	81570.29	Silver
9987	40	Other	27944.16	Platinum
5306	70	Other	111599.10	Bronze
4885	42	Female	110177.03	Silver
5413	28	Male	77382.91	Silver
8722	42	Other	104428.47	Platinum
6621	43	Female	81719.72	Silver
4013	57	Male	67098.91	Bronze
7945	52	Other	28901.28	Platinum
4449	23	Male	56951.02	Silver
7099	21	Male	116388.15	Gold
6981	70	Male	84712.83	Bronze
8384	46	Other	22332.71	Gold
3148	55	Other	30440.62	Platinum
4744	27	Male	44250.11	Silver
2636	19	Other	116810.24	Bronze
4863	53	Male	87318.78	Silver
8081	38	Male	69256.56	Silver
4212	43	Female	100081.81	Silver
3389	33	Other	74095.58	Platinum
3893	64	Female	72447.63	Platinum
3203	35	Other	105387.47	Silver
9470	63	Female	25843.34	Platinum
9748	44	Female	25751.36	Gold
5111	43	Female	51954.99	Silver
1781	58	Other	49879.92	Gold
7527	37	Female	101565.73	Silver
2621	54	Male	25180.88	Platinum
3676	67	Female	84122.72	Gold
1983	30	Male	105618.99	Bronze
4530	28	Other	114420.78	Gold
8370	39	Other	47188.54	Bronze
6483	62	Female	90478.86	Gold
5256	70	Female	86665.30	Bronze
6914	52	Male	20374.06	Gold
6903	31	Male	108370.09	Silver
6638	51	Other	61627.70	Platinum
1324	30	Female	76705.42	Gold
7746	64	Other	113621.63	Platinum
2986	69	Other	109814.95	Bronze
4259	32	Female	94096.27	Gold
3859	23	Other	106165.14	Gold
5663	34	Other	72088.55	Silver
6326	33	Other	65514.58	Bronze
8987	27	Other	75869.88	Silver
8322	40	Female	22555.58	Silver
7243	50	Female	46308.84	Gold
5694	38	Male	31504.25	Platinum
3373	61	Male	119974.37	Silver
3745	28	Male	102211.10	Silver
6527	50	Female	61031.08	Bronze
7911	69	Female	87912.23	Platinum
7631	58	Male	114792.37	Bronze
2168	29	Male	69581.75	Bronze
2296	65	Female	119875.54	Silver
3654	18	Other	39084.08	Silver
4739	43	Other	83310.68	Gold
6136	45	Other	96123.17	Bronze
6191	45	Female	23217.07	Silver
7479	34	Male	42434.10	Platinum
8289	57	Other	96013.63	Gold
6950	46	Other	31589.38	Silver
9535	62	Male	79093.02	Silver
8377	67	Other	52971.05	Platinum
3741	20	Female	72685.84	Silver
1378	19	Male	64810.32	Gold
3048	19	Other	45837.45	Gold
4844	27	Other	57271.36	Gold
5122	52	Female	97655.61	Bronze
2687	31	Male	111491.07	Silver
9985	43	Other	68849.50	Platinum
1431	23	Female	111291.51	Platinum
2363	18	Female	67342.22	Gold
5300	63	Male	93672.76	Silver
3544	50	Other	110757.78	Gold
7387	43	Female	45665.15	Platinum
6068	68	Other	71492.01	Silver
4757	34	Male	109109.35	Silver
5053	37	Female	34896.31	Silver
3071	63	Female	28188.36	Bronze
3150	55	Female	23442.73	Platinum
9630	22	Female	91747.66	Platinum
3795	43	Male	98873.40	Platinum
1468	27	Other	30753.27	Platinum
1575	49	Other	51870.84	Platinum
6328	49	Other	113645.34	Bronze
8654	44	Female	68376.40	Silver
5463	18	Male	97775.09	Bronze
8288	64	Male	77256.66	Platinum
3213	56	Male	91225.65	Bronze
8480	66	Other	30397.91	Platinum
6073	66	Male	118873.84	Platinum
9841	26	Female	22712.29	Silver
4721	70	Male	104949.77	Silver
2467	54	Male	66624.21	Bronze
6044	41	Other	113817.13	Gold
7753	41	Female	100270.98	Platinum
3551	47	Female	78280.06	Silver
5973	38	Female	78944.02	Bronze
1001	28	Male	108878.42	Bronze
9574	48	Male	41054.79	Silver
3233	22	Female	83261.25	Silver
6634	55	Other	30838.92	Platinum
5698	47	Other	20798.85	Platinum
8687	43	Male	112418.05	Silver
1136	43	Female	27842.41	Gold
9059	25	Other	69348.30	Bronze
8816	42	Other	39796.05	Gold
5908	28	Male	119595.76	Silver
5799	56	Other	110641.09	Bronze
1118	68	Other	88869.97	Gold
9981	30	Other	89244.78	Bronze
4089	51	Female	91919.53	Bronze
7467	70	Female	70709.89	Bronze
5094	60	Female	70725.39	Gold
3675	21	Female	72582.36	Silver
7385	66	Male	71007.47	Bronze
4614	48	Other	43994.60	Platinum
2297	20	Female	57769.41	Silver
7917	25	Other	22148.88	Gold
4924	46	Male	26769.67	Silver
5454	66	Other	27737.13	Bronze
5664	36	Male	115206.02	Gold
5404	43	Other	25532.27	Gold
4080	52	Male	74083.94	Silver
3988	36	Male	80942.71	Bronze
3238	53	Male	100278.64	Platinum
5744	42	Female	67866.29	Gold
2808	34	Other	73560.61	Platinum
8418	25	Other	109224.14	Platinum
9060	65	Male	25830.06	Bronze
4076	38	Female	74688.81	Bronze
9764	30	Male	26142.73	Platinum
1362	24	Other	108645.10	Silver
4046	26	Male	72193.48	Silver
2675	31	Male	88779.62	Gold
5622	32	Female	105083.69	Gold
5410	25	Other	79358.34	Gold
1134	32	Female	65670.79	Silver
3468	49	Other	63671.11	Platinum
9086	29	Other	44699.89	Platinum
4558	24	Female	68984.65	Bronze
6601	49	Female	20099.95	Gold
7885	36	Male	39467.40	Gold
6104	22	Female	94054.84	Bronze
7084	19	Other	62410.48	Silver
8597	66	Other	71981.02	Bronze
3393	40	Other	40387.32	Platinum
1918	24	Female	93398.63	Silver
7429	24	Female	108799.57	Silver
3975	64	Female	116420.70	Platinum
4148	65	Male	101244.39	Bronze
1206	42	Male	65902.61	Platinum
2998	51	Male	33639.61	Bronze
5078	61	Other	46217.67	Platinum
8257	53	Other	60748.06	Silver
5049	29	Other	115318.59	Platinum
1549	30	Female	97947.43	Gold
2539	47	Male	69443.80	Platinum
9538	61	Male	84360.18	Platinum
4415	30	Male	58157.32	Platinum
8746	59	Female	29665.74	Platinum
6293	51	Male	73323.63	Bronze
3598	43	Female	62773.47	Bronze
1691	20	Female	46106.89	Gold
9534	28	Male	39731.64	Platinum
8884	36	Female	95444.71	Gold
4255	57	Other	114470.26	Gold
6316	59	Male	45989.32	Bronze
1246	60	Female	62316.12	Gold
5523	22	Other	63626.54	Platinum
2960	27	Female	105891.15	Gold
4982	60	Other	45018.40	Bronze
1146	56	Other	48346.20	Gold
1688	60	Other	83633.66	Platinum
8786	69	Other	103112.71	Silver
3539	54	Female	77928.26	Silver
2466	23	Female	41502.34	Platinum
5075	34	Male	64252.78	Bronze
3583	61	Other	78309.99	Bronze
9190	55	Female	65123.57	Silver
2497	63	Other	62430.60	Bronze
1979	26	Female	27367.64	Platinum
6824	38	Female	102341.10	Bronze
3521	30	Female	90276.68	Bronze
9787	39	Female	49939.70	Gold
2759	54	Female	75227.80	Gold
3061	41	Other	105051.11	Silver
8992	33	Male	63258.69	Platinum
4812	18	Other	109172.81	Bronze
6189	23	Male	27477.25	Platinum
6690	67	Other	55176.08	Bronze
8187	54	Female	102909.01	Bronze
4161	42	Male	109027.81	Platinum
7189	35	Female	33617.65	Bronze
6868	54	Female	87845.00	Platinum
8168	68	Other	44755.44	Bronze
5828	57	Female	118210.70	Platinum
9892	36	Other	72547.14	Bronze
9029	34	Female	44174.11	Platinum
4057	61	Male	90126.48	Platinum
9906	60	Female	24785.12	Platinum
6696	55	Female	98749.81	Gold
6303	54	Other	70169.77	Bronze
8674	24	Other	77675.85	Silver
5510	34	Other	63302.09	Bronze
2128	27	Female	37870.89	Platinum
8362	18	Male	28424.63	Gold
9873	58	Male	114671.33	Silver
7014	66	Female	22771.26	Silver
8439	31	Other	84177.61	Platinum
7210	60	Other	71935.22	Silver
4039	48	Other	105790.80	Gold
1306	18	Male	48737.46	Gold
6965	58	Male	80832.11	Platinum
6254	22	Other	69457.91	Platinum
7348	58	Female	47914.33	Silver
5638	22	Other	115075.03	Gold
7714	24	Other	53020.70	Platinum
6276	69	Male	105906.63	Silver
9572	36	Male	63516.69	Silver
2092	44	Male	45304.45	Platinum
3926	56	Female	60186.83	Gold
1512	48	Female	46054.16	Platinum
8952	23	Female	74345.52	Platinum
2617	21	Male	31037.17	Bronze
1521	51	Other	29015.15	Platinum
7366	36	Male	118179.85	Gold
9026	53	Other	78999.98	Bronze
9615	45	Female	104221.56	Bronze
1804	37	Male	50997.32	Platinum
7002	29	Female	84619.61	Bronze
4616	40	Other	76099.20	Gold
2161	61	Male	78256.51	Bronze
1214	39	Male	41318.72	Silver
4419	63	Other	103137.69	Silver
9051	45	Female	47208.89	Platinum
2310	63	Male	24011.16	Silver
1994	42	Male	36754.32	Silver
6913	70	Male	88163.54	Bronze
1955	28	Other	113958.09	Bronze
5355	57	Female	92342.95	Bronze
9667	21	Male	47113.00	Silver
1666	65	Other	117761.55	Gold
2153	59	Female	114995.05	Platinum
4537	35	Other	43195.24	Platinum
9511	36	Male	116203.41	Platinum
2658	24	Other	24261.40	Platinum
4784	47	Male	24370.69	Platinum
9710	23	Other	99186.34	Platinum
7313	19	Female	38126.91	Gold
4104	40	Male	34101.71	Bronze
9621	49	Other	80033.61	Gold
3931	56	Female	59175.18	Platinum
7802	64	Male	68187.45	Platinum
2728	27	Female	51992.10	Platinum
8515	31	Male	82402.00	Silver
7997	62	Male	76651.29	Silver
7579	66	Other	117999.69	Gold
9268	54	Female	80723.40	Silver
8258	42	Male	31711.62	Bronze
6163	61	Male	95745.66	Silver
6319	51	Other	50982.97	Bronze
7090	59	Female	38339.87	Silver
6299	63	Male	111460.15	Bronze
4504	66	Female	72899.15	Platinum
7145	51	Other	20401.61	Platinum
5162	67	Male	43232.50	Bronze
6898	67	Male	46960.75	Gold
8331	64	Female	90217.76	Bronze
1003	53	Other	95114.01	Platinum
\.


--
-- Data for Name: demandforecast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.demandforecast (forecast_date, store_id, product_id, forecasted_demand, actual_demand) FROM stdin;
2024-03-31	1	843	172	179
2024-07-28	2	135	109	484
2024-06-10	3	391	289	416
2024-08-15	1	710	174	446
2024-09-13	4	116	287	469
2024-07-06	5	630	294	265
2024-03-17	2	238	178	257
2024-07-22	3	409	165	264
2024-03-30	5	106	476	428
2024-06-17	4	407	395	400
2024-04-03	3	327	303	181
2024-06-19	1	319	270	185
2024-03-01	5	976	141	127
2024-06-24	1	422	273	446
2024-07-11	3	122	221	244
2024-05-02	2	890	433	294
2024-03-01	1	941	415	191
2024-06-26	5	806	348	418
2024-06-02	1	942	172	477
2024-07-21	1	382	362	451
2024-05-18	3	666	130	157
2024-02-06	2	623	315	507
2024-03-03	4	669	434	364
2024-01-30	4	684	146	330
2024-08-03	2	685	280	506
2024-07-17	2	258	392	369
2024-04-15	2	196	483	445
2024-07-27	1	138	495	153
2024-07-15	1	571	154	128
2024-02-06	5	464	297	306
2024-07-31	4	259	386	156
2024-06-13	4	241	316	255
2024-05-02	5	371	312	415
2024-05-08	3	475	158	398
2024-02-14	5	696	451	367
2024-08-28	5	355	165	421
2024-04-21	5	338	373	208
2024-03-30	5	362	279	423
2024-01-28	5	930	441	481
2024-02-25	2	407	290	505
2024-06-01	1	194	449	385
2024-02-13	5	684	472	142
2024-04-11	3	509	129	201
2024-06-27	3	682	182	268
2024-03-06	1	322	389	119
2024-04-26	5	851	248	348
2024-08-06	3	179	119	214
2024-09-06	3	840	311	170
2024-06-21	2	432	177	418
2024-07-23	2	911	484	192
2024-01-21	4	594	422	490
2024-07-21	3	277	357	164
2024-05-25	4	599	411	206
2024-04-03	1	945	451	435
2024-03-17	2	806	369	258
2024-05-21	5	819	171	392
2024-05-20	3	690	497	130
2024-05-22	1	939	235	463
2024-07-13	1	197	490	300
2024-07-08	5	709	117	415
2024-02-23	5	757	237	287
2024-05-23	5	407	177	427
2024-07-18	1	138	290	142
2024-08-09	4	848	464	118
2024-03-29	5	927	154	329
2024-05-13	4	690	256	236
2024-04-01	3	490	410	286
2024-06-22	4	180	349	238
2024-06-12	1	898	235	475
2024-03-18	5	157	309	219
2024-03-23	3	889	206	198
2024-03-18	1	442	488	404
2024-05-12	1	456	236	492
2024-09-13	5	936	393	408
2024-01-08	3	544	332	487
2024-01-17	4	526	260	161
2024-03-11	2	988	217	95
2024-06-04	1	223	268	506
2024-05-20	5	990	224	308
2024-06-20	4	888	334	152
2024-05-04	4	332	244	497
2024-01-29	1	865	390	124
2024-01-29	1	768	269	118
2024-09-05	4	969	164	227
2024-06-24	4	716	290	476
2024-01-18	2	111	195	429
2024-04-08	4	749	433	445
2024-03-07	4	896	274	372
2024-05-31	2	747	320	297
2024-09-16	5	491	106	254
2024-07-07	1	155	361	343
2024-01-18	4	412	362	364
2024-04-23	5	636	250	181
2024-03-17	5	142	350	407
2024-03-18	2	426	450	441
2024-02-26	2	652	437	250
2024-09-05	4	678	101	323
2024-02-23	2	253	348	362
2024-03-19	4	434	432	339
2024-08-07	3	614	144	335
2024-01-03	2	814	156	260
2024-02-12	2	326	337	257
2024-08-24	5	256	301	93
2024-02-26	3	151	206	323
2024-09-07	1	789	204	143
2024-03-24	4	849	321	353
2024-02-25	1	502	482	129
2024-04-05	1	556	293	436
2024-02-01	4	870	151	97
2024-05-13	2	709	383	181
2024-05-14	3	689	436	281
2024-07-08	3	616	433	264
2024-07-17	1	192	133	421
2024-05-28	4	327	288	456
2024-01-01	5	542	133	110
2024-02-23	3	396	272	367
2024-01-02	3	905	400	243
2024-04-01	4	503	250	477
2024-02-29	1	251	344	206
2024-07-06	2	235	174	173
2024-07-16	2	444	380	191
2024-02-11	4	184	235	238
2024-06-20	4	587	145	229
2024-01-06	5	685	192	386
2024-03-09	5	863	391	328
2024-03-23	5	150	263	490
2024-08-12	3	661	364	170
2024-08-22	3	508	285	341
2024-04-24	1	368	270	509
2024-06-14	5	187	490	269
2024-02-12	4	508	446	419
2024-04-15	4	613	207	278
2024-03-21	2	544	110	256
2024-06-11	2	892	111	310
2024-09-15	4	814	136	321
2024-02-05	5	233	391	509
2024-08-14	1	880	381	434
2024-03-16	4	238	207	453
2024-06-04	1	592	305	121
2024-02-20	3	672	196	337
2024-07-18	4	302	324	500
2024-04-30	1	599	301	121
2024-03-20	1	504	114	390
2024-08-31	1	767	116	133
2024-01-10	1	685	273	454
2024-01-09	4	300	362	419
2024-07-03	5	674	405	303
2024-07-24	5	730	252	128
2024-07-22	1	853	288	336
2024-04-21	3	636	279	111
2024-01-20	1	352	490	491
2024-03-27	4	348	139	362
2024-02-28	2	173	309	504
2024-03-13	3	372	115	470
2024-06-15	1	895	393	231
2024-04-09	4	540	135	312
2024-05-09	4	431	142	105
2024-01-31	1	801	337	401
2024-08-20	3	689	461	241
2024-09-07	2	191	415	487
2024-07-31	2	215	490	267
2024-07-25	4	787	242	292
2024-01-18	3	523	412	338
2024-05-26	3	533	480	276
2024-06-27	4	474	207	374
2024-01-05	5	456	368	100
2024-01-21	2	295	189	500
2024-06-12	4	428	198	420
2024-05-04	2	452	181	387
2024-08-16	2	708	460	473
2024-05-30	4	771	383	249
2024-08-04	4	124	331	369
2024-08-07	4	888	148	201
2024-02-05	4	412	279	440
2024-02-03	3	273	410	101
2024-07-24	1	458	476	123
2024-05-09	4	731	478	193
2024-04-12	3	941	277	192
2024-01-19	3	922	281	396
2024-01-01	1	552	231	263
2024-09-13	4	738	347	383
2024-05-10	4	249	157	111
2024-05-21	4	551	348	328
2024-06-27	1	145	275	436
2024-02-27	3	937	374	262
2024-02-06	1	339	254	241
2024-08-21	3	304	436	447
2024-01-21	4	801	325	462
2024-08-08	5	482	125	133
2024-03-13	3	259	138	127
2024-05-07	3	875	396	376
2024-04-21	2	845	490	486
2024-08-25	3	973	350	187
2024-07-06	4	187	369	168
2024-08-17	3	215	381	235
2024-04-20	3	857	153	148
2024-08-12	5	155	147	100
2024-01-01	2	348	116	452
2024-02-09	3	735	396	157
2024-06-24	5	251	113	478
2024-05-21	3	989	463	229
2024-06-02	2	952	407	306
2024-05-22	4	939	106	240
2024-09-12	4	394	491	95
2024-07-21	2	114	440	283
2024-05-18	1	451	256	204
2024-05-25	5	810	202	239
2024-05-16	1	923	227	403
2024-08-19	3	213	355	358
2024-03-13	1	412	130	508
2024-07-21	1	560	295	415
2024-03-02	4	582	137	415
2024-03-21	3	123	413	399
2024-01-07	2	439	329	116
2024-02-09	1	314	377	422
2024-01-26	3	857	328	218
2024-02-10	3	650	194	122
2024-09-16	5	316	384	401
2024-05-18	2	308	454	110
2024-04-04	4	659	188	459
2024-04-25	3	635	429	161
2024-03-24	3	868	149	275
2024-07-16	1	364	333	137
2024-01-10	5	661	247	141
2024-06-26	4	594	348	380
2024-07-14	1	737	346	96
2024-08-07	5	847	417	162
2024-07-06	3	244	221	241
2024-03-21	2	811	461	232
2024-01-20	1	815	213	130
2024-09-10	2	784	301	186
2024-09-06	2	118	326	291
2024-02-06	1	485	320	451
2024-04-25	3	696	145	131
2024-08-06	4	779	156	305
2024-07-21	1	639	447	329
2024-09-02	2	144	355	160
2024-09-08	2	361	400	310
2024-08-22	1	274	456	358
2024-05-22	5	161	314	424
2024-02-05	2	390	159	334
2024-07-07	4	305	308	330
2024-01-25	1	908	461	183
2024-05-08	4	813	471	90
2024-07-06	3	732	326	475
2024-06-19	1	377	320	426
2024-03-17	5	154	292	343
2024-01-17	3	576	343	456
2024-07-08	5	770	453	468
2024-03-30	4	108	153	377
2024-01-20	2	168	282	496
2024-03-26	4	497	341	217
2024-03-28	2	776	154	413
2024-03-11	5	377	365	155
2024-02-25	3	778	335	238
2024-04-27	5	972	161	366
2024-08-03	3	775	387	201
2024-06-20	5	468	172	271
2024-03-18	4	985	123	299
2024-07-21	2	210	162	504
2024-08-06	2	119	326	148
2024-01-25	3	399	373	141
2024-09-08	5	988	362	288
2024-09-12	3	764	219	460
2024-05-09	5	495	348	443
2024-03-22	5	336	272	411
2024-07-29	2	489	380	152
2024-08-12	4	620	350	320
2024-01-30	3	826	267	203
2024-07-24	1	201	254	209
2024-05-06	2	423	260	421
2024-01-29	1	596	402	352
2024-03-28	4	987	292	329
2024-06-03	1	711	143	443
2024-02-21	4	644	446	136
2024-05-22	2	190	388	379
2024-07-13	2	290	124	151
2024-07-05	3	303	180	354
2024-07-26	4	612	186	482
2024-04-21	4	568	353	212
2024-06-25	3	674	406	349
2024-03-23	4	829	225	328
2024-02-20	3	122	252	371
2024-07-05	4	140	461	214
2024-04-04	4	353	317	186
2024-08-30	5	642	341	177
2024-04-25	2	412	254	313
2024-09-16	2	441	366	351
2024-04-22	2	601	454	333
2024-05-04	4	502	371	458
2024-05-22	2	862	267	299
2024-05-02	1	260	158	500
2024-06-24	1	118	378	199
2024-04-19	4	455	361	320
2024-07-30	3	800	279	328
2024-03-12	5	460	144	212
2024-06-14	3	463	196	119
2024-02-07	1	740	296	293
2024-07-03	2	409	213	106
2024-05-25	5	341	315	467
2024-05-25	1	613	182	189
2024-04-17	3	382	139	292
2024-04-01	5	931	209	447
2024-06-08	5	163	351	150
2024-02-06	5	740	416	337
2024-03-27	5	363	301	378
2024-08-15	2	999	412	157
2024-04-29	4	496	203	355
2024-01-17	4	934	151	305
2024-04-01	5	130	149	94
2024-05-27	4	668	351	439
2024-08-31	1	386	345	247
2024-03-28	5	330	201	318
2024-08-23	1	255	261	328
2024-01-15	3	449	275	211
2024-04-05	5	502	277	156
2024-01-12	4	772	315	338
2024-08-09	3	240	218	452
2024-07-22	1	189	294	269
2024-07-09	3	847	391	182
2024-09-02	1	491	206	358
2024-05-14	4	633	231	413
2024-01-13	4	794	346	462
2024-09-07	1	727	461	354
2024-01-25	4	993	392	169
2024-06-21	2	740	445	485
2024-04-14	1	802	236	95
2024-01-11	2	332	228	393
2024-04-24	2	527	125	266
2024-03-12	5	346	459	117
2024-07-02	4	686	199	407
2024-08-10	5	256	205	328
2024-03-06	3	536	224	246
2024-02-19	3	419	313	393
2024-08-04	2	719	332	402
2024-01-21	3	437	120	446
2024-04-27	4	559	186	92
2024-08-01	3	655	297	259
2024-04-07	3	234	152	349
2024-05-24	4	311	458	111
2024-04-01	1	768	203	380
2024-08-19	1	241	355	375
2024-04-05	2	694	302	411
2024-08-17	3	654	134	330
2024-01-20	5	800	131	120
2024-02-22	3	919	214	415
2024-05-04	2	307	264	326
2024-06-22	4	983	193	486
2024-02-06	5	241	196	482
2024-02-18	2	416	420	394
2024-02-27	4	805	209	125
2024-08-07	5	822	141	397
2024-01-05	4	636	407	481
2024-09-01	1	238	105	136
2024-08-02	4	540	352	480
2024-05-04	3	888	458	411
2024-03-29	4	248	188	272
2024-06-17	4	771	402	473
2024-08-23	5	678	339	359
2024-04-23	4	261	100	373
2024-03-24	5	425	159	201
2024-07-20	1	169	116	220
2024-08-27	5	670	227	273
2024-05-09	2	645	492	183
2024-04-12	1	836	440	223
2024-03-26	2	221	220	250
2024-04-29	2	288	363	231
2024-07-11	4	425	390	298
2024-09-13	5	959	255	328
2024-01-29	2	249	380	442
2024-05-24	1	844	111	339
2024-05-19	5	130	221	262
2024-05-06	2	883	343	166
2024-02-03	2	426	200	137
2024-02-03	4	523	305	97
2024-06-07	4	521	133	361
2024-02-29	3	410	102	182
2024-01-07	3	553	140	496
2024-02-24	1	863	379	142
2024-05-17	1	941	125	391
2024-07-05	1	752	159	142
2024-01-02	3	856	410	234
2024-06-10	5	380	456	199
2024-07-21	2	255	317	493
2024-05-24	2	897	173	437
2024-08-07	4	292	179	369
2024-07-30	4	209	309	418
2024-08-21	1	234	106	99
2024-08-28	4	289	444	179
2024-09-03	5	126	483	102
2024-02-21	3	880	383	362
2024-06-26	1	726	143	405
2024-09-04	5	731	459	483
2024-09-08	4	373	397	301
2024-06-15	1	720	273	336
2024-05-05	5	680	452	495
2024-01-17	5	727	460	148
2024-04-01	4	336	401	509
2024-07-03	3	710	479	406
2024-07-26	5	337	383	139
2024-01-16	5	336	287	485
2024-02-08	4	803	155	464
2024-01-11	3	126	364	392
2024-07-05	5	467	323	480
2024-04-20	4	181	330	144
2024-01-28	5	804	488	298
2024-01-16	4	898	298	115
2024-01-15	1	588	306	392
2024-05-14	2	237	349	149
2024-07-05	1	614	253	492
2024-08-06	3	966	392	159
2024-04-17	4	719	425	288
2024-01-18	1	580	270	375
2024-07-22	3	829	156	384
2024-05-31	1	765	210	314
2024-01-29	2	482	238	495
2024-03-06	5	288	483	502
2024-04-10	2	972	410	263
2024-05-10	3	496	386	213
2024-03-13	1	603	275	387
2024-04-20	3	585	419	465
2024-08-17	4	240	373	435
2024-08-10	2	267	170	256
2024-06-19	4	297	334	201
2024-01-05	3	331	424	157
2024-05-08	3	133	213	176
2024-06-29	5	518	168	337
2024-03-19	3	882	206	102
2024-02-15	3	115	334	462
2024-05-03	1	376	328	371
2024-09-16	2	522	315	311
2024-03-16	4	327	447	266
2024-05-17	2	860	458	349
2024-08-09	1	787	381	177
2024-01-18	5	307	212	329
2024-08-25	1	875	184	131
2024-03-23	5	309	452	460
2024-03-23	2	167	307	197
2024-06-07	5	281	375	455
2024-07-25	4	549	382	211
2024-09-11	1	987	485	301
2024-03-24	1	731	305	336
2024-07-20	2	601	188	310
2024-05-18	4	804	162	506
2024-04-28	3	432	464	389
2024-08-19	2	987	394	276
2024-03-21	5	568	474	153
2024-05-01	4	352	243	392
2024-02-10	4	537	297	244
2024-05-27	1	514	160	406
2024-08-20	3	894	480	152
2024-04-25	1	142	132	383
2024-06-23	1	722	110	509
2024-03-15	3	852	299	378
2024-07-18	3	944	471	409
2024-06-03	3	489	274	305
2024-08-22	5	837	104	445
2024-02-28	1	420	431	241
2024-02-15	1	503	461	416
2024-04-12	1	726	375	357
2024-02-25	3	860	191	152
2024-03-03	1	685	278	489
2024-02-17	2	708	463	403
2024-01-20	5	649	334	150
2024-05-21	2	637	186	414
2024-03-03	2	756	446	494
2024-01-06	5	996	302	252
2024-07-22	4	821	412	398
2024-08-26	3	905	316	342
2024-04-22	4	139	336	344
2024-01-29	5	633	341	353
2024-03-16	3	211	246	131
2024-09-01	2	562	269	460
2024-03-17	4	567	314	219
2024-05-21	1	946	264	292
2024-07-04	1	998	444	280
2024-07-18	5	143	358	475
2024-03-22	5	998	400	375
2024-04-14	3	351	388	405
2024-07-17	2	631	311	324
2024-08-07	2	650	484	480
2024-04-07	5	505	101	197
2024-07-16	2	852	227	323
2024-02-02	1	140	477	273
2024-05-07	1	671	434	504
2024-08-17	1	496	205	113
2024-06-28	4	628	277	324
2024-07-23	4	883	322	100
2024-01-08	2	745	203	92
2024-03-28	2	150	484	336
2024-03-05	5	294	229	450
2024-07-22	1	398	382	357
2024-03-20	2	550	211	178
2024-03-01	2	507	327	356
2024-04-15	3	411	491	148
2024-07-06	4	892	419	391
2024-09-03	3	947	474	462
2024-02-23	3	392	291	344
2024-04-26	5	572	185	260
2024-08-31	2	270	218	397
2024-02-10	5	532	198	388
2024-05-21	4	401	317	156
2024-03-27	1	727	403	414
2024-05-01	1	155	460	187
2024-04-21	5	806	410	463
2024-01-14	3	629	331	96
2024-08-05	3	245	476	218
2024-04-12	5	574	147	301
2024-04-18	2	949	328	265
2024-06-17	4	761	244	470
2024-01-23	2	562	289	362
2024-06-01	2	192	102	348
2024-06-03	5	839	217	310
2024-06-16	5	612	213	201
2024-09-06	2	215	272	384
2024-02-27	1	284	351	216
2024-09-06	3	897	455	136
2024-08-25	2	699	142	182
2024-04-28	5	812	352	246
2024-08-13	1	659	334	366
2024-02-21	3	238	175	318
2024-04-06	5	502	311	429
2024-06-25	5	523	293	500
2024-01-19	3	431	414	103
2024-03-13	2	561	149	456
2024-03-05	2	125	300	408
2024-09-01	5	283	244	331
2024-03-12	1	564	295	467
2024-05-17	2	704	192	183
2024-05-11	5	829	192	107
2024-06-01	4	306	131	483
2024-07-19	1	565	274	295
2024-05-01	2	192	421	359
2024-07-16	5	356	314	363
2024-08-03	3	431	491	471
2024-03-20	1	808	157	122
2024-03-18	5	764	281	433
2024-05-01	5	828	410	241
2024-02-13	1	915	400	327
2024-06-25	2	267	357	397
2024-03-01	5	835	440	349
2024-01-29	3	850	484	238
2024-03-12	3	226	117	488
2024-04-08	1	193	428	186
2024-02-06	3	216	213	505
2024-07-01	4	823	352	145
2024-01-19	2	560	287	424
2024-02-04	1	749	497	181
2024-08-06	3	471	175	489
2024-07-25	4	187	213	293
2024-07-24	4	636	478	239
2024-04-29	1	824	129	336
2024-06-16	4	493	464	509
2024-03-03	2	844	219	216
2024-01-07	1	910	422	375
2024-01-06	1	623	436	434
2024-08-29	2	726	417	508
2024-08-12	3	263	206	313
2024-05-30	3	487	487	357
2024-03-14	3	663	139	352
2024-02-08	2	489	148	92
2024-08-12	1	144	112	377
2024-05-23	5	886	174	143
2024-06-20	3	274	296	154
2024-04-26	5	443	458	299
2024-05-18	1	679	228	472
2024-06-07	2	992	201	435
2024-08-23	4	775	155	135
2024-06-18	2	983	347	355
2024-08-15	2	253	408	507
2024-04-17	1	266	436	432
2024-01-21	2	989	288	91
2024-07-28	4	248	451	325
2024-04-28	3	283	372	379
2024-05-25	2	887	173	109
2024-04-06	1	829	467	113
2024-01-27	3	152	489	315
2024-01-18	5	529	278	316
2024-05-16	1	415	173	242
2024-06-30	3	416	192	355
2024-03-09	2	847	182	268
2024-04-11	3	887	493	144
2024-08-26	3	556	409	505
2024-09-13	4	395	389	423
2024-04-02	4	741	134	106
2024-03-11	1	285	477	129
2024-09-10	1	220	158	321
2024-07-19	5	234	441	437
2024-02-15	3	307	497	254
2024-07-12	3	103	373	144
2024-04-27	1	737	451	312
2024-08-24	5	883	237	323
2024-08-29	2	359	126	286
2024-09-09	5	112	102	490
2024-04-25	1	569	168	426
2024-04-12	5	609	284	370
2024-08-30	1	975	175	216
2024-08-06	4	610	116	240
2024-06-01	1	656	352	483
2024-09-08	3	926	236	155
2024-05-12	3	105	198	284
2024-02-09	3	722	481	405
2024-01-21	1	605	246	460
2024-02-11	4	343	322	506
2024-05-17	4	322	239	456
2024-03-03	5	702	374	91
2024-03-06	3	775	432	214
2024-02-16	5	587	163	276
2024-01-15	3	564	358	383
2024-03-11	1	519	307	133
2024-06-10	1	552	472	128
2024-06-27	3	181	369	117
2024-07-04	1	715	231	136
2024-07-20	5	714	165	233
2024-03-29	3	106	283	135
2024-03-25	5	350	303	254
2024-01-18	1	660	210	176
2024-04-28	1	384	327	93
2024-04-06	2	734	462	205
2024-02-08	3	743	397	351
2024-02-07	3	670	401	348
2024-01-12	4	939	336	166
2024-06-06	3	945	484	381
2024-08-28	5	312	490	171
2024-05-23	2	150	220	300
2024-03-22	3	289	375	258
2024-01-06	5	251	383	316
2024-03-18	4	156	110	151
2024-05-02	4	768	281	295
2024-01-31	1	457	186	164
2024-03-19	3	137	382	129
2024-03-01	3	248	275	199
2024-08-03	3	974	102	95
2024-05-05	1	133	415	223
2024-08-16	2	783	470	478
2024-08-13	3	691	499	474
2024-05-27	3	958	308	236
2024-02-19	1	717	278	119
2024-07-10	1	405	302	235
2024-04-18	5	439	376	353
2024-06-15	5	189	294	373
2024-01-15	1	150	261	417
2024-07-31	2	211	158	315
2024-03-24	2	526	378	238
2024-08-23	4	282	419	290
2024-03-02	4	265	109	394
2024-03-05	3	788	164	311
2024-01-06	3	391	498	140
2024-05-03	4	725	444	489
2024-07-26	4	776	455	93
2024-07-03	4	808	248	422
2024-05-14	4	816	326	254
2024-08-15	3	709	186	392
2024-07-03	3	686	212	407
2024-01-22	1	906	184	123
2024-05-06	2	675	212	178
2024-03-16	3	281	365	214
2024-04-20	3	566	372	341
2024-07-10	5	867	330	300
2024-07-08	2	692	329	330
2024-07-22	2	468	316	333
2024-01-22	1	136	394	159
2024-02-21	4	195	219	345
2024-06-24	2	886	401	457
2024-03-14	3	406	418	106
2024-08-03	1	430	364	256
2024-03-12	2	477	129	322
2024-03-15	4	488	301	492
2024-06-13	1	939	365	355
2024-08-01	4	169	168	465
2024-07-03	1	876	133	313
2024-09-05	5	537	209	267
2024-05-24	5	963	175	265
2024-07-08	4	663	286	444
2024-04-13	5	166	268	501
2024-04-12	3	399	138	168
2024-07-10	3	582	333	92
2024-06-12	3	237	102	257
2024-04-06	1	224	391	227
2024-09-12	3	811	162	375
2024-07-26	1	980	285	201
2024-05-22	3	381	395	325
2024-04-09	1	437	443	502
2024-02-05	4	639	211	488
2024-03-19	4	523	133	248
2024-02-26	3	637	298	294
2024-03-12	5	314	248	400
2024-09-04	4	812	408	457
2024-07-03	4	314	427	437
2024-07-18	2	726	199	112
2024-02-24	2	159	470	307
2024-09-05	1	211	337	477
2024-02-22	3	685	376	244
2024-01-23	4	847	130	344
2024-07-16	4	744	371	486
2024-03-12	5	641	283	301
2024-03-12	2	189	112	218
2024-05-11	3	595	340	120
2024-03-19	3	841	407	280
2024-07-15	1	805	126	405
2024-04-08	2	719	434	90
2024-04-18	3	907	115	487
2024-04-09	5	823	371	416
2024-04-29	2	394	423	443
2024-02-15	4	723	462	225
2024-03-11	4	968	231	96
2024-08-31	3	424	482	449
2024-01-29	1	365	135	372
2024-06-21	5	638	267	504
2024-08-13	4	688	353	217
2024-07-10	3	738	194	186
2024-06-17	5	462	173	466
2024-07-17	2	232	148	466
2024-08-30	2	729	417	289
2024-05-07	4	676	315	389
2024-01-18	2	608	415	165
2024-05-13	4	632	199	128
2024-05-28	4	846	385	260
2024-08-15	3	747	150	437
2024-05-18	2	609	443	160
2024-05-08	5	604	105	299
2024-04-30	3	927	186	110
2024-05-20	3	284	162	423
2024-08-13	5	724	112	295
2024-08-27	2	338	183	498
2024-09-03	3	825	276	242
2024-08-26	5	397	145	247
2024-05-29	4	298	367	433
2024-09-05	5	101	262	141
2024-08-13	5	221	365	306
2024-05-17	3	124	182	161
2024-05-01	3	576	481	184
2024-02-28	3	740	216	95
2024-07-09	3	915	343	189
2024-02-12	1	220	408	223
2024-06-28	2	855	151	282
2024-09-13	3	968	382	365
2024-05-29	3	312	287	417
2024-09-02	3	918	386	235
2024-03-31	1	730	233	207
2024-07-03	3	524	320	357
2024-08-17	3	523	335	432
2024-01-11	4	146	365	392
2024-09-07	2	441	239	263
2024-05-28	5	458	192	218
2024-04-06	4	673	493	344
2024-09-08	1	925	346	318
2024-09-08	2	752	181	459
2024-01-01	2	317	141	129
2024-06-14	3	111	423	420
2024-01-28	4	755	330	287
2024-04-10	4	306	427	486
2024-08-31	4	806	408	106
2024-02-06	1	388	359	224
2024-09-12	5	360	179	359
2024-05-19	1	909	275	105
2024-05-06	1	169	122	278
2024-08-02	3	415	336	329
2024-01-26	5	407	269	210
2024-07-03	3	618	213	257
2024-02-10	1	663	185	368
2024-02-12	5	431	105	346
2024-06-10	5	885	441	224
2024-01-21	1	106	494	225
2024-07-16	4	216	493	266
2024-08-06	5	802	459	225
2024-04-26	3	441	373	374
2024-09-16	2	449	140	153
2024-04-06	5	505	260	154
2024-07-30	4	841	408	249
2024-03-25	5	682	213	297
2024-02-24	3	730	424	138
2024-04-25	3	129	341	433
2024-02-23	4	952	206	505
2024-04-05	1	279	237	490
2024-05-25	3	298	124	256
2024-08-28	2	438	160	325
2024-07-05	5	953	436	113
2024-02-24	1	446	201	389
2024-03-16	4	788	470	363
2024-06-19	1	590	219	157
2024-08-24	2	585	283	333
2024-09-09	2	916	336	157
2024-08-15	4	136	244	380
2024-08-04	1	761	431	93
2024-02-07	4	239	311	359
2024-01-18	5	593	268	380
2024-08-18	1	259	206	177
2024-04-23	2	742	314	391
2024-02-13	5	571	289	105
2024-05-24	4	985	181	198
2024-05-15	5	649	462	151
2024-07-05	1	443	124	476
2024-06-05	1	573	465	371
2024-02-17	1	902	275	364
2024-07-19	1	933	483	144
2024-07-04	1	523	225	186
2024-08-19	3	860	392	274
2024-01-10	5	157	119	276
2024-02-11	5	955	291	483
2024-09-13	5	633	123	480
2024-03-05	3	406	237	367
2024-02-29	3	678	440	423
2024-02-29	1	842	271	138
2024-03-05	2	794	359	100
2024-04-11	1	423	106	441
2024-05-18	5	668	244	436
2024-07-15	5	648	332	503
2024-01-15	5	119	114	204
2024-08-05	3	313	394	483
2024-08-09	2	691	181	381
2024-05-03	2	801	376	118
2024-01-06	5	439	377	384
2024-02-14	2	918	397	364
2024-02-10	4	914	207	361
2024-01-01	3	462	124	91
2024-02-21	5	167	262	456
2024-02-20	5	252	399	208
2024-09-06	1	387	412	177
2024-09-04	2	960	326	492
2024-02-07	2	131	284	417
2024-05-23	2	447	261	273
2024-05-06	1	484	402	241
2024-03-20	4	741	282	174
2024-05-06	2	647	491	348
2024-08-03	4	962	421	309
2024-05-11	1	269	133	479
2024-04-08	5	684	167	471
2024-01-25	2	720	138	243
2024-03-19	5	498	496	417
2024-02-07	2	291	187	439
2024-02-16	1	709	356	225
2024-08-04	1	219	305	220
2024-05-14	4	985	442	402
2024-09-13	1	901	398	500
2024-06-14	2	869	379	241
2024-08-25	5	415	178	337
2024-08-04	1	822	473	488
2024-07-26	1	978	120	297
2024-02-10	1	422	186	428
2024-01-24	2	826	285	432
2024-01-11	1	132	249	419
2024-08-28	3	378	182	310
2024-06-28	3	523	123	425
2024-07-29	4	188	109	135
2024-03-21	1	608	214	241
2024-01-22	5	998	143	183
2024-02-28	4	343	274	259
2024-02-16	4	480	111	361
2024-03-17	4	562	353	259
2024-07-25	4	949	357	338
2024-02-25	2	409	117	403
2024-09-09	3	321	144	213
2024-03-10	2	637	489	245
2024-01-14	5	409	275	325
2024-07-26	1	279	303	117
2024-01-08	2	214	142	385
2024-07-18	3	483	306	317
2024-06-17	1	903	468	268
2024-06-27	5	138	490	137
2024-05-26	2	896	229	162
2024-02-23	3	306	436	220
2024-01-03	2	194	456	127
2024-08-24	4	554	160	420
2024-01-03	4	618	205	316
2024-01-04	3	125	140	495
2024-02-28	4	918	437	476
2024-02-26	3	594	378	400
2024-09-14	2	612	240	248
2024-08-19	4	257	357	180
2024-01-12	3	294	442	510
2024-06-21	3	448	118	237
2024-05-17	5	595	202	260
2024-04-06	3	850	166	110
2024-02-04	4	994	359	391
2024-01-29	1	636	175	161
2024-08-01	2	417	163	113
2024-09-16	2	894	476	212
2024-03-13	4	435	245	121
2024-02-26	1	246	164	134
2024-05-23	4	887	348	409
2024-04-09	4	992	348	269
2024-08-12	2	200	379	176
2024-05-03	4	941	140	494
2024-05-09	1	628	117	160
2024-02-04	3	792	356	366
2024-08-16	1	235	244	264
2024-01-28	5	310	317	90
2024-04-01	1	841	376	464
2024-07-24	4	137	229	444
2024-06-06	4	570	440	165
2024-08-15	3	496	174	491
2024-05-29	3	830	270	243
2024-03-08	1	985	155	324
2024-07-06	1	634	296	141
2024-08-11	2	218	377	275
2024-01-18	3	104	209	175
2024-06-01	4	418	478	343
2024-01-02	1	145	151	498
2024-07-17	4	803	109	283
2024-04-02	5	968	380	215
2024-03-23	3	708	251	452
2024-03-15	3	992	303	287
2024-09-16	4	189	276	284
2024-07-07	1	441	295	358
2024-06-25	2	578	447	508
2024-01-30	1	147	235	337
2024-04-16	1	205	421	102
2024-09-13	3	633	464	389
2024-01-10	2	884	193	372
2024-05-28	5	774	198	389
2024-02-20	3	863	190	95
2024-02-05	3	419	258	236
2024-03-28	4	123	475	271
2024-05-14	4	691	289	111
2024-09-14	3	876	228	366
2024-05-11	2	419	265	190
2024-02-11	2	754	230	505
2024-03-02	1	314	144	407
2024-05-05	3	428	461	218
2024-03-18	5	305	410	331
2024-08-03	2	297	141	182
2024-01-20	4	393	206	510
2024-04-03	1	383	273	117
2024-03-26	5	645	500	327
2024-02-27	1	426	251	305
2024-01-12	1	891	289	384
2024-07-12	4	551	468	276
2024-05-04	3	787	256	192
2024-08-30	1	220	194	502
2024-06-05	4	379	195	294
2024-09-15	4	252	326	367
2024-09-06	4	261	172	493
2024-03-20	1	380	305	404
2024-01-24	5	217	157	167
2024-07-20	5	115	380	185
2024-09-01	1	737	224	174
2024-07-23	2	673	172	360
2024-03-11	2	626	369	382
2024-09-11	1	204	257	441
2024-08-28	2	311	471	349
2024-03-23	2	655	382	329
2024-09-05	2	458	389	357
2024-04-14	3	662	202	188
2024-03-22	4	426	281	491
2024-08-28	1	377	389	182
2024-08-13	4	244	399	286
2024-03-31	2	821	433	386
2024-03-16	2	923	357	335
2024-03-14	5	390	291	112
2024-03-13	2	687	157	203
2024-05-30	4	350	130	491
2024-08-01	2	275	490	297
2024-01-05	2	172	146	328
2024-06-16	4	418	333	272
2024-07-15	1	727	340	419
2024-03-22	3	446	133	346
2024-08-05	5	653	163	358
2024-03-05	4	554	242	122
2024-06-17	5	151	321	198
2024-05-25	2	233	329	276
2024-08-04	1	129	172	178
2024-07-06	4	582	302	508
2024-03-17	4	791	261	371
2024-07-12	3	151	472	435
2024-06-12	1	208	340	269
2024-01-19	3	492	409	407
2024-03-21	4	155	197	105
2024-09-12	1	188	355	337
2024-05-14	2	536	190	303
2024-05-29	5	501	464	272
2024-08-29	3	283	476	395
2024-06-02	3	821	153	479
2024-08-14	3	710	383	272
2024-07-17	1	706	477	252
2024-09-01	4	744	344	379
2024-05-18	3	956	476	119
2024-06-23	4	806	348	119
2024-06-15	4	816	433	393
2024-02-05	3	556	227	271
2024-08-17	4	731	279	199
2024-03-13	1	464	415	386
2024-07-15	4	419	284	452
2024-07-27	1	440	450	350
2024-08-15	5	937	104	240
2024-01-26	5	302	359	418
2024-04-05	3	830	241	398
2024-02-03	3	876	462	500
2024-02-09	5	786	456	335
2024-04-02	2	928	405	94
2024-06-20	4	646	214	241
2024-07-11	4	180	294	332
2024-04-29	4	873	247	121
2024-07-25	3	882	321	456
2024-07-05	3	576	294	203
2024-06-11	1	681	412	458
2024-05-03	3	234	307	234
2024-04-25	2	195	119	91
2024-07-05	4	932	158	261
2024-02-04	2	921	345	158
2024-03-11	2	815	256	440
2024-04-13	4	579	102	387
2024-06-15	5	199	389	494
2024-05-24	3	566	294	226
2024-08-01	4	417	292	125
2024-08-21	5	800	316	387
2024-01-14	3	759	193	146
2024-04-03	4	827	178	502
2024-06-22	3	884	227	234
2024-06-28	2	576	237	260
2024-01-09	3	581	312	364
2024-04-30	3	337	164	502
2024-01-01	2	329	393	407
2024-01-31	5	247	476	179
2024-06-10	5	981	450	409
2024-05-22	3	731	330	321
2024-07-19	2	364	404	105
2024-08-05	5	472	157	419
2024-03-03	1	501	269	365
2024-01-21	4	287	160	491
2024-05-21	4	816	463	176
2024-02-21	3	781	470	419
2024-08-29	4	438	234	450
2024-07-29	5	907	198	106
2024-02-11	3	981	113	298
2024-03-31	2	432	408	490
2024-01-04	5	564	477	377
2024-05-20	2	599	138	107
2024-09-08	3	130	354	355
2024-03-07	5	166	483	499
2024-08-12	1	586	477	297
2024-01-28	5	215	329	485
2024-06-21	1	459	421	199
2024-04-09	1	590	381	290
2024-03-15	3	572	381	308
2024-04-06	5	966	464	170
2024-06-05	3	274	480	454
2024-07-25	4	389	312	420
2024-05-26	3	886	461	152
2024-07-02	5	456	101	208
2024-03-18	2	718	103	451
2024-08-08	2	688	412	145
2024-04-29	3	230	206	207
2024-03-04	1	620	411	110
2024-08-30	3	205	141	323
2024-02-23	5	515	421	129
2024-01-02	1	937	318	472
2024-09-02	5	831	162	298
2024-03-11	3	915	353	394
2024-03-20	2	209	376	272
2024-08-03	2	433	494	173
2024-02-22	2	669	318	126
2024-03-31	1	765	153	270
2024-04-14	1	172	118	293
2024-02-14	4	911	313	441
2024-08-01	4	409	467	102
2024-07-05	4	645	228	269
2024-07-08	2	572	403	285
2024-03-06	2	510	283	386
2024-01-10	4	704	255	363
2024-01-07	1	523	238	331
2024-04-22	5	344	142	207
2024-07-17	3	735	319	259
2024-08-11	2	349	389	430
2024-05-17	2	661	195	160
2024-05-03	2	262	203	299
2024-09-15	1	593	436	378
2024-02-29	5	493	367	121
2024-08-26	5	167	134	379
2024-01-19	4	448	168	111
2024-09-10	5	313	404	125
2024-01-03	1	933	448	245
2024-03-24	1	810	448	348
2024-01-19	5	705	499	407
2024-03-20	4	541	127	414
2024-05-29	5	903	234	339
2024-03-30	5	545	171	274
2024-03-25	3	680	475	241
2024-07-04	2	906	150	347
2024-09-09	2	450	244	232
2024-01-21	1	657	465	132
2024-01-05	5	810	128	145
2024-06-06	1	341	368	390
2024-07-03	3	277	110	382
2024-08-28	3	778	151	236
2024-08-28	4	785	335	506
2024-08-15	3	179	259	480
2024-04-04	1	857	363	340
2024-03-18	4	828	206	260
2024-01-13	3	687	368	495
2024-01-14	1	956	211	313
2024-02-03	1	598	317	207
2024-04-22	5	217	145	453
2024-08-31	3	706	179	211
2024-01-25	2	710	455	353
2024-08-31	4	574	364	317
2024-07-05	5	433	161	391
2024-03-09	2	668	212	206
2024-04-13	3	199	171	510
2024-06-14	1	941	335	200
2024-07-09	1	555	429	183
2024-06-13	4	280	246	205
2024-04-05	5	415	420	267
2024-02-14	5	515	444	297
2024-02-26	3	171	366	405
2024-06-24	2	712	130	387
2024-04-19	3	211	353	138
2024-06-29	1	801	211	464
2024-03-07	2	933	480	476
2024-03-28	5	710	449	116
2024-05-08	3	889	101	322
2024-07-20	5	939	245	143
2024-09-11	4	488	312	108
2024-08-02	4	435	463	344
2024-08-09	3	606	212	167
2024-09-08	5	760	345	411
2024-02-02	2	776	257	299
2024-04-01	5	162	334	219
2024-05-13	4	192	277	281
2024-01-03	5	322	199	283
2024-01-19	5	936	235	184
2024-05-21	1	242	443	394
2024-01-17	2	694	203	175
2024-08-27	2	873	264	477
2024-05-10	5	751	355	139
2024-02-20	4	929	310	160
2024-04-05	1	100	103	160
2024-01-28	1	875	290	131
2024-01-15	4	250	233	119
2024-03-16	3	776	128	291
2024-03-02	3	252	499	406
2024-09-09	2	563	144	241
2024-05-30	4	644	290	195
2024-07-28	5	398	110	326
2024-02-23	3	499	204	403
2024-02-03	4	730	287	483
2024-08-08	2	691	226	482
2024-09-06	2	557	405	284
2024-06-08	5	300	228	161
2024-04-07	3	310	453	314
2024-08-12	2	797	482	116
2024-05-23	5	998	197	218
2024-06-28	1	424	496	299
2024-05-06	2	406	199	228
2024-03-25	4	683	366	356
2024-02-26	3	913	493	340
2024-06-28	2	795	443	354
2024-08-01	5	411	490	503
2024-09-16	2	545	242	161
2024-09-07	4	835	160	325
2024-03-07	4	452	484	425
2024-05-08	4	191	398	352
2024-07-15	3	696	254	318
2024-08-29	4	108	397	208
2024-07-17	5	726	264	255
2024-02-28	2	622	311	504
2024-01-10	2	513	210	367
2024-07-11	2	967	485	438
2024-08-26	4	230	350	305
2024-01-06	5	972	380	272
2024-05-29	4	401	129	447
2024-04-15	3	163	335	373
2024-02-24	3	478	244	182
2024-08-11	1	662	286	197
2024-03-08	5	154	134	444
2024-02-22	4	100	276	282
2024-04-12	2	820	423	187
2024-09-11	3	673	417	509
2024-03-08	4	940	387	107
2024-04-01	3	467	304	302
2024-02-20	3	212	440	156
2024-03-28	3	981	269	321
2024-07-24	2	388	495	322
2024-08-17	4	986	437	322
2024-01-01	4	131	327	413
2024-04-05	2	340	218	350
2024-04-01	5	542	141	396
2024-07-05	2	819	337	182
2024-08-25	4	704	400	370
2024-05-05	4	503	388	190
2024-02-24	5	740	376	377
2024-07-10	2	425	475	367
2024-04-06	4	828	285	140
2024-04-02	3	491	488	168
2024-06-19	5	515	151	394
2024-06-25	5	490	251	364
2024-05-14	5	545	324	251
2024-05-31	3	658	316	288
2024-08-11	4	316	175	161
2024-04-19	1	778	151	212
2024-07-22	4	277	187	140
2024-04-05	5	586	191	464
2024-08-24	4	242	385	131
2024-08-26	1	292	298	282
2024-07-31	5	668	307	280
2024-05-26	3	493	274	310
2024-02-23	4	963	138	395
2024-06-21	5	468	321	278
2024-06-30	5	960	148	118
2024-05-06	2	527	310	155
2024-08-17	5	257	310	156
2024-01-28	1	395	129	298
2024-09-14	5	993	145	339
2024-04-12	4	786	427	379
2024-05-04	4	228	407	296
2024-08-07	1	237	457	495
2024-07-12	2	111	198	411
2024-01-16	2	173	131	423
2024-07-05	2	763	456	390
2024-01-10	3	116	298	381
2024-05-12	2	247	220	493
2024-04-25	1	838	300	125
2024-07-06	2	598	108	320
2024-01-18	2	773	197	380
2024-03-09	5	547	125	126
2024-07-03	3	239	241	489
2024-03-27	3	186	368	287
2024-06-10	1	240	164	465
2024-08-30	3	757	133	224
2024-07-23	1	925	104	296
2024-04-23	3	525	170	398
2024-07-31	5	980	212	239
2024-06-24	4	566	295	365
2024-03-13	3	907	371	338
2024-04-17	4	812	425	138
2024-06-22	5	718	402	134
2024-02-20	4	535	406	180
2024-07-16	1	738	147	255
2024-06-25	3	284	372	295
2024-06-21	2	565	393	500
2024-03-14	2	621	185	319
2024-04-16	5	534	422	210
2024-05-06	1	665	340	421
2024-02-14	2	939	449	368
2024-03-28	5	560	348	282
2024-08-17	2	493	281	156
2024-01-28	3	463	324	324
2024-08-23	2	331	403	338
2024-01-11	4	290	106	242
2024-01-09	3	534	434	187
2024-03-30	4	719	295	268
2024-02-04	1	107	103	322
2024-09-13	3	691	500	312
2024-04-10	3	610	198	265
2024-06-08	5	967	471	405
2024-09-02	1	848	174	203
2024-07-22	5	342	109	380
2024-03-19	2	829	390	434
2024-08-07	5	613	410	414
2024-04-24	3	375	145	300
2024-07-14	5	520	272	167
2024-06-04	5	659	181	130
2024-07-29	3	690	140	352
2024-07-06	3	475	269	205
2024-04-09	1	134	394	264
2024-01-05	1	138	274	398
2024-03-03	5	681	292	163
2024-05-14	3	594	235	468
2024-08-05	5	821	294	225
2024-06-24	5	477	118	386
2024-08-17	1	215	450	129
2024-09-04	2	694	399	284
2024-06-23	2	593	172	441
2024-09-11	3	807	220	143
2024-04-19	4	181	370	287
2024-02-20	3	245	260	136
2024-07-19	2	847	280	448
2024-04-20	2	848	198	185
2024-03-26	4	639	192	509
2024-01-01	2	979	376	506
2024-04-02	2	868	451	292
2024-02-19	5	897	183	302
2024-03-08	3	386	192	356
2024-02-23	4	576	357	134
2024-05-22	3	629	295	354
2024-03-03	3	180	230	156
2024-01-08	2	635	235	204
2024-06-02	4	724	463	402
2024-04-30	5	190	436	178
2024-03-24	5	351	156	221
2024-07-16	1	583	233	271
2024-09-08	1	745	150	327
2024-05-27	3	859	383	297
2024-09-13	5	779	203	242
2024-07-18	4	784	390	486
2024-02-14	3	179	478	388
2024-08-04	2	800	235	175
2024-05-28	4	748	306	418
2024-06-10	4	652	320	422
2024-05-11	5	917	394	412
2024-08-17	2	693	271	183
2024-07-21	5	419	450	400
2024-01-22	4	727	112	178
2024-02-10	5	154	359	111
2024-06-13	3	451	245	287
2024-08-19	4	647	155	316
2024-02-01	5	897	376	408
2024-04-20	5	111	256	477
2024-04-30	2	580	430	492
2024-06-11	3	564	215	216
2024-04-11	1	624	296	369
2024-08-17	2	580	461	278
2024-01-04	1	687	123	345
2024-09-07	2	851	294	190
2024-01-04	2	439	487	274
2024-04-28	1	531	254	474
2024-04-30	4	461	197	398
2024-04-27	5	917	381	424
2024-06-04	4	401	117	474
2024-09-12	1	396	405	242
2024-01-20	3	271	199	107
2024-02-27	4	136	166	252
2024-01-16	1	811	324	203
2024-08-14	5	711	259	378
2024-07-10	4	867	206	372
2024-07-07	4	411	284	426
2024-09-02	1	844	112	444
2024-04-14	4	903	378	308
2024-04-10	3	677	204	485
2024-03-26	5	366	249	259
2024-04-17	3	162	110	273
2024-07-17	1	744	104	262
2024-01-28	5	584	489	150
2024-05-14	4	692	216	97
2024-01-05	2	273	487	291
2024-08-17	1	686	112	138
2024-08-05	2	152	377	127
2024-02-04	5	772	227	311
2024-06-30	5	398	105	211
2024-04-24	5	928	131	377
2024-09-10	3	855	492	383
2024-01-16	3	739	248	236
2024-05-17	1	127	474	439
2024-05-29	5	393	125	227
2024-05-13	4	596	408	386
2024-03-02	1	184	377	497
2024-08-24	1	229	405	503
2024-02-10	2	617	483	475
2024-07-29	2	178	275	247
2024-08-03	5	971	317	149
2024-09-12	4	902	168	215
2024-05-17	1	384	270	422
2024-01-22	2	358	369	90
2024-06-25	4	235	418	180
2024-06-26	3	730	229	237
2024-05-19	4	387	235	398
2024-01-21	5	381	491	194
2024-03-29	1	978	253	326
2024-03-17	1	363	456	444
2024-02-20	3	114	272	159
2024-04-06	3	859	266	484
2024-04-28	5	214	203	307
2024-06-06	4	718	147	140
2024-09-02	3	278	417	185
2024-01-08	3	705	123	419
2024-08-09	3	856	289	375
2024-06-09	2	254	278	457
2024-07-23	3	774	413	430
2024-06-02	1	557	450	359
2024-03-04	2	478	417	161
2024-05-07	3	927	374	173
2024-01-04	4	279	142	337
2024-05-22	5	367	356	490
2024-05-08	4	901	358	255
2024-06-20	4	817	282	198
2024-08-05	3	341	226	174
2024-07-27	5	596	466	452
2024-05-27	1	285	258	430
2024-09-16	3	918	230	301
2024-05-06	4	640	470	451
2024-04-26	2	982	249	172
2024-09-07	5	133	387	291
2024-08-27	4	451	486	122
2024-02-04	1	186	290	185
2024-05-27	3	248	497	106
2024-02-05	4	709	409	493
2024-06-05	2	941	112	256
2024-01-25	2	257	113	312
2024-04-01	4	957	337	386
2024-08-01	5	607	164	114
2024-04-21	1	870	343	465
2024-08-07	2	522	425	464
2024-04-17	4	888	240	317
2024-08-24	5	492	392	293
2024-02-13	2	343	279	243
2024-07-18	4	776	390	327
2024-06-20	5	550	137	288
2024-06-16	5	843	309	429
2024-01-10	1	752	396	320
2024-06-30	4	271	323	158
2024-09-10	1	315	105	413
2024-01-03	5	691	430	170
2024-03-21	5	851	359	246
2024-06-02	5	962	257	267
2024-03-16	1	453	151	242
2024-05-08	2	155	137	356
2024-02-10	4	757	152	249
2024-04-27	5	370	485	293
2024-03-22	1	873	252	307
2024-02-25	5	939	242	188
2024-03-12	1	218	435	101
2024-08-28	3	153	482	366
2024-05-18	1	271	127	246
2024-04-30	5	575	450	346
2024-06-30	1	508	343	204
2024-05-11	5	587	259	109
2024-08-25	4	408	115	434
2024-07-12	5	587	269	446
2024-01-23	5	864	188	136
2024-05-15	2	870	176	190
2024-04-11	2	645	282	165
2024-08-29	4	339	325	130
2024-02-29	4	488	166	227
2024-02-16	2	799	283	164
2024-02-19	1	822	401	432
2024-02-14	5	499	138	186
2024-08-30	3	585	479	211
2024-04-21	1	368	222	225
2024-08-23	4	248	500	500
2024-02-05	4	643	109	262
2024-03-06	4	991	491	433
2024-09-13	4	545	105	491
2024-07-29	5	112	108	214
2024-04-25	5	395	478	446
2024-08-06	3	916	207	338
2024-01-28	1	559	436	496
2024-06-11	4	491	466	277
2024-08-28	2	794	338	96
2024-01-02	4	423	270	166
2024-04-06	1	642	190	457
2024-08-23	2	799	458	141
2024-07-01	5	142	394	408
2024-04-01	5	199	408	90
2024-05-08	1	644	248	210
2024-05-26	3	752	492	165
2024-08-09	4	462	264	225
2024-09-09	1	964	270	218
2024-01-01	4	542	368	139
2024-01-13	3	725	175	211
2024-09-15	4	767	330	207
2024-05-10	5	978	265	165
2024-04-06	4	379	217	496
2024-08-21	4	443	174	413
2024-02-05	2	376	493	181
2024-01-30	3	373	318	224
2024-03-29	1	921	495	475
2024-04-09	3	200	180	500
2024-03-01	4	361	214	446
2024-02-02	1	770	478	257
2024-05-05	5	698	425	331
2024-09-11	1	500	334	337
2024-08-16	2	572	467	374
2024-02-13	2	891	133	198
2024-08-03	5	791	193	198
2024-05-20	3	867	337	338
2024-07-02	5	347	469	393
2024-06-30	2	851	263	216
2024-08-06	3	788	160	334
2024-09-10	4	702	408	91
2024-06-28	2	888	477	363
2024-05-12	1	299	398	293
2024-07-03	4	632	418	191
2024-07-15	3	445	448	352
2024-04-13	1	793	221	469
2024-01-29	1	806	320	162
2024-02-05	2	284	413	389
2024-04-03	3	420	283	367
2024-06-04	5	660	358	369
2024-04-09	5	110	454	269
2024-06-05	4	788	246	158
2024-07-24	3	108	151	234
2024-04-23	5	951	316	421
2024-05-07	4	169	499	383
2024-03-25	4	112	206	293
2024-06-20	3	521	262	322
2024-01-26	1	200	395	464
2024-07-01	4	637	311	180
2024-07-07	4	206	345	135
2024-07-25	2	801	399	131
2024-03-29	3	556	291	138
2024-06-09	1	459	306	193
2024-01-18	5	324	138	179
2024-01-19	1	842	277	90
2024-06-07	2	390	140	371
2024-06-06	5	357	122	143
2024-08-22	4	297	411	255
2024-07-28	4	134	106	219
2024-08-04	3	124	134	168
2024-08-10	1	734	118	295
2024-02-01	4	194	175	386
2024-03-09	3	158	171	476
2024-06-18	4	708	494	271
2024-06-17	4	772	386	100
2024-01-01	1	955	231	97
2024-01-29	2	322	384	127
2024-01-27	3	713	325	499
2024-05-09	1	753	414	409
2024-05-14	1	224	222	443
2024-08-16	3	825	112	310
2024-06-03	1	222	346	353
2024-05-09	3	188	241	245
2024-05-16	2	976	374	308
2024-04-13	1	719	209	366
2024-01-24	2	233	344	334
2024-02-18	3	484	442	209
2024-07-03	4	772	498	316
2024-07-05	1	882	332	474
2024-07-04	1	763	296	260
2024-01-03	1	679	380	309
2024-03-27	4	922	158	135
2024-07-30	5	289	116	304
2024-04-28	2	213	223	375
2024-03-16	3	812	195	475
2024-03-30	2	288	243	152
2024-08-11	5	359	344	248
2024-05-01	5	401	146	448
2024-02-18	1	578	331	189
2024-04-01	2	776	212	456
2024-07-07	5	177	263	414
2024-05-17	4	754	305	327
2024-04-13	3	564	266	424
2024-01-20	4	383	374	268
2024-08-05	1	887	315	219
2024-04-24	5	537	117	479
2024-02-24	2	808	365	327
2024-03-10	4	783	469	230
2024-08-06	4	888	382	92
2024-05-27	5	888	193	153
2024-02-13	1	431	174	452
2024-07-31	5	363	209	246
2024-05-24	1	265	271	114
2024-08-09	4	899	158	280
2024-02-09	1	175	308	421
2024-07-05	1	383	352	438
2024-01-04	2	895	125	158
2024-02-09	2	163	402	263
2024-03-12	3	491	183	224
2024-03-19	2	497	283	203
2024-01-19	5	440	430	169
2024-07-15	2	161	324	291
2024-07-11	5	364	327	209
2024-03-18	2	932	217	277
2024-07-22	1	371	256	116
2024-04-11	4	282	355	475
2024-08-05	1	551	263	403
2024-04-08	2	171	370	178
2024-09-14	5	603	407	310
2024-02-02	3	305	146	195
2024-04-18	4	724	303	296
2024-05-24	1	502	163	392
2024-01-25	2	282	475	120
2024-05-17	1	760	408	212
2024-08-11	4	603	352	284
2024-05-22	3	211	183	370
2024-03-04	2	247	201	114
2024-01-24	2	653	428	497
2024-02-18	3	887	355	323
2024-02-12	3	541	140	334
2024-05-26	2	323	360	474
2024-07-23	4	728	213	475
2024-03-03	2	758	205	286
2024-08-25	5	208	261	210
2024-09-16	2	552	195	103
2024-05-24	1	832	369	481
2024-08-13	3	365	110	447
2024-04-30	1	205	391	205
2024-04-19	4	135	373	180
2024-08-09	3	174	340	342
2024-07-29	4	172	312	150
2024-05-17	1	685	401	358
2024-03-18	5	845	163	450
2024-05-12	5	356	324	219
2024-08-03	2	895	233	198
2024-05-02	1	556	407	368
2024-08-25	2	119	329	460
2024-06-10	4	609	104	214
2024-04-03	1	252	297	166
2024-01-31	1	768	288	323
2024-01-27	2	755	189	267
2024-09-02	3	100	325	444
2024-02-07	3	138	407	94
2024-04-29	5	780	322	440
2024-05-27	4	499	153	316
2024-01-19	2	372	178	422
2024-08-12	1	255	228	111
2024-09-13	2	816	424	371
2024-01-08	2	437	484	504
2024-01-15	2	500	437	300
2024-02-20	1	688	186	98
2024-08-21	2	103	175	238
2024-04-26	5	627	466	236
2024-03-04	4	824	104	174
2024-03-18	4	889	201	408
2024-08-21	1	602	464	326
2024-03-11	4	589	408	296
2024-04-21	3	546	171	92
2024-03-11	5	513	147	199
2024-05-22	2	964	128	220
2024-03-03	1	845	151	306
2024-04-13	3	899	443	141
2024-07-26	4	931	293	428
2024-04-29	3	904	144	127
2024-04-23	5	171	258	345
2024-01-20	3	653	356	493
2024-05-11	3	331	484	214
2024-07-15	4	103	143	368
2024-07-31	4	493	163	295
2024-01-21	4	805	341	194
2024-06-17	1	937	304	457
2024-01-21	5	898	389	460
2024-06-25	4	593	232	269
2024-07-27	3	224	261	262
2024-04-03	2	680	440	423
2024-01-15	5	648	184	304
2024-01-29	2	467	353	193
2024-06-18	3	441	304	138
2024-02-16	2	798	439	271
2024-07-07	3	410	203	252
2024-06-15	3	510	107	413
2024-08-16	2	156	412	403
2024-05-14	3	747	315	187
2024-08-31	2	762	290	103
2024-05-21	1	192	120	243
2024-01-31	5	474	118	129
2024-07-22	5	647	254	489
2024-06-19	3	973	493	356
2024-02-11	4	448	117	286
2024-06-09	3	182	154	136
2024-03-30	5	961	143	487
2024-04-10	1	570	322	104
2024-08-02	2	878	251	506
2024-04-02	4	884	279	336
2024-01-15	2	396	368	425
2024-04-06	5	763	149	419
2024-06-27	1	307	330	486
2024-03-03	3	280	423	284
2024-03-21	1	667	473	326
2024-08-08	5	140	417	181
2024-02-22	2	493	331	350
2024-02-27	4	776	496	121
2024-07-19	1	295	366	403
2024-04-26	3	406	166	420
2024-01-04	4	812	165	261
2024-04-17	3	499	400	115
2024-06-29	4	209	239	233
2024-03-04	2	745	463	499
2024-03-15	1	805	162	509
2024-04-07	3	467	240	374
2024-03-30	2	598	109	476
2024-06-20	2	186	316	207
2024-08-13	1	747	143	321
2024-04-29	5	548	500	125
2024-07-04	4	852	178	125
2024-01-05	1	294	467	437
2024-02-14	4	243	451	164
2024-08-25	4	136	204	393
2024-03-07	5	297	422	106
2024-01-03	1	125	142	451
2024-02-14	1	837	238	282
2024-08-18	3	707	462	211
2024-05-02	3	344	177	153
2024-01-05	5	600	232	226
2024-03-13	4	498	145	418
2024-07-06	1	164	463	325
2024-05-11	3	911	220	379
2024-08-20	2	653	111	124
2024-05-22	1	758	222	248
2024-07-12	3	415	364	207
2024-09-11	3	611	397	386
2024-01-08	5	646	344	224
2024-05-16	5	954	327	163
2024-04-26	5	931	215	260
2024-01-26	5	560	500	467
2024-09-01	3	116	155	337
2024-09-09	2	137	182	344
2024-07-03	4	447	297	425
2024-08-11	1	157	278	269
2024-06-19	4	445	112	134
2024-07-16	3	906	128	201
2024-07-23	1	838	331	356
2024-06-01	2	143	455	417
2024-04-05	3	515	268	457
2024-02-27	3	221	250	181
2024-05-03	1	316	121	435
2024-01-04	2	926	313	495
2024-01-20	5	769	469	237
2024-04-04	5	783	217	236
2024-05-27	5	635	155	244
2024-07-07	1	569	165	172
2024-01-07	5	794	178	409
2024-05-18	1	991	267	209
2024-04-03	1	995	276	218
2024-02-04	1	649	421	501
2024-02-27	4	252	270	506
2024-03-08	1	858	149	256
2024-09-02	1	693	162	224
2024-02-21	5	338	394	498
2024-07-15	2	173	337	298
2024-09-07	2	137	187	173
2024-06-23	1	853	312	483
2024-06-15	2	244	209	302
2024-07-12	3	600	150	436
2024-09-11	4	769	325	481
2024-05-11	3	119	441	298
2024-03-20	2	582	188	280
2024-02-08	1	733	456	494
2024-06-24	3	146	326	330
2024-07-07	1	348	170	252
2024-02-23	5	818	107	235
2024-01-13	5	764	298	95
2024-03-16	5	233	287	136
2024-05-28	3	114	428	327
2024-08-19	4	276	279	174
2024-04-22	5	747	161	112
2024-05-01	2	151	473	400
2024-03-14	3	414	419	248
2024-07-24	4	940	251	235
2024-07-27	3	912	397	92
2024-03-08	4	199	353	210
2024-05-10	5	567	207	114
2024-01-26	5	725	358	166
2024-02-18	4	274	309	101
2024-08-06	3	955	199	255
2024-08-09	2	705	317	271
2024-04-26	4	165	173	398
2024-02-10	2	937	461	235
2024-07-15	3	937	127	160
2024-08-13	3	208	181	146
2024-05-31	3	216	320	249
2024-01-08	3	609	148	144
2024-09-03	4	709	202	95
2024-08-27	2	918	385	302
2024-01-03	5	730	304	330
2024-03-02	2	325	343	441
2024-08-18	5	164	435	464
2024-06-21	2	923	456	387
2024-04-04	3	307	174	221
2024-02-11	3	536	265	205
2024-04-19	4	445	192	188
2024-09-01	1	930	437	159
2024-05-19	2	955	379	119
2024-02-15	2	855	197	203
2024-01-26	2	794	157	152
2024-08-05	1	511	474	411
2024-05-27	3	432	383	94
2024-03-28	5	223	327	489
2024-01-06	4	800	489	98
2024-07-24	5	689	455	462
2024-01-09	4	658	116	291
2024-05-05	2	240	465	419
2024-05-20	3	429	246	257
2024-05-18	2	956	290	169
2024-03-09	3	912	129	188
2024-05-07	4	318	463	168
2024-03-19	4	882	200	123
2024-08-10	5	146	354	139
2024-05-25	1	707	459	207
2024-01-23	3	277	249	173
2024-07-03	3	443	496	216
2024-03-01	4	164	127	97
2024-02-24	5	223	216	235
2024-07-15	5	380	498	469
2024-07-30	4	244	229	175
2024-08-05	5	875	344	246
2024-01-29	2	525	293	247
2024-01-20	1	272	212	458
2024-01-13	1	813	199	126
2024-07-02	5	478	481	232
2024-07-11	5	666	254	383
2024-04-30	4	268	332	142
2024-01-09	1	549	279	321
2024-02-21	3	349	460	147
2024-08-24	5	695	405	343
2024-08-25	4	141	437	387
2024-09-15	2	236	252	185
2024-08-22	3	202	460	413
2024-06-05	2	910	405	193
2024-05-25	5	967	206	213
2024-08-17	3	747	206	423
2024-04-11	5	727	213	394
2024-08-03	2	485	134	455
2024-05-07	5	896	322	205
2024-04-28	2	261	408	404
2024-07-30	2	116	309	390
2024-03-07	3	598	287	157
2024-07-09	5	182	112	458
2024-02-26	4	106	499	495
2024-05-30	3	107	217	279
2024-07-16	4	283	386	192
2024-08-19	5	191	189	278
2024-05-08	4	823	438	477
2024-07-04	1	767	109	371
2024-05-17	5	707	262	143
2024-01-06	1	390	179	291
2024-03-19	3	526	354	139
2024-03-16	4	810	129	507
2024-03-21	3	926	104	391
2024-03-30	5	911	442	483
2024-02-09	1	891	122	175
2024-02-04	3	587	377	98
2024-03-25	3	808	303	495
2024-01-23	5	229	337	188
2024-07-07	2	311	306	304
2024-07-07	2	246	456	274
2024-04-12	2	755	258	375
2024-04-15	4	377	221	230
2024-03-21	4	635	311	148
2024-07-02	3	561	418	469
2024-01-10	5	521	461	118
2024-02-08	2	344	472	324
2024-03-09	1	278	241	272
2024-01-17	3	725	472	156
2024-04-11	1	808	476	357
2024-08-21	5	138	443	409
2024-03-12	3	710	482	132
2024-03-08	4	284	364	465
2024-01-23	3	834	490	429
2024-08-12	1	611	495	123
2024-07-28	5	726	371	418
2024-07-04	4	190	194	310
2024-06-28	1	742	260	488
2024-03-06	5	946	390	481
2024-03-16	3	901	277	165
2024-04-01	4	408	161	296
2024-06-02	1	456	391	148
2024-02-09	2	528	154	506
2024-05-08	1	104	450	146
2024-09-04	5	671	139	336
2024-04-15	3	341	107	134
2024-05-13	2	296	306	433
2024-07-19	3	220	374	202
2024-04-08	1	642	435	161
2024-07-11	2	197	392	174
2024-05-24	2	733	468	451
2024-08-08	5	470	163	189
2024-05-11	1	983	158	193
2024-03-29	5	879	121	457
2024-05-06	5	652	447	130
2024-03-24	3	619	268	308
2024-07-04	2	324	393	347
2024-06-08	1	575	226	368
2024-05-06	1	888	124	357
2024-01-26	1	741	340	277
2024-05-03	3	775	360	151
2024-06-19	1	313	218	436
2024-02-04	5	383	456	151
2024-07-30	3	154	113	295
2024-05-13	5	298	155	193
2024-01-13	3	215	307	165
2024-04-30	5	915	189	328
2024-08-03	5	252	404	140
2024-02-02	2	801	361	277
2024-06-14	1	964	365	245
2024-07-06	3	585	267	434
2024-08-06	4	609	480	407
2024-07-17	1	280	333	159
2024-06-12	1	263	345	334
2024-09-15	2	786	240	298
2024-01-13	1	144	255	410
2024-07-01	5	155	374	250
2024-06-19	3	760	471	148
2024-06-03	2	472	209	290
2024-09-11	4	391	109	486
2024-02-18	3	314	475	110
2024-08-18	2	545	336	198
2024-07-10	5	357	280	272
2024-03-03	5	442	452	104
2024-06-24	2	731	283	119
2024-07-24	5	924	371	353
2024-08-21	5	876	456	476
2024-05-25	4	564	258	450
2024-07-03	3	144	438	295
2024-04-28	5	206	357	385
2024-08-08	2	858	498	333
2024-01-28	5	153	274	246
2024-09-14	1	650	388	242
2024-05-15	1	280	195	312
2024-02-23	3	261	473	159
2024-03-02	3	904	211	279
2024-07-15	4	129	161	312
2024-07-31	1	596	222	257
2024-05-30	1	627	382	187
2024-07-12	1	218	338	158
2024-02-14	1	172	109	449
2024-03-17	4	340	232	106
2024-09-01	4	838	425	201
2024-08-24	3	555	193	354
2024-08-15	1	706	290	233
2024-03-16	3	693	163	200
2024-04-27	1	433	483	430
2024-03-22	5	529	267	265
2024-05-06	1	303	375	227
2024-09-06	2	865	350	99
2024-03-01	4	793	118	379
2024-08-26	2	433	464	315
2024-06-15	1	335	407	229
2024-02-14	5	897	327	507
2024-03-12	2	212	366	210
2024-05-01	4	433	326	235
2024-06-24	4	333	167	245
2024-07-07	3	200	446	135
2024-02-15	1	342	179	325
2024-08-22	5	855	209	369
2024-07-21	4	522	266	349
2024-03-21	3	990	359	472
2024-01-23	3	304	390	422
2024-01-09	1	484	162	97
2024-09-11	5	325	248	114
2024-07-30	3	175	450	338
2024-07-13	2	582	123	125
2024-07-14	2	699	417	459
2024-05-04	5	596	182	401
2024-04-27	1	155	470	184
2024-03-30	5	546	421	125
2024-06-17	5	248	308	101
2024-03-05	5	321	276	321
2024-07-20	2	724	140	142
2024-03-13	5	565	138	219
2024-09-03	1	282	461	408
2024-06-16	3	496	414	129
2024-01-31	2	482	170	480
2024-05-26	2	239	112	472
2024-07-25	5	568	258	368
2024-08-16	3	837	284	166
2024-07-02	4	298	210	458
2024-04-26	1	747	147	195
2024-09-05	2	467	275	363
2024-01-21	2	376	466	302
2024-03-10	3	307	337	426
2024-07-18	2	443	428	110
2024-04-20	1	230	490	460
2024-06-28	3	132	115	224
2024-09-02	5	808	197	169
2024-03-12	2	682	492	438
2024-05-20	2	161	219	119
2024-08-15	3	387	397	125
2024-02-23	4	239	455	458
2024-01-03	2	213	108	382
2024-04-19	4	972	127	117
2024-07-13	4	576	237	101
2024-07-11	5	569	305	302
2024-01-30	2	528	469	487
2024-08-16	2	275	231	484
2024-03-31	5	878	272	401
2024-02-09	2	451	321	255
2024-02-18	3	325	498	472
2024-06-10	2	402	344	244
2024-05-22	3	718	382	343
2024-04-17	2	260	419	491
2024-08-23	2	908	493	496
2024-01-01	1	913	353	499
2024-08-14	4	753	280	210
2024-03-04	4	726	249	395
2024-04-18	5	274	302	246
2024-01-20	4	691	252	120
2024-05-10	4	666	105	284
2024-04-02	4	975	210	134
2024-01-11	5	335	436	312
2024-09-12	3	188	111	244
2024-08-12	2	521	225	357
2024-03-20	1	977	337	147
2024-01-30	2	634	463	352
2024-06-17	1	600	189	351
2024-03-07	1	982	324	389
2024-05-28	4	321	311	346
2024-02-04	4	705	294	471
2024-03-04	4	584	211	324
2024-02-13	4	957	396	230
2024-01-04	3	573	330	205
2024-01-20	5	385	275	142
2024-02-02	1	114	414	250
2024-07-09	4	847	398	331
2024-06-11	4	538	375	322
2024-03-17	2	853	256	428
2024-03-27	5	993	225	416
2024-07-04	5	352	192	171
2024-09-12	4	353	451	193
2024-06-19	3	435	429	372
2024-07-08	2	544	131	273
2024-08-25	3	693	312	161
2024-07-09	5	327	383	475
2024-04-01	5	705	395	132
2024-02-13	2	252	247	191
2024-08-01	2	687	330	180
2024-03-03	5	105	404	397
2024-05-16	3	527	120	125
2024-08-26	5	145	371	109
2024-06-01	5	141	450	296
2024-08-29	1	581	249	294
2024-02-12	4	851	105	404
2024-05-09	2	887	261	394
2024-08-18	3	616	374	244
2024-04-26	4	134	432	333
2024-06-27	2	535	346	260
2024-01-17	3	643	336	408
2024-08-15	3	503	206	215
2024-06-29	2	590	333	466
2024-01-28	4	929	259	478
2024-01-24	3	917	441	503
2024-02-12	3	813	424	321
2024-03-08	5	941	270	331
2024-03-28	4	200	500	422
2024-07-08	1	563	418	331
2024-07-04	1	607	159	267
2024-07-08	2	346	189	323
2024-02-12	1	185	116	187
2024-07-05	2	671	437	119
2024-06-25	4	871	175	275
2024-03-06	4	112	145	386
2024-01-17	2	809	101	288
2024-04-21	1	849	398	484
2024-03-28	1	516	161	162
2024-04-30	3	323	242	128
2024-06-11	2	235	408	443
2024-06-08	2	467	136	475
2024-07-15	1	402	307	95
2024-03-31	5	344	465	219
2024-05-26	1	763	430	336
2024-08-22	2	192	496	335
2024-07-28	1	116	376	143
2024-05-06	1	591	494	309
2024-06-08	2	785	355	435
2024-03-28	4	412	264	339
2024-05-22	2	265	420	175
2024-06-01	2	820	482	299
2024-01-01	4	570	326	460
2024-05-16	1	978	235	207
2024-07-28	4	684	475	213
2024-02-27	1	865	467	160
2024-03-26	5	697	399	486
2024-04-16	4	124	185	243
2024-09-15	5	565	176	367
2024-02-23	3	574	167	172
2024-08-09	2	890	121	338
2024-09-12	2	241	103	156
2024-01-26	3	995	428	151
2024-06-11	4	820	379	107
2024-03-28	2	515	234	260
2024-08-26	5	289	232	357
2024-02-02	1	908	149	291
2024-02-07	1	992	295	366
2024-08-06	1	479	387	189
2024-04-19	3	741	455	115
2024-01-08	1	575	318	346
2024-08-17	2	820	238	155
2024-01-15	5	748	291	292
2024-05-09	5	101	337	452
2024-09-12	4	981	233	108
2024-01-26	1	742	435	140
2024-03-07	1	172	295	266
2024-06-01	2	494	315	269
2024-07-22	5	807	342	274
2024-08-05	2	440	182	107
2024-05-02	3	643	391	135
2024-05-29	2	133	133	275
2024-09-06	3	403	484	447
2024-08-16	4	536	264	504
2024-03-18	5	870	285	255
2024-07-09	3	376	243	480
2024-07-18	5	814	361	198
2024-01-13	4	727	344	351
2024-05-28	5	655	168	250
2024-08-13	4	689	470	196
2024-05-13	4	913	371	146
2024-07-19	3	312	411	411
2024-03-27	5	906	190	405
2024-07-17	1	801	250	188
2024-02-02	1	182	441	245
2024-03-25	3	735	319	351
2024-09-14	1	443	347	283
2024-01-31	3	853	215	426
2024-02-12	1	156	471	247
2024-05-26	1	627	330	457
2024-05-13	1	790	280	341
2024-06-08	4	472	483	431
2024-01-11	2	152	488	283
2024-01-09	3	213	308	461
2024-05-29	4	492	333	406
2024-08-24	4	474	405	297
2024-07-02	1	576	486	440
2024-06-18	4	733	387	214
2024-07-09	4	141	239	230
2024-09-04	2	474	353	450
2024-02-09	5	475	456	152
2024-05-04	2	279	269	316
2024-02-25	1	763	112	184
2024-03-09	5	672	356	144
2024-05-15	3	821	364	398
2024-08-20	1	168	168	127
2024-04-12	3	674	236	261
2024-08-09	5	826	293	483
2024-02-14	1	892	195	363
2024-04-22	3	309	156	316
2024-06-06	1	241	322	448
2024-08-16	3	442	270	400
2024-06-10	3	344	422	182
2024-03-06	3	652	341	495
2024-05-24	2	216	116	92
2024-05-05	2	764	126	97
2024-03-21	3	589	423	373
2024-08-29	1	855	374	510
2024-08-15	3	870	206	312
2024-08-26	3	694	149	346
2024-04-28	5	992	132	320
2024-05-28	2	819	380	173
2024-03-04	2	314	481	292
2024-07-19	5	871	217	218
2024-09-04	3	862	193	153
2024-06-21	1	879	342	397
2024-08-18	5	330	187	473
2024-09-06	3	428	195	223
2024-02-13	3	461	223	151
2024-01-04	5	373	135	386
2024-02-09	1	615	462	325
2024-04-02	4	796	341	453
2024-01-15	2	533	271	247
2024-04-01	3	383	275	200
2024-07-27	5	155	489	313
2024-08-21	5	164	429	426
2024-04-16	5	481	460	179
2024-05-17	1	453	157	321
2024-02-02	4	563	215	491
2024-05-21	4	597	244	132
2024-02-17	3	613	383	474
2024-02-23	3	639	187	167
2024-02-19	5	949	353	126
2024-06-06	2	225	305	211
2024-05-05	4	581	494	332
2024-09-13	2	826	462	142
2024-08-04	4	644	326	242
2024-08-03	3	794	438	281
2024-08-24	1	945	322	396
2024-07-04	5	645	500	457
2024-09-05	3	399	394	135
2024-02-27	5	562	427	403
2024-02-11	3	735	399	192
2024-07-28	5	476	252	162
2024-04-03	4	919	146	184
2024-08-19	2	789	493	324
2024-06-27	4	809	344	386
2024-07-09	2	928	104	347
2024-06-26	2	167	345	250
2024-08-08	2	292	126	389
2024-03-08	3	568	406	235
2024-08-24	2	189	318	127
2024-08-15	4	182	210	297
2024-01-25	4	500	403	296
2024-01-10	1	283	330	423
2024-08-12	4	395	312	122
2024-03-24	5	178	242	176
2024-02-09	2	211	104	482
2024-05-15	2	268	350	124
2024-07-23	2	382	356	452
2024-01-27	1	214	168	260
2024-09-11	5	813	445	431
2024-08-09	2	251	390	300
2024-06-26	5	254	223	474
2024-02-02	4	995	300	145
2024-04-09	5	309	304	112
2024-02-20	1	633	337	410
2024-04-12	1	742	132	375
2024-07-14	1	123	221	261
2024-03-03	2	400	426	141
2024-06-17	3	526	259	438
2024-07-14	3	798	121	132
2024-02-29	4	654	418	406
2024-07-12	3	235	288	316
2024-04-05	2	585	122	500
2024-05-07	5	455	173	306
2024-08-14	5	530	312	422
2024-06-21	2	554	242	300
2024-02-22	4	855	450	444
2024-09-12	3	760	139	233
2024-02-23	1	121	495	403
2024-09-03	4	398	376	295
2024-08-26	2	293	326	335
2024-04-16	4	164	195	151
2024-04-02	2	122	212	477
2024-05-26	5	992	373	132
2024-07-26	5	921	405	384
2024-08-29	3	337	295	303
2024-05-11	1	954	457	128
2024-02-12	2	632	392	240
2024-02-24	2	760	318	109
2024-06-04	5	443	442	454
2024-03-19	5	521	368	115
2024-05-18	1	692	309	245
2024-01-10	1	451	136	253
2024-02-28	4	771	276	285
2024-07-16	2	761	407	349
2024-02-16	2	905	186	494
2024-04-16	5	434	114	136
2024-08-16	4	597	311	262
2024-05-29	3	707	470	316
2024-05-10	1	781	258	417
2024-03-11	3	813	186	242
2024-06-07	5	642	199	475
2024-02-05	5	962	181	207
2024-03-11	2	661	160	419
2024-01-31	1	555	385	291
2024-07-18	5	568	126	322
2024-06-21	1	411	382	458
2024-05-27	5	680	156	426
2024-08-07	2	235	431	147
2024-05-09	4	908	471	259
2024-03-08	3	413	159	159
2024-08-06	1	275	305	354
2024-07-01	3	908	317	467
2024-09-11	5	366	375	195
2024-03-11	5	332	114	418
2024-04-19	5	595	414	166
2024-02-02	2	480	322	308
2024-07-02	5	395	431	235
2024-05-04	1	888	258	457
2024-05-29	2	965	446	170
2024-09-03	3	148	366	311
2024-04-11	5	251	307	489
2024-05-23	3	461	105	403
2024-02-02	5	391	480	168
2024-05-25	1	566	223	183
2024-02-01	5	270	484	285
2024-04-26	4	733	415	303
2024-03-04	5	264	444	242
2024-04-21	2	828	211	92
2024-05-15	1	648	177	106
2024-03-13	3	392	177	394
2024-07-31	4	286	199	125
2024-06-29	5	279	254	223
2024-03-03	4	959	392	142
2024-07-18	1	825	499	335
2024-06-13	4	809	331	296
2024-05-09	1	782	460	179
2024-09-01	4	913	185	268
2024-03-07	2	257	330	311
2024-02-14	2	265	392	454
2024-04-12	5	343	106	188
2024-04-12	3	219	361	169
2024-02-29	1	142	497	91
2024-03-01	1	424	467	136
2024-07-14	1	688	227	390
2024-03-24	4	229	229	98
2024-01-24	5	551	447	124
2024-06-30	2	366	349	386
2024-03-30	2	478	121	113
2024-04-21	5	288	370	394
2024-01-24	3	310	104	423
2024-03-16	2	675	244	231
2024-02-16	3	824	193	258
2024-02-21	4	135	412	397
2024-01-21	3	781	376	284
2024-06-06	2	424	295	340
2024-08-11	2	452	123	288
2024-06-03	3	251	193	275
2024-03-30	3	481	117	388
2024-07-05	2	559	226	168
2024-04-08	5	652	232	404
2024-02-01	5	266	486	495
2024-08-05	4	646	407	293
2024-08-02	3	408	227	297
2024-01-28	5	224	248	344
2024-05-16	5	125	193	144
2024-03-01	5	514	226	228
2024-06-19	3	611	475	473
2024-04-21	4	886	469	396
2024-09-08	5	248	208	467
2024-03-24	5	569	122	290
2024-05-24	5	427	264	186
2024-06-15	3	259	482	400
2024-03-01	5	104	296	315
2024-07-14	2	856	356	312
2024-06-24	5	659	474	352
2024-05-25	2	619	172	247
2024-04-08	3	439	163	259
2024-09-15	3	762	425	338
2024-08-15	3	822	464	235
2024-02-22	4	402	163	491
2024-03-08	1	585	129	380
2024-02-20	3	396	193	223
2024-05-12	2	872	205	152
2024-05-20	5	687	133	157
2024-02-20	4	782	119	448
2024-06-30	2	250	220	267
2024-07-15	2	918	448	147
2024-01-18	2	678	379	432
2024-01-14	1	846	103	325
2024-01-09	3	552	356	202
2024-02-02	4	446	431	94
2024-09-16	4	805	298	337
2024-01-12	2	215	408	432
2024-06-05	5	849	134	131
2024-03-23	4	590	411	342
2024-08-14	4	141	200	376
2024-02-28	5	242	316	444
2024-09-10	1	794	245	460
2024-08-08	1	664	399	273
2024-04-01	1	219	162	205
2024-06-13	1	415	216	269
2024-05-01	1	125	486	415
2024-07-11	4	511	198	290
2024-06-08	1	732	483	215
2024-04-02	4	961	294	194
2024-03-13	4	325	255	95
2024-08-29	4	556	124	398
2024-04-18	4	465	452	348
2024-04-13	4	194	166	451
2024-03-17	3	434	182	420
2024-02-29	5	156	130	110
2024-01-05	2	722	359	97
2024-02-23	1	756	180	185
2024-02-16	4	299	274	482
2024-03-07	4	697	348	476
2024-07-09	5	639	413	287
2024-06-18	2	327	144	473
2024-06-01	2	900	122	477
2024-08-10	1	885	124	274
2024-07-28	1	384	429	107
2024-01-18	5	300	183	137
2024-05-06	1	123	314	370
2024-07-07	1	185	189	109
2024-01-11	2	651	471	406
2024-05-28	1	969	220	414
2024-03-01	4	556	145	379
2024-01-11	2	793	164	118
2024-07-16	5	787	303	255
2024-07-27	3	189	352	433
2024-08-19	1	624	457	251
2024-06-19	4	503	266	376
2024-06-20	2	299	427	437
2024-07-05	5	602	221	397
2024-04-01	3	425	306	488
2024-03-18	3	717	170	255
2024-03-08	5	719	257	409
2024-03-08	1	623	371	437
2024-07-28	3	157	450	303
2024-04-01	3	782	325	202
2024-02-19	3	469	356	503
2024-01-17	1	507	236	424
2024-05-23	4	251	360	273
2024-06-17	1	833	286	500
2024-06-21	5	974	302	270
2024-06-12	4	537	163	500
2024-01-18	2	478	181	186
2024-06-21	3	495	386	359
2024-08-28	5	481	326	321
2024-08-29	1	112	251	417
2024-03-15	1	391	398	182
2024-09-06	5	453	410	138
2024-06-11	4	459	145	235
2024-02-16	1	415	341	322
2024-06-25	4	556	301	320
2024-06-30	3	995	122	98
2024-04-20	5	674	323	105
2024-07-04	2	189	320	487
2024-08-17	5	320	197	459
2024-05-09	3	845	262	349
2024-03-18	4	554	500	158
2024-07-01	3	859	281	354
2024-07-21	1	525	232	460
2024-09-02	3	922	188	299
2024-09-09	1	553	112	199
2024-01-26	2	395	492	388
2024-09-10	1	267	151	96
2024-08-12	5	925	158	101
2024-02-15	1	845	342	91
2024-03-18	3	534	440	194
2024-04-17	2	846	204	299
2024-04-17	4	524	379	510
2024-08-21	2	242	404	431
2024-05-12	5	955	411	495
2024-05-12	3	701	164	309
2024-05-17	3	712	146	219
2024-04-10	3	188	242	326
2024-06-03	1	247	312	227
2024-09-08	2	312	163	310
2024-02-26	2	410	144	350
2024-02-13	1	586	398	176
2024-08-02	2	988	163	129
2024-09-12	4	637	394	160
2024-07-12	5	443	361	164
2024-03-16	1	167	203	340
2024-08-02	3	704	392	423
2024-06-06	3	874	159	391
2024-03-10	5	484	211	446
2024-04-17	4	190	250	327
2024-03-12	2	106	185	306
2024-05-29	1	519	436	250
2024-01-30	3	754	216	485
2024-07-06	4	379	160	450
2024-08-03	4	524	267	196
2024-05-27	5	279	208	110
2024-04-18	2	669	118	148
2024-03-08	5	573	319	338
2024-04-08	4	827	151	332
2024-02-15	5	681	101	111
2024-04-28	3	873	371	119
2024-06-27	2	240	237	439
2024-04-19	4	304	421	395
2024-07-12	1	290	481	480
2024-08-21	3	952	202	420
2024-08-19	2	490	496	209
2024-08-01	5	396	181	226
2024-05-26	3	667	225	274
2024-02-07	3	602	480	461
2024-03-09	3	143	438	331
2024-05-24	3	942	156	230
2024-04-10	2	946	442	312
2024-01-31	3	409	180	252
2024-01-06	3	954	126	176
2024-05-27	3	699	140	456
2024-09-10	5	411	254	214
2024-04-02	4	605	370	489
2024-07-09	1	672	338	171
2024-09-04	1	857	492	108
2024-04-24	4	574	216	365
2024-03-20	4	329	279	486
2024-07-24	4	127	248	107
2024-08-16	1	910	244	180
2024-05-27	1	102	296	437
2024-08-16	1	257	172	268
2024-02-07	1	368	291	312
2024-06-28	2	407	415	151
2024-03-23	2	755	330	205
2024-04-05	5	954	440	202
2024-02-25	5	751	243	191
2024-05-16	5	583	108	211
2024-06-07	4	227	161	472
2024-05-07	2	769	454	286
2024-07-02	5	781	261	279
2024-01-20	3	394	152	494
2024-04-18	5	527	351	336
2024-06-01	1	283	424	312
2024-06-25	3	603	163	129
2024-01-01	4	804	251	110
2024-06-06	5	760	456	230
2024-08-29	5	350	208	105
2024-01-09	2	129	283	429
2024-02-03	3	222	303	473
2024-07-08	4	883	176	265
2024-04-24	5	383	356	366
2024-04-07	4	604	183	334
2024-04-21	3	168	277	143
2024-01-05	4	713	134	503
2024-03-05	1	863	285	265
2024-02-27	5	470	240	425
2024-06-10	3	695	109	152
2024-07-25	5	592	386	475
2024-07-21	5	679	223	203
2024-02-22	3	546	275	382
2024-02-21	1	989	321	448
2024-03-14	4	364	210	159
2024-02-11	4	743	122	191
2024-07-11	4	802	480	244
2024-03-04	1	810	245	353
2024-01-26	4	937	422	307
2024-09-13	3	222	427	367
2024-04-22	3	482	278	312
2024-05-01	2	624	152	471
2024-06-04	4	850	306	318
2024-02-09	2	689	234	229
2024-06-02	3	117	413	184
2024-02-10	3	965	375	221
2024-02-15	4	365	441	256
2024-03-22	5	266	349	386
2024-02-11	3	695	312	503
2024-06-02	1	159	332	120
2024-05-12	1	249	236	251
2024-04-15	4	427	320	292
2024-06-02	4	572	361	495
2024-07-08	5	999	241	411
2024-04-30	5	809	332	239
2024-09-11	5	238	434	122
2024-02-26	5	465	406	311
2024-03-11	1	267	415	483
2024-07-11	4	154	125	426
2024-03-07	4	379	307	251
2024-07-08	5	469	494	118
2024-04-18	2	529	167	274
2024-04-03	2	751	291	314
2024-02-08	2	464	467	123
2024-06-06	3	149	499	422
2024-05-04	4	396	136	242
2024-08-01	5	398	249	204
2024-06-29	3	642	285	333
2024-03-19	3	754	407	223
2024-04-19	2	178	211	353
2024-07-29	5	626	478	474
2024-01-26	4	298	114	187
2024-07-18	2	884	419	180
2024-08-04	2	743	138	169
2024-07-11	3	287	360	413
2024-03-21	4	883	244	258
2024-03-11	4	196	447	230
2024-05-20	1	713	373	497
2024-03-27	1	870	363	264
2024-07-10	1	271	181	206
2024-08-14	4	656	231	351
2024-08-09	3	430	176	421
2024-01-22	1	993	133	90
2024-03-18	5	423	137	92
2024-01-09	2	946	478	284
2024-07-28	5	965	111	406
2024-04-15	3	801	352	245
2024-06-01	2	919	117	300
2024-08-14	1	408	168	284
2024-04-05	5	377	377	297
2024-08-05	4	801	367	338
2024-06-21	4	814	220	432
2024-06-10	1	804	313	96
2024-02-08	1	471	162	243
2024-09-08	1	198	472	96
2024-09-11	1	647	397	264
2024-03-01	1	693	262	495
2024-04-19	2	460	298	445
2024-09-08	3	943	201	322
2024-07-20	4	247	215	134
2024-06-25	1	113	456	477
2024-05-01	2	240	292	374
2024-01-24	3	630	236	359
2024-01-29	4	388	267	306
2024-02-22	5	481	423	297
2024-04-29	3	897	234	355
2024-03-12	1	596	417	396
2024-07-02	5	521	500	167
2024-09-04	5	448	261	413
2024-05-09	2	266	109	309
2024-02-09	5	204	388	266
2024-02-07	5	323	168	351
2024-08-21	1	258	248	398
2024-08-07	4	615	204	262
2024-04-26	3	326	151	136
2024-01-18	2	951	257	341
2024-08-03	2	292	497	469
2024-05-08	2	914	481	174
2024-01-04	5	672	374	494
2024-04-03	3	728	141	479
2024-04-01	3	806	381	255
2024-01-15	4	951	322	158
2024-04-02	3	638	232	439
2024-05-25	5	966	270	106
2024-06-13	1	644	420	184
2024-03-28	5	829	428	188
2024-02-12	2	664	447	287
2024-01-17	4	819	144	309
2024-04-18	3	874	439	142
2024-02-06	1	921	302	392
2024-06-04	5	216	195	141
2024-09-11	4	527	291	437
2024-06-21	5	571	133	180
2024-01-28	5	178	114	163
2024-08-26	2	219	234	348
2024-08-30	3	938	132	506
2024-03-16	2	234	181	420
2024-02-25	4	117	175	313
2024-04-03	3	591	339	299
2024-07-13	2	456	342	395
2024-04-13	2	419	258	361
2024-07-03	3	807	148	364
2024-08-22	4	471	255	178
2024-06-21	4	242	244	497
2024-08-05	3	936	100	306
2024-04-22	5	552	184	222
2024-02-03	3	711	184	189
2024-07-30	2	635	159	466
2024-04-06	4	881	152	434
2024-03-05	2	450	448	114
2024-01-16	3	276	131	417
2024-01-17	5	826	361	176
2024-06-10	2	411	155	197
2024-02-07	2	129	160	338
2024-06-30	5	862	161	155
2024-05-16	5	934	399	137
2024-07-24	3	221	168	331
2024-01-04	3	327	452	432
2024-05-28	5	231	158	465
2024-08-03	5	977	285	488
2024-03-16	5	810	176	134
2024-05-26	1	245	116	178
2024-01-13	2	332	107	212
2024-08-10	5	414	401	192
2024-03-11	4	228	158	289
2024-06-15	5	314	476	222
2024-03-24	4	233	389	327
2024-05-02	5	180	321	171
2024-08-21	2	535	277	166
2024-07-22	4	807	489	209
2024-07-16	1	881	316	259
2024-04-05	2	902	463	191
2024-04-04	5	214	361	204
2024-01-14	5	179	264	472
2024-08-15	3	119	234	465
2024-08-10	2	893	294	399
2024-07-13	2	595	475	171
2024-09-13	5	875	370	420
2024-09-11	3	541	201	437
2024-07-29	3	143	256	367
2024-01-05	2	301	241	503
2024-08-28	4	210	341	156
2024-02-20	4	133	363	358
2024-01-16	2	912	477	429
2024-06-12	3	775	407	363
2024-06-30	2	625	341	194
2024-03-14	1	707	162	237
2024-06-21	3	160	192	382
2024-02-10	2	580	345	254
2024-08-20	3	221	325	452
2024-03-23	4	359	428	187
2024-05-22	5	144	303	369
2024-04-25	5	167	339	333
2024-03-09	4	408	192	296
2024-06-18	5	783	344	118
2024-04-18	3	110	133	211
2024-03-14	1	872	462	161
2024-05-05	1	198	116	408
2024-03-09	1	901	420	388
2024-05-17	3	226	317	145
2024-02-12	3	716	330	221
2024-07-19	2	310	363	348
2024-07-31	4	701	357	395
2024-06-11	5	304	274	114
2024-01-14	1	289	201	165
2024-06-23	3	786	327	483
2024-02-22	3	459	311	443
2024-08-09	3	129	379	232
2024-06-06	2	192	196	167
2024-07-02	4	249	487	469
2024-02-25	3	966	304	436
2024-07-18	1	864	497	194
2024-02-23	2	384	138	469
2024-04-18	4	693	299	407
2024-06-16	1	456	369	253
2024-04-09	2	460	358	184
2024-03-01	1	264	259	346
2024-02-10	3	975	306	389
2024-03-23	5	612	179	284
2024-02-27	1	899	193	287
2024-02-07	5	846	122	383
2024-06-04	3	727	342	378
2024-03-05	1	347	428	404
2024-01-23	1	617	309	252
2024-04-18	3	683	402	466
2024-07-16	5	169	205	279
2024-08-04	2	201	468	359
2024-05-27	2	939	341	449
2024-01-22	2	692	337	144
2024-04-13	2	881	233	194
2024-05-31	3	114	263	165
2024-08-04	1	641	251	228
2024-08-10	3	322	482	506
2024-04-24	1	832	175	206
2024-03-04	2	296	476	206
2024-05-30	3	388	113	485
2024-02-19	1	275	403	444
2024-05-09	5	872	395	289
2024-09-15	2	650	439	262
2024-05-24	3	104	343	342
2024-03-02	2	842	190	128
2024-05-11	1	201	213	293
2024-05-09	1	319	440	448
2024-07-15	5	616	312	335
2024-03-13	3	971	479	198
2024-07-30	5	824	261	109
2024-08-07	4	586	356	416
2024-07-02	3	475	331	211
2024-09-07	5	814	377	177
2024-03-30	4	703	241	338
2024-03-09	1	289	304	207
2024-04-24	5	550	339	216
2024-08-09	1	789	373	133
2024-08-26	4	209	307	326
2024-02-11	2	285	469	362
2024-04-06	3	954	403	452
2024-05-23	3	463	152	234
2024-03-05	3	488	224	469
2024-04-13	2	534	233	427
2024-03-13	3	319	116	131
2024-08-02	2	626	377	476
2024-01-06	3	333	423	473
2024-04-24	4	517	180	367
2024-05-25	4	215	174	492
2024-07-17	4	879	255	182
2024-08-09	4	421	149	292
2024-07-06	3	226	113	99
2024-06-07	3	577	394	242
2024-05-30	3	212	109	422
2024-03-07	1	632	170	361
2024-03-25	4	239	142	265
2024-01-03	3	607	139	477
2024-05-26	1	880	219	381
2024-04-13	2	469	322	450
2024-07-02	5	821	469	143
2024-07-12	3	395	488	441
2024-01-04	4	670	446	500
2024-08-08	3	839	119	203
2024-07-20	5	141	129	138
2024-09-13	5	184	272	217
2024-08-16	4	435	460	113
2024-04-25	5	605	331	198
2024-06-28	4	218	359	354
2024-08-19	1	494	364	368
2024-09-06	1	390	220	396
2024-07-15	1	567	467	397
2024-06-15	2	714	445	299
2024-05-12	4	853	384	258
2024-07-30	3	419	290	267
2024-07-04	1	803	119	397
2024-03-21	4	961	178	391
2024-05-16	2	554	325	321
2024-03-23	4	331	254	301
2024-03-15	3	667	438	475
2024-09-14	3	517	102	317
2024-03-09	2	397	392	396
2024-04-07	4	975	448	153
2024-08-26	4	538	253	110
2024-09-12	1	293	106	286
2024-08-21	2	977	377	180
2024-01-21	1	171	349	501
2024-09-11	3	961	179	105
2024-04-02	3	921	129	215
2024-06-25	4	587	258	302
2024-02-10	5	795	351	236
2024-03-10	1	476	484	294
2024-04-07	5	283	298	106
2024-02-09	2	113	467	108
2024-06-22	5	790	425	496
2024-05-21	5	603	284	486
2024-01-15	3	788	393	384
2024-01-07	5	207	109	457
2024-02-28	4	505	385	369
2024-01-13	2	548	387	327
2024-03-29	3	635	482	334
2024-02-11	3	774	383	325
2024-01-05	3	792	191	211
2024-02-23	2	187	279	441
2024-09-07	1	222	128	272
2024-02-23	4	246	321	298
2024-04-10	5	504	307	486
2024-06-20	5	510	123	228
2024-03-19	4	811	494	222
2024-06-28	5	704	407	376
2024-02-09	1	204	319	225
2024-08-06	1	859	244	419
2024-01-28	2	272	306	374
2024-03-11	2	166	355	319
2024-02-15	3	472	377	444
2024-05-02	4	303	453	413
2024-08-08	5	446	177	368
2024-03-21	4	305	304	404
2024-01-18	1	709	359	387
2024-04-20	2	964	131	402
2024-08-04	4	513	204	279
2024-01-31	2	225	457	346
2024-02-06	3	338	353	432
2024-02-25	5	958	487	356
2024-02-29	4	534	475	303
2024-08-18	3	842	402	118
2024-06-22	2	611	242	210
2024-02-07	5	385	151	383
2024-08-28	4	883	327	450
2024-06-17	5	830	489	412
2024-05-19	2	884	232	317
2024-09-14	2	695	268	406
2024-02-14	3	707	286	113
2024-04-15	5	379	208	313
2024-07-24	2	874	389	456
2024-05-17	1	908	204	485
2024-04-10	3	920	452	227
2024-04-07	2	759	228	437
2024-09-11	1	509	287	279
2024-07-13	1	464	356	424
2024-02-10	1	587	395	461
2024-03-17	3	782	147	223
2024-07-04	3	717	244	297
2024-03-01	2	514	217	293
2024-07-22	4	596	211	95
2024-04-15	1	623	338	498
2024-01-18	1	385	241	385
2024-02-11	3	250	134	311
2024-04-20	2	886	288	220
2024-05-08	2	565	428	360
2024-07-30	4	210	328	219
2024-01-03	5	225	177	510
2024-02-01	4	356	371	334
2024-08-31	1	601	154	232
2024-07-23	3	609	189	476
2024-09-10	1	336	172	251
2024-08-03	4	743	309	151
2024-07-26	3	130	335	299
2024-01-13	3	201	367	302
2024-09-01	1	855	326	462
2024-01-01	3	154	257	484
2024-01-31	1	950	370	496
2024-04-07	3	169	324	119
2024-06-26	4	610	292	456
2024-06-18	1	794	197	453
2024-05-21	5	127	175	119
2024-03-06	2	283	491	392
2024-09-15	4	491	483	342
2024-02-11	2	719	412	448
2024-08-30	5	795	233	508
2024-03-15	4	434	499	451
2024-07-24	3	256	175	345
2024-04-07	2	410	475	251
2024-04-23	4	736	241	412
2024-07-11	5	738	350	189
2024-09-04	1	198	255	325
2024-05-11	2	878	414	419
2024-01-24	2	178	223	216
2024-06-16	2	776	464	363
2024-02-12	3	869	374	389
2024-03-24	5	632	387	189
2024-03-25	2	885	179	271
2024-01-01	2	604	336	439
2024-04-09	1	911	395	494
2024-02-27	2	577	319	119
2024-08-23	4	306	198	447
2024-05-17	2	400	134	444
2024-04-27	4	777	100	254
2024-02-10	4	609	156	492
2024-03-26	5	602	181	323
2024-05-10	4	616	215	372
2024-02-05	4	367	247	282
2024-07-23	3	655	208	426
2024-05-15	5	451	491	224
2024-05-03	3	928	287	365
2024-01-28	5	980	256	153
2024-03-23	3	653	194	102
2024-06-28	4	659	231	336
2024-03-05	3	118	419	196
2024-06-10	3	882	279	489
2024-09-06	5	132	276	344
2024-05-23	5	540	419	431
2024-08-18	2	221	177	367
2024-01-20	1	492	306	299
2024-09-06	4	560	462	209
2024-02-12	2	422	430	462
2024-03-24	1	973	400	372
2024-04-05	5	485	254	285
2024-08-11	5	553	313	391
2024-09-07	5	570	403	125
2024-07-08	3	136	234	99
2024-05-30	5	133	315	108
2024-07-31	2	281	379	265
2024-04-30	2	670	227	322
2024-01-23	1	775	214	400
2024-03-11	1	981	398	313
2024-06-26	2	898	355	240
2024-05-20	5	410	477	369
2024-02-03	4	823	156	207
2024-05-28	3	268	201	223
2024-01-14	3	603	152	470
2024-01-19	1	541	132	248
2024-01-23	3	237	313	126
2024-06-01	2	419	410	149
2024-08-04	1	832	148	474
2024-08-16	2	498	227	231
2024-05-19	4	599	273	475
2024-04-28	4	882	385	498
2024-07-11	4	212	382	206
2024-02-10	4	682	143	210
2024-07-21	3	791	320	331
2024-08-06	2	602	310	313
2024-05-28	2	775	277	302
2024-04-25	1	667	419	307
2024-05-12	2	801	376	483
2024-04-16	3	652	145	379
2024-09-05	3	685	358	455
2024-03-07	2	581	250	451
2024-05-23	2	587	333	389
2024-05-26	4	675	119	134
2024-07-30	2	974	351	309
2024-05-30	2	260	137	494
2024-05-15	4	618	124	318
2024-02-17	1	157	496	158
2024-01-26	2	500	364	161
2024-05-26	1	369	288	232
2024-08-10	4	606	261	187
2024-08-18	1	705	283	404
2024-08-05	2	486	232	336
2024-05-31	5	731	130	299
2024-08-07	3	792	454	172
2024-01-10	5	461	443	504
2024-04-02	5	884	337	439
2024-08-04	5	391	239	211
2024-05-18	2	428	196	396
2024-07-20	4	162	493	333
2024-08-27	5	128	249	375
2024-03-08	4	704	374	215
2024-05-12	4	146	317	131
2024-07-29	2	231	335	422
2024-06-24	5	957	413	127
2024-05-17	3	475	135	148
2024-01-15	2	457	385	255
2024-09-03	3	928	202	99
2024-08-11	1	859	416	158
2024-08-29	4	697	302	214
2024-03-03	1	127	227	356
2024-03-12	3	740	434	353
2024-04-26	2	449	478	248
2024-03-09	4	489	229	238
2024-05-26	5	199	133	448
2024-05-28	3	538	304	284
2024-06-14	3	453	176	320
2024-06-26	4	465	328	277
2024-08-15	2	521	455	212
2024-08-11	5	459	294	194
2024-08-28	5	157	194	218
2024-06-18	3	777	179	496
2024-01-14	2	350	298	107
2024-08-20	5	353	354	240
2024-07-30	1	340	476	231
2024-03-08	1	419	414	490
2024-05-13	2	706	136	138
2024-08-04	5	186	155	152
2024-05-08	1	804	426	176
2024-04-15	4	167	303	434
2024-02-26	2	989	313	377
2024-01-25	5	412	144	257
2024-05-30	1	217	358	113
2024-08-01	3	445	441	340
2024-06-20	5	273	393	480
2024-05-08	4	120	376	378
2024-05-04	1	651	220	413
2024-03-12	2	433	450	297
2024-03-31	2	138	147	392
2024-01-30	4	571	147	136
2024-06-02	4	773	325	227
2024-02-22	2	984	426	318
2024-08-05	5	532	240	302
2024-01-04	2	681	154	102
2024-07-07	1	627	112	420
2024-04-06	4	531	436	236
2024-08-09	2	373	427	502
2024-02-13	3	120	257	428
2024-06-25	5	812	201	379
2024-08-20	3	580	200	183
2024-06-24	1	702	498	429
2024-09-13	3	122	393	368
2024-03-13	5	424	166	440
2024-03-31	2	486	309	238
2024-01-10	4	684	113	282
2024-08-24	3	499	358	124
2024-03-15	1	430	308	338
2024-07-09	5	686	191	364
2024-03-10	1	200	178	453
2024-07-27	2	927	313	374
2024-07-19	4	600	436	484
2024-01-13	1	202	353	104
2024-07-20	5	807	377	249
2024-02-17	5	791	369	144
2024-01-19	1	310	344	211
2024-01-04	5	444	104	504
2024-02-17	4	608	389	194
2024-09-09	2	614	112	332
2024-07-04	2	930	162	456
2024-03-11	5	883	464	372
2024-07-10	1	783	454	115
2024-08-20	4	447	119	147
2024-03-03	5	270	382	223
2024-02-11	2	729	141	187
2024-04-19	5	406	298	456
2024-05-15	1	472	496	275
2024-06-24	1	546	432	259
2024-09-07	3	306	226	261
2024-03-20	3	608	499	119
2024-05-17	2	750	319	391
2024-05-25	2	967	117	429
2024-05-16	1	906	111	260
2024-05-16	3	177	287	227
2024-06-24	1	960	189	245
2024-03-07	4	970	491	263
2024-08-22	5	648	253	244
2024-06-17	2	319	423	381
2024-08-07	2	394	444	390
2024-02-10	2	371	393	261
2024-01-16	5	148	200	165
2024-08-23	3	404	384	425
2024-05-06	1	687	201	254
2024-08-13	1	511	284	386
2024-03-10	1	923	124	362
2024-09-09	4	331	417	288
2024-01-29	3	739	100	238
2024-04-09	5	860	206	458
2024-01-15	4	194	356	389
2024-08-31	3	834	187	448
2024-05-28	4	964	146	438
2024-02-29	1	692	284	157
2024-04-21	5	197	371	232
2024-08-14	2	706	476	225
2024-08-11	2	444	316	396
2024-02-25	2	379	186	374
2024-04-09	5	168	443	193
2024-04-16	1	680	271	440
2024-07-15	1	920	152	401
2024-01-11	1	643	130	157
2024-05-19	5	586	160	446
2024-03-08	4	537	217	156
2024-08-04	5	314	185	482
2024-07-12	1	455	148	388
2024-05-16	3	914	447	201
2024-04-25	5	178	469	330
2024-08-24	4	767	281	224
2024-08-03	3	943	265	294
2024-06-18	5	409	342	300
2024-07-02	2	616	421	223
2024-01-25	3	923	200	371
2024-05-20	5	407	166	460
2024-01-26	2	543	342	442
2024-03-26	5	779	407	317
2024-03-17	5	652	122	251
2024-05-21	4	420	455	504
2024-09-06	1	304	423	445
2024-08-07	1	524	341	477
2024-02-28	4	511	127	109
2024-07-27	4	357	491	191
2024-06-28	3	739	331	454
2024-07-03	1	627	148	184
2024-03-27	4	564	243	277
2024-04-26	3	787	268	381
2024-01-06	3	881	471	248
2024-06-18	1	660	424	147
2024-07-13	3	284	371	223
2024-04-23	5	119	494	111
2024-04-15	1	742	169	500
2024-09-11	3	820	190	267
2024-02-04	1	628	206	330
2024-09-13	5	983	209	268
2024-08-03	3	291	340	404
2024-06-09	3	690	121	486
2024-09-13	5	611	206	388
2024-07-23	3	318	403	268
2024-05-03	1	776	113	453
2024-05-03	4	943	407	250
2024-01-27	2	860	286	394
2024-03-30	2	578	130	290
2024-05-28	4	374	461	267
2024-01-02	4	753	376	144
2024-04-20	1	645	101	187
2024-07-11	3	928	449	153
2024-03-03	4	729	349	178
2024-08-26	2	973	153	509
2024-05-10	4	887	448	361
2024-08-20	2	544	105	107
2024-06-02	1	679	160	138
2024-05-31	4	844	281	457
2024-03-13	3	741	411	269
2024-04-11	5	161	269	460
2024-05-21	1	634	264	147
2024-06-14	5	305	414	139
2024-07-17	3	473	150	251
2024-01-05	2	573	397	197
2024-03-31	5	251	381	361
2024-01-20	3	346	492	276
2024-08-04	2	254	267	482
2024-09-02	1	864	389	186
2024-01-21	3	801	341	291
2024-01-11	3	883	129	111
2024-04-30	5	407	465	191
2024-04-24	3	964	209	367
2024-05-31	4	545	339	241
2024-06-25	2	520	181	302
2024-04-13	5	426	162	495
2024-09-11	4	980	432	332
2024-05-21	4	950	429	278
2024-08-21	3	165	469	424
2024-06-17	2	749	239	320
2024-06-06	3	308	104	231
2024-08-03	1	966	365	415
2024-06-15	2	522	171	152
2024-01-27	1	373	412	386
2024-02-04	3	943	283	507
2024-03-15	5	393	437	180
2024-05-18	4	761	407	224
2024-06-10	4	264	245	285
2024-07-21	4	362	315	271
2024-03-14	3	803	106	403
2024-07-11	5	715	299	224
2024-03-16	4	341	488	122
2024-03-28	1	515	244	256
2024-05-12	1	344	159	129
2024-02-13	4	216	398	348
2024-03-22	1	253	479	129
2024-08-17	1	296	478	164
2024-04-10	3	128	223	163
2024-06-26	1	351	212	450
2024-03-07	3	916	494	467
2024-05-04	4	947	329	177
2024-08-02	3	417	481	161
2024-04-10	1	575	271	450
2024-08-20	5	597	271	382
2024-06-21	5	673	182	121
2024-06-01	5	546	132	399
2024-06-26	4	532	284	265
2024-07-18	4	762	290	343
2024-06-20	4	137	128	279
2024-07-06	2	306	433	120
2024-07-31	4	263	187	176
2024-08-06	3	379	325	172
2024-05-21	5	239	331	320
2024-01-19	1	129	157	474
2024-01-24	4	364	196	502
2024-03-10	1	908	299	127
2024-01-30	2	922	413	399
2024-01-22	1	384	428	487
2024-03-17	4	774	443	341
2024-06-22	1	663	345	483
2024-09-14	1	280	133	258
2024-04-09	3	759	392	490
2024-06-25	2	972	358	302
2024-04-26	4	143	239	419
2024-07-15	4	839	410	96
2024-07-17	5	597	263	408
2024-06-29	5	901	137	197
2024-06-22	2	120	208	189
2024-08-05	3	156	239	321
2024-02-17	1	980	147	319
2024-02-18	2	185	213	216
2024-01-14	5	421	116	179
2024-07-22	4	716	323	347
2024-07-21	3	405	210	299
2024-06-10	3	987	210	246
2024-07-25	1	165	306	315
2024-01-01	1	516	494	357
2024-01-26	2	472	377	413
2024-04-01	3	787	357	282
2024-06-30	2	773	202	178
2024-08-17	4	192	426	483
2024-06-30	1	506	418	379
2024-03-15	5	959	200	467
2024-01-27	4	962	452	317
2024-08-08	5	243	295	475
2024-01-16	3	341	441	126
2024-02-26	5	214	219	181
2024-05-27	4	684	492	348
2024-04-04	1	852	104	222
2024-07-01	2	612	492	100
2024-08-26	4	223	230	257
2024-05-19	3	634	235	477
2024-07-08	5	780	455	281
2024-04-21	1	948	292	265
2024-02-22	4	694	133	225
2024-06-15	3	893	289	168
2024-04-01	4	637	290	211
2024-06-14	1	357	420	156
2024-03-15	2	608	293	462
2024-03-23	4	192	210	469
2024-02-08	1	343	354	330
2024-06-08	2	714	472	170
2024-04-24	5	225	129	398
2024-06-16	2	891	185	331
2024-07-14	2	926	335	95
2024-03-28	4	420	355	184
2024-06-14	2	437	120	331
2024-07-29	3	952	181	362
2024-06-18	4	698	266	294
2024-06-28	5	854	227	228
2024-08-02	2	499	356	386
2024-09-04	3	925	148	147
2024-09-12	4	866	278	207
2024-07-23	4	861	181	427
2024-06-27	2	341	372	207
2024-08-03	5	533	499	149
2024-08-31	2	323	391	487
2024-09-11	2	247	334	460
2024-07-19	5	209	317	292
2024-05-09	5	279	153	497
2024-07-31	1	319	364	126
2024-06-27	3	381	241	473
2024-06-14	4	550	343	237
2024-07-25	1	518	485	273
2024-02-26	1	360	249	192
2024-04-08	3	983	293	458
2024-03-23	1	703	141	468
2024-02-12	5	157	473	365
2024-02-28	3	602	189	422
2024-04-11	2	646	324	314
2024-07-12	2	483	270	223
2024-06-10	3	816	103	339
2024-02-21	2	215	273	146
2024-03-20	3	424	114	253
2024-07-23	4	658	423	259
2024-05-10	4	533	203	346
2024-08-01	5	586	315	404
2024-07-13	5	799	129	387
2024-01-11	1	352	411	474
2024-08-06	1	384	197	184
2024-01-03	5	903	298	270
2024-07-17	3	248	158	230
2024-08-13	4	471	187	116
2024-09-03	1	586	197	185
2024-06-08	2	832	121	311
2024-09-14	4	476	139	234
2024-05-23	1	941	349	468
2024-01-01	5	415	316	163
2024-08-19	2	121	284	325
2024-05-04	5	760	116	508
2024-04-07	2	720	163	438
2024-01-18	3	135	190	136
2024-07-07	5	961	370	348
2024-04-08	2	857	424	306
2024-01-18	4	778	124	225
2024-08-25	3	918	425	146
2024-06-02	2	155	335	234
2024-07-21	2	807	450	277
2024-01-05	1	907	458	217
2024-08-22	1	787	333	476
2024-06-06	3	345	182	339
2024-03-26	4	359	146	189
2024-06-06	1	665	179	205
2024-05-13	3	493	143	313
2024-03-23	1	416	173	360
2024-07-08	1	754	165	282
2024-06-29	4	817	340	115
2024-09-15	4	471	322	170
2024-05-21	5	931	240	107
2024-05-18	4	801	177	442
2024-03-05	5	224	275	219
2024-04-08	4	647	140	90
2024-03-11	5	987	189	469
2024-06-17	5	342	258	504
2024-05-23	4	978	175	154
2024-01-15	3	553	318	269
2024-01-07	4	497	326	125
2024-05-23	5	108	467	211
2024-06-15	3	502	225	228
2024-08-18	2	361	391	266
2024-06-01	2	408	110	328
2024-09-07	4	192	449	446
2024-04-23	5	942	229	387
2024-06-19	5	874	500	504
2024-08-21	3	341	156	282
2024-04-17	1	404	210	232
2024-02-28	5	315	430	368
2024-09-12	4	980	160	352
2024-08-07	3	264	190	350
2024-06-23	3	549	169	329
2024-02-07	2	746	455	144
2024-06-28	4	424	243	407
2024-06-27	1	931	302	400
2024-05-01	4	885	148	142
2024-07-12	5	759	340	405
2024-04-24	4	516	247	501
2024-05-09	2	908	469	223
2024-08-09	1	134	306	146
2024-06-25	4	380	473	138
2024-02-18	4	987	413	105
2024-06-09	2	182	470	471
2024-01-20	5	942	452	136
2024-01-16	3	898	319	474
2024-07-21	4	603	343	226
2024-09-07	4	582	146	253
2024-01-15	3	854	314	97
2024-04-07	5	522	107	311
2024-05-27	3	961	205	132
2024-08-12	3	440	455	295
2024-06-23	3	834	269	504
2024-08-31	1	532	318	503
2024-06-28	4	997	399	454
2024-09-10	4	939	312	424
2024-02-21	5	202	307	128
2024-06-12	1	944	143	259
2024-08-19	2	264	470	112
2024-08-14	3	815	272	345
2024-04-05	1	367	248	184
2024-02-16	4	618	303	452
2024-05-03	3	167	166	381
2024-06-27	5	460	184	143
2024-08-29	3	530	364	400
2024-01-13	2	716	373	304
2024-04-21	4	846	272	121
2024-07-22	1	932	452	418
2024-05-29	3	660	162	302
2024-07-08	2	855	257	145
2024-04-10	5	434	496	228
2024-04-30	3	564	148	239
2024-02-01	5	811	185	400
2024-04-09	1	128	410	239
2024-07-16	1	880	480	448
2024-08-25	1	153	179	353
2024-09-08	4	756	336	159
2024-02-23	2	756	286	164
2024-04-06	4	288	294	96
2024-03-02	2	745	290	168
2024-07-10	3	554	326	331
2024-08-21	1	910	151	325
2024-09-14	2	756	140	277
2024-03-01	5	239	417	219
2024-07-28	2	103	410	226
2024-01-18	2	510	280	463
2024-09-06	2	304	375	142
2024-05-17	2	743	334	508
2024-06-05	1	412	441	106
2024-06-25	1	421	403	386
2024-08-14	1	689	124	385
2024-06-05	2	184	141	212
2024-05-26	5	213	204	264
2024-04-01	3	261	200	358
2024-08-27	1	355	423	275
2024-08-01	5	628	278	168
2024-03-24	5	830	426	157
2024-05-14	4	886	128	320
2024-09-15	5	950	305	233
2024-03-28	2	764	340	151
2024-07-31	2	881	357	297
2024-08-30	5	233	456	218
2024-04-01	3	967	303	337
2024-07-23	3	708	241	125
2024-07-31	1	802	450	379
2024-05-25	3	520	440	464
2024-03-19	3	911	498	395
2024-04-22	4	427	492	180
2024-01-25	4	562	195	131
2024-09-07	4	589	198	159
2024-05-01	5	994	499	455
2024-04-04	3	852	279	353
2024-04-16	3	236	415	124
2024-03-27	5	366	136	413
2024-02-26	4	277	203	435
2024-03-18	4	803	466	361
2024-06-10	4	707	285	435
2024-07-05	5	946	307	260
2024-08-18	3	435	326	345
2024-01-16	3	918	382	507
2024-07-12	4	388	342	137
2024-08-03	1	303	348	287
2024-09-13	1	186	136	206
2024-07-05	2	524	255	128
2024-03-03	1	476	165	111
2024-03-07	5	286	338	203
2024-06-07	5	502	407	99
2024-03-25	4	997	349	138
2024-01-24	3	486	213	110
2024-06-04	3	954	124	506
2024-02-10	4	684	344	476
2024-08-07	4	329	133	198
2024-04-03	4	121	263	189
2024-01-20	4	123	343	423
2024-03-25	4	671	238	378
2024-01-23	3	762	164	425
2024-02-16	4	726	315	484
2024-07-11	4	741	406	392
2024-08-26	4	334	447	339
2024-01-28	4	191	299	90
2024-03-24	3	573	408	202
2024-04-27	4	303	201	258
2024-02-22	4	368	233	479
2024-08-11	5	818	253	143
2024-08-30	1	972	278	281
2024-02-28	3	272	436	277
2024-06-07	2	150	203	338
2024-01-12	5	510	298	405
2024-08-22	1	732	474	496
2024-01-29	3	539	143	263
2024-03-17	2	714	114	209
2024-09-07	1	366	261	443
2024-08-21	4	252	141	497
2024-09-11	3	191	199	296
2024-07-07	3	476	379	224
2024-05-22	3	274	142	467
2024-02-23	2	680	114	167
2024-07-07	5	220	152	124
2024-05-14	4	114	271	463
2024-07-25	3	835	468	196
2024-09-02	5	638	276	437
2024-06-23	3	545	157	339
2024-04-08	1	891	296	405
2024-08-15	1	564	220	123
2024-03-14	1	947	259	146
2024-03-18	1	789	138	462
2024-04-17	4	606	422	502
2024-02-29	1	221	271	251
2024-04-14	2	329	276	289
2024-03-28	1	830	269	386
2024-05-03	1	308	161	399
2024-04-10	1	295	165	320
2024-01-12	4	982	202	133
2024-05-11	2	932	495	274
2024-01-18	4	900	247	107
2024-08-17	3	372	184	377
2024-05-16	3	394	193	487
2024-06-19	3	864	394	222
2024-04-07	2	606	457	107
2024-04-28	2	491	315	318
2024-04-22	5	233	240	298
2024-07-23	4	541	183	304
2024-04-25	5	976	376	507
2024-07-29	1	311	406	406
2024-03-28	3	714	185	328
2024-02-09	5	320	160	400
2024-06-30	4	943	315	455
2024-04-29	1	389	270	499
2024-01-10	2	844	134	145
2024-07-26	1	793	319	334
2024-06-12	1	293	111	361
2024-01-04	4	528	275	205
2024-01-17	2	284	102	314
2024-01-13	1	518	330	246
2024-06-06	4	911	233	292
2024-03-09	3	249	145	433
2024-08-17	5	129	467	495
2024-05-21	5	397	285	249
2024-08-27	4	368	102	214
2024-03-21	4	341	336	347
2024-02-25	2	732	190	463
2024-07-31	3	561	215	472
2024-02-11	4	354	367	507
2024-04-01	4	478	435	430
2024-05-19	2	696	434	503
2024-09-14	1	800	402	91
2024-08-13	5	762	273	200
2024-06-25	2	569	249	304
2024-05-19	2	187	184	413
2024-08-13	5	110	378	327
2024-06-28	3	580	326	419
2024-01-27	2	236	267	163
2024-06-02	5	992	483	188
2024-05-13	2	431	357	121
2024-03-03	5	809	171	110
2024-04-09	1	507	391	329
2024-08-28	2	803	477	403
2024-03-22	1	317	226	145
2024-01-17	2	830	477	262
2024-08-08	2	492	109	218
2024-04-21	5	825	450	282
2024-07-20	5	533	454	426
2024-06-20	5	853	247	500
2024-06-12	5	711	454	96
2024-02-22	1	362	176	300
2024-01-14	3	174	492	424
2024-04-08	5	197	429	93
2024-03-21	4	670	116	139
2024-02-24	3	160	354	264
2024-01-21	3	153	460	236
2024-03-16	1	440	140	437
2024-06-27	1	340	106	352
2024-06-15	3	582	226	491
2024-03-18	3	462	162	170
2024-04-02	1	720	238	320
2024-04-01	4	786	178	170
2024-08-25	3	921	163	183
2024-03-13	3	712	116	94
2024-02-23	2	826	296	98
2024-08-25	3	866	277	310
2024-01-14	3	929	213	440
2024-01-25	2	146	496	407
2024-09-16	1	105	419	329
2024-02-11	4	359	116	448
2024-01-30	5	616	218	346
2024-09-06	3	734	405	485
2024-01-21	5	490	139	338
2024-08-18	3	409	266	493
2024-05-20	2	504	407	346
2024-03-27	4	787	268	234
2024-07-19	1	479	416	362
2024-02-26	4	235	307	379
2024-09-01	3	672	127	414
2024-01-14	3	142	427	444
2024-08-26	4	694	222	396
2024-06-20	1	283	490	117
2024-03-05	2	366	375	480
2024-05-04	3	273	244	119
2024-09-04	5	615	247	426
2024-03-09	4	604	279	431
2024-07-10	1	447	350	362
2024-08-20	1	998	438	465
2024-09-06	2	579	119	295
2024-06-22	1	235	462	218
2024-08-23	4	191	260	309
2024-04-07	5	424	260	335
2024-03-04	2	827	370	272
2024-05-28	3	643	438	182
2024-01-16	3	543	416	371
2024-01-27	4	245	478	109
2024-03-26	4	366	423	324
2024-01-22	1	219	224	252
2024-06-06	4	420	483	235
2024-06-05	2	145	280	182
2024-07-03	2	230	138	104
2024-09-14	1	611	321	501
2024-05-15	1	992	336	142
2024-02-26	3	954	275	450
2024-03-02	1	387	109	249
2024-08-27	4	865	124	178
2024-05-24	3	469	246	493
2024-02-07	5	540	281	387
2024-08-08	4	389	309	484
2024-06-17	1	997	142	300
2024-08-22	2	369	294	381
2024-06-08	3	727	292	389
2024-02-24	4	949	242	360
2024-06-10	5	879	384	368
2024-04-13	5	370	335	265
2024-05-06	1	629	208	326
2024-01-11	1	420	449	415
2024-03-10	1	546	237	390
2024-06-16	5	268	479	449
2024-06-08	4	423	211	201
2024-07-06	2	854	169	366
2024-07-27	3	603	443	438
2024-08-09	4	882	251	502
2024-01-10	1	254	408	204
2024-02-16	3	669	192	228
2024-07-01	4	973	466	153
2024-08-19	4	773	226	207
2024-08-27	2	751	377	375
2024-01-18	1	917	365	150
2024-09-08	2	550	436	202
2024-02-08	4	154	476	405
2024-02-21	1	293	406	147
2024-03-08	3	252	184	236
2024-01-06	2	155	283	103
2024-01-31	4	335	107	277
2024-01-18	1	287	480	510
2024-04-27	3	136	109	231
2024-04-24	5	581	457	270
2024-06-27	4	366	105	310
2024-05-28	1	267	105	369
2024-01-27	4	822	254	138
2024-01-11	2	578	309	171
2024-08-01	4	546	209	458
2024-01-03	4	218	309	494
2024-04-23	1	606	452	257
2024-08-21	1	141	339	407
2024-08-21	5	552	140	416
2024-08-02	5	465	451	224
2024-01-21	5	826	239	114
2024-03-13	2	674	273	152
2024-08-18	4	596	433	479
2024-03-14	5	568	353	368
2024-07-28	1	604	360	401
2024-03-18	5	215	422	429
2024-01-11	1	966	396	436
2024-01-13	3	837	303	451
2024-09-12	2	987	216	506
2024-01-22	5	251	181	348
2024-08-07	2	226	125	100
2024-07-08	1	457	318	281
2024-02-12	4	195	334	198
2024-01-27	2	308	345	352
2024-03-05	5	989	149	437
2024-02-12	2	390	284	461
2024-07-17	5	284	110	348
2024-03-11	3	954	240	163
2024-04-27	5	272	498	391
2024-02-17	1	867	139	338
2024-03-19	5	620	313	159
2024-06-26	3	942	464	197
2024-07-21	3	379	169	301
2024-06-15	4	676	302	131
2024-02-28	2	779	410	151
2024-01-18	3	699	165	370
2024-09-01	3	317	185	258
2024-06-09	4	697	182	322
2024-03-20	2	104	465	435
2024-07-09	2	638	263	342
2024-05-23	5	885	266	494
2024-04-24	5	684	196	339
2024-06-27	4	284	412	392
2024-09-12	3	526	363	254
2024-06-25	4	178	214	138
2024-04-12	4	352	133	170
2024-04-19	2	886	445	429
2024-09-10	2	610	279	241
2024-05-16	1	793	104	134
2024-06-25	2	196	121	337
2024-09-16	3	436	340	435
2024-08-09	5	126	488	405
2024-04-21	1	391	422	436
2024-04-25	2	797	341	372
2024-08-13	3	796	460	491
2024-08-03	2	224	454	225
2024-08-12	2	503	473	201
2024-04-07	4	482	296	200
2024-07-01	2	704	209	426
2024-07-29	3	208	151	392
2024-05-25	2	957	183	377
2024-03-17	1	431	113	181
2024-07-09	5	257	230	141
2024-03-04	3	129	193	421
2024-03-18	5	183	294	485
2024-05-15	2	571	184	109
2024-07-18	5	950	370	244
2024-07-06	4	824	278	452
2024-09-16	3	775	333	147
2024-05-06	3	591	221	384
2024-09-10	1	564	329	175
2024-08-16	1	743	262	177
2024-03-07	3	375	300	233
2024-01-21	5	708	362	461
2024-01-07	3	773	456	275
2024-07-22	2	105	238	96
2024-05-13	5	437	309	454
2024-03-27	2	144	411	439
2024-08-01	3	771	306	481
2024-03-28	1	737	169	459
2024-03-17	3	563	283	290
2024-08-29	2	432	142	220
2024-04-29	3	849	465	227
2024-07-28	5	851	195	183
2024-05-16	4	916	132	212
2024-03-26	3	682	366	496
2024-09-07	3	232	429	415
2024-03-16	5	316	129	248
2024-08-20	1	983	174	152
2024-03-30	2	149	249	304
2024-09-16	2	920	100	373
2024-06-29	2	759	260	321
2024-03-17	1	389	435	106
2024-02-28	5	430	451	176
2024-04-22	1	917	139	347
2024-04-21	1	156	316	141
2024-02-23	1	861	181	127
2024-07-09	4	172	448	290
2024-04-02	5	660	245	507
2024-07-21	2	716	223	339
2024-07-13	3	490	175	261
2024-06-20	3	194	336	412
2024-01-02	5	508	487	435
2024-03-17	3	361	151	466
2024-06-10	2	282	404	108
2024-04-30	5	345	289	155
2024-05-13	5	889	410	165
2024-08-07	1	986	200	97
2024-08-27	5	508	164	479
2024-05-31	4	191	380	394
2024-02-18	4	121	162	444
2024-07-24	5	972	393	465
2024-06-04	1	313	112	407
2024-07-23	2	266	494	180
2024-08-31	2	497	238	221
2024-03-05	3	898	300	291
2024-09-05	2	512	310	116
2024-05-28	2	391	454	326
2024-03-30	4	762	126	303
2024-05-30	4	870	178	182
2024-07-14	2	769	482	308
2024-09-15	4	257	475	195
2024-02-02	4	223	359	507
2024-05-12	3	405	463	169
2024-08-23	3	602	436	320
2024-07-15	3	920	340	218
2024-04-18	4	542	397	380
2024-05-03	4	853	111	160
2024-06-02	5	925	174	467
2024-06-07	4	417	217	266
2024-03-19	2	801	162	282
2024-01-25	4	717	233	151
2024-02-27	3	234	393	176
2024-03-30	4	467	405	365
2024-02-09	2	781	288	255
2024-03-22	3	198	149	210
2024-09-15	3	952	460	389
2024-08-25	3	476	336	215
2024-03-25	1	624	343	195
2024-09-15	5	304	282	149
2024-02-23	3	601	454	141
2024-02-14	4	556	298	214
2024-03-24	5	497	291	178
2024-07-14	2	587	342	115
2024-03-30	4	374	467	110
2024-03-10	4	676	114	377
2024-01-26	4	714	164	156
2024-02-29	5	533	222	111
2024-02-05	3	192	142	465
2024-05-08	2	874	303	456
2024-09-08	1	532	180	479
2024-04-07	2	930	376	279
2024-05-17	1	477	213	370
2024-03-24	2	728	445	142
2024-08-24	1	290	195	104
2024-03-04	3	544	418	435
2024-06-11	2	745	373	432
2024-03-20	4	536	436	317
2024-08-19	5	195	216	282
2024-03-08	2	141	154	394
2024-01-16	5	625	457	209
2024-08-19	3	449	189	367
2024-03-13	5	574	225	134
2024-02-28	5	792	272	438
2024-05-06	2	329	496	217
2024-08-27	3	763	382	285
2024-08-26	2	802	449	119
2024-01-01	2	830	282	420
2024-05-06	1	258	169	155
2024-08-17	5	607	492	398
2024-04-27	4	639	489	142
2024-01-03	2	744	124	491
2024-09-07	4	762	377	492
2024-02-23	1	637	439	406
2024-05-07	1	185	134	306
2024-09-09	1	397	135	148
2024-07-06	3	579	403	307
2024-07-17	1	547	336	141
2024-09-07	2	181	414	360
2024-04-23	3	920	343	255
2024-03-31	4	589	273	329
2024-04-20	4	407	111	288
2024-07-16	2	252	351	169
2024-08-25	2	230	492	245
2024-08-05	1	800	263	343
2024-02-24	5	407	381	497
2024-07-05	2	961	497	167
2024-06-29	1	354	109	450
2024-02-21	1	635	359	447
2024-01-25	5	537	288	332
2024-08-07	2	402	409	445
2024-08-06	4	682	450	258
2024-06-25	5	148	404	431
2024-08-30	1	664	347	370
2024-07-05	5	178	220	443
2024-05-12	2	146	287	131
2024-02-19	4	625	386	400
2024-01-15	3	210	366	491
2024-05-27	1	622	441	109
2024-05-29	2	535	171	355
2024-02-06	1	522	460	444
2024-07-02	3	196	242	134
2024-08-16	3	575	427	258
2024-03-06	4	776	250	487
2024-05-04	5	837	430	240
2024-07-24	3	682	155	354
2024-02-08	2	932	322	264
2024-04-12	5	359	345	492
2024-03-02	5	463	481	491
2024-07-01	4	360	167	114
2024-02-24	2	699	402	420
2024-04-15	2	183	428	105
2024-08-14	5	887	357	196
2024-03-21	4	615	452	128
2024-04-28	3	116	134	115
2024-01-20	1	216	216	374
2024-08-01	5	858	472	170
2024-03-01	5	777	483	314
2024-04-17	5	573	416	471
2024-08-25	3	283	237	318
2024-09-07	3	905	119	215
2024-07-24	2	286	271	146
2024-05-26	4	963	216	288
2024-04-14	3	502	280	236
2024-08-12	2	146	336	98
2024-08-12	4	185	192	388
2024-01-29	3	526	164	344
2024-08-27	3	997	265	257
2024-06-28	3	821	329	278
2024-05-26	2	404	247	282
2024-04-14	2	421	173	199
2024-04-04	1	701	202	242
2024-01-29	4	841	300	101
2024-02-05	1	565	327	98
2024-07-27	5	875	286	99
2024-07-01	3	786	499	191
2024-04-21	2	560	453	235
2024-08-27	2	738	466	98
2024-04-30	5	927	359	395
2024-05-22	5	371	436	226
2024-03-11	4	449	110	350
2024-07-03	2	992	281	348
2024-02-18	2	929	263	244
2024-04-14	4	291	186	247
2024-06-02	4	316	118	464
2024-01-23	1	289	432	363
2024-07-01	2	180	449	393
2024-08-16	3	864	230	423
2024-04-20	2	718	477	478
2024-08-26	4	365	463	224
2024-01-02	1	992	149	416
2024-02-07	5	789	397	315
2024-01-23	1	208	332	205
2024-08-06	4	544	397	131
2024-06-06	1	647	490	380
2024-04-13	3	118	355	330
2024-04-24	4	105	262	354
2024-07-26	5	504	339	350
2024-08-23	5	219	314	325
2024-05-08	1	113	106	373
2024-05-06	2	275	156	509
2024-08-08	2	771	138	255
2024-03-30	1	588	434	197
2024-08-23	3	571	104	191
2024-06-21	2	808	357	378
2024-08-27	5	514	287	266
2024-01-06	5	989	176	311
2024-06-12	5	773	378	498
2024-06-01	1	862	135	357
2024-08-22	5	716	392	184
2024-03-04	5	843	476	207
2024-02-26	4	598	246	319
2024-02-03	2	410	297	128
2024-03-06	2	733	425	128
2024-06-23	3	932	261	431
2024-05-20	1	731	407	494
2024-03-02	4	469	257	452
2024-03-20	4	807	102	335
2024-08-23	4	789	172	280
2024-07-06	3	806	475	442
2024-03-14	3	791	133	334
2024-06-16	4	504	470	291
2024-07-05	3	923	294	202
2024-04-20	1	409	136	421
2024-04-19	4	189	241	392
2024-09-06	5	228	420	275
2024-02-19	4	238	220	197
2024-04-08	2	114	465	430
2024-03-26	1	295	341	167
2024-07-17	3	214	111	465
2024-07-11	4	935	395	134
2024-01-06	5	116	150	143
2024-02-09	2	812	193	250
2024-06-12	3	292	289	464
2024-04-15	3	979	297	417
2024-09-13	4	127	403	458
2024-07-29	2	314	432	137
2024-02-06	2	592	288	199
2024-01-16	3	248	260	475
2024-08-06	4	765	419	163
2024-05-11	3	347	318	335
2024-06-30	4	546	209	245
2024-06-09	1	962	445	465
2024-03-08	3	741	140	307
2024-02-20	5	978	352	290
2024-05-22	3	908	311	244
2024-07-21	3	651	159	399
2024-06-10	4	295	303	382
2024-06-02	2	188	352	373
2024-01-03	3	408	258	385
2024-05-12	5	888	145	257
2024-03-27	4	574	483	404
2024-05-16	3	251	235	437
2024-05-31	4	585	365	253
2024-07-25	2	532	219	304
2024-04-26	3	122	150	167
2024-06-19	5	219	271	352
2024-09-10	1	270	335	323
2024-04-18	3	256	358	280
2024-07-23	5	856	143	122
2024-01-10	4	819	466	224
2024-02-25	4	555	283	209
2024-08-21	1	596	475	233
2024-05-10	4	582	170	166
2024-01-28	3	120	313	353
2024-09-10	1	980	130	464
2024-05-01	3	560	302	311
2024-03-20	1	699	259	463
2024-04-08	4	348	229	303
2024-03-25	3	306	411	122
2024-01-14	4	401	117	402
2024-09-14	5	683	123	169
2024-08-06	5	949	214	449
2024-05-02	2	953	381	475
2024-04-02	2	501	413	486
2024-05-13	4	152	157	470
2024-03-11	3	441	121	147
2024-02-04	2	108	330	95
2024-07-29	2	205	419	492
2024-02-04	1	745	246	179
2024-01-19	4	967	233	502
2024-06-14	3	830	292	407
2024-01-29	1	542	328	463
2024-05-20	3	525	415	388
2024-04-09	2	968	286	478
2024-04-29	5	607	455	250
2024-09-02	5	854	413	341
2024-02-23	1	692	323	159
2024-08-02	2	710	141	165
2024-02-28	2	848	255	403
2024-02-17	2	667	351	188
2024-04-25	3	397	423	257
2024-09-01	5	137	339	259
2024-07-02	3	599	376	193
2024-04-30	3	509	145	193
2024-06-27	3	597	437	451
2024-05-21	4	625	252	302
2024-01-12	1	705	321	435
2024-08-03	3	842	495	97
2024-01-25	2	726	475	423
2024-02-06	4	794	395	426
2024-05-03	2	936	434	261
2024-01-27	2	988	100	202
2024-08-07	4	599	179	293
2024-03-17	4	337	227	410
2024-03-06	4	831	226	497
2024-05-03	5	162	104	399
2024-08-23	3	640	276	451
2024-07-04	5	119	185	352
2024-01-01	3	532	140	268
2024-06-24	2	690	347	345
2024-06-29	4	423	388	508
2024-03-31	3	666	496	112
2024-01-29	2	165	286	234
2024-06-17	5	374	424	214
2024-07-07	2	763	379	92
2024-08-20	1	527	206	422
2024-04-04	4	584	468	159
2024-05-03	5	219	178	417
2024-02-23	1	606	171	475
2024-01-03	5	737	105	197
2024-08-18	2	761	338	490
2024-07-29	4	455	427	376
2024-05-01	2	559	347	273
2024-05-17	2	814	330	242
2024-05-13	1	546	474	253
2024-05-06	1	121	246	123
2024-01-27	2	265	489	246
2024-07-12	5	394	363	356
2024-08-11	5	843	438	123
2024-03-24	1	296	164	371
2024-06-30	2	580	136	509
2024-08-16	3	452	447	492
2024-05-16	2	548	168	145
2024-02-11	3	337	291	237
2024-04-06	2	619	352	322
2024-04-06	1	324	479	463
2024-03-05	2	701	117	381
2024-01-06	2	801	180	158
2024-01-14	1	447	297	434
2024-06-09	3	716	281	157
2024-05-23	5	973	386	151
2024-03-19	5	962	111	306
2024-01-20	3	832	436	494
2024-07-27	1	772	451	90
2024-01-10	4	579	153	411
2024-07-22	2	234	332	489
2024-02-06	1	400	258	106
2024-05-30	3	840	438	379
2024-06-12	5	828	383	113
2024-06-23	4	499	309	455
2024-02-26	4	526	206	451
2024-05-18	1	953	365	116
2024-08-26	3	789	325	118
2024-07-16	2	768	368	466
2024-08-24	1	852	273	198
2024-09-06	5	468	196	328
2024-02-16	1	915	407	345
2024-01-10	4	583	376	216
2024-02-06	1	918	421	451
2024-03-03	2	964	123	101
2024-07-05	3	265	302	371
2024-06-30	4	736	337	317
2024-03-10	4	312	393	124
2024-02-04	4	389	168	130
2024-03-09	1	807	229	229
2024-07-14	5	867	485	124
2024-09-05	5	188	376	183
2024-01-24	4	783	159	274
2024-05-04	1	594	411	424
2024-08-12	2	232	314	211
2024-08-24	3	277	310	505
2024-03-19	3	304	372	474
2024-08-04	4	260	256	364
2024-05-31	4	720	467	197
2024-01-19	4	603	178	387
2024-08-26	4	203	406	434
2024-03-20	1	912	174	342
2024-08-10	3	525	222	233
2024-01-04	1	605	388	308
2024-02-01	2	410	492	463
2024-06-09	4	340	139	385
2024-02-29	5	314	188	277
2024-02-05	1	670	187	395
2024-08-29	3	148	196	311
2024-08-01	2	118	268	154
2024-03-06	1	467	307	216
2024-04-11	4	367	209	343
2024-07-05	1	465	129	255
2024-06-09	2	793	418	274
2024-08-14	3	262	341	361
2024-08-19	5	278	283	509
2024-02-09	1	947	440	160
2024-07-21	3	980	284	174
2024-01-22	3	615	405	109
2024-06-13	1	132	348	231
2024-07-20	2	926	403	186
2024-03-07	3	165	115	246
2024-07-31	4	445	301	212
2024-05-04	2	540	207	282
2024-02-14	1	216	360	225
2024-07-20	4	732	481	371
2024-07-07	2	332	121	204
2024-01-01	4	223	473	99
2024-09-14	4	675	306	426
2024-03-09	1	329	483	167
2024-06-21	2	598	138	240
2024-07-29	2	364	328	214
2024-04-10	2	448	217	401
2024-08-18	3	903	204	110
2024-07-08	4	463	393	384
2024-01-26	2	887	147	430
2024-06-28	4	147	159	201
2024-02-24	2	888	392	98
2024-06-28	3	998	363	278
2024-08-22	4	670	441	478
2024-04-06	1	373	478	421
2024-03-11	1	254	200	163
2024-02-03	2	973	215	447
2024-08-27	4	806	190	315
2024-02-27	3	627	471	225
2024-05-02	4	718	429	318
2024-01-06	2	785	366	404
2024-07-23	2	206	465	499
2024-01-25	2	823	432	139
2024-03-24	3	151	174	346
2024-06-04	3	548	214	383
2024-07-21	4	918	322	104
2024-05-15	4	568	485	179
2024-09-06	4	961	382	156
2024-07-24	5	873	367	239
2024-08-26	5	213	205	462
2024-06-07	3	208	135	488
2024-08-08	5	900	175	376
2024-08-04	3	725	360	239
2024-07-15	1	724	358	384
2024-08-13	4	900	191	206
2024-02-11	5	978	441	339
2024-06-05	1	204	472	105
2024-01-01	5	943	446	324
2024-02-28	4	675	398	505
2024-07-28	1	142	369	442
2024-06-30	4	619	225	498
2024-04-25	2	207	450	344
2024-04-22	1	271	172	231
2024-08-13	1	745	106	227
2024-02-26	4	220	237	160
2024-07-22	1	991	233	431
2024-04-22	1	310	116	105
2024-08-22	4	470	364	369
2024-08-30	1	260	205	230
2024-01-21	2	845	253	228
2024-06-22	3	399	256	238
2024-03-07	3	825	349	227
2024-05-05	1	552	247	106
2024-06-19	3	880	231	427
2024-01-22	5	618	372	191
2024-04-15	2	610	323	323
2024-01-21	1	850	375	133
2024-08-04	3	991	412	118
2024-05-09	5	201	433	447
2024-08-31	1	257	316	475
2024-09-01	4	762	383	203
2024-04-08	3	442	409	344
2024-09-01	4	938	187	381
2024-05-09	5	241	393	423
2024-01-22	2	225	500	263
2024-07-16	3	968	173	411
2024-06-03	3	306	299	322
2024-04-11	5	549	457	132
2024-02-08	1	525	351	427
2024-04-09	1	887	161	483
2024-06-22	2	887	463	174
2024-06-03	2	106	198	366
2024-02-20	5	351	480	168
2024-07-13	1	954	233	124
2024-04-09	2	928	359	331
2024-09-12	1	585	383	195
2024-02-23	5	449	152	478
2024-02-06	5	393	472	275
2024-06-06	4	617	258	186
2024-08-29	1	275	499	224
2024-01-30	2	187	367	472
2024-05-17	3	372	463	277
2024-01-28	4	481	496	360
2024-03-20	4	832	251	130
2024-04-14	1	872	240	124
2024-01-17	5	524	189	508
2024-01-09	2	469	209	287
2024-09-07	2	744	235	302
2024-07-01	4	780	451	474
2024-08-03	4	351	185	260
2024-08-06	1	255	175	505
2024-06-06	2	871	480	322
2024-02-22	1	871	210	406
2024-05-10	1	642	372	178
2024-05-04	5	531	402	338
2024-07-03	5	906	203	115
2024-04-01	2	333	312	362
2024-04-17	2	241	347	150
2024-06-10	5	921	131	105
2024-01-16	5	539	101	284
2024-08-25	4	523	199	245
2024-02-09	2	519	312	208
2024-03-02	5	569	392	380
2024-06-10	1	972	110	251
2024-09-06	3	628	229	404
2024-08-25	2	913	467	261
2024-06-04	5	798	186	143
2024-05-13	5	470	294	157
2024-05-11	2	130	128	456
2024-01-12	2	553	268	207
2024-02-26	1	249	119	300
2024-02-29	5	888	287	311
2024-04-17	3	110	340	504
2024-04-01	2	834	184	445
2024-05-15	2	925	268	174
2024-07-23	5	629	143	207
2024-06-07	2	171	308	338
2024-02-14	2	186	356	228
2024-06-22	4	446	240	118
2024-08-09	2	422	232	218
2024-08-26	5	511	494	107
2024-07-01	3	890	332	468
2024-04-23	5	268	436	295
2024-04-08	1	544	227	382
2024-05-13	1	162	138	421
2024-07-18	2	502	228	246
2024-06-02	5	877	315	255
2024-07-19	2	137	385	333
2024-08-06	4	776	185	264
2024-06-13	5	756	494	415
2024-03-29	2	254	278	322
2024-04-16	2	688	355	127
2024-02-18	5	159	499	272
2024-06-01	1	746	449	421
2024-06-05	1	830	127	362
2024-02-13	4	918	319	423
2024-08-29	4	776	264	326
2024-09-08	2	996	314	486
2024-04-11	5	632	224	328
2024-09-04	5	402	189	99
2024-05-13	2	529	115	497
2024-02-10	1	511	112	500
2024-04-28	3	797	210	480
2024-03-10	1	817	332	416
2024-06-15	5	666	250	441
2024-08-10	2	994	281	109
2024-05-18	5	411	173	282
2024-09-09	4	838	499	388
2024-03-11	4	860	131	194
2024-05-09	3	421	451	266
2024-05-21	4	452	419	141
2024-05-31	1	108	424	325
2024-04-05	5	946	151	221
2024-02-02	5	386	492	467
2024-07-13	5	640	242	141
2024-04-01	5	725	351	181
2024-06-18	1	250	402	297
2024-02-24	5	817	497	369
2024-06-28	4	513	125	215
2024-02-05	4	556	384	124
2024-02-25	3	759	140	350
2024-04-10	2	310	276	410
2024-07-23	2	657	360	185
2024-07-03	3	739	489	506
2024-06-27	3	907	423	162
2024-02-19	1	733	408	212
2024-02-16	2	767	495	437
2024-06-19	3	552	210	394
2024-05-29	2	814	388	378
2024-07-04	1	453	171	263
2024-07-30	4	931	447	152
2024-05-28	5	900	116	495
2024-06-10	3	764	407	176
2024-02-24	5	514	186	454
2024-02-02	3	894	183	362
2024-04-25	3	302	481	443
2024-08-21	4	408	468	201
2024-02-09	3	186	335	485
2024-09-07	4	137	141	271
2024-06-09	1	650	325	483
2024-04-05	5	442	186	194
2024-04-14	5	499	255	132
2024-02-19	4	842	230	375
2024-08-10	5	836	178	250
2024-09-07	1	857	169	264
2024-01-15	4	229	221	345
2024-06-10	5	632	165	314
2024-07-01	2	653	438	276
2024-01-21	4	390	475	126
2024-06-01	2	318	224	479
2024-07-28	1	195	288	466
2024-09-11	2	623	423	259
2024-04-19	5	665	418	239
2024-04-09	3	419	186	318
2024-06-08	5	633	329	195
2024-01-05	5	448	393	347
2024-08-13	1	875	133	498
2024-03-06	2	750	297	425
2024-03-10	1	263	118	428
2024-05-22	5	123	126	154
2024-01-05	1	128	276	221
2024-06-18	2	915	208	480
2024-08-24	3	652	197	377
2024-07-08	1	706	129	228
2024-03-08	5	364	479	197
2024-02-16	2	347	109	273
2024-05-15	2	952	285	359
2024-05-19	2	892	275	430
2024-05-25	5	411	436	107
2024-05-08	4	843	304	344
2024-04-09	5	532	219	163
2024-03-03	5	617	444	207
2024-06-24	3	213	128	489
2024-07-25	1	849	192	487
2024-02-06	2	161	196	481
2024-07-30	2	961	370	130
2024-08-09	3	481	492	422
2024-01-07	5	365	458	342
2024-05-16	1	742	488	267
2024-03-10	2	619	263	95
2024-05-04	2	462	437	219
2024-04-22	3	226	116	111
2024-03-26	2	148	400	499
2024-01-25	4	874	398	433
2024-05-13	4	766	168	145
2024-04-12	2	227	395	434
2024-09-07	3	559	102	421
2024-01-22	2	405	136	164
2024-04-21	5	686	100	355
2024-01-25	2	854	459	115
2024-07-15	5	105	270	406
2024-02-27	2	564	398	243
2024-06-10	5	447	322	337
2024-03-21	5	341	451	389
2024-02-19	4	924	436	203
2024-08-26	4	863	490	438
2024-05-31	1	695	486	415
2024-06-04	3	679	333	221
2024-03-24	3	831	374	165
2024-09-01	2	742	386	488
2024-01-13	1	781	125	92
2024-04-16	2	646	321	269
2024-06-19	2	964	173	123
2024-07-27	4	709	260	421
2024-04-17	4	339	189	341
2024-04-06	5	458	391	321
2024-03-17	5	406	145	361
2024-01-20	5	391	359	250
2024-01-01	4	782	327	181
2024-06-18	4	903	456	286
2024-07-24	1	934	325	193
2024-06-30	5	832	207	327
2024-08-13	5	686	235	213
2024-01-11	4	788	181	121
2024-02-23	4	243	172	163
2024-08-13	1	831	125	203
2024-09-03	4	486	210	260
2024-05-15	2	632	345	264
2024-07-01	1	855	352	188
2024-08-12	5	353	493	187
2024-02-11	2	207	118	342
2024-01-05	3	435	227	158
2024-05-26	5	628	175	189
2024-06-29	3	696	393	131
2024-08-21	2	297	283	252
2024-08-18	1	942	145	345
2024-05-09	4	897	343	112
2024-01-10	3	469	105	184
2024-08-30	2	565	465	395
2024-07-22	4	200	342	349
2024-01-12	4	250	441	221
2024-05-21	2	828	310	132
2024-08-17	5	535	326	255
2024-06-20	2	948	463	485
2024-05-09	2	521	335	92
2024-01-06	5	183	279	382
2024-01-10	1	194	393	141
2024-05-01	1	163	288	471
2024-04-22	3	535	355	159
2024-01-10	5	233	337	299
2024-06-13	4	587	100	138
2024-05-29	3	319	259	151
2024-02-07	2	556	369	217
2024-03-12	5	179	441	194
2024-01-03	3	478	223	340
2024-07-18	5	793	186	209
2024-02-12	3	638	148	386
2024-07-05	2	512	286	403
2024-02-29	5	702	423	163
2024-02-21	1	672	317	90
2024-06-10	1	631	197	143
2024-03-17	3	897	171	313
2024-06-01	5	504	465	99
2024-07-11	5	992	227	143
2024-08-20	3	370	327	221
2024-02-28	5	698	224	479
2024-05-12	4	610	443	101
2024-06-08	3	751	414	242
2024-06-24	3	533	133	205
2024-05-09	5	550	189	117
2024-07-18	1	805	471	223
2024-05-25	3	601	307	220
2024-08-02	1	849	323	269
2024-01-03	3	526	176	440
2024-07-24	2	943	298	318
2024-02-17	1	266	425	282
2024-08-03	3	247	404	432
2024-02-18	4	617	120	158
2024-09-11	4	230	347	194
2024-08-08	4	596	186	460
2024-03-20	5	828	292	446
2024-04-25	2	568	498	156
2024-03-10	4	232	197	194
2024-05-14	1	821	159	171
2024-03-28	3	625	130	288
2024-06-26	4	983	426	449
2024-06-06	4	641	316	469
2024-04-28	1	220	356	105
2024-07-20	4	811	163	399
2024-08-15	5	317	436	122
2024-04-20	5	566	265	316
2024-01-01	1	584	481	212
2024-01-25	2	133	259	148
2024-06-03	5	864	228	493
2024-06-13	4	260	441	119
2024-04-22	4	672	246	475
2024-07-12	3	478	436	359
2024-08-08	3	221	496	114
2024-04-04	5	716	243	391
2024-05-03	3	972	476	235
2024-02-09	1	518	236	279
2024-01-25	2	212	439	121
2024-01-02	3	223	279	156
2024-06-21	3	478	437	281
2024-08-30	5	685	173	226
2024-04-26	5	396	434	377
2024-08-15	4	141	420	174
2024-03-10	2	635	496	495
2024-06-11	4	256	480	378
2024-07-01	2	220	434	423
2024-08-27	4	480	481	499
2024-07-26	1	412	198	330
2024-03-13	4	483	325	421
2024-01-13	2	410	421	239
2024-01-01	2	401	319	313
2024-02-22	1	597	256	412
2024-03-22	2	128	300	135
2024-03-21	1	910	384	281
2024-06-30	5	246	216	253
2024-06-11	5	245	154	418
2024-08-12	1	902	386	446
2024-02-11	2	703	402	208
2024-04-08	2	531	353	316
2024-08-16	5	149	160	249
2024-06-27	3	412	172	151
2024-03-30	5	390	278	120
2024-07-01	5	320	155	208
2024-03-10	2	287	301	94
2024-05-30	5	938	291	151
2024-02-13	2	857	317	461
2024-07-04	3	600	278	421
2024-05-24	5	102	217	428
2024-03-19	4	225	254	451
2024-01-10	2	660	483	139
2024-06-09	4	457	228	428
2024-09-05	1	169	234	201
2024-05-22	5	991	122	252
2024-09-13	5	145	398	468
2024-04-24	1	527	177	389
2024-06-30	1	592	206	399
2024-02-07	5	686	105	467
2024-07-24	3	417	160	492
2024-07-06	5	679	496	166
2024-07-02	2	563	216	493
2024-06-14	3	445	184	162
2024-03-15	5	900	460	329
2024-08-04	4	486	441	414
2024-04-08	3	586	465	123
2024-03-04	5	954	350	280
2024-09-07	5	837	106	400
2024-07-26	4	953	356	266
2024-01-04	3	720	473	339
2024-01-20	4	235	397	451
2024-05-24	5	880	469	290
2024-04-22	5	241	424	401
2024-04-17	4	616	210	303
2024-08-16	5	751	118	497
2024-06-18	4	571	471	193
2024-07-04	3	879	123	480
2024-01-09	1	560	328	468
2024-07-10	3	783	141	259
2024-07-23	4	559	247	235
2024-04-13	1	252	175	427
2024-04-13	4	987	251	433
2024-03-23	1	845	256	93
2024-08-08	1	433	497	205
2024-01-23	4	191	437	296
2024-06-13	2	919	333	185
2024-07-18	5	739	300	241
2024-08-07	2	780	150	109
2024-06-08	3	738	334	364
2024-01-30	5	519	338	401
2024-08-24	4	496	111	306
2024-06-22	1	338	468	452
2024-05-06	5	504	231	485
2024-03-07	3	447	263	171
2024-02-01	3	653	372	207
2024-07-11	1	146	314	101
2024-04-13	5	786	289	185
2024-03-20	2	553	418	495
2024-07-20	1	853	425	324
2024-02-18	1	384	479	488
2024-04-12	5	761	190	134
2024-03-10	1	190	231	450
2024-02-14	5	986	423	230
2024-04-20	5	269	229	214
2024-04-13	5	824	297	144
2024-04-09	3	125	127	106
2024-03-05	3	685	173	109
2024-07-23	4	745	306	350
2024-01-06	4	915	114	159
2024-06-19	4	890	401	495
2024-02-02	4	824	490	167
2024-08-18	4	416	205	231
2024-04-19	4	674	103	270
2024-08-03	5	760	238	103
2024-04-13	1	226	369	178
2024-08-23	3	759	185	456
2024-03-24	2	672	144	263
2024-04-07	3	187	198	500
2024-05-09	1	297	204	400
2024-03-27	4	733	228	137
2024-01-31	5	654	342	183
2024-07-04	5	690	102	386
2024-02-15	4	875	378	355
2024-08-08	5	154	244	333
2024-01-17	1	683	344	454
2024-07-30	2	634	242	200
2024-01-07	5	293	386	361
2024-01-15	4	868	489	229
2024-09-10	4	587	224	240
2024-02-17	3	614	255	264
2024-05-18	3	119	390	130
2024-03-14	5	223	158	229
2024-08-21	4	774	360	397
2024-02-17	4	644	384	476
2024-09-13	5	284	341	216
2024-06-20	2	119	230	143
2024-01-10	2	381	471	367
2024-01-15	2	905	329	349
2024-08-24	1	310	241	262
2024-03-08	5	351	499	308
2024-03-06	3	949	337	134
2024-01-05	3	822	236	287
2024-03-01	2	959	394	459
2024-02-22	3	693	188	483
2024-08-26	4	554	322	397
2024-05-16	1	186	457	429
2024-06-21	2	926	330	335
2024-04-06	4	646	156	479
2024-08-12	4	721	428	140
2024-01-30	2	428	224	438
2024-08-04	3	511	191	494
2024-08-26	2	703	419	410
2024-08-29	2	146	124	180
2024-01-06	5	603	369	247
2024-05-28	1	982	395	223
2024-04-25	3	123	470	236
2024-05-16	1	448	379	209
2024-06-24	2	547	471	204
2024-01-05	1	284	233	376
2024-01-10	3	524	160	158
2024-06-22	1	124	284	353
2024-02-01	1	980	344	259
2024-04-18	1	640	138	234
2024-05-01	4	424	471	276
2024-04-17	2	491	363	370
2024-03-02	3	363	213	178
2024-03-16	1	193	257	427
2024-03-13	4	217	186	295
2024-04-17	2	201	256	184
2024-08-15	4	654	145	327
2024-01-21	2	272	135	128
2024-04-13	1	392	123	262
2024-04-16	1	247	497	369
2024-05-27	2	287	291	376
2024-05-13	2	361	381	169
2024-07-25	3	886	371	498
2024-01-06	4	191	377	439
2024-07-05	5	257	374	399
2024-08-26	2	414	190	441
2024-01-24	3	517	360	298
2024-02-09	5	794	382	148
2024-04-13	1	273	342	478
2024-02-04	2	160	172	507
2024-02-20	1	729	232	136
2024-09-02	4	285	109	267
2024-01-06	4	127	308	102
2024-02-27	2	830	441	185
2024-09-02	1	159	277	146
2024-02-10	1	405	300	328
2024-05-26	3	499	438	342
2024-08-26	4	201	308	120
2024-03-31	3	427	349	448
2024-02-24	1	245	308	495
2024-04-28	3	522	381	480
2024-09-07	3	431	249	205
2024-06-09	2	364	450	117
2024-08-20	4	484	113	268
2024-02-18	2	947	391	226
2024-09-05	1	223	212	218
2024-02-15	1	153	377	489
2024-02-09	2	307	107	269
2024-05-12	3	345	137	424
2024-08-26	4	870	447	378
2024-05-31	3	711	474	236
2024-08-22	2	700	192	98
2024-08-18	2	342	321	294
2024-06-10	1	604	308	237
2024-02-10	5	620	107	281
2024-01-01	1	870	483	153
2024-03-08	1	616	156	161
2024-01-13	4	494	475	256
2024-05-23	4	217	358	373
2024-05-23	4	375	208	143
2024-06-11	2	162	234	410
2024-04-08	2	425	255	243
2024-08-28	4	575	130	234
2024-03-02	2	666	414	263
2024-07-16	3	516	203	222
2024-08-21	2	167	182	165
2024-02-16	2	595	281	181
2024-06-12	3	129	135	115
2024-06-13	5	517	245	216
2024-05-20	4	748	286	235
2024-09-01	2	339	433	100
2024-03-16	5	119	463	495
2024-03-30	5	375	114	461
2024-07-10	4	667	168	245
2024-08-02	4	700	129	90
2024-06-19	2	791	407	153
2024-02-29	2	203	115	123
2024-08-24	3	352	444	411
2024-07-23	5	881	287	201
2024-06-04	5	668	244	479
2024-02-16	3	767	192	248
2024-06-10	2	904	229	398
2024-05-20	5	228	221	402
2024-03-25	3	411	158	339
2024-08-13	4	681	107	291
2024-08-07	2	516	334	170
2024-07-29	3	556	130	160
2024-06-02	3	185	153	221
2024-01-04	2	966	234	268
2024-02-07	4	751	472	455
2024-01-14	2	612	156	285
2024-02-18	4	308	167	372
2024-08-19	2	901	433	473
2024-06-15	1	245	329	341
2024-02-11	1	482	359	352
2024-05-29	4	653	113	462
2024-02-24	2	272	482	445
2024-06-03	2	900	393	140
2024-08-06	2	351	344	426
2024-05-05	3	650	182	442
2024-02-20	4	533	362	102
2024-07-01	5	668	151	253
2024-06-20	3	562	117	235
2024-03-22	3	142	411	102
2024-02-19	3	101	127	234
2024-08-10	3	932	497	314
2024-02-10	3	575	299	346
2024-08-12	5	949	192	387
2024-01-13	3	735	101	247
2024-04-24	2	396	226	411
2024-05-23	3	768	180	188
2024-06-20	3	271	344	389
2024-01-04	2	100	208	181
2024-09-09	5	161	125	346
2024-03-20	5	593	323	186
2024-07-02	5	379	222	401
2024-04-17	4	712	229	157
2024-01-27	3	356	496	347
2024-06-13	3	959	241	258
2024-07-11	1	796	224	425
2024-09-12	3	489	318	204
2024-01-22	3	459	491	358
2024-03-27	1	962	176	332
2024-02-06	3	747	390	506
2024-08-18	4	317	399	93
2024-04-08	3	699	121	201
2024-04-25	2	960	197	343
2024-02-13	5	622	479	251
2024-06-28	1	388	399	96
2024-03-21	1	146	251	431
2024-07-12	3	265	377	322
2024-05-26	2	856	159	336
2024-01-15	3	646	149	418
2024-08-13	4	676	437	174
2024-05-08	2	171	143	340
2024-01-30	1	407	180	389
2024-05-20	5	191	394	386
2024-02-09	3	504	346	96
2024-04-28	5	815	316	377
2024-05-25	2	225	229	346
2024-06-06	1	950	103	428
2024-05-27	5	243	338	139
2024-02-19	5	842	166	97
2024-05-28	4	669	122	382
2024-04-22	3	386	433	144
2024-04-20	4	999	273	149
2024-03-24	1	542	155	500
2024-09-16	2	315	269	314
2024-02-11	3	725	373	297
2024-04-14	4	616	288	155
2024-01-13	3	921	217	441
2024-03-19	2	425	209	287
2024-02-08	1	798	132	418
2024-03-14	1	450	446	213
2024-04-14	1	750	262	459
2024-05-24	4	367	246	333
2024-02-05	2	870	144	350
2024-07-14	3	824	390	407
2024-05-30	4	563	229	183
2024-02-14	2	379	247	417
2024-01-24	3	351	309	94
2024-08-09	2	778	381	110
2024-05-04	1	429	485	138
2024-05-07	1	449	378	435
2024-07-10	1	315	142	97
2024-08-20	4	570	200	399
2024-01-10	3	713	118	137
2024-02-17	1	436	152	386
2024-03-24	5	116	104	247
2024-03-30	3	808	123	99
2024-06-28	2	236	368	387
2024-06-07	5	761	214	487
2024-05-17	5	102	127	187
2024-04-11	4	723	370	482
2024-02-08	3	587	314	465
2024-05-02	5	104	377	460
2024-03-28	3	109	406	301
2024-06-04	3	788	441	486
2024-08-26	5	277	389	346
2024-03-22	1	523	128	257
2024-04-07	2	669	220	146
2024-06-08	4	820	204	233
2024-04-05	1	600	426	399
2024-02-21	2	880	335	364
2024-04-20	2	502	114	173
2024-03-21	5	651	211	343
2024-01-28	3	183	486	192
2024-09-03	4	906	450	229
2024-07-09	1	997	494	394
2024-03-30	2	764	310	157
2024-06-01	3	766	500	412
2024-05-15	3	179	146	383
2024-02-06	2	651	320	436
2024-05-19	5	131	178	248
2024-07-07	5	952	172	223
2024-02-08	1	935	217	302
2024-02-14	5	787	273	499
2024-06-18	2	555	395	427
2024-05-23	3	788	225	225
2024-09-15	4	226	321	441
2024-08-14	3	461	301	195
2024-04-17	2	932	179	462
2024-02-01	4	485	393	393
2024-08-07	1	947	206	394
2024-02-06	4	715	392	229
2024-01-26	2	466	413	234
2024-02-18	3	496	443	405
2024-06-09	2	281	420	457
2024-07-19	5	959	381	457
2024-04-27	5	886	352	398
2024-08-30	3	931	236	429
2024-02-14	4	813	104	332
2024-05-18	5	108	425	358
2024-07-18	4	227	372	107
2024-07-12	4	573	110	506
2024-02-03	1	479	165	236
2024-02-15	4	297	463	369
2024-02-02	5	555	487	125
2024-09-14	5	109	500	95
2024-05-22	4	326	123	398
2024-05-06	1	860	360	115
2024-08-25	4	120	268	267
2024-02-29	2	876	433	307
2024-03-09	4	387	190	266
2024-06-01	3	796	290	242
2024-07-21	1	826	251	283
2024-03-05	5	466	261	208
2024-05-25	2	296	316	302
2024-07-26	5	192	370	221
2024-03-23	1	935	250	133
2024-01-15	4	728	335	398
2024-07-18	1	740	404	406
2024-09-11	5	410	407	470
2024-02-02	4	927	148	299
2024-05-17	3	835	480	299
2024-02-27	5	326	346	415
2024-06-01	4	339	183	241
2024-05-18	5	605	337	280
2024-03-16	3	471	464	276
2024-05-05	4	137	364	419
2024-07-22	5	387	461	231
2024-02-11	3	604	113	458
2024-04-03	1	820	191	204
2024-08-02	5	823	498	304
2024-03-24	5	720	448	415
2024-03-03	5	314	332	489
2024-03-13	2	107	184	338
2024-02-09	3	300	229	146
2024-01-03	5	940	138	115
2024-04-13	2	753	499	344
2024-02-07	2	505	398	335
2024-04-06	5	213	368	94
2024-07-10	4	990	455	153
2024-03-08	5	384	333	334
2024-08-02	5	682	288	319
2024-03-31	3	612	293	120
2024-01-31	5	605	173	130
2024-08-15	2	274	497	351
2024-03-17	4	665	178	140
2024-06-15	2	298	273	462
2024-08-06	1	856	342	205
2024-03-17	1	679	224	226
2024-02-27	4	788	256	441
2024-07-25	1	798	170	244
2024-05-28	2	717	141	434
2024-06-08	2	678	238	303
2024-08-16	5	279	179	285
2024-02-11	2	166	297	260
2024-07-24	5	702	344	377
2024-07-03	1	231	354	385
2024-03-21	4	863	245	124
2024-06-28	5	166	461	181
2024-08-09	3	230	369	192
2024-03-10	1	365	438	420
2024-04-09	1	683	324	369
2024-08-30	3	976	152	333
2024-03-23	2	333	489	132
2024-03-13	3	635	137	392
2024-08-05	5	846	439	322
2024-08-13	4	901	113	185
2024-07-10	1	380	260	322
2024-05-02	4	296	345	293
2024-03-21	4	968	325	494
2024-05-28	1	794	222	401
2024-06-07	1	123	109	327
2024-06-26	4	809	471	294
2024-02-02	1	794	357	331
2024-06-03	3	645	428	480
2024-02-19	2	729	287	356
2024-08-09	5	358	380	488
2024-06-10	5	797	184	233
2024-02-11	5	673	237	146
2024-05-18	3	564	214	430
2024-08-06	5	102	123	168
2024-09-02	3	537	261	498
2024-02-20	3	756	287	217
2024-03-21	2	789	448	147
2024-08-04	3	765	357	263
2024-08-27	4	153	141	282
2024-02-18	5	974	364	144
2024-02-02	4	430	300	124
2024-05-28	2	542	198	404
2024-02-05	4	964	358	442
2024-07-30	2	516	166	205
2024-05-05	2	380	291	202
2024-05-07	1	224	244	233
2024-07-30	4	796	202	363
2024-07-12	5	630	302	246
2024-08-04	3	577	280	294
2024-08-13	1	607	391	203
2024-06-07	3	470	345	483
2024-02-03	2	629	288	320
2024-04-28	1	877	157	118
2024-07-19	3	144	102	434
2024-08-24	1	838	344	110
2024-03-13	1	329	288	229
2024-08-11	3	148	298	443
2024-03-03	4	384	168	224
2024-01-05	3	530	302	450
2024-05-09	4	645	413	301
2024-04-16	4	559	186	228
2024-07-26	2	423	166	480
2024-04-01	4	105	298	500
2024-05-22	1	501	386	477
2024-01-09	1	299	259	461
2024-08-02	2	442	179	138
2024-04-15	1	183	113	503
2024-02-15	2	685	404	386
2024-02-20	5	927	173	362
2024-02-14	3	125	190	428
2024-08-26	3	855	431	446
2024-09-12	4	331	145	97
2024-08-07	4	806	217	360
2024-06-17	1	533	319	126
2024-04-30	4	176	128	275
2024-02-28	1	355	272	286
2024-02-17	1	301	343	249
2024-03-14	2	268	442	211
2024-05-18	4	437	413	393
2024-06-09	4	418	332	455
2024-03-24	4	164	413	176
2024-02-23	5	741	450	139
2024-02-29	4	740	182	143
2024-03-15	3	199	345	390
2024-03-25	5	128	125	184
2024-05-22	5	591	167	142
2024-04-19	3	542	218	195
2024-01-17	1	927	353	203
2024-01-24	2	124	423	120
2024-05-31	1	706	168	405
2024-07-15	3	916	419	146
2024-08-24	1	741	267	483
2024-04-22	5	442	200	402
2024-09-06	3	960	234	444
2024-02-01	5	356	210	116
2024-03-19	3	353	498	287
2024-05-10	2	210	456	340
2024-08-09	1	584	182	316
2024-07-12	5	344	173	221
2024-04-19	2	448	477	282
2024-06-12	3	952	112	346
2024-07-18	4	155	232	455
2024-05-20	5	941	339	116
2024-07-19	2	441	309	193
2024-04-11	1	632	212	497
2024-05-07	3	913	412	400
2024-08-20	1	342	240	90
2024-06-16	4	174	242	333
2024-08-12	1	894	290	417
2024-09-15	4	714	332	269
2024-05-20	4	734	176	299
2024-07-30	5	549	386	506
2024-08-15	1	882	181	153
2024-07-03	4	197	298	136
2024-02-25	2	740	158	202
2024-01-09	3	557	359	353
2024-04-18	3	692	310	427
2024-05-09	4	227	342	448
2024-04-25	4	187	399	411
2024-03-09	5	162	306	384
2024-04-14	4	134	352	111
2024-01-19	3	486	419	431
2024-06-28	5	420	187	491
2024-03-23	2	968	351	430
2024-07-20	5	810	166	246
2024-06-06	5	166	276	466
2024-04-27	5	901	391	120
2024-08-31	1	230	389	299
2024-08-02	3	163	359	164
2024-07-13	2	921	245	303
2024-04-29	4	552	408	339
2024-03-13	2	156	382	244
2024-08-07	2	408	294	480
2024-04-10	4	725	101	391
2024-02-13	3	741	141	130
2024-02-11	3	542	355	316
2024-04-20	5	167	342	232
2024-05-19	1	204	279	444
2024-06-15	5	793	435	275
2024-07-21	2	157	486	254
2024-07-03	3	672	463	237
2024-02-03	3	153	286	301
2024-01-15	1	401	322	353
2024-08-10	3	970	176	130
2024-06-23	5	490	183	490
2024-02-19	1	511	476	263
2024-05-15	3	198	163	396
2024-07-11	1	732	458	498
2024-08-24	2	870	328	256
2024-06-08	3	520	136	315
2024-01-20	4	338	251	293
2024-04-11	3	985	317	407
2024-06-06	2	713	354	300
2024-04-17	3	906	234	499
2024-01-07	2	775	433	501
2024-01-01	3	738	161	173
2024-08-02	2	110	376	270
2024-06-23	4	564	376	352
2024-03-03	4	493	111	282
2024-01-24	1	575	260	305
2024-07-13	3	914	115	438
2024-03-24	5	538	274	283
2024-08-25	4	735	371	189
2024-02-07	4	734	201	466
2024-01-31	3	203	376	107
2024-02-27	3	447	407	218
2024-07-22	4	766	161	463
2024-01-19	2	791	241	387
2024-09-03	4	901	307	311
2024-01-18	3	126	181	495
2024-09-05	1	564	149	440
2024-03-27	3	629	435	287
2024-06-27	2	436	360	459
2024-04-23	3	701	416	139
2024-05-11	5	297	247	362
2024-08-10	2	210	150	414
2024-09-10	2	205	345	504
2024-06-28	3	112	390	119
2024-02-09	1	709	278	206
2024-09-15	3	830	355	499
2024-05-25	4	169	289	166
2024-08-23	4	707	368	104
2024-09-03	1	908	145	507
2024-08-07	5	960	427	271
2024-09-15	5	298	152	199
2024-02-22	4	686	381	462
2024-06-27	3	229	303	114
2024-06-13	2	752	213	286
2024-01-16	2	621	319	247
2024-04-09	4	362	408	379
2024-03-07	1	463	437	106
2024-01-10	2	531	110	346
2024-07-04	1	592	334	265
2024-01-31	3	842	303	348
2024-07-13	1	735	309	448
2024-02-27	4	555	428	466
2024-03-14	3	290	390	324
2024-02-20	2	348	413	383
2024-04-24	2	240	201	222
2024-02-28	1	916	441	136
2024-02-14	4	145	322	475
2024-09-09	4	161	156	242
2024-06-04	3	230	495	350
2024-03-29	1	419	335	110
2024-08-16	1	698	474	105
2024-09-16	1	546	202	354
2024-07-15	5	625	175	200
2024-08-21	2	767	479	105
2024-03-02	5	872	425	164
2024-06-25	2	466	340	461
2024-05-08	1	418	151	416
2024-04-30	3	697	254	228
2024-04-16	3	654	282	372
2024-03-19	5	894	377	444
2024-07-17	4	249	463	363
2024-06-19	5	250	208	479
2024-02-17	5	580	391	324
2024-02-03	1	416	142	305
2024-03-08	3	717	376	241
2024-01-31	5	451	439	287
2024-04-01	3	398	336	137
2024-07-08	1	477	218	133
2024-01-18	5	108	177	207
2024-06-26	2	630	266	173
2024-07-20	3	700	136	382
2024-04-28	2	773	237	354
2024-01-22	4	794	264	372
2024-01-16	1	248	245	198
2024-04-09	3	158	313	194
2024-02-25	4	343	109	202
2024-04-25	3	619	319	308
2024-06-03	2	938	441	152
2024-05-21	1	955	124	298
2024-01-25	3	672	338	316
2024-04-30	5	979	500	472
2024-03-14	2	155	320	391
2024-05-03	1	532	235	120
2024-06-09	4	452	428	100
2024-02-07	4	300	412	332
2024-08-08	2	305	112	411
2024-05-08	3	755	213	471
2024-03-15	2	306	459	122
2024-03-15	1	904	341	130
2024-03-23	3	170	390	467
2024-05-14	4	449	136	335
2024-05-26	5	293	364	316
2024-08-21	3	783	411	452
2024-03-10	2	587	259	263
2024-05-02	4	811	255	351
2024-09-11	2	808	407	103
2024-03-23	5	578	415	171
2024-06-08	3	714	353	508
2024-09-15	5	809	119	458
2024-08-09	1	439	334	143
2024-08-05	3	972	113	364
2024-09-03	2	692	258	359
2024-01-11	5	679	493	482
2024-05-17	4	443	272	193
2024-03-03	2	730	462	229
2024-03-18	2	406	241	180
2024-07-18	3	528	386	429
2024-03-29	4	436	189	381
2024-05-27	5	266	162	107
2024-07-22	5	207	220	199
2024-04-22	1	565	267	362
2024-06-02	1	997	441	96
2024-08-05	4	908	244	298
2024-03-04	1	143	451	387
2024-07-04	4	607	397	504
2024-07-08	2	324	343	278
2024-03-17	4	103	499	497
2024-04-07	2	754	462	136
2024-08-21	1	328	281	192
2024-01-23	2	809	388	136
2024-06-17	4	335	462	401
2024-06-06	3	577	397	442
2024-05-26	1	738	197	147
2024-07-24	2	318	290	135
2024-04-02	2	344	201	341
2024-06-28	1	592	356	494
2024-07-08	5	852	257	294
2024-02-07	3	886	388	397
2024-08-20	5	934	314	204
2024-08-26	1	439	488	144
2024-02-09	5	926	142	148
\.


--
-- Data for Name: inventory; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory (store_id, product_id, inventory_level) FROM stdin;
2	135	43
3	391	411
1	710	452
4	116	412
5	630	196
2	238	24
3	409	125
5	106	103
4	407	424
3	327	377
1	319	411
5	976	346
1	422	118
3	122	31
2	890	258
1	941	417
5	806	191
1	942	149
1	382	144
3	666	44
2	623	270
4	669	332
4	684	154
2	685	127
2	258	214
2	196	334
1	138	411
1	571	442
5	464	220
4	259	27
4	241	340
5	371	92
3	475	346
5	696	8
5	355	322
5	338	309
5	362	470
5	930	101
2	407	44
1	194	113
5	684	241
3	509	466
3	682	283
1	322	276
5	851	24
3	179	374
3	840	81
2	432	350
2	911	465
4	594	34
3	277	16
4	599	297
1	945	123
2	806	476
5	819	212
3	690	248
1	939	371
1	197	499
5	709	370
5	757	477
5	407	211
4	848	481
5	927	234
4	690	400
3	490	237
4	180	232
1	898	122
5	157	436
3	889	213
1	442	175
1	456	391
5	936	488
3	544	233
4	526	193
2	988	159
1	223	182
5	990	178
4	888	152
4	332	169
1	865	316
1	768	453
4	969	29
4	716	106
2	111	128
4	749	460
4	896	492
2	747	258
5	491	56
1	155	314
4	412	169
5	636	412
5	142	440
2	426	356
2	652	128
4	678	103
2	253	183
4	434	395
3	614	378
2	814	369
2	326	56
5	256	55
3	151	461
1	789	25
4	849	71
1	502	195
1	556	319
4	870	104
2	709	293
3	689	161
3	616	190
1	192	105
4	327	120
5	542	421
3	396	25
3	905	275
4	503	316
1	251	374
2	235	384
2	444	69
4	184	98
4	587	353
5	685	127
5	863	96
5	150	334
3	661	484
3	508	449
1	368	42
5	187	105
4	508	186
4	613	347
2	544	381
2	892	35
4	814	159
5	233	498
1	880	335
4	238	266
1	592	161
3	672	172
4	302	382
1	599	402
1	504	14
1	767	237
1	685	11
4	300	73
5	674	192
5	730	128
1	853	8
3	636	221
1	352	70
4	348	409
2	173	407
3	372	216
1	895	7
4	540	197
4	431	225
1	801	144
2	191	54
2	215	163
4	787	323
3	523	63
3	533	382
4	474	422
5	456	152
2	295	156
4	428	417
2	452	259
2	708	244
4	771	223
4	124	80
3	273	479
1	458	463
4	731	215
3	941	491
3	922	146
1	552	287
4	738	125
4	249	376
4	551	130
1	145	338
3	937	69
1	339	232
3	304	356
4	801	449
5	482	427
3	259	456
3	875	296
2	845	232
3	973	127
4	187	27
3	215	89
3	857	298
5	155	144
2	348	27
3	735	223
5	251	290
3	989	167
2	952	422
4	939	244
4	394	470
2	114	86
1	451	176
5	810	85
1	923	341
3	213	17
1	412	80
1	560	117
4	582	379
3	123	408
2	439	396
1	314	490
3	650	259
5	316	317
2	308	105
4	659	232
3	635	236
3	868	393
1	364	57
5	661	82
1	737	279
5	847	92
3	244	274
2	811	135
1	815	271
2	784	392
2	118	286
1	485	308
3	696	457
4	779	43
1	639	302
2	144	342
2	361	455
1	274	423
5	161	367
2	390	301
4	305	488
1	908	491
4	813	153
3	732	425
1	377	308
5	154	183
3	576	487
5	770	42
4	108	196
2	168	347
4	497	371
2	776	170
5	377	319
3	778	298
5	972	34
3	775	383
5	468	361
4	985	358
2	210	298
2	119	141
3	399	160
5	988	428
3	764	418
5	495	201
5	336	336
2	489	150
4	620	152
3	826	221
1	201	128
2	423	392
1	596	164
4	987	73
1	711	121
4	644	422
2	190	299
2	290	3
3	303	15
4	612	132
4	568	37
3	674	495
4	829	189
4	140	155
4	353	446
5	642	79
2	412	500
2	441	448
2	601	449
4	502	437
2	862	377
1	260	269
1	118	192
4	455	253
3	800	275
5	460	187
3	463	169
1	740	130
2	409	252
5	341	455
1	613	4
3	382	403
5	931	35
5	163	257
5	740	301
5	363	240
2	999	390
4	496	249
4	934	306
5	130	351
4	668	177
1	386	391
5	330	23
1	255	63
3	449	457
5	502	350
4	772	154
3	240	192
1	189	231
3	847	480
1	491	22
4	633	383
4	794	477
1	727	315
4	993	347
2	740	385
1	802	116
2	332	216
2	527	250
5	346	73
4	686	388
3	536	487
3	419	175
2	719	462
3	437	22
4	559	380
3	655	65
3	234	464
4	311	257
1	241	14
2	694	29
3	654	408
5	800	353
3	919	158
2	307	341
4	983	39
5	241	236
2	416	247
4	805	460
5	822	364
4	636	16
1	238	424
3	888	253
4	248	123
5	678	358
4	261	435
5	425	216
1	169	21
5	670	344
2	645	127
1	836	54
2	221	211
2	288	50
4	425	113
5	959	339
2	249	152
1	844	6
2	883	249
4	523	316
4	521	65
3	410	410
3	553	350
1	863	381
1	752	197
3	856	453
5	380	137
2	255	179
2	897	246
4	292	165
4	209	431
1	234	90
4	289	249
5	126	176
3	880	147
1	726	331
5	731	91
4	373	367
1	720	257
5	680	364
5	727	471
4	336	341
3	710	447
5	337	103
4	803	64
3	126	389
5	467	287
4	181	386
5	804	204
4	898	250
1	588	351
2	237	460
1	614	257
3	966	173
4	719	471
1	580	46
3	829	491
1	765	181
2	482	348
5	288	26
2	972	216
3	496	464
1	603	452
3	585	200
4	240	266
2	267	478
4	297	260
3	331	35
3	133	177
5	518	183
3	882	380
3	115	239
1	376	56
2	522	354
2	860	186
1	787	427
5	307	212
1	875	346
5	309	213
2	167	41
5	281	440
4	549	215
1	987	212
1	731	286
4	804	456
3	432	154
2	987	22
5	568	289
4	352	122
4	537	215
1	514	478
3	894	382
1	142	122
1	722	198
3	852	128
3	944	208
3	489	327
5	837	7
1	420	174
1	503	291
3	860	189
5	649	356
2	637	211
2	756	59
5	996	442
4	821	464
4	139	112
5	633	106
3	211	300
2	562	171
4	567	212
1	946	96
1	998	95
5	143	67
5	998	133
3	351	464
2	631	190
2	650	476
5	505	38
2	852	261
1	140	76
1	671	191
1	496	202
4	628	310
4	883	206
2	745	34
2	150	303
5	294	65
1	398	41
2	550	485
2	507	74
3	411	328
4	892	363
3	947	219
3	392	462
5	572	290
2	270	230
5	532	432
4	401	378
3	629	429
3	245	389
5	574	358
2	949	449
4	761	198
2	192	248
5	839	283
5	612	155
1	284	246
3	897	292
2	699	385
5	812	423
1	659	259
3	238	321
5	523	209
3	431	378
2	561	101
2	125	43
5	283	292
1	564	217
2	704	476
5	829	114
4	306	29
1	565	177
5	356	253
1	808	26
5	764	133
5	828	362
1	915	104
5	835	292
3	850	448
3	226	425
1	193	93
3	216	92
4	823	390
2	560	177
1	749	416
3	471	288
1	824	216
4	493	128
2	844	68
1	910	120
1	623	2
2	726	481
3	263	61
3	487	68
3	663	247
1	144	207
5	886	300
3	274	469
5	443	367
1	679	392
2	992	5
4	775	56
2	983	249
1	266	104
2	989	498
3	283	385
2	887	310
1	829	46
3	152	292
5	529	422
1	415	257
3	416	441
2	847	217
3	887	124
3	556	238
4	395	349
4	741	333
1	285	8
1	220	428
5	234	268
3	307	185
3	103	341
5	883	115
2	359	415
5	112	198
1	569	2
5	609	215
1	975	403
4	610	76
1	656	88
3	926	98
3	105	6
3	722	211
1	605	96
4	343	178
4	322	213
5	702	240
5	587	328
3	564	377
1	519	180
3	181	232
1	715	191
5	714	200
3	106	317
5	350	374
1	660	148
1	384	85
2	734	392
3	743	311
3	670	266
3	945	409
5	312	33
3	289	409
4	156	450
4	768	4
1	457	429
3	137	498
3	248	363
3	974	18
1	133	111
2	783	437
3	691	381
3	958	81
1	717	240
1	405	104
5	439	9
5	189	111
1	150	385
2	211	65
2	526	157
4	282	392
4	265	268
3	788	89
4	725	227
4	776	155
4	808	442
4	816	355
3	709	195
3	686	105
1	906	383
2	675	406
3	281	166
3	566	65
5	867	349
2	692	371
2	468	117
1	136	402
4	195	174
2	886	429
3	406	211
1	430	41
2	477	59
4	488	285
4	169	353
1	876	385
5	537	77
5	963	6
4	663	494
5	166	124
3	582	499
3	237	276
1	224	1
3	811	351
1	980	431
3	381	219
1	437	438
4	639	422
3	637	360
5	314	368
4	812	298
4	314	168
2	159	341
1	211	211
3	685	494
4	847	71
4	744	338
5	641	34
2	189	287
3	595	171
3	841	102
1	805	470
3	907	495
5	823	340
2	394	447
4	723	363
4	968	52
3	424	48
1	365	335
5	638	476
4	688	83
3	738	257
5	462	390
2	232	40
2	729	238
4	676	248
2	608	407
4	632	308
4	846	15
3	747	414
2	609	480
5	604	107
3	927	326
3	284	200
5	724	217
2	338	197
3	825	201
5	397	117
4	298	200
5	221	368
3	124	480
3	740	155
3	915	245
2	855	259
3	968	37
3	312	332
3	918	126
1	730	81
3	524	212
4	146	434
5	458	297
4	673	263
1	925	143
2	752	172
2	317	5
3	111	98
4	755	102
4	806	350
1	388	251
5	360	312
1	909	25
3	415	88
3	618	339
1	663	307
5	431	142
5	885	15
1	106	426
4	216	115
5	802	251
3	441	184
2	449	111
4	841	324
5	682	352
3	730	101
3	129	341
4	952	380
1	279	55
3	298	337
2	438	102
5	953	79
1	446	363
4	788	128
1	590	378
2	585	175
2	916	64
4	136	432
1	761	352
4	239	229
5	593	487
1	259	352
2	742	168
5	571	212
1	443	50
1	573	298
1	902	323
1	933	175
1	523	24
5	955	424
3	678	127
1	842	27
2	794	189
1	423	206
5	668	256
5	648	232
5	119	284
3	313	31
2	691	233
2	801	404
2	918	64
4	914	358
3	462	439
5	167	395
5	252	203
1	387	168
2	960	77
2	131	145
2	447	434
1	484	437
2	647	149
4	962	407
1	269	277
2	720	36
5	498	256
2	291	182
1	709	81
1	219	409
1	901	306
2	869	489
5	415	258
1	822	121
1	978	259
2	826	460
1	132	86
3	378	465
4	188	464
1	608	365
4	480	61
4	562	141
4	949	300
3	321	226
5	409	211
2	214	294
3	483	45
1	903	125
5	138	204
2	896	371
3	306	43
2	194	209
4	554	438
4	618	180
3	125	225
4	918	211
3	594	429
2	612	177
4	257	70
3	294	260
3	448	461
5	595	85
4	994	68
1	636	360
2	417	484
2	894	412
4	435	384
1	246	198
4	887	55
4	992	429
2	200	290
4	941	335
1	628	167
3	792	336
1	235	137
5	310	362
1	841	475
4	137	288
4	570	341
3	830	12
1	985	455
1	634	438
2	218	489
3	104	67
4	418	288
5	968	438
3	708	134
3	992	297
4	189	398
1	441	151
2	578	97
1	147	343
1	205	436
3	633	381
2	884	416
5	774	131
3	863	379
4	123	163
4	691	234
3	876	245
2	419	426
2	754	414
3	428	442
5	305	202
2	297	39
4	393	369
1	383	451
5	645	121
1	426	470
1	891	277
3	787	432
4	379	175
4	252	320
1	380	8
5	217	397
5	115	377
2	673	451
2	626	468
1	204	17
2	311	362
2	655	458
2	458	298
3	662	435
4	426	46
4	244	188
2	821	304
2	923	177
5	390	368
2	687	204
4	350	381
2	275	227
2	172	263
3	446	484
5	653	106
5	151	356
2	233	333
1	129	498
4	791	401
1	208	186
3	492	491
4	155	479
1	188	387
2	536	302
5	501	387
3	821	196
1	706	7
3	956	59
1	464	78
4	419	326
1	440	235
5	937	15
5	302	212
5	786	287
2	928	396
4	646	167
4	873	117
1	681	361
2	195	252
4	932	273
2	921	21
2	815	479
4	579	224
5	199	69
4	417	342
3	759	14
4	827	462
3	884	439
2	576	462
3	581	114
3	337	474
2	329	324
5	247	364
5	981	109
3	731	281
2	364	481
5	472	281
1	501	51
4	287	483
3	781	80
4	438	5
5	907	388
3	981	467
5	564	316
2	599	218
3	130	202
1	586	244
5	215	219
1	459	500
3	572	226
5	966	83
4	389	8
3	886	102
2	718	227
2	688	114
3	230	151
1	620	396
3	205	128
5	515	257
1	937	114
5	831	458
2	209	185
2	433	215
2	669	247
1	172	235
4	911	327
4	409	51
4	645	296
2	572	322
2	510	356
4	704	1
5	344	207
2	349	438
2	661	166
2	262	251
1	593	412
5	493	146
4	448	441
5	313	433
1	810	301
5	705	208
4	541	250
5	903	244
5	545	17
3	680	162
2	906	133
2	450	200
1	657	419
1	341	103
4	785	38
1	857	128
4	828	371
3	687	305
1	956	2
1	598	302
3	706	380
2	710	174
4	574	138
5	433	217
2	668	457
3	199	281
1	555	272
4	280	253
3	171	123
2	712	367
2	933	386
5	710	181
5	939	495
3	606	273
5	760	63
5	162	435
4	192	82
5	322	169
1	242	48
2	873	495
5	751	301
4	929	410
1	100	90
4	250	429
3	776	451
3	252	214
2	563	65
5	398	139
3	499	253
4	730	398
2	557	458
5	300	24
3	310	351
2	797	16
1	424	167
2	406	264
4	683	26
3	913	156
2	795	7
5	411	434
2	545	46
4	835	399
4	452	150
4	191	197
5	726	161
2	622	311
2	513	403
2	967	239
4	230	393
3	163	20
3	478	13
1	662	36
4	100	296
2	820	343
3	673	28
4	940	494
3	467	455
3	212	473
2	388	230
4	986	107
4	131	265
2	340	259
2	819	163
2	425	469
3	491	363
5	490	322
3	658	372
4	316	254
1	778	144
4	277	124
5	586	432
4	242	205
1	292	385
3	493	118
4	963	419
5	960	325
5	257	16
1	395	283
5	993	309
4	786	141
4	228	53
1	237	107
2	763	271
3	116	162
2	247	484
1	838	294
2	598	193
2	773	254
5	547	34
3	239	268
3	186	112
1	240	73
3	757	55
3	525	491
5	980	6
4	566	179
5	718	477
4	535	338
1	738	277
2	565	129
2	621	335
5	534	405
1	665	363
2	939	89
5	560	183
2	493	322
2	331	53
4	290	44
3	534	494
1	107	298
3	610	21
5	967	100
1	848	386
5	342	180
2	829	307
5	613	153
3	375	440
5	520	382
5	659	7
1	134	85
5	681	295
5	821	32
5	477	422
1	215	92
2	593	289
3	807	229
2	848	420
2	979	18
2	868	373
5	897	349
3	386	116
4	576	389
3	180	71
2	635	126
4	724	285
5	190	277
5	351	363
1	583	229
1	745	347
3	859	214
5	779	239
4	784	199
2	800	220
4	748	18
4	652	323
5	917	198
2	693	425
5	419	84
4	727	430
3	451	268
4	647	295
5	111	163
2	580	458
1	624	36
1	687	103
2	851	399
1	531	425
4	461	158
1	396	108
3	271	288
1	811	418
5	711	498
4	867	240
4	411	281
4	903	273
3	677	236
5	366	146
3	162	148
1	744	342
5	584	358
4	692	334
2	273	99
1	686	10
2	152	270
5	772	51
5	928	100
3	855	208
3	739	122
1	127	82
5	393	353
4	596	387
1	184	291
1	229	340
2	617	104
2	178	324
5	971	319
4	902	446
2	358	419
4	235	229
4	387	4
5	381	92
1	363	385
3	114	195
5	214	261
4	718	85
3	278	449
3	705	2
2	254	62
3	774	178
1	557	477
2	478	158
4	279	40
5	367	282
4	901	166
4	817	60
3	341	113
5	596	114
4	640	53
2	982	39
5	133	416
4	451	240
1	186	260
4	709	28
2	941	174
2	257	224
4	957	424
5	607	229
1	870	207
5	492	252
2	343	36
5	550	69
5	843	360
4	271	447
1	315	416
5	691	340
5	962	282
1	453	310
2	155	69
4	757	390
5	370	17
1	873	447
1	218	30
3	153	471
1	271	79
5	575	271
1	508	496
4	408	163
5	864	224
2	870	138
4	339	183
2	799	319
5	499	464
4	643	428
4	991	6
4	545	107
5	395	6
3	916	193
1	559	224
4	491	250
4	423	246
1	642	56
1	644	86
3	752	136
4	462	388
1	964	305
4	542	241
3	725	339
4	767	475
5	978	89
4	443	165
2	376	174
3	373	384
1	921	450
3	200	238
4	361	32
1	770	96
5	698	472
1	500	207
2	891	295
5	791	430
3	867	212
5	347	244
4	702	357
2	888	186
1	299	48
3	445	381
1	793	158
1	806	161
2	284	117
3	420	231
5	660	182
5	110	391
3	108	181
5	951	227
4	112	153
3	521	497
1	200	413
4	637	152
4	206	347
5	324	265
5	357	438
4	134	71
1	734	214
4	194	335
3	158	431
4	708	485
1	955	293
2	322	495
3	713	24
1	753	362
1	222	266
3	188	187
2	976	485
1	719	53
3	484	473
1	882	419
1	763	57
4	922	376
5	289	221
2	213	243
3	812	457
5	359	403
5	401	118
1	578	278
5	177	176
4	754	38
4	383	235
1	887	219
2	808	376
4	783	215
5	888	18
1	431	332
1	265	30
4	899	338
1	175	211
2	895	443
2	163	433
2	497	4
5	440	496
2	161	311
5	364	278
2	932	103
1	371	258
1	551	107
2	171	34
5	603	440
3	305	298
2	282	222
1	760	165
4	603	359
2	653	388
3	541	163
2	323	260
4	728	487
2	758	219
5	208	26
2	552	127
1	832	471
3	365	320
4	135	382
3	174	381
4	172	460
5	845	192
4	609	105
1	252	398
2	755	295
3	100	77
3	138	125
5	780	153
4	499	319
2	372	497
2	816	184
2	437	70
2	500	142
1	688	393
2	103	164
5	627	231
4	824	27
4	889	173
1	602	39
4	589	162
3	546	442
5	513	450
2	964	447
1	845	172
3	899	369
4	931	240
3	904	436
5	171	271
3	653	480
4	103	326
5	898	274
4	593	278
3	224	3
2	680	421
2	467	103
2	798	85
3	510	137
2	156	346
2	762	447
5	474	74
5	647	237
3	182	56
5	961	340
1	570	268
2	878	382
4	884	343
2	396	199
5	763	395
1	307	82
3	280	366
1	667	475
5	140	352
1	295	323
2	186	213
1	747	370
5	548	412
4	852	92
1	294	487
4	243	456
5	297	323
1	125	240
1	837	12
3	707	107
3	344	350
5	600	284
4	498	176
1	164	333
3	911	142
1	758	286
3	611	227
5	646	385
5	954	445
2	137	269
4	447	49
1	157	292
4	445	444
3	906	96
2	143	62
3	515	407
3	221	312
1	316	79
2	926	91
5	769	370
5	783	292
5	635	487
5	794	46
1	991	395
1	995	406
1	649	364
1	858	89
1	693	477
2	244	261
3	600	385
4	769	356
3	119	0
2	582	443
1	733	480
3	146	391
1	348	437
5	818	200
4	276	350
5	747	296
2	151	128
3	414	444
3	912	48
4	199	466
5	567	256
5	725	184
4	274	140
3	955	174
2	705	188
4	165	142
2	937	32
3	208	276
3	609	84
2	325	271
5	164	454
1	930	133
2	955	392
1	511	455
5	223	177
4	800	205
5	689	115
4	658	14
2	240	103
3	429	463
2	956	468
4	318	258
4	882	77
5	146	220
1	707	243
3	443	167
4	164	341
5	875	4
2	525	157
1	272	228
1	813	296
5	478	416
5	666	386
4	268	279
1	549	487
3	349	194
5	695	184
4	141	226
2	236	51
3	202	218
2	910	424
2	485	365
5	896	223
2	261	334
2	116	71
3	598	47
5	182	99
4	106	75
3	107	399
4	283	378
5	191	406
5	707	268
1	390	213
3	526	88
4	810	435
5	911	208
3	587	274
3	808	160
5	229	197
2	246	491
4	377	107
4	635	152
3	561	224
5	521	197
2	344	25
1	278	350
4	284	482
3	834	275
1	611	89
4	190	10
1	742	295
5	946	87
3	901	435
2	528	224
1	104	90
5	671	266
2	296	405
3	220	333
2	197	148
2	733	202
5	470	239
1	983	477
5	879	448
5	652	340
3	619	109
2	324	201
1	575	107
1	888	39
1	741	203
1	313	124
5	383	8
3	154	436
5	298	283
5	915	198
1	280	201
1	263	495
2	786	456
3	760	393
2	472	7
4	391	120
3	314	483
5	442	455
2	731	207
5	924	159
5	876	311
4	564	25
3	144	263
5	206	422
2	858	414
5	153	145
1	650	400
3	261	341
4	129	144
1	627	41
4	340	221
4	838	413
3	555	122
3	693	436
1	433	333
1	303	113
2	865	439
4	793	348
1	335	117
2	212	48
4	433	31
4	333	365
1	342	353
5	855	50
4	522	198
3	990	210
5	325	192
3	175	220
5	546	268
5	248	140
5	321	185
2	724	428
5	565	162
1	282	156
2	239	384
3	837	273
2	443	474
1	230	437
3	132	487
5	808	193
2	682	77
3	387	458
4	972	38
5	569	428
5	878	0
2	451	261
3	325	159
2	402	269
3	718	218
2	260	40
2	908	18
1	913	195
4	753	374
4	726	396
5	274	212
4	666	22
4	975	378
5	335	337
2	521	30
1	977	93
2	634	443
1	600	199
1	982	456
4	321	3
4	705	151
4	584	214
3	573	9
5	385	326
1	114	53
4	538	134
2	853	313
5	352	171
3	435	261
5	327	319
2	252	465
5	105	368
3	527	194
5	145	456
5	141	420
1	581	68
4	851	461
2	535	493
3	643	12
3	503	213
2	590	199
3	917	251
3	813	279
5	941	278
4	200	147
1	563	163
1	607	240
2	346	447
1	185	476
2	671	113
4	871	434
2	809	75
1	849	465
1	516	38
3	323	220
1	402	447
1	116	140
1	591	78
2	785	459
2	265	396
5	697	380
3	574	427
2	241	235
3	995	39
4	820	409
2	515	34
1	992	7
1	479	351
3	741	237
5	748	315
4	981	191
2	494	124
5	807	338
2	440	337
2	133	177
3	403	327
4	536	476
5	870	383
3	376	15
5	814	430
5	655	222
4	689	227
4	913	48
5	906	276
1	182	119
3	853	336
1	156	101
1	790	62
4	472	255
4	492	130
1	576	294
4	733	389
2	474	182
5	475	130
2	279	376
5	672	33
1	168	288
5	826	409
1	892	443
3	309	282
3	442	84
3	652	385
2	216	388
2	764	296
3	589	91
1	855	80
3	870	2
3	694	420
5	992	400
2	314	259
5	871	490
3	862	343
1	879	461
3	461	182
5	373	402
1	615	334
4	796	92
2	533	24
3	383	260
5	481	348
4	563	71
4	597	56
3	613	432
3	639	225
5	949	446
2	225	200
4	581	280
3	794	497
5	562	310
5	476	85
4	919	171
2	789	494
4	809	23
2	292	388
3	568	29
4	182	377
4	500	116
1	283	364
5	178	142
2	268	470
2	382	307
1	214	32
5	813	118
2	251	454
5	254	151
4	995	122
1	633	126
1	123	493
2	400	352
3	798	86
4	654	187
3	235	23
5	455	386
5	530	86
2	554	249
4	855	128
1	121	203
4	398	416
2	293	77
2	122	498
5	921	287
1	954	258
2	632	491
2	760	144
1	692	388
2	761	485
2	905	498
5	434	496
1	781	118
1	411	305
4	908	136
3	413	79
1	275	431
3	908	374
5	332	387
2	480	377
2	965	97
3	148	115
5	391	210
1	566	327
5	270	130
5	264	49
2	828	147
1	648	284
4	286	335
5	279	125
4	959	424
1	825	65
1	782	332
5	343	415
3	219	10
4	229	386
5	551	424
2	366	139
3	824	253
2	424	171
3	251	14
3	481	428
2	559	161
5	266	285
3	408	466
5	224	108
5	125	238
5	514	249
4	886	53
5	427	26
5	104	129
2	856	147
2	619	240
3	439	293
3	762	353
3	822	118
4	402	290
1	585	54
2	872	36
5	687	241
4	782	63
2	250	248
2	678	128
1	846	437
3	552	365
4	446	5
5	849	363
4	590	131
5	242	201
1	794	270
1	664	347
4	511	141
1	732	468
4	961	485
4	325	271
4	556	202
4	465	168
3	434	477
5	156	249
2	722	386
1	756	106
4	299	245
4	697	150
5	639	399
2	327	142
2	900	306
1	885	193
2	651	226
1	969	69
2	793	201
5	787	193
3	189	373
2	299	149
5	602	435
3	425	451
3	717	407
5	719	240
3	157	53
3	782	75
3	469	3
1	507	285
4	251	54
1	833	278
5	974	0
3	495	264
1	112	107
1	391	256
5	453	327
4	459	78
5	320	273
3	845	347
1	525	320
1	553	2
2	395	156
1	267	110
5	925	297
2	846	186
4	524	59
2	242	205
3	701	70
3	712	202
1	247	396
2	312	362
2	410	168
1	167	67
3	704	353
3	874	470
5	484	220
2	106	287
3	754	484
5	573	341
3	873	218
4	304	204
1	290	240
3	952	267
2	490	35
5	396	235
3	667	161
3	602	76
3	143	133
3	942	427
2	946	331
3	954	34
3	699	127
4	605	124
1	672	249
4	329	137
4	127	80
1	102	424
1	257	450
5	583	112
4	227	5
2	769	107
5	781	489
3	394	319
5	527	390
3	603	183
2	129	69
3	222	379
4	604	434
3	168	203
4	713	21
3	695	275
5	592	177
5	679	96
1	989	307
4	364	412
4	743	286
4	802	428
4	937	121
3	482	360
2	624	442
4	850	15
2	689	47
3	117	43
3	965	130
4	365	317
1	159	250
1	249	427
4	427	368
4	572	155
5	999	233
5	809	500
5	238	168
5	465	139
4	154	250
5	469	344
2	529	445
2	751	334
2	464	230
3	149	438
4	396	237
3	642	141
5	626	487
2	743	294
3	287	213
4	196	273
1	713	34
4	656	186
3	430	421
1	993	405
5	423	199
5	965	440
3	801	172
2	919	294
1	408	245
1	804	312
1	471	197
1	198	48
1	647	399
2	460	16
3	943	339
4	247	102
1	113	395
3	630	128
4	388	10
5	448	459
2	266	205
5	204	277
5	323	462
1	258	434
4	615	373
3	326	297
2	951	49
2	914	26
3	728	443
3	806	381
4	951	10
3	638	150
2	664	345
4	819	254
5	216	160
4	527	219
2	219	142
3	938	455
2	234	109
4	117	16
3	591	242
2	456	438
4	471	82
3	936	53
5	552	459
3	711	350
4	881	338
3	276	259
2	411	338
5	862	410
5	934	34
5	231	217
5	977	487
1	245	295
5	414	198
4	233	236
5	180	92
4	807	210
1	881	126
2	902	157
5	179	35
2	893	16
2	595	135
2	301	225
4	210	284
4	133	469
2	912	365
2	625	230
3	160	467
4	359	74
5	144	197
3	110	355
1	872	81
3	716	283
2	310	496
4	701	73
5	304	430
1	289	394
3	786	300
3	459	430
1	864	388
2	384	287
4	693	319
1	264	273
3	975	260
1	899	466
5	846	332
3	727	84
1	347	132
1	617	295
3	683	489
5	169	344
2	201	298
2	881	450
1	641	13
3	322	326
3	388	51
5	872	356
2	842	286
5	616	448
3	971	188
5	824	98
4	586	238
4	703	31
2	285	233
3	488	104
2	534	63
3	319	271
3	333	188
4	517	289
4	215	206
4	879	497
4	421	252
3	577	252
1	632	63
3	607	384
2	469	427
3	395	130
4	670	280
3	839	363
5	184	433
5	605	138
4	218	383
1	494	156
1	567	2
2	714	30
4	853	382
1	803	139
4	331	227
3	517	210
2	397	23
1	293	396
2	977	441
1	171	62
3	961	26
3	921	372
5	795	159
1	476	496
2	113	20
5	790	227
5	207	248
4	505	81
2	548	299
2	187	82
4	246	375
5	504	287
5	510	257
4	811	338
5	704	459
1	859	383
2	272	405
2	166	156
3	472	78
4	303	232
5	446	473
4	513	132
3	338	364
5	958	248
4	534	294
3	842	421
2	611	379
5	830	458
2	695	191
5	379	408
2	874	436
3	920	470
2	759	305
1	509	245
1	587	99
2	514	208
1	385	449
3	250	164
5	225	481
4	356	187
1	601	260
1	336	427
3	201	359
1	950	341
3	169	495
5	127	488
2	283	341
3	256	30
4	736	358
5	738	165
3	869	356
5	632	73
2	885	181
2	604	331
1	911	365
2	577	302
4	777	220
4	616	253
4	367	235
5	451	285
3	928	165
3	118	1
5	132	325
5	540	54
1	492	148
4	560	475
2	422	114
1	973	358
5	485	10
5	553	131
5	570	31
3	136	493
2	281	80
2	670	179
1	775	193
1	981	488
2	898	406
5	410	30
3	268	150
1	541	102
2	498	349
4	212	253
4	682	238
3	791	180
2	602	75
2	775	245
2	581	79
2	587	451
4	675	229
2	974	294
1	369	52
4	606	224
1	705	220
2	486	109
5	461	166
5	884	4
2	428	447
4	162	407
5	128	389
2	231	356
5	957	234
2	457	291
4	489	262
3	538	322
3	453	51
5	459	368
3	777	236
2	350	203
5	353	69
1	340	477
1	419	85
2	706	434
5	186	452
4	167	17
5	412	377
1	217	178
5	273	126
4	120	486
1	651	36
2	138	327
4	571	118
4	773	294
2	984	34
2	681	261
4	531	215
2	373	139
3	120	453
3	580	64
1	702	171
5	424	27
5	686	239
2	927	262
4	600	80
1	202	334
1	310	104
5	444	223
4	608	317
2	614	10
2	930	200
1	783	464
5	406	407
1	472	359
1	546	179
3	608	339
2	750	416
3	177	466
1	960	33
4	970	121
2	319	15
2	371	319
5	148	445
3	404	241
5	860	405
4	964	28
5	197	416
2	379	196
5	168	224
1	680	222
1	920	207
1	643	496
1	455	2
3	914	166
2	616	142
3	923	80
2	543	497
4	420	354
1	304	441
1	524	210
4	357	289
3	881	359
3	820	381
5	983	467
3	291	37
5	611	281
3	318	340
1	776	6
4	943	187
4	374	34
1	645	499
4	729	265
2	973	16
4	844	114
3	473	397
2	573	412
3	346	438
3	883	467
3	964	286
2	520	151
5	426	182
4	980	170
4	950	426
3	165	190
2	749	68
3	308	209
1	966	56
1	373	61
4	264	376
4	362	178
3	803	340
5	715	187
4	341	254
1	515	4
1	344	186
1	253	489
1	296	80
3	128	318
1	351	484
4	947	18
3	417	287
5	597	272
5	673	252
4	532	408
4	762	136
2	306	47
4	263	64
3	379	395
5	239	97
2	922	300
4	774	428
4	143	301
4	839	222
5	901	88
2	120	477
3	156	478
2	185	287
5	421	203
3	405	77
3	987	447
1	165	204
1	506	196
5	243	340
1	852	44
4	223	409
3	634	389
1	948	300
4	694	446
3	893	386
1	357	355
1	343	38
4	698	301
5	854	171
2	499	111
3	925	34
4	866	427
4	861	88
2	341	232
5	533	410
5	209	391
4	550	444
1	518	171
1	360	271
3	983	330
1	703	10
2	646	319
2	483	252
3	816	216
4	533	101
5	799	137
2	832	192
4	476	39
2	121	480
3	135	468
2	857	394
4	778	171
2	807	415
1	907	72
3	345	433
1	416	462
1	754	449
5	987	48
4	978	54
5	108	353
3	502	55
2	408	298
5	942	226
5	874	37
1	404	285
5	315	274
3	264	22
3	549	396
2	746	430
4	424	284
1	931	307
4	885	450
5	759	495
4	516	337
4	380	229
2	182	404
3	898	154
3	854	391
5	522	469
3	440	331
1	532	419
4	997	375
5	202	61
1	944	414
2	264	69
3	815	457
1	367	205
3	167	56
3	530	386
2	716	474
1	932	127
3	660	4
5	811	436
1	128	9
1	153	263
4	756	277
4	288	303
3	554	446
2	304	260
1	421	61
1	689	137
2	184	8
5	213	98
1	355	144
5	628	364
5	950	174
3	967	379
3	520	369
5	994	485
3	236	113
4	707	265
2	524	302
5	286	19
3	486	492
4	121	35
4	671	210
4	334	155
4	368	70
1	972	325
3	272	38
3	539	450
1	366	463
3	191	492
3	476	229
5	220	397
4	114	132
3	835	73
3	545	58
1	947	350
1	221	177
1	830	268
1	308	442
4	982	203
4	900	81
3	864	418
2	606	414
2	491	136
1	311	286
3	714	401
1	389	299
4	528	164
3	249	88
5	129	199
2	732	76
4	354	125
4	478	114
2	696	40
1	800	370
5	762	431
2	569	132
2	431	351
2	803	366
1	317	461
2	830	446
2	492	61
5	825	388
5	853	200
1	362	251
3	866	155
3	929	120
2	146	474
1	105	256
3	734	385
2	504	332
3	142	20
5	615	370
1	447	477
2	579	449
2	827	454
3	543	393
4	245	65
4	366	433
2	145	241
2	230	75
4	865	469
1	997	48
2	369	469
1	629	111
5	268	291
2	854	417
1	254	398
3	669	185
4	973	250
1	917	278
4	335	352
1	287	165
5	581	258
4	822	125
4	546	452
1	606	18
1	141	265
2	674	324
1	604	142
2	226	263
5	989	279
5	284	261
5	272	301
1	867	88
5	620	7
2	779	190
3	317	313
2	104	91
2	638	189
4	178	414
2	610	234
3	436	83
3	796	275
2	224	120
2	503	42
4	482	412
2	957	174
5	183	62
2	571	272
1	743	385
5	708	494
3	773	173
2	105	325
5	437	240
3	771	287
3	563	383
3	849	486
4	916	82
3	232	492
2	149	420
2	920	435
5	430	457
1	861	45
3	194	347
5	508	498
3	361	13
5	345	66
5	889	288
1	986	151
2	512	388
2	391	292
4	717	144
4	467	126
2	781	318
3	198	37
3	601	486
5	497	376
4	714	270
3	192	429
1	477	494
2	728	239
5	195	454
2	141	217
5	625	216
5	792	491
3	763	131
2	802	240
2	744	384
1	637	364
1	397	49
3	579	40
1	547	338
2	181	446
2	961	126
1	354	379
1	635	239
4	625	328
3	210	279
1	622	228
1	522	364
3	196	243
3	575	402
5	463	96
4	360	443
2	183	382
5	887	477
1	216	68
5	858	166
5	777	108
2	286	315
4	185	65
3	997	453
2	404	252
2	421	244
1	701	230
2	738	185
4	449	173
2	929	84
4	291	54
2	180	266
5	789	47
4	544	479
4	105	269
5	219	221
2	771	364
3	571	97
5	773	423
1	862	202
5	716	364
4	598	273
3	932	426
4	469	447
4	789	90
4	504	8
1	409	383
5	228	341
3	214	460
4	935	352
5	116	320
2	812	354
3	292	452
3	979	300
2	592	126
4	765	257
3	347	405
1	962	159
3	651	28
4	295	450
2	188	196
4	585	424
2	532	125
1	270	90
5	856	174
4	555	66
3	560	498
1	699	478
5	683	41
2	953	214
2	501	364
4	152	340
2	108	330
2	205	242
4	967	486
1	542	210
2	968	227
2	667	34
3	397	266
5	137	389
3	599	291
3	597	403
2	936	470
4	337	115
4	831	445
3	640	166
3	532	367
2	690	148
2	165	167
5	374	500
1	527	299
5	737	33
5	394	117
3	452	492
1	324	316
2	701	143
5	973	249
3	832	216
1	772	70
1	400	100
1	953	194
3	789	452
2	768	425
4	583	491
1	918	288
3	265	318
4	312	252
1	807	237
5	188	43
1	594	245
4	260	78
4	720	414
4	203	406
1	912	69
1	670	63
1	467	15
1	465	380
3	262	91
5	278	258
3	980	208
3	615	341
2	540	93
4	732	43
1	329	300
2	448	129
3	903	443
4	463	298
4	147	386
3	998	21
3	627	357
2	206	411
2	823	7
3	548	261
5	873	135
5	900	180
1	724	355
5	943	139
4	619	89
2	207	247
4	220	460
4	470	448
5	618	216
1	850	360
3	991	337
5	201	65
4	938	101
5	549	58
5	449	92
4	617	111
4	481	105
4	832	388
5	524	120
4	780	483
4	351	221
2	871	191
1	871	345
5	531	348
2	333	254
5	539	128
2	519	369
3	628	66
2	913	198
5	798	409
2	130	393
2	553	171
2	834	165
2	925	24
5	629	105
5	511	362
3	890	331
1	544	224
1	162	306
2	502	47
5	877	131
5	756	467
5	159	322
1	746	458
2	996	444
5	402	15
3	797	211
1	817	43
2	994	338
4	860	18
3	421	246
1	108	135
5	386	201
5	640	454
1	250	211
5	817	309
2	657	139
2	767	432
3	302	87
4	842	256
5	836	336
4	390	25
2	318	111
1	195	78
5	665	387
5	123	190
2	915	73
2	347	272
4	843	455
5	617	250
5	365	496
2	462	47
2	148	28
4	874	338
4	766	255
2	227	90
3	559	267
2	405	352
2	564	152
5	447	415
4	924	430
4	863	197
1	695	137
3	679	485
3	831	371
1	934	312
5	832	357
1	831	104
4	486	336
4	897	440
5	535	357
2	948	152
1	163	444
3	535	390
2	556	32
5	793	428
1	631	111
3	370	201
3	751	74
2	943	347
3	247	199
2	568	236
4	232	445
1	821	379
3	625	494
4	641	414
5	317	331
5	566	28
1	584	446
4	672	256
3	972	379
3	223	391
4	256	477
2	220	352
4	483	383
2	401	343
1	597	323
2	128	126
5	246	212
5	245	186
2	703	81
2	531	247
5	149	472
3	412	321
2	287	391
5	938	410
4	225	383
2	660	278
4	457	200
5	991	235
3	586	394
4	953	45
3	720	93
5	880	300
3	879	391
3	783	476
5	739	420
2	780	481
5	519	4
1	338	336
3	447	293
1	146	111
5	761	108
1	190	65
5	986	200
5	269	260
4	745	417
4	915	134
4	890	215
4	416	80
4	674	32
1	226	222
2	672	279
3	187	432
1	297	274
5	654	38
5	690	184
4	875	255
1	683	42
5	293	69
4	868	379
2	381	191
3	949	180
2	959	211
4	721	464
3	511	172
1	448	354
2	547	188
1	124	66
1	640	279
3	363	251
4	217	13
1	392	99
2	414	280
1	273	365
2	160	90
1	729	311
4	285	114
4	201	278
3	427	437
3	522	269
4	484	53
2	947	191
2	700	306
2	342	332
1	616	482
4	494	80
4	375	269
2	162	340
4	575	435
2	666	377
3	516	255
5	517	346
2	339	164
5	375	232
4	667	350
4	700	77
2	791	459
2	203	266
3	352	125
5	881	52
3	767	5
2	904	472
4	681	281
2	516	485
3	185	371
2	966	350
4	751	25
4	308	279
2	901	25
1	482	276
4	653	245
2	351	378
3	562	482
3	101	384
3	768	56
2	100	6
4	712	55
3	356	0
3	959	287
1	796	463
4	317	421
5	622	304
3	646	129
1	407	40
3	504	108
5	815	228
5	842	373
4	999	218
2	315	99
1	798	151
1	450	198
1	750	390
2	778	418
1	429	227
1	449	226
1	436	209
3	109	75
5	277	406
2	880	456
5	651	257
3	183	58
4	906	315
3	766	176
5	131	111
5	952	248
1	935	148
2	555	281
4	226	327
4	485	147
4	715	25
2	466	165
3	931	148
4	573	324
5	555	242
5	109	66
4	326	384
1	860	213
2	876	319
1	826	465
5	466	328
5	192	218
4	927	181
5	326	300
5	387	496
3	604	209
1	820	193
5	720	292
2	107	384
3	300	379
5	940	479
2	753	162
2	505	297
4	990	310
5	384	285
3	612	224
2	274	152
4	665	248
2	298	500
1	856	118
2	717	104
1	231	269
3	976	259
4	296	462
3	645	125
5	358	409
5	797	323
3	537	491
3	756	134
3	765	490
4	153	405
4	430	307
2	542	477
2	380	470
3	470	92
2	629	173
1	877	245
4	384	142
2	442	259
1	183	140
1	533	417
4	176	37
1	301	438
4	437	317
5	741	280
4	740	387
5	591	265
3	542	240
1	927	170
2	124	191
3	960	275
3	353	498
4	174	30
1	894	165
4	734	6
4	197	179
3	557	58
3	692	224
5	420	145
4	552	141
2	157	378
1	401	52
3	970	68
4	338	466
3	985	28
2	713	396
2	110	121
5	538	99
4	735	448
3	203	188
2	436	299
3	112	202
3	229	206
1	463	250
1	735	322
3	290	324
1	916	333
4	145	440
4	161	282
1	698	359
1	418	480
3	697	217
5	894	24
5	250	477
5	580	240
3	398	328
2	630	371
3	700	126
1	248	432
2	938	291
5	979	291
2	305	476
3	755	171
1	904	5
3	170	404
5	578	142
1	439	23
2	730	204
3	528	483
4	436	312
1	143	379
4	607	13
1	328	475
5	852	75
5	926	229
1	843	245
5	101	323
5	102	282
\.


--
-- Data for Name: paymentmethods; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.paymentmethods (method_id, method_name) FROM stdin;
1	Credit Card
2	Cash
3	Digital Wallet
4	Debit Card
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (product_id, product_name, category_id, supplier_id, unit_price, reorder_point, reorder_quantity) FROM stdin;
843	Fridge	1	474	188.46	116	170
135	TV	1	135	1912.04	70	212
391	Fridge	1	475	1377.75	94	252
710	Smartphone	1	118	182.31	87	112
116	Laptop	1	155	499.28	99	177
630	Camera	1	169	1465.38	80	210
238	Laptop	2	250	1904.70	52	287
409	Tablet	1	248	875.16	92	178
106	Camera	1	368	1627.48	129	172
407	Laptop	2	494	666.27	88	253
327	Tablet	1	104	155.24	135	167
319	Smartphone	2	290	1076.79	60	115
976	Headphones	2	300	1165.56	144	297
422	Washing Machine	2	410	778.17	94	188
122	TV	2	427	399.52	104	274
890	Camera	2	252	639.33	113	239
941	Laptop	2	165	457.92	65	116
806	Laptop	1	153	1201.92	58	184
942	TV	1	157	649.80	108	125
382	TV	2	478	1155.98	106	254
666	Headphones	1	360	160.40	90	294
623	Smartphone	1	346	781.98	76	157
669	TV	2	257	565.22	124	257
684	Headphones	1	466	1503.41	120	165
685	Smartphone	1	400	466.90	148	139
258	Camera	1	434	1376.02	142	226
196	TV	2	110	673.75	150	243
138	Smartphone	2	113	1880.99	106	244
571	TV	1	243	1839.91	71	123
464	Laptop	1	231	1187.87	85	280
259	Smartphone	1	399	672.67	131	260
241	Headphones	1	135	947.46	90	118
371	Tablet	2	127	1166.71	120	259
475	Laptop	1	436	1483.91	61	275
696	Smartphone	1	498	1529.02	141	141
355	Fridge	1	470	1868.19	125	211
338	Tablet	1	131	1292.59	150	236
362	Camera	2	324	1086.46	120	252
930	TV	2	186	897.72	108	113
194	Washing Machine	1	198	635.67	54	259
509	Camera	1	136	1182.44	135	209
682	Camera	1	474	887.89	114	273
322	Smartphone	1	250	807.27	88	112
851	Fridge	2	391	289.96	50	263
179	Tablet	1	188	508.35	113	208
840	Tablet	1	115	1768.16	92	233
432	Smartphone	1	245	1441.29	141	118
911	Smartphone	2	391	1015.05	90	174
594	TV	2	407	1273.04	147	178
277	TV	1	206	1141.15	75	120
599	Fridge	2	108	822.18	138	209
945	Camera	2	465	1911.95	120	263
819	Fridge	1	248	963.98	96	284
690	TV	2	128	1555.39	75	199
939	Laptop	2	235	1942.61	144	124
197	TV	1	143	1987.95	100	126
709	Headphones	2	166	1403.43	93	222
757	Smartphone	1	137	1702.75	129	294
848	Laptop	1	120	567.45	68	138
927	Headphones	2	443	1718.30	105	255
490	Washing Machine	1	450	245.51	77	141
180	TV	2	205	411.94	129	100
898	Tablet	1	138	99.79	97	204
157	Washing Machine	1	114	751.77	54	220
889	Tablet	2	278	1003.29	148	112
442	Smartphone	1	289	473.18	108	242
456	Fridge	1	104	1708.10	144	107
936	Camera	2	211	330.13	139	187
544	Washing Machine	1	145	1427.61	53	289
526	Washing Machine	1	286	1412.28	94	232
988	Smartphone	1	472	464.77	60	290
223	Camera	2	367	1381.09	74	188
990	Camera	1	362	460.15	55	241
888	Washing Machine	1	333	1996.67	102	139
332	Washing Machine	2	381	839.50	127	171
865	Washing Machine	2	262	555.20	103	273
768	Headphones	1	119	412.78	107	102
969	Fridge	1	298	1143.31	73	165
716	Laptop	1	312	310.07	58	259
111	TV	1	107	518.14	149	265
749	TV	1	494	369.54	66	222
896	TV	2	320	819.83	118	224
747	Washing Machine	1	327	1617.59	63	282
491	TV	1	283	1930.09	90	275
155	Fridge	2	431	783.32	99	250
412	TV	1	159	1725.96	120	279
636	Headphones	1	236	1322.84	81	182
142	Fridge	1	159	553.66	120	279
426	Fridge	1	235	906.63	107	223
652	Smartphone	1	367	1840.97	150	145
678	Camera	2	216	1262.80	53	172
253	Headphones	2	276	1432.76	73	101
434	Tablet	2	136	486.48	111	108
614	Smartphone	2	270	1093.09	116	159
814	Tablet	2	306	709.39	92	115
326	Headphones	1	110	324.35	78	150
256	Washing Machine	2	390	316.49	107	121
151	Camera	2	279	1387.72	122	193
789	TV	2	161	92.30	121	116
849	Laptop	2	236	233.15	148	291
502	Washing Machine	2	468	1393.04	69	233
556	Camera	1	167	50.26	64	205
870	Fridge	2	334	875.40	86	123
689	Washing Machine	1	126	1534.23	123	188
616	Fridge	1	450	391.62	71	250
192	Fridge	2	179	593.86	89	242
542	Washing Machine	2	275	1924.98	78	211
396	Camera	2	498	1014.56	110	145
905	Headphones	1	217	187.67	63	297
503	Fridge	2	376	1202.43	111	138
251	Laptop	1	298	341.23	80	275
235	Smartphone	2	158	1235.81	50	179
444	Washing Machine	2	153	1609.41	104	256
184	TV	1	271	992.38	138	177
587	Headphones	1	162	1648.76	74	262
863	Camera	2	140	690.10	54	207
150	Tablet	1	463	574.02	117	167
661	Headphones	2	322	717.09	97	265
508	Tablet	1	189	1798.56	117	125
368	Headphones	2	471	162.28	77	256
187	TV	1	341	1855.66	54	169
613	Tablet	2	231	1158.37	121	188
892	Camera	2	484	185.41	137	154
233	TV	2	415	481.22	76	192
880	Camera	2	198	107.44	104	119
592	Camera	2	157	817.03	147	246
672	Headphones	2	118	604.47	116	109
302	Headphones	2	301	529.42	65	121
504	TV	1	431	409.39	106	134
767	Smartphone	1	315	1528.82	70	203
300	Laptop	1	105	1463.18	118	154
674	Headphones	1	423	343.57	100	167
730	Headphones	1	230	300.15	104	259
853	Camera	2	457	926.33	93	134
352	Fridge	2	195	447.32	102	213
348	Laptop	2	262	197.09	55	292
173	Washing Machine	2	278	1779.07	101	224
372	Smartphone	1	210	1037.15	110	278
895	Fridge	2	162	1922.18	111	294
540	TV	1	457	1912.14	97	221
431	TV	2	118	833.53	94	114
801	TV	1	354	632.54	122	236
191	TV	2	355	1854.75	107	247
215	Washing Machine	2	138	913.75	150	178
787	Washing Machine	1	195	454.30	81	273
523	Camera	1	174	754.94	144	142
533	Tablet	1	103	514.18	146	208
474	Camera	2	324	1605.26	91	229
295	Fridge	2	264	660.72	62	160
428	Fridge	2	475	1266.61	50	257
452	TV	1	116	1602.49	90	268
708	Washing Machine	2	379	313.78	145	290
771	Washing Machine	1	431	610.94	146	192
124	Laptop	1	256	1469.46	131	289
273	Smartphone	2	482	1430.72	111	150
458	Headphones	1	190	1469.45	134	277
731	Laptop	2	253	307.94	66	171
922	Camera	1	380	86.08	51	237
552	Camera	2	364	1313.61	87	146
738	TV	2	323	896.94	55	123
249	Fridge	2	468	1573.93	72	161
551	Fridge	1	117	765.31	92	233
145	Fridge	1	478	375.66	138	262
937	Headphones	2	412	934.21	145	101
339	Camera	2	319	318.55	118	130
304	Laptop	1	445	1159.89	133	130
482	Smartphone	1	165	1855.60	144	265
875	Camera	1	492	76.90	120	222
845	Fridge	1	217	128.02	58	203
973	Fridge	1	220	1427.85	53	254
857	Tablet	2	150	1965.12	90	125
735	Washing Machine	1	398	1890.48	107	126
989	Camera	2	435	1601.15	77	259
952	Washing Machine	1	413	1894.44	93	239
394	Tablet	2	221	601.31	114	192
114	Smartphone	2	500	923.24	87	194
451	Tablet	2	138	664.37	146	163
810	Smartphone	2	402	997.12	96	140
923	Laptop	1	150	1193.09	150	152
213	Washing Machine	2	495	253.75	110	220
560	Smartphone	1	237	1962.83	69	103
582	TV	1	495	1413.02	55	229
123	Tablet	1	130	1162.93	117	294
439	Fridge	1	113	994.59	52	155
314	Headphones	2	404	1169.92	69	256
650	TV	2	449	591.70	64	162
316	Headphones	1	358	1994.65	52	130
308	Tablet	2	158	1589.71	86	218
659	Washing Machine	2	184	552.49	60	181
635	Laptop	1	468	1832.09	97	142
868	Camera	1	419	1036.87	57	181
364	Laptop	1	331	117.04	109	138
737	Fridge	1	400	1637.04	88	156
847	Fridge	1	169	77.70	124	137
244	Smartphone	2	438	600.09	81	171
811	Tablet	2	458	1419.29	64	160
815	Smartphone	2	429	1340.59	101	164
784	Fridge	2	194	328.70	98	278
118	Washing Machine	1	364	863.04	51	137
485	Tablet	1	366	1751.17	116	124
779	TV	2	256	298.74	65	152
639	Smartphone	1	475	1503.34	104	245
144	TV	2	139	1951.95	148	189
361	Headphones	1	271	551.66	137	289
274	Fridge	2	463	792.96	64	223
161	Washing Machine	2	402	304.99	61	247
390	Smartphone	2	231	356.05	93	210
305	Headphones	1	418	1118.70	131	183
908	TV	2	176	1422.58	96	211
813	Washing Machine	1	282	1767.01	130	142
732	Headphones	1	235	1620.88	98	241
377	TV	1	425	195.53	105	101
154	Laptop	2	198	1740.70	61	225
576	Smartphone	2	252	253.44	79	150
770	Washing Machine	1	462	1251.04	132	157
108	Tablet	1	269	1146.65	86	195
168	Fridge	1	122	711.90	52	104
497	TV	2	176	540.38	140	103
776	Camera	2	307	57.96	85	207
778	Washing Machine	2	233	1385.86	134	166
972	Washing Machine	2	430	902.03	133	276
775	Laptop	1	188	1413.07	95	183
468	Tablet	2	345	1842.45	55	297
985	Headphones	1	224	368.53	55	183
210	Washing Machine	2	372	1823.76	55	284
119	Camera	2	463	1642.41	89	233
399	Headphones	1	321	1945.73	92	111
764	Smartphone	1	404	643.16	88	300
495	Fridge	2	301	1020.53	54	232
336	TV	2	323	386.62	132	143
489	Smartphone	1	242	1784.53	120	256
620	Fridge	1	380	1292.10	125	174
826	Washing Machine	1	132	714.97	67	110
201	Fridge	2	142	1444.51	66	221
423	Smartphone	2	119	1505.72	130	273
596	Tablet	2	271	1407.36	111	238
987	Fridge	2	135	175.22	52	140
711	Laptop	2	492	1051.11	101	232
644	TV	1	187	1027.31	123	197
190	Smartphone	2	389	325.62	129	147
290	Headphones	2	427	1932.12	137	193
303	Headphones	1	473	449.81	54	288
612	Tablet	2	169	1075.43	133	188
568	TV	1	457	1114.77	99	233
829	Fridge	1	175	693.16	127	291
140	Camera	2	196	1703.25	129	247
353	Tablet	2	109	181.42	80	148
642	Tablet	1	476	1068.21	92	287
441	Fridge	2	352	200.22	133	215
601	Washing Machine	2	341	1476.01	94	105
862	Headphones	2	416	548.06	139	209
260	TV	2	364	1302.75	133	292
455	Washing Machine	2	439	961.70	55	261
800	Laptop	2	297	1960.11	136	263
460	Tablet	2	333	1218.94	78	192
463	Washing Machine	2	334	1946.31	150	229
740	Fridge	1	359	1938.65	133	218
341	Fridge	2	105	1518.42	77	155
931	Laptop	2	361	915.45	101	234
163	Laptop	2	453	575.21	87	115
363	Tablet	2	228	804.30	67	190
999	Smartphone	1	127	1773.01	71	237
496	Camera	2	357	1106.07	88	134
934	Washing Machine	1	412	1943.58	96	273
130	Washing Machine	1	214	1719.82	91	134
668	Washing Machine	1	424	1723.26	148	207
386	Tablet	1	283	917.31	115	136
330	Tablet	1	142	442.59	145	293
255	TV	1	466	1617.77	62	151
449	Washing Machine	1	455	148.86	112	280
772	Washing Machine	1	197	1169.16	117	121
240	Headphones	1	480	324.38	143	204
189	Smartphone	1	490	213.16	78	217
633	Tablet	1	332	866.45	58	116
794	Smartphone	1	395	744.84	150	121
727	Headphones	2	191	671.38	147	194
993	Tablet	1	128	926.76	148	150
802	Smartphone	2	192	1904.61	132	262
527	Laptop	1	227	1347.74	73	291
346	Headphones	1	321	1069.34	83	106
686	Smartphone	1	297	827.26	84	298
536	Camera	1	463	1529.37	131	176
419	Smartphone	1	298	1782.51	150	296
719	TV	1	429	736.53	128	124
437	Laptop	1	183	1982.84	130	173
559	TV	1	108	385.69	140	213
655	Washing Machine	1	142	967.01	102	222
234	Laptop	2	328	585.46	101	186
311	Tablet	1	177	63.35	139	293
694	Washing Machine	1	475	1065.99	127	239
654	Laptop	2	159	1628.13	54	230
919	Laptop	1	171	1718.88	55	272
307	Fridge	2	295	617.78	143	207
983	TV	1	429	162.11	54	154
416	Camera	1	129	796.10	95	224
805	TV	2	449	547.94	77	122
822	TV	2	387	257.70	125	160
248	Laptop	1	156	1048.97	139	220
261	Tablet	2	383	59.63	147	107
425	TV	1	238	1613.27	119	276
169	Tablet	1	100	1674.72	144	185
670	Smartphone	1	444	443.10	103	163
645	Smartphone	1	222	842.74	113	229
836	Laptop	1	419	1092.10	130	147
221	Fridge	1	113	880.31	71	238
288	Tablet	2	480	1049.49	90	249
959	Camera	1	192	670.64	88	289
844	TV	2	435	131.70	137	145
883	Fridge	2	344	88.77	98	138
521	TV	2	210	1769.70	106	298
410	Tablet	2	487	631.68	56	157
553	Camera	1	310	1876.39	122	268
752	Laptop	2	370	1303.83	107	184
856	Fridge	1	313	168.49	76	215
380	Camera	1	217	138.18	59	276
897	Fridge	1	211	1476.08	51	193
292	TV	2	398	1104.09	125	149
209	Washing Machine	2	404	1484.97	114	294
289	Tablet	2	277	1967.08	100	224
126	Headphones	1	122	1564.88	102	294
726	Laptop	1	300	184.87	121	169
373	TV	2	307	1177.85	78	185
720	Fridge	2	429	1188.57	52	129
680	Headphones	1	352	894.85	79	140
337	Headphones	2	274	1742.61	98	139
803	Camera	2	110	1795.88	63	139
467	Smartphone	2	430	313.11	73	238
181	Camera	2	113	581.84	120	268
804	Smartphone	2	432	1980.56	62	152
588	Washing Machine	1	273	263.56	56	171
237	Tablet	1	124	757.03	62	297
966	Laptop	2	411	1076.92	82	165
580	Fridge	2	380	1833.03	83	168
765	Laptop	2	122	740.18	99	250
603	TV	1	284	1948.68	64	131
585	Fridge	1	124	77.61	69	153
267	Tablet	2	463	1298.43	78	114
297	Laptop	1	402	1909.01	103	214
331	Smartphone	1	489	1167.42	63	119
133	Camera	2	358	1369.82	66	243
518	Washing Machine	2	118	1782.13	106	273
882	Headphones	1	279	1189.73	101	196
115	TV	2	289	1274.48	125	111
376	Smartphone	2	320	1119.59	114	286
522	Fridge	1	251	323.69	107	210
860	Laptop	1	139	52.13	72	251
309	Smartphone	1	247	1750.23	146	253
167	Headphones	1	496	1720.40	124	167
281	Camera	2	134	1612.79	95	187
549	Laptop	2	164	1940.42	113	119
537	Laptop	2	457	1696.55	121	257
514	TV	2	192	349.45	57	136
894	TV	1	405	493.35	130	118
722	Camera	2	484	908.04	132	137
852	Smartphone	2	399	946.68	114	249
944	Washing Machine	2	412	607.12	128	232
837	Tablet	1	325	757.02	107	196
420	Washing Machine	2	304	762.33	65	103
649	Smartphone	2	358	1987.19	147	195
637	Tablet	2	156	1389.13	93	279
756	Smartphone	1	479	1457.19	149	226
996	TV	1	258	442.86	113	127
821	TV	2	412	1026.68	62	292
139	Fridge	2	207	301.82	54	162
211	Headphones	1	352	1584.08	72	266
562	Smartphone	2	367	1064.00	98	148
567	TV	1	234	823.04	60	262
946	TV	2	412	1052.89	83	103
998	Fridge	2	107	1878.24	148	192
143	Smartphone	2	221	256.74	82	196
351	Headphones	1	147	527.15	61	185
631	Headphones	2	330	1544.58	103	266
505	TV	2	242	1788.43	54	293
671	Tablet	2	147	1459.01	148	180
628	Fridge	1	492	1264.29	97	108
745	Smartphone	2	322	945.53	105	248
294	Washing Machine	1	270	620.44	86	257
398	Fridge	1	290	1056.89	94	176
550	Fridge	2	111	242.38	137	118
507	Smartphone	1	454	1965.27	134	135
411	Washing Machine	2	441	425.32	114	154
947	Fridge	2	242	835.57	131	143
392	Fridge	2	196	1694.68	68	240
572	Tablet	2	352	466.59	126	235
270	Headphones	1	273	1934.88	103	239
532	Smartphone	1	428	1833.78	144	257
401	Smartphone	2	201	218.58	126	249
629	Headphones	2	328	1606.55	82	240
245	Washing Machine	2	281	226.14	61	231
574	Headphones	1	430	1104.72	134	294
949	Fridge	2	440	341.68	136	295
761	Washing Machine	1	167	1568.93	123	232
839	Smartphone	2	264	1652.32	143	107
284	Smartphone	2	375	1120.08	55	123
699	Laptop	1	386	1870.45	126	217
812	Laptop	2	301	1859.31	114	125
561	Camera	1	317	1268.11	74	280
125	Fridge	2	353	1894.39	120	202
283	Washing Machine	1	249	102.60	74	106
564	Headphones	1	384	345.43	106	162
704	Tablet	1	319	383.96	81	299
306	Laptop	2	284	1663.67	100	230
565	Tablet	2	302	160.40	91	107
356	Smartphone	2	288	1603.32	71	266
808	Fridge	2	495	666.90	72	242
828	Camera	1	138	1608.93	135	229
915	Washing Machine	1	261	1107.20	103	173
835	Laptop	2	232	158.48	140	300
850	Fridge	1	438	1782.72	112	297
226	Fridge	1	457	597.11	86	169
193	TV	2	352	958.73	134	153
216	TV	1	245	920.92	136	224
823	Washing Machine	2	203	679.77	65	134
471	Laptop	2	354	918.08	83	150
824	Washing Machine	1	153	1207.03	50	282
493	Smartphone	2	187	200.92	71	281
910	TV	1	334	1736.54	138	226
263	Tablet	2	490	1693.84	95	243
487	Tablet	2	466	1510.45	74	300
663	Fridge	1	113	952.40	86	157
886	TV	1	376	674.79	95	283
443	Smartphone	2	101	1137.76	99	119
679	Fridge	1	159	639.87	61	275
992	Headphones	2	101	1044.36	121	229
266	Fridge	2	102	839.72	142	231
887	Smartphone	2	231	914.42	118	111
152	TV	1	493	94.57	65	251
529	Fridge	1	307	353.33	138	220
415	Headphones	2	104	82.94	96	245
395	Tablet	2	395	262.11	135	231
741	Tablet	1	337	273.31	95	283
285	Fridge	2	277	1281.61	84	166
220	Fridge	2	350	1352.41	66	145
103	Smartphone	2	373	1489.54	148	131
359	Smartphone	2	305	244.55	93	108
112	Smartphone	1	304	1860.38	50	116
569	TV	1	143	1311.73	97	234
609	Washing Machine	1	388	1103.04	101	291
975	Smartphone	2	109	1304.97	119	220
610	Tablet	1	355	1702.30	114	171
656	Washing Machine	1	302	1579.07	131	218
926	TV	1	233	241.67	57	142
105	Smartphone	1	259	1545.68	115	253
605	Laptop	1	406	101.78	132	282
343	Smartphone	1	124	1663.66	117	277
702	Headphones	2	214	833.49	139	126
519	Smartphone	2	443	1752.50	110	191
715	Tablet	2	467	477.92	100	212
714	Fridge	2	138	1569.70	74	179
350	Headphones	2	431	330.76	89	101
660	Tablet	2	172	1128.89	54	155
384	Camera	1	164	1792.26	138	114
734	Laptop	1	453	486.61	134	133
743	TV	1	186	1815.31	73	275
312	Laptop	2	167	642.39	112	118
156	Laptop	1	274	666.56	150	214
457	TV	1	499	689.41	69	104
137	Laptop	2	431	1046.51	102	178
974	Headphones	1	186	1061.20	70	280
783	Washing Machine	1	295	489.31	81	135
691	Camera	1	109	1950.11	81	226
958	Fridge	1	481	709.72	69	180
717	Camera	2	192	1396.51	102	234
405	Camera	2	367	75.88	66	239
282	Fridge	1	269	1802.66	87	256
265	Laptop	2	399	475.14	105	142
788	Camera	1	172	679.66	128	106
725	Tablet	1	462	133.28	114	155
816	Fridge	1	262	1368.43	124	129
906	Tablet	2	359	232.55	147	133
675	Headphones	1	305	982.96	99	216
566	Camera	1	419	1760.49	107	201
867	Washing Machine	2	394	484.16	131	122
692	Washing Machine	1	211	584.00	140	241
136	TV	1	442	563.64	146	126
195	Laptop	2	399	656.80	87	102
406	Laptop	2	240	1097.92	137	188
430	Camera	2	280	254.11	69	157
477	Laptop	1	197	198.88	123	124
488	Camera	1	410	174.59	87	110
876	Washing Machine	1	121	1320.23	128	217
963	Tablet	2	219	1517.46	150	268
166	Fridge	1	250	1956.66	75	293
224	Headphones	2	143	1094.72	131	201
980	Smartphone	1	255	682.38	70	143
381	Laptop	1	255	1512.60	143	139
159	Washing Machine	2	325	1098.57	137	108
744	Smartphone	1	429	639.98	133	267
641	Tablet	2	430	1567.06	104	243
595	Fridge	1	417	881.39	132	252
841	Laptop	2	131	619.25	114	179
907	Fridge	1	324	1629.90	73	293
723	Washing Machine	2	477	1555.69	100	199
968	Tablet	2	339	1464.98	65	121
424	Smartphone	2	408	883.18	141	280
365	Washing Machine	2	256	631.42	141	160
638	Tablet	1	326	92.22	149	203
688	Camera	2	300	892.41	76	109
462	Tablet	2	210	1245.65	111	226
232	Camera	1	153	985.54	107	136
729	Fridge	1	370	1528.85	126	225
676	Fridge	1	466	1036.76	51	140
608	Fridge	1	211	456.21	93	109
632	TV	1	434	282.10	81	261
846	TV	1	230	1185.47	88	290
604	Headphones	1	393	1838.14	120	112
724	Tablet	2	181	337.24	78	246
825	TV	1	403	253.70	75	101
397	Tablet	1	184	817.33	63	211
298	Camera	2	428	1141.14	133	288
101	Smartphone	1	349	1498.93	90	152
855	Fridge	1	470	643.38	100	192
918	Camera	1	262	491.95	119	202
524	TV	1	181	783.03	70	147
146	Fridge	2	486	777.05	104	133
673	Camera	1	306	545.86	57	109
925	Smartphone	2	476	532.51	65	179
317	TV	1	367	808.67	78	169
755	Washing Machine	1	309	1825.24	117	130
388	Smartphone	2	110	1700.79	128	109
360	Laptop	2	293	1432.59	132	192
909	Camera	1	318	808.11	96	270
618	Washing Machine	1	328	745.64	95	125
885	Headphones	2	181	1272.87	135	268
129	Fridge	1	486	1051.56	61	175
279	Smartphone	2	211	1150.86	124	222
438	Fridge	1	268	1676.55	52	123
953	Camera	2	228	609.02	136	263
446	Fridge	1	459	1996.95	98	151
590	Camera	1	121	1538.26	104	245
916	Fridge	2	437	1351.91	114	274
239	Headphones	2	250	1425.21	80	186
593	TV	2	420	547.53	141	161
742	Tablet	1	109	1403.29	95	244
573	Washing Machine	2	304	1630.21	68	269
902	Smartphone	2	199	1725.89	102	232
933	Smartphone	1	369	1095.23	133	192
955	Smartphone	2	293	442.50	113	156
842	Laptop	2	111	1712.85	66	181
648	Fridge	2	250	1465.72	131	102
313	Smartphone	2	371	1428.81	120	241
914	Smartphone	2	464	946.38	62	274
252	Camera	2	215	860.20	93	192
387	Fridge	2	193	899.24	55	111
960	Smartphone	2	451	202.02	103	123
131	Fridge	1	384	322.12	66	282
447	TV	1	463	661.22	58	179
484	Laptop	2	214	818.60	57	210
647	TV	2	276	389.10	87	161
962	Fridge	1	439	1902.75	54	265
269	Washing Machine	1	203	112.54	59	131
498	Fridge	1	108	310.60	128	192
291	Tablet	2	338	1412.95	124	101
219	Fridge	1	153	1246.75	133	104
901	Washing Machine	1	121	191.12	100	247
869	Camera	2	249	1977.71	67	165
978	Tablet	2	456	1129.77	117	194
132	Washing Machine	2	317	1253.53	122	283
378	TV	2	111	81.48	128	272
188	Washing Machine	2	283	932.06	132	283
480	Fridge	1	491	1637.79	117	173
321	Smartphone	1	241	462.01	56	125
214	Smartphone	1	410	1710.36	120	265
483	Fridge	1	370	1820.53	61	253
903	Laptop	2	176	896.85	147	105
554	TV	1	277	1121.69	64	124
257	Camera	1	202	1513.35	75	240
448	Laptop	1	354	1303.55	117	101
994	Smartphone	2	155	744.23	60	104
417	Headphones	1	433	1296.75	146	128
435	Tablet	2	485	905.41	124	296
246	Tablet	2	462	1709.08	52	189
200	Smartphone	2	279	1235.32	51	187
792	TV	1	257	1939.06	53	248
310	Laptop	2	369	1117.77	93	199
570	Smartphone	2	202	1613.08	100	262
830	Camera	2	282	1470.78	100	105
634	TV	2	130	1671.90	111	202
218	Tablet	1	432	1574.50	50	124
104	Laptop	2	464	578.62	130	200
418	TV	2	128	612.67	72	265
578	Camera	1	100	636.35	107	172
147	Headphones	2	117	1522.31	129	150
205	Smartphone	1	497	1915.57	116	287
884	Tablet	2	197	1854.05	118	272
774	Headphones	1	483	588.19	117	210
754	Headphones	1	130	747.32	79	294
393	Headphones	2	206	959.79	69	102
383	TV	1	211	1656.60	126	136
891	Fridge	1	237	1392.00	72	242
379	Fridge	1	243	909.58	135	158
217	Headphones	2	147	150.95	91	186
626	Tablet	2	176	244.82	87	196
204	Camera	1	415	1408.58	125	292
662	Headphones	1	462	1185.48	120	174
687	TV	1	180	252.58	80	275
275	Tablet	2	235	997.48	60	212
172	Tablet	1	434	1119.58	114	175
653	Tablet	2	379	840.51	89	175
791	Smartphone	2	456	842.76	56	243
208	Fridge	2	448	1683.81	110	112
492	Smartphone	1	285	328.44	130	137
501	Smartphone	1	203	1852.77	84	209
706	Smartphone	2	134	1428.12	101	178
956	Fridge	1	300	838.28	126	150
440	Smartphone	2	144	1398.20	133	135
786	Headphones	2	471	319.31	93	261
928	Fridge	2	130	612.20	119	123
646	TV	2	131	236.37	81	109
873	Tablet	1	401	349.13	113	256
681	Camera	1	311	251.04	51	233
932	Tablet	1	203	1198.21	145	182
921	TV	1	446	326.25	109	114
579	Smartphone	2	407	1726.84	128	233
199	Laptop	2	435	877.61	124	129
759	Laptop	2	366	301.01	64	270
827	Fridge	1	227	1713.12	106	176
581	Washing Machine	1	342	673.06	130	138
329	Fridge	2	345	1194.86	79	207
247	Laptop	1	295	409.17	148	101
981	TV	2	268	393.40	96	212
472	Camera	1	168	103.69	114	225
287	Laptop	1	252	1491.36	86	300
781	Smartphone	1	490	1708.16	76	103
586	Washing Machine	2	103	1058.20	83	268
459	Smartphone	1	165	277.65	64	148
389	Tablet	1	314	1726.84	53	207
718	Washing Machine	1	495	472.33	136	239
230	Headphones	1	275	829.47	76	247
515	Fridge	2	214	913.30	50	117
831	Headphones	1	292	387.86	71	194
433	Washing Machine	1	298	426.99	56	108
510	Tablet	2	232	973.43	66	297
344	Smartphone	1	498	589.62	101	241
349	Camera	2	399	1292.10	79	241
262	Tablet	1	361	1262.57	98	214
705	Washing Machine	1	283	838.35	50	203
541	Laptop	1	268	1637.44	58	258
545	Headphones	2	304	179.35	60	126
450	Fridge	2	421	1922.86	65	295
657	Camera	2	186	770.98	127	239
785	Headphones	2	234	862.15	144	269
598	Camera	1	353	1184.13	127	300
555	Smartphone	2	492	504.98	140	166
280	Fridge	2	462	456.34	51	218
171	Laptop	2	387	1855.57	92	197
712	Smartphone	2	473	298.20	102	143
606	Camera	2	131	1980.28	96	119
760	Fridge	1	239	1013.02	126	266
162	Smartphone	2	361	630.73	61	163
242	Smartphone	1	175	1733.65	96	139
751	Laptop	1	132	433.21	64	103
929	TV	2	280	1269.33	80	248
100	Laptop	1	493	1865.88	133	248
250	Fridge	2	365	464.38	69	231
563	Washing Machine	2	433	690.62	117	102
499	Washing Machine	2	236	1176.61	98	188
557	TV	1	167	1474.92	56	295
797	TV	2	452	1200.96	91	161
683	TV	1	222	1115.44	71	182
913	Fridge	2	381	1331.68	87	274
795	TV	2	262	859.80	124	185
622	Fridge	1	232	222.35	135	204
513	Laptop	2	374	527.44	88	186
967	Headphones	2	491	1019.35	124	244
478	TV	1	363	1561.28	113	244
820	Fridge	1	470	1246.41	66	189
940	TV	2	417	1919.91	113	235
212	Camera	2	385	87.24	129	254
986	Laptop	2	123	586.44	138	186
340	Laptop	1	464	307.04	148	103
658	Laptop	2	153	1671.13	126	234
228	Tablet	2	479	1700.64	83	131
763	Camera	1	342	856.54	139	103
838	TV	2	479	1155.96	96	248
773	TV	1	469	849.50	103	108
547	Fridge	1	353	1979.67	106	254
186	Tablet	2	132	1379.76	59	224
525	TV	1	427	266.33	59	189
535	Headphones	1	303	271.50	123	129
621	Laptop	2	467	1476.19	101	216
534	Smartphone	1	161	116.08	126	211
665	TV	2	317	1520.98	91	220
107	Washing Machine	2	379	1916.15	50	262
342	Smartphone	2	474	1113.72	133	226
375	Laptop	2	301	171.05	101	180
520	TV	2	188	188.76	61	253
134	Smartphone	2	170	1988.25	63	244
807	Smartphone	2	231	98.58	77	155
979	TV	2	325	1082.79	130	110
583	Headphones	2	440	619.36	95	203
859	Headphones	1	283	1698.98	83	182
748	Laptop	2	333	1129.36	58	275
917	Camera	1	289	1993.01	149	178
693	Camera	1	454	458.58	133	148
624	TV	1	196	1109.91	106	229
531	Tablet	2	497	1773.33	65	121
461	Fridge	2	326	1591.90	103	264
271	TV	1	237	240.63	147	108
677	Fridge	1	261	365.07	82	101
366	Camera	1	365	1869.06	110	140
584	Tablet	1	133	614.19	134	147
739	Headphones	1	409	1862.40	79	155
127	Laptop	1	100	465.60	57	218
229	Fridge	1	333	792.10	66	117
617	TV	1	341	1727.36	145	155
178	Tablet	2	434	415.67	59	119
971	Smartphone	1	318	189.91	60	234
358	TV	2	201	123.14	83	173
278	Laptop	1	304	603.72	128	136
254	TV	1	278	210.68	85	116
367	Tablet	2	224	411.81	58	143
817	Tablet	2	477	1118.34	113	213
640	Smartphone	2	145	1329.18	74	223
982	Headphones	1	116	1492.21	147	292
957	Laptop	1	267	1188.31	51	189
607	Laptop	2	493	1214.56	105	206
315	Fridge	2	487	770.03	133	183
453	TV	2	219	893.74	136	203
370	Washing Machine	1	345	833.69	104	263
153	Tablet	2	372	334.01	63	239
575	Camera	2	471	924.10	137	233
408	Tablet	2	382	809.95	119	157
864	Tablet	2	195	1324.15	137	149
799	Camera	1	268	93.98	104	270
643	Camera	2	341	483.84	145	203
991	Tablet	2	415	1974.32	98	195
964	Fridge	1	396	580.29	86	172
698	Fridge	2	389	328.51	110	167
500	Camera	2	171	338.76	81	277
347	Washing Machine	2	111	687.15	54	155
299	Fridge	2	175	629.46	148	167
445	Tablet	2	412	229.93	69	149
793	TV	1	171	1466.27	96	276
110	Camera	2	189	1785.32	111	215
951	Tablet	1	234	530.24	82	138
206	Washing Machine	2	125	1570.55	60	101
324	TV	2	347	1084.69	91	266
357	Smartphone	1	130	1593.51	121	298
158	Camera	1	345	1135.22	52	245
713	Smartphone	1	109	1856.94	122	173
753	Laptop	1	210	83.53	52	225
222	Smartphone	2	470	249.54	150	248
177	Laptop	2	252	391.81	56	224
899	Headphones	2	221	1138.71	61	193
175	Tablet	2	119	1557.56	126	276
323	Laptop	1	195	1931.26	147	139
728	TV	2	152	1154.56	65	230
758	Headphones	1	476	145.24	69	226
832	Tablet	1	276	1063.65	108	103
174	TV	1	417	1469.38	67	276
780	Camera	1	155	632.74	94	223
627	Camera	1	294	363.42	65	256
602	Smartphone	1	350	575.24	138	254
589	Laptop	1	429	946.67	108	265
546	Fridge	1	313	1682.86	139	238
904	Washing Machine	2	288	1366.86	72	114
798	Fridge	1	487	688.87	73	181
762	Washing Machine	2	479	106.15	142	232
182	Washing Machine	1	207	769.40	54	110
961	Tablet	1	411	169.80	106	212
878	Camera	1	286	465.15	80	261
667	Camera	1	352	1865.29	115	121
548	Headphones	1	283	357.97	92	273
243	Smartphone	2	494	1220.47	50	198
707	Tablet	1	257	1858.84	138	280
600	Washing Machine	1	387	282.49	137	138
164	Laptop	2	479	1201.16	112	100
611	Tablet	2	108	1676.71	78	140
954	Fridge	1	405	1973.09	87	243
769	Tablet	1	474	257.17	62	239
995	Tablet	1	270	215.27	124	222
858	Washing Machine	2	330	92.27	80	215
733	Camera	2	201	1492.93	63	184
818	Laptop	1	420	54.79	92	280
276	TV	1	429	328.12	136	245
414	Laptop	1	137	721.05	83	209
912	Headphones	1	302	473.53	123	297
165	Fridge	2	419	1548.34	63	240
325	Tablet	1	293	1892.71	54	163
511	Smartphone	2	402	712.96	57	156
429	Smartphone	2	400	1172.22	76	234
318	Laptop	2	496	1313.61	81	135
272	Washing Machine	1	344	911.51	65	278
268	TV	2	341	448.77	144	179
695	Fridge	2	142	1383.71	67	142
141	TV	1	178	290.05	98	148
236	Camera	1	126	743.68	133	294
202	TV	2	288	352.86	56	258
834	Fridge	2	353	189.58	135	157
528	Camera	1	436	806.28	89	260
296	Laptop	2	479	408.78	51	240
470	Headphones	2	228	174.05	91	181
879	Fridge	1	153	407.00	114	130
619	Laptop	1	471	1888.98	66	234
924	Smartphone	2	131	328.84	71	110
335	Smartphone	1	307	1968.73	57	200
333	Washing Machine	2	169	1413.11	101	222
402	Laptop	2	250	145.57	118	276
977	Washing Machine	1	429	793.00	73	168
385	Tablet	1	428	453.35	84	239
538	TV	1	473	1370.50	68	179
185	Camera	2	140	1905.73	52	213
871	Camera	2	479	1175.30	90	185
809	Laptop	1	393	1483.83	139	135
516	Laptop	1	482	1294.21	51	199
591	TV	2	403	693.84	83	267
697	TV	2	420	132.02	142	175
479	Camera	1	497	1235.99	57	255
494	Smartphone	1	439	993.28	111	199
403	Laptop	2	138	877.37	72	133
790	Tablet	2	351	1095.80	130	113
615	Washing Machine	1	446	1205.43	117	178
796	Headphones	2	114	1631.68	77	185
481	Headphones	2	170	1434.73	94	237
597	Camera	2	344	1059.82	102	276
225	Tablet	2	164	58.62	124	243
476	Tablet	1	342	940.53	57	130
400	Laptop	1	294	625.65	97	238
530	Camera	2	197	1652.22	63	285
121	Camera	1	359	1257.13	59	113
293	TV	1	120	1438.04	113	172
413	TV	1	220	440.57	70	114
965	TV	1	218	755.60	85	197
148	Headphones	1	208	604.80	98	101
264	Headphones	1	418	211.10	114	158
286	Washing Machine	1	447	135.52	82	253
782	Tablet	1	120	1032.64	119	104
427	Camera	1	191	1400.71	89	162
872	Headphones	2	205	1356.13	80	287
664	Tablet	2	335	595.62	111	161
465	Headphones	1	242	1977.29	110	257
900	Tablet	2	230	163.51	64	170
651	Headphones	2	411	1128.44	104	180
469	Laptop	1	368	1268.74	128	197
833	Laptop	2	134	146.27	65	238
320	Laptop	2	324	180.22	107	272
701	Headphones	1	364	1377.72	133	207
874	Tablet	2	421	1189.83	134	176
102	Headphones	1	341	915.51	66	241
227	Washing Machine	2	394	1979.55	145	206
117	Smartphone	1	324	692.84	110	192
149	Laptop	2	334	1226.76	84	177
198	Fridge	2	275	492.77	96	291
943	Washing Machine	2	199	1286.28	127	277
113	Headphones	1	130	377.89	63	121
938	Smartphone	1	187	456.14	54	180
881	Laptop	1	225	1052.52	115	260
231	Smartphone	1	292	1892.16	75	251
893	Washing Machine	2	191	1773.45	72	252
301	TV	1	211	1315.21	86	132
625	Tablet	2	334	1396.49	139	165
160	Headphones	1	184	111.76	136	104
703	Camera	2	434	516.05	86	252
517	Tablet	2	117	720.69	120	238
421	Washing Machine	2	465	1017.02	91	190
577	Headphones	1	314	1130.31	144	213
207	Laptop	2	287	1075.15	140	207
920	Fridge	2	375	1029.06	90	173
950	Washing Machine	1	272	428.46	126	125
736	Tablet	2	307	1345.72	106	146
777	Laptop	1	382	175.25	76	258
369	Fridge	1	271	1587.92	71	198
486	Washing Machine	1	112	945.51	59	278
128	TV	1	203	137.07	51	137
120	Smartphone	2	418	1220.45	90	110
984	Smartphone	2	355	409.17	123	228
750	Headphones	2	359	906.42	57	260
970	Camera	2	387	1025.93	145	250
404	Camera	1	206	1497.26	149	254
543	Laptop	2	261	1620.80	95	106
374	Headphones	1	316	478.78	130	153
473	TV	2	318	1339.58	115	141
506	Headphones	1	277	1788.69	50	201
948	Camera	1	179	199.88	117	160
854	TV	1	175	1520.91	120	217
866	Laptop	2	150	1677.85	88	237
861	Tablet	2	195	523.21	125	249
345	TV	2	476	1216.56	119	197
746	Laptop	1	459	392.89	141	158
997	Tablet	1	303	1427.38	146	122
334	Headphones	1	313	1161.20	127	143
539	Washing Machine	2	404	1261.17	97	196
354	Headphones	1	267	1160.17	112	195
436	Fridge	2	253	1490.56	147	254
183	Smartphone	2	116	1777.52	63	207
512	Laptop	2	150	1320.89	105	285
935	Camera	1	143	753.96	140	223
203	Camera	1	257	545.47	84	229
877	Washing Machine	1	494	476.68	101	213
766	Fridge	1	492	686.28	101	194
721	Fridge	1	444	1552.77	56	192
700	TV	2	454	810.17	63	146
109	Washing Machine	1	214	1359.01	67	217
466	Camera	2	219	1127.01	133	141
176	Headphones	1	249	1108.55	139	295
170	TV	1	436	1838.25	65	161
328	Fridge	1	175	653.93	128	205
\.


--
-- Data for Name: promotionapplications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.promotionapplications (transaction_id, promotion_id) FROM stdin;
2	1
4	1
20	1
25	1
29	2
37	1
45	1
47	2
63	2
77	2
78	1
79	2
101	1
107	2
110	1
119	1
125	1
147	2
155	2
165	2
179	2
182	1
187	1
190	1
192	2
198	1
201	2
207	2
222	1
228	1
235	2
237	2
238	1
243	2
244	2
246	2
263	1
273	1
283	2
287	1
298	2
299	1
301	2
310	2
312	1
326	2
328	2
333	2
337	1
343	2
346	1
349	2
352	1
356	2
366	1
371	2
386	1
388	1
403	2
405	1
412	2
415	2
416	2
422	1
429	2
430	1
432	1
436	2
437	2
439	2
445	1
447	1
448	2
449	2
451	2
453	1
464	1
471	1
474	2
478	1
479	2
480	2
484	1
487	2
488	1
489	2
490	1
499	2
503	2
515	1
539	1
552	2
566	1
569	2
570	2
582	1
583	2
584	2
585	2
592	1
594	2
597	2
598	2
600	2
602	1
603	2
604	1
610	2
613	2
614	2
615	2
617	2
618	2
619	1
621	2
623	1
627	2
631	1
632	1
640	1
644	2
647	2
649	1
663	1
683	1
698	2
701	2
705	2
706	2
711	1
714	2
717	2
723	1
724	2
750	2
754	2
755	1
765	2
767	1
772	1
775	1
781	2
790	2
791	2
793	2
809	2
813	1
824	2
832	1
844	1
845	2
848	1
853	2
857	1
869	2
870	1
873	2
885	1
887	2
894	1
895	2
902	2
909	2
935	1
936	2
942	1
943	1
944	2
947	1
966	1
970	1
973	2
975	2
992	1
995	2
1003	1
1011	2
1012	2
1013	2
1016	1
1019	2
1020	1
1025	1
1032	2
1033	1
1039	2
1054	2
1055	1
1056	2
1059	1
1063	1
1070	2
1081	2
1083	1
1102	2
1106	1
1110	2
1121	2
1128	2
1133	1
1134	1
1143	2
1149	1
1158	2
1175	1
1187	1
1190	1
1200	2
1204	2
1206	2
1211	2
1216	2
1224	2
1226	2
1228	1
1233	1
1238	2
1245	1
1248	1
1252	2
1257	2
1263	1
1268	1
1279	2
1283	1
1304	2
1312	2
1326	1
1331	1
1342	1
1350	1
1354	2
1356	1
1366	2
1373	2
1379	1
1383	2
1393	1
1399	2
1404	2
1421	2
1442	2
1444	2
1447	1
1449	1
1469	2
1474	2
1475	2
1493	1
1496	1
1502	2
1503	2
1504	1
1516	2
1536	2
1537	2
1538	1
1542	1
1557	2
1568	2
1571	2
1573	2
1579	2
1581	1
1590	1
1595	1
1597	1
1601	1
1611	1
1612	1
1617	1
1620	2
1631	2
1635	2
1645	2
1648	2
1671	2
1677	2
1682	2
1687	2
1694	1
1702	2
1706	1
1709	1
1713	1
1717	1
1722	2
1740	2
1742	2
1744	2
1745	1
1750	2
1758	1
1759	2
1770	1
1778	1
1779	1
1788	1
1794	2
1799	1
1803	1
1813	2
1820	2
1823	2
1825	1
1826	1
1835	1
1844	1
1852	1
1859	1
1860	2
1865	1
1878	1
1880	1
1884	1
1888	1
1893	2
1902	2
1909	1
1910	1
1929	2
1939	2
1944	1
1956	2
1957	1
1972	2
1975	1
1985	2
1987	2
1993	2
2004	1
2005	2
2007	2
2008	1
2016	2
2024	1
2026	1
2040	2
2042	2
2043	1
2049	2
2072	1
2079	2
2084	1
2086	1
2096	1
2101	1
2111	1
2113	1
2115	2
2116	1
2119	1
2120	2
2140	2
2143	1
2145	2
2147	1
2154	1
2156	2
2162	2
2163	2
2164	2
2168	1
2170	2
2174	2
2177	1
2199	2
2201	2
2207	1
2213	2
2214	2
2217	2
2219	1
2221	2
2228	2
2236	1
2237	1
2238	1
2239	1
2242	1
2251	1
2252	2
2254	1
2260	2
2266	1
2273	2
2311	1
2313	1
2333	2
2335	2
2337	1
2341	2
2345	2
2347	2
2350	2
2372	1
2374	1
2379	2
2381	2
2384	2
2391	1
2397	2
2398	2
2407	1
2408	1
2421	2
2436	1
2437	1
2445	2
2448	1
2450	2
2453	1
2454	2
2455	2
2459	2
2464	1
2478	2
2489	1
2491	2
2494	1
2496	2
2502	2
2504	1
2505	2
2506	2
2519	1
2540	1
2541	1
2551	1
2552	1
2556	1
2565	1
2566	1
2567	2
2570	2
2573	2
2576	1
2583	1
2588	1
2596	1
2597	1
2617	2
2634	1
2639	1
2645	2
2646	1
2659	2
2667	2
2669	1
2686	1
2694	1
2703	2
2731	2
2737	1
2748	1
2749	2
2759	1
2765	1
2785	1
2791	2
2796	2
2806	1
2819	1
2829	1
2836	2
2840	2
2847	2
2850	2
2854	2
2858	1
2859	1
2861	1
2862	2
2865	2
2866	2
2869	1
2874	1
2876	2
2879	1
2887	2
2893	1
2896	1
2907	1
2908	2
2909	2
2918	1
2920	1
2921	1
2930	1
2935	1
2941	2
2968	1
2975	2
2976	2
2995	2
2998	2
2999	1
3005	1
3010	2
3013	1
3018	1
3025	2
3030	2
3031	2
3039	2
3044	2
3046	1
3048	1
3059	1
3064	2
3070	2
3076	2
3083	2
3085	1
3090	2
3092	1
3098	2
3106	1
3108	1
3109	2
3125	2
3130	2
3135	1
3139	1
3154	2
3157	1
3159	1
3164	2
3168	2
3174	2
3186	2
3192	1
3201	2
3202	2
3205	1
3217	2
3224	2
3225	2
3228	1
3232	1
3238	2
3248	1
3256	1
3259	2
3268	2
3270	2
3272	1
3299	2
3321	1
3347	2
3349	1
3363	1
3370	1
3382	2
3386	1
3390	2
3394	1
3401	2
3402	1
3410	1
3417	1
3420	2
3438	2
3466	1
3471	2
3481	1
3483	2
3485	1
3494	2
3497	2
3503	1
3504	2
3513	2
3515	2
3532	2
3539	2
3548	1
3551	2
3559	2
3563	1
3570	2
3572	2
3582	1
3592	1
3618	2
3626	2
3627	1
3635	2
3643	2
3645	2
3653	1
3656	2
3660	2
3662	2
3669	1
3670	1
3677	1
3683	2
3694	2
3714	1
3720	1
3723	2
3725	2
3727	2
3732	2
3734	2
3743	1
3747	2
3753	1
3762	1
3768	2
3773	2
3785	1
3788	2
3790	1
3793	2
3813	1
3814	2
3815	1
3818	1
3831	2
3842	2
3846	2
3853	2
3860	1
3863	1
3871	1
3872	1
3882	2
3892	2
3895	1
3896	2
3900	2
3903	2
3904	1
3917	2
3919	1
3921	1
3925	1
3927	1
3928	1
3935	1
3939	1
3940	1
3943	2
3947	2
3949	2
3953	1
3960	1
3962	2
3964	2
3976	2
3984	2
3991	2
4000	2
4004	2
4006	1
4009	2
4021	2
4023	2
4026	1
4033	2
4048	2
4049	2
4051	2
4053	1
4054	2
4055	2
4060	2
4066	1
4071	2
4076	1
4084	1
4093	1
4106	1
4109	1
4112	1
4119	2
4131	2
4137	2
4140	2
4144	1
4147	2
4151	1
4156	1
4158	2
4159	2
4175	1
4184	2
4188	1
4203	2
4209	1
4238	1
4250	1
4258	2
4272	1
4279	2
4280	2
4285	1
4293	1
4301	1
4303	1
4313	2
4326	2
4334	2
4336	1
4337	2
4347	1
4348	1
4356	1
4358	2
4361	1
4366	2
4389	2
4402	1
4406	2
4409	1
4416	1
4428	2
4431	1
4434	1
4443	2
4444	2
4447	2
4456	1
4457	1
4459	1
4463	2
4464	1
4467	1
4470	1
4471	2
4478	1
4485	2
4493	2
4494	1
4499	1
4513	1
4516	1
4517	1
4521	2
4527	2
4539	2
4543	1
4548	1
4557	1
4561	1
4564	1
4565	1
4566	1
4567	1
4575	1
4578	2
4599	1
4607	1
4624	2
4633	2
4637	1
4646	2
4675	2
4680	1
4684	2
4690	2
4695	2
4699	2
4716	2
4726	2
4727	2
4728	2
4734	2
4735	2
4736	2
4742	1
4744	2
4755	2
4759	1
4761	2
4763	1
4770	1
4791	2
4797	1
4802	2
4803	1
4806	2
4807	2
4808	2
4821	2
4829	2
4839	1
4843	1
4844	1
4853	2
4856	1
4865	2
4870	1
4878	1
4880	2
4890	2
4894	2
4895	1
4913	1
4922	2
4928	1
4940	2
4945	1
4952	1
4953	1
4963	1
4972	2
4974	1
4989	1
4992	1
5000	2
\.


--
-- Data for Name: promotions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.promotions (promotion_id, promotion_type) FROM stdin;
1	Percentage Discount
2	BOGO
\.


--
-- Data for Name: stores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stores (store_id, location) FROM stdin;
1	Miami, FL
2	Dallas, TX
3	Los Angeles, CA
4	Chicago, IL
5	New York, NY
\.


--
-- Data for Name: transactiondetails; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transactiondetails (transaction_id, product_id, quantity) FROM stdin;
1	843	3
2	135	4
3	391	4
4	710	5
5	116	3
6	630	4
7	238	3
8	409	4
9	106	4
10	407	5
11	327	3
12	319	3
13	976	2
14	422	3
15	122	2
16	890	4
17	941	3
18	806	5
19	942	4
20	382	3
21	666	4
22	623	4
23	669	5
24	684	5
25	685	4
26	258	1
27	196	4
28	138	2
29	571	3
30	464	2
31	259	1
32	241	2
33	371	3
34	475	3
35	696	3
36	355	1
37	338	5
38	362	1
39	930	5
40	407	3
41	194	5
42	684	3
43	509	5
44	682	1
45	322	3
46	851	2
47	179	4
48	840	5
49	432	2
50	911	3
51	594	3
52	277	5
53	599	4
54	945	4
55	806	3
56	819	4
57	690	2
58	939	1
59	197	2
60	709	1
61	757	4
62	407	3
63	138	2
64	848	2
65	927	3
66	690	5
67	490	1
68	180	3
69	898	2
70	157	4
71	889	1
72	442	3
73	456	1
74	936	3
75	544	5
76	526	5
77	988	2
78	223	2
79	990	2
80	888	4
81	332	1
82	865	3
83	768	3
84	969	3
85	716	2
86	111	1
87	749	4
88	896	5
89	747	4
90	491	2
91	155	4
92	412	2
93	636	1
94	142	1
95	426	1
96	652	5
97	678	1
98	253	4
99	434	5
100	614	3
101	814	2
102	326	2
103	256	1
104	151	1
105	789	3
106	849	5
107	502	4
108	556	1
109	870	5
110	709	3
111	689	3
112	616	2
113	192	2
114	327	3
115	542	3
116	396	2
117	905	4
118	503	5
119	251	4
120	235	3
121	444	3
122	184	4
123	587	1
124	685	1
125	863	4
126	150	2
127	661	2
128	508	1
129	368	5
130	187	4
131	508	3
132	613	2
133	544	2
134	892	4
135	814	4
136	233	4
137	880	2
138	238	5
139	592	4
140	672	4
141	302	3
142	599	4
143	504	2
144	767	2
145	685	4
146	300	1
147	674	1
148	730	3
149	853	1
150	636	1
151	352	3
152	348	2
153	173	4
154	372	5
155	895	1
156	540	1
157	431	3
158	801	3
159	689	5
160	191	1
161	215	1
162	787	1
163	523	2
164	533	4
165	474	2
166	456	2
167	295	1
168	428	3
169	452	2
170	708	3
171	771	4
172	124	2
173	888	1
174	412	4
175	273	1
176	458	5
177	731	3
178	941	2
179	922	5
180	552	1
181	738	2
182	249	4
183	551	5
184	145	1
185	937	4
186	339	2
187	304	1
188	801	2
189	482	1
190	259	2
191	875	4
192	845	5
193	973	3
194	187	3
195	215	2
196	857	5
197	155	4
198	348	2
199	735	1
200	251	5
201	989	2
202	952	5
203	939	4
204	394	2
205	114	3
206	451	2
207	810	3
208	923	5
209	213	3
210	412	2
211	560	2
212	582	2
213	123	2
214	439	2
215	314	4
216	857	2
217	650	5
218	316	2
219	308	5
220	659	5
221	635	5
222	868	2
223	364	1
224	661	3
225	594	3
226	737	4
227	847	2
228	244	3
229	811	2
230	815	2
231	784	2
232	118	4
233	485	4
234	696	1
235	779	5
236	639	3
237	144	1
238	361	4
239	274	4
240	161	1
241	390	1
242	305	5
243	908	4
244	813	1
245	732	5
246	377	2
247	154	4
248	576	5
249	770	4
250	108	1
251	168	5
252	497	2
253	776	2
254	377	4
255	778	1
256	972	1
257	775	1
258	468	4
259	985	1
260	210	2
261	119	4
262	399	1
263	988	3
264	764	5
265	495	2
266	336	5
267	489	5
268	620	2
269	826	1
270	201	4
271	423	4
272	596	3
273	987	5
274	711	3
275	644	4
276	190	4
277	290	2
278	303	3
279	612	4
280	568	3
281	674	2
282	829	2
283	122	2
284	140	2
285	353	2
286	642	2
287	412	2
288	441	5
289	601	1
290	502	1
291	862	5
292	260	3
293	118	3
294	455	2
295	800	3
296	460	5
297	463	5
298	740	2
299	409	2
300	341	2
301	613	3
302	382	4
303	931	1
304	163	4
305	740	2
306	363	5
307	999	3
308	496	2
309	934	3
310	130	1
311	668	4
312	386	2
313	330	4
314	255	2
315	449	1
316	502	1
317	772	5
318	240	1
319	189	3
320	847	4
321	491	4
322	633	3
323	794	1
324	727	2
325	993	1
326	740	4
327	802	3
328	332	2
329	527	5
330	346	3
331	686	1
332	256	5
333	536	3
334	419	2
335	719	1
336	437	1
337	559	2
338	655	4
339	234	2
340	311	4
341	768	1
342	241	5
343	694	3
344	654	4
345	800	2
346	919	5
347	307	4
348	983	3
349	241	4
350	416	1
351	805	3
352	822	3
353	636	4
354	238	1
355	540	3
356	888	3
357	248	3
358	771	5
359	678	1
360	261	2
361	425	1
362	169	3
363	670	1
364	645	4
365	836	3
366	221	1
367	288	1
368	425	5
369	959	3
370	249	3
371	844	4
372	130	3
373	883	1
374	426	5
375	523	1
376	521	5
377	410	4
378	553	5
379	863	2
380	941	5
381	752	3
382	856	4
383	380	5
384	255	4
385	897	3
386	292	2
387	209	1
388	234	4
389	289	1
390	126	2
391	880	1
392	726	3
393	731	2
394	373	4
395	720	2
396	680	1
397	727	1
398	336	5
399	710	4
400	337	1
401	336	2
402	803	1
403	126	2
404	467	3
405	181	1
406	804	2
407	898	5
408	588	2
409	237	4
410	614	5
411	966	4
412	719	4
413	580	5
414	829	5
415	765	4
416	482	4
417	288	1
418	972	5
419	496	5
420	603	4
421	585	2
422	240	1
423	267	2
424	297	4
425	331	4
426	133	4
427	518	2
428	882	1
429	115	5
430	376	2
431	522	2
432	327	4
433	860	4
434	787	1
435	307	4
436	875	3
437	309	5
438	167	5
439	281	5
440	549	5
441	987	4
442	731	5
443	601	4
444	804	3
445	432	2
446	987	2
447	568	5
448	352	3
449	537	2
450	514	1
451	894	5
452	142	1
453	722	4
454	852	3
455	944	3
456	489	2
457	837	1
458	420	5
459	503	5
460	726	3
461	860	2
462	685	2
463	708	1
464	649	2
465	637	1
466	756	2
467	996	1
468	821	5
469	905	1
470	139	3
471	633	1
472	211	3
473	562	4
474	567	4
475	946	3
476	998	3
477	143	5
478	998	4
479	351	3
480	631	4
481	650	1
482	505	1
483	852	1
484	140	2
485	671	4
486	496	5
487	628	4
488	883	4
489	745	3
490	150	3
491	294	5
492	398	4
493	550	4
494	507	4
495	411	3
496	892	5
497	947	4
498	392	5
499	572	4
500	270	3
501	532	1
502	401	4
503	727	2
504	155	4
505	806	3
506	629	4
507	245	1
508	574	3
509	949	3
510	761	1
511	562	1
512	192	4
513	839	2
514	612	3
515	215	3
516	284	2
517	897	4
518	699	2
519	812	1
520	659	5
521	238	4
522	502	3
523	523	5
524	431	4
525	561	5
526	125	2
527	283	4
528	564	4
529	704	1
530	829	1
531	306	5
532	565	3
533	192	2
534	356	5
535	431	4
536	808	2
537	764	3
538	828	2
539	915	1
540	267	3
541	835	5
542	850	4
543	226	1
544	193	2
545	216	3
546	823	3
547	560	1
548	749	2
549	471	5
550	187	2
551	636	4
552	824	4
553	493	2
554	844	4
555	910	3
556	623	2
557	726	1
558	263	3
559	487	5
560	663	3
561	489	5
562	144	5
563	886	5
564	274	5
565	443	3
566	679	5
567	992	4
568	775	3
569	983	3
570	253	4
571	266	4
572	989	2
573	248	3
574	283	3
575	887	3
576	829	3
577	152	2
578	529	3
579	415	3
580	416	1
581	847	3
582	887	5
583	556	1
584	395	4
585	741	5
586	285	5
587	220	5
588	234	2
589	307	5
590	103	2
591	737	3
592	883	3
593	359	5
594	112	4
595	569	3
596	609	2
597	975	5
598	610	3
599	656	4
600	926	3
601	105	1
602	722	5
603	605	5
604	343	2
605	322	2
606	702	2
607	775	1
608	587	5
609	564	3
610	519	5
611	552	4
612	181	2
613	715	5
614	714	4
615	106	2
616	350	5
617	660	5
618	384	5
619	734	5
620	743	3
621	670	1
622	939	2
623	945	2
624	312	1
625	150	1
626	289	5
627	251	4
628	156	2
629	768	1
630	457	2
631	137	1
632	248	4
633	974	1
634	133	4
635	783	3
636	691	3
637	958	5
638	717	3
639	405	2
640	439	3
641	189	4
642	150	3
643	211	3
644	526	4
645	282	5
646	265	2
647	788	2
648	391	1
649	725	2
650	776	1
651	808	1
652	816	3
653	709	3
654	686	5
655	906	4
656	675	3
657	281	4
658	566	1
659	867	2
660	692	5
661	468	2
662	136	5
663	195	1
664	886	1
665	406	2
666	430	3
667	477	1
668	488	2
669	939	1
670	169	2
671	876	4
672	537	3
673	963	4
674	663	3
675	166	5
676	399	5
677	582	4
678	237	2
679	224	3
680	811	5
681	980	3
682	381	4
683	437	1
684	639	5
685	523	4
686	637	1
687	314	5
688	812	5
689	314	2
690	726	1
691	159	3
692	211	3
693	685	5
694	847	3
695	744	2
696	641	3
697	189	3
698	595	4
699	841	4
700	805	2
701	719	1
702	907	1
703	823	2
704	394	5
705	537	5
706	723	3
707	968	1
708	424	2
709	365	3
710	638	2
711	688	2
712	738	4
713	462	2
714	232	2
715	729	1
716	676	2
717	608	2
718	632	3
719	846	4
720	747	3
721	609	2
722	604	3
723	927	4
724	284	2
725	724	1
726	338	1
727	825	3
728	397	2
729	298	4
730	101	5
731	221	4
732	124	5
733	576	4
734	740	5
735	915	1
736	220	1
737	855	5
738	968	3
739	312	2
740	918	5
741	730	3
742	524	4
743	523	5
744	146	1
745	441	2
746	458	1
747	673	4
748	925	4
749	752	3
750	317	1
751	111	4
752	755	3
753	306	2
754	806	1
755	388	3
756	360	2
757	909	3
758	169	1
759	415	2
760	407	2
761	618	5
762	663	3
763	431	1
764	885	2
765	106	2
766	216	5
767	802	5
768	441	3
769	449	4
770	505	4
771	841	3
772	682	2
773	730	4
774	129	3
775	952	2
776	279	2
777	298	2
778	438	2
779	953	5
780	446	2
781	788	5
782	590	2
783	585	1
784	916	2
785	136	1
786	761	2
787	239	3
788	593	4
789	259	5
790	742	1
791	571	2
792	985	2
793	649	1
794	443	2
795	573	1
796	902	2
797	933	2
798	523	3
799	860	4
800	157	4
801	955	4
802	633	1
803	406	1
804	678	4
805	842	4
806	794	3
807	423	1
808	668	4
809	648	4
810	119	2
811	313	4
812	691	5
813	801	5
814	439	3
815	918	3
816	914	2
817	462	1
818	167	2
819	252	3
820	387	3
821	960	2
822	131	1
823	447	1
824	484	2
825	741	2
826	647	5
827	962	5
828	269	3
829	684	4
830	720	2
831	498	2
832	291	1
833	709	2
834	219	3
835	985	2
836	901	1
837	869	2
838	415	5
839	822	3
840	978	4
841	422	1
842	826	5
843	132	1
844	378	1
845	523	4
846	188	2
847	608	2
848	998	2
849	343	3
850	480	1
851	562	3
852	949	1
853	409	4
854	321	4
855	637	3
856	409	5
857	279	4
858	214	1
859	483	4
860	903	4
861	138	3
862	896	3
863	306	4
864	194	1
865	554	5
866	618	5
867	125	2
868	918	3
869	594	1
870	612	4
871	257	3
872	294	5
873	448	2
874	595	5
875	850	4
876	994	2
877	636	4
878	417	2
879	894	3
880	435	5
881	246	1
882	887	2
883	992	2
884	200	3
885	941	5
886	628	1
887	792	5
888	235	3
889	310	4
890	841	4
891	137	5
892	570	3
893	496	3
894	830	5
895	985	2
896	634	2
897	218	4
898	104	2
899	418	2
900	145	4
901	803	5
902	968	1
903	708	2
904	992	1
905	189	2
906	441	1
907	578	1
908	147	1
909	205	1
910	633	5
911	884	4
912	774	5
913	863	1
914	419	2
915	123	3
916	691	5
917	876	4
918	419	5
919	754	1
920	314	1
921	428	4
922	305	1
923	297	4
924	393	3
925	383	1
926	645	2
927	426	5
928	891	2
929	551	3
930	787	1
931	220	5
932	379	5
933	252	5
934	261	3
935	380	3
936	217	2
937	115	5
938	737	3
939	673	1
940	626	4
941	204	1
942	311	2
943	655	2
944	458	2
945	662	4
946	426	4
947	377	3
948	244	2
949	821	2
950	923	5
951	390	4
952	687	2
953	350	2
954	275	1
955	172	3
956	418	3
957	727	2
958	446	2
959	653	1
960	554	4
961	151	2
962	233	4
963	129	3
964	582	3
965	791	5
966	151	4
967	208	2
968	492	2
969	155	1
970	188	5
971	536	2
972	501	2
973	283	3
974	821	3
975	710	3
976	706	4
977	744	1
978	956	3
979	806	5
980	816	5
981	556	4
982	731	5
983	464	5
984	419	5
985	440	3
986	937	1
987	302	3
988	830	4
989	876	1
990	786	2
991	928	1
992	646	3
993	180	5
994	873	4
995	882	5
996	576	3
997	681	1
998	234	5
999	195	3
1000	932	2
1001	921	4
1002	815	4
1003	579	3
1004	199	5
1005	566	2
1006	417	4
1007	800	4
1008	759	2
1009	827	2
1010	884	5
1011	576	3
1012	581	4
1013	337	2
1014	329	3
1015	247	2
1016	981	4
1017	731	4
1018	364	4
1019	472	3
1020	501	2
1021	287	2
1022	816	3
1023	781	5
1024	438	2
1025	907	1
1026	981	4
1027	432	1
1028	564	4
1029	599	3
1030	130	5
1031	166	1
1032	586	2
1033	215	5
1034	459	2
1035	590	1
1036	572	3
1037	966	5
1038	274	2
1039	389	2
1040	886	5
1041	456	3
1042	718	1
1043	688	1
1044	230	3
1045	620	4
1046	205	2
1047	515	1
1048	937	2
1049	831	5
1050	915	3
1051	209	3
1052	433	5
1053	669	4
1054	765	2
1055	172	4
1056	911	2
1057	409	4
1058	645	2
1059	572	4
1060	510	2
1061	704	5
1062	523	3
1063	344	2
1064	735	1
1065	349	4
1066	661	4
1067	262	1
1068	593	3
1069	493	3
1070	167	5
1071	448	5
1072	313	1
1073	933	5
1074	810	3
1075	705	1
1076	541	2
1077	903	2
1078	545	1
1079	680	2
1080	906	5
1081	450	1
1082	657	1
1083	810	3
1084	341	5
1085	277	5
1086	778	2
1087	785	2
1088	179	1
1089	857	1
1090	828	2
1091	687	2
1092	956	1
1093	598	2
1094	217	1
1095	706	3
1096	710	3
1097	574	5
1098	433	1
1099	668	3
1100	199	5
1101	941	2
1102	555	4
1103	280	5
1104	415	4
1105	515	5
1106	171	4
1107	712	4
1108	211	3
1109	801	1
1110	933	1
1111	710	5
1112	889	1
1113	939	5
1114	488	3
1115	435	3
1116	606	5
1117	760	5
1118	776	1
1119	162	4
1120	192	3
1121	322	3
1122	936	2
1123	242	1
1124	694	1
1125	873	4
1126	751	2
1127	929	5
1128	100	5
1129	875	4
1130	250	4
1131	776	5
1132	252	4
1133	563	2
1134	644	3
1135	398	5
1136	499	3
1137	730	4
1138	691	4
1139	557	3
1140	300	4
1141	310	3
1142	797	1
1143	998	5
1144	424	4
1145	406	2
1146	683	2
1147	913	3
1148	795	2
1149	411	1
1150	545	5
1151	835	2
1152	452	4
1153	191	2
1154	696	2
1155	108	1
1156	726	2
1157	622	2
1158	513	1
1159	967	3
1160	230	1
1161	972	1
1162	401	3
1163	163	2
1164	478	5
1165	662	3
1166	154	5
1167	100	2
1168	820	1
1169	673	3
1170	940	4
1171	467	5
1172	212	5
1173	981	1
1174	388	1
1175	986	4
1176	131	5
1177	340	4
1178	542	2
1179	819	4
1180	704	5
1181	503	5
1182	740	5
1183	425	5
1184	828	3
1185	491	5
1186	515	5
1187	490	1
1188	545	2
1189	658	5
1190	316	2
1191	778	1
1192	277	5
1193	586	1
1194	242	1
1195	292	2
1196	668	4
1197	493	4
1198	963	4
1199	468	1
1200	960	2
1201	527	1
1202	257	1
1203	395	1
1204	993	3
1205	786	2
1206	228	2
1207	237	5
1208	111	3
1209	173	2
1210	763	5
1211	116	4
1212	247	2
1213	838	1
1214	598	1
1215	773	3
1216	547	1
1217	239	3
1218	186	2
1219	240	3
1220	757	2
1221	925	5
1222	525	2
1223	980	5
1224	566	1
1225	907	3
1226	812	5
1227	718	2
1228	535	4
1229	738	5
1230	284	2
1231	565	5
1232	621	5
1233	534	1
1234	665	1
1235	939	4
1236	560	4
1237	493	5
1238	463	4
1239	331	2
1240	290	4
1241	534	4
1242	719	2
1243	107	2
1244	691	2
1245	610	5
1246	967	2
1247	848	5
1248	342	5
1249	829	4
1250	613	2
1251	375	2
1252	520	4
1253	659	4
1254	690	1
1255	475	5
1256	134	3
1257	138	1
1258	681	5
1259	594	4
1260	821	2
1261	477	4
1262	215	4
1263	694	1
1264	593	2
1265	807	4
1266	181	5
1267	245	3
1268	847	1
1269	848	1
1270	639	1
1271	979	2
1272	868	2
1273	897	5
1274	386	2
1275	576	2
1276	629	2
1277	180	5
1278	635	2
1279	724	1
1280	190	5
1281	351	5
1282	583	2
1283	745	3
1284	859	2
1285	779	4
1286	784	5
1287	179	1
1288	800	5
1289	748	4
1290	652	3
1291	917	1
1292	693	4
1293	419	4
1294	727	4
1295	154	4
1296	451	1
1297	647	1
1298	897	4
1299	111	3
1300	580	5
1301	564	2
1302	624	1
1303	580	5
1304	687	5
1305	851	1
1306	439	3
1307	531	2
1308	461	1
1309	917	5
1310	401	2
1311	396	4
1312	271	5
1313	136	4
1314	811	4
1315	711	1
1316	867	4
1317	411	5
1318	844	1
1319	903	3
1320	677	5
1321	366	4
1322	162	5
1323	744	5
1324	584	2
1325	692	5
1326	273	3
1327	686	3
1328	152	4
1329	772	2
1330	398	1
1331	928	2
1332	855	4
1333	739	4
1334	127	3
1335	393	4
1336	596	5
1337	184	4
1338	229	2
1339	617	5
1340	178	3
1341	971	5
1342	902	1
1343	384	2
1344	358	3
1345	235	4
1346	730	2
1347	387	3
1348	381	5
1349	978	5
1350	363	5
1351	114	5
1352	859	2
1353	214	3
1354	718	3
1355	278	2
1356	705	5
1357	856	3
1358	254	4
1359	774	1
1360	557	4
1361	478	3
1362	927	2
1363	279	5
1364	367	5
1365	901	1
1366	817	4
1367	341	3
1368	596	4
1369	285	2
1370	918	5
1371	640	4
1372	982	4
1373	133	5
1374	451	3
1375	186	1
1376	248	4
1377	709	5
1378	941	5
1379	257	4
1380	957	4
1381	607	1
1382	870	5
1383	522	1
1384	888	5
1385	492	5
1386	343	4
1387	776	3
1388	550	4
1389	843	3
1390	752	5
1391	271	3
1392	315	5
1393	691	5
1394	851	3
1395	962	4
1396	453	3
1397	155	1
1398	757	5
1399	370	2
1400	873	5
1401	939	5
1402	218	3
1403	153	1
1404	271	4
1405	575	4
1406	508	2
1407	587	3
1408	408	4
1409	587	5
1410	864	3
1411	870	2
1412	645	4
1413	339	5
1414	488	5
1415	799	5
1416	822	1
1417	499	4
1418	585	3
1419	368	5
1420	248	5
1421	643	1
1422	991	3
1423	545	3
1424	112	3
1425	395	1
1426	916	5
1427	559	2
1428	491	5
1429	794	4
1430	423	1
1431	642	3
1432	799	2
1433	142	1
1434	199	1
1435	644	2
1436	752	4
1437	462	2
1438	964	4
1439	542	1
1440	725	4
1441	767	4
1442	978	3
1443	379	5
1444	443	5
1445	376	1
1446	373	1
1447	921	5
1448	200	2
1449	361	3
1450	770	5
1451	698	3
1452	500	3
1453	572	5
1454	891	1
1455	791	2
1456	867	1
1457	347	5
1458	851	5
1459	788	5
1460	702	5
1461	888	2
1462	299	1
1463	632	3
1464	445	4
1465	793	3
1466	806	5
1467	284	5
1468	420	2
1469	660	5
1470	110	5
1471	788	4
1472	108	3
1473	951	1
1474	169	5
1475	112	3
1476	521	4
1477	200	2
1478	637	1
1479	206	2
1480	801	4
1481	556	3
1482	459	1
1483	324	1
1484	842	1
1485	390	2
1486	357	1
1487	297	3
1488	134	4
1489	124	4
1490	734	1
1491	194	5
1492	158	5
1493	708	3
1494	772	2
1495	955	1
1496	322	3
1497	713	4
1498	753	3
1499	224	1
1500	825	5
1501	222	3
1502	188	5
1503	976	2
1504	719	4
1505	233	5
1506	484	3
1507	772	4
1508	882	4
1509	763	5
1510	679	1
1511	922	5
1512	289	4
1513	213	1
1514	812	1
1515	288	5
1516	359	4
1517	401	2
1518	578	4
1519	776	1
1520	177	1
1521	754	1
1522	564	2
1523	383	4
1524	887	3
1525	537	1
1526	808	1
1527	783	2
1528	888	3
1529	888	3
1530	431	3
1531	363	3
1532	265	2
1533	899	5
1534	175	5
1535	383	1
1536	895	4
1537	163	4
1538	491	3
1539	497	3
1540	440	4
1541	161	5
1542	364	4
1543	932	3
1544	371	2
1545	282	3
1546	551	1
1547	171	4
1548	603	2
1549	305	2
1550	724	1
1551	502	3
1552	282	3
1553	760	5
1554	603	5
1555	211	4
1556	247	4
1557	653	2
1558	887	3
1559	541	4
1560	323	2
1561	728	2
1562	758	2
1563	208	1
1564	552	5
1565	832	1
1566	365	3
1567	205	2
1568	135	2
1569	174	3
1570	172	4
1571	685	1
1572	845	3
1573	356	4
1574	895	3
1575	556	4
1576	119	4
1577	609	3
1578	252	5
1579	768	3
1580	755	3
1581	100	3
1582	138	5
1583	780	2
1584	499	5
1585	372	4
1586	255	3
1587	816	2
1588	437	1
1589	500	2
1590	688	5
1591	103	2
1592	627	3
1593	824	1
1594	889	4
1595	602	1
1596	589	2
1597	546	3
1598	513	3
1599	964	3
1600	845	2
1601	899	1
1602	931	2
1603	904	5
1604	171	1
1605	653	1
1606	331	2
1607	103	4
1608	493	2
1609	805	2
1610	937	1
1611	898	1
1612	593	4
1613	224	2
1614	680	2
1615	648	4
1616	467	4
1617	441	2
1618	798	4
1619	410	3
1620	510	5
1621	156	5
1622	747	2
1623	762	5
1624	192	3
1625	474	5
1626	647	3
1627	973	3
1628	448	5
1629	182	3
1630	961	2
1631	570	2
1632	878	5
1633	884	3
1634	396	2
1635	763	3
1636	307	2
1637	280	3
1638	667	1
1639	140	4
1640	493	1
1641	776	5
1642	295	3
1643	406	4
1644	812	3
1645	499	5
1646	209	1
1647	745	4
1648	805	1
1649	467	1
1650	598	3
1651	186	1
1652	747	5
1653	548	1
1654	852	3
1655	294	3
1656	243	5
1657	136	1
1658	297	3
1659	125	4
1660	837	4
1661	707	3
1662	344	3
1663	600	4
1664	498	2
1665	164	3
1666	911	2
1667	653	3
1668	758	2
1669	415	3
1670	611	4
1671	646	5
1672	954	3
1673	931	1
1674	560	4
1675	116	1
1676	137	3
1677	447	5
1678	157	3
1679	445	5
1680	906	4
1681	838	2
1682	143	3
1683	515	3
1684	221	5
1685	316	2
1686	926	1
1687	769	3
1688	783	2
1689	635	4
1690	569	5
1691	794	5
1692	991	1
1693	995	2
1694	649	2
1695	252	1
1696	858	5
1697	693	2
1698	338	4
1699	173	1
1700	137	1
1701	853	2
1702	244	2
1703	600	5
1704	769	5
1705	119	2
1706	582	4
1707	733	1
1708	146	5
1709	348	4
1710	818	5
1711	764	5
1712	233	2
1713	114	5
1714	276	1
1715	747	3
1716	151	2
1717	414	4
1718	940	5
1719	912	4
1720	199	2
1721	567	1
1722	725	3
1723	274	5
1724	955	4
1725	705	2
1726	165	3
1727	937	1
1728	937	3
1729	208	2
1730	216	1
1731	609	4
1732	709	3
1733	918	4
1734	730	3
1735	325	2
1736	164	3
1737	923	2
1738	307	4
1739	536	5
1740	445	1
1741	930	1
1742	955	5
1743	855	5
1744	794	1
1745	511	3
1746	432	4
1747	223	4
1748	800	2
1749	689	3
1750	658	3
1751	240	4
1752	429	4
1753	956	1
1754	912	4
1755	318	4
1756	882	4
1757	146	2
1758	707	5
1759	277	4
1760	443	5
1761	164	1
1762	223	3
1763	380	2
1764	244	2
1765	875	4
1766	525	2
1767	272	5
1768	813	5
1769	478	5
1770	666	3
1771	268	4
1772	549	4
1773	349	3
1774	695	3
1775	141	1
1776	236	5
1777	202	5
1778	910	5
1779	967	5
1780	747	1
1781	727	1
1782	485	1
1783	896	1
1784	261	5
1785	116	5
1786	598	5
1787	182	3
1788	106	4
1789	107	2
1790	283	5
1791	191	1
1792	823	5
1793	767	2
1794	707	3
1795	390	2
1796	526	1
1797	810	1
1798	926	5
1799	911	5
1800	891	4
1801	587	5
1802	808	3
1803	229	3
1804	311	2
1805	246	3
1806	755	4
1807	377	3
1808	635	5
1809	561	5
1810	521	3
1811	344	5
1812	278	5
1813	725	4
1814	808	5
1815	138	3
1816	710	4
1817	284	2
1818	834	5
1819	611	3
1820	726	4
1821	190	3
1822	742	5
1823	946	3
1824	901	5
1825	408	2
1826	456	5
1827	528	1
1828	104	5
1829	671	1
1830	341	2
1831	296	2
1832	220	1
1833	642	4
1834	197	5
1835	733	4
1836	470	5
1837	983	5
1838	879	1
1839	652	2
1840	619	3
1841	324	5
1842	575	5
1843	888	2
1844	741	5
1845	775	4
1846	313	1
1847	383	4
1848	154	1
1849	298	3
1850	215	5
1851	915	5
1852	252	3
1853	801	3
1854	964	3
1855	585	1
1856	609	3
1857	280	2
1858	263	4
1859	786	4
1860	144	2
1861	155	5
1862	760	4
1863	472	5
1864	391	1
1865	314	1
1866	545	2
1867	357	2
1868	442	1
1869	731	2
1870	924	5
1871	876	5
1872	564	3
1873	144	4
1874	206	5
1875	858	1
1876	153	1
1877	650	5
1878	280	2
1879	261	5
1880	904	4
1881	129	5
1882	596	1
1883	627	3
1884	218	3
1885	172	5
1886	340	1
1887	838	1
1888	555	5
1889	706	5
1890	693	2
1891	433	1
1892	529	4
1893	303	4
1894	865	5
1895	793	1
1896	433	3
1897	335	3
1898	897	2
1899	212	5
1900	433	4
1901	333	4
1902	200	5
1903	342	2
1904	855	2
1905	522	3
1906	990	1
1907	304	3
1908	484	5
1909	325	5
1910	175	1
1911	582	4
1912	699	1
1913	596	3
1914	155	2
1915	546	2
1916	248	4
1917	321	1
1918	724	1
1919	565	1
1920	282	5
1921	496	2
1922	482	5
1923	239	1
1924	568	1
1925	837	2
1926	298	5
1927	747	2
1928	467	5
1929	376	4
1930	307	3
1931	443	2
1932	230	3
1933	132	3
1934	808	1
1935	682	2
1936	161	4
1937	387	1
1938	239	5
1939	213	1
1940	972	5
1941	576	3
1942	569	5
1943	528	1
1944	275	5
1945	878	1
1946	451	1
1947	325	3
1948	402	3
1949	718	1
1950	260	2
1951	908	3
1952	913	2
1953	753	4
1954	726	2
1955	274	4
1956	691	1
1957	666	3
1958	975	5
1959	335	4
1960	188	2
1961	521	4
1962	977	4
1963	634	2
1964	600	4
1965	982	1
1966	321	2
1967	705	3
1968	584	5
1969	957	5
1970	573	4
1971	385	5
1972	114	2
1973	847	2
1974	538	3
1975	853	2
1976	993	5
1977	352	1
1978	353	1
1979	435	3
1980	544	5
1981	693	3
1982	327	4
1983	705	1
1984	252	3
1985	687	3
1986	105	4
1987	527	2
1988	145	1
1989	141	3
1990	581	4
1991	851	4
1992	887	2
1993	616	5
1994	134	4
1995	535	5
1996	643	2
1997	503	3
1998	590	3
1999	929	1
2000	917	1
2001	813	4
2002	941	3
2003	200	2
2004	563	4
2005	607	5
2006	346	1
2007	185	2
2008	671	5
2009	871	2
2010	112	4
2011	809	4
2012	849	2
2013	516	4
2014	323	1
2015	235	2
2016	467	5
2017	402	5
2018	344	4
2019	763	4
2020	192	4
2021	116	1
2022	591	3
2023	785	2
2024	412	3
2025	265	2
2026	820	5
2027	570	1
2028	978	4
2029	684	3
2030	865	3
2031	697	1
2032	124	4
2033	565	1
2034	574	1
2035	890	1
2036	241	5
2037	995	4
2038	820	3
2039	515	2
2040	289	3
2041	908	5
2042	992	3
2043	479	4
2044	741	3
2045	575	1
2046	820	3
2047	748	1
2048	101	1
2049	981	2
2050	742	5
2051	172	5
2052	494	1
2053	807	2
2054	440	4
2055	643	2
2056	133	1
2057	403	3
2058	536	2
2059	870	4
2060	376	4
2061	814	2
2062	727	4
2063	655	2
2064	689	5
2065	913	1
2066	312	3
2067	906	3
2068	801	3
2069	182	4
2070	735	1
2071	443	5
2072	853	5
2073	156	2
2074	627	5
2075	790	3
2076	472	2
2077	152	1
2078	213	5
2079	492	4
2080	474	5
2081	576	1
2082	733	4
2083	141	4
2084	474	4
2085	475	3
2086	279	5
2087	763	1
2088	672	5
2089	821	2
2090	168	2
2091	674	5
2092	826	5
2093	892	3
2094	309	5
2095	241	5
2096	442	4
2097	344	3
2098	652	3
2099	216	3
2100	764	1
2101	589	2
2102	855	3
2103	870	5
2104	694	4
2105	992	2
2106	819	4
2107	314	1
2108	871	4
2109	862	3
2110	879	2
2111	330	1
2112	428	4
2113	461	5
2114	373	5
2115	615	1
2116	796	1
2117	533	4
2118	383	3
2119	155	1
2120	164	2
2121	481	3
2122	453	2
2123	563	5
2124	597	5
2125	613	5
2126	639	1
2127	949	5
2128	225	4
2129	581	2
2130	826	5
2131	644	4
2132	794	4
2133	945	3
2134	645	5
2135	399	2
2136	562	2
2137	735	2
2138	476	4
2139	919	3
2140	789	4
2141	809	4
2142	928	1
2143	167	3
2144	292	1
2145	568	2
2146	189	1
2147	182	5
2148	500	1
2149	283	5
2150	395	1
2151	178	3
2152	211	2
2153	268	5
2154	382	4
2155	214	1
2156	813	2
2157	251	5
2158	608	2
2159	254	4
2160	995	2
2161	309	3
2162	633	3
2163	742	2
2164	123	1
2165	400	3
2166	526	1
2167	798	2
2168	654	2
2169	235	1
2170	585	5
2171	455	1
2172	530	3
2173	554	4
2174	855	4
2175	760	2
2176	121	1
2177	398	3
2178	293	3
2179	164	1
2180	122	1
2181	992	1
2182	921	4
2183	337	5
2184	954	3
2185	632	1
2186	760	5
2187	443	2
2188	521	2
2189	692	3
2190	451	3
2191	771	2
2192	761	5
2193	905	1
2194	434	1
2195	597	5
2196	707	4
2197	781	5
2198	813	3
2199	642	1
2200	962	2
2201	661	2
2202	555	3
2203	568	5
2204	411	4
2205	680	1
2206	235	5
2207	908	5
2208	413	4
2209	275	2
2210	908	4
2211	366	3
2212	332	5
2213	595	4
2214	480	2
2215	395	2
2216	888	2
2217	965	3
2218	148	1
2219	251	4
2220	461	3
2221	391	2
2222	566	2
2223	270	3
2224	733	1
2225	264	3
2226	828	2
2227	648	2
2228	392	4
2229	286	1
2230	279	1
2231	959	5
2232	825	5
2233	809	1
2234	782	1
2235	913	2
2236	257	3
2237	265	4
2238	343	5
2239	219	4
2240	142	1
2241	424	4
2242	688	2
2243	229	1
2244	551	4
2245	366	1
2246	478	2
2247	288	5
2248	310	4
2249	675	4
2250	824	2
2251	135	1
2252	781	2
2253	424	1
2254	452	1
2255	251	5
2256	481	3
2257	559	2
2258	652	4
2259	266	4
2260	646	2
2261	408	1
2262	224	5
2263	125	3
2264	514	2
2265	611	4
2266	886	5
2267	248	5
2268	569	1
2269	427	1
2270	259	3
2271	104	4
2272	856	4
2273	659	5
2274	619	3
2275	439	1
2276	762	1
2277	822	1
2278	402	4
2279	585	2
2280	396	2
2281	872	3
2282	687	5
2283	782	1
2284	250	1
2285	918	4
2286	678	2
2287	846	5
2288	552	4
2289	446	1
2290	805	2
2291	215	1
2292	849	4
2293	590	2
2294	141	2
2295	242	1
2296	794	1
2297	664	2
2298	219	5
2299	415	4
2300	125	5
2301	511	1
2302	732	5
2303	961	4
2304	325	1
2305	556	4
2306	465	4
2307	194	2
2308	434	2
2309	156	1
2310	722	1
2311	756	3
2312	299	3
2313	697	3
2314	639	4
2315	327	1
2316	900	4
2317	885	1
2318	384	5
2319	300	2
2320	123	5
2321	185	1
2322	651	4
2323	969	1
2324	556	4
2325	793	3
2326	787	3
2327	189	2
2328	624	4
2329	503	1
2330	299	2
2331	602	2
2332	425	3
2333	717	3
2334	719	2
2335	623	2
2336	157	3
2337	782	2
2338	469	1
2339	507	4
2340	251	1
2341	833	2
2342	974	3
2343	537	2
2344	478	2
2345	495	5
2346	481	3
2347	112	1
2348	391	2
2349	453	1
2350	459	5
2351	415	3
2352	556	3
2353	995	4
2354	674	4
2355	189	2
2356	320	4
2357	845	5
2358	554	1
2359	859	2
2360	525	2
2361	922	4
2362	553	3
2363	395	3
2364	267	1
2365	925	2
2366	845	2
2367	534	4
2368	846	4
2369	524	1
2370	242	4
2371	955	5
2372	701	3
2373	712	5
2374	188	1
2375	247	2
2376	312	3
2377	410	3
2378	586	3
2379	988	5
2380	637	5
2381	443	3
2382	167	1
2383	704	4
2384	874	1
2385	484	2
2386	190	1
2387	106	1
2388	519	5
2389	754	1
2390	379	3
2391	524	5
2392	279	5
2393	669	1
2394	573	2
2395	827	4
2396	681	5
2397	873	4
2398	240	3
2399	304	5
2400	290	5
2401	952	4
2402	490	3
2403	396	4
2404	667	5
2405	602	4
2406	143	5
2407	942	4
2408	946	2
2409	409	2
2410	954	4
2411	699	4
2412	411	1
2413	605	1
2414	672	5
2415	857	5
2416	574	3
2417	329	3
2418	127	4
2419	910	3
2420	102	1
2421	257	5
2422	368	2
2423	407	4
2424	755	5
2425	954	1
2426	751	5
2427	583	1
2428	227	5
2429	769	1
2430	781	4
2431	394	3
2432	527	5
2433	283	5
2434	603	2
2435	804	1
2436	760	4
2437	350	3
2438	129	1
2439	222	1
2440	883	4
2441	383	5
2442	604	5
2443	168	2
2444	713	4
2445	863	5
2446	470	2
2447	695	2
2448	592	3
2449	679	2
2450	546	3
2451	989	5
2452	364	3
2453	743	5
2454	802	4
2455	587	3
2456	810	4
2457	937	1
2458	222	5
2459	482	2
2460	624	1
2461	850	2
2462	689	5
2463	117	5
2464	965	4
2465	365	3
2466	266	3
2467	695	4
2468	159	2
2469	249	2
2470	427	1
2471	572	2
2472	999	1
2473	809	2
2474	238	2
2475	465	4
2476	267	2
2477	154	1
2478	379	3
2479	469	3
2480	529	1
2481	751	2
2482	464	2
2483	149	1
2484	396	1
2485	398	1
2486	642	1
2487	754	5
2488	178	5
2489	626	4
2490	298	2
2491	884	3
2492	743	4
2493	287	4
2494	883	2
2495	196	5
2496	713	1
2497	870	5
2498	271	1
2499	656	1
2500	430	5
2501	993	5
2502	423	5
2503	946	5
2504	965	1
2505	801	1
2506	919	3
2507	408	1
2508	377	4
2509	801	1
2510	814	1
2511	804	5
2512	471	1
2513	198	4
2514	647	5
2515	693	2
2516	460	2
2517	943	2
2518	247	4
2519	113	2
2520	240	4
2521	630	5
2522	388	5
2523	481	5
2524	897	4
2525	596	5
2526	521	1
2527	448	4
2528	266	1
2529	204	5
2530	323	3
2531	258	3
2532	615	5
2533	326	1
2534	951	5
2535	292	4
2536	914	4
2537	672	3
2538	728	4
2539	806	2
2540	951	1
2541	638	1
2542	966	1
2543	644	5
2544	829	5
2545	664	5
2546	819	3
2547	874	2
2548	921	2
2549	216	4
2550	527	1
2551	571	1
2552	178	2
2553	219	4
2554	938	1
2555	234	1
2556	117	5
2557	591	1
2558	456	3
2559	419	1
2560	807	5
2561	471	5
2562	242	3
2563	936	3
2564	552	3
2565	711	5
2566	635	2
2567	881	5
2568	450	3
2569	276	2
2570	826	1
2571	411	2
2572	129	3
2573	862	1
2574	934	1
2575	221	3
2576	327	2
2577	231	3
2578	977	2
2579	810	3
2580	245	4
2581	804	4
2582	332	1
2583	414	4
2584	228	3
2585	314	4
2586	233	5
2587	180	5
2588	535	5
2589	807	3
2590	881	3
2591	902	5
2592	214	3
2593	179	4
2594	119	4
2595	893	4
2596	595	2
2597	875	1
2598	541	1
2599	143	1
2600	301	5
2601	210	2
2602	133	3
2603	912	1
2604	775	2
2605	625	5
2606	707	1
2607	160	5
2608	580	2
2609	221	2
2610	359	2
2611	144	5
2612	167	4
2613	408	5
2614	783	3
2615	110	1
2616	872	2
2617	198	4
2618	901	2
2619	226	1
2620	716	5
2621	310	3
2622	701	5
2623	304	1
2624	289	4
2625	786	3
2626	459	3
2627	129	2
2628	192	4
2629	249	2
2630	966	3
2631	864	2
2632	384	4
2633	693	3
2634	456	2
2635	460	2
2636	264	3
2637	975	4
2638	612	1
2639	899	1
2640	846	3
2641	727	1
2642	347	2
2643	617	5
2644	683	1
2645	169	5
2646	201	2
2647	939	5
2648	692	3
2649	881	1
2650	114	5
2651	641	1
2652	322	4
2653	832	1
2654	296	2
2655	388	3
2656	275	3
2657	872	5
2658	650	1
2659	104	3
2660	842	4
2661	201	1
2662	319	1
2663	616	1
2664	971	4
2665	824	5
2666	586	2
2667	475	2
2668	814	1
2669	703	3
2670	289	4
2671	550	4
2672	789	1
2673	209	1
2674	285	1
2675	954	2
2676	463	5
2677	488	2
2678	534	5
2679	319	2
2680	626	4
2681	333	1
2682	517	1
2683	215	1
2684	879	2
2685	421	2
2686	226	2
2687	577	5
2688	212	4
2689	632	1
2690	239	3
2691	607	1
2692	880	2
2693	469	1
2694	821	3
2695	395	5
2696	670	3
2697	839	1
2698	141	4
2699	184	4
2700	435	4
2701	605	3
2702	218	2
2703	494	3
2704	390	3
2705	567	4
2706	714	1
2707	853	3
2708	419	2
2709	803	2
2710	961	4
2711	554	4
2712	331	2
2713	667	3
2714	517	4
2715	397	1
2716	975	1
2717	538	5
2718	293	1
2719	977	3
2720	171	2
2721	961	1
2722	921	3
2723	587	4
2724	795	2
2725	476	3
2726	283	4
2727	113	2
2728	790	3
2729	603	2
2730	788	3
2731	207	5
2732	505	4
2733	548	1
2734	635	4
2735	774	4
2736	792	5
2737	187	2
2738	222	2
2739	246	3
2740	504	1
2741	510	2
2742	811	4
2743	704	2
2744	204	4
2745	859	4
2746	272	1
2747	166	5
2748	472	4
2749	303	4
2750	446	4
2751	305	3
2752	709	4
2753	964	2
2754	513	2
2755	225	3
2756	338	1
2757	958	5
2758	534	4
2759	842	4
2760	611	5
2761	385	4
2762	883	5
2763	830	3
2764	884	5
2765	695	3
2766	707	4
2767	379	4
2768	874	1
2769	908	2
2770	920	5
2771	759	1
2772	509	2
2773	464	3
2774	587	1
2775	782	1
2776	717	4
2777	514	1
2778	596	5
2779	623	3
2780	385	5
2781	250	5
2782	886	4
2783	565	3
2784	210	2
2785	225	2
2786	356	2
2787	601	3
2788	609	3
2789	336	2
2790	743	3
2791	237	1
2792	130	3
2793	201	4
2794	855	4
2795	154	5
2796	950	2
2797	169	1
2798	610	2
2799	794	1
2800	127	3
2801	283	4
2802	491	3
2803	719	5
2804	795	3
2805	434	2
2806	256	3
2807	410	3
2808	736	5
2809	738	2
2810	198	1
2811	878	4
2812	178	3
2813	776	3
2814	869	1
2815	632	1
2816	885	1
2817	604	5
2818	911	4
2819	577	2
2820	306	5
2821	400	5
2822	777	1
2823	609	5
2824	602	2
2825	616	4
2826	367	2
2827	655	1
2828	451	4
2829	928	2
2830	980	3
2831	653	2
2832	659	3
2833	118	5
2834	882	3
2835	132	5
2836	540	5
2837	221	2
2838	492	1
2839	560	5
2840	422	5
2841	973	3
2842	485	5
2843	553	4
2844	570	5
2845	136	1
2846	133	4
2847	281	4
2848	670	3
2849	775	1
2850	981	3
2851	898	1
2852	410	1
2853	823	1
2854	268	2
2855	603	1
2856	541	2
2857	237	3
2858	419	3
2859	832	2
2860	498	3
2861	599	1
2862	882	2
2863	212	2
2864	682	1
2865	791	1
2866	602	4
2867	775	1
2868	667	3
2869	801	5
2870	652	5
2871	685	4
2872	581	1
2873	587	2
2874	675	4
2875	974	2
2876	260	1
2877	618	5
2878	157	4
2879	500	1
2880	369	1
2881	606	2
2882	705	2
2883	486	1
2884	731	2
2885	792	1
2886	461	5
2887	884	4
2888	391	5
2889	428	5
2890	162	5
2891	128	5
2892	704	1
2893	146	1
2894	231	1
2895	957	3
2896	475	1
2897	457	1
2898	928	2
2899	859	3
2900	697	4
2901	127	1
2902	883	2
2903	740	1
2904	449	4
2905	489	1
2906	199	5
2907	538	4
2908	453	5
2909	465	4
2910	521	1
2911	459	1
2912	157	4
2913	777	2
2914	350	3
2915	353	5
2916	340	1
2917	763	5
2918	419	3
2919	706	1
2920	186	5
2921	804	3
2922	167	4
2923	989	5
2924	412	3
2925	217	3
2926	445	1
2927	273	1
2928	120	1
2929	651	2
2930	433	4
2931	138	3
2932	571	2
2933	773	3
2934	984	5
2935	532	2
2936	681	1
2937	627	1
2938	531	4
2939	373	2
2940	120	5
2941	812	5
2942	580	4
2943	702	5
2944	122	1
2945	424	4
2946	486	2
2947	684	4
2948	499	5
2949	430	1
2950	686	2
2951	200	4
2952	927	1
2953	600	4
2954	202	1
2955	807	4
2956	791	1
2957	310	5
2958	444	5
2959	608	1
2960	614	5
2961	930	4
2962	883	2
2963	783	2
2964	447	2
2965	270	5
2966	729	5
2967	406	4
2968	472	3
2969	546	4
2970	306	4
2971	608	1
2972	750	5
2973	967	2
2974	906	4
2975	177	3
2976	960	2
2977	970	1
2978	648	4
2979	319	4
2980	394	5
2981	371	1
2982	148	1
2983	404	2
2984	687	3
2985	511	5
2986	923	1
2987	331	5
2988	739	3
2989	860	3
2990	194	4
2991	834	5
2992	964	1
2993	692	1
2994	197	2
2995	706	3
2996	444	3
2997	379	2
2998	168	2
2999	680	2
3000	920	4
3001	643	2
3002	586	2
3003	537	1
3004	314	4
3005	455	5
3006	914	1
3007	178	4
3008	767	5
3009	943	4
3010	409	5
3011	616	3
3012	923	4
3013	407	3
3014	543	4
3015	779	4
3016	652	1
3017	420	4
3018	304	4
3019	524	3
3020	511	1
3021	357	4
3022	739	5
3023	627	1
3024	564	2
3025	787	5
3026	881	3
3027	660	2
3028	284	1
3029	119	3
3030	742	1
3031	820	1
3032	628	4
3033	983	3
3034	291	2
3035	690	4
3036	611	1
3037	318	1
3038	776	4
3039	943	1
3040	860	2
3041	578	2
3042	374	3
3043	753	1
3044	645	5
3045	928	3
3046	729	2
3047	973	3
3048	887	2
3049	544	1
3050	679	5
3051	844	5
3052	741	2
3053	161	5
3054	634	2
3055	305	3
3056	473	5
3057	573	3
3058	251	5
3059	346	1
3060	254	2
3061	864	1
3062	801	1
3063	883	3
3064	407	1
3065	964	4
3066	545	5
3067	520	1
3068	426	1
3069	980	3
3070	950	2
3071	165	1
3072	749	2
3073	308	1
3074	966	3
3075	522	1
3076	373	4
3077	943	4
3078	393	3
3079	761	5
3080	264	4
3081	362	3
3082	803	4
3083	715	2
3084	341	2
3085	515	5
3086	344	3
3087	216	2
3088	253	3
3089	296	5
3090	128	1
3091	351	1
3092	916	1
3093	947	3
3094	417	1
3095	575	1
3096	597	3
3097	673	4
3098	546	4
3099	532	3
3100	762	2
3101	137	4
3102	306	5
3103	263	5
3104	379	4
3105	239	1
3106	129	3
3107	364	4
3108	908	2
3109	922	5
3110	384	3
3111	774	3
3112	663	1
3113	280	2
3114	759	5
3115	972	1
3116	143	4
3117	839	4
3118	597	3
3119	901	1
3120	120	2
3121	156	2
3122	980	5
3123	185	3
3124	421	5
3125	716	4
3126	405	5
3127	987	1
3128	165	3
3129	516	3
3130	472	3
3131	787	2
3132	773	4
3133	192	1
3134	506	5
3135	959	4
3136	841	2
3137	962	2
3138	243	4
3139	341	1
3140	214	2
3141	684	3
3142	852	3
3143	612	4
3144	223	3
3145	634	3
3146	780	4
3147	948	4
3148	694	4
3149	893	2
3150	637	1
3151	357	3
3152	608	1
3153	192	4
3154	343	1
3155	714	1
3156	225	4
3157	891	2
3158	926	1
3159	420	5
3160	437	4
3161	952	1
3162	698	3
3163	854	4
3164	499	3
3165	925	4
3166	866	5
3167	861	2
3168	341	4
3169	533	1
3170	323	2
3171	247	1
3172	209	4
3173	279	3
3174	319	3
3175	381	2
3176	550	5
3177	518	1
3178	360	2
3179	983	4
3180	703	3
3181	157	1
3182	602	3
3183	646	5
3184	483	3
3185	816	4
3186	215	2
3187	424	4
3188	658	1
3189	533	2
3190	586	5
3191	799	2
3192	352	3
3193	384	3
3194	903	4
3195	248	5
3196	471	4
3197	586	2
3198	832	4
3199	476	2
3200	941	5
3201	415	5
3202	121	3
3203	760	1
3204	720	4
3205	135	4
3206	961	4
3207	857	3
3208	778	2
3209	918	1
3210	155	4
3211	807	4
3212	907	2
3213	787	2
3214	345	4
3215	359	1
3216	665	2
3217	493	3
3218	416	2
3219	754	5
3220	817	4
3221	471	4
3222	931	4
3223	801	2
3224	224	3
3225	647	5
3226	987	2
3227	342	2
3228	978	5
3229	553	4
3230	497	5
3231	108	4
3232	502	5
3233	361	1
3234	408	4
3235	192	1
3236	942	3
3237	874	5
3238	341	5
3239	404	4
3240	315	5
3241	980	2
3242	264	2
3243	549	1
3244	746	3
3245	424	3
3246	931	2
3247	885	3
3248	759	1
3249	516	3
3250	908	1
3251	134	5
3252	380	5
3253	987	2
3254	182	4
3255	942	2
3256	898	5
3257	603	4
3258	582	1
3259	854	3
3260	522	5
3261	961	4
3262	440	4
3263	834	3
3264	532	1
3265	997	3
3266	939	2
3267	202	3
3268	944	4
3269	264	4
3270	815	1
3271	367	4
3272	618	5
3273	167	5
3274	460	4
3275	530	4
3276	716	3
3277	846	3
3278	932	3
3279	660	2
3280	855	4
3281	434	1
3282	564	5
3283	811	1
3284	128	2
3285	880	5
3286	153	3
3287	756	2
3288	756	2
3289	288	4
3290	745	2
3291	554	4
3292	910	2
3293	756	4
3294	239	2
3295	103	2
3296	510	1
3297	304	2
3298	743	2
3299	412	2
3300	421	4
3301	689	1
3302	184	1
3303	213	1
3304	261	4
3305	355	3
3306	628	4
3307	830	4
3308	886	5
3309	950	1
3310	764	4
3311	881	1
3312	233	4
3313	967	2
3314	708	1
3315	802	3
3316	520	2
3317	911	5
3318	427	5
3319	562	3
3320	589	1
3321	994	3
3322	852	3
3323	236	5
3324	366	4
3325	277	5
3326	803	5
3327	707	2
3328	946	1
3329	435	3
3330	918	2
3331	388	1
3332	303	4
3333	186	5
3334	524	1
3335	476	2
3336	286	5
3337	502	2
3338	997	2
3339	486	1
3340	954	2
3341	684	4
3342	329	5
3343	121	5
3344	123	1
3345	671	1
3346	762	3
3347	726	2
3348	741	4
3349	334	3
3350	191	4
3351	573	1
3352	303	1
3353	368	4
3354	818	5
3355	972	1
3356	272	1
3357	150	4
3358	510	4
3359	732	1
3360	539	2
3361	714	1
3362	366	4
3363	252	2
3364	191	4
3365	476	1
3366	274	3
3367	680	1
3368	220	1
3369	114	3
3370	835	5
3371	638	2
3372	545	2
3373	891	2
3374	564	4
3375	947	4
3376	789	2
3377	606	3
3378	221	3
3379	329	4
3380	830	5
3381	308	2
3382	295	1
3383	982	4
3384	932	2
3385	900	5
3386	372	3
3387	394	4
3388	864	4
3389	606	2
3390	491	5
3391	233	1
3392	541	5
3393	976	2
3394	311	5
3395	714	1
3396	320	4
3397	943	3
3398	389	3
3399	844	1
3400	793	2
3401	293	3
3402	528	5
3403	284	5
3404	518	5
3405	911	3
3406	249	1
3407	129	5
3408	397	2
3409	368	5
3410	341	2
3411	732	2
3412	561	4
3413	354	2
3414	478	4
3415	696	2
3416	800	5
3417	762	1
3418	569	2
3419	187	5
3420	110	1
3421	580	4
3422	236	2
3423	992	3
3424	431	1
3425	809	3
3426	507	5
3427	803	4
3428	317	1
3429	830	2
3430	492	4
3431	825	4
3432	533	4
3433	853	4
3434	711	3
3435	362	2
3436	174	4
3437	197	2
3438	670	5
3439	160	3
3440	153	3
3441	440	2
3442	340	5
3443	582	4
3444	462	3
3445	720	5
3446	786	5
3447	921	3
3448	712	1
3449	826	4
3450	866	1
3451	929	5
3452	146	5
3453	105	4
3454	359	3
3455	616	1
3456	734	4
3457	490	4
3458	409	3
3459	504	4
3460	787	1
3461	479	2
3462	235	1
3463	672	5
3464	142	1
3465	694	1
3466	283	5
3467	366	2
3468	273	5
3469	615	1
3470	604	2
3471	447	2
3472	998	1
3473	579	3
3474	235	3
3475	191	2
3476	424	5
3477	827	1
3478	643	3
3479	543	3
3480	245	5
3481	366	5
3482	219	1
3483	420	5
3484	145	2
3485	230	2
3486	611	2
3487	992	3
3488	954	2
3489	387	2
3490	865	2
3491	469	2
3492	540	1
3493	389	2
3494	997	2
3495	369	3
3496	727	1
3497	949	1
3498	879	2
3499	370	3
3500	629	3
3501	420	3
3502	546	1
3503	268	1
3504	423	5
3505	854	2
3506	603	3
3507	882	3
3508	254	3
3509	669	1
3510	973	2
3511	773	4
3512	751	5
3513	917	5
3514	550	5
3515	154	5
3516	293	3
3517	252	2
3518	155	5
3519	335	2
3520	287	2
3521	136	2
3522	581	2
3523	366	3
3524	267	2
3525	822	4
3526	578	2
3527	546	5
3528	218	4
3529	606	2
3530	141	1
3531	552	5
3532	465	1
3533	826	3
3534	674	5
3535	596	5
3536	568	2
3537	604	1
3538	215	2
3539	966	3
3540	837	3
3541	987	1
3542	251	2
3543	226	5
3544	457	1
3545	195	4
3546	308	3
3547	989	5
3548	390	4
3549	284	3
3550	954	5
3551	272	5
3552	867	5
3553	620	2
3554	942	1
3555	379	1
3556	676	2
3557	779	2
3558	699	4
3559	317	4
3560	697	2
3561	104	1
3562	638	4
3563	885	4
3564	684	3
3565	284	5
3566	526	3
3567	178	3
3568	352	2
3569	886	1
3570	610	1
3571	793	4
3572	196	2
3573	436	5
3574	126	3
3575	391	1
3576	797	5
3577	796	2
3578	224	4
3579	503	3
3580	482	5
3581	704	1
3582	208	5
3583	957	2
3584	431	2
3585	257	4
3586	129	4
3587	183	1
3588	571	2
3589	950	1
3590	824	4
3591	775	3
3592	591	2
3593	564	4
3594	743	2
3595	375	4
3596	708	3
3597	773	4
3598	105	3
3599	437	2
3600	144	5
3601	771	4
3602	737	3
3603	563	4
3604	432	1
3605	849	2
3606	851	1
3607	916	5
3608	682	4
3609	232	1
3610	316	4
3611	983	2
3612	149	1
3613	920	1
3614	759	5
3615	389	5
3616	430	2
3617	917	5
3618	156	3
3619	861	3
3620	172	2
3621	660	3
3622	716	1
3623	490	2
3624	194	2
3625	508	1
3626	361	1
3627	282	3
3628	345	2
3629	889	3
3630	986	3
3631	508	1
3632	191	3
3633	121	1
3634	972	3
3635	313	2
3636	266	2
3637	497	1
3638	898	5
3639	512	1
3640	391	3
3641	762	2
3642	870	1
3643	769	5
3644	257	4
3645	223	4
3646	405	5
3647	602	4
3648	920	2
3649	542	3
3650	853	4
3651	925	5
3652	417	2
3653	801	3
3654	717	3
3655	234	2
3656	467	2
3657	781	1
3658	198	5
3659	952	5
3660	476	2
3661	624	3
3662	304	3
3663	601	5
3664	556	1
3665	497	5
3666	587	2
3667	374	1
3668	676	3
3669	714	5
3670	533	4
3671	192	4
3672	874	1
3673	532	4
3674	930	4
3675	477	4
3676	728	5
3677	290	2
3678	544	2
3679	745	2
3680	536	2
3681	195	5
3682	141	5
3683	625	5
3684	449	4
3685	574	3
3686	792	1
3687	329	3
3688	763	5
3689	802	1
3690	830	2
3691	258	3
3692	607	4
3693	639	5
3694	744	3
3695	762	4
3696	637	3
3697	185	1
3698	397	5
3699	579	3
3700	547	5
3701	181	3
3702	920	5
3703	589	5
3704	407	2
3705	252	5
3706	230	2
3707	800	3
3708	407	4
3709	961	4
3710	354	2
3711	635	4
3712	537	2
3713	402	1
3714	682	5
3715	148	3
3716	664	4
3717	178	4
3718	146	2
3719	625	5
3720	210	2
3721	622	3
3722	535	3
3723	522	2
3724	196	3
3725	575	3
3726	776	1
3727	837	5
3728	682	4
3729	932	2
3730	359	5
3731	463	2
3732	360	2
3733	699	2
3734	183	3
3735	887	1
3736	615	1
3737	116	5
3738	216	2
3739	858	3
3740	777	4
3741	573	2
3742	283	3
3743	905	4
3744	286	2
3745	963	5
3746	502	4
3747	146	2
3748	185	5
3749	526	3
3750	997	2
3751	821	1
3752	404	1
3753	421	2
3754	701	2
3755	841	2
3756	565	3
3757	875	1
3758	786	3
3759	560	5
3760	738	5
3761	927	2
3762	371	5
3763	449	1
3764	992	1
3765	929	5
3766	291	4
3767	316	4
3768	289	2
3769	180	4
3770	864	1
3771	718	2
3772	365	4
3773	992	4
3774	789	1
3775	208	3
3776	544	3
3777	647	1
3778	118	5
3779	105	3
3780	504	4
3781	219	2
3782	113	2
3783	275	1
3784	771	4
3785	588	3
3786	571	1
3787	808	1
3788	514	2
3789	989	5
3790	773	1
3791	862	1
3792	716	1
3793	843	5
3794	598	2
3795	410	2
3796	733	3
3797	932	2
3798	731	5
3799	469	5
3800	807	2
3801	789	2
3802	806	2
3803	791	3
3804	504	4
3805	923	1
3806	409	1
3807	189	5
3808	228	2
3809	238	4
3810	114	1
3811	295	1
3812	214	4
3813	935	1
3814	116	5
3815	812	2
3816	292	4
3817	979	4
3818	127	1
3819	314	3
3820	592	4
3821	764	3
3822	248	4
3823	765	1
3824	347	4
3825	546	1
3826	962	4
3827	741	4
3828	978	2
3829	908	4
3830	651	3
3831	295	2
3832	188	5
3833	408	3
3834	888	1
3835	574	1
3836	251	5
3837	585	3
3838	532	2
3839	122	4
3840	219	2
3841	270	2
3842	256	3
3843	856	4
3844	819	1
3845	555	4
3846	596	4
3847	582	2
3848	120	2
3849	980	1
3850	560	2
3851	699	2
3852	348	4
3853	306	1
3854	401	1
3855	683	5
3856	949	3
3857	953	3
3858	501	1
3859	152	4
3860	441	3
3861	108	2
3862	205	2
3863	745	1
3864	967	4
3865	830	3
3866	542	3
3867	525	3
3868	968	1
3869	607	2
3870	854	4
3871	692	2
3872	710	4
3873	848	4
3874	667	4
3875	397	5
3876	137	3
3877	599	4
3878	509	4
3879	597	1
3880	625	4
3881	705	2
3882	842	3
3883	726	5
3884	794	3
3885	936	2
3886	988	5
3887	599	1
3888	337	3
3889	831	4
3890	162	1
3891	640	4
3892	119	3
3893	532	3
3894	690	1
3895	423	5
3896	666	5
3897	165	4
3898	374	1
3899	763	1
3900	527	4
3901	584	5
3902	219	5
3903	606	5
3904	737	2
3905	761	2
3906	455	3
3907	559	2
3908	814	1
3909	546	2
3910	121	3
3911	265	5
3912	394	2
3913	843	4
3914	296	3
3915	580	3
3916	452	3
3917	548	1
3918	337	4
3919	619	2
3920	324	2
3921	701	3
3922	801	3
3923	447	4
3924	716	3
3925	973	2
3926	962	5
3927	832	4
3928	772	5
3929	579	3
3930	234	4
3931	400	5
3932	840	1
3933	828	2
3934	499	3
3935	526	3
3936	953	5
3937	789	3
3938	768	2
3939	852	4
3940	468	2
3941	915	4
3942	583	5
3943	918	5
3944	964	1
3945	265	3
3946	736	4
3947	312	2
3948	389	2
3949	807	5
3950	867	4
3951	188	3
3952	783	1
3953	594	1
3954	232	1
3955	277	5
3956	304	3
3957	260	2
3958	720	5
3959	603	3
3960	203	3
3961	912	4
3962	525	3
3963	605	2
3964	410	1
3965	340	4
3966	314	3
3967	670	2
3968	148	3
3969	118	5
3970	467	5
3971	367	1
3972	465	1
3973	793	5
3974	262	2
3975	278	4
3976	947	5
3977	980	1
3978	615	3
3979	132	4
3980	926	1
3981	165	3
3982	445	4
3983	540	4
3984	216	1
3985	732	3
3986	332	2
3987	223	4
3988	675	5
3989	329	5
3990	598	3
3991	364	3
3992	448	2
3993	903	4
3994	463	1
3995	887	4
3996	147	4
3997	888	1
3998	998	5
3999	670	4
4000	373	3
4001	254	4
4002	973	3
4003	806	4
4004	994	4
4005	627	2
4006	718	4
4007	785	2
4008	206	4
4009	823	5
4010	151	1
4011	548	3
4012	918	3
4013	568	1
4014	961	5
4015	873	3
4016	213	5
4017	208	5
4018	900	5
4019	725	1
4020	724	1
4021	900	2
4022	978	4
4023	204	4
4024	943	2
4025	675	5
4026	142	1
4027	619	1
4028	207	5
4029	271	3
4030	745	3
4031	220	1
4032	991	4
4033	310	5
4034	470	4
4035	260	1
4036	845	3
4037	399	2
4038	825	3
4039	552	4
4040	880	4
4041	618	1
4042	610	3
4043	850	1
4044	991	2
4045	201	2
4046	257	4
4047	762	3
4048	472	4
4049	442	5
4050	938	5
4051	241	2
4052	225	2
4053	968	1
4054	306	4
4055	549	4
4056	525	4
4057	887	2
4058	887	1
4059	106	4
4060	351	4
4061	954	1
4062	928	5
4063	585	2
4064	449	2
4065	393	2
4066	617	4
4067	275	4
4068	187	4
4069	372	5
4070	481	3
4071	832	1
4072	872	5
4073	524	1
4074	469	5
4075	744	4
4076	780	5
4077	351	5
4078	255	4
4079	871	3
4080	871	2
4081	642	5
4082	531	3
4083	906	5
4084	333	1
4085	241	4
4086	921	4
4087	539	2
4088	523	5
4089	519	4
4090	569	2
4091	972	3
4092	628	2
4093	913	5
4094	798	5
4095	470	5
4096	130	4
4097	553	4
4098	249	1
4099	888	3
4100	110	3
4101	834	1
4102	925	3
4103	629	5
4104	171	2
4105	186	2
4106	446	1
4107	422	4
4108	511	1
4109	890	3
4110	268	5
4111	544	4
4112	162	1
4113	502	5
4114	877	4
4115	137	4
4116	776	1
4117	756	4
4118	254	4
4119	688	2
4120	159	2
4121	746	1
4122	830	1
4123	918	4
4124	776	2
4125	996	5
4126	632	1
4127	402	4
4128	529	2
4129	511	5
4130	797	5
4131	817	2
4132	666	5
4133	994	5
4134	411	1
4135	838	5
4136	860	5
4137	421	2
4138	452	4
4139	108	1
4140	946	5
4141	386	2
4142	640	4
4143	725	3
4144	250	2
4145	817	2
4146	513	4
4147	556	1
4148	759	4
4149	310	1
4150	657	5
4151	739	4
4152	907	3
4153	733	5
4154	767	3
4155	552	2
4156	814	4
4157	453	5
4158	931	3
4159	900	2
4160	764	1
4161	514	2
4162	894	5
4163	302	5
4164	408	2
4165	186	1
4166	137	2
4167	650	3
4168	442	3
4169	499	5
4170	842	1
4171	836	1
4172	857	3
4173	229	3
4174	632	5
4175	653	5
4176	390	4
4177	318	4
4178	195	1
4179	623	4
4180	665	5
4181	419	2
4182	633	1
4183	448	5
4184	875	3
4185	750	5
4186	263	4
4187	123	2
4188	128	1
4189	915	3
4190	652	3
4191	706	5
4192	364	5
4193	347	2
4194	952	3
4195	892	2
4196	411	5
4197	843	5
4198	532	3
4199	617	2
4200	213	1
4201	849	2
4202	161	1
4203	961	4
4204	481	5
4205	365	1
4206	742	4
4207	619	4
4208	462	5
4209	226	1
4210	148	4
4211	874	4
4212	766	3
4213	227	2
4214	559	1
4215	405	3
4216	686	5
4217	854	5
4218	105	1
4219	564	1
4220	447	4
4221	341	3
4222	924	5
4223	863	2
4224	695	5
4225	679	1
4226	831	3
4227	742	1
4228	781	2
4229	646	4
4230	964	1
4231	709	1
4232	339	4
4233	458	1
4234	406	5
4235	391	2
4236	782	4
4237	903	3
4238	934	1
4239	832	4
4240	686	1
4241	788	2
4242	243	1
4243	831	5
4244	486	5
4245	632	1
4246	855	5
4247	353	1
4248	207	4
4249	435	2
4250	628	4
4251	696	2
4252	297	5
4253	942	2
4254	897	5
4255	469	4
4256	565	5
4257	200	2
4258	250	3
4259	828	3
4260	535	5
4261	948	3
4262	521	1
4263	183	1
4264	194	4
4265	163	2
4266	535	5
4267	233	5
4268	587	5
4269	319	3
4270	556	5
4271	179	2
4272	478	4
4273	793	3
4274	638	1
4275	512	1
4276	702	4
4277	672	5
4278	631	1
4279	897	4
4280	504	5
4281	992	1
4282	370	5
4283	698	4
4284	610	1
4285	751	2
4286	533	4
4287	550	4
4288	805	4
4289	601	2
4290	849	1
4291	526	5
4292	943	1
4293	266	5
4294	247	2
4295	617	1
4296	230	2
4297	596	5
4298	828	1
4299	568	4
4300	232	1
4301	821	2
4302	625	4
4303	983	2
4304	641	3
4305	220	3
4306	811	3
4307	317	2
4308	566	3
4309	584	5
4310	133	4
4311	864	2
4312	260	3
4313	672	3
4314	478	5
4315	221	4
4316	716	1
4317	972	1
4318	518	2
4319	212	1
4320	223	3
4321	478	2
4322	685	3
4323	396	2
4324	141	3
4325	635	2
4326	256	4
4327	220	5
4328	480	1
4329	412	5
4330	483	1
4331	410	2
4332	401	2
4333	597	4
4334	128	3
4335	910	2
4336	246	1
4337	245	2
4338	902	5
4339	703	3
4340	531	5
4341	149	4
4342	412	4
4343	390	1
4344	320	2
4345	287	5
4346	938	4
4347	857	4
4348	600	1
4349	102	2
4350	225	3
4351	660	2
4352	457	4
4353	169	3
4354	991	2
4355	145	3
4356	527	1
4357	592	3
4358	686	3
4359	417	2
4360	679	4
4361	563	3
4362	445	5
4363	900	1
4364	486	5
4365	586	4
4366	954	3
4367	837	3
4368	953	1
4369	720	2
4370	235	4
4371	880	3
4372	241	5
4373	616	5
4374	751	2
4375	571	1
4376	879	3
4377	560	5
4378	783	4
4379	559	4
4380	252	2
4381	987	5
4382	845	3
4383	433	3
4384	191	4
4385	919	4
4386	739	2
4387	780	2
4388	738	2
4389	519	2
4390	496	4
4391	338	1
4392	504	4
4393	447	4
4394	653	4
4395	146	5
4396	786	5
4397	553	5
4398	853	4
4399	384	3
4400	761	5
4401	190	1
4402	986	2
4403	269	3
4404	824	5
4405	125	3
4406	685	5
4407	745	4
4408	915	2
4409	890	2
4410	824	1
4411	416	3
4412	674	2
4413	760	5
4414	226	5
4415	759	4
4416	672	2
4417	187	2
4418	297	4
4419	733	5
4420	654	5
4421	690	2
4422	875	1
4423	154	4
4424	683	4
4425	634	4
4426	293	1
4427	868	4
4428	587	5
4429	614	5
4430	119	4
4431	223	2
4432	774	2
4433	644	3
4434	284	4
4435	119	5
4436	381	5
4437	905	5
4438	310	2
4439	351	5
4440	949	5
4441	822	5
4442	959	2
4443	693	2
4444	554	3
4445	186	5
4446	926	4
4447	646	4
4448	721	5
4449	428	5
4450	511	4
4451	703	4
4452	146	4
4453	603	5
4454	982	2
4455	123	3
4456	448	4
4457	547	1
4458	284	3
4459	524	1
4460	124	2
4461	980	3
4462	640	5
4463	424	2
4464	491	1
4465	363	5
4466	193	3
4467	217	5
4468	201	2
4469	654	1
4470	272	3
4471	392	2
4472	247	5
4473	287	5
4474	361	2
4475	886	5
4476	191	1
4477	257	2
4478	414	2
4479	517	4
4480	794	1
4481	273	1
4482	160	1
4483	729	1
4484	433	3
4485	285	3
4486	127	1
4487	830	4
4488	159	4
4489	405	2
4490	499	5
4491	201	1
4492	427	3
4493	245	2
4494	522	1
4495	431	3
4496	364	5
4497	484	1
4498	947	2
4499	223	3
4500	153	1
4501	307	1
4502	345	2
4503	870	5
4504	711	5
4505	700	4
4506	342	3
4507	604	2
4508	620	5
4509	870	4
4510	616	2
4511	494	1
4512	217	5
4513	375	5
4514	162	5
4515	425	4
4516	575	3
4517	666	4
4518	516	3
4519	167	2
4520	595	2
4521	129	3
4522	517	1
4523	748	3
4524	339	5
4525	119	2
4526	375	1
4527	667	5
4528	700	2
4529	791	2
4530	203	3
4531	352	2
4532	881	1
4533	668	5
4534	767	4
4535	904	4
4536	228	4
4537	411	5
4538	681	1
4539	516	5
4540	556	3
4541	185	5
4542	966	5
4543	751	4
4544	612	2
4545	308	5
4546	901	5
4547	245	1
4548	482	3
4549	653	4
4550	272	5
4551	900	2
4552	351	1
4553	650	1
4554	533	4
4555	668	3
4556	562	2
4557	142	1
4558	101	4
4559	932	5
4560	575	4
4561	949	4
4562	735	1
4563	396	5
4564	768	4
4565	271	5
4566	100	3
4567	161	4
4568	593	2
4569	379	3
4570	712	1
4571	356	3
4572	959	2
4573	796	3
4574	489	4
4575	459	3
4576	962	1
4577	747	2
4578	317	3
4579	699	2
4580	960	1
4581	622	2
4582	388	4
4583	146	5
4584	265	3
4585	856	4
4586	646	1
4587	676	1
4588	171	1
4589	407	4
4590	191	4
4591	504	4
4592	815	2
4593	225	2
4594	950	1
4595	243	4
4596	842	3
4597	669	1
4598	386	2
4599	999	4
4600	542	1
4601	315	5
4602	725	2
4603	616	1
4604	921	2
4605	425	3
4606	798	5
4607	450	5
4608	750	5
4609	367	1
4610	870	5
4611	824	2
4612	563	5
4613	379	4
4614	351	2
4615	778	2
4616	429	4
4617	449	1
4618	315	2
4619	570	3
4620	713	2
4621	436	3
4622	116	3
4623	808	3
4624	236	4
4625	761	3
4626	102	5
4627	723	5
4628	587	1
4629	104	3
4630	109	4
4631	788	4
4632	277	1
4633	523	4
4634	669	5
4635	813	4
4636	820	2
4637	600	2
4638	880	3
4639	502	1
4640	651	1
4641	183	4
4642	906	4
4643	997	3
4644	764	1
4645	766	5
4646	179	1
4647	651	4
4648	131	1
4649	952	5
4650	935	3
4651	787	1
4652	555	4
4653	788	2
4654	226	2
4655	461	5
4656	932	5
4657	485	3
4658	947	1
4659	715	3
4660	466	3
4661	496	4
4662	281	2
4663	959	3
4664	886	1
4665	931	5
4666	813	1
4667	108	5
4668	227	3
4669	573	5
4670	479	1
4671	297	3
4672	555	3
4673	109	5
4674	326	1
4675	860	1
4676	120	3
4677	876	4
4678	387	3
4679	796	3
4680	826	5
4681	466	4
4682	296	3
4683	192	2
4684	935	5
4685	728	1
4686	740	4
4687	410	1
4688	927	4
4689	835	4
4690	326	1
4691	339	1
4692	605	3
4693	471	1
4694	137	5
4695	387	2
4696	604	1
4697	820	3
4698	823	3
4699	720	3
4700	314	1
4701	107	5
4702	300	3
4703	940	1
4704	753	2
4705	505	5
4706	213	5
4707	990	2
4708	384	2
4709	682	1
4710	612	5
4711	605	1
4712	274	2
4713	665	5
4714	298	4
4715	775	4
4716	856	2
4717	679	1
4718	788	2
4719	798	5
4720	717	3
4721	678	5
4722	279	5
4723	166	4
4724	702	3
4725	231	1
4726	863	4
4727	166	5
4728	230	5
4729	365	1
4730	683	2
4731	976	4
4732	333	3
4733	635	2
4734	846	5
4735	901	3
4736	380	1
4737	296	4
4738	968	3
4739	794	4
4740	123	5
4741	809	2
4742	794	2
4743	645	2
4744	729	3
4745	358	4
4746	797	2
4747	673	2
4748	564	1
4749	102	2
4750	537	5
4751	756	4
4752	789	3
4753	765	3
4754	153	1
4755	974	5
4756	430	5
4757	542	1
4758	964	4
4759	516	4
4760	380	1
4761	224	5
4762	796	5
4763	630	5
4764	577	4
4765	607	1
4766	470	5
4767	629	2
4768	877	1
4769	144	1
4770	838	5
4771	329	5
4772	148	1
4773	384	5
4774	530	3
4775	645	2
4776	559	1
4777	423	1
4778	105	2
4779	501	2
4780	299	4
4781	442	4
4782	183	1
4783	685	1
4784	927	3
4785	125	5
4786	855	3
4787	331	5
4788	806	3
4789	533	5
4790	176	1
4791	355	3
4792	301	2
4793	268	4
4794	437	2
4795	418	2
4796	164	1
4797	741	1
4798	740	5
4799	199	4
4800	128	1
4801	591	3
4802	542	4
4803	927	2
4804	124	2
4805	706	1
4806	916	3
4807	741	2
4808	442	5
4809	960	4
4810	356	1
4811	353	4
4812	210	4
4813	584	3
4814	344	3
4815	448	3
4816	952	3
4817	155	4
4818	941	1
4819	441	5
4820	632	2
4821	913	2
4822	342	1
4823	174	4
4824	894	1
4825	714	3
4826	734	4
4827	549	1
4828	882	5
4829	197	5
4830	740	3
4831	557	2
4832	692	5
4833	227	3
4834	187	4
4835	162	4
4836	134	4
4837	486	4
4838	420	2
4839	968	4
4840	810	2
4841	166	2
4842	901	3
4843	230	5
4844	163	4
4845	921	1
4846	552	3
4847	156	2
4848	408	1
4849	725	2
4850	741	4
4851	542	1
4852	167	5
4853	204	3
4854	793	1
4855	157	2
4856	672	3
4857	153	4
4858	401	5
4859	970	4
4860	490	1
4861	511	2
4862	198	4
4863	732	5
4864	870	4
4865	520	1
4866	338	3
4867	985	1
4868	713	4
4869	906	2
4870	775	1
4871	738	4
4872	110	4
4873	564	2
4874	493	4
4875	575	1
4876	914	3
4877	538	1
4878	735	2
4879	734	5
4880	203	1
4881	447	4
4882	766	3
4883	791	1
4884	901	5
4885	126	5
4886	564	5
4887	629	1
4888	436	1
4889	701	2
4890	297	5
4891	210	1
4892	205	5
4893	112	1
4894	709	2
4895	830	1
4896	169	2
4897	707	1
4898	908	2
4899	960	3
4900	298	2
4901	686	1
4902	229	5
4903	752	3
4904	621	3
4905	362	2
4906	463	2
4907	531	4
4908	592	3
4909	842	5
4910	735	4
4911	555	5
4912	290	3
4913	348	2
4914	240	1
4915	916	5
4916	145	2
4917	161	4
4918	230	1
4919	419	1
4920	698	5
4921	546	5
4922	625	4
4923	767	1
4924	872	2
4925	466	4
4926	418	3
4927	697	4
4928	654	3
4929	894	3
4930	249	3
4931	250	3
4932	580	5
4933	416	2
4934	717	1
4935	451	3
4936	398	3
4937	477	5
4938	108	5
4939	630	3
4940	700	3
4941	773	3
4942	794	2
4943	248	5
4944	158	1
4945	343	1
4946	619	5
4947	938	1
4948	955	5
4949	672	1
4950	979	5
4951	155	5
4952	532	4
4953	452	3
4954	300	3
4955	305	5
4956	755	2
4957	306	3
4958	904	3
4959	170	3
4960	449	4
4961	293	4
4962	783	2
4963	587	2
4964	811	5
4965	808	3
4966	578	2
4967	714	1
4968	809	4
4969	439	5
4970	972	4
4971	692	1
4972	679	3
4973	443	4
4974	730	4
4975	406	1
4976	528	2
4977	436	4
4978	266	1
4979	207	4
4980	565	2
4981	997	3
4982	908	5
4983	143	4
4984	607	1
4985	324	4
4986	103	1
4987	754	3
4988	328	4
4989	809	2
4990	335	4
4991	577	4
4992	738	1
4993	318	2
4994	344	2
4995	592	3
4996	852	1
4997	886	3
4998	934	5
4999	439	3
5000	926	1
5001	101	2
5001	102	3
5002	101	2
5002	102	3
5004	843	1
5005	101	2
5005	102	3
5006	101	2
5006	102	3
5007	101	2
5007	102	3
\.


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transactions (transaction_id, transaction_date, customer_id, store_id, payment_method_id, promotion_applied, promotion_id, weather_id, stockout) FROM stdin;
1	2024-03-31 21:46:00	2824	1	1	t	\N	1	t
2	2024-07-28 12:45:00	1409	2	2	t	1	2	t
3	2024-06-10 04:55:00	5506	3	2	f	\N	3	t
4	2024-08-15 01:03:00	5012	1	2	t	1	3	f
5	2024-09-13 00:45:00	4657	4	3	f	\N	3	t
6	2024-07-06 07:24:00	3286	5	1	t	\N	3	f
7	2024-03-17 22:33:00	2679	2	2	f	2	3	t
8	2024-07-22 13:57:00	9935	3	4	f	1	2	t
9	2024-03-30 04:10:00	2424	5	1	f	\N	3	t
10	2024-06-17 16:59:00	7912	4	3	t	\N	3	t
11	2024-04-03 11:37:00	1520	3	2	f	\N	1	t
12	2024-06-19 10:41:00	1488	1	4	t	\N	4	t
13	2024-03-01 04:08:00	2535	5	3	f	\N	3	f
14	2024-06-24 17:34:00	4582	1	3	f	\N	2	f
15	2024-07-11 11:58:00	4811	3	3	f	\N	1	t
16	2024-05-02 19:28:00	9279	2	4	t	\N	3	f
17	2024-03-01 14:26:00	1434	1	4	f	\N	3	f
18	2024-06-26 04:41:00	4257	5	4	f	\N	3	t
19	2024-06-02 20:20:00	9928	1	2	f	\N	3	t
20	2024-07-21 20:20:00	7873	1	3	t	1	2	t
21	2024-05-18 14:04:00	4611	3	1	f	2	3	t
22	2024-02-06 09:06:00	8359	2	1	f	\N	2	t
23	2024-03-03 11:00:00	5557	4	2	f	\N	3	f
24	2024-01-30 09:19:00	1106	4	4	f	\N	1	t
25	2024-08-03 04:57:00	3615	2	3	t	1	2	t
26	2024-07-17 15:17:00	7924	2	3	t	\N	4	f
27	2024-04-15 01:23:00	6574	2	2	t	\N	4	t
28	2024-07-27 03:42:00	5552	1	4	t	\N	1	f
29	2024-07-15 17:29:00	3547	1	4	t	2	4	t
30	2024-02-06 06:57:00	4527	5	3	t	\N	1	t
31	2024-07-31 10:27:00	6514	4	3	f	\N	2	t
32	2024-06-13 23:45:00	2674	4	4	t	\N	2	f
33	2024-05-02 07:21:00	2519	5	2	f	\N	1	f
34	2024-05-08 09:01:00	7224	3	2	t	\N	1	f
35	2024-02-14 07:00:00	2584	5	4	f	1	4	f
36	2024-08-28 12:57:00	6881	5	1	f	\N	3	t
37	2024-04-21 07:24:00	6635	5	1	t	1	1	t
38	2024-03-30 22:38:00	5333	5	2	f	\N	1	f
39	2024-01-28 23:03:00	1711	5	3	t	\N	2	f
40	2024-02-25 02:52:00	8527	2	4	f	2	1	t
41	2024-06-01 22:32:00	9785	1	4	f	1	2	t
42	2024-02-13 13:55:00	3045	5	3	f	\N	3	f
43	2024-04-11 02:53:00	7201	3	3	f	\N	1	t
44	2024-06-27 11:57:00	2291	3	4	f	1	2	t
45	2024-03-06 22:28:00	5803	1	4	t	1	4	t
46	2024-04-26 20:53:00	6925	5	2	f	\N	4	t
47	2024-08-06 05:40:00	4150	3	2	t	2	4	t
48	2024-09-06 23:19:00	2139	3	4	f	2	4	t
49	2024-06-21 16:04:00	1750	2	1	t	\N	4	t
50	2024-07-23 05:50:00	4733	2	1	t	\N	1	f
51	2024-01-21 05:04:00	5741	4	2	f	\N	3	f
52	2024-07-21 23:28:00	2307	3	3	t	\N	1	t
53	2024-05-25 12:08:00	4814	4	1	f	1	3	f
54	2024-04-03 17:35:00	2654	1	4	t	\N	1	f
55	2024-03-17 15:38:00	7227	2	1	f	2	3	f
56	2024-05-21 08:02:00	5554	5	4	t	\N	4	f
57	2024-05-20 22:46:00	8428	3	1	f	\N	4	f
58	2024-05-22 01:12:00	6977	1	4	t	\N	3	t
59	2024-07-13 12:07:00	3664	1	3	f	\N	1	f
60	2024-07-08 13:47:00	7065	5	1	t	\N	3	f
61	2024-02-23 07:27:00	6820	5	1	f	2	2	f
62	2024-05-23 12:54:00	4432	5	4	t	\N	1	t
63	2024-07-18 23:38:00	5374	1	1	t	2	3	t
64	2024-08-09 23:16:00	2169	4	2	f	\N	3	t
65	2024-03-29 14:26:00	3803	5	4	t	\N	3	t
66	2024-05-13 18:13:00	9751	4	4	f	\N	1	f
67	2024-04-01 02:35:00	5010	3	1	f	1	1	f
68	2024-06-22 22:55:00	3677	4	2	t	\N	2	f
69	2024-06-12 02:03:00	8573	1	3	f	\N	3	f
70	2024-03-18 05:57:00	7216	5	2	f	2	4	t
71	2024-03-23 21:42:00	5422	3	3	t	\N	1	t
72	2024-03-18 04:25:00	4598	1	2	f	\N	2	t
73	2024-05-12 22:09:00	6313	1	1	t	\N	3	t
74	2024-09-13 07:47:00	1916	5	4	t	\N	4	t
75	2024-01-08 06:33:00	4752	3	3	t	\N	4	t
76	2024-01-17 16:44:00	1525	4	3	t	\N	3	t
77	2024-03-11 05:28:00	6168	2	2	t	2	2	t
78	2024-06-04 11:51:00	7572	1	3	t	1	2	t
79	2024-05-20 19:29:00	5386	5	3	t	2	3	t
80	2024-06-20 02:36:00	2084	4	3	f	\N	4	t
81	2024-05-04 15:09:00	4456	4	3	t	\N	2	t
82	2024-01-29 01:58:00	6155	1	2	t	\N	2	f
83	2024-01-29 14:44:00	4483	1	4	f	1	4	f
84	2024-09-05 09:25:00	9179	4	2	t	\N	2	t
85	2024-06-24 17:20:00	7482	4	3	t	\N	4	t
86	2024-01-18 04:28:00	8517	2	3	f	\N	2	t
87	2024-04-08 12:55:00	3340	4	4	f	\N	2	f
88	2024-03-07 19:44:00	5339	4	3	t	\N	2	f
89	2024-05-31 21:18:00	3287	2	2	t	\N	3	t
90	2024-09-16 10:49:00	5040	5	4	f	1	3	t
91	2024-07-07 08:08:00	9830	1	2	f	\N	2	f
92	2024-01-18 18:20:00	5304	4	1	t	\N	1	t
93	2024-04-23 02:13:00	8019	5	1	t	\N	4	t
94	2024-03-17 21:53:00	7543	5	3	t	\N	2	t
95	2024-03-18 21:14:00	6930	2	2	f	2	3	f
96	2024-02-26 09:16:00	4593	2	2	f	\N	3	f
97	2024-09-05 02:59:00	3266	4	2	t	\N	3	f
98	2024-02-23 18:26:00	9348	2	4	f	\N	3	t
99	2024-03-19 14:38:00	9085	4	2	f	2	3	f
100	2024-08-07 02:50:00	2489	3	3	f	\N	2	f
101	2024-01-03 17:27:00	1771	2	4	t	1	4	t
102	2024-02-12 10:44:00	2796	2	4	t	\N	3	t
103	2024-08-24 15:02:00	3504	5	3	f	2	3	t
104	2024-02-26 23:09:00	3621	3	1	f	2	1	f
105	2024-09-07 10:41:00	7916	1	4	t	\N	2	f
106	2024-03-24 13:44:00	2040	4	4	f	\N	2	t
107	2024-02-25 16:31:00	7304	1	1	t	2	4	t
108	2024-04-05 15:10:00	7252	1	1	f	\N	4	t
109	2024-02-01 09:42:00	8668	4	1	f	\N	1	f
110	2024-05-13 02:08:00	9669	2	4	t	1	1	f
111	2024-05-14 00:38:00	5119	3	3	t	\N	1	t
112	2024-07-08 16:45:00	1188	3	3	f	\N	4	t
113	2024-07-17 04:47:00	2876	1	4	t	\N	2	t
114	2024-05-28 22:36:00	9797	4	3	f	\N	1	f
115	2024-01-01 22:11:00	5371	5	1	t	\N	3	t
116	2024-02-23 17:35:00	6573	3	1	f	\N	2	f
117	2024-01-02 01:25:00	2827	3	3	t	\N	1	t
118	2024-04-01 10:59:00	5808	4	1	t	\N	3	t
119	2024-02-29 19:33:00	8123	1	2	t	1	4	f
120	2024-07-06 00:16:00	3591	2	3	t	\N	4	t
121	2024-07-16 17:23:00	8433	2	3	f	\N	2	f
122	2024-02-11 19:48:00	1053	4	3	t	\N	2	f
123	2024-06-20 09:10:00	5315	4	1	f	\N	2	f
124	2024-01-06 04:49:00	9201	5	1	f	\N	3	t
125	2024-03-09 12:24:00	3927	5	1	t	1	1	t
126	2024-03-23 20:31:00	9317	5	4	f	\N	3	f
127	2024-08-12 10:41:00	2743	3	4	t	\N	4	f
128	2024-08-22 21:06:00	5889	3	1	t	\N	3	f
129	2024-04-24 08:23:00	9317	1	3	t	\N	3	f
130	2024-06-14 22:58:00	4258	5	4	t	\N	1	t
131	2024-02-12 08:18:00	3504	4	4	t	\N	3	f
132	2024-04-15 08:08:00	7126	4	4	f	\N	3	t
133	2024-03-21 03:39:00	3646	2	2	f	\N	3	f
134	2024-06-11 10:50:00	9837	2	1	f	\N	4	t
135	2024-09-15 01:10:00	9689	4	2	f	\N	3	t
136	2024-02-05 19:28:00	1009	5	4	t	\N	1	f
137	2024-08-14 08:29:00	6310	1	1	f	1	1	t
138	2024-03-16 13:26:00	9005	4	1	f	\N	3	f
139	2024-06-04 09:38:00	1319	1	3	f	\N	1	f
140	2024-02-20 05:21:00	2832	3	2	f	\N	4	f
141	2024-07-18 12:03:00	6947	4	1	t	\N	4	f
142	2024-04-30 18:10:00	6038	1	1	f	\N	2	f
143	2024-03-20 17:35:00	4923	1	4	f	\N	4	t
144	2024-08-31 05:11:00	1949	1	2	t	\N	1	t
145	2024-01-10 02:58:00	4946	1	2	t	\N	2	t
146	2024-01-09 16:59:00	2290	4	4	t	\N	3	f
147	2024-07-03 14:56:00	2403	5	2	t	2	1	f
148	2024-07-24 09:24:00	8962	5	2	t	\N	2	t
149	2024-07-22 18:07:00	2133	1	4	t	\N	3	t
150	2024-04-21 13:05:00	9727	3	1	t	\N	4	t
151	2024-01-20 06:27:00	3060	1	1	f	\N	4	f
152	2024-03-27 05:41:00	3103	4	4	f	\N	4	t
153	2024-02-28 13:29:00	8787	2	4	t	\N	3	t
154	2024-03-13 02:08:00	3705	3	2	t	\N	4	f
155	2024-06-15 18:09:00	5342	1	1	t	2	1	f
156	2024-04-09 14:07:00	9645	4	1	t	\N	4	f
157	2024-05-09 10:14:00	7932	4	4	f	\N	2	t
158	2024-01-31 18:25:00	4470	1	2	t	\N	3	f
159	2024-08-20 02:32:00	9835	3	1	f	\N	2	t
160	2024-09-07 00:27:00	4295	2	1	t	\N	4	f
161	2024-07-31 18:22:00	6107	2	4	t	\N	4	f
162	2024-07-25 17:42:00	7537	4	3	f	\N	1	f
163	2024-01-18 16:41:00	7118	3	1	f	2	4	t
164	2024-05-26 14:34:00	8177	3	4	f	\N	2	t
165	2024-06-27 14:02:00	9479	4	1	t	2	4	f
166	2024-01-05 18:03:00	8397	5	1	t	\N	4	f
167	2024-01-21 18:02:00	2982	2	3	t	\N	2	f
168	2024-06-12 20:13:00	5061	4	4	t	\N	4	f
169	2024-05-04 14:32:00	4681	2	2	t	\N	2	f
170	2024-08-16 19:29:00	2049	2	1	t	\N	2	f
171	2024-05-30 02:24:00	6539	4	3	f	\N	4	t
172	2024-08-04 19:14:00	1344	4	2	t	\N	2	t
173	2024-08-07 17:14:00	4770	4	3	f	\N	3	f
174	2024-02-05 11:11:00	4608	4	4	t	\N	3	t
175	2024-02-03 13:45:00	1117	3	1	t	\N	4	f
176	2024-07-24 07:39:00	2163	1	1	t	\N	2	t
177	2024-05-09 11:59:00	1964	4	2	t	\N	4	f
178	2024-04-12 13:50:00	4750	3	3	f	\N	4	f
179	2024-01-19 12:48:00	2104	3	4	t	2	2	f
180	2024-01-01 08:40:00	1514	1	1	f	\N	2	f
181	2024-09-13 00:34:00	6413	4	4	f	1	3	t
182	2024-05-10 14:05:00	2160	4	1	t	1	2	t
183	2024-05-21 04:08:00	9423	4	2	t	\N	1	f
184	2024-06-27 20:13:00	4899	1	1	f	\N	3	f
185	2024-02-27 14:54:00	5562	3	1	f	\N	1	f
186	2024-02-06 20:13:00	8953	1	3	f	1	1	f
187	2024-08-21 11:45:00	4510	3	3	t	1	2	t
188	2024-01-21 01:56:00	9834	4	3	f	2	2	t
189	2024-08-08 20:50:00	3167	5	1	f	\N	4	t
190	2024-03-13 10:32:00	8744	3	1	t	1	4	t
191	2024-05-07 20:35:00	4981	3	4	f	\N	3	t
192	2024-04-21 04:50:00	8749	2	1	t	2	4	f
193	2024-08-25 23:31:00	7669	3	1	t	\N	1	t
194	2024-07-06 20:44:00	4119	4	3	t	\N	2	t
195	2024-08-17 10:19:00	2545	3	2	f	1	2	t
196	2024-04-20 14:39:00	2588	3	3	f	1	2	t
197	2024-08-12 09:49:00	8062	5	2	t	\N	1	t
198	2024-01-01 21:35:00	6804	2	2	t	1	4	t
199	2024-02-09 21:53:00	7939	3	2	t	\N	4	t
200	2024-06-24 09:50:00	7735	5	3	f	\N	2	t
201	2024-05-21 02:21:00	8651	3	3	t	2	3	f
202	2024-06-02 01:43:00	1887	2	3	f	2	4	f
203	2024-05-22 19:58:00	2612	4	2	f	1	3	t
204	2024-09-12 13:10:00	1993	4	2	f	\N	1	t
205	2024-07-21 01:20:00	7596	2	3	t	\N	1	t
206	2024-05-18 23:50:00	6559	1	2	t	\N	4	f
207	2024-05-25 22:09:00	2790	5	2	t	2	4	t
208	2024-05-16 14:05:00	5073	1	2	t	\N	2	t
209	2024-08-19 06:49:00	4139	3	1	f	1	4	f
210	2024-03-13 22:30:00	4116	1	2	f	1	1	f
211	2024-07-21 20:11:00	9786	1	3	t	\N	2	f
212	2024-03-02 09:19:00	8350	4	2	t	\N	4	f
213	2024-03-21 01:03:00	3296	3	1	t	\N	2	t
214	2024-01-07 01:00:00	7912	2	2	t	\N	4	f
215	2024-02-09 21:17:00	4006	1	3	f	\N	1	f
216	2024-01-26 20:24:00	5563	3	2	f	\N	1	t
217	2024-02-10 18:37:00	8579	3	2	f	\N	4	f
218	2024-09-16 00:35:00	5092	5	1	f	\N	3	t
219	2024-05-18 05:54:00	2235	2	2	t	\N	3	f
220	2024-04-04 04:09:00	8260	4	4	f	\N	1	f
221	2024-04-25 11:47:00	2604	3	1	t	\N	1	t
222	2024-03-24 06:44:00	1828	3	2	t	1	4	f
223	2024-07-16 20:53:00	9856	1	2	t	\N	1	f
224	2024-01-10 13:48:00	1241	5	2	t	\N	3	t
225	2024-06-26 10:40:00	2528	4	4	f	2	3	f
226	2024-07-14 10:35:00	4872	1	4	f	\N	1	f
227	2024-08-07 10:32:00	3724	5	1	t	\N	4	t
228	2024-07-06 00:29:00	7658	3	3	t	1	4	f
229	2024-03-21 04:05:00	8956	2	4	t	\N	2	f
230	2024-01-20 06:23:00	8886	1	3	t	\N	2	f
231	2024-09-10 06:31:00	4502	2	3	f	2	1	f
232	2024-09-06 21:20:00	7570	2	4	t	\N	3	t
233	2024-02-06 00:32:00	1960	1	2	f	\N	3	t
234	2024-04-25 12:48:00	3697	3	1	f	2	4	t
235	2024-08-06 21:46:00	7209	4	1	t	2	3	f
236	2024-07-21 20:04:00	1035	1	1	f	\N	4	f
237	2024-09-02 05:58:00	7396	2	1	t	2	4	t
238	2024-09-08 18:05:00	5345	2	4	t	1	3	t
239	2024-08-22 19:49:00	8454	1	1	t	\N	3	f
240	2024-05-22 02:02:00	5673	5	4	f	2	4	f
241	2024-02-05 03:34:00	7930	2	4	f	2	3	t
242	2024-07-07 17:51:00	8973	4	4	f	\N	1	f
243	2024-01-25 18:04:00	3536	1	4	t	2	1	f
244	2024-05-08 00:59:00	4111	4	3	t	2	4	t
245	2024-07-06 12:16:00	5861	3	3	f	\N	1	t
246	2024-06-19 20:12:00	4566	1	2	t	2	1	t
247	2024-03-17 00:39:00	1958	5	2	t	\N	3	f
248	2024-01-17 02:24:00	9883	3	3	t	\N	2	f
249	2024-07-08 09:55:00	1998	5	2	f	1	2	t
250	2024-03-30 02:31:00	6138	4	2	f	1	4	f
251	2024-01-20 18:19:00	1936	2	3	t	\N	1	f
252	2024-03-26 09:34:00	1821	4	4	f	2	1	t
253	2024-03-28 09:15:00	8811	2	3	t	\N	1	t
254	2024-03-11 08:29:00	9238	5	2	f	\N	2	t
255	2024-02-25 01:41:00	9701	3	4	t	\N	1	f
256	2024-04-27 11:14:00	3579	5	1	t	\N	3	f
257	2024-08-03 14:21:00	1931	3	1	t	\N	3	f
258	2024-06-20 08:28:00	9320	5	1	f	\N	3	t
259	2024-03-18 11:22:00	2312	4	1	t	\N	1	t
260	2024-07-21 11:57:00	4044	2	2	t	\N	2	t
261	2024-08-06 20:09:00	2122	2	2	t	\N	2	f
262	2024-01-25 07:20:00	2113	3	4	f	\N	2	f
263	2024-09-08 08:45:00	4853	5	1	t	1	1	t
264	2024-09-12 00:32:00	7615	3	2	f	1	2	t
265	2024-05-09 07:56:00	2964	5	4	f	\N	4	t
266	2024-03-22 08:59:00	5033	5	2	f	\N	2	t
267	2024-07-29 20:31:00	1651	2	4	t	\N	1	f
268	2024-08-12 16:27:00	2343	4	3	t	\N	1	t
269	2024-01-30 09:35:00	7868	3	1	t	\N	2	f
270	2024-07-24 14:30:00	9565	1	4	f	2	3	f
271	2024-05-06 16:04:00	6183	2	1	f	\N	1	t
272	2024-01-29 14:14:00	5272	1	3	f	\N	3	t
273	2024-03-28 14:18:00	4346	4	1	t	1	3	t
274	2024-06-03 00:23:00	6147	1	2	f	\N	2	f
275	2024-02-21 02:05:00	4910	4	2	f	\N	3	t
276	2024-05-22 15:14:00	5351	2	3	t	\N	1	f
277	2024-07-13 20:16:00	7484	2	1	f	\N	1	t
278	2024-07-05 22:07:00	3144	3	1	t	\N	3	t
279	2024-07-26 05:15:00	5915	4	4	f	\N	2	t
280	2024-04-21 16:41:00	8491	4	2	t	\N	2	f
281	2024-06-25 15:46:00	6180	3	4	t	\N	2	t
282	2024-03-23 22:16:00	2188	4	3	f	\N	2	t
283	2024-02-20 16:11:00	1152	3	3	t	2	3	f
284	2024-07-05 18:18:00	8508	4	4	t	\N	1	t
285	2024-04-04 11:53:00	2638	4	2	t	\N	4	f
286	2024-08-30 15:58:00	2200	5	4	t	\N	4	f
287	2024-04-25 09:49:00	9808	2	2	t	1	1	f
288	2024-09-16 03:20:00	4492	2	3	f	1	4	t
289	2024-04-22 22:31:00	9288	2	2	f	\N	3	t
290	2024-05-04 22:18:00	5345	4	1	f	\N	1	t
291	2024-05-22 18:38:00	3170	2	2	t	\N	3	t
292	2024-05-02 23:28:00	6718	1	3	f	\N	4	f
293	2024-06-24 04:55:00	2127	1	2	t	\N	3	t
294	2024-04-19 20:20:00	5002	4	4	f	2	2	f
295	2024-07-30 07:56:00	7054	3	1	f	\N	3	f
296	2024-03-12 21:25:00	5669	5	2	f	\N	1	t
297	2024-06-14 06:41:00	3584	3	4	f	\N	3	t
298	2024-02-07 21:38:00	8179	1	2	t	2	4	f
299	2024-07-03 06:04:00	9900	2	2	t	1	1	f
300	2024-05-25 21:05:00	5956	5	2	f	\N	3	f
301	2024-05-25 13:49:00	9666	1	4	t	2	3	t
302	2024-04-17 03:36:00	1128	3	2	f	\N	3	f
303	2024-04-01 03:05:00	5905	5	4	f	\N	4	t
304	2024-06-08 04:58:00	2697	5	2	f	1	1	f
305	2024-02-06 13:01:00	3200	5	4	f	2	2	f
306	2024-03-27 00:02:00	5333	5	1	f	\N	4	t
307	2024-08-15 17:08:00	2891	2	2	f	\N	4	t
308	2024-04-29 18:12:00	2753	4	2	f	\N	3	t
309	2024-01-17 14:40:00	3546	4	3	f	\N	3	f
310	2024-04-01 15:37:00	5462	5	1	t	2	3	t
311	2024-05-27 23:21:00	5616	4	1	t	\N	2	t
312	2024-08-31 14:26:00	4450	1	4	t	1	1	t
313	2024-03-28 02:03:00	6617	5	3	f	\N	2	t
314	2024-08-23 07:44:00	4335	1	1	t	\N	3	f
315	2024-01-15 03:24:00	5325	3	1	f	\N	2	t
316	2024-04-05 22:06:00	9280	5	1	f	2	3	t
317	2024-01-12 22:56:00	9004	4	2	t	\N	3	t
318	2024-08-09 00:06:00	5114	3	2	t	\N	4	f
319	2024-07-22 05:47:00	1832	1	3	f	1	3	f
320	2024-07-09 12:29:00	2512	3	1	t	\N	1	t
321	2024-09-02 17:20:00	7939	1	4	f	2	3	f
322	2024-05-14 03:41:00	5533	4	3	f	\N	4	t
323	2024-01-13 15:04:00	1722	4	4	f	2	1	t
324	2024-09-07 21:36:00	1058	1	4	t	\N	3	t
325	2024-01-25 10:53:00	6464	4	3	f	\N	3	t
326	2024-06-21 11:56:00	3143	2	4	t	2	1	t
327	2024-04-14 00:24:00	5291	1	3	t	\N	1	t
328	2024-01-11 23:32:00	3647	2	3	t	2	4	t
329	2024-04-24 21:21:00	8239	2	1	f	2	2	f
330	2024-03-12 06:28:00	8007	5	4	f	\N	2	t
331	2024-07-02 12:50:00	1158	4	1	f	\N	1	f
332	2024-08-10 23:39:00	2832	5	2	f	\N	2	t
333	2024-03-06 00:36:00	2232	3	1	t	2	3	f
334	2024-02-19 18:35:00	3442	3	2	f	\N	4	t
335	2024-08-04 03:43:00	9938	2	2	t	\N	2	f
336	2024-01-21 10:31:00	1590	3	2	t	\N	4	t
337	2024-04-27 22:48:00	7049	4	3	t	1	2	t
338	2024-08-01 22:12:00	3426	3	3	t	\N	2	t
339	2024-04-07 06:20:00	8041	3	2	f	\N	2	t
340	2024-05-24 08:01:00	3088	4	2	f	\N	4	t
341	2024-04-01 11:18:00	1685	1	1	f	\N	4	t
342	2024-08-19 18:40:00	6050	1	2	f	\N	2	f
343	2024-04-05 06:10:00	6974	2	3	t	2	4	f
344	2024-08-17 08:53:00	1653	3	2	f	2	3	f
345	2024-01-20 05:02:00	6862	5	2	t	\N	4	t
346	2024-02-22 05:23:00	4441	3	2	t	1	2	t
347	2024-05-04 04:53:00	5088	2	1	f	\N	4	t
348	2024-06-22 05:32:00	2684	4	2	t	\N	3	t
349	2024-02-06 14:36:00	6794	5	2	t	2	3	f
350	2024-02-18 22:23:00	7658	2	1	t	\N	2	t
351	2024-02-27 16:56:00	3532	4	1	f	\N	4	f
352	2024-08-07 16:22:00	4878	5	1	t	1	3	t
353	2024-01-05 07:48:00	3662	4	3	t	\N	1	t
354	2024-09-01 03:39:00	3900	1	2	f	\N	4	f
355	2024-08-02 10:07:00	7755	4	3	t	\N	2	t
356	2024-05-04 09:58:00	1406	3	4	t	2	1	f
357	2024-03-29 13:20:00	3938	4	1	f	1	3	f
358	2024-06-17 13:30:00	6442	4	2	f	\N	1	f
359	2024-08-23 12:49:00	7745	5	1	t	\N	1	f
360	2024-04-23 00:05:00	5065	4	2	f	\N	4	t
361	2024-03-24 04:06:00	5371	5	2	t	\N	4	t
362	2024-07-20 05:04:00	3608	1	1	f	\N	2	f
363	2024-08-27 17:54:00	2771	5	3	t	\N	3	f
364	2024-05-09 09:36:00	7267	2	4	t	\N	3	f
365	2024-04-12 22:04:00	1634	1	2	f	\N	2	f
366	2024-03-26 22:09:00	8711	2	1	t	1	3	f
367	2024-04-29 17:48:00	4644	2	2	f	2	1	f
368	2024-07-11 07:30:00	4269	4	1	f	\N	2	t
369	2024-09-13 07:18:00	8541	5	4	t	\N	1	f
370	2024-01-29 21:46:00	6728	2	3	f	1	1	f
371	2024-05-24 07:03:00	6000	1	2	t	2	4	t
372	2024-05-19 11:04:00	4728	5	1	t	\N	3	f
373	2024-05-06 05:27:00	4652	2	1	f	2	3	t
374	2024-02-03 03:08:00	1387	2	2	f	\N	4	t
375	2024-02-03 05:40:00	4164	4	3	f	\N	2	f
376	2024-06-07 06:22:00	7528	4	3	f	1	2	f
377	2024-02-29 15:59:00	6378	3	4	t	\N	4	f
378	2024-01-07 20:14:00	5564	3	2	f	2	2	t
379	2024-02-24 01:48:00	2137	1	1	t	\N	2	f
380	2024-05-17 17:17:00	5573	1	4	f	1	3	t
381	2024-07-05 14:12:00	6753	1	1	f	2	4	t
382	2024-01-02 18:44:00	9346	3	4	t	\N	2	t
383	2024-06-10 18:12:00	7548	5	2	t	\N	2	f
384	2024-07-21 02:36:00	9785	2	2	f	\N	3	t
385	2024-05-24 02:04:00	6425	2	1	f	\N	3	t
386	2024-08-07 04:08:00	1452	4	3	t	1	1	f
387	2024-07-30 22:12:00	2889	4	2	f	\N	2	f
388	2024-08-21 12:57:00	5279	1	4	t	1	2	f
389	2024-08-28 09:47:00	3925	4	3	f	2	3	t
390	2024-09-03 08:06:00	5349	5	3	t	\N	4	f
391	2024-02-21 21:22:00	1626	3	2	t	\N	3	f
392	2024-06-26 04:36:00	2776	1	4	f	\N	4	f
393	2024-09-04 11:31:00	8119	5	2	f	\N	1	t
394	2024-09-08 10:12:00	6663	4	1	f	\N	2	f
395	2024-06-15 16:05:00	6139	1	3	f	\N	1	t
396	2024-05-05 22:23:00	8149	5	2	f	\N	1	t
397	2024-01-17 19:04:00	9379	5	3	f	\N	2	f
398	2024-04-01 13:00:00	2894	4	4	t	\N	4	t
399	2024-07-03 23:36:00	7311	3	2	f	\N	4	t
400	2024-07-26 13:55:00	4114	5	4	t	\N	1	f
401	2024-01-16 08:38:00	5173	5	4	f	\N	2	f
402	2024-02-08 04:36:00	1727	4	2	f	\N	4	f
403	2024-01-11 21:00:00	8144	3	1	t	2	1	f
404	2024-07-05 07:07:00	1027	5	1	f	1	4	f
405	2024-04-20 01:31:00	9518	4	4	t	1	2	f
406	2024-01-28 11:30:00	9821	5	4	f	\N	1	t
407	2024-01-16 14:38:00	4228	4	2	f	\N	1	f
408	2024-01-15 21:00:00	6967	1	2	t	\N	4	f
409	2024-05-14 05:33:00	8066	2	3	f	1	2	f
410	2024-07-05 03:58:00	2146	1	2	t	\N	4	f
411	2024-08-06 17:12:00	6409	3	4	t	\N	3	f
412	2024-04-17 21:01:00	6143	4	2	t	2	3	t
413	2024-01-18 06:07:00	3041	1	4	f	\N	1	t
414	2024-07-22 01:45:00	5920	3	4	t	\N	1	f
415	2024-05-31 02:04:00	9308	1	4	t	2	2	f
416	2024-01-29 23:02:00	6067	2	3	t	2	1	f
417	2024-03-06 06:18:00	7691	5	1	f	\N	1	t
418	2024-04-10 22:19:00	6344	2	2	t	\N	1	t
419	2024-05-10 22:31:00	7592	3	1	t	\N	3	f
420	2024-03-13 12:23:00	5844	1	3	f	\N	1	f
421	2024-04-20 04:20:00	3085	3	2	t	\N	2	f
422	2024-08-17 02:30:00	4143	4	1	t	1	4	t
423	2024-08-10 05:49:00	7888	2	2	f	1	2	f
424	2024-06-19 07:59:00	7211	4	4	f	\N	1	t
425	2024-01-05 11:41:00	3851	3	3	t	\N	1	f
426	2024-05-08 17:24:00	5930	3	4	t	\N	2	f
427	2024-06-29 14:18:00	7653	5	3	t	\N	4	t
428	2024-03-19 07:17:00	9977	3	1	t	\N	4	t
429	2024-02-15 13:40:00	1006	3	3	t	2	1	t
430	2024-05-03 11:49:00	5978	1	2	t	1	4	t
431	2024-09-16 01:14:00	5700	2	1	t	\N	4	t
432	2024-03-16 04:06:00	4443	4	3	t	1	3	f
433	2024-05-17 16:55:00	8043	2	1	t	\N	4	t
434	2024-08-09 23:42:00	6279	1	1	t	\N	2	f
435	2024-01-18 22:58:00	8618	5	2	f	\N	1	t
436	2024-08-25 14:36:00	8238	1	4	t	2	1	f
437	2024-03-23 10:00:00	8244	5	3	t	2	3	f
438	2024-03-23 12:43:00	4501	2	2	t	\N	1	f
439	2024-06-07 02:11:00	9375	5	3	t	2	3	t
440	2024-07-25 14:15:00	8752	4	2	f	1	4	t
441	2024-09-11 00:04:00	3780	1	2	t	\N	4	t
442	2024-03-24 14:12:00	2389	1	4	f	\N	3	t
443	2024-07-20 02:47:00	5649	2	1	t	\N	3	f
444	2024-05-18 21:20:00	9445	4	3	f	\N	4	t
445	2024-04-28 13:09:00	6491	3	2	t	1	3	t
446	2024-08-19 16:07:00	2530	2	3	t	\N	4	t
447	2024-03-21 11:01:00	4848	5	1	t	1	1	f
448	2024-05-01 18:45:00	6085	4	3	t	2	1	f
449	2024-02-10 02:10:00	4680	4	4	t	2	2	t
450	2024-05-27 11:27:00	4262	1	2	t	\N	1	t
451	2024-08-20 02:58:00	3414	3	1	t	2	4	t
452	2024-04-25 23:13:00	1400	1	2	t	\N	4	t
453	2024-06-23 08:10:00	1757	1	3	t	1	1	t
454	2024-03-15 03:16:00	5011	3	2	t	\N	3	f
455	2024-07-18 15:30:00	8784	3	1	f	1	3	f
456	2024-06-03 01:51:00	2193	3	2	t	\N	2	f
457	2024-08-22 23:59:00	8461	5	1	t	\N	4	t
458	2024-02-28 16:40:00	7790	1	1	t	\N	2	t
459	2024-02-15 04:48:00	4185	1	3	f	\N	3	f
460	2024-04-12 05:17:00	7291	1	1	t	\N	1	f
461	2024-02-25 10:06:00	9099	3	4	t	\N	1	t
462	2024-03-03 01:49:00	7547	1	3	f	\N	4	t
463	2024-02-17 04:13:00	4997	2	3	t	\N	4	t
464	2024-01-20 16:35:00	3417	5	1	t	1	3	t
465	2024-05-21 22:37:00	1090	2	3	f	2	2	t
466	2024-03-03 00:13:00	2746	2	3	t	\N	3	f
467	2024-01-06 04:49:00	7965	5	4	f	2	3	t
468	2024-07-22 03:29:00	4585	4	3	f	\N	2	t
469	2024-08-26 10:26:00	3881	3	4	f	\N	2	f
470	2024-04-22 00:54:00	9486	4	1	t	\N	4	f
471	2024-01-29 21:46:00	8611	5	2	t	1	1	f
472	2024-03-16 15:12:00	1822	3	2	f	\N	2	f
473	2024-09-01 17:59:00	5082	2	1	f	\N	1	f
474	2024-03-17 04:27:00	2988	4	4	t	2	1	t
475	2024-05-21 06:14:00	8478	1	1	f	\N	2	f
476	2024-07-04 14:54:00	3184	1	2	f	\N	1	t
477	2024-07-18 08:44:00	8612	5	3	f	\N	1	f
478	2024-03-22 07:46:00	9702	5	1	t	1	3	f
479	2024-04-14 06:19:00	6198	3	3	t	2	3	f
480	2024-07-17 10:38:00	8251	2	2	t	2	1	t
481	2024-08-07 20:36:00	9270	2	2	t	\N	2	f
482	2024-04-07 04:09:00	7991	5	3	f	\N	2	f
483	2024-07-16 17:50:00	9976	2	3	f	\N	2	t
484	2024-02-02 09:27:00	8305	1	1	t	1	3	t
485	2024-05-07 04:38:00	3607	1	2	f	\N	4	t
486	2024-08-17 20:00:00	8777	1	1	f	2	2	f
487	2024-06-28 21:13:00	8373	4	4	t	2	3	t
488	2024-07-23 22:39:00	5246	4	1	t	1	3	t
489	2024-01-08 18:22:00	5050	2	4	t	2	2	t
490	2024-03-28 05:30:00	5543	2	1	t	1	4	t
491	2024-03-05 21:45:00	9540	5	2	f	\N	2	t
492	2024-07-22 07:51:00	8939	1	3	t	\N	4	t
493	2024-03-20 01:54:00	4919	2	4	f	1	3	t
494	2024-03-01 17:06:00	5499	2	2	t	\N	4	t
495	2024-04-15 05:27:00	8206	3	4	f	\N	4	t
496	2024-07-06 19:11:00	2269	4	2	t	\N	4	t
497	2024-09-03 01:27:00	5681	3	2	f	\N	4	f
498	2024-02-23 22:38:00	4841	3	3	t	\N	3	f
499	2024-04-26 05:24:00	5451	5	3	t	2	1	f
500	2024-08-31 12:51:00	6502	2	4	f	2	2	t
501	2024-02-10 12:18:00	6238	5	2	f	\N	3	t
502	2024-05-21 20:20:00	9849	4	4	f	2	3	t
503	2024-03-27 18:48:00	2320	1	3	t	2	3	t
504	2024-05-01 03:21:00	3267	1	3	f	\N	2	f
505	2024-04-21 08:28:00	3471	5	4	f	2	4	t
506	2024-01-14 00:05:00	4788	3	1	t	\N	1	t
507	2024-08-05 09:33:00	7275	3	3	t	\N	1	f
508	2024-04-12 12:25:00	3503	5	4	t	\N	1	t
509	2024-04-18 10:03:00	4505	2	4	f	1	4	t
510	2024-06-17 19:55:00	2052	4	2	f	\N	1	f
511	2024-01-23 17:35:00	7797	2	2	t	\N	3	f
512	2024-06-01 21:47:00	7678	2	3	f	2	3	t
513	2024-06-03 09:14:00	6421	5	3	f	\N	2	f
514	2024-06-16 02:38:00	9890	5	1	f	\N	2	f
515	2024-09-06 22:24:00	8633	2	4	t	1	4	t
516	2024-02-27 21:10:00	7812	1	2	t	\N	2	f
517	2024-09-06 19:58:00	2020	3	4	t	\N	3	f
518	2024-08-25 14:03:00	4388	2	3	f	2	3	t
519	2024-04-28 04:29:00	7883	5	3	f	1	2	t
520	2024-08-13 01:44:00	7381	1	4	t	\N	1	f
521	2024-02-21 21:50:00	1320	3	2	t	\N	2	f
522	2024-04-06 11:28:00	7232	5	4	t	\N	2	t
523	2024-06-25 19:36:00	8814	5	1	f	\N	4	f
524	2024-01-19 23:47:00	1096	3	3	t	\N	1	t
525	2024-03-13 23:22:00	6763	2	3	t	\N	4	f
526	2024-03-05 12:22:00	5892	2	3	f	1	1	f
527	2024-09-01 22:18:00	7389	5	4	t	\N	1	t
528	2024-03-12 06:32:00	7865	1	1	f	\N	1	t
529	2024-05-17 17:05:00	9818	2	4	f	\N	1	t
530	2024-05-11 01:48:00	9947	5	2	f	1	1	f
531	2024-06-01 02:10:00	4613	4	3	f	1	3	f
532	2024-07-19 00:54:00	8999	1	2	f	\N	2	t
533	2024-05-01 00:43:00	4595	2	4	t	\N	1	t
534	2024-07-16 23:00:00	5471	5	1	f	1	1	t
535	2024-08-03 14:36:00	8140	3	4	f	1	4	t
536	2024-03-20 10:23:00	8956	1	3	f	\N	3	t
537	2024-03-18 19:43:00	1475	5	3	t	\N	4	f
538	2024-05-01 00:06:00	7371	5	4	t	\N	2	t
539	2024-02-13 11:32:00	6507	1	1	t	1	4	f
540	2024-06-25 01:20:00	7624	2	4	t	\N	3	t
541	2024-03-01 14:54:00	3704	5	4	f	2	3	t
542	2024-01-29 07:23:00	8657	3	3	f	\N	3	f
543	2024-03-12 16:28:00	3091	3	1	t	\N	1	f
544	2024-04-08 04:10:00	9751	1	1	f	\N	3	f
545	2024-02-06 13:42:00	1441	3	2	t	\N	3	t
546	2024-07-01 14:31:00	7455	4	4	f	\N	4	f
547	2024-01-19 13:06:00	1444	2	1	t	\N	3	f
548	2024-02-04 17:54:00	2375	1	2	t	\N	3	t
549	2024-08-06 20:34:00	8022	3	4	t	\N	2	t
550	2024-07-25 13:25:00	3223	4	1	t	\N	1	f
551	2024-07-24 00:32:00	8564	4	1	f	\N	1	f
552	2024-04-29 14:09:00	3977	1	4	t	2	2	t
553	2024-06-16 22:37:00	1823	4	1	t	\N	3	f
554	2024-03-03 04:47:00	5262	2	1	f	\N	1	t
555	2024-01-07 14:14:00	7211	1	1	f	\N	1	t
556	2024-01-06 23:09:00	6363	1	4	f	\N	1	f
557	2024-08-29 11:34:00	4467	2	3	t	\N	3	t
558	2024-08-12 07:58:00	8449	3	1	t	\N	3	t
559	2024-05-30 00:08:00	6355	3	2	f	2	2	t
560	2024-03-14 16:52:00	6529	3	2	f	2	3	f
561	2024-02-08 02:41:00	7211	2	2	t	\N	3	t
562	2024-08-12 07:38:00	5558	1	3	f	\N	3	f
563	2024-05-23 20:45:00	7906	5	4	t	\N	1	t
564	2024-06-20 09:14:00	5133	3	1	t	\N	4	f
565	2024-04-26 21:42:00	2341	5	1	f	\N	4	t
566	2024-05-18 02:04:00	8705	1	1	t	1	3	f
567	2024-06-07 19:34:00	1317	2	3	f	1	2	f
568	2024-08-23 00:40:00	9837	4	3	f	2	4	f
569	2024-06-18 04:13:00	1853	2	3	t	2	1	t
570	2024-08-15 07:56:00	6733	2	4	t	2	1	f
571	2024-04-17 04:39:00	4673	1	3	f	\N	2	t
572	2024-01-21 09:38:00	2124	2	3	f	\N	3	f
573	2024-07-28 13:56:00	1659	4	1	t	\N	3	f
574	2024-04-28 10:26:00	1508	3	1	t	\N	3	t
575	2024-05-25 03:44:00	5051	2	2	t	\N	3	f
576	2024-04-06 07:16:00	4266	1	3	f	\N	3	f
577	2024-01-27 00:19:00	1333	3	2	f	2	1	f
578	2024-01-18 16:33:00	3496	5	2	t	\N	3	f
579	2024-05-16 22:11:00	4908	1	4	f	\N	3	t
580	2024-06-30 08:55:00	3068	3	1	f	\N	2	f
581	2024-03-09 15:51:00	8758	2	4	t	\N	3	f
582	2024-04-11 01:29:00	2874	3	1	t	1	4	f
583	2024-08-26 06:20:00	4571	3	2	t	2	1	f
584	2024-09-13 11:46:00	8619	4	2	t	2	2	f
585	2024-04-02 22:12:00	5198	4	1	t	2	1	t
586	2024-03-11 11:38:00	7043	1	4	t	\N	3	t
587	2024-09-10 04:32:00	3749	1	2	f	\N	1	t
588	2024-07-19 00:10:00	2876	5	3	f	\N	3	f
589	2024-02-15 23:20:00	3683	3	2	f	\N	2	t
590	2024-07-12 14:04:00	6096	3	1	f	\N	4	t
591	2024-04-27 12:45:00	2771	1	4	t	\N	4	t
592	2024-08-24 05:46:00	1420	5	4	t	1	4	t
593	2024-08-29 23:51:00	6111	2	4	f	\N	4	t
594	2024-09-09 19:23:00	7149	5	2	t	2	3	t
595	2024-04-25 11:47:00	7498	1	2	f	\N	4	t
596	2024-04-12 10:06:00	4249	5	4	f	\N	3	f
597	2024-08-30 23:40:00	2245	1	4	t	2	2	t
598	2024-08-06 20:18:00	4978	4	3	t	2	2	t
599	2024-06-01 22:26:00	2669	1	4	f	\N	2	f
600	2024-09-08 19:23:00	5941	3	4	t	2	2	f
601	2024-05-12 23:09:00	2983	3	4	t	\N	1	t
602	2024-02-09 16:37:00	1672	3	3	t	1	1	t
603	2024-01-21 18:44:00	6688	1	3	t	2	4	f
604	2024-02-11 04:18:00	9728	4	4	t	1	3	f
605	2024-05-17 08:08:00	8018	4	2	t	\N	3	t
606	2024-03-03 08:29:00	7071	5	4	t	\N	3	f
607	2024-03-06 14:53:00	2129	3	4	t	\N	1	f
608	2024-02-16 07:42:00	9289	5	3	t	\N	3	t
609	2024-01-15 03:47:00	6590	3	3	t	\N	4	t
610	2024-03-11 07:41:00	1207	1	4	t	2	1	t
611	2024-06-10 22:53:00	7882	1	1	t	\N	4	f
612	2024-06-27 19:32:00	9031	3	1	t	\N	3	f
613	2024-07-04 13:25:00	2729	1	4	t	2	4	t
614	2024-07-20 07:32:00	8102	5	2	t	2	4	f
615	2024-03-29 05:16:00	6934	3	3	t	2	1	t
616	2024-03-25 03:46:00	8532	5	1	t	\N	4	f
617	2024-01-18 10:26:00	3506	1	4	t	2	1	t
618	2024-04-28 14:59:00	8135	1	1	t	2	3	f
619	2024-04-06 06:07:00	3885	2	4	t	1	4	f
620	2024-02-08 00:20:00	9548	3	2	f	2	2	f
621	2024-02-07 22:41:00	5425	3	2	t	2	4	t
622	2024-01-12 21:17:00	9817	4	4	f	\N	3	t
623	2024-06-06 19:45:00	8921	3	4	t	1	2	f
624	2024-08-28 20:50:00	8616	5	3	f	\N	3	f
625	2024-05-23 04:40:00	8136	2	4	t	\N	3	f
626	2024-03-22 01:55:00	5397	3	2	f	\N	4	t
627	2024-01-06 20:03:00	6280	5	4	t	2	4	f
628	2024-03-18 07:20:00	5022	4	4	f	2	3	f
629	2024-05-02 00:35:00	2419	4	2	f	\N	4	t
630	2024-01-31 10:49:00	5569	1	2	f	1	2	f
631	2024-03-19 14:10:00	8385	3	4	t	1	4	t
632	2024-03-01 05:27:00	4995	3	1	t	1	2	f
633	2024-08-03 21:33:00	8613	3	2	f	\N	1	t
634	2024-05-05 17:51:00	7209	1	4	t	\N	4	t
635	2024-08-16 19:15:00	6511	2	1	f	\N	1	f
636	2024-08-13 05:21:00	1470	3	3	t	\N	4	t
637	2024-05-27 04:55:00	9098	3	2	f	2	1	f
638	2024-02-19 00:51:00	6325	1	4	f	\N	1	f
639	2024-07-10 14:44:00	3979	1	3	f	\N	4	f
640	2024-04-18 16:02:00	8988	5	1	t	1	4	t
641	2024-06-15 17:36:00	4475	5	4	f	2	2	t
642	2024-01-15 12:07:00	6813	1	4	t	\N	3	f
643	2024-07-31 17:34:00	5232	2	2	f	1	2	f
644	2024-03-24 01:05:00	6576	2	1	t	2	1	t
645	2024-08-23 14:02:00	5581	4	2	f	1	3	t
646	2024-03-02 14:41:00	5526	4	2	f	1	3	f
647	2024-03-05 05:50:00	1166	3	1	t	2	1	f
648	2024-01-06 06:28:00	9464	3	4	t	\N	4	t
649	2024-05-03 13:17:00	4130	4	3	t	1	4	t
650	2024-07-26 13:21:00	2402	4	3	f	1	1	t
651	2024-07-03 06:02:00	4954	4	4	t	\N	3	t
652	2024-05-14 01:40:00	7658	4	2	t	\N	4	t
653	2024-08-15 21:05:00	9004	3	3	t	\N	3	t
654	2024-07-03 03:15:00	4937	3	1	f	2	2	f
655	2024-01-22 03:09:00	8800	1	2	t	\N	3	f
656	2024-05-06 12:17:00	9041	2	2	f	\N	4	t
657	2024-03-16 07:42:00	8342	3	3	f	\N	4	t
658	2024-04-20 19:06:00	1282	3	3	f	\N	3	t
659	2024-07-10 18:24:00	2524	5	1	f	\N	4	t
660	2024-07-08 11:38:00	5820	2	2	f	2	2	f
661	2024-07-22 03:45:00	4630	2	2	f	2	4	f
662	2024-01-22 18:31:00	7625	1	1	t	\N	4	t
663	2024-02-21 00:02:00	4986	4	3	t	1	1	t
664	2024-06-24 11:32:00	6016	2	1	f	1	1	f
665	2024-03-14 05:34:00	7046	3	3	t	\N	2	t
666	2024-08-03 10:01:00	8753	1	2	f	\N	4	f
667	2024-03-12 17:22:00	9698	2	1	f	\N	4	f
668	2024-03-15 13:38:00	6632	4	3	f	\N	3	f
669	2024-06-13 05:48:00	7971	1	2	t	\N	2	f
670	2024-08-01 03:09:00	6419	4	3	f	\N	2	f
671	2024-07-03 07:17:00	6764	1	3	f	\N	3	t
672	2024-09-05 07:54:00	8434	5	3	t	\N	4	t
673	2024-05-24 08:28:00	5438	5	1	f	\N	1	t
674	2024-07-08 04:06:00	6023	4	3	f	\N	3	f
675	2024-04-13 15:27:00	5118	5	2	t	\N	1	t
676	2024-04-12 13:35:00	4777	3	3	t	\N	1	f
677	2024-07-10 20:35:00	2976	3	2	t	\N	3	t
678	2024-06-12 11:38:00	4155	3	2	t	\N	4	f
679	2024-04-06 13:23:00	6169	1	3	t	\N	2	t
680	2024-09-12 16:47:00	2958	3	1	t	\N	2	f
681	2024-07-26 19:28:00	9779	1	1	f	1	4	f
682	2024-05-22 00:21:00	4033	3	4	t	\N	1	t
683	2024-04-09 15:46:00	4138	1	2	t	1	4	t
684	2024-02-05 00:43:00	4545	4	1	t	\N	1	t
685	2024-03-19 00:03:00	8933	4	3	t	\N	1	f
686	2024-02-26 13:27:00	5530	3	1	f	\N	4	t
687	2024-03-12 18:43:00	9595	5	1	t	\N	3	t
688	2024-09-04 11:19:00	5636	4	2	f	\N	4	t
689	2024-07-03 23:47:00	2647	4	3	t	\N	4	f
690	2024-07-18 21:03:00	4180	2	1	f	\N	1	f
691	2024-02-24 06:56:00	5853	2	3	f	\N	1	t
692	2024-09-05 02:18:00	4727	1	3	t	\N	1	t
693	2024-02-22 02:09:00	6912	3	2	f	1	4	f
694	2024-01-23 08:21:00	3939	4	2	t	\N	4	t
695	2024-07-16 10:58:00	5952	4	3	t	\N	4	t
696	2024-03-12 00:53:00	1231	5	3	t	\N	2	t
697	2024-03-12 05:39:00	9751	2	2	f	\N	3	t
698	2024-05-11 07:15:00	3073	3	2	t	2	2	t
699	2024-03-19 18:09:00	5494	3	3	t	\N	1	t
700	2024-07-15 10:11:00	1745	1	2	f	\N	1	t
701	2024-04-08 03:33:00	1893	2	4	t	2	2	f
702	2024-04-18 09:58:00	5786	3	1	t	\N	2	t
703	2024-04-09 04:06:00	3068	5	4	f	2	1	t
704	2024-04-29 11:32:00	9042	2	1	f	\N	2	f
705	2024-02-10 04:14:00	2680	4	4	t	2	1	t
706	2024-02-15 23:08:00	1200	4	4	t	2	4	t
707	2024-03-11 11:50:00	5658	4	1	t	\N	2	t
708	2024-08-31 02:19:00	8690	3	3	f	\N	2	t
709	2024-01-29 13:35:00	8843	1	4	f	\N	1	f
710	2024-06-21 00:31:00	8216	5	4	f	\N	4	f
711	2024-08-13 03:37:00	6582	4	3	t	1	3	f
712	2024-07-10 17:16:00	4020	3	2	f	\N	4	t
713	2024-06-17 22:02:00	1841	5	2	t	\N	3	f
714	2024-07-17 01:14:00	5136	2	4	t	2	1	t
715	2024-08-30 23:21:00	8827	2	1	t	\N	3	t
716	2024-05-07 21:53:00	2869	4	4	f	1	1	t
717	2024-01-18 19:47:00	2070	2	1	t	2	4	f
718	2024-05-13 03:03:00	7565	4	2	t	\N	1	f
719	2024-05-28 09:24:00	9056	4	2	f	1	2	f
720	2024-08-15 13:24:00	2213	3	3	t	\N	2	f
721	2024-05-18 01:21:00	1878	2	2	f	\N	2	f
722	2024-05-08 08:38:00	3485	5	2	f	\N	2	f
723	2024-04-30 00:11:00	3444	3	2	t	1	1	t
724	2024-05-20 07:23:00	5978	3	3	t	2	3	t
725	2024-08-13 04:21:00	2395	5	1	f	\N	2	f
726	2024-08-27 07:58:00	5066	2	4	t	\N	3	t
727	2024-09-03 09:13:00	2940	3	4	f	\N	4	t
728	2024-08-26 19:37:00	7818	5	2	t	\N	2	t
729	2024-05-29 13:40:00	4697	4	1	f	2	3	f
730	2024-09-05 23:58:00	9561	5	1	f	1	3	t
731	2024-08-13 15:43:00	7232	5	4	f	\N	2	t
732	2024-05-17 23:59:00	8381	3	1	t	\N	1	f
733	2024-05-01 23:07:00	8253	3	1	f	\N	2	f
734	2024-02-28 11:51:00	5871	3	3	f	1	4	f
735	2024-07-09 03:19:00	8025	3	2	f	\N	3	t
736	2024-02-12 05:46:00	6003	1	3	t	\N	2	f
737	2024-06-28 18:12:00	1986	2	3	t	\N	1	f
738	2024-09-13 05:15:00	2625	3	4	f	\N	2	t
739	2024-05-29 03:38:00	4404	3	1	t	\N	1	t
740	2024-09-02 09:54:00	4457	3	1	t	\N	4	t
741	2024-03-31 00:48:00	5335	1	1	f	2	1	f
742	2024-07-03 04:44:00	2330	3	2	t	\N	2	t
743	2024-08-17 10:00:00	3573	3	4	t	\N	4	t
744	2024-01-11 18:02:00	4929	4	1	f	\N	2	f
745	2024-09-07 03:14:00	3847	2	4	t	\N	2	t
746	2024-05-28 01:20:00	2229	5	2	f	\N	4	t
747	2024-04-06 09:20:00	3564	4	1	t	\N	2	f
748	2024-09-08 01:27:00	1043	1	3	f	1	2	t
749	2024-09-08 19:17:00	7693	2	1	t	\N	2	t
750	2024-01-01 19:18:00	8381	2	2	t	2	1	t
751	2024-06-14 12:49:00	8699	3	4	f	\N	1	f
752	2024-01-28 15:55:00	5771	4	1	t	\N	4	f
753	2024-04-10 19:34:00	1534	4	3	f	\N	4	f
754	2024-08-31 19:24:00	4792	4	2	t	2	2	t
755	2024-02-06 19:30:00	5720	1	1	t	1	3	t
756	2024-09-12 21:23:00	5632	5	3	f	\N	2	t
757	2024-05-19 19:23:00	8438	1	2	f	1	1	f
758	2024-05-06 15:02:00	2166	1	1	f	\N	3	f
759	2024-08-02 01:59:00	4824	3	1	t	\N	1	t
760	2024-01-26 12:34:00	5334	5	4	f	2	4	t
761	2024-07-03 05:49:00	4241	3	1	f	\N	3	t
762	2024-02-10 18:23:00	7965	1	4	f	\N	1	f
763	2024-02-12 18:18:00	2880	5	4	f	\N	2	f
764	2024-06-10 13:04:00	9922	5	2	t	\N	3	f
765	2024-01-21 21:43:00	4683	1	3	t	2	3	f
766	2024-07-16 01:21:00	3441	4	4	t	\N	1	f
767	2024-08-06 01:31:00	5352	5	1	t	1	3	f
768	2024-04-26 03:16:00	3330	3	3	f	2	3	f
769	2024-09-16 06:06:00	2169	2	4	t	\N	2	t
770	2024-04-06 02:22:00	1977	5	2	t	\N	4	t
771	2024-07-30 08:29:00	3718	4	4	f	\N	3	t
772	2024-03-25 18:11:00	6039	5	4	t	1	2	t
773	2024-02-24 07:59:00	5728	3	3	f	\N	1	f
774	2024-04-25 20:23:00	8195	3	4	f	\N	3	t
775	2024-02-23 02:50:00	3037	4	3	t	1	2	f
776	2024-04-05 16:26:00	8679	1	1	t	\N	1	f
777	2024-05-25 02:11:00	5982	3	3	f	2	3	f
778	2024-08-28 13:26:00	7594	2	3	f	\N	2	t
779	2024-07-05 07:50:00	5460	5	4	f	\N	1	t
780	2024-02-24 13:24:00	9199	1	4	f	\N	3	f
781	2024-03-16 03:42:00	9847	4	1	t	2	4	f
782	2024-06-19 01:03:00	9090	1	4	f	\N	1	t
783	2024-08-24 01:49:00	8172	2	2	f	2	4	t
784	2024-09-09 21:22:00	2317	2	3	f	\N	4	f
785	2024-08-15 22:58:00	1653	4	2	t	\N	1	f
786	2024-08-04 02:21:00	8078	1	4	f	\N	4	t
787	2024-02-07 10:04:00	6280	4	4	f	\N	4	t
788	2024-01-18 15:26:00	5102	5	3	f	\N	2	t
789	2024-08-18 09:09:00	1423	1	2	t	\N	3	f
790	2024-04-23 14:52:00	2496	2	1	t	2	3	f
791	2024-02-13 21:48:00	4750	5	4	t	2	2	t
792	2024-05-24 13:29:00	1339	4	1	f	\N	3	f
793	2024-05-15 08:32:00	5415	5	1	t	2	2	t
794	2024-07-05 00:15:00	1659	1	2	f	1	1	f
795	2024-06-05 12:01:00	3870	1	4	t	\N	2	t
796	2024-02-17 11:27:00	8708	1	2	f	\N	4	f
797	2024-07-19 18:21:00	9502	1	3	f	\N	4	t
798	2024-07-04 08:01:00	8245	1	3	t	\N	2	f
799	2024-08-19 11:21:00	5557	3	2	f	\N	2	f
800	2024-01-10 02:35:00	3973	5	1	t	\N	3	t
801	2024-02-11 15:16:00	8141	5	2	f	\N	2	t
802	2024-09-13 09:16:00	9056	5	2	f	2	2	f
803	2024-03-05 02:05:00	2494	3	1	t	\N	4	f
804	2024-02-29 19:42:00	8700	3	1	t	\N	1	t
805	2024-02-29 14:45:00	6700	1	2	t	\N	2	f
806	2024-03-05 22:11:00	7690	2	4	f	2	1	t
807	2024-04-11 04:54:00	6460	1	1	t	\N	4	f
808	2024-05-18 22:42:00	6260	5	4	f	\N	3	t
809	2024-07-15 07:39:00	2713	5	3	t	2	2	t
810	2024-01-15 13:59:00	3634	5	3	t	\N	4	t
811	2024-08-05 01:24:00	6403	3	3	t	\N	3	f
812	2024-08-09 04:25:00	7744	2	4	t	\N	4	f
813	2024-05-03 05:02:00	9117	2	2	t	1	4	f
814	2024-01-06 21:13:00	5722	5	1	f	\N	1	t
815	2024-02-14 13:15:00	7561	2	3	t	\N	3	f
816	2024-02-10 19:03:00	1601	4	4	t	\N	3	f
817	2024-01-01 19:34:00	8451	3	1	f	2	3	f
818	2024-02-21 13:54:00	2442	5	1	f	2	3	f
819	2024-02-20 19:55:00	6153	5	2	f	\N	1	f
820	2024-09-06 15:38:00	5135	1	1	f	\N	2	t
821	2024-09-04 16:27:00	6296	2	2	t	\N	2	f
822	2024-02-07 05:47:00	2899	2	2	f	\N	3	t
823	2024-05-23 06:11:00	7622	2	4	f	1	3	f
824	2024-05-06 10:47:00	9431	1	1	t	2	3	t
825	2024-03-20 04:36:00	1018	4	4	t	\N	4	t
826	2024-05-06 16:39:00	9889	2	1	t	\N	2	f
827	2024-08-03 03:06:00	8569	4	3	f	\N	3	f
828	2024-05-11 09:53:00	7770	1	1	t	\N	2	f
829	2024-04-08 21:00:00	1888	5	2	t	\N	1	t
830	2024-01-25 06:01:00	4073	2	4	f	2	3	t
831	2024-03-19 23:42:00	9494	5	4	t	\N	1	f
832	2024-02-07 11:48:00	6927	2	4	t	1	2	t
833	2024-02-16 00:05:00	9167	1	1	f	\N	2	f
834	2024-08-04 03:59:00	8242	1	4	f	\N	3	t
835	2024-05-14 21:11:00	1845	4	3	f	2	2	t
836	2024-09-13 10:41:00	4335	1	3	t	\N	4	t
837	2024-06-14 07:45:00	5375	2	1	f	\N	1	f
838	2024-08-25 18:15:00	9998	5	2	f	\N	1	t
839	2024-08-04 04:40:00	3146	1	1	f	\N	3	f
840	2024-07-26 01:19:00	5719	1	3	t	\N	4	f
841	2024-02-10 03:15:00	8178	1	4	f	1	2	f
842	2024-01-24 01:48:00	8941	2	4	f	1	3	f
843	2024-01-11 19:48:00	2989	1	4	f	\N	1	f
844	2024-08-28 19:57:00	1472	3	1	t	1	2	f
845	2024-06-28 05:48:00	4920	3	3	t	2	3	f
846	2024-07-29 14:33:00	3594	4	1	f	2	4	t
847	2024-03-21 01:39:00	6091	1	4	f	\N	3	f
848	2024-01-22 14:45:00	1224	5	2	t	1	2	f
849	2024-02-28 11:16:00	7684	4	4	t	\N	4	t
850	2024-02-16 01:15:00	2527	4	1	f	\N	2	f
851	2024-03-17 17:40:00	4681	4	1	t	\N	4	f
852	2024-07-25 23:36:00	2858	4	3	t	\N	2	t
853	2024-02-25 03:07:00	8560	2	3	t	2	3	t
854	2024-09-09 17:53:00	2924	3	2	f	1	1	f
855	2024-03-10 22:57:00	3522	2	4	f	\N	3	t
856	2024-01-14 11:05:00	9165	5	2	f	1	3	f
857	2024-07-26 02:46:00	5781	1	3	t	1	4	f
858	2024-01-08 19:44:00	9337	2	4	f	2	2	f
859	2024-07-18 15:59:00	5479	3	3	f	\N	2	t
860	2024-06-17 12:47:00	7807	1	1	f	2	2	t
861	2024-06-27 09:09:00	8905	5	3	t	\N	3	t
862	2024-05-26 05:40:00	8736	2	1	f	\N	2	f
863	2024-02-23 05:51:00	4993	3	4	t	\N	4	t
864	2024-01-03 12:22:00	8483	2	3	f	\N	3	t
865	2024-08-24 09:51:00	3369	4	3	f	\N	4	t
866	2024-01-03 15:00:00	7284	4	3	t	\N	2	f
867	2024-01-04 12:40:00	4122	3	3	t	\N	1	f
868	2024-02-28 22:32:00	9327	4	1	t	\N	1	f
869	2024-02-26 15:35:00	3236	3	2	t	2	1	f
870	2024-09-14 15:20:00	2143	2	2	t	1	4	f
871	2024-08-19 00:58:00	5526	4	3	t	\N	4	f
872	2024-01-12 16:42:00	7798	3	2	f	2	2	f
873	2024-06-21 03:03:00	6568	3	2	t	2	4	f
874	2024-05-17 12:49:00	9318	5	3	f	1	2	f
875	2024-04-06 17:29:00	5377	3	3	f	\N	2	t
876	2024-02-04 18:47:00	1042	4	2	f	\N	4	t
877	2024-01-29 10:43:00	5634	1	4	t	\N	2	f
878	2024-08-01 06:11:00	5891	2	2	t	\N	4	f
879	2024-09-16 01:11:00	9022	2	4	f	1	4	f
880	2024-03-13 09:05:00	3434	4	2	f	\N	1	f
881	2024-02-26 04:38:00	8316	1	2	f	\N	4	f
882	2024-05-23 06:03:00	9824	4	1	t	\N	4	t
883	2024-04-09 07:05:00	8935	4	4	t	\N	1	f
884	2024-08-12 15:51:00	6654	2	1	f	\N	1	t
885	2024-05-03 16:09:00	6446	4	4	t	1	2	t
886	2024-05-09 10:54:00	9903	1	4	t	\N	4	f
887	2024-02-04 22:05:00	7180	3	1	t	2	2	f
888	2024-08-16 02:58:00	8460	1	3	t	\N	1	t
889	2024-01-28 00:09:00	6272	5	2	f	\N	3	f
890	2024-04-01 15:04:00	4090	1	1	t	\N	1	t
891	2024-07-24 22:33:00	4912	4	1	f	2	4	t
892	2024-06-06 17:27:00	7274	4	1	t	\N	2	f
893	2024-08-15 00:04:00	4826	3	4	t	\N	2	f
894	2024-05-29 18:16:00	7730	3	2	t	1	3	f
895	2024-03-08 01:54:00	1715	1	1	t	2	1	t
896	2024-07-06 16:29:00	6213	1	1	f	\N	3	f
897	2024-08-11 02:55:00	8749	2	3	f	1	2	t
898	2024-01-18 19:52:00	7246	3	3	f	\N	1	f
899	2024-06-01 19:28:00	7325	4	1	t	\N	2	t
900	2024-01-02 20:59:00	3492	1	4	f	\N	4	t
901	2024-07-17 05:13:00	9115	4	4	t	\N	4	f
902	2024-04-02 15:54:00	1606	5	1	t	2	4	f
903	2024-03-23 05:53:00	3068	3	3	f	1	2	t
904	2024-03-15 13:24:00	9229	3	1	t	\N	2	t
905	2024-09-16 14:35:00	6439	4	3	f	1	4	f
906	2024-07-07 11:43:00	2644	1	4	f	1	2	f
907	2024-06-25 09:45:00	8213	2	4	f	\N	3	f
908	2024-01-30 07:50:00	2633	1	1	f	\N	1	t
909	2024-04-16 14:14:00	9617	1	4	t	2	1	f
910	2024-09-13 10:25:00	8486	3	1	f	\N	2	t
911	2024-01-10 23:25:00	1251	2	4	f	2	3	f
912	2024-05-28 14:29:00	3361	5	2	f	\N	2	t
913	2024-02-20 07:06:00	7717	3	2	t	\N	4	t
914	2024-02-05 03:52:00	3529	3	2	f	1	1	f
915	2024-03-28 16:53:00	2225	4	1	t	\N	3	t
916	2024-05-14 08:49:00	8692	4	1	f	1	3	t
917	2024-09-14 11:17:00	5342	3	2	t	\N	1	f
918	2024-05-11 01:40:00	6546	2	1	f	\N	2	t
919	2024-02-11 02:26:00	7512	2	1	f	2	2	t
920	2024-03-02 14:10:00	2315	1	1	t	\N	1	f
921	2024-05-05 19:16:00	6383	3	1	t	\N	4	f
922	2024-03-18 03:13:00	9742	5	3	t	\N	3	t
923	2024-08-03 18:49:00	7226	2	2	f	2	4	t
924	2024-01-20 17:45:00	6188	4	1	t	\N	3	t
925	2024-04-03 16:53:00	8994	1	4	f	\N	1	t
926	2024-03-26 09:17:00	9864	5	3	t	\N	1	t
927	2024-02-27 07:07:00	1588	1	1	f	\N	4	f
928	2024-01-12 19:39:00	2121	1	3	f	\N	2	f
929	2024-07-12 01:15:00	4846	4	4	f	\N	4	t
930	2024-05-04 00:15:00	5708	3	2	t	\N	3	f
931	2024-08-30 05:14:00	4727	1	2	t	\N	4	t
932	2024-06-05 00:44:00	2480	4	4	f	2	4	f
933	2024-09-15 13:32:00	8110	4	3	t	\N	1	t
934	2024-09-06 07:46:00	2612	4	4	t	\N	2	f
935	2024-03-20 15:12:00	2646	1	1	t	1	1	f
936	2024-01-24 02:48:00	8269	5	4	t	2	4	f
937	2024-07-20 14:26:00	3725	5	1	t	\N	4	t
938	2024-09-01 21:24:00	5906	1	1	t	\N	2	f
939	2024-07-23 10:07:00	1474	2	4	t	\N	2	t
940	2024-03-11 22:38:00	1753	2	1	f	2	4	t
941	2024-09-11 13:09:00	6314	1	2	f	\N	3	t
942	2024-08-28 02:13:00	1919	2	2	t	1	1	t
943	2024-03-23 11:05:00	5806	2	2	t	1	2	f
944	2024-09-05 18:02:00	6873	2	2	t	2	3	t
945	2024-04-14 16:53:00	7141	3	2	t	\N	4	t
946	2024-03-22 06:09:00	8056	4	2	f	\N	3	f
947	2024-08-28 23:02:00	3385	1	2	t	1	4	t
948	2024-08-13 18:10:00	5000	4	2	f	\N	4	f
949	2024-03-31 10:03:00	9702	2	3	t	\N	2	f
950	2024-03-16 14:20:00	7751	2	2	t	\N	4	t
951	2024-03-14 21:15:00	3950	5	4	t	\N	1	t
952	2024-03-13 11:46:00	3785	2	3	f	2	1	t
953	2024-05-30 12:37:00	3868	4	3	f	\N	4	t
954	2024-08-01 17:44:00	2293	2	4	t	\N	2	t
955	2024-01-05 01:49:00	7267	2	2	f	\N	4	f
956	2024-06-16 05:28:00	4945	4	4	f	\N	1	t
957	2024-07-15 12:00:00	9153	1	1	f	\N	2	f
958	2024-03-22 13:00:00	3344	3	3	f	\N	1	t
959	2024-08-05 17:53:00	4804	5	2	f	2	4	f
960	2024-03-05 06:55:00	8555	4	3	f	\N	2	t
961	2024-06-17 14:34:00	5161	5	1	t	\N	1	t
962	2024-05-25 00:42:00	8529	2	1	t	\N	1	f
963	2024-08-04 23:09:00	5183	1	4	t	\N	1	t
964	2024-07-06 02:49:00	1153	4	2	t	\N	3	f
965	2024-03-17 09:55:00	8622	4	1	f	\N	3	f
966	2024-07-12 01:45:00	5712	3	4	t	1	2	f
967	2024-06-12 10:53:00	9955	1	4	f	1	3	t
968	2024-01-19 05:47:00	3588	3	3	t	\N	1	f
969	2024-03-21 08:04:00	2210	4	4	t	\N	1	t
970	2024-09-12 17:24:00	8237	1	4	t	1	3	f
971	2024-05-14 09:39:00	6661	2	4	f	\N	4	t
972	2024-05-29 11:54:00	5901	5	4	f	\N	1	t
973	2024-08-29 18:31:00	7951	3	4	t	2	4	t
974	2024-06-02 18:26:00	5097	3	4	f	2	3	t
975	2024-08-14 00:11:00	8484	3	1	t	2	4	f
976	2024-07-17 00:20:00	5949	1	2	t	\N	1	t
977	2024-09-01 21:15:00	4263	4	1	t	\N	3	f
978	2024-05-18 14:15:00	7302	3	3	t	\N	1	t
979	2024-06-23 22:40:00	8916	4	2	t	\N	2	t
980	2024-06-15 21:29:00	2747	4	4	t	\N	4	f
981	2024-02-05 14:20:00	4886	3	2	t	\N	3	t
982	2024-08-17 22:04:00	7248	4	1	t	\N	3	t
983	2024-03-13 09:54:00	6881	1	1	t	\N	3	t
984	2024-07-15 19:10:00	5847	4	4	f	\N	1	f
985	2024-07-27 01:43:00	5837	1	4	f	\N	1	t
986	2024-08-15 22:27:00	1359	5	2	t	\N	1	t
987	2024-01-26 06:21:00	7484	5	2	f	\N	4	f
988	2024-04-05 05:57:00	5497	3	3	f	1	4	t
989	2024-02-03 15:05:00	1132	3	4	t	\N	4	t
990	2024-02-09 02:13:00	1803	5	4	t	\N	3	f
991	2024-04-02 11:10:00	9138	2	3	t	\N	4	f
992	2024-06-20 11:30:00	5689	4	4	t	1	1	t
993	2024-07-11 20:55:00	4770	4	3	t	\N	3	f
994	2024-04-29 19:02:00	6772	4	2	t	\N	2	f
995	2024-07-25 17:32:00	4588	3	4	t	2	3	t
996	2024-07-05 10:37:00	4115	3	4	f	2	3	t
997	2024-06-11 22:02:00	5106	1	1	f	1	1	f
998	2024-05-03 21:34:00	3240	3	4	t	\N	2	t
999	2024-04-25 12:19:00	2591	2	1	t	\N	2	t
1000	2024-07-05 14:15:00	1645	4	4	t	\N	4	t
1001	2024-02-04 13:09:00	6061	2	3	f	2	1	t
1002	2024-03-11 23:26:00	8222	2	1	f	\N	4	t
1003	2024-04-13 10:13:00	1546	4	1	t	1	3	t
1004	2024-06-15 14:08:00	6977	5	2	t	\N	3	f
1005	2024-05-24 22:24:00	3153	3	1	f	1	4	t
1006	2024-08-01 01:55:00	2476	4	3	t	\N	2	t
1007	2024-08-21 21:23:00	5835	5	1	t	\N	3	f
1008	2024-01-14 17:49:00	6352	3	3	f	\N	4	t
1009	2024-04-03 17:53:00	7807	4	2	f	\N	2	f
1010	2024-06-22 14:40:00	3877	3	1	f	2	4	f
1011	2024-06-28 13:57:00	4289	2	1	t	2	1	f
1012	2024-01-09 13:29:00	3165	3	3	t	2	4	f
1013	2024-04-30 10:06:00	9837	3	2	t	2	3	t
1014	2024-01-01 04:05:00	6994	2	1	t	\N	2	f
1015	2024-01-31 10:29:00	9697	5	3	f	\N	2	t
1016	2024-06-10 17:24:00	9221	5	1	t	1	4	f
1017	2024-05-22 10:04:00	5465	3	1	t	\N	3	t
1018	2024-07-19 12:29:00	3695	2	3	t	\N	2	t
1019	2024-08-05 13:13:00	5210	5	2	t	2	3	f
1020	2024-03-03 21:57:00	8894	1	3	t	1	1	t
1021	2024-01-21 02:15:00	5835	4	2	f	\N	3	f
1022	2024-05-21 10:35:00	6549	4	3	f	1	2	f
1023	2024-02-21 02:51:00	2886	3	3	f	\N	3	t
1024	2024-08-29 10:46:00	8673	4	3	t	\N	4	f
1025	2024-07-29 23:46:00	2233	5	2	t	1	4	f
1026	2024-02-11 00:02:00	3306	3	3	f	\N	2	f
1027	2024-03-31 05:52:00	4696	2	3	t	\N	2	t
1028	2024-01-04 06:13:00	7511	5	4	f	2	4	f
1029	2024-05-20 05:30:00	6992	2	1	f	\N	2	f
1030	2024-09-08 07:14:00	2479	3	3	t	\N	1	t
1031	2024-03-07 21:06:00	7464	5	1	f	\N	1	t
1032	2024-08-12 04:32:00	1228	1	4	t	2	2	f
1033	2024-01-28 23:17:00	5332	5	3	t	1	4	t
1034	2024-06-21 21:14:00	9791	1	2	t	\N	1	t
1035	2024-04-09 23:58:00	3024	1	4	f	\N	3	f
1036	2024-03-15 13:48:00	8451	3	4	f	1	1	t
1037	2024-04-06 17:06:00	7038	5	1	f	\N	2	t
1038	2024-06-05 10:50:00	5295	3	1	f	2	1	f
1039	2024-07-25 02:45:00	7242	4	2	t	2	4	f
1040	2024-05-26 22:44:00	7086	3	2	t	\N	4	t
1041	2024-07-02 01:55:00	2775	5	3	t	\N	1	t
1042	2024-03-18 10:39:00	4830	2	4	t	\N	1	t
1043	2024-08-08 10:57:00	8724	2	1	t	\N	4	t
1044	2024-04-29 13:49:00	1410	3	4	f	\N	1	t
1045	2024-03-04 23:08:00	6374	1	3	f	\N	3	t
1046	2024-08-30 18:02:00	4626	3	2	f	1	3	t
1047	2024-02-23 08:54:00	2035	5	3	f	\N	3	t
1048	2024-01-02 13:12:00	8606	1	2	f	1	3	t
1049	2024-09-02 12:45:00	5951	5	3	f	1	4	f
1050	2024-03-11 22:28:00	7689	3	4	t	\N	2	f
1051	2024-03-20 01:46:00	2911	2	2	t	\N	3	f
1052	2024-08-03 11:43:00	3290	2	4	f	\N	3	t
1053	2024-02-22 03:01:00	1742	2	1	t	\N	1	f
1054	2024-03-31 14:32:00	1609	1	3	t	2	2	f
1055	2024-04-14 02:30:00	5986	1	2	t	1	4	t
1056	2024-02-14 03:26:00	9071	4	3	t	2	1	f
1057	2024-08-01 02:58:00	2902	4	1	f	\N	4	f
1058	2024-07-05 04:25:00	2592	4	3	f	1	3	f
1059	2024-07-08 23:56:00	4846	2	1	t	1	4	t
1060	2024-03-06 10:21:00	9807	2	1	t	\N	1	f
1061	2024-01-10 15:44:00	3222	4	2	f	\N	3	t
1062	2024-01-07 08:10:00	7367	1	3	f	1	3	t
1063	2024-04-22 11:11:00	8432	5	1	t	1	2	f
1064	2024-07-17 01:39:00	7078	3	3	f	\N	4	f
1065	2024-08-11 03:55:00	9850	2	2	t	\N	2	f
1066	2024-05-17 06:56:00	7866	2	2	f	\N	3	f
1067	2024-05-03 13:51:00	3531	2	3	t	\N	3	f
1068	2024-09-15 12:57:00	7797	1	3	t	\N	4	f
1069	2024-02-29 18:55:00	2622	5	3	f	\N	4	f
1070	2024-08-26 06:13:00	9017	5	4	t	2	3	f
1071	2024-01-19 20:57:00	7686	4	3	t	\N	2	t
1072	2024-09-10 08:07:00	5583	5	2	f	\N	4	f
1073	2024-01-03 08:38:00	1536	1	3	f	\N	4	f
1074	2024-03-24 01:55:00	7070	1	2	t	\N	3	f
1075	2024-01-19 01:17:00	4559	5	3	f	\N	4	t
1076	2024-03-20 06:26:00	8264	4	3	t	\N	4	f
1077	2024-05-29 00:21:00	8285	5	1	f	1	3	f
1078	2024-03-30 01:32:00	4868	5	2	t	\N	3	t
1079	2024-03-25 21:39:00	6942	3	2	t	\N	1	f
1080	2024-07-04 22:56:00	2627	2	4	t	\N	1	t
1081	2024-09-09 11:38:00	7018	2	3	t	2	4	t
1082	2024-01-21 22:00:00	9920	1	2	f	1	4	f
1083	2024-01-05 18:31:00	6876	5	2	t	1	3	f
1084	2024-06-06 14:20:00	1992	1	2	f	\N	2	t
1085	2024-07-03 11:31:00	7523	3	1	f	\N	4	t
1086	2024-08-28 23:43:00	5520	3	1	t	\N	4	f
1087	2024-08-28 08:29:00	4109	4	4	f	1	4	t
1088	2024-08-15 20:31:00	3001	3	2	t	\N	2	t
1089	2024-04-04 06:12:00	8450	1	4	t	\N	4	t
1090	2024-03-18 00:04:00	2501	4	3	t	\N	2	f
1091	2024-01-13 08:36:00	4475	3	2	f	\N	3	t
1092	2024-01-14 04:45:00	1349	1	1	f	1	4	t
1093	2024-02-03 03:11:00	1828	1	1	t	\N	3	t
1094	2024-04-22 07:02:00	6464	5	1	f	\N	2	t
1095	2024-08-31 18:00:00	4990	3	4	t	\N	4	f
1096	2024-01-25 03:42:00	3063	2	2	t	\N	4	t
1097	2024-08-31 23:30:00	4362	4	3	f	\N	3	t
1098	2024-07-05 03:15:00	2124	5	1	f	2	2	t
1099	2024-03-09 17:46:00	4394	2	1	t	\N	1	f
1100	2024-04-13 13:25:00	4538	3	2	f	\N	4	f
1101	2024-06-14 08:04:00	4817	1	2	f	\N	3	t
1102	2024-07-09 17:23:00	6383	1	3	t	2	3	f
1103	2024-06-13 03:51:00	3417	4	4	f	\N	2	t
1104	2024-04-05 05:55:00	1046	5	1	f	2	1	f
1105	2024-02-14 04:24:00	5542	5	3	f	\N	4	f
1106	2024-02-26 01:43:00	3370	3	3	t	1	4	f
1107	2024-06-24 09:15:00	3129	2	1	f	\N	1	t
1108	2024-04-19 20:55:00	9850	3	3	t	\N	3	t
1109	2024-06-29 17:29:00	5106	1	2	t	\N	1	f
1110	2024-03-07 01:39:00	3858	2	2	t	2	1	t
1111	2024-03-28 16:02:00	2801	5	3	t	\N	1	f
1112	2024-05-08 04:23:00	1422	3	2	f	\N	4	t
1113	2024-07-20 13:18:00	3159	5	1	f	\N	2	t
1114	2024-09-11 20:58:00	1243	4	2	f	\N	3	f
1115	2024-08-02 02:19:00	6869	4	3	f	1	1	f
1116	2024-08-09 11:38:00	4898	3	3	t	\N	1	t
1117	2024-09-08 06:34:00	6304	5	3	t	\N	2	t
1118	2024-02-02 07:42:00	1258	2	3	f	\N	1	f
1119	2024-04-01 23:54:00	3854	5	4	f	1	4	t
1120	2024-05-13 14:05:00	5347	4	2	t	\N	3	t
1121	2024-01-03 11:31:00	1858	5	2	t	2	2	t
1122	2024-01-19 17:32:00	3076	5	4	f	\N	1	f
1123	2024-05-21 17:01:00	7897	1	3	f	1	1	t
1124	2024-01-17 03:04:00	9619	2	2	t	\N	2	t
1125	2024-08-27 21:49:00	2862	2	4	t	\N	1	f
1126	2024-05-10 01:59:00	2041	5	1	f	1	2	f
1127	2024-02-20 10:24:00	8802	4	3	t	\N	3	t
1128	2024-04-05 10:57:00	8344	1	3	t	2	4	f
1129	2024-01-28 09:20:00	6931	1	1	t	\N	3	f
1130	2024-01-15 09:00:00	9408	4	2	t	\N	1	t
1131	2024-03-16 01:06:00	2786	3	4	f	\N	1	t
1132	2024-03-02 20:53:00	8405	3	2	f	\N	4	t
1133	2024-09-09 03:46:00	9254	2	3	t	1	4	f
1134	2024-05-30 15:23:00	4629	4	1	t	1	4	t
1135	2024-07-28 14:57:00	1710	5	3	f	\N	4	f
1136	2024-02-23 10:37:00	9543	3	2	t	\N	3	f
1137	2024-02-03 07:21:00	5941	4	3	f	\N	3	f
1138	2024-08-08 16:22:00	8504	2	2	f	\N	1	t
1139	2024-09-06 21:47:00	1510	2	3	t	\N	1	t
1140	2024-06-08 03:20:00	1996	5	3	t	\N	3	t
1141	2024-04-07 18:51:00	8847	3	4	f	\N	1	t
1142	2024-08-12 23:23:00	7580	2	1	t	\N	2	f
1143	2024-05-23 09:50:00	7984	5	4	t	2	4	f
1144	2024-06-28 07:40:00	2768	1	2	t	\N	1	f
1145	2024-05-06 19:19:00	9032	2	1	t	\N	4	t
1146	2024-03-25 23:32:00	8267	4	4	f	\N	2	t
1147	2024-02-26 05:16:00	2204	3	1	f	\N	2	t
1148	2024-06-28 02:50:00	2323	2	2	f	\N	3	f
1149	2024-08-01 17:27:00	6277	5	4	t	1	3	f
1150	2024-09-16 20:22:00	3430	2	4	t	\N	4	f
1151	2024-09-07 06:52:00	2076	4	2	f	2	2	t
1152	2024-03-07 03:04:00	3067	4	4	f	\N	3	f
1153	2024-05-08 03:49:00	5505	4	2	t	\N	4	t
1154	2024-07-15 10:55:00	9984	3	4	t	\N	3	f
1155	2024-08-29 11:57:00	6327	4	2	f	\N	1	t
1156	2024-07-17 18:27:00	7240	5	1	t	\N	3	t
1157	2024-02-28 00:34:00	9692	2	1	t	\N	1	t
1158	2024-01-10 08:37:00	5831	2	3	t	2	3	t
1159	2024-07-11 20:09:00	8433	2	2	t	\N	3	f
1160	2024-08-26 03:50:00	9282	4	4	f	2	2	f
1161	2024-01-06 00:01:00	8048	5	4	t	\N	3	t
1162	2024-05-29 17:09:00	2624	4	2	f	\N	2	t
1163	2024-04-15 18:08:00	2874	3	4	f	\N	2	t
1164	2024-02-24 06:00:00	4522	3	3	f	1	4	f
1165	2024-08-11 18:54:00	8046	1	1	f	1	2	f
1166	2024-03-08 23:16:00	8398	5	1	t	\N	4	f
1167	2024-02-22 16:18:00	4743	4	3	t	\N	3	f
1168	2024-04-12 04:09:00	7779	2	3	f	1	1	f
1169	2024-09-11 08:29:00	6553	3	4	t	\N	3	f
1170	2024-03-08 08:35:00	8430	4	1	f	1	2	f
1171	2024-04-01 20:51:00	7532	3	3	f	\N	3	f
1172	2024-02-20 02:34:00	7815	3	2	t	\N	2	t
1173	2024-03-28 01:56:00	2557	3	1	f	2	1	t
1174	2024-07-24 17:51:00	6120	2	3	t	\N	2	t
1175	2024-08-17 11:29:00	7992	4	3	t	1	3	f
1176	2024-01-01 22:23:00	6120	4	1	f	2	2	t
1177	2024-04-05 03:38:00	5176	2	1	f	1	2	t
1178	2024-04-01 02:39:00	7132	5	1	f	1	4	f
1179	2024-07-05 17:41:00	3500	2	2	f	1	3	t
1180	2024-08-25 18:31:00	8770	4	3	t	\N	3	t
1181	2024-05-05 03:57:00	2099	4	3	t	\N	1	f
1182	2024-02-24 10:16:00	2494	5	4	f	\N	2	f
1183	2024-07-10 17:01:00	2398	2	2	t	\N	1	t
1184	2024-04-06 17:45:00	2527	4	3	f	\N	2	t
1185	2024-04-02 11:56:00	8075	3	4	f	\N	3	f
1186	2024-06-19 03:58:00	2582	5	2	f	1	2	t
1187	2024-06-25 18:29:00	7105	5	1	t	1	2	f
1188	2024-05-14 07:42:00	3131	5	2	f	\N	4	t
1189	2024-05-31 01:51:00	1982	3	1	t	\N	3	f
1190	2024-08-11 09:39:00	6400	4	2	t	1	3	f
1191	2024-04-19 14:37:00	3002	1	2	f	\N	3	t
1192	2024-07-22 10:43:00	7730	4	1	f	\N	3	t
1193	2024-04-05 22:16:00	6793	5	2	f	\N	2	t
1194	2024-08-24 09:02:00	7929	4	4	t	\N	2	t
1195	2024-08-26 08:23:00	1842	1	2	f	\N	4	t
1196	2024-07-31 02:42:00	5712	5	3	t	\N	3	f
1197	2024-05-26 14:26:00	6119	3	3	t	\N	1	f
1198	2024-02-23 23:41:00	6761	4	1	f	\N	2	f
1199	2024-06-21 06:45:00	2697	5	3	f	1	2	t
1200	2024-06-30 14:34:00	9313	5	2	t	2	4	f
1201	2024-05-06 07:09:00	4485	2	2	t	\N	4	f
1202	2024-08-17 10:24:00	3535	5	3	f	1	2	t
1203	2024-01-28 07:30:00	8900	1	1	f	1	4	t
1204	2024-09-14 18:06:00	4674	5	1	t	2	2	t
1205	2024-04-12 06:19:00	2773	4	4	f	\N	3	t
1206	2024-05-04 04:25:00	6736	4	3	t	2	3	t
1207	2024-08-07 09:23:00	7022	1	4	f	\N	4	t
1208	2024-07-12 06:32:00	2882	2	3	t	\N	4	t
1209	2024-01-16 12:41:00	5564	2	1	f	\N	3	f
1210	2024-07-05 22:18:00	4705	2	4	t	\N	3	t
1211	2024-01-10 09:45:00	8030	3	1	t	2	2	t
1212	2024-05-12 04:05:00	1430	2	2	f	\N	3	f
1213	2024-04-25 17:45:00	5381	1	2	f	\N	3	f
1214	2024-07-06 00:28:00	1474	2	4	t	\N	2	t
1215	2024-01-18 06:16:00	3955	2	1	f	\N	3	t
1216	2024-03-09 14:50:00	5477	5	4	t	2	4	t
1217	2024-07-03 04:38:00	6062	3	3	t	\N	2	t
1218	2024-03-27 02:30:00	6567	3	3	f	\N	1	t
1219	2024-06-10 06:05:00	6751	1	1	t	\N	3	t
1220	2024-08-30 06:11:00	1100	3	1	f	2	2	f
1221	2024-07-23 11:27:00	3972	1	2	t	\N	4	f
1222	2024-04-23 12:02:00	3347	3	1	t	\N	4	t
1223	2024-07-31 10:18:00	7566	5	3	t	\N	3	t
1224	2024-06-24 07:32:00	2140	4	4	t	2	4	t
1225	2024-03-13 14:01:00	3324	3	3	t	\N	4	f
1226	2024-04-17 11:30:00	1502	4	3	t	2	3	f
1227	2024-06-22 18:30:00	2503	5	1	f	2	4	t
1228	2024-02-20 15:11:00	9691	4	2	t	1	2	f
1229	2024-07-16 08:38:00	4524	1	2	f	\N	3	t
1230	2024-06-25 05:51:00	7163	3	2	t	\N	1	t
1231	2024-06-21 01:32:00	7878	2	1	f	\N	4	f
1232	2024-03-14 23:49:00	8432	2	4	f	\N	4	f
1233	2024-04-16 08:45:00	6585	5	1	t	1	4	f
1234	2024-05-06 01:31:00	3578	1	3	f	\N	3	t
1235	2024-02-14 09:24:00	7062	2	2	f	\N	4	f
1236	2024-03-28 10:22:00	6105	5	3	f	\N	4	f
1237	2024-08-17 10:58:00	6314	2	1	t	\N	4	t
1238	2024-01-28 10:53:00	2391	3	1	t	2	1	f
1239	2024-08-23 13:25:00	1861	2	1	t	\N	4	f
1240	2024-01-11 17:06:00	3549	4	4	t	\N	4	t
1241	2024-01-09 12:34:00	3579	3	4	t	\N	4	f
1242	2024-03-30 18:49:00	1815	4	4	t	\N	2	t
1243	2024-02-04 06:44:00	2336	1	3	f	\N	1	f
1244	2024-09-13 06:11:00	5458	3	1	t	\N	4	f
1245	2024-04-10 22:45:00	8259	3	3	t	1	1	f
1246	2024-06-08 14:16:00	7947	5	4	t	\N	4	t
1247	2024-09-02 20:02:00	8957	1	1	f	\N	3	t
1248	2024-07-22 23:37:00	8242	5	1	t	1	1	t
1249	2024-03-19 01:25:00	7785	2	4	f	\N	2	f
1250	2024-08-07 18:34:00	5475	5	2	t	\N	2	t
1251	2024-04-24 00:42:00	4531	3	2	f	2	3	f
1252	2024-07-14 11:07:00	9394	5	3	t	2	2	t
1253	2024-06-04 10:04:00	2864	5	1	f	\N	4	t
1254	2024-07-29 01:15:00	6655	3	1	f	\N	3	t
1255	2024-07-06 01:28:00	8043	3	4	t	\N	3	f
1256	2024-04-09 22:31:00	2816	1	4	f	2	1	f
1257	2024-01-05 06:30:00	5640	1	3	t	2	2	f
1258	2024-03-03 18:58:00	8972	5	1	f	\N	4	f
1259	2024-05-14 03:09:00	9633	3	4	f	\N	4	t
1260	2024-08-05 07:47:00	6053	5	3	f	\N	2	f
1261	2024-06-24 18:47:00	1744	5	1	f	\N	4	f
1262	2024-08-17 13:49:00	4612	1	2	f	1	1	f
1263	2024-09-04 01:03:00	7475	2	2	t	1	4	f
1264	2024-06-23 08:40:00	1897	2	2	f	1	2	t
1265	2024-09-11 10:29:00	1125	3	4	f	\N	3	f
1266	2024-04-19 11:35:00	4349	4	1	f	\N	4	t
1267	2024-02-20 00:04:00	5938	3	3	f	2	3	f
1268	2024-07-19 21:36:00	4460	2	3	t	1	3	f
1269	2024-04-20 06:19:00	3248	2	4	f	\N	3	t
1270	2024-03-26 00:21:00	5186	4	1	f	\N	2	f
1271	2024-01-01 15:51:00	5742	2	4	f	\N	1	t
1272	2024-04-02 09:20:00	6375	2	1	t	\N	2	t
1273	2024-02-19 23:01:00	2965	5	4	t	\N	2	t
1274	2024-03-08 10:28:00	1126	3	4	t	\N	2	t
1275	2024-02-23 13:12:00	9149	4	1	t	\N	2	t
1276	2024-05-22 03:47:00	8055	3	3	f	\N	2	t
1277	2024-03-03 14:15:00	3878	3	4	f	\N	1	t
1278	2024-01-08 13:39:00	3116	2	4	f	2	3	t
1279	2024-06-02 18:09:00	7229	4	3	t	2	2	t
1280	2024-04-30 08:51:00	9725	5	2	t	\N	3	f
1281	2024-03-24 15:58:00	4770	5	4	t	\N	3	t
1282	2024-07-16 21:48:00	9196	1	2	t	\N	2	f
1283	2024-09-08 05:39:00	6802	1	2	t	1	3	f
1284	2024-05-27 11:50:00	2180	3	1	t	\N	1	f
1285	2024-09-13 02:39:00	7505	5	1	f	1	3	f
1286	2024-07-18 17:58:00	1693	4	2	t	\N	1	t
1287	2024-02-14 03:08:00	8147	3	3	f	2	4	f
1288	2024-08-04 09:49:00	1307	2	2	f	1	1	t
1289	2024-05-28 06:15:00	8532	4	2	f	\N	2	t
1290	2024-06-10 04:56:00	2275	4	1	f	\N	4	t
1291	2024-05-11 08:54:00	6129	5	4	f	\N	3	f
1292	2024-08-17 00:26:00	8033	2	1	t	\N	3	f
1293	2024-07-21 01:22:00	7626	5	1	f	1	3	t
1294	2024-01-22 07:01:00	7843	4	4	f	\N	1	t
1295	2024-02-10 23:45:00	5743	5	2	f	\N	4	t
1296	2024-06-13 07:20:00	2887	3	3	t	\N	4	t
1297	2024-08-19 13:21:00	7636	4	3	t	\N	3	t
1298	2024-02-01 23:05:00	1341	5	3	f	1	3	f
1299	2024-04-20 06:17:00	6321	5	3	f	1	1	t
1300	2024-04-30 21:18:00	3815	2	1	t	\N	3	t
1301	2024-06-11 03:57:00	8538	3	4	t	\N	1	f
1302	2024-04-11 17:22:00	6928	1	4	t	\N	2	t
1303	2024-08-17 17:30:00	2443	2	1	f	1	2	t
1304	2024-01-04 05:12:00	8155	1	2	t	2	3	f
1305	2024-09-07 17:36:00	2734	2	4	f	\N	4	f
1306	2024-01-04 06:39:00	4986	2	1	f	\N	1	f
1307	2024-04-28 05:44:00	8138	1	2	t	\N	1	t
1308	2024-04-30 11:39:00	7560	4	3	t	\N	1	t
1309	2024-04-27 22:16:00	9584	5	1	f	\N	2	f
1310	2024-06-04 12:55:00	2288	4	3	f	\N	3	t
1311	2024-09-12 11:28:00	7484	1	4	f	\N	1	t
1312	2024-01-20 13:31:00	6083	3	3	t	2	2	t
1313	2024-02-27 11:28:00	6562	4	2	t	\N	4	t
1314	2024-01-16 01:01:00	4630	1	1	f	1	4	f
1315	2024-08-14 22:06:00	6456	5	3	t	\N	2	t
1316	2024-07-10 00:41:00	3754	4	1	t	\N	4	f
1317	2024-07-07 02:56:00	2251	4	2	f	\N	3	t
1318	2024-09-02 14:37:00	9363	1	4	t	\N	1	f
1319	2024-04-14 08:54:00	2868	4	3	t	\N	1	f
1320	2024-04-10 03:58:00	9693	3	2	f	1	4	f
1321	2024-03-26 18:26:00	9355	5	2	f	\N	3	t
1322	2024-04-17 05:42:00	4176	3	1	f	1	2	t
1323	2024-07-17 04:05:00	6724	1	1	t	\N	1	f
1324	2024-01-28 05:15:00	6752	5	4	f	\N	3	f
1325	2024-05-14 05:28:00	3419	4	3	t	\N	2	f
1326	2024-01-05 03:14:00	4871	2	3	t	1	3	f
1327	2024-08-17 02:35:00	2684	1	3	f	1	2	t
1328	2024-08-05 15:36:00	3399	2	3	f	1	3	f
1329	2024-02-04 23:07:00	5193	5	1	t	\N	4	f
1330	2024-06-30 04:36:00	4232	5	4	t	\N	3	t
1331	2024-04-24 15:47:00	3842	5	2	t	1	2	f
1332	2024-09-10 03:23:00	3504	3	1	f	\N	1	t
1333	2024-01-16 10:33:00	2234	3	3	f	\N	3	t
1334	2024-05-17 01:30:00	3902	1	2	t	\N	3	t
1335	2024-05-29 15:06:00	9095	5	4	t	\N	3	f
1336	2024-05-13 11:07:00	8601	4	3	t	\N	4	f
1337	2024-03-02 18:16:00	8354	1	4	f	1	4	f
1338	2024-08-24 11:16:00	6295	1	1	t	\N	1	t
1339	2024-02-10 18:09:00	6179	2	4	t	\N	4	f
1340	2024-07-29 00:57:00	3473	2	2	t	\N	2	f
1341	2024-08-03 22:00:00	8205	5	3	t	\N	4	t
1342	2024-09-12 13:19:00	2118	4	1	t	1	2	t
1343	2024-05-17 21:58:00	8682	1	2	f	\N	1	t
1344	2024-01-22 17:39:00	8245	2	2	f	\N	4	f
1345	2024-06-25 23:30:00	5961	4	2	f	1	2	f
1346	2024-06-26 10:09:00	5500	3	1	t	\N	2	t
1347	2024-05-19 13:33:00	1920	4	2	t	\N	4	t
1348	2024-01-21 03:40:00	6766	5	1	f	1	2	f
1349	2024-03-29 17:45:00	9312	1	4	f	1	3	f
1350	2024-03-17 05:44:00	2215	1	2	t	1	4	t
1351	2024-02-20 12:07:00	6085	3	2	f	\N	3	f
1352	2024-04-06 20:46:00	8565	3	1	t	\N	1	t
1353	2024-04-28 17:21:00	8404	5	3	t	\N	2	t
1354	2024-06-06 05:55:00	1616	4	2	t	2	2	t
1355	2024-09-02 00:10:00	1932	3	3	f	\N	4	f
1356	2024-01-08 05:09:00	7041	3	3	t	1	2	t
1357	2024-08-09 04:08:00	5703	3	2	t	\N	4	f
1358	2024-06-09 05:31:00	2257	2	1	t	\N	1	t
1359	2024-07-23 06:54:00	2479	3	2	t	\N	3	f
1360	2024-06-02 21:17:00	9307	1	3	f	2	3	t
1361	2024-03-04 22:40:00	7299	2	4	t	\N	2	t
1362	2024-05-07 06:59:00	8581	3	3	f	\N	4	f
1363	2024-01-04 22:04:00	1672	4	4	t	\N	2	f
1364	2024-05-22 14:38:00	8368	5	3	f	\N	4	t
1365	2024-05-08 09:04:00	4084	4	2	f	\N	3	t
1366	2024-06-20 05:48:00	6267	4	2	t	2	4	f
1367	2024-08-05 14:30:00	8792	3	2	t	\N	4	t
1368	2024-07-27 13:03:00	9214	5	4	f	\N	4	f
1369	2024-05-27 02:08:00	3471	1	4	t	\N	1	f
1370	2024-09-16 03:45:00	2013	3	1	t	\N	4	f
1371	2024-05-06 13:38:00	8381	4	1	f	\N	3	t
1372	2024-04-26 10:22:00	2695	2	2	f	\N	4	f
1373	2024-09-07 09:36:00	6626	5	2	t	2	3	f
1374	2024-08-27 15:36:00	2381	4	1	f	\N	3	f
1375	2024-02-04 13:38:00	9266	1	1	f	\N	2	f
1376	2024-05-27 11:04:00	3827	3	4	t	\N	3	f
1377	2024-02-05 05:58:00	1641	4	2	t	\N	2	f
1378	2024-06-05 08:02:00	5059	2	1	f	\N	2	f
1379	2024-01-25 19:26:00	8172	2	3	t	1	3	t
1380	2024-04-01 17:55:00	8199	4	1	f	\N	3	f
1381	2024-08-01 21:55:00	9586	5	2	f	\N	1	t
1382	2024-04-21 23:13:00	9564	1	3	f	1	2	t
1383	2024-08-07 15:02:00	3600	2	3	t	2	4	t
1384	2024-04-17 06:10:00	6962	4	1	t	\N	1	t
1385	2024-08-24 19:00:00	7108	5	2	t	\N	3	f
1386	2024-02-13 09:35:00	5634	2	1	f	\N	3	f
1387	2024-07-18 16:03:00	7347	4	4	f	\N	1	t
1388	2024-06-20 06:41:00	7697	5	2	t	\N	4	t
1389	2024-06-16 09:19:00	6543	5	3	t	\N	4	t
1390	2024-01-10 11:08:00	1857	1	2	f	1	3	f
1391	2024-06-30 13:49:00	6482	4	4	f	\N	2	t
1392	2024-09-10 16:24:00	2079	1	3	f	\N	4	f
1393	2024-01-03 17:03:00	6401	5	4	t	1	2	f
1394	2024-03-21 04:13:00	2548	5	4	f	1	2	t
1395	2024-06-02 01:11:00	7333	5	1	f	\N	1	t
1396	2024-03-16 23:28:00	5655	1	4	f	\N	2	t
1397	2024-05-08 08:34:00	5128	2	1	t	\N	3	t
1398	2024-02-10 01:55:00	3463	4	2	t	\N	1	f
1399	2024-04-27 08:13:00	6461	5	3	t	2	1	f
1400	2024-03-22 20:48:00	2335	1	3	t	\N	3	f
1401	2024-02-25 14:09:00	3317	5	4	f	\N	1	t
1402	2024-03-12 05:55:00	6731	1	2	f	1	2	t
1403	2024-08-28 19:25:00	6082	3	1	t	\N	3	t
1404	2024-05-18 15:04:00	7421	1	3	t	2	3	t
1405	2024-04-30 16:56:00	3112	5	3	f	\N	4	t
1406	2024-06-30 18:47:00	2388	1	3	t	\N	3	t
1407	2024-05-11 21:02:00	6072	5	2	f	\N	3	t
1408	2024-08-25 06:13:00	7171	4	4	f	\N	3	t
1409	2024-07-12 01:16:00	6381	5	3	t	\N	3	t
1410	2024-01-23 13:37:00	3093	5	2	f	1	4	t
1411	2024-05-15 17:53:00	9624	2	1	t	\N	3	f
1412	2024-04-11 11:24:00	2531	2	4	f	\N	4	t
1413	2024-08-29 13:49:00	7937	4	1	f	\N	1	f
1414	2024-02-29 18:23:00	9331	4	3	t	\N	1	t
1415	2024-02-16 18:06:00	6928	2	4	f	2	4	t
1416	2024-02-19 00:39:00	1298	1	3	f	2	1	f
1417	2024-02-14 09:36:00	6940	5	3	f	\N	4	t
1418	2024-08-30 23:05:00	6060	3	1	f	\N	3	t
1419	2024-04-21 13:00:00	3953	1	1	t	\N	1	t
1420	2024-08-23 00:49:00	4509	4	3	f	\N	1	t
1421	2024-02-05 22:57:00	6598	4	3	t	2	3	t
1422	2024-03-06 00:48:00	8967	4	3	f	\N	4	t
1423	2024-09-13 19:08:00	4145	4	1	t	\N	3	t
1424	2024-07-29 15:00:00	4711	5	4	t	\N	4	t
1425	2024-04-25 18:32:00	3253	5	3	f	\N	2	t
1426	2024-08-06 00:08:00	3538	3	3	f	\N	3	f
1427	2024-01-28 02:47:00	2264	1	4	t	\N	3	t
1428	2024-06-11 00:21:00	5846	4	2	f	\N	1	t
1429	2024-08-28 16:26:00	2657	2	2	f	2	2	t
1430	2024-01-02 05:48:00	9317	4	3	f	\N	2	t
1431	2024-04-06 17:16:00	9843	1	1	f	\N	4	t
1432	2024-08-23 09:53:00	9626	2	4	f	1	3	f
1433	2024-07-01 12:46:00	1618	5	4	t	\N	3	f
1434	2024-04-01 08:15:00	6517	5	4	f	2	1	t
1435	2024-05-08 20:04:00	3147	1	1	f	\N	1	f
1436	2024-05-26 15:23:00	7172	3	1	f	2	2	t
1437	2024-08-09 17:14:00	3527	4	4	t	\N	2	t
1438	2024-09-09 03:42:00	3658	1	1	t	\N	3	t
1439	2024-01-01 11:02:00	3962	4	1	f	\N	2	t
1440	2024-01-13 01:08:00	3712	3	4	f	2	2	f
1441	2024-09-15 00:04:00	8170	4	3	t	\N	2	t
1442	2024-05-10 18:28:00	1715	5	1	t	2	1	t
1443	2024-04-06 22:22:00	7731	4	1	t	\N	2	t
1444	2024-08-21 08:58:00	6968	4	4	t	2	1	f
1445	2024-02-05 09:33:00	4891	2	1	t	\N	3	t
1446	2024-01-30 21:15:00	8277	3	1	t	\N	1	f
1447	2024-03-29 05:21:00	5668	1	2	t	1	4	t
1448	2024-04-09 21:51:00	8355	3	1	f	\N	4	t
1449	2024-03-01 15:11:00	4833	4	2	t	1	2	t
1450	2024-02-02 10:58:00	9749	1	1	f	2	4	f
1451	2024-05-05 03:31:00	4918	5	3	t	\N	1	f
1452	2024-09-11 18:19:00	6070	1	3	t	\N	4	f
1453	2024-08-16 01:25:00	8684	2	4	f	\N	4	f
1454	2024-02-13 03:08:00	4178	2	4	f	\N	4	f
1455	2024-08-03 04:15:00	7026	5	4	t	\N	2	f
1456	2024-05-20 07:42:00	8218	3	3	t	\N	3	t
1457	2024-07-02 16:54:00	8564	5	2	f	1	2	t
1458	2024-06-30 21:25:00	5616	2	1	f	\N	4	f
1459	2024-08-06 09:06:00	7256	3	4	f	\N	3	t
1460	2024-09-10 04:21:00	9239	4	2	t	\N	1	f
1461	2024-06-28 12:04:00	9641	2	3	t	\N	4	t
1462	2024-05-12 11:52:00	7859	1	2	f	2	3	f
1463	2024-07-03 05:53:00	3655	4	3	f	\N	1	t
1464	2024-07-15 03:41:00	4271	3	3	f	1	4	t
1465	2024-04-13 23:11:00	3267	1	3	t	\N	1	t
1466	2024-01-29 01:41:00	5096	1	3	t	\N	3	t
1467	2024-02-05 05:40:00	1854	2	1	f	\N	4	f
1468	2024-04-03 09:07:00	8873	3	4	t	\N	1	f
1469	2024-06-04 06:07:00	7081	5	4	t	2	4	t
1470	2024-04-09 03:44:00	2680	5	3	f	\N	3	f
1471	2024-06-05 11:12:00	9452	4	3	t	\N	3	t
1472	2024-07-24 12:22:00	3042	3	4	f	\N	3	t
1473	2024-04-23 01:55:00	5670	5	1	f	\N	4	f
1474	2024-05-07 23:00:00	2374	4	3	t	2	3	f
1475	2024-03-25 09:01:00	3626	4	3	t	2	2	t
1476	2024-06-20 11:40:00	5469	3	2	f	\N	2	t
1477	2024-01-26 04:39:00	8361	1	4	f	\N	1	f
1478	2024-07-01 12:14:00	9410	4	4	t	\N	3	f
1479	2024-07-07 02:20:00	3414	4	3	t	\N	4	f
1480	2024-07-25 10:46:00	8167	2	1	t	\N	1	f
1481	2024-03-29 14:25:00	2502	3	3	t	\N	2	f
1482	2024-06-09 09:40:00	4637	1	2	f	1	1	f
1483	2024-01-18 05:38:00	8391	5	3	f	\N	2	t
1484	2024-01-19 13:12:00	6727	1	1	t	\N	3	f
1485	2024-06-07 13:02:00	1436	2	4	t	\N	1	f
1486	2024-06-06 00:46:00	7797	5	3	t	\N	2	t
1487	2024-08-22 08:25:00	1872	4	2	f	\N	3	t
1488	2024-07-28 19:13:00	7495	4	2	t	\N	4	t
1489	2024-08-04 07:59:00	9224	3	1	f	\N	1	f
1490	2024-08-10 17:33:00	7126	1	2	t	\N	1	f
1491	2024-02-01 16:44:00	4862	4	1	t	\N	1	f
1492	2024-03-09 10:48:00	7326	3	2	f	1	3	f
1493	2024-06-18 18:11:00	2337	4	4	t	1	4	t
1494	2024-06-17 03:00:00	7142	4	2	t	\N	1	f
1495	2024-01-01 00:54:00	4678	1	4	f	2	4	t
1496	2024-01-29 07:10:00	1461	2	1	t	1	2	f
1497	2024-01-27 21:03:00	6221	3	1	t	\N	4	t
1498	2024-05-09 06:13:00	2623	1	1	f	\N	4	t
1499	2024-05-14 04:08:00	6493	1	3	t	\N	3	f
1500	2024-08-16 18:01:00	3392	3	3	f	\N	2	t
1501	2024-06-03 14:20:00	3254	1	2	t	\N	1	f
1502	2024-05-09 07:02:00	1627	3	2	t	2	4	f
1503	2024-05-16 14:25:00	5700	2	2	t	2	2	t
1504	2024-04-13 03:47:00	8740	1	2	t	1	3	t
1505	2024-01-24 13:40:00	3273	2	2	t	\N	3	t
1506	2024-02-18 04:50:00	8685	3	1	f	2	1	t
1507	2024-07-03 15:38:00	8349	4	3	f	1	4	f
1508	2024-07-05 07:08:00	1086	1	2	t	\N	4	f
1509	2024-07-04 18:45:00	2298	1	1	f	\N	2	f
1510	2024-01-03 01:11:00	1311	1	3	t	\N	1	t
1511	2024-03-27 00:07:00	5193	4	1	t	\N	1	f
1512	2024-07-30 21:20:00	4533	5	4	t	\N	2	f
1513	2024-04-28 05:14:00	3449	2	2	f	\N	4	t
1514	2024-03-16 16:24:00	9991	3	3	f	\N	2	t
1515	2024-03-30 18:54:00	9647	2	2	f	2	4	t
1516	2024-08-11 03:46:00	7934	5	3	t	2	1	t
1517	2024-05-01 12:41:00	2821	5	2	f	2	3	f
1518	2024-02-18 11:52:00	5720	1	1	t	\N	3	f
1519	2024-04-01 07:20:00	4893	2	4	t	\N	4	t
1520	2024-07-07 01:06:00	5934	5	1	t	\N	2	t
1521	2024-05-17 00:47:00	2996	4	3	f	\N	1	t
1522	2024-04-13 04:32:00	1782	3	4	t	\N	3	t
1523	2024-01-20 01:29:00	4906	4	4	t	\N	3	f
1524	2024-08-05 15:05:00	7878	1	1	f	\N	2	t
1525	2024-04-24 00:50:00	8489	5	1	f	1	1	f
1526	2024-02-24 03:25:00	2029	2	2	f	\N	1	t
1527	2024-03-10 16:31:00	2816	4	3	f	\N	4	f
1528	2024-08-06 12:19:00	9189	4	1	t	\N	2	t
1529	2024-05-27 17:30:00	9782	5	3	t	\N	3	f
1530	2024-02-13 00:22:00	1269	1	1	t	\N	1	f
1531	2024-07-31 04:00:00	9443	5	2	t	\N	1	t
1532	2024-05-24 20:30:00	4963	1	2	t	\N	3	f
1533	2024-08-09 00:27:00	3352	4	2	f	\N	4	t
1534	2024-02-09 19:56:00	5772	1	1	f	\N	1	t
1535	2024-07-05 00:49:00	8032	1	2	t	\N	2	f
1536	2024-01-04 12:35:00	1025	2	2	t	2	1	f
1537	2024-02-09 11:06:00	6780	2	4	t	2	4	t
1538	2024-03-12 18:09:00	4941	3	1	t	1	2	t
1539	2024-03-19 20:49:00	7825	2	3	t	\N	3	t
1540	2024-01-19 06:05:00	4068	5	4	f	\N	4	t
1541	2024-07-15 22:00:00	2402	2	2	f	\N	4	f
1542	2024-07-11 01:53:00	9576	5	1	t	1	1	t
1543	2024-03-18 11:02:00	6908	2	4	f	2	1	f
1544	2024-07-22 11:07:00	2108	1	2	t	\N	1	t
1545	2024-04-11 17:48:00	9618	4	1	f	\N	1	t
1546	2024-08-05 08:32:00	9914	1	1	t	\N	3	f
1547	2024-04-08 03:48:00	9312	2	3	t	\N	4	f
1548	2024-09-14 05:26:00	9316	5	4	t	\N	1	f
1549	2024-02-02 07:31:00	1333	3	4	f	2	1	f
1550	2024-04-18 05:10:00	7397	4	4	f	\N	3	t
1551	2024-05-24 08:18:00	8702	1	2	t	\N	1	f
1552	2024-01-25 14:12:00	1713	2	2	t	\N	1	f
1553	2024-05-17 18:42:00	7338	1	4	t	\N	3	t
1554	2024-08-11 22:18:00	7116	4	3	f	\N	3	f
1555	2024-05-22 01:49:00	5155	3	2	f	\N	3	f
1556	2024-03-04 16:48:00	1266	2	4	t	\N	2	t
1557	2024-01-24 14:46:00	6850	2	2	t	2	3	t
1558	2024-02-18 04:14:00	2106	3	1	f	\N	3	t
1559	2024-02-12 12:52:00	6649	3	1	t	\N	2	t
1560	2024-05-26 09:03:00	4950	2	4	f	\N	4	f
1561	2024-07-23 00:37:00	2698	4	1	f	2	2	t
1562	2024-03-03 16:55:00	6447	2	1	t	\N	3	f
1563	2024-08-25 17:28:00	3185	5	2	t	\N	3	t
1564	2024-09-16 08:20:00	1726	2	1	f	\N	3	f
1565	2024-05-24 03:41:00	6772	1	2	t	\N	3	f
1566	2024-08-13 16:42:00	9945	3	4	f	\N	2	t
1567	2024-04-30 23:26:00	6546	1	3	f	\N	4	t
1568	2024-04-19 15:11:00	3868	4	2	t	2	2	t
1569	2024-08-09 00:43:00	8612	3	4	f	\N	2	f
1570	2024-07-29 20:58:00	8840	4	2	f	\N	4	t
1571	2024-05-17 14:04:00	3986	1	3	t	2	2	t
1572	2024-03-18 09:22:00	3209	5	1	t	\N	1	f
1573	2024-05-12 19:08:00	2033	5	3	t	2	4	t
1574	2024-08-03 19:49:00	8498	2	3	f	1	4	t
1575	2024-05-02 06:11:00	1605	1	4	f	2	1	f
1576	2024-08-25 09:40:00	5807	2	3	f	1	3	t
1577	2024-06-10 16:42:00	4302	4	3	t	\N	2	t
1578	2024-04-03 00:18:00	1717	1	1	f	\N	3	t
1579	2024-01-31 01:21:00	4268	1	3	t	2	1	t
1580	2024-01-27 21:01:00	1686	2	4	f	2	2	f
1581	2024-09-02 00:15:00	6170	3	2	t	1	2	f
1582	2024-02-07 05:06:00	6080	3	2	f	\N	1	f
1583	2024-04-29 00:27:00	9444	5	2	f	\N	4	f
1584	2024-05-27 08:21:00	7524	4	1	f	2	4	t
1585	2024-01-19 13:10:00	9897	2	1	t	\N	1	t
1586	2024-08-12 03:42:00	8756	1	2	f	2	1	f
1587	2024-09-13 05:46:00	5150	2	1	f	\N	1	t
1588	2024-01-08 19:28:00	1599	2	1	f	\N	3	t
1589	2024-01-15 11:02:00	4131	2	1	f	\N	4	t
1590	2024-02-20 15:18:00	5687	1	4	t	1	1	t
1591	2024-08-21 06:59:00	6848	2	4	f	\N	4	f
1592	2024-04-26 11:05:00	1783	5	1	t	\N	1	t
1593	2024-03-04 17:34:00	6438	4	1	f	\N	4	f
1594	2024-03-18 16:00:00	5476	4	2	t	\N	4	f
1595	2024-08-21 09:40:00	3039	1	4	t	1	4	t
1596	2024-03-11 08:47:00	7029	4	4	f	\N	2	t
1597	2024-04-21 20:20:00	8159	3	1	t	1	2	t
1598	2024-03-11 20:33:00	7553	5	4	f	2	4	f
1599	2024-05-22 10:16:00	8204	2	3	f	\N	3	t
1600	2024-03-03 18:11:00	7334	1	4	t	\N	2	t
1601	2024-04-13 20:35:00	6554	3	4	t	1	2	f
1602	2024-07-26 08:33:00	4060	4	3	t	\N	1	t
1603	2024-04-29 03:46:00	9129	3	4	t	\N	1	t
1604	2024-04-23 19:05:00	9151	5	4	f	\N	3	f
1605	2024-01-20 23:26:00	7018	3	4	t	\N	2	t
1606	2024-05-11 18:44:00	9507	3	1	t	\N	2	f
1607	2024-07-15 07:01:00	5369	4	2	t	\N	1	f
1608	2024-07-31 19:31:00	2353	4	1	f	\N	2	f
1609	2024-01-21 00:12:00	7955	4	4	f	\N	4	t
1610	2024-06-17 22:14:00	2293	1	4	f	\N	4	t
1611	2024-01-21 15:11:00	8055	5	3	t	1	1	t
1612	2024-06-25 14:29:00	3956	4	3	t	1	1	t
1613	2024-07-27 06:44:00	9937	3	3	t	\N	1	f
1614	2024-04-03 15:23:00	5813	2	1	f	\N	2	t
1615	2024-01-15 18:24:00	6262	5	3	f	\N	1	t
1616	2024-01-29 02:16:00	2680	2	4	t	\N	2	t
1617	2024-06-18 10:56:00	2311	3	3	t	1	4	f
1618	2024-02-16 20:37:00	6372	2	4	f	1	1	t
1619	2024-07-07 17:58:00	5843	3	3	f	\N	2	t
1620	2024-06-15 17:04:00	6021	3	2	t	2	1	t
1621	2024-08-16 10:19:00	8305	2	4	t	\N	4	f
1622	2024-05-14 04:53:00	7981	3	3	f	1	1	f
1623	2024-08-31 11:46:00	3730	2	2	f	\N	1	t
1624	2024-05-21 04:12:00	8272	1	3	t	\N	2	t
1625	2024-01-31 15:30:00	6759	5	1	t	\N	4	t
1626	2024-07-22 13:24:00	8325	5	2	f	\N	3	f
1627	2024-06-19 20:37:00	1693	3	2	t	\N	4	t
1628	2024-02-11 16:28:00	6776	4	1	f	\N	4	t
1629	2024-06-09 18:37:00	8126	3	1	f	2	2	t
1630	2024-03-30 18:00:00	5498	5	1	t	\N	1	f
1631	2024-04-10 22:40:00	1939	1	2	t	2	2	f
1632	2024-08-02 00:37:00	2229	2	3	t	\N	4	t
1633	2024-04-02 10:59:00	7655	4	3	t	\N	2	f
1634	2024-01-15 19:36:00	6952	2	3	t	\N	2	f
1635	2024-04-06 20:14:00	9406	5	3	t	2	3	f
1636	2024-06-27 16:18:00	3621	1	3	f	\N	2	t
1637	2024-03-03 05:54:00	1510	3	4	f	2	4	f
1638	2024-03-21 19:28:00	3339	1	2	f	1	3	f
1639	2024-08-08 18:07:00	8179	5	3	f	\N	2	t
1640	2024-02-22 14:34:00	1570	2	2	t	\N	1	f
1641	2024-02-27 20:42:00	3068	4	4	t	\N	3	f
1642	2024-07-19 18:22:00	2101	1	3	t	\N	1	t
1643	2024-04-26 03:13:00	4866	3	1	t	\N	2	f
1644	2024-01-04 08:57:00	7001	4	4	t	\N	1	t
1645	2024-04-17 11:53:00	6933	3	1	t	2	1	t
1646	2024-06-29 07:32:00	7272	4	3	f	\N	3	f
1647	2024-03-04 22:10:00	1530	2	1	t	\N	4	f
1648	2024-03-15 18:07:00	3513	1	2	t	2	3	t
1649	2024-04-07 00:38:00	8371	3	1	t	\N	1	t
1650	2024-03-30 08:40:00	7077	2	1	f	1	3	f
1651	2024-06-20 03:54:00	7095	2	3	t	\N	2	t
1652	2024-08-13 21:50:00	8273	1	4	f	\N	3	f
1653	2024-04-29 00:05:00	2259	5	3	t	\N	1	t
1654	2024-07-04 12:45:00	3255	4	2	t	\N	4	t
1655	2024-01-05 23:00:00	9674	1	4	t	\N	3	t
1656	2024-02-14 23:19:00	7012	4	3	f	1	3	t
1657	2024-08-25 18:37:00	7521	4	1	t	\N	2	t
1658	2024-03-07 09:10:00	6150	5	3	t	\N	3	f
1659	2024-01-03 13:16:00	5566	1	3	f	\N	1	f
1660	2024-02-14 02:54:00	5089	1	4	t	\N	2	f
1661	2024-08-18 16:03:00	2858	3	3	f	\N	2	t
1662	2024-05-02 18:39:00	1424	3	3	f	2	2	t
1663	2024-01-05 22:33:00	4048	5	3	f	\N	3	t
1664	2024-03-13 23:11:00	9176	4	2	t	\N	4	f
1665	2024-07-06 02:13:00	9482	1	1	f	\N	3	f
1666	2024-05-11 19:37:00	7340	3	2	t	\N	4	t
1667	2024-08-20 11:29:00	2929	2	1	f	1	1	f
1668	2024-05-22 20:33:00	5288	1	2	f	\N	4	t
1669	2024-07-12 14:09:00	5264	3	2	t	\N	3	f
1670	2024-09-11 04:44:00	8311	3	4	f	\N	1	f
1671	2024-01-08 09:08:00	4515	5	3	t	2	3	t
1672	2024-05-16 03:24:00	5678	5	1	t	\N	2	t
1673	2024-04-26 04:06:00	9047	5	2	f	\N	2	t
1674	2024-01-26 01:22:00	4279	5	3	t	\N	1	t
1675	2024-09-01 00:36:00	3009	3	4	f	2	4	f
1676	2024-09-09 13:58:00	3223	2	2	f	\N	2	f
1677	2024-07-03 04:49:00	2213	4	2	t	2	2	f
1678	2024-08-11 07:15:00	8406	1	4	f	\N	2	t
1679	2024-06-19 10:21:00	3828	4	2	t	\N	2	t
1680	2024-07-16 09:59:00	8292	3	2	f	2	4	f
1681	2024-07-23 04:51:00	2438	1	4	t	\N	1	f
1682	2024-06-01 13:37:00	6236	2	1	t	2	4	t
1683	2024-04-05 11:43:00	6692	3	1	t	\N	1	f
1684	2024-02-27 23:21:00	2063	3	3	f	\N	4	f
1685	2024-05-03 21:19:00	9882	1	1	f	2	4	f
1686	2024-01-04 10:51:00	5757	2	1	f	\N	4	f
1687	2024-01-20 13:50:00	5914	5	2	t	2	2	t
1688	2024-04-04 16:21:00	3580	5	1	t	\N	4	t
1689	2024-05-27 08:11:00	3852	5	2	f	\N	1	f
1690	2024-07-07 00:56:00	6922	1	2	t	\N	4	f
1691	2024-01-07 11:50:00	9335	5	2	t	\N	2	t
1692	2024-05-18 15:08:00	4673	1	4	t	\N	2	f
1693	2024-04-03 09:07:00	2988	1	4	f	\N	1	t
1694	2024-02-04 01:16:00	4292	1	1	t	1	1	f
1695	2024-02-27 13:19:00	3275	4	3	t	\N	2	t
1696	2024-03-08 03:08:00	4878	1	3	f	1	3	f
1697	2024-09-02 15:08:00	9094	1	2	t	\N	4	f
1698	2024-02-21 19:32:00	1430	5	3	t	\N	2	f
1699	2024-07-15 17:08:00	6912	2	1	f	\N	2	f
1700	2024-09-07 11:27:00	7044	2	1	f	1	4	t
1701	2024-06-23 08:21:00	8657	1	4	f	\N	4	t
1702	2024-06-15 00:45:00	3126	2	3	t	2	2	t
1703	2024-07-12 19:46:00	2412	3	2	f	\N	3	t
1704	2024-09-11 00:42:00	2077	4	2	f	\N	2	t
1705	2024-05-11 03:06:00	6067	3	2	f	\N	4	t
1706	2024-03-20 21:56:00	7523	2	1	t	1	3	t
1707	2024-02-08 07:16:00	8842	1	3	t	\N	4	f
1708	2024-06-24 00:56:00	9612	3	2	f	\N	1	f
1709	2024-07-07 17:45:00	7730	1	1	t	1	1	t
1710	2024-02-23 05:44:00	7708	5	2	f	\N	1	t
1711	2024-01-13 02:30:00	2208	5	2	f	\N	3	t
1712	2024-03-16 06:00:00	3053	5	4	t	\N	2	f
1713	2024-05-28 06:54:00	6194	3	3	t	1	4	t
1714	2024-08-19 11:26:00	2215	4	4	t	\N	3	t
1715	2024-04-22 06:53:00	8372	5	1	f	\N	2	f
1716	2024-05-01 05:30:00	8632	2	2	f	\N	4	t
1717	2024-03-14 00:18:00	9476	3	3	t	1	4	t
1718	2024-07-24 03:22:00	6644	4	1	t	\N	2	f
1719	2024-07-27 08:10:00	3102	3	4	f	\N	2	f
1720	2024-03-08 09:04:00	3981	4	1	t	\N	1	t
1721	2024-05-10 08:14:00	3114	5	1	t	\N	1	f
1722	2024-01-26 00:52:00	8088	5	3	t	2	4	t
1723	2024-02-18 13:31:00	9238	4	3	t	\N	3	f
1724	2024-08-06 18:25:00	1907	3	3	f	2	2	f
1725	2024-08-09 14:47:00	3034	2	2	t	\N	2	t
1726	2024-04-26 05:19:00	9488	4	4	f	\N	3	t
1727	2024-02-10 16:39:00	3507	2	2	f	\N	1	f
1728	2024-07-15 22:13:00	5982	3	4	t	\N	1	f
1729	2024-08-13 14:11:00	3697	3	3	t	\N	1	t
1730	2024-05-31 11:39:00	3653	3	1	f	\N	2	f
1731	2024-01-08 11:41:00	6286	3	4	f	\N	3	f
1732	2024-09-03 07:01:00	4694	4	2	t	\N	1	t
1733	2024-08-27 13:10:00	6669	2	1	t	\N	2	t
1734	2024-01-03 04:48:00	9501	5	4	f	2	4	f
1735	2024-03-02 10:19:00	5653	2	3	f	\N	1	f
1736	2024-08-18 21:34:00	2292	5	2	t	\N	4	t
1737	2024-06-21 20:43:00	5105	2	4	t	\N	1	t
1738	2024-04-04 15:16:00	4216	3	4	f	2	4	f
1739	2024-02-11 11:58:00	5496	3	3	t	\N	2	f
1740	2024-04-19 19:48:00	3050	4	2	t	2	4	t
1741	2024-09-01 01:14:00	5961	1	3	t	\N	1	f
1742	2024-05-19 10:52:00	9740	2	4	t	2	4	t
1743	2024-02-15 21:20:00	2530	2	3	t	\N	4	t
1744	2024-01-26 06:45:00	9234	2	1	t	2	3	t
1745	2024-08-05 00:35:00	3762	1	2	t	1	3	f
1746	2024-05-27 09:03:00	3526	3	4	t	\N	1	t
1747	2024-03-28 00:27:00	3804	5	1	f	\N	3	t
1748	2024-01-06 15:27:00	6531	4	4	f	1	3	t
1749	2024-07-24 10:58:00	1674	5	3	f	\N	4	f
1750	2024-01-09 06:12:00	1464	4	4	t	2	1	f
1751	2024-05-05 07:49:00	2330	2	2	t	\N	2	f
1752	2024-05-20 14:06:00	1744	3	4	f	\N	1	t
1753	2024-05-18 09:40:00	5336	2	3	f	1	4	f
1754	2024-03-09 05:16:00	4453	3	2	f	\N	2	f
1755	2024-05-07 19:24:00	7825	4	1	t	\N	4	t
1756	2024-03-19 09:40:00	1496	4	1	f	\N	1	f
1757	2024-08-10 21:18:00	9159	5	2	t	\N	3	t
1758	2024-05-25 05:11:00	9938	1	1	t	1	4	f
1759	2024-01-23 04:04:00	5745	3	4	t	2	1	t
1760	2024-07-03 01:38:00	5949	3	1	f	\N	4	f
1761	2024-03-01 13:22:00	8912	4	1	t	\N	4	t
1762	2024-02-24 19:55:00	5012	5	2	t	\N	2	t
1763	2024-07-15 00:50:00	7653	5	1	t	\N	3	t
1764	2024-07-30 14:10:00	5873	4	1	f	\N	3	f
1765	2024-08-05 21:21:00	8430	5	1	f	\N	4	f
1766	2024-01-29 14:38:00	2195	2	1	t	\N	3	t
1767	2024-01-20 23:22:00	1981	1	4	t	\N	3	f
1768	2024-01-13 04:27:00	3589	1	1	f	1	1	f
1769	2024-07-02 06:47:00	8202	5	3	f	2	4	t
1770	2024-07-11 15:00:00	7809	5	1	t	1	1	f
1771	2024-04-30 10:21:00	8933	4	3	t	\N	1	f
1772	2024-01-09 08:51:00	8609	1	4	f	\N	1	t
1773	2024-02-21 11:44:00	4342	3	4	t	\N	2	t
1774	2024-08-24 05:37:00	6573	5	2	f	\N	2	t
1775	2024-08-25 11:59:00	3353	4	4	f	1	2	f
1776	2024-09-15 23:13:00	6121	2	3	t	\N	1	f
1777	2024-08-22 18:16:00	6231	3	1	f	2	4	t
1778	2024-06-05 14:52:00	6658	2	3	t	1	4	t
1779	2024-05-25 09:26:00	7532	5	2	t	1	2	t
1780	2024-08-17 20:00:00	3142	3	1	t	\N	2	f
1781	2024-04-11 05:51:00	7070	5	4	f	\N	3	t
1782	2024-08-03 15:40:00	9437	2	1	f	\N	2	f
1783	2024-05-07 01:53:00	2739	5	2	t	\N	2	f
1784	2024-04-28 10:43:00	6228	2	1	f	2	3	f
1785	2024-07-30 21:53:00	4960	2	4	t	\N	4	f
1786	2024-03-07 08:22:00	8642	3	2	f	\N	2	t
1787	2024-07-09 05:59:00	3007	5	4	t	\N	2	t
1788	2024-02-26 20:56:00	5382	4	1	t	1	3	f
1789	2024-05-30 08:04:00	8366	3	1	t	\N	3	f
1790	2024-07-16 19:37:00	5061	4	4	f	\N	4	t
1791	2024-08-19 15:07:00	3308	5	2	f	\N	3	f
1792	2024-05-08 15:01:00	2586	4	1	f	\N	1	f
1793	2024-07-04 12:16:00	1829	1	4	f	1	1	f
1794	2024-05-17 01:52:00	5754	5	2	t	2	4	t
1795	2024-01-06 16:07:00	7293	1	3	f	\N	2	f
1796	2024-03-19 07:16:00	7850	3	1	f	2	2	f
1797	2024-03-16 10:42:00	5067	4	1	t	\N	4	t
1798	2024-03-21 19:47:00	3616	3	4	f	\N	2	f
1799	2024-03-30 10:48:00	6364	5	4	t	1	3	t
1800	2024-02-09 21:00:00	6123	1	1	f	\N	4	f
1801	2024-02-04 22:02:00	4110	3	4	t	\N	1	t
1802	2024-03-25 13:24:00	3610	3	4	t	\N	4	f
1803	2024-01-23 16:11:00	9163	5	4	t	1	1	t
1804	2024-07-07 22:28:00	9433	2	4	f	\N	4	t
1805	2024-07-07 08:22:00	8648	2	3	t	\N	3	f
1806	2024-04-12 21:40:00	9171	2	1	f	\N	1	f
1807	2024-04-15 01:34:00	6055	4	4	f	\N	4	t
1808	2024-03-21 05:07:00	9148	4	4	f	1	4	t
1809	2024-07-02 13:55:00	1379	3	1	f	2	1	t
1810	2024-01-10 20:52:00	2475	5	4	f	\N	2	f
1811	2024-02-08 05:36:00	7442	2	3	f	2	4	f
1812	2024-03-09 18:31:00	9281	1	3	t	\N	2	f
1813	2024-01-17 08:40:00	8491	3	3	t	2	3	f
1814	2024-04-11 00:50:00	4944	1	3	f	\N	4	t
1815	2024-08-21 05:28:00	4524	5	3	f	2	2	t
1816	2024-03-12 16:27:00	6781	3	2	f	\N	4	t
1817	2024-03-08 12:29:00	1797	4	3	t	\N	1	f
1818	2024-01-23 02:18:00	1828	3	3	f	\N	3	f
1819	2024-08-12 20:08:00	5609	1	1	f	\N	2	f
1820	2024-07-28 09:45:00	9108	5	3	t	2	4	t
1821	2024-07-04 04:12:00	8710	4	4	f	1	3	t
1822	2024-06-28 19:26:00	5681	1	3	f	\N	3	f
1823	2024-03-06 01:39:00	9793	5	3	t	2	4	t
1824	2024-03-16 06:04:00	1133	3	2	f	\N	1	t
1825	2024-04-01 12:23:00	2761	4	4	t	1	2	f
1826	2024-06-02 23:14:00	8060	1	3	t	1	4	f
1827	2024-02-09 04:24:00	3194	2	3	t	\N	4	t
1828	2024-05-08 15:11:00	5333	1	1	f	1	4	t
1829	2024-09-04 08:54:00	6992	5	2	t	\N	3	t
1830	2024-04-15 06:23:00	7606	3	4	f	\N	2	t
1831	2024-05-13 13:30:00	6995	2	3	f	\N	3	t
1832	2024-07-19 10:58:00	1741	3	2	t	\N	4	f
1833	2024-04-08 15:10:00	7563	1	4	t	\N	2	f
1834	2024-07-11 07:34:00	1838	2	4	t	\N	3	t
1835	2024-05-24 14:00:00	4189	2	4	t	1	4	f
1836	2024-08-08 18:37:00	6939	5	4	f	\N	4	t
1837	2024-05-11 01:35:00	5728	1	2	f	\N	2	f
1838	2024-03-29 12:33:00	2204	5	1	f	\N	4	f
1839	2024-05-06 07:38:00	7329	5	3	t	\N	3	f
1840	2024-03-24 16:05:00	9261	3	3	f	\N	3	f
1841	2024-07-04 04:11:00	8378	2	2	t	\N	4	f
1842	2024-06-08 02:18:00	5582	1	3	f	\N	1	f
1843	2024-05-06 16:58:00	2946	1	3	f	\N	1	f
1844	2024-01-26 10:35:00	3108	1	1	t	1	4	t
1845	2024-05-03 11:02:00	2584	3	4	f	1	3	t
1846	2024-06-19 04:32:00	7453	1	2	f	1	4	t
1847	2024-02-04 03:20:00	7114	5	2	f	2	3	t
1848	2024-07-30 07:43:00	6555	3	1	f	\N	3	t
1849	2024-05-13 00:30:00	6990	5	1	f	2	4	f
1850	2024-01-13 17:54:00	3363	3	2	t	\N	4	t
1851	2024-04-30 16:01:00	4261	5	4	f	\N	1	f
1852	2024-08-03 14:20:00	9341	5	1	t	1	4	t
1853	2024-02-02 13:11:00	7576	2	4	f	2	2	t
1854	2024-06-14 01:13:00	9193	1	3	f	1	2	t
1855	2024-07-06 01:09:00	1659	3	1	f	\N	4	f
1856	2024-08-06 13:18:00	1742	4	4	t	\N	3	f
1857	2024-07-17 12:36:00	1637	1	2	t	\N	4	t
1858	2024-06-12 22:08:00	3245	1	3	t	\N	1	f
1859	2024-09-15 14:07:00	6456	2	3	t	1	4	t
1860	2024-01-13 13:14:00	8761	1	3	t	2	1	f
1861	2024-07-01 03:34:00	9508	5	4	f	\N	3	f
1862	2024-06-19 18:49:00	8487	3	4	t	\N	1	f
1863	2024-06-03 20:59:00	3440	2	4	f	\N	1	f
1864	2024-09-11 16:41:00	9446	4	1	f	\N	3	t
1865	2024-02-18 05:04:00	3290	3	1	t	1	2	t
1866	2024-08-18 13:16:00	6373	2	3	f	2	3	t
1867	2024-07-10 08:34:00	6218	5	3	f	2	2	f
1868	2024-03-03 05:52:00	3662	5	4	t	\N	4	t
1869	2024-06-24 02:55:00	7438	2	2	t	\N	1	t
1870	2024-07-24 07:24:00	5902	5	4	f	\N	4	f
1871	2024-08-21 01:48:00	6511	5	2	t	\N	2	f
1872	2024-05-25 15:28:00	9311	4	3	f	\N	3	f
1873	2024-07-03 06:34:00	9351	3	2	t	\N	1	t
1874	2024-04-28 14:15:00	9721	5	3	f	2	2	f
1875	2024-08-08 21:30:00	9025	2	2	t	\N	2	t
1876	2024-01-28 07:10:00	5911	5	2	t	\N	4	f
1877	2024-09-14 22:38:00	8780	1	3	f	1	4	f
1878	2024-05-15 12:53:00	1272	1	2	t	1	2	t
1879	2024-02-23 15:08:00	7035	3	4	f	\N	3	t
1880	2024-03-02 10:20:00	6427	3	1	t	1	4	t
1881	2024-07-15 00:00:00	2795	4	1	t	\N	1	t
1882	2024-07-31 01:28:00	7824	1	3	t	\N	2	f
1883	2024-05-30 03:12:00	6040	1	2	t	\N	2	f
1884	2024-07-12 12:35:00	1436	1	3	t	1	3	f
1885	2024-02-14 16:56:00	8775	1	1	t	\N	4	t
1886	2024-03-17 14:47:00	5350	4	2	t	\N	1	t
1887	2024-09-01 12:09:00	4728	4	4	t	\N	4	t
1888	2024-08-24 16:01:00	1841	3	2	t	1	4	f
1889	2024-08-15 16:48:00	8871	1	4	t	\N	4	t
1890	2024-03-16 14:34:00	3793	3	2	t	\N	1	f
1891	2024-04-27 09:27:00	9589	1	3	t	\N	4	t
1892	2024-03-22 12:27:00	7229	5	4	f	1	3	f
1893	2024-05-06 20:16:00	3421	1	1	t	2	2	t
1894	2024-09-06 14:14:00	4968	2	2	t	\N	2	f
1895	2024-03-01 23:25:00	1517	4	1	f	1	1	t
1896	2024-08-26 01:26:00	2800	2	1	f	\N	4	t
1897	2024-06-15 17:20:00	4125	1	3	f	2	1	f
1898	2024-02-14 21:31:00	1310	5	1	f	\N	3	f
1899	2024-03-12 06:53:00	8225	2	3	f	\N	4	t
1900	2024-05-01 02:07:00	6139	4	4	f	1	1	t
1901	2024-06-24 16:59:00	7861	4	3	f	\N	2	t
1902	2024-07-07 20:04:00	3481	3	2	t	2	3	f
1903	2024-02-15 09:43:00	7765	1	4	f	1	2	f
1904	2024-08-22 00:19:00	4340	5	1	t	\N	2	f
1905	2024-07-21 05:48:00	7723	4	3	f	\N	4	f
1906	2024-03-21 16:01:00	9221	3	3	t	\N	2	t
1907	2024-01-23 02:03:00	8726	3	4	t	\N	1	f
1908	2024-01-09 08:07:00	2020	1	1	t	\N	1	t
1909	2024-09-11 16:10:00	3262	5	2	t	1	1	f
1910	2024-07-30 13:39:00	9498	3	1	t	1	4	f
1911	2024-07-13 18:08:00	4397	2	4	t	\N	1	f
1912	2024-07-14 02:54:00	6325	2	2	f	\N	1	t
1913	2024-05-04 01:08:00	8837	5	4	t	\N	1	t
1914	2024-04-27 11:28:00	9609	1	3	f	2	2	t
1915	2024-03-30 05:16:00	7173	5	4	t	\N	3	f
1916	2024-06-17 18:16:00	6140	5	2	f	\N	4	t
1917	2024-03-05 09:54:00	3837	5	2	f	\N	4	t
1918	2024-07-20 22:51:00	8531	2	2	t	\N	3	t
1919	2024-03-13 03:56:00	9734	5	1	f	\N	1	t
1920	2024-09-03 07:21:00	6608	1	1	t	\N	3	f
1921	2024-06-16 16:55:00	9950	3	4	f	\N	4	t
1922	2024-01-31 01:39:00	6804	2	1	f	2	1	f
1923	2024-05-26 07:09:00	5331	2	1	f	1	1	f
1924	2024-07-25 00:36:00	8932	5	2	f	\N	4	t
1925	2024-08-16 20:47:00	4150	3	4	f	1	3	t
1926	2024-07-02 21:49:00	5038	4	3	f	\N	3	t
1927	2024-04-26 18:06:00	5571	1	2	f	\N	1	t
1928	2024-09-05 18:55:00	5890	2	4	t	\N	1	t
1929	2024-01-21 19:57:00	4684	2	3	t	2	4	f
1930	2024-03-10 14:43:00	5876	3	1	t	\N	3	f
1931	2024-07-18 14:07:00	5735	2	2	t	\N	4	f
1932	2024-04-20 13:10:00	4396	1	2	f	1	2	f
1933	2024-06-28 21:04:00	9011	3	2	f	1	3	f
1934	2024-09-02 05:16:00	6194	5	3	t	\N	2	t
1935	2024-03-12 01:48:00	8861	2	2	t	\N	4	t
1936	2024-05-20 10:26:00	6714	2	2	f	2	3	f
1937	2024-08-15 21:28:00	5480	3	3	t	\N	2	t
1938	2024-02-23 14:24:00	5715	4	3	t	\N	1	t
1939	2024-01-03 11:14:00	2996	2	3	t	2	1	t
1940	2024-04-19 20:41:00	9899	4	4	t	\N	3	f
1941	2024-07-13 15:45:00	7220	4	2	f	\N	1	t
1942	2024-07-11 12:33:00	7464	5	2	t	\N	1	t
1943	2024-01-30 17:35:00	6654	2	3	f	\N	4	f
1944	2024-08-16 08:51:00	3399	2	4	t	1	4	t
1945	2024-03-31 15:05:00	5758	5	1	f	2	1	f
1946	2024-02-09 03:58:00	1689	2	4	t	\N	4	t
1947	2024-02-18 04:58:00	5712	3	3	t	\N	3	f
1948	2024-06-10 11:28:00	2294	2	1	f	2	3	f
1949	2024-05-22 23:36:00	6674	3	4	t	\N	2	f
1950	2024-04-17 02:21:00	8247	2	1	f	1	4	t
1951	2024-08-23 10:29:00	5201	2	3	f	\N	2	t
1952	2024-01-01 16:24:00	8849	1	3	f	\N	1	t
1953	2024-08-14 22:48:00	4505	4	3	f	1	3	t
1954	2024-03-04 18:51:00	4310	4	4	f	\N	3	t
1955	2024-04-18 15:41:00	9824	5	1	t	\N	1	f
1956	2024-01-20 23:04:00	5442	4	2	t	2	2	t
1957	2024-05-10 18:23:00	5450	4	4	t	1	3	t
1958	2024-04-02 23:48:00	3249	4	1	f	2	2	t
1959	2024-01-11 13:26:00	2789	5	3	t	\N	3	t
1960	2024-09-12 02:29:00	4920	3	4	t	\N	2	t
1961	2024-08-12 22:27:00	4972	2	3	f	1	4	t
1962	2024-03-20 10:17:00	1831	1	1	f	2	4	t
1963	2024-01-30 18:04:00	9700	2	1	f	\N	3	t
1964	2024-06-17 07:03:00	4697	1	3	t	\N	1	t
1965	2024-03-07 06:31:00	4814	1	2	f	2	1	t
1966	2024-05-28 08:28:00	1860	4	3	f	\N	2	t
1967	2024-02-04 17:20:00	2641	4	2	t	\N	4	f
1968	2024-03-04 12:50:00	7771	4	3	f	2	1	f
1969	2024-02-13 15:43:00	6411	4	3	t	\N	4	t
1970	2024-01-04 18:49:00	8739	3	4	f	2	4	f
1971	2024-01-20 21:09:00	2647	5	3	f	2	3	f
1972	2024-02-02 20:03:00	3252	1	2	t	2	4	t
1973	2024-07-09 04:14:00	1084	4	2	f	\N	4	f
1974	2024-06-11 17:22:00	3587	4	2	t	\N	3	f
1975	2024-03-17 17:56:00	7666	2	3	t	1	1	f
1976	2024-03-27 07:30:00	8793	5	4	t	\N	1	f
1977	2024-07-04 16:58:00	8822	5	1	f	\N	4	t
1978	2024-09-12 07:09:00	4267	4	4	f	2	2	f
1979	2024-06-19 15:58:00	5706	3	4	t	\N	4	t
1980	2024-07-08 12:06:00	6262	2	3	t	\N	3	t
1981	2024-08-25 00:38:00	5676	3	2	f	\N	2	t
1982	2024-07-09 21:32:00	1969	5	3	t	\N	3	t
1983	2024-04-01 10:09:00	2465	5	3	t	\N	1	t
1984	2024-02-13 08:19:00	4804	2	1	f	\N	3	f
1985	2024-08-01 13:33:00	9767	2	3	t	2	2	t
1986	2024-03-03 03:28:00	1611	5	4	t	\N	3	t
1987	2024-05-16 23:16:00	3868	3	4	t	2	1	t
1988	2024-08-26 09:08:00	7846	5	2	f	1	2	f
1989	2024-06-01 00:02:00	3880	5	4	t	\N	4	t
1990	2024-08-29 02:19:00	1595	1	4	f	2	2	t
1991	2024-02-12 12:28:00	7504	4	2	f	\N	2	f
1992	2024-05-09 02:20:00	9116	2	1	f	\N	2	t
1993	2024-08-18 21:36:00	4052	3	2	t	2	4	t
1994	2024-04-26 14:27:00	5742	4	4	f	\N	1	t
1995	2024-06-27 18:37:00	1613	2	4	t	\N	2	t
1996	2024-01-17 21:13:00	1151	3	1	t	\N	4	f
1997	2024-08-15 14:30:00	5888	3	3	t	\N	3	t
1998	2024-06-29 21:11:00	2758	2	1	t	\N	4	t
1999	2024-01-28 13:02:00	6489	4	1	t	\N	2	f
2000	2024-01-24 09:16:00	5662	3	3	t	\N	3	f
2001	2024-02-12 17:21:00	8444	3	4	f	\N	2	t
2002	2024-03-08 03:11:00	9901	5	3	f	\N	1	f
2003	2024-03-28 06:29:00	9590	4	1	t	\N	1	t
2004	2024-07-08 22:16:00	9092	1	4	t	1	4	f
2005	2024-07-04 21:04:00	3198	1	1	t	2	3	f
2006	2024-07-08 08:08:00	9261	2	4	t	\N	1	t
2007	2024-02-12 11:01:00	8668	1	2	t	2	3	f
2008	2024-07-05 08:28:00	5470	2	4	t	1	4	f
2009	2024-06-25 16:38:00	4159	4	1	f	2	4	f
2010	2024-03-06 01:29:00	2845	4	3	t	\N	4	t
2011	2024-01-17 18:49:00	6417	2	4	f	2	3	t
2012	2024-04-21 11:01:00	3662	1	3	f	2	1	f
2013	2024-03-28 08:24:00	8518	1	2	f	\N	3	t
2014	2024-04-30 12:49:00	5215	3	3	f	2	2	t
2015	2024-06-11 19:23:00	4050	2	3	t	\N	4	t
2016	2024-06-08 15:24:00	1230	2	2	t	2	4	f
2017	2024-07-15 11:42:00	6523	1	1	t	\N	1	t
2018	2024-03-31 22:28:00	5833	5	4	f	\N	4	t
2019	2024-05-26 03:23:00	4164	1	3	t	\N	4	t
2020	2024-08-22 03:16:00	3875	2	2	t	\N	1	t
2021	2024-07-28 07:12:00	7643	1	1	t	\N	3	f
2022	2024-05-06 07:35:00	8007	1	1	t	\N	1	f
2023	2024-06-08 13:50:00	9442	2	1	f	2	2	f
2024	2024-03-28 06:38:00	6372	4	1	t	1	4	t
2025	2024-05-22 06:57:00	2421	2	2	f	\N	4	t
2026	2024-06-01 11:35:00	7567	2	3	t	1	2	f
2027	2024-01-01 09:04:00	2562	4	3	f	2	2	t
2028	2024-05-16 07:17:00	4027	1	3	t	\N	2	t
2029	2024-07-28 16:51:00	3303	4	2	f	1	3	t
2030	2024-02-27 21:47:00	8822	1	1	t	\N	4	f
2031	2024-03-26 02:45:00	6301	5	1	t	\N	4	t
2032	2024-04-16 09:06:00	5064	4	2	f	2	3	f
2033	2024-09-15 01:47:00	1111	5	1	f	\N	4	t
2034	2024-02-23 19:56:00	5272	3	3	t	\N	3	t
2035	2024-08-09 19:48:00	7284	2	3	f	\N	2	f
2036	2024-09-12 17:38:00	4858	2	4	f	\N	2	t
2037	2024-01-26 21:47:00	8319	3	2	f	\N	1	t
2038	2024-06-11 02:07:00	5374	4	2	f	\N	1	t
2039	2024-03-28 17:19:00	6400	2	2	t	\N	2	t
2040	2024-08-26 20:28:00	5947	5	1	t	2	1	t
2041	2024-02-02 22:26:00	1187	1	4	f	1	1	t
2042	2024-02-07 23:57:00	5285	1	3	t	2	3	t
2043	2024-08-06 17:01:00	6890	1	2	t	1	3	f
2044	2024-04-19 00:34:00	4871	3	4	f	\N	1	f
2045	2024-01-08 03:03:00	2017	1	4	t	\N	3	t
2046	2024-08-17 22:53:00	2936	2	1	f	\N	1	f
2047	2024-01-15 01:15:00	8625	5	1	f	\N	3	t
2048	2024-05-09 12:29:00	6026	5	4	t	\N	4	f
2049	2024-09-12 05:46:00	3616	4	4	t	2	3	t
2050	2024-01-26 05:32:00	7642	1	1	f	\N	2	f
2051	2024-03-07 17:31:00	9233	1	4	f	1	2	f
2052	2024-06-01 00:59:00	6095	2	1	f	\N	2	f
2053	2024-07-22 20:13:00	2923	5	3	t	\N	1	t
2054	2024-08-05 05:13:00	5833	2	2	t	\N	2	f
2055	2024-05-02 11:52:00	7021	3	2	f	1	3	f
2056	2024-05-29 20:45:00	4618	2	4	t	\N	2	t
2057	2024-09-06 10:24:00	4590	3	1	f	\N	4	f
2058	2024-08-16 05:44:00	3188	4	1	t	\N	3	f
2059	2024-03-18 18:02:00	8834	5	2	f	2	1	f
2060	2024-07-09 01:29:00	3509	3	4	f	\N	1	t
2061	2024-07-18 17:19:00	8454	5	2	t	\N	1	t
2062	2024-01-13 03:32:00	7121	4	4	t	\N	2	t
2063	2024-05-28 10:53:00	7813	5	3	f	\N	1	t
2064	2024-08-13 02:24:00	9998	4	1	f	2	1	t
2065	2024-05-13 14:01:00	8714	4	3	t	\N	3	t
2066	2024-07-19 17:04:00	9806	3	2	f	\N	2	f
2067	2024-03-27 01:40:00	4578	5	4	f	\N	3	f
2068	2024-07-17 21:22:00	5054	1	3	f	2	4	f
2069	2024-02-02 03:25:00	2341	1	4	f	1	3	t
2070	2024-03-25 08:26:00	9609	3	2	f	2	4	t
2071	2024-09-14 04:26:00	8319	1	4	f	\N	4	f
2072	2024-01-31 04:32:00	9653	3	1	t	1	2	t
2073	2024-02-12 21:35:00	6927	1	3	f	\N	4	f
2074	2024-05-26 16:24:00	2279	1	3	f	1	3	t
2075	2024-05-13 08:15:00	2838	1	3	t	\N	3	t
2076	2024-06-08 14:19:00	2011	4	2	t	\N	2	t
2077	2024-01-11 12:54:00	9972	2	1	f	\N	2	f
2078	2024-01-09 17:43:00	9281	3	1	f	\N	1	t
2079	2024-05-29 09:45:00	4312	4	2	t	2	2	f
2080	2024-08-24 06:03:00	9792	4	4	t	\N	3	f
2081	2024-07-02 23:33:00	3455	1	4	f	\N	4	f
2082	2024-06-18 14:39:00	3695	4	1	t	\N	4	t
2083	2024-07-09 13:24:00	6375	4	2	f	\N	2	f
2084	2024-09-04 01:44:00	9525	2	3	t	1	3	t
2085	2024-02-09 01:24:00	8239	5	3	f	\N	2	t
2086	2024-05-04 21:03:00	2904	2	1	t	1	4	f
2087	2024-02-25 22:38:00	4365	1	3	f	2	1	f
2088	2024-03-09 22:59:00	9008	5	4	t	\N	3	f
2089	2024-05-15 06:58:00	2489	3	4	f	\N	1	t
2090	2024-08-20 01:17:00	9361	1	1	f	\N	4	f
2091	2024-04-12 21:20:00	8298	3	2	f	2	1	f
2092	2024-08-09 07:54:00	1911	5	1	f	\N	3	t
2093	2024-02-14 07:40:00	8429	1	4	f	\N	2	f
2094	2024-04-22 03:33:00	3161	3	2	f	\N	4	t
2095	2024-06-06 10:44:00	9409	1	3	t	\N	4	t
2096	2024-08-16 16:12:00	7806	3	3	t	1	4	f
2097	2024-06-10 22:18:00	8484	3	4	f	2	2	f
2098	2024-03-06 13:00:00	1945	3	1	t	\N	3	t
2099	2024-05-24 15:04:00	8575	2	1	t	\N	3	f
2100	2024-05-05 19:08:00	6049	2	4	f	\N	4	f
2101	2024-03-21 09:22:00	1356	3	4	t	1	3	t
2102	2024-08-29 05:44:00	7487	1	3	f	1	4	t
2103	2024-08-15 12:56:00	5169	3	1	t	\N	4	f
2104	2024-08-26 02:35:00	1049	3	4	t	\N	3	f
2105	2024-04-28 23:52:00	4570	5	4	f	1	4	t
2106	2024-05-28 10:20:00	2196	2	3	f	1	3	f
2107	2024-03-04 14:19:00	1742	2	4	f	2	3	f
2108	2024-07-19 23:15:00	7941	5	3	t	\N	4	t
2109	2024-09-04 21:47:00	6644	3	3	f	1	3	f
2110	2024-06-21 22:15:00	2044	1	2	f	2	1	t
2111	2024-08-18 13:39:00	9866	5	3	t	1	4	t
2112	2024-09-06 22:01:00	1987	3	3	t	\N	3	t
2113	2024-02-13 16:12:00	2130	3	2	t	1	4	f
2114	2024-01-04 11:09:00	8734	5	2	f	1	2	t
2115	2024-02-09 23:53:00	1519	1	3	t	2	2	t
2116	2024-04-02 02:03:00	5703	4	4	t	1	4	t
2117	2024-01-15 15:13:00	7698	2	3	t	\N	4	t
2118	2024-04-01 00:40:00	3948	3	3	t	\N	3	f
2119	2024-07-27 19:04:00	3218	5	4	t	1	3	t
2120	2024-08-21 09:22:00	7887	5	1	t	2	1	f
2121	2024-04-16 02:31:00	7135	5	1	f	\N	2	t
2122	2024-05-17 13:51:00	7266	1	2	f	\N	1	t
2123	2024-02-02 17:53:00	8348	4	2	f	\N	2	f
2124	2024-05-21 01:57:00	7184	4	1	f	\N	3	f
2125	2024-02-17 21:21:00	7154	3	4	t	\N	2	t
2126	2024-02-23 23:03:00	2314	3	4	t	\N	2	f
2127	2024-02-19 12:29:00	9835	5	3	t	\N	4	f
2128	2024-06-06 05:03:00	3178	2	4	t	\N	1	f
2129	2024-05-05 04:04:00	6697	4	3	f	\N	4	f
2130	2024-09-13 11:05:00	2943	2	2	f	\N	1	t
2131	2024-08-04 20:37:00	3924	4	1	t	\N	4	t
2132	2024-08-03 11:06:00	9802	3	4	t	\N	4	f
2133	2024-08-24 05:04:00	7439	1	3	f	1	4	t
2134	2024-07-04 20:13:00	9664	5	3	f	\N	3	t
2135	2024-09-05 02:05:00	3086	3	4	f	\N	1	f
2136	2024-02-27 03:56:00	4648	5	2	t	\N	2	t
2137	2024-02-11 19:08:00	1056	3	4	f	\N	4	f
2138	2024-07-28 13:54:00	1372	5	3	t	\N	4	t
2139	2024-04-03 00:57:00	5888	4	2	t	\N	1	f
2140	2024-08-19 08:23:00	8585	2	2	t	2	3	f
2141	2024-06-27 22:09:00	9920	4	2	t	\N	2	t
2142	2024-07-09 02:32:00	7948	2	3	t	\N	2	f
2143	2024-06-26 11:41:00	9715	2	1	t	1	4	f
2144	2024-08-08 20:22:00	7214	2	2	t	\N	3	f
2145	2024-03-08 03:54:00	4762	3	2	t	2	1	f
2146	2024-08-24 22:20:00	5055	2	3	t	\N	3	t
2147	2024-08-15 21:06:00	8546	4	2	t	1	2	t
2148	2024-01-25 04:18:00	6671	4	4	f	\N	1	f
2149	2024-01-10 04:28:00	3541	1	1	f	\N	1	f
2150	2024-08-12 08:14:00	5516	4	2	t	\N	2	f
2151	2024-03-24 12:50:00	4088	5	4	t	\N	1	t
2152	2024-02-09 04:07:00	2848	2	3	f	\N	3	t
2153	2024-05-15 10:32:00	1527	2	2	f	\N	3	f
2154	2024-07-23 02:21:00	7868	2	4	t	1	3	t
2155	2024-01-27 11:54:00	1256	1	4	t	\N	2	f
2156	2024-09-11 00:19:00	4943	5	3	t	2	3	t
2157	2024-08-09 19:20:00	4376	2	4	f	\N	4	f
2158	2024-03-21 23:36:00	2102	1	3	f	2	4	f
2159	2024-06-26 12:17:00	2653	5	2	f	\N	3	t
2160	2024-02-02 11:05:00	1550	4	1	t	\N	1	f
2161	2024-04-09 03:34:00	8314	5	4	f	2	3	f
2162	2024-02-20 16:12:00	1797	1	1	t	2	1	t
2163	2024-04-12 06:19:00	5009	1	2	t	2	2	f
2164	2024-07-14 03:21:00	1724	1	3	t	2	4	t
2165	2024-03-03 07:28:00	7590	2	4	f	\N	3	t
2166	2024-06-17 20:01:00	8191	3	2	f	\N	4	f
2167	2024-07-14 12:06:00	4839	3	2	f	\N	4	t
2168	2024-02-29 05:06:00	9843	4	2	t	1	4	t
2169	2024-07-12 15:27:00	4559	3	4	f	\N	3	f
2170	2024-04-05 21:22:00	1924	2	4	t	2	3	t
2171	2024-05-07 05:23:00	3295	5	4	f	2	3	f
2172	2024-08-14 14:51:00	9255	5	1	f	\N	1	f
2173	2024-06-21 12:09:00	5739	2	4	f	2	4	t
2174	2024-02-22 03:43:00	4836	4	2	t	2	1	t
2175	2024-09-12 20:18:00	6224	3	3	f	\N	4	f
2176	2024-02-23 19:06:00	6253	1	1	f	\N	4	t
2177	2024-09-03 20:24:00	4881	4	1	t	1	1	f
2178	2024-08-26 10:47:00	5944	2	4	f	\N	3	f
2179	2024-04-16 10:49:00	3347	4	2	f	\N	1	f
2180	2024-04-02 00:27:00	9540	2	2	f	\N	4	f
2181	2024-05-26 20:24:00	4621	5	3	f	\N	1	t
2182	2024-07-26 11:00:00	7775	5	1	f	\N	4	t
2183	2024-08-29 04:02:00	5923	3	2	t	\N	4	t
2184	2024-05-11 20:52:00	5508	1	3	t	\N	4	f
2185	2024-02-12 05:16:00	1998	2	4	f	2	3	t
2186	2024-02-24 22:50:00	3869	2	3	t	\N	3	t
2187	2024-06-04 20:43:00	7999	5	1	f	\N	3	t
2188	2024-03-19 05:00:00	9120	5	3	f	\N	3	t
2189	2024-05-18 20:32:00	1768	1	2	t	\N	1	t
2190	2024-01-10 19:08:00	6642	1	2	f	\N	2	t
2191	2024-02-28 02:46:00	7244	4	3	f	\N	4	f
2192	2024-07-16 13:52:00	9592	2	4	f	\N	3	f
2193	2024-02-16 03:55:00	6222	2	1	f	2	3	f
2194	2024-04-16 18:29:00	7821	5	4	f	2	4	t
2195	2024-08-16 10:34:00	7688	4	2	t	\N	2	f
2196	2024-05-29 14:26:00	3444	3	1	f	\N	4	t
2197	2024-05-10 04:08:00	5913	1	1	f	1	4	t
2198	2024-03-11 22:40:00	7167	3	3	t	\N	2	t
2199	2024-06-07 11:45:00	4012	5	3	t	2	3	t
2200	2024-02-05 14:07:00	9813	5	3	f	\N	4	f
2201	2024-03-11 16:23:00	8758	2	2	t	2	1	f
2202	2024-01-31 02:27:00	4948	1	1	t	\N	2	f
2203	2024-07-18 11:02:00	4692	5	4	f	\N	3	f
2204	2024-06-21 05:54:00	5927	1	1	f	\N	3	f
2205	2024-05-27 08:43:00	3365	5	2	t	\N	3	t
2206	2024-08-07 10:09:00	8586	2	4	f	2	1	f
2207	2024-05-09 09:36:00	1944	4	1	t	1	3	f
2208	2024-03-08 16:42:00	7761	3	1	f	\N	1	f
2209	2024-08-06 14:16:00	7824	1	4	t	\N	3	f
2210	2024-07-01 09:02:00	9683	3	3	t	\N	2	t
2211	2024-09-11 10:36:00	3196	5	2	t	\N	3	t
2212	2024-03-11 04:46:00	7363	5	3	f	\N	2	f
2213	2024-04-19 01:05:00	4978	5	1	t	2	3	t
2214	2024-02-02 04:32:00	5177	2	4	t	2	3	f
2215	2024-07-02 02:54:00	4331	5	1	t	\N	2	f
2216	2024-05-04 05:07:00	6411	1	4	f	\N	2	f
2217	2024-05-29 16:13:00	2295	2	4	t	2	2	f
2218	2024-09-03 18:21:00	8369	3	2	f	\N	1	t
2219	2024-04-11 04:38:00	7079	5	2	t	1	3	f
2220	2024-05-23 21:20:00	2514	3	2	t	\N	3	f
2221	2024-02-02 11:43:00	9775	5	1	t	2	3	t
2222	2024-05-25 03:02:00	4120	1	4	f	\N	3	f
2223	2024-02-01 12:05:00	1844	5	3	f	2	4	f
2224	2024-04-26 00:47:00	5398	4	1	t	\N	2	t
2225	2024-03-04 07:56:00	7179	5	1	f	2	1	f
2226	2024-04-21 05:35:00	1647	2	2	f	\N	1	f
2227	2024-05-15 21:06:00	2192	1	3	t	\N	2	t
2228	2024-03-13 16:17:00	4082	3	4	t	2	4	t
2229	2024-07-31 09:49:00	4555	4	3	f	\N	1	f
2230	2024-06-29 14:43:00	8854	5	4	t	\N	1	f
2231	2024-03-03 12:45:00	4422	4	4	t	\N	3	t
2232	2024-07-18 12:08:00	6455	1	1	f	\N	4	t
2233	2024-06-13 21:24:00	5967	4	1	f	\N	4	f
2234	2024-05-09 00:36:00	1251	1	2	t	\N	4	f
2235	2024-09-01 00:15:00	4470	4	2	f	\N	1	t
2236	2024-03-07 18:13:00	4113	2	1	t	1	2	t
2237	2024-02-14 16:44:00	2922	2	2	t	1	3	f
2238	2024-04-12 18:55:00	8846	5	2	t	1	3	f
2239	2024-04-12 16:24:00	4974	3	3	t	1	1	f
2240	2024-02-29 23:21:00	4350	1	1	t	\N	3	f
2241	2024-03-01 09:51:00	7498	1	1	f	2	4	f
2242	2024-07-14 05:00:00	4921	1	4	t	1	3	t
2243	2024-03-24 14:01:00	6269	4	2	t	\N	2	f
2244	2024-01-24 21:36:00	5637	5	2	f	2	1	t
2245	2024-06-30 21:40:00	7236	2	1	f	\N	4	f
2246	2024-03-30 23:50:00	8639	2	3	t	\N	2	f
2247	2024-04-21 20:42:00	9743	5	3	f	\N	4	t
2248	2024-01-24 15:41:00	6886	3	3	f	2	1	f
2249	2024-03-16 05:53:00	6053	2	2	t	\N	1	f
2250	2024-02-16 00:31:00	5285	3	1	f	2	2	f
2251	2024-02-21 04:47:00	6892	4	2	t	1	2	f
2252	2024-01-21 13:40:00	9401	3	3	t	2	4	t
2253	2024-06-06 21:40:00	9147	2	4	f	\N	4	f
2254	2024-08-11 14:21:00	8635	2	4	t	1	1	f
2255	2024-06-03 19:03:00	2615	3	3	f	\N	1	t
2256	2024-03-30 21:44:00	8692	3	1	t	\N	4	t
2257	2024-07-05 08:30:00	6246	2	1	f	\N	2	t
2258	2024-04-08 12:19:00	4328	5	3	f	\N	2	f
2259	2024-02-01 20:36:00	7073	5	1	t	\N	1	f
2260	2024-08-05 15:51:00	6126	4	3	t	2	1	t
2261	2024-08-02 19:12:00	7781	3	2	f	\N	2	t
2262	2024-01-28 18:35:00	1749	5	4	t	\N	4	f
2263	2024-05-16 09:29:00	4625	5	1	f	\N	1	f
2264	2024-03-01 11:27:00	3390	5	3	f	1	4	t
2265	2024-06-19 00:51:00	1265	3	1	f	\N	3	f
2266	2024-04-21 19:25:00	5272	4	1	t	1	4	t
2267	2024-09-08 13:14:00	7841	5	3	f	\N	1	f
2268	2024-03-24 13:31:00	5836	5	4	f	\N	2	t
2269	2024-05-24 08:09:00	3497	5	2	t	\N	1	f
2270	2024-06-15 04:19:00	4214	3	4	t	\N	1	f
2271	2024-03-01 12:56:00	6404	5	1	t	\N	3	f
2272	2024-07-14 17:09:00	4768	2	4	f	\N	2	f
2273	2024-06-24 12:01:00	7223	5	2	t	2	4	t
2274	2024-05-25 15:50:00	5026	2	3	f	\N	4	t
2275	2024-04-08 20:37:00	9180	3	1	f	\N	2	t
2276	2024-09-15 03:41:00	6530	3	3	f	\N	3	f
2277	2024-08-15 17:56:00	5216	3	1	t	\N	3	f
2278	2024-02-22 20:18:00	9005	4	2	f	\N	2	f
2279	2024-03-08 13:56:00	9037	1	1	f	2	4	t
2280	2024-02-20 22:48:00	8550	3	1	f	\N	1	f
2281	2024-05-12 07:21:00	3756	2	3	t	\N	3	f
2282	2024-05-20 03:47:00	6770	5	4	f	\N	4	f
2283	2024-02-20 09:27:00	3773	4	2	t	\N	3	f
2284	2024-06-30 19:33:00	3293	2	2	f	\N	2	f
2285	2024-07-15 04:47:00	9954	2	3	t	\N	2	f
2286	2024-01-18 03:19:00	9000	2	2	t	\N	4	f
2287	2024-01-14 21:27:00	4015	1	2	t	\N	3	f
2288	2024-01-09 02:48:00	9882	3	4	t	\N	4	t
2289	2024-02-02 20:44:00	1962	4	1	f	1	4	f
2290	2024-09-16 08:35:00	9584	4	2	f	\N	4	f
2291	2024-01-12 09:55:00	1554	2	2	t	\N	3	t
2292	2024-06-05 16:48:00	2217	5	2	t	\N	3	f
2293	2024-03-23 05:41:00	1794	4	1	t	\N	3	f
2294	2024-08-14 00:57:00	1104	4	4	t	\N	4	f
2295	2024-02-28 00:34:00	7756	5	4	t	\N	4	f
2296	2024-09-10 07:00:00	3252	1	1	f	\N	1	f
2297	2024-08-08 20:15:00	4791	1	4	t	\N	1	f
2298	2024-04-01 18:56:00	2113	1	2	f	2	2	t
2299	2024-06-13 04:02:00	3474	1	4	f	2	1	f
2300	2024-05-01 15:40:00	1149	1	1	f	1	4	f
2301	2024-07-11 02:11:00	4583	4	4	t	\N	3	t
2302	2024-06-08 03:40:00	9285	1	3	t	\N	4	t
2303	2024-04-02 19:12:00	8471	4	3	f	\N	1	f
2304	2024-03-13 02:16:00	7114	4	1	f	1	1	t
2305	2024-08-29 22:51:00	1990	4	3	f	1	1	f
2306	2024-04-18 09:43:00	8916	4	3	t	\N	2	t
2307	2024-04-13 20:49:00	8993	4	2	f	\N	2	f
2308	2024-03-17 01:13:00	1257	3	2	f	\N	3	t
2309	2024-02-29 00:27:00	1108	5	2	f	2	1	t
2310	2024-01-05 14:15:00	9719	2	3	f	\N	2	f
2311	2024-02-23 08:02:00	7739	1	2	t	1	2	f
2312	2024-02-16 09:35:00	1194	4	1	t	\N	2	f
2313	2024-03-07 21:31:00	1274	4	3	t	1	1	t
2314	2024-07-09 01:04:00	9673	5	4	t	\N	4	t
2315	2024-06-18 17:37:00	5501	2	1	f	\N	1	t
2316	2024-06-01 07:29:00	9777	2	2	t	\N	2	t
2317	2024-08-10 16:01:00	5697	1	2	f	\N	4	f
2318	2024-07-28 03:41:00	1280	1	2	f	\N	4	t
2319	2024-01-18 19:20:00	9228	5	3	t	\N	4	t
2320	2024-05-06 17:35:00	8054	1	4	f	\N	2	f
2321	2024-07-07 11:33:00	3937	1	3	t	\N	3	t
2322	2024-01-11 10:19:00	2753	2	4	t	\N	1	f
2323	2024-05-28 00:36:00	2578	1	4	t	\N	1	t
2324	2024-03-01 04:01:00	9591	4	2	f	\N	4	f
2325	2024-01-11 23:20:00	3439	2	4	t	\N	4	f
2326	2024-07-16 11:13:00	4948	5	1	f	1	2	f
2327	2024-07-27 22:22:00	4144	3	3	f	\N	3	f
2328	2024-08-19 02:41:00	9625	1	3	t	\N	4	t
2329	2024-06-19 07:29:00	5135	4	1	f	\N	4	t
2330	2024-06-20 18:24:00	6807	2	2	t	\N	3	f
2331	2024-07-05 03:52:00	5379	5	4	t	\N	4	f
2332	2024-04-01 15:28:00	7502	3	1	f	2	1	f
2333	2024-03-18 07:03:00	2294	3	2	t	2	4	t
2334	2024-03-08 04:08:00	7112	5	3	f	1	1	f
2335	2024-03-08 01:19:00	7652	1	4	t	2	1	t
2336	2024-07-28 07:41:00	8520	3	4	t	\N	4	t
2337	2024-04-01 00:33:00	4984	3	1	t	1	4	t
2338	2024-02-19 13:37:00	4700	3	4	f	1	3	f
2339	2024-01-17 15:34:00	5914	1	3	t	\N	4	t
2340	2024-05-23 07:51:00	2320	4	1	t	\N	3	t
2341	2024-06-17 00:50:00	1519	1	4	t	2	1	f
2342	2024-06-21 03:25:00	2531	5	4	f	\N	4	t
2343	2024-06-12 10:33:00	7640	4	4	f	\N	4	t
2344	2024-01-18 08:06:00	7213	2	2	t	\N	2	t
2345	2024-06-21 11:36:00	7179	3	2	t	2	2	f
2346	2024-08-28 00:57:00	8798	5	4	t	\N	1	t
2347	2024-08-29 01:39:00	1919	1	2	t	2	1	f
2348	2024-03-15 00:44:00	1154	1	3	t	\N	2	t
2349	2024-09-06 03:53:00	3807	5	3	f	\N	4	f
2350	2024-06-11 07:19:00	2354	4	4	t	2	2	f
2351	2024-02-16 20:39:00	9189	1	2	f	2	1	f
2352	2024-06-25 16:00:00	8109	4	1	f	\N	3	f
2353	2024-06-30 21:35:00	6427	3	2	f	\N	1	t
2354	2024-04-20 03:16:00	2562	5	1	f	\N	4	t
2355	2024-07-04 07:19:00	9653	2	2	f	2	4	t
2356	2024-08-17 22:44:00	1697	5	3	f	2	4	t
2357	2024-05-09 02:07:00	4764	3	2	t	\N	2	f
2358	2024-03-18 14:47:00	4463	4	1	f	\N	4	t
2359	2024-07-01 17:22:00	8790	3	1	t	\N	1	f
2360	2024-07-21 21:17:00	5441	1	3	t	\N	1	t
2361	2024-09-02 17:19:00	1762	3	1	f	1	2	f
2362	2024-09-09 22:49:00	2218	1	1	f	\N	4	t
2363	2024-01-26 23:18:00	5593	2	3	t	\N	1	f
2364	2024-09-10 11:31:00	9897	1	4	f	\N	4	t
2365	2024-08-12 07:54:00	1539	5	1	f	1	1	t
2366	2024-02-15 23:48:00	3938	1	2	t	\N	3	t
2367	2024-03-18 23:28:00	6152	3	2	f	\N	3	t
2368	2024-04-17 20:42:00	1256	2	2	t	\N	2	f
2369	2024-04-17 01:47:00	4394	4	1	f	\N	4	f
2370	2024-08-21 09:36:00	3362	2	2	f	\N	4	f
2371	2024-05-12 09:19:00	7525	5	4	t	\N	3	t
2372	2024-05-12 10:22:00	2260	3	2	t	1	2	t
2373	2024-05-17 23:34:00	5903	3	3	f	\N	3	f
2374	2024-04-10 05:23:00	3661	3	2	t	1	2	f
2375	2024-06-03 13:24:00	4939	1	2	t	\N	3	f
2376	2024-09-08 22:41:00	7375	2	3	f	\N	2	f
2377	2024-02-26 11:18:00	9856	2	2	t	\N	3	t
2378	2024-02-13 23:15:00	6435	1	3	f	\N	2	t
2379	2024-08-02 23:44:00	7288	2	2	t	2	1	f
2380	2024-09-12 04:51:00	3292	4	4	f	\N	2	t
2381	2024-07-12 10:42:00	2284	5	1	t	2	3	f
2382	2024-03-16 01:56:00	9204	1	1	t	\N	4	t
2383	2024-08-02 08:21:00	6666	3	3	t	\N	1	f
2384	2024-06-06 00:22:00	1879	3	1	t	2	2	f
2385	2024-03-10 23:24:00	2600	5	4	t	\N	4	f
2386	2024-04-17 12:27:00	8161	4	4	f	\N	3	f
2387	2024-03-12 16:24:00	4803	2	2	f	\N	4	f
2388	2024-05-29 00:42:00	2245	1	3	f	2	1	t
2389	2024-01-30 23:26:00	6580	3	1	f	1	4	t
2390	2024-07-06 07:41:00	7499	4	1	f	\N	2	f
2391	2024-08-03 00:50:00	6347	4	2	t	1	3	t
2392	2024-05-27 20:14:00	1485	5	1	t	\N	4	t
2393	2024-04-18 11:31:00	5478	2	1	f	1	1	f
2394	2024-03-08 02:12:00	8381	5	4	f	\N	4	t
2395	2024-04-08 03:06:00	9038	4	3	t	\N	2	t
2396	2024-02-15 15:33:00	4737	5	1	t	\N	3	t
2397	2024-04-28 03:54:00	6829	3	3	t	2	3	t
2398	2024-06-27 10:14:00	7150	2	1	t	2	1	f
2399	2024-04-19 10:37:00	8075	4	2	t	\N	1	t
2400	2024-07-12 14:24:00	4043	1	4	f	1	4	t
2401	2024-08-21 06:55:00	7227	3	4	f	\N	1	f
2402	2024-08-19 11:53:00	2404	2	2	t	\N	1	f
2403	2024-08-01 02:52:00	5839	5	1	f	\N	1	t
2404	2024-05-26 03:40:00	5037	3	1	f	\N	2	t
2405	2024-02-07 11:15:00	2204	3	1	t	\N	1	f
2406	2024-03-09 08:25:00	2344	3	4	t	\N	1	f
2407	2024-05-24 05:31:00	5390	3	1	t	1	3	t
2408	2024-04-10 08:12:00	3526	2	3	t	1	1	f
2409	2024-01-31 14:26:00	7225	3	2	t	\N	1	t
2410	2024-01-06 12:04:00	3527	3	1	f	\N	3	f
2411	2024-05-27 07:56:00	7383	3	1	f	\N	1	t
2412	2024-09-10 04:59:00	6188	5	3	t	\N	4	f
2413	2024-04-02 07:28:00	6909	4	2	f	\N	2	t
2414	2024-07-09 23:32:00	2745	1	1	t	\N	3	f
2415	2024-09-04 23:57:00	2499	1	1	f	\N	2	f
2416	2024-04-24 11:38:00	1085	4	2	t	\N	2	f
2417	2024-03-20 18:34:00	6050	4	1	t	\N	2	f
2418	2024-07-24 23:37:00	8286	4	4	t	\N	4	t
2419	2024-08-16 22:27:00	6896	1	2	t	\N	4	f
2420	2024-05-27 21:36:00	5419	1	3	f	2	2	f
2421	2024-08-16 04:29:00	2674	1	3	t	2	2	f
2422	2024-02-07 03:26:00	3170	1	1	f	2	4	t
2423	2024-06-28 08:24:00	2430	2	3	f	\N	3	t
2424	2024-03-23 06:13:00	4070	2	1	t	\N	1	t
2425	2024-04-05 20:30:00	8061	5	1	f	\N	4	t
2426	2024-02-25 12:20:00	8353	5	4	t	\N	1	t
2427	2024-05-16 05:18:00	9395	5	4	f	\N	4	f
2428	2024-06-07 11:54:00	7685	4	3	f	\N	1	t
2429	2024-05-07 01:19:00	2692	2	1	f	1	4	t
2430	2024-07-02 05:33:00	1430	5	3	t	\N	3	t
2431	2024-01-20 16:54:00	2468	3	1	f	\N	3	t
2432	2024-04-18 15:44:00	6798	5	3	t	\N	3	f
2433	2024-06-01 02:55:00	2524	1	4	f	\N	1	f
2434	2024-06-25 17:39:00	6315	3	3	f	\N	1	f
2435	2024-01-01 22:08:00	7311	4	4	f	\N	3	t
2436	2024-06-06 10:19:00	1202	5	1	t	1	2	t
2437	2024-08-29 16:22:00	5781	5	1	t	1	3	f
2438	2024-01-09 11:33:00	7779	2	2	t	\N	3	f
2439	2024-02-03 07:06:00	7353	3	3	t	\N	3	t
2440	2024-07-08 06:10:00	2387	4	2	f	2	2	t
2441	2024-04-24 06:16:00	4977	5	1	t	\N	4	t
2442	2024-04-07 22:27:00	9537	4	3	t	\N	1	f
2443	2024-04-21 19:58:00	3778	3	2	f	\N	3	f
2444	2024-01-05 15:31:00	7237	4	2	f	\N	4	f
2445	2024-03-05 00:41:00	3777	1	2	t	2	4	f
2446	2024-02-27 08:20:00	3274	5	1	f	2	2	t
2447	2024-06-10 16:05:00	5405	3	3	f	2	2	t
2448	2024-07-25 17:24:00	5933	5	2	t	1	1	f
2449	2024-07-21 21:06:00	5397	5	2	f	\N	3	f
2450	2024-02-22 12:18:00	9079	3	2	t	2	3	f
2451	2024-02-21 11:16:00	3390	1	2	f	\N	1	t
2452	2024-03-14 19:06:00	2036	4	2	t	\N	1	f
2453	2024-02-11 07:35:00	3739	4	3	t	1	1	f
2454	2024-07-11 21:07:00	8121	4	4	t	2	4	t
2455	2024-02-16 23:56:00	5521	5	2	t	2	1	f
2456	2024-03-04 10:58:00	7899	1	3	f	\N	1	t
2457	2024-01-26 13:17:00	5911	4	4	t	\N	2	t
2458	2024-09-13 12:41:00	8933	3	2	f	\N	3	f
2459	2024-04-22 09:51:00	2260	3	4	t	2	2	f
2460	2024-05-01 02:21:00	6916	2	2	f	\N	2	f
2461	2024-06-04 08:44:00	5123	4	3	f	2	4	t
2462	2024-02-09 07:04:00	5040	2	4	t	\N	3	f
2463	2024-06-02 21:43:00	9123	3	1	t	\N	3	t
2464	2024-02-10 20:19:00	4203	3	2	t	1	1	t
2465	2024-02-15 06:59:00	8501	4	1	t	\N	3	t
2466	2024-03-22 08:59:00	2752	5	4	f	\N	2	f
2467	2024-02-11 17:07:00	3219	3	3	f	\N	1	t
2468	2024-06-02 23:25:00	5991	1	2	f	\N	2	f
2469	2024-05-12 22:00:00	1110	1	4	t	\N	2	t
2470	2024-04-15 00:44:00	7483	4	4	t	\N	4	f
2471	2024-06-02 07:13:00	6443	4	2	f	\N	4	f
2472	2024-07-08 13:52:00	7224	5	1	t	\N	1	f
2473	2024-04-30 03:55:00	6399	5	4	f	\N	2	t
2474	2024-09-11 14:41:00	8212	5	2	f	\N	2	t
2475	2024-02-26 16:21:00	6484	5	3	f	\N	1	f
2476	2024-03-11 09:30:00	8055	1	1	f	1	1	t
2477	2024-07-11 19:12:00	3230	4	2	t	\N	3	t
2478	2024-03-07 14:40:00	5922	4	4	t	2	1	t
2479	2024-07-08 22:01:00	6253	5	3	f	\N	1	f
2480	2024-04-18 11:54:00	4290	2	1	t	\N	4	t
2481	2024-04-03 15:53:00	8848	2	1	f	\N	3	t
2482	2024-02-08 13:01:00	6147	2	2	f	\N	2	f
2483	2024-06-06 10:11:00	3910	3	3	f	\N	4	t
2484	2024-05-04 04:32:00	7524	4	3	f	1	2	f
2485	2024-08-01 04:22:00	6228	5	1	t	\N	3	t
2486	2024-06-29 03:55:00	5775	3	4	f	\N	2	t
2487	2024-03-19 09:37:00	9044	3	3	t	\N	3	t
2488	2024-04-19 19:25:00	4971	2	4	t	\N	1	t
2489	2024-07-29 20:32:00	6339	5	4	t	1	3	t
2490	2024-01-26 09:13:00	7161	4	4	t	\N	4	t
2491	2024-07-18 21:15:00	5592	2	3	t	2	4	f
2492	2024-08-04 07:23:00	7437	2	1	t	\N	2	t
2493	2024-07-11 15:36:00	6980	3	4	t	\N	2	t
2494	2024-03-21 15:35:00	2865	4	2	t	1	1	t
2495	2024-03-11 08:19:00	4273	4	4	t	\N	1	t
2496	2024-05-20 01:13:00	9939	1	4	t	2	4	t
2497	2024-03-27 10:21:00	3947	1	3	f	\N	2	f
2498	2024-07-10 02:25:00	1440	1	2	f	2	2	t
2499	2024-08-14 10:22:00	8563	4	2	t	\N	2	f
2500	2024-08-09 23:03:00	4434	3	1	f	2	4	f
2501	2024-01-22 12:29:00	8183	1	2	f	1	1	t
2502	2024-03-18 07:27:00	5773	5	2	t	2	4	t
2503	2024-01-09 08:40:00	2133	2	4	t	\N	4	f
2504	2024-07-28 17:27:00	7703	5	3	t	1	3	f
2505	2024-04-15 17:05:00	9180	3	3	t	2	4	t
2506	2024-06-01 05:45:00	3280	2	4	t	2	3	t
2507	2024-08-14 01:59:00	5961	1	3	f	\N	2	f
2508	2024-04-05 20:45:00	4965	5	3	f	\N	1	f
2509	2024-08-05 02:34:00	5139	4	1	t	\N	4	f
2510	2024-06-21 01:02:00	3525	4	3	f	\N	4	f
2511	2024-06-10 14:54:00	7932	1	2	f	\N	3	t
2512	2024-02-08 14:59:00	7176	1	1	f	2	3	f
2513	2024-09-08 03:01:00	2211	1	1	f	\N	1	t
2514	2024-09-11 16:07:00	8357	1	1	t	\N	1	t
2515	2024-03-01 03:12:00	8851	1	3	t	\N	4	t
2516	2024-04-19 14:29:00	7566	2	1	f	\N	4	f
2517	2024-09-08 23:32:00	9755	3	2	f	\N	2	t
2518	2024-07-20 03:11:00	9300	4	2	t	\N	4	f
2519	2024-06-25 00:03:00	7853	1	3	t	1	1	t
2520	2024-05-01 00:51:00	9907	2	1	f	\N	2	t
2521	2024-01-24 18:52:00	1602	3	2	t	\N	4	t
2522	2024-01-29 15:30:00	6890	4	1	f	\N	3	f
2523	2024-02-22 08:42:00	9796	5	2	f	\N	4	t
2524	2024-04-29 06:45:00	2392	3	2	f	\N	3	t
2525	2024-03-12 02:26:00	2791	1	2	f	\N	3	t
2526	2024-07-02 18:31:00	5067	5	3	f	2	3	f
2527	2024-09-04 21:16:00	6816	5	2	f	1	3	f
2528	2024-05-09 21:28:00	3725	2	4	t	\N	1	f
2529	2024-02-09 05:42:00	1725	5	3	t	\N	3	t
2530	2024-02-07 05:19:00	7547	5	3	f	1	2	t
2531	2024-08-21 08:47:00	6432	1	3	f	\N	3	f
2532	2024-08-07 02:07:00	8052	4	4	t	\N	2	t
2533	2024-04-26 22:39:00	2735	3	4	f	2	4	t
2534	2024-01-18 20:46:00	1172	2	2	f	\N	4	f
2535	2024-08-03 12:15:00	2615	2	1	t	\N	4	f
2536	2024-05-08 04:09:00	5239	2	1	f	1	2	t
2537	2024-01-04 22:01:00	4637	5	4	t	\N	4	t
2538	2024-04-03 21:12:00	9366	3	4	t	\N	3	t
2539	2024-04-01 03:20:00	9499	3	3	t	\N	4	t
2540	2024-01-15 11:57:00	4621	4	1	t	1	2	t
2541	2024-04-02 16:36:00	8303	3	3	t	1	4	f
2542	2024-05-25 05:44:00	7129	5	3	f	\N	4	t
2543	2024-06-13 16:44:00	7408	1	1	t	\N	2	t
2544	2024-03-28 21:21:00	8586	5	4	f	1	1	t
2545	2024-02-12 22:41:00	9199	2	4	t	\N	2	t
2546	2024-01-17 23:21:00	3469	4	3	f	2	3	f
2547	2024-04-18 07:31:00	6651	3	3	t	\N	4	t
2548	2024-02-06 21:01:00	1402	1	4	f	2	1	t
2549	2024-06-04 05:42:00	8909	5	3	t	\N	3	f
2550	2024-09-11 18:27:00	2712	4	1	f	\N	4	f
2551	2024-06-21 09:15:00	5840	5	3	t	1	3	t
2552	2024-01-28 17:47:00	7815	5	4	t	1	3	f
2553	2024-08-26 01:28:00	2406	2	1	f	\N	4	f
2554	2024-08-30 11:04:00	2901	3	4	f	\N	4	f
2555	2024-03-16 19:17:00	3321	2	2	f	\N	1	f
2556	2024-02-25 07:05:00	6707	4	2	t	1	4	t
2557	2024-04-03 16:08:00	6110	3	1	f	\N	2	f
2558	2024-07-13 21:29:00	6620	2	1	f	\N	4	f
2559	2024-04-13 13:56:00	8460	2	2	f	\N	2	t
2560	2024-07-03 10:55:00	4389	3	2	f	2	2	f
2561	2024-08-22 00:30:00	9537	4	3	t	\N	3	t
2562	2024-06-21 23:01:00	8912	4	2	f	\N	1	f
2563	2024-08-05 17:24:00	6706	3	3	f	\N	1	t
2564	2024-04-22 00:47:00	8801	5	3	t	\N	1	f
2565	2024-02-03 12:43:00	2599	3	3	t	1	1	t
2566	2024-07-30 18:16:00	8178	2	3	t	1	3	f
2567	2024-04-06 19:36:00	8412	4	1	t	2	4	t
2568	2024-03-05 11:43:00	6225	2	4	t	\N	4	t
2569	2024-01-16 00:19:00	2100	3	3	f	\N	2	f
2570	2024-01-17 01:42:00	5919	5	2	t	2	2	t
2571	2024-06-10 07:04:00	1732	2	2	t	\N	1	f
2572	2024-02-07 10:31:00	2885	2	1	t	\N	2	f
2573	2024-06-30 19:33:00	1370	5	2	t	2	2	t
2574	2024-05-16 09:27:00	6620	5	4	t	\N	2	t
2575	2024-07-24 14:09:00	2791	3	3	f	\N	2	f
2576	2024-01-04 05:28:00	3692	3	3	t	1	3	t
2577	2024-05-28 03:28:00	4996	5	1	t	\N	4	f
2578	2024-08-03 07:25:00	9454	5	1	t	\N	3	t
2579	2024-03-16 21:30:00	3858	5	1	t	\N	2	t
2580	2024-05-26 13:12:00	3623	1	1	f	\N	4	f
2581	2024-01-28 09:49:00	6422	5	1	f	\N	3	t
2582	2024-01-13 21:18:00	7985	2	3	f	2	2	t
2583	2024-08-10 00:06:00	8570	5	4	t	1	4	t
2584	2024-03-11 12:28:00	4798	4	4	t	\N	1	f
2585	2024-06-15 10:09:00	7636	5	4	t	\N	2	t
2586	2024-03-24 03:47:00	4022	4	1	f	\N	3	f
2587	2024-05-02 18:38:00	4053	5	2	f	\N	4	t
2588	2024-08-21 11:13:00	8080	2	4	t	1	2	f
2589	2024-07-22 11:13:00	7481	4	3	f	\N	1	t
2590	2024-07-16 18:27:00	1478	1	4	f	\N	4	t
2591	2024-04-05 11:43:00	4232	2	3	f	\N	3	f
2592	2024-04-04 17:49:00	8365	5	3	f	\N	1	f
2593	2024-01-14 04:02:00	8037	5	2	t	\N	1	f
2594	2024-08-15 20:06:00	7370	3	2	t	\N	3	f
2595	2024-08-10 05:31:00	1072	2	1	f	\N	1	t
2596	2024-07-13 03:21:00	4519	2	4	t	1	4	t
2597	2024-09-13 23:00:00	4371	5	4	t	1	1	t
2598	2024-09-11 21:00:00	5560	3	2	f	\N	4	t
2599	2024-07-29 02:35:00	2025	3	4	t	\N	1	f
2600	2024-01-05 13:34:00	2667	2	4	f	1	1	f
2601	2024-08-28 19:13:00	9796	4	4	t	\N	4	f
2602	2024-02-20 09:21:00	4063	4	2	f	2	2	t
2603	2024-01-16 04:48:00	6993	2	3	t	\N	4	f
2604	2024-06-12 03:26:00	6340	3	3	t	\N	2	t
2605	2024-06-30 05:11:00	4228	2	4	f	1	2	f
2606	2024-03-14 09:44:00	8496	1	2	f	2	4	t
2607	2024-06-21 02:32:00	2867	3	3	f	\N	1	t
2608	2024-02-10 15:26:00	5298	2	4	t	\N	3	f
2609	2024-08-20 22:27:00	9019	3	2	t	\N	2	t
2610	2024-03-23 15:49:00	9646	4	2	f	\N	3	f
2611	2024-05-22 13:15:00	6134	5	2	f	\N	2	t
2612	2024-04-25 04:51:00	7367	5	1	f	\N	2	t
2613	2024-03-09 11:39:00	7431	4	3	t	\N	1	t
2614	2024-06-18 22:35:00	2871	5	2	f	\N	3	f
2615	2024-04-18 07:39:00	6700	3	4	f	\N	3	t
2616	2024-03-14 22:13:00	6766	1	1	t	\N	3	f
2617	2024-05-05 23:20:00	8501	1	3	t	2	2	t
2618	2024-03-09 04:59:00	3826	1	4	f	\N	2	t
2619	2024-05-17 02:38:00	5873	3	3	f	2	4	t
2620	2024-02-12 23:12:00	2388	3	1	f	\N	1	t
2621	2024-07-19 21:49:00	3194	2	3	f	\N	2	f
2622	2024-07-31 10:16:00	6131	4	4	t	\N	1	t
2623	2024-06-11 18:47:00	2931	5	3	f	\N	2	t
2624	2024-01-14 18:56:00	4908	1	1	f	2	2	t
2625	2024-06-23 13:50:00	6003	3	1	f	\N	2	f
2626	2024-02-22 23:00:00	2916	3	1	f	\N	4	t
2627	2024-08-09 08:54:00	3999	3	1	f	1	3	t
2628	2024-06-06 15:04:00	7116	2	3	f	\N	3	t
2629	2024-07-02 19:14:00	3316	4	3	f	\N	2	t
2630	2024-02-25 00:23:00	9369	3	3	f	\N	2	f
2631	2024-07-18 12:10:00	7364	1	4	t	\N	1	f
2632	2024-02-23 21:26:00	7852	2	3	t	\N	3	f
2633	2024-04-18 01:07:00	3258	4	1	t	\N	1	t
2634	2024-06-16 20:36:00	7286	1	2	t	1	1	t
2635	2024-04-09 16:48:00	7931	2	3	f	\N	3	t
2636	2024-03-01 19:06:00	4043	1	3	t	\N	2	t
2637	2024-02-10 11:52:00	8973	3	4	t	\N	3	t
2638	2024-03-23 19:34:00	9804	5	2	f	\N	3	t
2639	2024-02-27 00:56:00	3838	1	4	t	1	4	t
2640	2024-02-07 12:43:00	3733	5	3	t	\N	2	t
2641	2024-06-04 17:27:00	9022	3	1	f	\N	1	t
2642	2024-03-05 19:25:00	5732	1	1	t	\N	3	t
2643	2024-01-23 03:20:00	3298	1	2	f	2	3	t
2644	2024-04-18 19:27:00	4065	3	1	t	\N	2	t
2645	2024-07-16 03:26:00	6154	5	2	t	2	3	f
2646	2024-08-04 20:26:00	8389	2	2	t	1	4	f
2647	2024-05-27 20:50:00	1878	2	4	f	2	2	f
2648	2024-01-22 09:43:00	6882	2	1	f	\N	2	t
2649	2024-04-13 06:11:00	1157	2	4	f	\N	1	t
2650	2024-05-31 21:25:00	8939	3	4	f	\N	1	t
2651	2024-08-04 14:00:00	3236	1	1	f	2	4	t
2652	2024-08-10 13:45:00	4196	3	4	f	1	2	f
2653	2024-04-24 13:30:00	7290	1	2	f	\N	3	f
2654	2024-03-04 09:13:00	9281	2	2	f	1	2	f
2655	2024-05-30 19:37:00	9109	3	2	f	\N	4	t
2656	2024-02-19 04:45:00	7703	1	3	f	1	1	f
2657	2024-05-09 21:13:00	9056	5	1	t	\N	4	t
2658	2024-09-15 03:43:00	7809	2	1	t	\N	2	t
2659	2024-05-24 08:48:00	8272	3	3	t	2	2	t
2660	2024-03-02 03:55:00	9006	2	3	f	1	3	t
2661	2024-05-11 11:39:00	3740	1	4	f	\N	4	t
2662	2024-05-09 10:58:00	2354	1	2	t	\N	2	f
2663	2024-07-15 07:46:00	1505	5	2	f	\N	3	t
2664	2024-03-13 17:56:00	4613	3	2	f	2	1	t
2665	2024-07-30 02:45:00	5785	5	2	t	\N	1	t
2666	2024-08-07 10:09:00	1535	4	2	t	\N	4	t
2667	2024-07-02 14:55:00	5503	3	2	t	2	4	t
2668	2024-09-07 03:19:00	4683	5	2	f	\N	4	t
2669	2024-03-30 21:54:00	9808	4	4	t	1	4	t
2670	2024-03-09 22:36:00	5729	1	1	t	\N	3	f
2671	2024-04-24 11:01:00	3755	5	1	f	1	1	t
2672	2024-08-09 17:34:00	8492	1	4	t	\N	4	t
2673	2024-08-26 12:32:00	9115	4	3	f	2	2	f
2674	2024-02-11 23:31:00	9369	2	3	f	\N	3	t
2675	2024-04-06 18:45:00	2854	3	2	f	\N	1	f
2676	2024-05-23 08:12:00	2871	3	4	f	1	1	t
2677	2024-03-05 21:31:00	5389	3	2	f	\N	2	t
2678	2024-04-13 14:03:00	9898	2	2	t	\N	3	t
2679	2024-03-13 12:43:00	7010	3	1	f	\N	3	f
2680	2024-08-02 19:35:00	9880	2	1	f	1	4	f
2681	2024-01-06 14:18:00	1681	3	2	t	\N	1	f
2682	2024-04-24 04:26:00	8231	4	3	f	\N	4	f
2683	2024-05-25 03:18:00	9951	4	2	f	2	2	f
2684	2024-07-17 05:10:00	4580	4	2	f	2	4	t
2685	2024-08-09 09:28:00	7965	4	3	f	\N	1	f
2686	2024-07-06 13:25:00	2677	3	2	t	1	4	f
2687	2024-06-07 14:42:00	5055	3	1	f	\N	2	t
2688	2024-05-30 08:18:00	5877	3	4	t	\N	1	f
2689	2024-03-07 07:45:00	1528	1	1	f	\N	4	f
2690	2024-03-25 03:36:00	8368	4	3	f	\N	2	f
2691	2024-01-03 00:21:00	5305	3	3	f	1	1	t
2692	2024-05-26 01:29:00	6711	1	4	f	1	1	t
2693	2024-04-13 14:25:00	2425	2	4	f	1	3	t
2694	2024-07-02 18:58:00	8193	5	2	t	1	3	t
2695	2024-07-12 18:42:00	2923	3	4	f	2	1	t
2696	2024-01-04 21:58:00	4882	4	3	f	2	2	t
2697	2024-08-08 17:32:00	4438	3	4	f	2	3	t
2698	2024-07-20 02:14:00	6744	5	2	f	2	3	f
2699	2024-09-13 21:16:00	8015	5	1	t	\N	1	t
2700	2024-08-16 08:23:00	3719	4	2	f	1	2	t
2701	2024-04-25 16:54:00	3281	5	2	t	\N	3	t
2702	2024-06-28 20:35:00	4385	4	3	t	\N	2	f
2703	2024-08-19 11:23:00	4390	1	3	t	2	1	f
2704	2024-09-06 16:19:00	1972	1	4	t	\N	4	t
2705	2024-07-15 01:11:00	6747	1	4	f	\N	2	t
2706	2024-06-15 23:22:00	9720	2	1	t	\N	4	t
2707	2024-05-12 23:29:00	5605	4	3	f	2	2	t
2708	2024-07-30 12:48:00	9827	3	4	f	\N	2	f
2709	2024-07-04 11:00:00	3758	1	4	f	\N	3	t
2710	2024-03-21 04:31:00	6302	4	2	t	\N	3	f
2711	2024-05-16 04:47:00	5794	2	2	t	\N	3	f
2712	2024-03-23 11:09:00	5740	4	1	f	1	1	t
2713	2024-03-15 08:38:00	5380	3	2	f	\N	4	t
2714	2024-09-14 18:38:00	9428	3	1	f	\N	2	t
2715	2024-03-09 05:08:00	2560	2	2	t	\N	4	t
2716	2024-04-07 02:58:00	3221	4	4	t	\N	2	f
2717	2024-08-26 20:56:00	7743	4	1	f	\N	2	t
2718	2024-09-12 12:17:00	1971	1	1	t	\N	3	f
2719	2024-08-21 06:47:00	5543	2	2	f	\N	4	f
2720	2024-01-21 00:23:00	3078	1	2	f	1	1	t
2721	2024-09-11 20:38:00	3174	3	4	t	\N	4	f
2722	2024-04-02 10:58:00	5090	3	3	f	\N	2	f
2723	2024-06-25 08:38:00	3396	4	1	f	\N	4	f
2724	2024-02-10 09:05:00	6277	5	2	f	\N	4	t
2725	2024-03-10 02:14:00	5055	1	1	t	\N	4	t
2726	2024-04-07 21:13:00	7434	5	4	t	\N	3	t
2727	2024-02-09 20:06:00	9019	2	3	f	\N	3	t
2728	2024-06-22 18:47:00	3329	5	4	f	\N	1	f
2729	2024-05-21 06:37:00	5402	5	3	t	\N	4	t
2730	2024-01-15 13:21:00	7786	3	2	t	\N	1	f
2731	2024-01-07 03:41:00	7146	5	3	t	2	1	f
2732	2024-02-28 09:42:00	8405	4	1	f	1	1	f
2733	2024-01-13 07:12:00	2237	2	1	f	1	1	f
2734	2024-03-29 08:12:00	2525	3	3	t	\N	1	t
2735	2024-02-11 01:26:00	7600	3	4	t	\N	3	t
2736	2024-01-05 10:44:00	9447	3	4	f	\N	1	f
2737	2024-02-23 08:14:00	5558	2	3	t	1	3	f
2738	2024-09-07 17:38:00	7046	1	1	t	\N	2	t
2739	2024-02-23 21:22:00	8449	4	3	f	1	4	f
2740	2024-04-10 03:37:00	8996	5	1	t	\N	4	t
2741	2024-06-20 10:06:00	6362	5	2	f	\N	2	t
2742	2024-03-19 23:18:00	1040	4	1	f	\N	1	f
2743	2024-06-28 14:32:00	2526	5	4	f	\N	1	f
2744	2024-02-09 19:56:00	8511	1	3	f	\N	2	t
2745	2024-08-06 10:08:00	6869	1	3	f	\N	2	t
2746	2024-01-28 13:34:00	2037	2	2	f	\N	3	t
2747	2024-03-11 08:03:00	9756	2	1	t	\N	1	t
2748	2024-02-15 23:58:00	7516	3	3	t	1	1	t
2749	2024-05-02 03:56:00	4568	4	1	t	2	3	t
2750	2024-08-08 19:59:00	8039	5	3	f	\N	1	f
2751	2024-03-21 20:31:00	4470	4	1	f	\N	1	f
2752	2024-01-18 05:41:00	9105	1	4	t	\N	2	t
2753	2024-04-20 18:14:00	5399	2	4	f	\N	2	t
2754	2024-08-04 06:58:00	6289	4	2	f	1	3	f
2755	2024-01-31 04:40:00	5646	2	4	t	\N	1	f
2756	2024-02-06 10:56:00	6533	3	1	f	1	1	f
2757	2024-02-25 20:27:00	9967	5	1	t	\N	4	t
2758	2024-02-29 22:08:00	3139	4	3	f	\N	3	f
2759	2024-08-18 16:44:00	8951	3	3	t	1	1	t
2760	2024-06-22 09:11:00	6631	2	1	f	\N	2	t
2761	2024-02-07 13:31:00	1793	5	2	t	\N	3	f
2762	2024-08-28 22:40:00	1752	4	1	t	\N	2	f
2763	2024-06-17 07:07:00	2631	5	2	f	\N	3	t
2764	2024-05-19 02:29:00	8529	2	2	t	\N	4	t
2765	2024-09-14 05:25:00	1266	2	3	t	1	3	f
2766	2024-02-14 15:57:00	3035	3	2	t	\N	4	f
2767	2024-04-15 19:24:00	3588	5	3	f	2	1	t
2768	2024-07-24 07:13:00	8230	2	3	t	\N	2	t
2769	2024-05-17 17:40:00	8479	1	3	f	2	3	f
2770	2024-04-10 07:37:00	1011	3	3	t	\N	4	t
2771	2024-04-07 20:49:00	8009	2	2	f	\N	2	f
2772	2024-09-11 22:34:00	4314	1	4	t	\N	3	f
2773	2024-07-13 19:50:00	3161	1	2	f	\N	4	t
2774	2024-02-10 21:09:00	5945	1	1	f	\N	1	t
2775	2024-03-17 17:19:00	3604	3	3	f	\N	3	t
2776	2024-07-04 10:04:00	5489	3	4	t	\N	1	t
2777	2024-03-01 07:11:00	2529	2	1	f	\N	3	f
2778	2024-07-22 12:22:00	6905	4	1	f	\N	4	f
2779	2024-04-15 15:05:00	5102	1	4	f	\N	3	f
2780	2024-01-18 11:01:00	2350	1	3	f	2	4	t
2781	2024-02-11 05:28:00	7092	3	2	f	\N	3	t
2782	2024-04-20 22:13:00	3711	2	1	f	1	2	t
2783	2024-05-08 15:10:00	1848	2	2	t	\N	4	f
2784	2024-07-30 10:39:00	7493	4	2	f	\N	3	f
2785	2024-01-03 15:38:00	6005	5	3	t	1	2	t
2786	2024-02-01 09:27:00	4836	4	4	f	\N	1	f
2787	2024-08-31 01:13:00	8032	1	2	f	\N	3	t
2788	2024-07-23 23:48:00	2494	3	4	f	2	4	f
2789	2024-09-10 08:27:00	2559	1	4	f	2	3	f
2790	2024-08-03 17:57:00	1017	4	1	f	1	3	t
2791	2024-06-12 07:28:00	4496	3	4	t	2	3	f
2792	2024-07-26 19:04:00	8812	3	1	t	\N	2	t
2793	2024-01-13 18:41:00	2276	3	1	t	\N	2	t
2794	2024-09-01 18:21:00	3174	1	4	t	\N	2	f
2795	2024-01-01 02:59:00	4705	3	1	f	\N	2	t
2796	2024-01-31 05:52:00	9510	1	1	t	2	2	f
2797	2024-04-07 22:05:00	8291	3	1	f	\N	3	t
2798	2024-06-26 19:17:00	1152	4	2	f	2	3	t
2799	2024-06-18 01:56:00	1132	1	1	f	\N	1	f
2800	2024-05-21 08:07:00	6629	5	2	f	\N	4	t
2801	2024-03-06 09:37:00	2975	2	2	f	2	4	t
2802	2024-09-15 11:34:00	7919	4	2	t	\N	1	t
2803	2024-02-11 01:29:00	3165	2	2	t	\N	4	f
2804	2024-08-30 00:17:00	8826	5	2	t	\N	2	f
2805	2024-03-15 05:43:00	2160	4	2	f	1	4	f
2806	2024-07-24 02:34:00	4751	3	3	t	1	4	f
2807	2024-04-07 18:07:00	7276	2	3	f	1	3	f
2808	2024-04-23 10:54:00	2463	4	2	t	\N	1	t
2809	2024-07-11 11:13:00	2678	5	2	t	\N	2	t
2810	2024-09-04 21:11:00	2690	1	4	f	\N	2	t
2811	2024-05-11 03:18:00	6133	2	3	f	2	1	f
2812	2024-01-24 17:51:00	7022	2	3	t	\N	3	f
2813	2024-06-16 22:02:00	5902	2	2	t	\N	2	t
2814	2024-02-12 13:32:00	3246	3	4	f	\N	4	f
2815	2024-03-24 23:04:00	7270	5	3	f	\N	2	f
2816	2024-03-25 04:53:00	3181	2	4	t	\N	2	f
2817	2024-01-01 14:37:00	3340	2	1	f	1	2	t
2818	2024-04-09 01:34:00	2120	1	2	t	\N	1	t
2819	2024-02-27 06:39:00	9691	2	4	t	1	3	t
2820	2024-08-23 11:52:00	1138	4	4	f	\N	1	t
2821	2024-05-17 13:40:00	3688	2	3	f	\N	1	f
2822	2024-04-27 09:24:00	8210	4	1	t	\N	2	t
2823	2024-02-10 18:15:00	6753	4	2	t	\N	2	t
2824	2024-03-26 15:27:00	4490	5	1	t	\N	1	t
2825	2024-05-10 14:42:00	3480	4	4	f	\N	1	f
2826	2024-02-05 06:50:00	7745	4	2	t	\N	3	f
2827	2024-07-23 21:08:00	8248	3	2	f	\N	4	t
2828	2024-05-15 19:29:00	4559	5	3	f	\N	2	f
2829	2024-05-03 08:47:00	2420	3	3	t	1	4	f
2830	2024-01-28 13:55:00	2646	5	4	f	\N	4	t
2831	2024-03-23 10:45:00	3293	3	2	f	\N	4	f
2832	2024-06-28 08:12:00	3017	4	2	t	\N	2	f
2833	2024-03-05 15:51:00	7291	3	2	f	2	4	f
2834	2024-06-10 14:25:00	6759	3	4	f	2	3	t
2835	2024-09-06 11:22:00	8035	5	2	f	\N	4	f
2836	2024-05-23 10:24:00	6152	5	3	t	2	4	t
2837	2024-08-18 16:57:00	3290	2	3	f	2	3	f
2838	2024-01-20 02:51:00	5059	1	2	t	\N	2	t
2839	2024-09-06 01:50:00	5537	4	4	t	\N	2	f
2840	2024-02-12 17:23:00	2380	2	1	t	2	2	t
2841	2024-03-24 04:20:00	5065	1	4	f	\N	1	f
2842	2024-04-05 00:55:00	5668	5	1	t	\N	3	f
2843	2024-08-11 07:19:00	1439	5	4	t	\N	4	t
2844	2024-09-07 13:33:00	5942	5	2	t	\N	2	f
2845	2024-07-08 12:22:00	4366	3	1	f	\N	4	t
2846	2024-05-30 17:03:00	9482	5	1	f	2	1	t
2847	2024-07-31 15:35:00	9348	2	3	t	2	4	f
2848	2024-04-30 18:05:00	4090	2	1	f	1	2	t
2849	2024-01-23 17:03:00	7418	1	3	f	\N	4	f
2850	2024-03-11 10:05:00	5842	1	1	t	2	4	f
2851	2024-06-26 08:17:00	1894	2	4	f	2	4	f
2852	2024-05-20 15:40:00	4921	5	1	f	\N	2	t
2853	2024-02-03 04:03:00	9108	4	1	t	\N	3	f
2854	2024-05-28 06:38:00	7322	3	1	t	2	4	t
2855	2024-01-14 23:53:00	2847	3	4	f	1	3	t
2856	2024-01-19 11:23:00	4949	1	3	t	\N	4	t
2857	2024-01-23 13:06:00	9185	3	2	t	\N	4	f
2858	2024-06-01 21:46:00	2163	2	3	t	1	1	f
2859	2024-08-04 20:49:00	9655	1	3	t	1	2	t
2860	2024-08-16 08:13:00	1197	2	1	t	\N	1	t
2861	2024-05-19 04:13:00	6916	4	3	t	1	4	f
2862	2024-04-28 08:47:00	6185	4	2	t	2	2	f
2863	2024-07-11 17:28:00	3162	4	2	t	\N	3	t
2864	2024-02-10 04:16:00	7337	4	1	f	\N	2	f
2865	2024-07-21 16:51:00	7895	3	2	t	2	2	t
2866	2024-08-06 01:09:00	6986	2	2	t	2	1	f
2867	2024-05-28 15:39:00	9951	2	3	f	1	1	t
2868	2024-04-25 12:07:00	3830	1	2	f	1	4	f
2869	2024-05-12 12:03:00	8717	2	3	t	1	2	f
2870	2024-04-16 06:04:00	2195	3	2	f	\N	3	f
2871	2024-09-05 14:05:00	1273	3	3	f	\N	2	f
2872	2024-03-07 20:27:00	2106	2	3	t	\N	4	t
2873	2024-05-23 18:56:00	1225	2	1	t	\N	4	f
2874	2024-05-26 07:16:00	5295	4	1	t	1	1	f
2875	2024-07-30 17:24:00	4534	2	3	f	\N	3	t
2876	2024-05-30 16:30:00	1652	2	2	t	2	2	t
2877	2024-05-15 03:10:00	1990	4	1	t	\N	3	t
2878	2024-02-17 16:07:00	7520	1	1	t	\N	4	t
2879	2024-01-26 12:56:00	9300	2	4	t	1	4	t
2880	2024-05-26 09:29:00	5693	1	3	t	\N	2	t
2881	2024-08-10 13:43:00	9209	4	4	f	1	3	t
2882	2024-08-18 19:42:00	7806	1	1	f	2	2	t
2883	2024-08-05 17:11:00	7939	2	3	t	\N	2	t
2884	2024-05-31 01:43:00	7590	5	4	f	2	2	t
2885	2024-08-07 05:20:00	2350	3	4	t	\N	4	t
2886	2024-01-10 07:47:00	9791	5	2	f	2	4	t
2887	2024-04-02 05:59:00	9808	5	2	t	2	1	f
2888	2024-08-04 01:16:00	3501	5	3	t	\N	3	t
2889	2024-05-18 18:30:00	5546	2	4	f	\N	3	t
2890	2024-07-20 03:23:00	2369	4	4	t	\N	3	f
2891	2024-08-27 14:39:00	6077	5	3	t	\N	3	t
2892	2024-03-08 08:20:00	2294	4	2	f	\N	3	t
2893	2024-05-12 09:15:00	9377	4	4	t	1	4	t
2894	2024-07-29 02:21:00	4329	2	2	t	\N	4	f
2895	2024-06-24 00:34:00	3545	5	4	f	1	4	t
2896	2024-05-17 08:08:00	9788	3	1	t	1	1	t
2897	2024-01-15 14:11:00	6353	2	1	f	\N	2	f
2898	2024-09-03 01:19:00	7401	3	2	f	\N	1	t
2899	2024-08-11 08:16:00	2083	1	4	f	\N	4	f
2900	2024-08-29 03:48:00	6081	4	4	t	\N	2	t
2901	2024-03-03 22:37:00	8167	1	2	f	\N	1	t
2902	2024-07-23 06:23:00	4909	4	1	t	\N	4	t
2903	2024-03-12 12:59:00	1948	3	1	t	\N	2	t
2904	2024-04-26 22:21:00	5005	2	3	f	\N	1	f
2905	2024-03-09 13:25:00	2412	4	3	t	\N	2	f
2906	2024-05-26 14:23:00	8118	5	4	t	\N	2	t
2907	2024-05-28 09:17:00	2900	3	4	t	1	2	t
2908	2024-06-14 19:21:00	8428	3	3	t	2	1	t
2909	2024-06-26 08:19:00	1901	4	2	t	2	3	f
2910	2024-08-15 21:12:00	6067	2	3	t	\N	3	t
2911	2024-08-11 21:33:00	3877	5	3	f	2	1	f
2912	2024-08-28 00:21:00	2956	5	3	f	\N	2	f
2913	2024-06-18 20:00:00	1207	3	2	t	\N	4	f
2914	2024-01-14 20:36:00	3248	2	2	f	\N	3	t
2915	2024-08-20 09:54:00	1185	5	1	f	2	2	t
2916	2024-07-30 12:34:00	3684	1	2	t	\N	4	f
2917	2024-07-04 21:12:00	9133	1	2	t	\N	1	t
2918	2024-03-08 18:46:00	6680	1	3	t	1	3	t
2919	2024-05-13 19:02:00	9568	2	3	f	\N	4	f
2920	2024-08-04 19:48:00	9474	5	1	t	1	2	f
2921	2024-05-08 03:54:00	5247	1	2	t	1	3	f
2922	2024-04-15 09:25:00	3735	4	4	f	2	2	t
2923	2024-02-26 02:57:00	7092	2	4	f	\N	4	t
2924	2024-01-25 12:36:00	3079	5	1	f	\N	3	t
2925	2024-05-30 22:30:00	5403	1	4	f	\N	2	t
2926	2024-08-01 17:07:00	2934	3	2	f	2	3	f
2927	2024-06-20 15:51:00	1480	5	4	f	1	4	f
2928	2024-05-08 02:46:00	6488	4	2	f	\N	3	t
2929	2024-05-04 06:55:00	8034	1	4	f	2	3	t
2930	2024-03-12 23:59:00	5456	2	2	t	1	4	t
2931	2024-03-31 23:11:00	9582	2	1	f	2	2	f
2932	2024-01-30 14:04:00	2046	4	2	t	\N	3	t
2933	2024-06-02 14:15:00	5308	4	4	t	\N	4	f
2934	2024-02-22 22:45:00	2262	2	1	f	\N	3	t
2935	2024-08-05 12:54:00	9128	5	4	t	1	1	f
2936	2024-01-04 01:38:00	8457	2	4	f	\N	3	f
2937	2024-07-07 19:16:00	9368	1	1	f	2	3	f
2938	2024-04-06 05:05:00	6900	4	2	f	\N	3	t
2939	2024-08-09 17:21:00	1908	2	2	f	\N	3	t
2940	2024-02-13 19:07:00	9185	3	4	f	\N	4	t
2941	2024-06-25 18:47:00	3734	5	2	t	2	4	f
2942	2024-08-20 01:19:00	7024	3	1	t	\N	3	f
2943	2024-06-24 07:09:00	3577	1	4	f	1	2	t
2944	2024-09-13 21:47:00	5179	3	3	f	\N	2	f
2945	2024-03-13 20:15:00	2685	5	1	t	\N	4	t
2946	2024-03-31 22:41:00	2889	2	1	t	\N	3	f
2947	2024-01-10 05:24:00	4742	4	2	t	\N	1	t
2948	2024-08-24 03:18:00	9336	3	3	f	1	4	t
2949	2024-03-15 09:06:00	1042	1	1	f	\N	2	f
2950	2024-07-09 15:15:00	1721	5	3	f	\N	3	t
2951	2024-03-10 03:03:00	1201	1	1	t	\N	4	f
2952	2024-07-27 21:58:00	5006	2	2	f	\N	1	t
2953	2024-07-19 08:01:00	1753	4	3	f	\N	2	t
2954	2024-01-13 06:35:00	8729	1	1	f	1	2	f
2955	2024-07-20 21:14:00	6963	5	4	f	1	2	t
2956	2024-02-17 11:21:00	7274	5	4	t	\N	3	f
2957	2024-01-19 01:55:00	3458	1	1	f	\N	3	t
2958	2024-01-04 22:33:00	3932	5	4	f	\N	2	t
2959	2024-02-17 15:52:00	1579	4	1	t	\N	1	f
2960	2024-09-09 07:43:00	7870	2	2	f	\N	2	f
2961	2024-07-04 22:42:00	4678	2	4	t	\N	1	t
2962	2024-03-11 16:51:00	6272	5	4	f	\N	3	f
2963	2024-07-10 09:33:00	5067	1	4	f	\N	3	f
2964	2024-08-20 17:22:00	7819	4	2	f	\N	1	t
2965	2024-03-03 19:40:00	6241	5	4	f	2	2	f
2966	2024-02-11 21:26:00	5444	2	3	f	1	4	t
2967	2024-04-19 13:16:00	2276	5	1	f	\N	4	f
2968	2024-05-15 05:57:00	7108	1	3	t	1	2	t
2969	2024-06-24 13:36:00	2956	1	4	f	\N	3	t
2970	2024-09-07 15:17:00	9225	3	1	t	\N	3	f
2971	2024-03-20 00:57:00	1862	3	3	f	2	3	t
2972	2024-05-17 03:25:00	3938	2	2	f	\N	2	t
2973	2024-05-25 17:39:00	4656	2	1	t	\N	1	t
2974	2024-05-16 17:31:00	9450	1	4	f	2	3	t
2975	2024-05-16 09:41:00	1752	3	4	t	2	3	f
2976	2024-06-24 09:19:00	7568	1	3	t	2	4	t
2977	2024-03-07 03:09:00	2129	4	4	t	\N	3	f
2978	2024-08-22 15:06:00	8620	5	4	f	2	1	t
2979	2024-06-17 23:56:00	5625	2	2	t	\N	4	t
2980	2024-08-07 22:34:00	6090	2	3	t	\N	1	f
2981	2024-02-10 10:27:00	6362	2	3	f	2	4	t
2982	2024-01-16 14:21:00	2415	5	2	f	\N	1	t
2983	2024-08-23 00:14:00	8483	3	1	t	\N	1	t
2984	2024-05-06 17:19:00	1130	1	1	t	\N	3	t
2985	2024-08-13 05:45:00	7044	1	2	t	\N	2	t
2986	2024-03-10 18:12:00	4287	1	2	t	\N	1	t
2987	2024-09-09 08:40:00	5777	4	4	t	\N	3	t
2988	2024-01-29 17:39:00	5979	3	3	f	\N	3	f
2989	2024-04-09 05:44:00	4974	5	1	t	\N	3	f
2990	2024-01-15 00:33:00	8600	4	3	f	\N	1	f
2991	2024-08-31 22:00:00	7033	3	2	f	\N	1	t
2992	2024-05-28 03:16:00	9083	4	3	f	\N	4	t
2993	2024-02-29 21:57:00	4201	1	3	f	\N	1	f
2994	2024-04-21 06:21:00	9954	5	2	t	\N	2	t
2995	2024-08-14 14:51:00	5016	2	1	t	2	4	t
2996	2024-08-11 19:56:00	3466	2	4	f	\N	3	t
2997	2024-02-25 20:35:00	1104	2	1	f	\N	2	t
2998	2024-04-09 09:50:00	7718	5	3	t	2	1	f
2999	2024-04-16 11:14:00	1391	1	1	t	1	3	t
3000	2024-07-15 04:25:00	4817	1	2	f	\N	4	f
3001	2024-01-11 17:14:00	9872	1	2	t	\N	3	f
3002	2024-05-19 22:55:00	6675	5	1	t	\N	1	t
3003	2024-03-08 09:38:00	1157	4	4	t	\N	3	f
3004	2024-08-04 20:03:00	6488	5	2	f	\N	4	t
3005	2024-07-12 21:51:00	1023	1	3	t	1	4	f
3006	2024-05-16 15:26:00	7164	3	2	t	\N	4	t
3007	2024-04-25 07:01:00	6038	5	2	f	\N	1	t
3008	2024-08-24 19:32:00	2703	4	2	t	\N	3	f
3009	2024-08-03 07:21:00	4361	3	3	f	2	3	f
3010	2024-06-18 10:21:00	9680	5	1	t	2	3	t
3011	2024-07-02 14:24:00	4902	2	3	f	\N	3	t
3012	2024-01-25 23:35:00	7878	3	1	f	\N	4	f
3013	2024-05-20 08:41:00	9061	5	4	t	1	1	f
3014	2024-01-26 18:37:00	1981	2	3	t	\N	4	t
3015	2024-03-26 11:26:00	3332	5	2	f	\N	3	t
3016	2024-03-17 01:18:00	5584	5	2	f	\N	2	f
3017	2024-05-21 21:39:00	2524	4	3	f	\N	2	t
3018	2024-09-06 00:00:00	1719	1	1	t	1	3	f
3019	2024-08-07 10:48:00	4792	1	4	f	\N	1	f
3020	2024-02-28 12:09:00	9515	4	2	f	1	1	f
3021	2024-07-27 19:06:00	7767	4	2	t	\N	2	t
3022	2024-06-28 11:22:00	7102	3	2	f	\N	1	t
3023	2024-07-03 23:38:00	8511	1	3	t	\N	3	t
3024	2024-03-27 19:53:00	2391	4	2	f	1	4	t
3025	2024-04-26 09:51:00	2565	3	4	t	2	1	f
3026	2024-01-06 06:54:00	9280	3	3	t	\N	4	f
3027	2024-06-18 19:42:00	3187	1	3	t	\N	2	f
3028	2024-07-13 20:18:00	7461	3	1	t	\N	2	f
3029	2024-04-23 11:56:00	2226	5	2	t	\N	3	t
3030	2024-04-15 09:27:00	2020	1	1	t	2	4	f
3031	2024-09-11 18:05:00	8126	3	2	t	2	1	f
3032	2024-02-04 14:16:00	3141	1	2	t	\N	1	t
3033	2024-09-13 05:16:00	4879	5	2	f	\N	4	f
3034	2024-08-03 23:53:00	5778	3	2	f	\N	1	f
3035	2024-06-09 08:53:00	5276	3	4	f	\N	2	t
3036	2024-09-13 04:44:00	6161	5	4	f	\N	2	f
3037	2024-07-23 08:57:00	7438	3	1	f	\N	4	f
3038	2024-05-03 02:57:00	6345	1	2	f	\N	1	t
3039	2024-05-03 07:39:00	6211	4	2	t	2	2	t
3040	2024-01-27 01:40:00	8417	2	1	t	\N	3	t
3041	2024-03-30 10:20:00	5455	2	1	t	\N	3	f
3042	2024-05-28 20:51:00	4827	4	4	f	\N	4	f
3043	2024-01-02 23:35:00	2223	4	3	f	\N	4	f
3044	2024-04-20 11:53:00	4321	1	1	t	2	4	t
3045	2024-07-11 13:30:00	3230	3	4	t	\N	3	t
3046	2024-03-03 22:11:00	2785	4	3	t	1	2	t
3047	2024-08-26 01:17:00	3546	2	2	t	\N	4	t
3048	2024-05-10 17:18:00	2731	4	3	t	1	2	t
3049	2024-08-20 15:05:00	3693	2	3	f	\N	4	f
3050	2024-06-02 05:23:00	8365	1	1	t	\N	2	t
3051	2024-05-31 18:37:00	8635	4	2	t	\N	3	t
3052	2024-03-13 12:08:00	6145	3	4	t	\N	2	t
3053	2024-04-11 19:47:00	7660	5	4	t	\N	4	f
3054	2024-05-21 21:16:00	2978	1	2	f	2	4	t
3055	2024-06-14 01:06:00	9780	5	1	f	\N	2	f
3056	2024-07-17 01:50:00	6870	3	1	t	\N	3	f
3057	2024-01-05 12:09:00	4401	2	3	f	\N	2	f
3058	2024-03-31 00:11:00	8404	5	2	f	\N	3	f
3059	2024-01-20 12:01:00	6051	3	1	t	1	2	f
3060	2024-08-04 16:41:00	8591	2	4	t	\N	4	f
3061	2024-09-02 02:20:00	5341	1	4	t	\N	2	t
3062	2024-01-21 02:31:00	2964	3	1	f	1	4	t
3063	2024-01-11 18:21:00	2481	3	3	t	\N	1	t
3064	2024-04-30 19:46:00	3582	5	4	t	2	2	f
3065	2024-04-24 13:35:00	5984	3	2	f	\N	2	t
3066	2024-05-31 23:03:00	1660	4	3	t	\N	3	t
3067	2024-06-25 16:31:00	4522	2	1	f	1	3	f
3068	2024-04-13 08:14:00	6370	5	4	t	\N	1	t
3069	2024-09-11 09:40:00	3430	4	4	t	\N	1	t
3070	2024-05-21 15:06:00	2494	4	2	t	2	2	t
3071	2024-08-21 11:01:00	5066	3	1	f	\N	2	t
3072	2024-06-17 04:12:00	6828	2	3	f	\N	4	f
3073	2024-06-06 11:13:00	7492	3	2	t	\N	2	t
3074	2024-08-03 10:29:00	9412	1	4	f	\N	4	t
3075	2024-06-15 23:45:00	1802	2	4	t	\N	4	f
3076	2024-01-27 19:26:00	5896	1	3	t	2	2	t
3077	2024-02-04 21:53:00	5262	3	2	t	\N	2	f
3078	2024-03-15 13:18:00	3848	5	2	t	\N	2	t
3079	2024-05-18 09:51:00	1509	4	3	f	\N	3	f
3080	2024-06-10 14:52:00	7625	4	3	t	\N	3	f
3081	2024-07-21 20:14:00	8408	4	1	t	\N	2	f
3082	2024-03-14 06:02:00	5093	3	3	f	\N	2	t
3083	2024-07-11 13:51:00	2551	5	2	t	2	1	t
3084	2024-03-16 01:08:00	8570	4	2	f	2	1	f
3085	2024-03-28 13:24:00	2669	1	2	t	1	2	t
3086	2024-05-12 10:37:00	3290	1	3	t	\N	4	t
3087	2024-02-13 10:06:00	2989	4	2	t	\N	2	f
3088	2024-03-22 11:36:00	1195	1	2	t	\N	3	f
3089	2024-08-17 05:07:00	2010	1	3	f	\N	1	f
3090	2024-04-10 05:24:00	4641	3	1	t	2	1	f
3091	2024-06-26 00:52:00	3141	1	4	f	\N	1	f
3092	2024-03-07 21:46:00	4246	3	3	t	1	1	f
3093	2024-05-04 12:37:00	7563	4	3	t	\N	3	t
3094	2024-08-02 04:05:00	7098	3	2	f	\N	4	f
3095	2024-04-10 07:45:00	2376	1	2	t	\N	4	t
3096	2024-08-20 15:20:00	5240	5	1	f	1	2	t
3097	2024-06-21 04:46:00	2228	5	2	f	1	2	t
3098	2024-06-01 19:31:00	1357	5	3	t	2	3	f
3099	2024-06-26 19:58:00	2056	4	3	t	\N	4	f
3100	2024-07-18 19:38:00	4239	4	4	t	\N	1	f
3101	2024-06-20 17:38:00	8265	4	1	t	\N	4	t
3102	2024-07-06 18:46:00	3110	2	2	f	1	4	f
3103	2024-07-31 07:24:00	2506	4	4	f	1	4	t
3104	2024-08-06 10:53:00	6432	3	1	f	2	4	t
3105	2024-05-21 21:04:00	3007	5	4	t	\N	2	f
3106	2024-01-19 23:25:00	1699	1	4	t	1	1	t
3107	2024-01-24 04:55:00	8552	4	3	f	\N	2	t
3108	2024-03-10 18:05:00	1829	1	3	t	1	3	t
3109	2024-01-30 13:17:00	3752	2	3	t	2	4	t
3110	2024-01-22 05:53:00	8096	1	4	t	\N	3	t
3111	2024-03-17 10:08:00	7471	4	4	f	2	1	t
3112	2024-06-22 03:44:00	9128	1	4	f	\N	2	f
3113	2024-09-14 14:46:00	1483	1	2	f	\N	3	t
3114	2024-04-09 18:32:00	7270	3	4	f	1	3	t
3115	2024-06-25 15:10:00	7990	2	3	f	\N	2	t
3116	2024-04-26 20:40:00	3831	4	3	t	\N	2	t
3117	2024-07-15 03:18:00	6799	4	1	f	\N	3	t
3118	2024-07-17 11:36:00	4517	5	2	t	\N	4	f
3119	2024-06-29 20:09:00	4066	5	4	f	2	4	t
3120	2024-06-22 12:18:00	5505	2	1	f	\N	1	t
3121	2024-08-05 04:31:00	5585	3	1	f	\N	2	t
3122	2024-02-17 21:13:00	8307	1	1	f	1	1	f
3123	2024-02-18 08:06:00	3435	2	2	t	\N	1	t
3124	2024-01-14 01:37:00	1567	5	4	f	\N	1	t
3125	2024-07-22 09:50:00	5026	4	1	t	2	1	t
3126	2024-07-21 13:55:00	5835	3	4	f	\N	1	t
3127	2024-06-10 07:48:00	9173	3	2	t	\N	1	t
3128	2024-07-25 09:21:00	7750	1	4	f	\N	3	f
3129	2024-01-01 11:24:00	8848	1	1	t	\N	4	t
3130	2024-01-26 09:30:00	1999	2	3	t	2	3	t
3131	2024-04-01 12:40:00	2437	3	3	f	\N	2	f
3132	2024-06-30 23:51:00	5583	2	3	f	\N	1	t
3133	2024-08-17 13:05:00	7275	4	3	t	\N	1	t
3134	2024-06-30 14:22:00	3248	1	4	t	\N	2	t
3135	2024-03-15 18:02:00	7868	5	3	t	1	2	t
3136	2024-03-19 23:10:00	4267	3	1	f	1	4	f
3137	2024-01-27 04:04:00	9614	4	3	t	\N	1	f
3138	2024-08-08 03:18:00	5082	5	3	t	\N	2	t
3139	2024-01-16 07:49:00	9907	3	1	t	1	4	t
3140	2024-02-26 15:54:00	1319	5	3	f	\N	4	t
3141	2024-05-27 00:15:00	7266	4	2	f	\N	2	f
3142	2024-04-04 02:50:00	6883	1	2	f	\N	2	t
3143	2024-07-01 03:13:00	8859	2	4	f	\N	3	f
3144	2024-08-26 09:44:00	9921	4	1	t	\N	3	f
3145	2024-05-19 13:20:00	8940	3	3	t	\N	4	t
3146	2024-07-08 06:39:00	6636	5	3	f	\N	4	f
3147	2024-04-21 16:41:00	9231	1	1	t	\N	1	f
3148	2024-02-22 08:04:00	6269	4	3	t	\N	4	t
3149	2024-06-15 18:59:00	7363	3	1	f	\N	1	f
3150	2024-04-01 05:41:00	5430	4	2	f	\N	1	f
3151	2024-06-14 21:36:00	3946	1	2	t	\N	3	f
3152	2024-03-15 15:17:00	1427	2	2	f	\N	3	t
3153	2024-03-23 22:54:00	6224	4	3	f	\N	1	t
3154	2024-02-08 14:49:00	4588	1	1	t	2	2	f
3155	2024-06-08 07:30:00	1480	2	3	f	2	2	t
3156	2024-04-24 07:54:00	5602	5	1	t	\N	1	t
3157	2024-06-16 13:39:00	1959	2	1	t	1	4	f
3158	2024-07-14 16:34:00	8728	2	1	f	\N	3	t
3159	2024-03-28 06:16:00	9674	4	1	t	1	4	t
3160	2024-06-14 14:49:00	6856	2	1	t	\N	4	t
3161	2024-07-29 01:20:00	4813	3	1	f	1	3	f
3162	2024-06-18 06:01:00	3615	4	3	f	2	1	f
3163	2024-06-28 11:10:00	2640	5	1	f	\N	4	t
3164	2024-08-02 21:07:00	5060	2	3	t	2	1	f
3165	2024-09-04 21:59:00	4951	3	3	t	\N	3	f
3166	2024-09-12 04:56:00	5366	4	2	f	\N	1	f
3167	2024-07-23 05:26:00	9743	4	1	f	2	3	t
3168	2024-06-27 00:27:00	1916	2	4	t	2	1	t
3169	2024-08-03 16:41:00	4594	5	3	f	2	2	f
3170	2024-08-31 00:35:00	7363	2	3	t	\N	2	f
3171	2024-09-11 19:27:00	6813	2	1	f	\N	3	f
3172	2024-07-19 03:22:00	3846	5	1	f	\N	4	t
3173	2024-05-09 15:25:00	3885	5	1	t	\N	3	f
3174	2024-07-31 10:34:00	4875	1	4	t	2	4	f
3175	2024-06-27 15:18:00	6210	3	2	t	\N	3	t
3176	2024-06-14 14:36:00	6878	4	3	t	\N	4	f
3177	2024-07-25 11:43:00	1462	1	3	t	\N	2	t
3178	2024-02-26 15:09:00	6761	1	1	t	\N	4	f
3179	2024-04-08 00:25:00	3328	3	4	f	2	4	t
3180	2024-03-23 12:06:00	4084	1	2	f	\N	3	f
3181	2024-02-12 18:09:00	9064	5	4	t	\N	2	f
3182	2024-02-28 14:29:00	9882	3	2	f	\N	1	f
3183	2024-04-11 23:24:00	6063	2	3	f	\N	3	f
3184	2024-07-12 13:19:00	3876	2	3	t	\N	2	t
3185	2024-06-10 07:55:00	9035	3	3	f	\N	1	t
3186	2024-02-21 06:41:00	1621	2	3	t	2	2	f
3187	2024-03-20 01:32:00	2478	3	4	f	2	3	t
3188	2024-07-23 00:48:00	1920	4	3	f	\N	3	t
3189	2024-05-10 17:43:00	4811	4	2	t	\N	4	t
3190	2024-08-01 23:58:00	4584	5	3	t	\N	2	t
3191	2024-07-13 06:17:00	1326	5	4	t	\N	3	t
3192	2024-01-11 05:27:00	9625	1	4	t	1	2	t
3193	2024-08-06 19:31:00	8831	1	2	f	1	4	t
3194	2024-01-03 04:33:00	1011	5	3	t	\N	1	t
3195	2024-07-17 22:05:00	6435	3	3	t	\N	4	f
3196	2024-08-13 04:28:00	4300	4	3	t	\N	4	t
3197	2024-09-03 18:42:00	3137	1	4	t	\N	3	t
3198	2024-06-08 09:01:00	6582	2	2	f	1	3	f
3199	2024-09-14 05:40:00	3907	4	2	f	\N	4	t
3200	2024-05-23 22:42:00	6301	1	1	f	\N	1	t
3201	2024-01-01 02:04:00	1975	5	3	t	2	4	f
3202	2024-08-19 21:54:00	1359	2	1	t	2	3	f
3203	2024-05-04 08:10:00	3420	5	1	t	\N	1	f
3204	2024-04-07 13:21:00	3320	2	1	t	\N	3	f
3205	2024-01-18 14:58:00	2817	3	4	t	1	4	t
3206	2024-07-07 15:54:00	9622	5	1	f	2	3	t
3207	2024-04-08 07:21:00	6978	2	1	t	\N	4	t
3208	2024-01-18 11:04:00	2188	4	2	t	\N	3	f
3209	2024-08-25 06:42:00	7120	3	4	f	2	4	t
3210	2024-06-02 22:02:00	7481	2	3	t	\N	1	f
3211	2024-07-21 21:28:00	2655	2	4	f	\N	4	f
3212	2024-01-05 22:08:00	6514	1	4	t	\N	1	f
3213	2024-08-22 08:10:00	5944	1	4	f	\N	2	t
3214	2024-06-06 19:14:00	6285	3	4	f	1	3	t
3215	2024-03-26 18:58:00	3235	4	4	t	\N	3	t
3216	2024-06-06 02:25:00	3580	1	1	t	\N	1	f
3217	2024-05-13 22:28:00	8157	3	2	t	2	2	f
3218	2024-03-23 18:03:00	8982	1	1	t	\N	4	t
3219	2024-07-08 23:30:00	6198	1	2	t	\N	2	f
3220	2024-06-29 10:02:00	3854	4	4	f	\N	4	f
3221	2024-09-15 19:17:00	6846	4	4	t	\N	1	t
3222	2024-05-21 04:03:00	4657	5	2	f	\N	3	t
3223	2024-05-18 05:03:00	3872	4	4	t	\N	2	f
3224	2024-03-05 00:02:00	7199	5	4	t	2	4	t
3225	2024-04-08 06:40:00	6026	4	3	t	2	1	f
3226	2024-03-11 05:43:00	5825	5	3	t	\N	4	t
3227	2024-06-17 04:39:00	3086	5	3	t	\N	3	f
3228	2024-05-23 05:08:00	3911	4	4	t	1	3	t
3229	2024-01-15 07:05:00	1029	3	3	t	\N	1	t
3230	2024-01-07 10:34:00	7415	4	2	t	\N	1	t
3231	2024-05-23 21:14:00	1530	5	1	t	\N	3	f
3232	2024-06-15 15:30:00	3983	3	2	t	1	1	t
3233	2024-08-18 05:49:00	6213	2	4	f	\N	1	t
3234	2024-06-01 16:56:00	4619	2	4	t	\N	4	t
3235	2024-09-07 02:42:00	2705	4	4	f	\N	3	t
3236	2024-04-23 01:32:00	9129	5	1	t	\N	2	t
3237	2024-06-19 11:49:00	3304	5	1	t	\N	3	t
3238	2024-08-21 16:29:00	6425	3	4	t	2	3	f
3239	2024-04-17 14:26:00	2274	1	2	f	\N	4	f
3240	2024-02-28 03:39:00	4899	5	3	f	\N	4	f
3241	2024-09-12 09:31:00	6682	4	2	f	\N	2	t
3242	2024-08-07 07:35:00	6234	3	3	t	\N	2	f
3243	2024-06-23 12:21:00	3750	3	2	t	\N	4	f
3244	2024-02-07 10:16:00	2453	2	2	f	\N	3	f
3245	2024-06-28 06:02:00	6500	4	2	t	\N	4	t
3246	2024-06-27 14:40:00	8317	1	4	f	\N	3	f
3247	2024-05-01 20:44:00	1186	4	2	t	\N	4	t
3248	2024-07-12 13:22:00	5345	5	1	t	1	2	t
3249	2024-04-24 09:31:00	4435	4	4	f	\N	1	t
3250	2024-05-09 05:51:00	5088	2	2	t	\N	1	t
3251	2024-08-09 17:12:00	2110	1	4	f	\N	2	f
3252	2024-06-25 09:16:00	6742	4	3	f	\N	1	t
3253	2024-02-18 01:50:00	5205	4	2	f	\N	1	f
3254	2024-06-09 09:03:00	2770	2	4	f	1	1	f
3255	2024-01-20 23:09:00	1020	5	2	t	\N	2	f
3256	2024-01-16 12:58:00	1788	3	4	t	1	4	t
3257	2024-07-21 16:57:00	7323	4	3	t	\N	4	f
3258	2024-09-07 02:56:00	8179	4	1	t	\N	1	f
3259	2024-01-15 04:28:00	7875	3	2	t	2	4	f
3260	2024-04-07 22:12:00	3725	5	1	t	\N	1	f
3261	2024-05-27 12:55:00	7783	3	3	t	\N	2	f
3262	2024-08-12 00:04:00	9078	3	4	f	\N	4	t
3263	2024-06-23 22:05:00	7204	3	2	t	\N	1	f
3264	2024-08-31 13:07:00	6754	1	1	f	\N	1	t
3265	2024-06-28 10:19:00	9946	4	4	f	1	2	f
3266	2024-09-10 17:54:00	7149	4	1	f	\N	4	f
3267	2024-02-21 01:46:00	2661	5	2	t	\N	1	t
3268	2024-06-12 08:49:00	8855	1	3	t	2	4	f
3269	2024-08-19 03:55:00	4695	2	4	f	1	4	f
3270	2024-08-14 01:44:00	3664	3	4	t	2	3	f
3271	2024-04-05 23:53:00	8393	1	3	f	2	2	f
3272	2024-02-16 23:34:00	2207	4	3	t	1	4	f
3273	2024-05-03 09:32:00	1547	3	1	t	\N	2	t
3274	2024-06-27 10:54:00	5831	5	4	f	1	1	f
3275	2024-08-29 23:34:00	1328	3	3	t	\N	2	f
3276	2024-01-13 03:19:00	6221	2	3	t	\N	3	t
3277	2024-04-21 11:53:00	5278	4	2	t	\N	2	t
3278	2024-07-22 04:28:00	2715	1	2	f	1	3	f
3279	2024-05-29 09:21:00	2215	3	3	t	\N	4	t
3280	2024-07-08 02:07:00	6600	2	1	t	\N	3	f
3281	2024-04-10 23:49:00	3787	5	1	f	1	1	t
3282	2024-04-30 12:48:00	7151	3	2	f	\N	4	t
3283	2024-02-01 04:08:00	3636	5	2	t	\N	4	f
3284	2024-04-09 01:18:00	2228	1	4	f	\N	2	t
3285	2024-07-16 15:07:00	9962	1	3	f	\N	1	f
3286	2024-08-25 02:06:00	2525	1	4	t	\N	3	f
3287	2024-09-08 17:10:00	6536	4	2	t	\N	3	f
3288	2024-02-23 12:43:00	8909	2	3	f	\N	3	f
3289	2024-04-06 19:18:00	1507	4	1	f	\N	2	f
3290	2024-03-02 18:40:00	8066	2	4	t	\N	3	f
3291	2024-07-10 08:41:00	3703	3	4	t	\N	4	t
3292	2024-08-21 10:55:00	8113	1	4	t	\N	2	t
3293	2024-09-14 05:24:00	3573	2	2	t	\N	3	f
3294	2024-03-01 12:08:00	1877	5	1	t	\N	2	t
3295	2024-07-28 16:05:00	2659	2	4	f	\N	3	f
3296	2024-01-18 17:34:00	6424	2	3	f	2	4	f
3297	2024-09-06 12:21:00	4367	2	4	t	\N	3	f
3298	2024-05-17 11:15:00	4112	2	3	f	\N	3	t
3299	2024-06-05 08:59:00	7705	1	1	t	2	1	t
3300	2024-06-25 12:20:00	9849	1	3	t	\N	2	t
3301	2024-08-14 12:59:00	5346	1	3	t	\N	1	f
3302	2024-06-05 03:27:00	5612	2	1	t	\N	1	t
3303	2024-05-26 12:12:00	5872	5	2	f	\N	2	t
3304	2024-04-01 09:21:00	4891	3	4	f	2	3	f
3305	2024-08-27 00:11:00	2571	1	3	t	\N	4	t
3306	2024-08-01 14:01:00	1813	5	1	f	\N	1	f
3307	2024-03-24 11:07:00	7437	5	1	t	\N	3	f
3308	2024-05-14 14:43:00	9043	4	4	f	\N	4	t
3309	2024-09-15 12:12:00	3516	5	1	f	\N	4	f
3310	2024-03-28 16:27:00	1893	2	3	t	\N	3	f
3311	2024-07-31 23:11:00	6911	2	3	t	\N	2	t
3312	2024-08-30 23:55:00	1062	5	4	f	\N	2	f
3313	2024-04-01 21:27:00	8005	3	1	f	2	2	t
3314	2024-07-23 19:09:00	2435	3	3	t	\N	3	t
3315	2024-07-31 07:15:00	5825	1	4	f	\N	3	f
3316	2024-05-25 16:40:00	8869	3	4	f	\N	2	t
3317	2024-03-19 08:38:00	4271	3	1	f	1	1	t
3318	2024-04-22 15:41:00	2589	4	2	f	\N	3	t
3319	2024-01-25 22:35:00	1421	4	2	t	\N	2	f
3320	2024-09-07 20:18:00	4390	4	4	t	\N	4	f
3321	2024-05-01 20:56:00	3798	5	2	t	1	2	f
3322	2024-04-04 17:57:00	5781	3	4	f	\N	3	t
3323	2024-04-16 22:15:00	2342	3	2	f	\N	1	f
3324	2024-03-27 17:33:00	8758	5	3	t	\N	2	t
3325	2024-02-26 08:55:00	2892	4	4	f	2	1	t
3326	2024-03-18 17:01:00	6052	4	4	t	\N	3	t
3327	2024-06-10 14:24:00	7512	4	3	f	1	3	f
3328	2024-07-05 09:47:00	8715	5	4	f	\N	2	f
3329	2024-08-18 10:34:00	9013	3	3	f	\N	1	f
3330	2024-01-16 11:35:00	5341	3	2	t	\N	1	f
3331	2024-07-12 14:01:00	2493	4	4	f	\N	1	t
3332	2024-08-03 15:22:00	9914	1	3	f	1	3	f
3333	2024-09-13 18:39:00	7349	1	2	f	1	1	f
3334	2024-07-05 10:53:00	4029	2	1	f	\N	4	f
3335	2024-03-03 19:37:00	7078	1	3	f	\N	3	f
3336	2024-03-07 04:14:00	7249	5	3	f	\N	4	t
3337	2024-06-07 17:46:00	7052	5	4	t	\N	2	t
3338	2024-03-25 01:09:00	4056	4	1	t	\N	2	t
3339	2024-01-24 12:47:00	8303	3	4	t	\N	4	f
3340	2024-06-04 09:51:00	1731	3	4	t	\N	2	t
3341	2024-02-10 00:42:00	5313	4	3	f	\N	3	f
3342	2024-08-07 15:09:00	8204	4	1	t	\N	4	f
3343	2024-04-03 20:43:00	8619	4	4	t	\N	4	t
3344	2024-01-20 10:27:00	5315	4	4	f	\N	1	f
3345	2024-03-25 01:26:00	4706	4	4	t	\N	2	t
3346	2024-01-23 20:11:00	5400	3	3	f	\N	3	f
3347	2024-02-16 06:47:00	2009	4	3	t	2	4	f
3348	2024-07-11 00:41:00	3476	4	4	f	\N	3	f
3349	2024-08-26 18:22:00	2584	4	1	t	1	3	t
3350	2024-01-28 13:13:00	2404	4	3	t	\N	3	t
3351	2024-03-24 13:34:00	6632	3	1	t	\N	1	t
3352	2024-04-27 08:23:00	9871	4	4	f	\N	4	f
3353	2024-02-22 21:23:00	7782	4	1	t	\N	3	f
3354	2024-08-11 14:06:00	4727	5	1	f	1	3	t
3355	2024-08-30 13:56:00	1999	1	1	t	\N	1	t
3356	2024-02-28 12:58:00	7342	3	3	f	\N	4	f
3357	2024-06-07 13:56:00	9561	2	3	t	\N	4	f
3358	2024-01-12 04:49:00	7858	5	2	t	\N	2	f
3359	2024-08-22 23:06:00	9773	1	3	t	\N	4	t
3360	2024-01-29 23:55:00	8779	3	2	t	\N	1	t
3361	2024-03-17 01:16:00	4860	2	3	f	\N	4	f
3362	2024-09-07 14:35:00	8803	1	1	t	\N	1	f
3363	2024-08-21 08:21:00	5896	4	1	t	1	1	t
3364	2024-09-11 09:23:00	2293	3	1	f	\N	4	f
3365	2024-07-07 11:51:00	7468	3	4	f	\N	3	f
3366	2024-05-22 02:37:00	1568	3	4	f	\N	2	t
3367	2024-02-23 02:38:00	9226	2	1	f	\N	1	t
3368	2024-07-07 16:32:00	9467	5	4	t	\N	3	t
3369	2024-05-14 07:43:00	3415	4	4	t	\N	3	f
3370	2024-07-25 09:44:00	2970	3	1	t	1	2	t
3371	2024-09-02 19:38:00	8357	5	2	f	\N	3	t
3372	2024-06-23 04:50:00	3832	3	3	f	\N	2	t
3373	2024-04-08 02:52:00	3738	1	3	t	\N	2	t
3374	2024-08-15 11:40:00	4471	1	2	f	\N	3	f
3375	2024-03-14 19:22:00	4157	1	1	f	\N	3	t
3376	2024-03-18 12:39:00	3067	1	1	f	2	1	f
3377	2024-04-17 07:05:00	1699	4	4	t	\N	3	f
3378	2024-02-29 18:44:00	7936	1	2	t	\N	2	f
3379	2024-04-14 16:18:00	2283	2	3	f	\N	2	f
3380	2024-03-28 14:21:00	8133	1	1	t	\N	4	t
3381	2024-05-03 16:42:00	4308	1	3	t	\N	1	f
3382	2024-04-10 16:51:00	3422	1	2	t	2	2	t
3383	2024-01-12 01:37:00	5225	4	4	f	\N	1	f
3384	2024-05-11 17:35:00	6238	2	3	f	1	3	f
3385	2024-01-18 19:49:00	2097	4	2	f	\N	2	t
3386	2024-08-17 18:56:00	2425	3	1	t	1	2	f
3387	2024-05-16 00:33:00	7358	3	2	t	\N	4	t
3388	2024-06-19 19:08:00	7510	3	1	f	\N	1	f
3389	2024-04-07 05:57:00	6343	2	2	f	\N	2	f
3390	2024-04-28 15:48:00	5525	2	2	t	2	4	f
3391	2024-04-22 05:25:00	9514	5	1	f	1	4	t
3392	2024-07-23 10:26:00	8506	4	3	t	\N	3	f
3393	2024-04-25 11:18:00	1202	5	2	t	\N	4	t
3394	2024-07-29 17:40:00	9561	1	1	t	1	1	f
3395	2024-03-28 11:44:00	7874	3	1	f	2	2	t
3396	2024-02-09 10:36:00	2843	5	1	t	\N	4	f
3397	2024-06-30 12:14:00	7790	4	4	t	\N	3	t
3398	2024-04-29 00:54:00	3451	1	3	t	\N	2	f
3399	2024-01-10 12:56:00	3428	2	2	f	\N	4	t
3400	2024-07-26 09:12:00	2641	1	4	f	\N	3	t
3401	2024-06-12 09:00:00	2730	1	3	t	2	3	t
3402	2024-01-04 23:55:00	2654	4	1	t	1	4	f
3403	2024-01-17 08:01:00	5687	2	2	f	\N	1	f
3404	2024-01-13 08:12:00	9775	1	4	t	\N	1	t
3405	2024-06-06 04:29:00	6633	4	1	f	\N	1	t
3406	2024-03-09 11:01:00	7732	3	1	f	\N	2	t
3407	2024-08-17 01:31:00	5327	5	2	f	2	4	f
3408	2024-05-21 08:37:00	7275	5	4	f	\N	2	t
3409	2024-08-27 20:05:00	8955	4	4	f	1	1	t
3410	2024-03-21 04:15:00	8750	4	3	t	1	1	t
3411	2024-02-25 13:54:00	1613	2	3	f	1	1	t
3412	2024-07-31 15:43:00	3821	3	4	t	\N	1	t
3413	2024-02-11 08:19:00	5512	4	1	t	\N	1	f
3414	2024-04-01 20:47:00	7602	4	3	t	\N	3	t
3415	2024-05-19 23:26:00	3356	2	2	t	\N	1	t
3416	2024-09-14 22:31:00	7581	1	1	t	\N	3	t
3417	2024-08-13 16:17:00	1635	5	4	t	1	2	t
3418	2024-06-25 14:25:00	7484	2	2	f	2	1	t
3419	2024-05-19 02:21:00	6431	2	3	f	2	1	f
3420	2024-08-13 13:28:00	4892	5	4	t	2	4	f
3421	2024-06-28 09:36:00	1807	3	2	t	\N	3	t
3422	2024-01-27 03:19:00	8785	2	1	t	\N	3	t
3423	2024-06-02 23:30:00	5400	5	2	f	2	3	t
3424	2024-05-13 13:38:00	7102	2	2	f	2	1	t
3425	2024-03-03 01:51:00	1331	5	3	t	\N	2	t
3426	2024-04-09 01:29:00	6535	1	2	f	2	4	t
3427	2024-08-28 08:20:00	5965	2	4	t	\N	2	t
3428	2024-03-22 09:03:00	6094	1	3	f	2	4	t
3429	2024-01-17 18:15:00	5593	2	3	f	2	3	t
3430	2024-08-08 21:27:00	9054	2	2	t	\N	1	t
3431	2024-04-21 16:43:00	2609	5	2	f	\N	1	t
3432	2024-07-20 17:11:00	4734	5	1	t	\N	3	f
3433	2024-06-20 07:59:00	3201	5	3	f	2	3	f
3434	2024-06-12 02:57:00	5923	5	2	f	\N	3	f
3435	2024-02-22 03:21:00	8259	1	3	t	\N	2	t
3436	2024-01-14 03:41:00	6257	3	1	t	\N	1	t
3437	2024-04-08 17:04:00	5414	5	2	f	1	1	f
3438	2024-03-21 09:18:00	7828	4	1	t	2	4	f
3439	2024-02-24 06:45:00	2462	3	2	f	\N	1	f
3440	2024-01-21 11:47:00	4079	3	3	t	\N	4	f
3441	2024-03-16 16:08:00	8237	1	1	f	\N	1	t
3442	2024-06-27 04:55:00	4463	1	3	f	\N	4	f
3443	2024-06-15 04:38:00	7671	3	4	t	\N	4	f
3444	2024-03-18 09:08:00	8937	3	1	f	2	1	f
3445	2024-04-02 06:27:00	9462	1	4	f	\N	1	t
3446	2024-04-01 00:01:00	7126	4	1	f	\N	2	f
3447	2024-08-25 18:58:00	1920	3	3	f	2	4	t
3448	2024-03-13 20:19:00	9442	3	3	f	\N	2	t
3449	2024-02-23 10:36:00	3604	2	4	t	\N	2	f
3450	2024-08-25 02:11:00	2075	3	4	t	\N	3	t
3451	2024-01-14 05:15:00	6097	3	2	f	\N	1	f
3452	2024-01-25 07:37:00	9303	2	2	f	\N	1	f
3453	2024-09-16 03:30:00	7609	1	1	t	\N	1	t
3454	2024-02-11 09:03:00	3222	4	3	t	\N	4	t
3455	2024-01-30 13:18:00	9589	5	3	f	1	4	f
3456	2024-09-06 08:51:00	1474	3	1	f	\N	3	t
3457	2024-01-21 20:53:00	3846	5	3	f	\N	1	f
3458	2024-08-18 07:45:00	4158	3	1	t	\N	3	f
3459	2024-05-20 11:44:00	4288	2	4	f	\N	3	t
3460	2024-03-27 11:57:00	1944	4	1	f	\N	1	t
3461	2024-07-19 13:15:00	5087	1	1	f	\N	4	f
3462	2024-02-26 01:01:00	1541	4	2	t	\N	4	f
3463	2024-09-01 23:24:00	8478	3	2	f	\N	1	t
3464	2024-01-14 21:06:00	1828	3	3	t	\N	3	f
3465	2024-08-26 14:22:00	6904	4	1	f	\N	3	f
3466	2024-06-20 20:05:00	4262	1	3	t	1	2	t
3467	2024-03-05 12:41:00	5488	2	4	t	\N	4	f
3468	2024-05-04 17:24:00	7035	3	2	t	\N	1	t
3469	2024-09-04 13:06:00	8605	5	3	f	\N	2	t
3470	2024-03-09 00:29:00	9275	4	3	f	2	4	t
3471	2024-07-10 10:43:00	7503	1	4	t	2	1	t
3472	2024-08-20 20:54:00	3029	1	4	t	\N	1	t
3473	2024-09-06 15:31:00	1500	2	3	f	\N	3	f
3474	2024-06-22 20:47:00	4963	1	3	f	\N	4	t
3475	2024-08-23 23:28:00	7102	4	3	t	\N	3	t
3476	2024-04-07 13:53:00	9008	5	3	f	\N	3	t
3477	2024-03-04 10:48:00	8308	2	4	f	\N	4	t
3478	2024-05-28 10:24:00	3909	3	4	f	\N	1	f
3479	2024-01-16 19:30:00	8775	3	2	t	\N	2	f
3480	2024-01-27 10:27:00	6730	4	1	t	\N	4	t
3481	2024-03-26 01:03:00	6640	4	4	t	1	4	t
3482	2024-01-22 17:00:00	3679	1	2	t	\N	1	t
3483	2024-06-06 17:20:00	5237	4	3	t	2	1	f
3484	2024-06-05 11:22:00	2480	2	4	f	\N	1	t
3485	2024-07-03 16:07:00	5670	2	4	t	1	3	f
3486	2024-09-14 11:59:00	1449	1	2	f	\N	2	f
3487	2024-05-15 11:42:00	7333	1	4	f	\N	1	t
3488	2024-02-26 14:26:00	1813	3	1	f	\N	4	t
3489	2024-03-02 02:35:00	3669	1	2	t	\N	2	t
3490	2024-08-27 02:37:00	4511	4	1	f	1	3	f
3491	2024-05-24 16:07:00	4626	3	4	f	2	4	t
3492	2024-02-07 18:56:00	4688	5	4	f	2	3	f
3493	2024-08-08 13:33:00	4387	4	1	t	\N	3	t
3494	2024-06-17 04:03:00	5408	1	4	t	2	3	f
3495	2024-08-22 21:21:00	7709	2	3	f	\N	2	f
3496	2024-06-08 14:35:00	9409	3	2	f	\N	2	f
3497	2024-02-24 18:59:00	1328	4	2	t	2	1	f
3498	2024-06-10 04:30:00	1145	5	4	f	1	1	t
3499	2024-04-13 18:12:00	8767	5	3	f	\N	1	f
3500	2024-05-06 01:19:00	3167	1	1	f	\N	2	f
3501	2024-01-11 05:26:00	3837	1	4	f	\N	1	t
3502	2024-03-10 00:13:00	1138	1	2	f	2	3	t
3503	2024-06-16 07:43:00	4666	5	2	t	1	4	f
3504	2024-06-08 14:28:00	5135	4	3	t	2	3	t
3505	2024-07-06 09:49:00	6004	2	3	f	\N	1	t
3506	2024-07-27 03:27:00	5511	3	1	f	\N	3	t
3507	2024-08-09 19:59:00	7943	4	3	f	2	2	f
3508	2024-01-10 00:03:00	7168	1	3	f	\N	1	f
3509	2024-02-16 18:19:00	6713	3	3	t	\N	4	t
3510	2024-07-01 21:11:00	8520	4	1	f	1	4	t
3511	2024-08-19 15:34:00	5128	4	1	f	\N	4	f
3512	2024-08-27 18:00:00	4575	2	2	f	\N	2	f
3513	2024-01-18 02:56:00	8646	1	1	t	2	2	t
3514	2024-09-08 08:48:00	5950	2	1	f	\N	1	f
3515	2024-02-08 22:17:00	9530	4	1	t	2	4	t
3516	2024-02-21 07:40:00	7506	1	1	t	\N	1	t
3517	2024-03-08 20:28:00	2676	3	1	t	\N	4	f
3518	2024-01-06 20:08:00	1120	2	2	f	\N	3	t
3519	2024-01-31 02:54:00	9380	4	4	t	\N	2	f
3520	2024-01-18 07:05:00	7131	1	2	t	\N	4	f
3521	2024-04-27 14:26:00	5631	3	1	t	\N	1	t
3522	2024-04-24 06:21:00	5890	5	1	f	2	3	f
3523	2024-06-27 09:58:00	2771	4	1	f	\N	2	f
3524	2024-05-28 01:53:00	8892	1	1	t	\N	4	f
3525	2024-01-27 07:37:00	2045	4	4	t	\N	4	t
3526	2024-01-11 07:56:00	6509	2	2	t	\N	4	f
3527	2024-08-01 12:26:00	5529	4	3	f	2	1	t
3528	2024-01-03 02:24:00	6327	4	2	t	\N	2	t
3529	2024-04-23 03:35:00	5536	1	3	f	\N	2	f
3530	2024-08-21 18:48:00	5278	1	1	t	\N	3	t
3531	2024-08-21 01:41:00	5895	5	2	t	\N	2	f
3532	2024-08-02 00:59:00	4086	5	1	t	2	3	f
3533	2024-01-21 12:38:00	3456	5	4	t	\N	4	t
3534	2024-03-13 00:48:00	9475	2	1	t	\N	2	t
3535	2024-08-18 01:37:00	4937	4	4	f	2	4	t
3536	2024-03-14 15:29:00	1930	5	4	f	\N	1	f
3537	2024-07-28 19:37:00	7620	1	1	f	\N	3	f
3538	2024-03-18 01:30:00	6236	5	4	t	\N	2	t
3539	2024-01-11 16:53:00	3292	1	2	t	2	4	t
3540	2024-01-13 00:31:00	1417	3	4	f	1	3	t
3541	2024-09-12 14:34:00	9148	2	1	f	\N	2	f
3542	2024-01-22 18:45:00	5843	5	2	t	\N	1	f
3543	2024-08-07 07:49:00	5250	2	3	t	\N	2	t
3544	2024-07-08 10:50:00	7857	1	3	f	\N	2	f
3545	2024-02-12 21:42:00	7628	4	1	f	\N	3	f
3546	2024-01-27 09:15:00	7361	2	3	f	\N	4	t
3547	2024-03-05 09:46:00	1578	5	2	f	1	1	f
3548	2024-02-12 10:38:00	4111	2	1	t	1	3	f
3549	2024-07-17 18:17:00	6622	5	2	f	\N	1	t
3550	2024-03-11 23:56:00	4643	3	3	f	\N	3	f
3551	2024-04-27 06:25:00	9759	5	3	t	2	4	t
3552	2024-02-17 00:21:00	8794	1	4	t	\N	3	f
3553	2024-03-19 14:53:00	6873	5	3	t	\N	4	f
3554	2024-06-26 04:12:00	9311	3	2	t	\N	4	f
3555	2024-07-21 10:26:00	5918	3	4	f	2	4	f
3556	2024-06-15 09:31:00	3785	4	3	t	\N	1	f
3557	2024-02-28 17:59:00	3967	2	2	f	\N	4	t
3558	2024-01-18 00:54:00	5813	3	2	f	1	2	f
3559	2024-09-01 04:49:00	2599	3	3	t	2	3	t
3560	2024-06-09 17:07:00	8713	4	4	f	\N	3	f
3561	2024-03-20 08:26:00	3096	2	4	f	\N	2	t
3562	2024-07-09 21:57:00	5237	2	2	t	\N	3	t
3563	2024-05-23 11:59:00	3999	5	1	t	1	3	f
3564	2024-04-24 19:25:00	6499	5	3	f	\N	4	t
3565	2024-06-27 13:23:00	2463	4	2	t	\N	3	t
3566	2024-09-12 13:43:00	4641	3	1	f	\N	1	f
3567	2024-06-25 02:29:00	6820	4	3	f	1	4	f
3568	2024-04-12 11:46:00	4659	4	3	f	1	1	f
3569	2024-04-19 20:14:00	6031	2	2	f	\N	1	f
3570	2024-09-10 07:25:00	7889	2	2	t	2	4	t
3571	2024-05-16 18:41:00	6428	1	2	f	\N	2	f
3572	2024-06-25 00:49:00	7089	2	2	t	2	4	t
3573	2024-09-16 12:16:00	5269	3	2	f	1	4	f
3574	2024-08-09 23:16:00	5817	5	1	t	\N	3	t
3575	2024-04-21 19:05:00	8598	1	2	t	\N	2	f
3576	2024-04-25 17:41:00	2929	2	1	f	\N	1	t
3577	2024-08-13 17:19:00	8709	3	1	t	\N	4	t
3578	2024-08-03 11:10:00	1879	2	2	f	2	4	f
3579	2024-08-12 05:51:00	2166	2	4	f	\N	2	t
3580	2024-04-07 05:32:00	8736	4	2	t	\N	3	t
3581	2024-07-01 09:45:00	4187	2	2	f	\N	1	t
3582	2024-07-29 19:54:00	9199	3	4	t	1	3	f
3583	2024-05-25 20:35:00	2963	2	4	f	\N	4	t
3584	2024-03-17 09:40:00	7253	1	2	f	1	3	t
3585	2024-07-09 08:14:00	9680	5	2	t	\N	1	f
3586	2024-03-04 02:25:00	5888	3	3	f	\N	4	f
3587	2024-03-18 18:32:00	7768	5	4	f	\N	1	f
3588	2024-05-15 08:25:00	1885	2	1	f	\N	3	f
3589	2024-07-18 18:56:00	3470	5	1	f	1	4	t
3590	2024-07-06 03:30:00	3250	4	3	f	\N	1	t
3591	2024-09-16 17:55:00	4281	3	2	f	1	4	t
3592	2024-05-06 05:01:00	6614	3	4	t	1	1	f
3593	2024-09-10 11:01:00	7704	1	1	t	\N	4	f
3594	2024-08-16 07:31:00	8496	1	3	f	\N	1	t
3595	2024-03-07 05:51:00	3346	3	4	f	\N	2	t
3596	2024-01-21 16:45:00	6183	5	3	t	\N	2	t
3597	2024-01-07 15:31:00	3954	3	4	f	\N	1	t
3598	2024-07-22 17:43:00	2324	2	2	f	1	1	t
3599	2024-05-13 03:38:00	8988	5	4	f	\N	3	t
3600	2024-03-27 15:19:00	6449	2	2	f	\N	3	f
3601	2024-08-01 00:15:00	3897	3	2	f	\N	1	t
3602	2024-03-28 14:06:00	6134	1	3	f	2	1	t
3603	2024-03-17 08:08:00	1950	3	3	f	1	3	t
3604	2024-08-29 20:23:00	1077	2	2	f	\N	4	t
3605	2024-04-29 23:30:00	8406	3	1	t	\N	1	t
3606	2024-07-28 23:53:00	5481	5	3	f	\N	3	t
3607	2024-05-16 13:37:00	4430	4	3	t	\N	2	t
3608	2024-03-26 08:54:00	3762	3	3	t	\N	1	t
3609	2024-09-07 20:34:00	3595	3	4	f	2	4	t
3610	2024-03-16 09:03:00	9021	5	1	t	\N	3	t
3611	2024-08-20 16:55:00	2442	1	3	t	\N	4	t
3612	2024-03-30 15:15:00	3120	2	2	f	\N	1	f
3613	2024-09-16 10:30:00	8105	2	3	f	\N	3	f
3614	2024-06-29 13:53:00	8035	2	4	f	\N	3	t
3615	2024-03-17 21:11:00	7609	1	2	f	2	3	f
3616	2024-02-28 12:03:00	8029	5	3	t	\N	1	f
3617	2024-04-22 09:51:00	8821	1	4	f	\N	2	t
3618	2024-04-21 11:18:00	7280	1	1	t	2	4	f
3619	2024-02-23 20:41:00	1076	1	4	t	\N	1	f
3620	2024-07-09 05:07:00	1618	4	1	f	1	3	t
3621	2024-04-02 01:37:00	9745	5	1	t	\N	4	f
3622	2024-07-21 01:17:00	4267	2	4	t	\N	1	f
3623	2024-07-13 20:41:00	7112	3	4	f	\N	4	f
3624	2024-06-20 19:13:00	1230	3	1	f	\N	2	f
3625	2024-01-02 18:30:00	6279	5	1	t	\N	4	t
3626	2024-03-17 12:32:00	9700	3	4	t	2	1	t
3627	2024-06-10 06:41:00	4122	2	4	t	1	3	f
3628	2024-04-30 06:34:00	1293	5	3	f	2	2	t
3629	2024-05-13 20:30:00	1067	5	3	t	\N	4	f
3630	2024-08-07 23:06:00	5076	1	1	t	\N	3	t
3631	2024-08-27 11:14:00	4707	5	4	f	\N	3	t
3632	2024-05-31 13:15:00	6641	4	3	f	\N	3	t
3633	2024-02-18 17:49:00	6113	4	1	t	\N	2	t
3634	2024-07-24 01:25:00	3112	5	1	t	\N	3	f
3635	2024-06-04 22:29:00	2682	1	2	t	2	2	t
3636	2024-07-23 04:26:00	7284	2	2	f	1	4	t
3637	2024-08-31 11:30:00	9246	2	3	t	\N	4	t
3638	2024-03-05 11:01:00	6015	3	4	f	\N	4	t
3639	2024-09-05 19:45:00	3736	2	3	f	\N	3	t
3640	2024-05-28 08:49:00	2069	2	1	t	\N	1	t
3641	2024-03-30 02:55:00	1749	4	3	f	\N	2	f
3642	2024-05-30 17:35:00	5885	4	1	f	2	1	f
3643	2024-07-14 10:54:00	5764	2	4	t	2	1	f
3644	2024-09-15 10:31:00	8469	4	4	t	\N	2	f
3645	2024-02-02 05:15:00	9524	4	1	t	2	3	f
3646	2024-05-12 15:56:00	9587	3	3	t	\N	2	f
3647	2024-08-23 05:08:00	6535	3	2	t	\N	2	t
3648	2024-07-15 08:31:00	8105	3	1	f	\N	4	f
3649	2024-04-18 01:13:00	3192	4	1	t	\N	3	t
3650	2024-05-03 16:56:00	6615	4	3	t	\N	4	t
3651	2024-06-02 11:10:00	9031	5	3	f	\N	1	t
3652	2024-06-07 23:42:00	6885	4	2	f	2	2	t
3653	2024-03-19 05:14:00	4087	2	3	t	1	3	f
3654	2024-01-25 21:01:00	3701	4	1	f	\N	3	t
3655	2024-02-27 02:27:00	7609	3	2	f	1	1	t
3656	2024-03-30 00:19:00	1313	4	4	t	2	4	f
3657	2024-02-09 07:35:00	4742	2	1	t	\N	4	f
3658	2024-03-22 00:52:00	4675	3	2	t	\N	1	f
3659	2024-09-15 12:35:00	3149	3	3	f	2	3	t
3660	2024-08-25 15:34:00	4460	3	4	t	2	2	t
3661	2024-03-25 06:18:00	1359	1	2	f	\N	1	f
3662	2024-09-15 21:45:00	9267	5	2	t	2	1	t
3663	2024-02-23 21:17:00	3768	3	1	f	\N	3	t
3664	2024-02-14 11:36:00	3017	4	1	f	\N	4	f
3665	2024-03-24 10:35:00	7006	5	1	t	\N	3	f
3666	2024-07-14 10:22:00	1612	2	4	t	\N	1	t
3667	2024-03-30 07:51:00	7147	4	4	f	\N	2	f
3668	2024-03-10 08:26:00	5190	4	3	f	\N	3	f
3669	2024-01-26 20:39:00	9761	4	3	t	1	1	f
3670	2024-02-29 20:29:00	1796	5	1	t	1	2	f
3671	2024-02-05 02:59:00	1785	3	2	f	\N	3	t
3672	2024-05-08 10:15:00	2771	2	2	t	\N	1	f
3673	2024-09-08 08:27:00	1323	1	1	t	\N	1	t
3674	2024-04-07 03:58:00	1790	2	4	t	\N	4	f
3675	2024-05-17 12:34:00	2897	1	4	f	1	1	f
3676	2024-03-24 09:28:00	7828	2	4	f	\N	3	f
3677	2024-08-24 06:09:00	8279	1	1	t	1	4	f
3678	2024-03-04 04:00:00	7230	3	2	f	\N	2	t
3679	2024-06-11 18:07:00	3024	2	2	f	\N	1	t
3680	2024-03-20 23:40:00	9966	4	3	f	\N	1	t
3681	2024-08-19 11:37:00	5140	5	4	f	\N	3	t
3682	2024-03-08 16:59:00	8772	2	4	f	2	3	f
3683	2024-01-16 00:48:00	3508	5	2	t	2	1	f
3684	2024-08-19 02:19:00	4366	3	4	f	\N	1	t
3685	2024-03-13 12:34:00	1152	5	3	f	\N	3	f
3686	2024-02-28 13:53:00	5933	5	4	t	\N	3	f
3687	2024-05-06 00:34:00	7895	2	1	f	\N	3	t
3688	2024-08-27 00:30:00	2654	3	4	f	\N	3	t
3689	2024-08-26 17:45:00	9524	2	1	f	\N	2	f
3690	2024-01-01 20:40:00	5423	2	3	f	\N	2	t
3691	2024-05-06 09:16:00	3247	1	1	t	\N	3	t
3692	2024-08-17 04:09:00	7862	5	1	f	\N	2	f
3693	2024-04-27 03:15:00	2718	4	4	f	\N	4	f
3694	2024-01-03 09:16:00	9381	2	1	t	2	3	t
3695	2024-09-07 13:09:00	2928	4	3	t	\N	2	t
3696	2024-02-23 19:10:00	5631	1	1	f	\N	4	f
3697	2024-05-07 06:33:00	2867	1	2	t	\N	1	t
3698	2024-09-09 07:52:00	2741	1	3	t	\N	4	f
3699	2024-07-06 11:02:00	9154	3	1	f	\N	3	f
3700	2024-07-17 08:57:00	4254	1	1	f	1	3	t
3701	2024-09-07 03:04:00	4272	2	4	f	\N	3	f
3702	2024-04-23 15:12:00	5308	3	4	t	\N	2	f
3703	2024-03-31 11:40:00	9571	4	1	f	\N	3	f
3704	2024-04-20 23:25:00	4304	4	1	t	\N	3	f
3705	2024-07-16 05:44:00	6864	2	3	f	\N	4	t
3706	2024-08-25 13:09:00	7713	2	1	f	1	4	t
3707	2024-08-05 08:23:00	5839	1	4	f	1	3	f
3708	2024-02-24 04:41:00	3627	5	4	t	\N	4	t
3709	2024-07-05 04:36:00	1645	2	4	f	\N	1	f
3710	2024-06-29 01:45:00	9980	1	1	t	\N	2	f
3711	2024-02-21 20:40:00	9132	1	2	f	\N	1	t
3712	2024-01-25 20:21:00	4402	5	3	f	\N	4	t
3713	2024-08-07 10:22:00	8875	2	4	f	\N	4	f
3714	2024-08-06 10:47:00	6416	4	1	t	1	3	f
3715	2024-06-25 13:56:00	4842	5	1	f	\N	1	f
3716	2024-08-30 22:58:00	1044	1	2	f	2	4	t
3717	2024-07-05 02:26:00	1208	5	4	t	\N	2	t
3718	2024-05-12 22:10:00	2458	2	2	t	\N	4	f
3719	2024-02-19 08:51:00	2809	4	4	f	\N	4	f
3720	2024-01-15 03:58:00	9095	3	3	t	1	1	t
3721	2024-05-27 01:37:00	3443	1	4	t	\N	1	t
3722	2024-05-29 11:24:00	2475	2	3	t	\N	3	t
3723	2024-02-06 18:36:00	9383	1	4	t	2	4	f
3724	2024-07-02 02:18:00	2229	3	2	f	\N	3	t
3725	2024-08-16 16:07:00	2659	3	2	t	2	4	f
3726	2024-03-06 01:47:00	5192	4	3	f	\N	1	t
3727	2024-05-04 18:50:00	4787	5	1	t	2	2	f
3728	2024-07-24 10:36:00	8483	3	4	f	\N	3	t
3729	2024-02-08 22:29:00	5850	2	3	f	2	4	f
3730	2024-04-12 00:51:00	5327	5	4	f	1	3	t
3731	2024-03-02 18:27:00	8606	5	4	t	\N	2	t
3732	2024-07-01 18:48:00	1820	4	2	t	2	4	f
3733	2024-02-24 19:47:00	2635	2	1	f	\N	1	f
3734	2024-04-15 10:16:00	3862	2	2	t	2	3	f
3735	2024-08-14 17:58:00	1646	5	2	t	\N	1	t
3736	2024-03-21 10:37:00	5760	4	3	f	\N	2	t
3737	2024-04-28 03:21:00	6901	3	2	f	2	2	f
3738	2024-01-20 14:44:00	6123	1	1	f	\N	4	t
3739	2024-08-01 02:41:00	7979	5	1	f	\N	3	t
3740	2024-03-01 09:19:00	2898	5	4	t	\N	2	t
3741	2024-04-17 14:13:00	2556	5	3	t	\N	2	t
3742	2024-08-25 14:17:00	1751	3	4	f	\N	4	t
3743	2024-09-07 07:21:00	1158	3	1	t	1	2	t
3744	2024-07-24 15:15:00	3267	2	4	t	\N	1	f
3745	2024-05-26 05:10:00	3793	4	1	f	\N	2	f
3746	2024-04-14 03:37:00	6384	3	2	f	2	1	t
3747	2024-08-12 13:07:00	6857	2	3	t	2	1	t
3748	2024-08-12 06:24:00	8171	4	4	t	\N	4	t
3749	2024-01-29 09:06:00	5395	3	3	t	\N	3	f
3750	2024-08-27 16:29:00	2522	3	1	f	2	3	t
3751	2024-06-28 13:49:00	7105	3	1	f	\N	4	f
3752	2024-05-26 20:36:00	6615	2	4	f	\N	3	f
3753	2024-04-14 09:56:00	3996	2	1	t	1	2	f
3754	2024-04-04 19:02:00	2865	1	3	f	\N	3	t
3755	2024-01-29 17:44:00	7566	4	3	f	1	3	f
3756	2024-02-05 19:06:00	7557	1	1	t	\N	1	t
3757	2024-07-27 05:40:00	8479	5	2	f	2	2	t
3758	2024-07-01 04:56:00	5453	3	3	f	1	3	f
3759	2024-04-21 19:20:00	7319	2	2	f	\N	3	f
3760	2024-08-27 16:03:00	8835	2	4	f	\N	1	f
3761	2024-04-30 07:07:00	7909	5	3	f	\N	4	t
3762	2024-05-22 00:48:00	3732	5	4	t	1	2	f
3763	2024-03-11 23:19:00	2852	4	4	t	\N	1	t
3764	2024-07-03 00:09:00	3171	2	2	t	\N	1	t
3765	2024-02-18 11:39:00	1960	2	1	f	\N	1	t
3766	2024-04-14 01:51:00	3611	4	1	f	\N	1	t
3767	2024-06-02 18:34:00	2699	4	1	f	\N	1	t
3768	2024-01-23 13:47:00	7816	1	1	t	2	1	t
3769	2024-07-01 17:01:00	8908	2	4	f	\N	2	f
3770	2024-08-16 13:38:00	8178	3	4	t	\N	3	t
3771	2024-04-20 02:29:00	3969	2	4	f	\N	1	f
3772	2024-08-26 04:25:00	7221	4	1	t	\N	3	f
3773	2024-01-02 11:11:00	6875	1	2	t	2	3	f
3774	2024-02-07 19:03:00	1472	5	4	f	\N	4	f
3775	2024-01-23 01:27:00	3140	1	1	t	\N	2	f
3776	2024-08-06 07:02:00	8914	4	2	f	1	4	t
3777	2024-06-06 12:41:00	8997	1	4	f	\N	3	t
3778	2024-04-13 12:33:00	2850	3	1	t	\N	3	t
3779	2024-04-24 23:04:00	7738	4	3	f	\N	1	f
3780	2024-07-26 21:17:00	8220	5	3	f	\N	2	t
3781	2024-08-23 17:01:00	1753	5	1	f	2	1	t
3782	2024-05-08 22:43:00	2037	1	3	f	\N	4	t
3783	2024-05-06 19:37:00	5286	2	4	t	\N	1	f
3784	2024-08-08 12:39:00	6148	2	1	t	\N	2	t
3785	2024-03-30 11:08:00	1202	1	1	t	1	2	f
3786	2024-08-23 10:56:00	9598	3	2	f	1	3	t
3787	2024-06-21 22:32:00	4669	2	2	t	\N	1	t
3788	2024-08-27 19:11:00	6542	5	3	t	2	1	f
3789	2024-01-06 08:15:00	9504	5	1	f	\N	3	f
3790	2024-06-12 04:21:00	9570	5	1	t	1	3	f
3791	2024-06-01 14:15:00	2560	1	1	f	\N	4	f
3792	2024-08-22 05:06:00	8091	5	2	f	\N	1	f
3793	2024-03-04 01:37:00	5072	5	2	t	2	2	f
3794	2024-02-26 09:49:00	8895	4	3	f	\N	4	f
3795	2024-02-03 23:00:00	6664	2	3	f	\N	4	f
3796	2024-03-06 07:17:00	7305	2	2	f	2	3	t
3797	2024-06-23 07:43:00	3435	3	2	t	\N	4	t
3798	2024-05-20 17:12:00	1894	1	1	f	\N	1	t
3799	2024-03-02 05:04:00	1190	4	4	t	\N	4	f
3800	2024-03-20 10:08:00	3571	4	3	f	\N	2	f
3801	2024-08-23 20:46:00	9283	4	2	f	1	1	f
3802	2024-07-06 03:05:00	8688	3	2	t	\N	4	f
3803	2024-03-14 02:22:00	9123	3	1	f	\N	2	t
3804	2024-06-16 02:42:00	3709	4	4	t	\N	1	f
3805	2024-07-05 22:31:00	2226	3	3	f	\N	4	t
3806	2024-04-20 15:29:00	9055	1	1	t	\N	4	f
3807	2024-04-19 01:58:00	6253	4	1	t	\N	3	f
3808	2024-09-06 11:20:00	4946	5	3	t	\N	4	f
3809	2024-02-19 15:53:00	6421	4	4	f	\N	3	f
3810	2024-04-08 16:31:00	5557	2	1	f	1	3	f
3811	2024-03-26 23:09:00	1824	1	2	f	\N	1	f
3812	2024-07-17 09:19:00	9305	3	4	f	\N	3	f
3813	2024-07-11 07:05:00	4648	4	4	t	1	2	f
3814	2024-01-06 00:42:00	7203	5	3	t	2	3	f
3815	2024-02-09 11:08:00	7607	2	2	t	1	4	t
3816	2024-06-12 05:38:00	4850	3	4	f	2	1	t
3817	2024-04-15 00:02:00	2291	3	2	t	\N	3	f
3818	2024-09-13 20:30:00	8521	4	1	t	1	4	t
3819	2024-07-29 10:01:00	8277	2	4	t	\N	4	t
3820	2024-02-06 10:43:00	8341	2	2	f	1	3	f
3821	2024-03-28 21:04:00	2442	2	4	t	\N	4	f
3822	2024-01-16 19:52:00	9166	3	2	f	\N	1	f
3823	2024-08-06 12:50:00	8324	4	3	f	\N	2	f
3824	2024-05-11 09:46:00	6178	3	1	f	\N	2	f
3825	2024-06-30 14:25:00	2944	4	4	t	\N	3	t
3826	2024-06-09 01:03:00	9148	1	2	f	\N	3	f
3827	2024-03-08 20:43:00	1291	3	4	f	2	2	f
3828	2024-02-20 23:53:00	2681	5	1	f	\N	1	f
3829	2024-05-22 03:49:00	7609	3	2	f	\N	3	f
3830	2024-07-21 11:04:00	7755	3	1	f	\N	2	f
3831	2024-06-10 19:13:00	1587	4	1	t	2	2	t
3832	2024-06-02 07:55:00	9996	2	3	t	\N	1	f
3833	2024-01-03 23:08:00	1002	3	2	t	\N	1	t
3834	2024-05-12 02:07:00	2489	5	3	t	\N	1	f
3835	2024-03-27 23:28:00	5990	4	1	f	\N	4	t
3836	2024-05-16 00:23:00	9328	3	3	t	\N	2	t
3837	2024-05-31 22:28:00	4389	4	2	f	\N	1	t
3838	2024-07-25 18:22:00	8474	2	3	f	\N	4	t
3839	2024-04-26 18:50:00	6584	3	2	t	\N	2	t
3840	2024-06-19 07:45:00	6953	5	1	f	1	3	t
3841	2024-09-10 00:28:00	1889	1	1	f	\N	1	t
3842	2024-04-18 11:38:00	4652	3	2	t	2	4	f
3843	2024-07-23 22:44:00	8445	5	1	f	\N	4	t
3844	2024-01-10 01:40:00	6439	4	2	t	\N	3	f
3845	2024-02-25 11:48:00	8751	4	2	t	\N	3	t
3846	2024-08-21 17:21:00	6952	1	1	t	2	4	f
3847	2024-05-10 06:33:00	8414	4	3	f	2	2	f
3848	2024-01-28 20:26:00	2868	3	3	t	\N	1	f
3849	2024-09-10 01:13:00	2596	1	3	f	\N	1	t
3850	2024-05-01 17:43:00	4633	3	4	f	2	4	t
3851	2024-03-20 21:27:00	1035	1	1	t	\N	4	t
3852	2024-04-08 01:39:00	6592	4	3	f	\N	1	f
3853	2024-03-25 04:36:00	6818	3	3	t	2	3	f
3854	2024-01-14 03:32:00	5783	4	2	f	\N	2	f
3855	2024-09-14 15:27:00	9973	5	2	f	1	4	t
3856	2024-08-06 19:56:00	9552	5	2	t	\N	1	t
3857	2024-05-02 02:15:00	7125	2	1	t	\N	1	f
3858	2024-04-02 09:34:00	2741	2	2	f	\N	1	f
3859	2024-05-13 16:43:00	1750	4	3	f	\N	4	t
3860	2024-03-11 21:16:00	3689	3	3	t	1	4	t
3861	2024-02-04 09:21:00	9067	2	3	f	1	3	f
3862	2024-07-29 17:26:00	3301	2	2	t	\N	2	t
3863	2024-02-04 08:05:00	7704	1	2	t	1	1	t
3864	2024-01-19 23:51:00	2752	4	3	f	\N	3	f
3865	2024-06-14 08:50:00	5166	3	3	f	\N	2	t
3866	2024-01-29 02:34:00	4209	1	2	f	2	2	t
3867	2024-05-20 13:28:00	4072	3	2	t	\N	3	t
3868	2024-04-09 13:15:00	2978	2	2	f	\N	4	t
3869	2024-04-29 05:47:00	7437	5	1	f	\N	1	f
3870	2024-09-02 06:58:00	4532	5	4	t	\N	2	t
3871	2024-02-23 18:20:00	8488	1	1	t	1	2	f
3872	2024-08-02 22:03:00	4122	2	1	t	1	4	f
3873	2024-02-28 16:18:00	6536	2	3	t	\N	2	f
3874	2024-02-17 09:21:00	2765	2	1	f	\N	4	f
3875	2024-04-25 15:25:00	7790	3	3	f	\N	3	t
3876	2024-09-01 02:11:00	1761	5	1	f	1	1	f
3877	2024-07-02 09:59:00	3018	3	1	t	\N	3	t
3878	2024-04-30 11:05:00	8381	3	4	f	\N	1	f
3879	2024-06-27 04:29:00	8493	3	4	t	\N	2	f
3880	2024-05-21 12:42:00	9260	4	2	t	\N	3	f
3881	2024-01-12 10:51:00	3205	1	2	f	\N	4	f
3882	2024-08-03 05:21:00	9172	3	2	t	2	2	f
3883	2024-01-25 19:45:00	1071	2	4	f	\N	3	f
3884	2024-02-06 00:23:00	9689	4	2	f	1	4	f
3885	2024-05-03 03:57:00	1795	2	3	f	\N	3	t
3886	2024-01-27 17:29:00	8091	2	1	f	2	1	f
3887	2024-08-07 09:30:00	8912	4	1	f	\N	1	t
3888	2024-03-17 02:35:00	9328	4	4	t	\N	2	t
3889	2024-03-06 07:03:00	3903	4	2	f	1	3	f
3890	2024-05-03 12:50:00	3845	5	3	f	\N	2	f
3891	2024-08-23 06:46:00	3103	3	1	f	\N	4	f
3892	2024-07-04 11:02:00	2696	5	3	t	2	2	t
3893	2024-01-01 05:55:00	7347	3	2	f	\N	3	f
3894	2024-06-24 18:43:00	6273	2	3	t	\N	3	t
3895	2024-06-29 21:44:00	9259	4	2	t	1	4	t
3896	2024-03-31 07:02:00	7302	3	3	t	2	1	t
3897	2024-01-29 00:21:00	7859	2	4	f	\N	2	t
3898	2024-06-17 16:38:00	5067	5	4	f	\N	2	t
3899	2024-07-07 03:01:00	5482	2	3	f	\N	4	f
3900	2024-08-20 14:47:00	7518	1	1	t	2	2	f
3901	2024-04-04 21:59:00	6617	4	3	f	\N	3	t
3902	2024-05-03 02:45:00	5819	5	3	t	\N	3	t
3903	2024-02-23 18:23:00	8419	1	1	t	2	4	t
3904	2024-01-03 12:29:00	3185	5	3	t	1	4	t
3905	2024-08-18 02:48:00	3263	2	4	t	\N	2	t
3906	2024-07-29 04:01:00	7762	4	1	t	\N	1	f
3907	2024-05-01 02:01:00	9393	2	4	f	1	4	f
3908	2024-05-17 02:47:00	5897	2	3	f	\N	4	t
3909	2024-05-13 08:58:00	9975	1	3	t	\N	1	f
3910	2024-05-06 21:02:00	6143	1	3	f	\N	2	t
3911	2024-01-27 09:05:00	4560	2	4	t	\N	1	f
3912	2024-07-12 11:04:00	4291	5	2	f	1	2	f
3913	2024-08-11 05:20:00	4435	5	4	f	1	1	t
3914	2024-03-24 07:46:00	5760	1	1	t	\N	3	f
3915	2024-06-30 04:25:00	6657	2	1	f	\N	1	t
3916	2024-08-16 18:45:00	3173	3	4	f	\N	3	f
3917	2024-05-16 02:04:00	3913	2	1	t	2	1	t
3918	2024-02-11 06:35:00	9255	3	3	f	\N	3	f
3919	2024-04-06 02:36:00	9888	2	1	t	1	1	f
3920	2024-04-06 14:06:00	6281	1	2	f	2	4	t
3921	2024-03-05 18:29:00	2890	2	1	t	1	2	t
3922	2024-01-06 07:37:00	6771	2	1	f	\N	4	f
3923	2024-01-14 11:26:00	8870	1	4	t	\N	3	f
3924	2024-06-09 04:34:00	7839	3	2	t	\N	2	f
3925	2024-05-23 23:21:00	9747	5	3	t	1	2	f
3926	2024-03-19 03:56:00	5684	5	1	t	\N	3	t
3927	2024-01-20 08:02:00	7920	3	4	t	1	1	t
3928	2024-07-27 13:39:00	1209	1	1	t	1	3	t
3929	2024-01-10 01:33:00	9564	4	2	t	\N	2	f
3930	2024-07-22 18:34:00	2744	2	2	f	\N	1	t
3931	2024-02-06 02:19:00	1414	1	4	t	\N	2	t
3932	2024-05-30 03:25:00	7240	3	2	t	\N	4	f
3933	2024-06-12 10:38:00	3381	5	2	f	1	4	t
3934	2024-06-23 13:09:00	1869	4	4	t	\N	2	f
3935	2024-02-26 15:17:00	1927	4	1	t	1	4	t
3936	2024-05-18 05:26:00	4275	1	1	t	\N	2	f
3937	2024-08-26 20:16:00	5374	3	3	t	\N	4	f
3938	2024-07-16 22:32:00	3636	2	4	t	\N	4	f
3939	2024-08-24 12:38:00	5695	1	4	t	1	1	t
3940	2024-09-06 21:23:00	5105	5	4	t	1	2	f
3941	2024-02-16 04:10:00	3399	1	4	f	\N	1	t
3942	2024-01-10 20:56:00	2016	4	3	f	\N	1	t
3943	2024-02-06 13:41:00	5835	1	2	t	2	3	f
3944	2024-03-03 16:45:00	4342	2	2	f	\N	2	t
3945	2024-07-05 03:12:00	9866	3	4	f	\N	4	t
3946	2024-06-30 17:29:00	1529	4	3	f	\N	4	t
3947	2024-03-10 01:07:00	6876	4	1	t	2	3	t
3948	2024-02-04 07:39:00	8415	4	4	t	\N	4	t
3949	2024-03-09 12:05:00	2679	1	1	t	2	2	f
3950	2024-07-14 23:05:00	4675	5	3	f	2	2	f
3951	2024-09-05 09:16:00	7371	5	4	f	1	1	f
3952	2024-01-24 09:45:00	4892	4	3	f	\N	3	f
3953	2024-05-04 04:38:00	9370	1	3	t	1	1	t
3954	2024-08-12 22:56:00	5712	2	2	f	\N	1	t
3955	2024-08-24 14:56:00	1769	3	2	f	\N	1	t
3956	2024-03-19 18:35:00	7251	3	1	f	\N	4	f
3957	2024-08-04 14:39:00	7349	4	2	t	\N	4	f
3958	2024-05-31 23:42:00	7825	4	2	f	1	1	f
3959	2024-01-19 23:37:00	6122	4	3	f	2	1	t
3960	2024-08-26 07:12:00	1881	4	1	t	1	4	f
3961	2024-03-20 00:22:00	1212	1	1	f	\N	1	f
3962	2024-08-10 13:10:00	5117	3	2	t	2	4	t
3963	2024-01-04 20:36:00	4327	1	2	t	\N	1	t
3964	2024-02-01 21:22:00	8259	2	2	t	2	1	f
3965	2024-06-09 19:55:00	4695	4	1	f	\N	1	f
3966	2024-02-29 11:12:00	7025	5	1	f	\N	1	t
3967	2024-02-05 10:54:00	9955	1	1	f	\N	2	f
3968	2024-08-29 21:31:00	4218	3	1	t	\N	4	f
3969	2024-08-01 12:40:00	4170	2	2	t	\N	3	t
3970	2024-03-06 01:34:00	5819	1	3	f	\N	4	t
3971	2024-04-11 01:27:00	8353	4	2	f	1	2	t
3972	2024-07-05 04:24:00	3906	1	3	f	1	3	f
3973	2024-06-09 07:53:00	2220	2	1	t	\N	1	t
3974	2024-08-14 23:11:00	4063	3	3	t	\N	3	t
3975	2024-08-19 16:14:00	3847	5	2	t	\N	4	t
3976	2024-02-09 13:31:00	9418	1	2	t	2	1	t
3977	2024-07-21 18:23:00	2955	3	1	t	\N	2	t
3978	2024-01-22 21:21:00	7180	3	2	f	\N	2	t
3979	2024-06-13 17:19:00	1665	1	1	t	\N	2	f
3980	2024-07-20 18:24:00	8020	2	3	f	\N	1	f
3981	2024-03-07 23:08:00	5572	3	1	f	\N	2	f
3982	2024-07-31 03:13:00	5329	4	1	t	\N	4	t
3983	2024-05-04 06:28:00	3131	2	1	t	\N	4	t
3984	2024-02-14 17:51:00	3636	1	1	t	2	1	t
3985	2024-07-20 19:55:00	5178	4	3	t	\N	3	t
3986	2024-07-07 14:25:00	1092	2	1	t	\N	4	f
3987	2024-01-01 00:40:00	6415	4	4	f	\N	4	f
3988	2024-09-14 06:33:00	8640	4	4	t	\N	4	f
3989	2024-03-09 17:52:00	3536	1	3	f	\N	2	f
3990	2024-06-21 21:01:00	1654	2	2	f	\N	4	t
3991	2024-07-29 22:49:00	3518	2	3	t	2	3	t
3992	2024-04-10 22:48:00	6285	2	4	t	\N	3	t
3993	2024-08-18 17:00:00	1833	3	1	f	\N	3	f
3994	2024-07-08 07:55:00	5934	4	3	t	\N	1	t
3995	2024-01-26 06:09:00	9037	2	1	t	\N	1	f
3996	2024-06-28 15:10:00	6866	4	1	f	\N	4	t
3997	2024-02-24 15:16:00	2194	2	1	f	1	1	t
3998	2024-06-28 16:39:00	6207	3	3	t	\N	3	f
3999	2024-08-22 05:07:00	9608	4	3	t	\N	1	f
4000	2024-04-06 07:50:00	4603	1	2	t	2	2	t
4001	2024-03-11 12:44:00	4012	1	4	f	\N	1	f
4002	2024-02-03 10:21:00	9529	2	1	t	\N	3	f
4003	2024-08-27 10:55:00	2117	4	4	t	\N	1	f
4004	2024-05-01 08:34:00	9276	5	2	t	2	4	f
4005	2024-02-27 23:36:00	3611	3	1	f	1	2	f
4006	2024-05-02 02:36:00	7814	4	4	t	1	4	t
4007	2024-01-06 04:38:00	9897	2	3	f	\N	1	f
4008	2024-07-23 05:44:00	9798	2	3	t	\N	4	t
4009	2024-01-25 09:17:00	7609	2	4	t	2	3	t
4010	2024-03-24 02:17:00	2506	3	1	t	\N	3	f
4011	2024-06-04 19:00:00	6724	3	4	f	\N	2	f
4012	2024-07-21 16:44:00	4624	4	3	f	\N	3	f
4013	2024-05-15 19:40:00	4495	4	3	f	\N	1	f
4014	2024-09-06 10:52:00	6437	4	2	f	2	4	f
4015	2024-07-24 14:24:00	6424	5	2	f	\N	4	t
4016	2024-08-26 10:02:00	6911	5	3	t	\N	3	f
4017	2024-06-07 13:29:00	5809	3	3	t	\N	4	f
4018	2024-08-08 17:14:00	4579	5	4	f	\N	2	f
4019	2024-08-04 03:40:00	9691	3	4	f	\N	3	f
4020	2024-07-15 03:55:00	8780	1	2	f	\N	1	t
4021	2024-08-13 17:35:00	1144	4	1	t	2	4	f
4022	2024-02-11 21:43:00	2879	5	4	f	\N	3	f
4023	2024-06-05 21:25:00	6668	1	1	t	2	1	t
4024	2024-01-01 03:00:00	8301	5	1	t	\N	2	t
4025	2024-02-28 03:06:00	4937	4	4	f	\N	4	f
4026	2024-07-28 08:36:00	4994	1	4	t	1	1	f
4027	2024-06-30 13:56:00	1653	4	3	f	\N	1	f
4028	2024-04-25 07:20:00	6258	2	1	f	\N	2	f
4029	2024-04-22 01:40:00	7248	1	4	f	\N	3	t
4030	2024-08-13 08:59:00	2857	1	3	f	1	1	f
4031	2024-02-26 20:07:00	7322	4	4	t	\N	3	t
4032	2024-07-22 15:45:00	5203	1	1	t	\N	2	t
4033	2024-04-22 11:27:00	9851	1	1	t	2	1	f
4034	2024-08-22 21:15:00	5633	4	3	t	\N	3	t
4035	2024-08-30 14:57:00	1404	1	2	t	\N	1	t
4036	2024-01-21 20:10:00	9468	2	3	t	\N	4	f
4037	2024-06-22 21:56:00	7143	3	1	f	1	4	t
4038	2024-03-07 13:21:00	9426	3	4	f	\N	1	f
4039	2024-05-05 05:53:00	9335	1	2	f	\N	2	f
4040	2024-06-19 18:45:00	8300	3	3	t	\N	2	t
4041	2024-01-22 23:28:00	8975	5	3	f	1	3	f
4042	2024-04-15 17:10:00	1718	2	1	t	\N	1	t
4043	2024-01-21 20:37:00	5856	1	4	f	\N	3	f
4044	2024-08-04 05:52:00	4154	3	4	t	\N	3	f
4045	2024-05-09 17:31:00	6248	5	3	f	\N	4	t
4046	2024-08-31 02:51:00	9419	1	2	f	\N	2	t
4047	2024-09-01 21:32:00	2349	4	1	t	\N	4	f
4048	2024-05-15 22:37:00	2572	1	3	t	2	2	f
4049	2024-04-08 01:32:00	3742	3	3	t	2	1	t
4050	2024-09-01 14:52:00	9814	4	3	t	\N	3	f
4051	2024-05-09 20:59:00	9736	5	4	t	2	3	f
4052	2024-01-22 06:48:00	1120	2	4	t	\N	2	t
4053	2024-07-16 04:28:00	2072	3	3	t	1	3	t
4054	2024-06-03 00:46:00	4453	3	1	t	2	3	f
4055	2024-04-11 07:05:00	4492	5	4	t	2	3	t
4056	2024-02-08 23:07:00	7950	1	2	t	\N	1	f
4057	2024-04-09 16:51:00	2702	1	2	t	\N	4	t
4058	2024-06-22 19:52:00	4368	2	3	f	\N	2	f
4059	2024-06-03 20:00:00	9810	2	2	t	\N	1	f
4060	2024-02-20 12:07:00	8130	5	2	t	2	3	t
4061	2024-07-13 11:33:00	2181	1	3	f	\N	4	f
4062	2024-04-09 09:26:00	3519	2	1	f	1	2	t
4063	2024-09-12 09:23:00	1389	1	3	t	\N	2	f
4064	2024-02-23 08:56:00	8523	5	1	f	2	1	f
4065	2024-02-06 01:35:00	6434	5	1	t	\N	1	f
4066	2024-06-06 01:01:00	1620	4	2	t	1	3	t
4067	2024-08-29 17:14:00	2433	1	4	t	\N	2	t
4068	2024-01-30 23:45:00	2200	2	3	t	\N	1	f
4069	2024-05-17 21:00:00	1889	3	1	f	\N	2	f
4070	2024-01-28 05:59:00	3916	4	4	f	\N	1	t
4071	2024-03-20 21:59:00	5127	4	2	t	2	4	f
4072	2024-04-14 04:29:00	2154	1	4	f	\N	4	f
4073	2024-01-17 16:49:00	4729	5	3	f	\N	2	f
4074	2024-01-09 11:57:00	5237	2	2	t	\N	2	t
4075	2024-09-07 00:23:00	7678	2	1	f	\N	2	f
4076	2024-07-01 14:42:00	7357	4	3	t	1	1	f
4077	2024-08-03 14:54:00	8391	4	4	f	\N	4	t
4078	2024-08-06 07:44:00	7626	1	4	f	1	4	f
4079	2024-06-06 19:51:00	8094	2	1	t	\N	1	f
4080	2024-02-22 12:23:00	6183	1	3	f	\N	4	t
4081	2024-05-10 18:02:00	1276	1	2	f	\N	2	t
4082	2024-05-04 16:22:00	7381	5	2	t	\N	1	t
4083	2024-07-03 06:46:00	2938	5	1	t	\N	2	t
4084	2024-04-01 08:15:00	9762	2	4	t	1	1	t
4085	2024-04-17 18:53:00	1096	2	3	t	\N	1	f
4086	2024-06-10 19:19:00	2036	5	4	f	\N	1	t
4087	2024-01-16 00:06:00	1745	5	3	t	\N	2	f
4088	2024-08-25 03:39:00	2189	4	4	f	\N	3	t
4089	2024-02-09 14:46:00	6860	2	2	t	\N	2	t
4090	2024-03-02 21:16:00	9238	5	2	f	\N	2	t
4091	2024-06-10 03:10:00	2738	1	3	f	\N	1	t
4092	2024-09-06 00:58:00	5748	3	4	t	\N	3	f
4093	2024-08-25 11:26:00	5937	2	1	t	1	2	t
4094	2024-06-04 23:53:00	2417	5	2	f	\N	3	t
4095	2024-05-13 01:07:00	5612	5	4	f	\N	1	t
4096	2024-05-11 20:28:00	8170	2	4	f	2	4	t
4097	2024-01-12 19:54:00	7249	2	1	f	\N	3	f
4098	2024-02-26 13:11:00	7473	1	4	f	1	1	f
4099	2024-02-29 20:45:00	1504	5	4	f	\N	4	t
4100	2024-04-17 05:51:00	8765	3	1	f	\N	4	f
4101	2024-04-01 13:09:00	3561	2	2	f	2	3	f
4102	2024-05-15 20:09:00	9740	2	1	t	\N	1	f
4103	2024-07-23 04:39:00	4602	5	1	t	\N	2	t
4104	2024-06-07 07:28:00	3234	2	2	f	2	2	f
4105	2024-02-14 10:51:00	7406	2	1	t	\N	3	t
4106	2024-06-22 01:13:00	9941	4	4	t	1	4	f
4107	2024-08-09 21:48:00	5832	2	3	t	\N	3	f
4108	2024-08-26 01:00:00	3360	5	1	t	\N	1	f
4109	2024-07-01 18:11:00	5883	3	2	t	1	1	f
4110	2024-04-23 04:50:00	7113	5	2	t	\N	3	f
4111	2024-04-08 05:43:00	1182	1	4	t	\N	1	f
4112	2024-05-13 07:59:00	3316	1	3	t	1	4	f
4113	2024-07-18 22:04:00	3019	2	1	f	\N	4	f
4114	2024-06-02 16:44:00	1684	5	1	f	\N	4	f
4115	2024-07-19 11:10:00	1082	2	2	t	\N	2	t
4116	2024-08-06 15:30:00	7456	4	1	t	\N	2	t
4117	2024-06-13 10:02:00	9800	5	1	t	\N	3	t
4118	2024-03-29 05:59:00	9970	2	3	f	2	3	f
4119	2024-04-16 23:39:00	2394	2	4	t	2	3	f
4120	2024-02-18 23:14:00	5992	5	2	f	\N	4	f
4121	2024-06-01 11:57:00	4441	1	3	f	\N	3	t
4122	2024-06-05 07:05:00	6633	1	3	t	\N	1	t
4123	2024-02-13 01:58:00	4469	4	2	f	1	2	t
4124	2024-08-29 12:07:00	7760	4	2	f	2	3	t
4125	2024-09-08 02:42:00	9397	2	1	f	\N	3	t
4126	2024-04-11 20:52:00	3333	5	4	t	\N	1	f
4127	2024-09-04 21:28:00	3637	5	3	f	\N	4	f
4128	2024-05-13 17:55:00	4014	2	2	f	\N	1	t
4129	2024-02-10 02:19:00	4617	1	1	f	\N	2	t
4130	2024-04-28 12:22:00	5140	3	4	t	\N	2	t
4131	2024-03-10 09:17:00	4183	1	4	t	2	1	f
4132	2024-06-15 11:01:00	2877	5	3	t	\N	1	f
4133	2024-08-10 23:43:00	3971	2	4	f	\N	3	f
4134	2024-05-18 11:44:00	1891	5	1	t	\N	4	t
4135	2024-09-09 20:14:00	9992	4	2	f	2	4	t
4136	2024-03-11 07:35:00	8557	4	3	t	\N	1	f
4137	2024-05-09 11:44:00	2198	3	4	t	2	1	t
4138	2024-05-21 10:03:00	5762	4	2	f	\N	1	f
4139	2024-05-31 17:04:00	2103	1	4	f	\N	2	t
4140	2024-04-05 13:32:00	5107	5	1	t	2	4	t
4141	2024-02-02 01:46:00	2608	5	1	f	\N	1	t
4142	2024-07-13 22:59:00	4234	5	4	f	1	4	t
4143	2024-04-01 08:37:00	8982	5	1	t	\N	4	f
4144	2024-06-18 23:47:00	6420	1	4	t	1	1	f
4145	2024-02-24 13:20:00	6851	5	2	f	\N	2	t
4146	2024-06-28 08:45:00	3100	4	4	f	1	2	f
4147	2024-02-05 14:24:00	4842	4	2	t	2	2	t
4148	2024-02-25 13:59:00	2639	3	2	t	\N	3	f
4149	2024-04-10 14:41:00	5671	2	3	f	1	2	t
4150	2024-07-23 16:26:00	2143	2	3	f	1	3	t
4151	2024-07-03 03:03:00	4170	3	4	t	1	4	t
4152	2024-06-27 09:07:00	6206	3	4	f	\N	2	t
4153	2024-02-19 08:22:00	8960	1	4	f	2	1	f
4154	2024-02-16 15:35:00	8383	2	3	t	\N	3	f
4155	2024-06-19 19:24:00	6379	3	3	t	\N	4	t
4156	2024-05-29 06:08:00	6008	2	1	t	1	1	f
4157	2024-07-04 10:13:00	3496	1	3	f	\N	1	f
4158	2024-07-30 01:43:00	6971	4	2	t	2	1	t
4159	2024-05-28 03:04:00	6182	5	2	t	2	3	t
4160	2024-06-10 20:46:00	8017	3	4	f	\N	2	f
4161	2024-02-24 07:19:00	3762	5	1	f	\N	3	t
4162	2024-02-02 17:20:00	1079	3	2	t	\N	2	f
4163	2024-04-25 02:42:00	6131	3	4	f	\N	4	t
4164	2024-08-21 21:30:00	5033	4	2	f	\N	1	t
4165	2024-02-09 02:35:00	4629	3	4	t	\N	2	t
4166	2024-09-07 12:53:00	8145	4	1	t	\N	2	f
4167	2024-06-09 10:56:00	5533	1	4	f	\N	2	t
4168	2024-04-05 08:51:00	6889	5	3	t	\N	3	t
4169	2024-04-14 23:04:00	3200	5	4	f	1	2	f
4170	2024-02-19 16:40:00	6432	4	4	f	1	2	f
4171	2024-08-10 19:31:00	8863	5	2	t	\N	1	f
4172	2024-09-07 11:10:00	8583	1	4	t	\N	3	t
4173	2024-01-15 08:51:00	8296	4	4	t	\N	3	f
4174	2024-06-10 17:29:00	6877	5	2	t	\N	3	f
4175	2024-07-01 02:03:00	6004	2	2	t	1	1	t
4176	2024-01-21 02:04:00	8978	4	3	f	\N	3	t
4177	2024-06-01 11:34:00	2783	2	1	f	\N	2	f
4178	2024-07-28 20:43:00	3879	1	4	t	\N	4	t
4179	2024-09-11 20:05:00	2343	2	4	f	\N	4	f
4180	2024-04-19 21:17:00	5597	5	1	t	\N	4	t
4181	2024-04-09 01:32:00	3293	3	3	t	\N	3	f
4182	2024-06-08 04:32:00	9824	5	2	f	1	1	f
4183	2024-01-05 04:13:00	4218	5	4	f	\N	1	f
4184	2024-08-13 22:27:00	5312	1	2	t	2	2	t
4185	2024-03-06 10:23:00	2252	2	3	f	\N	2	f
4186	2024-03-10 01:21:00	2235	1	4	f	2	4	f
4187	2024-05-22 12:19:00	1305	5	4	t	\N	4	t
4188	2024-01-05 12:01:00	9309	1	2	t	1	2	f
4189	2024-06-18 15:49:00	1511	2	3	t	\N	1	t
4190	2024-08-24 02:52:00	7637	3	1	f	\N	4	t
4191	2024-07-08 07:22:00	4485	1	3	f	2	2	t
4192	2024-03-08 00:50:00	1600	5	3	t	\N	4	t
4193	2024-02-16 23:34:00	5269	2	1	t	\N	1	f
4194	2024-05-15 17:32:00	9904	2	3	f	2	4	f
4195	2024-05-19 04:38:00	9842	2	4	f	1	1	t
4196	2024-05-25 18:48:00	8734	5	1	f	\N	2	f
4197	2024-05-08 13:34:00	3435	4	4	f	1	3	t
4198	2024-04-09 21:14:00	6993	5	4	t	\N	4	t
4199	2024-03-03 04:19:00	7430	5	2	f	\N	3	f
4200	2024-06-24 13:26:00	4658	3	4	t	\N	4	f
4201	2024-07-25 09:29:00	5767	1	4	f	2	2	t
4202	2024-02-06 12:20:00	3193	2	4	t	\N	1	f
4203	2024-07-30 09:53:00	8613	2	2	t	2	1	f
4204	2024-08-09 11:25:00	9210	3	2	f	\N	1	t
4205	2024-01-07 19:18:00	9362	5	3	f	\N	1	t
4206	2024-05-16 20:21:00	2483	1	4	f	2	1	f
4207	2024-03-10 16:13:00	7500	2	4	t	\N	4	f
4208	2024-05-04 12:15:00	6961	2	3	f	\N	1	t
4209	2024-04-22 21:34:00	9227	3	3	t	1	4	t
4210	2024-03-26 10:49:00	1173	2	3	f	\N	3	t
4211	2024-01-25 03:18:00	4913	4	1	f	\N	1	f
4212	2024-05-13 00:18:00	3717	4	3	t	\N	3	f
4213	2024-04-12 08:22:00	9423	2	4	f	\N	3	f
4214	2024-09-07 05:39:00	3299	3	3	f	1	2	t
4215	2024-01-22 08:45:00	8310	2	2	t	\N	3	t
4216	2024-04-21 08:53:00	3608	5	1	f	\N	2	t
4217	2024-01-25 23:13:00	3935	2	3	f	\N	1	t
4218	2024-07-15 05:50:00	3395	5	2	t	\N	4	t
4219	2024-02-27 08:20:00	8921	2	1	f	\N	3	t
4220	2024-06-10 01:02:00	6878	5	3	f	2	3	t
4221	2024-03-21 02:13:00	1662	5	2	t	\N	1	f
4222	2024-02-19 00:12:00	4585	4	2	t	\N	2	t
4223	2024-08-26 19:15:00	8989	4	1	f	\N	2	f
4224	2024-05-31 13:05:00	4796	1	2	t	\N	4	t
4225	2024-06-04 04:33:00	2029	3	1	t	\N	4	t
4226	2024-03-24 16:29:00	5331	3	3	f	\N	4	t
4227	2024-09-01 10:41:00	7052	2	2	f	\N	3	f
4228	2024-01-13 07:03:00	4834	1	1	t	\N	2	t
4229	2024-04-16 15:15:00	1701	2	3	t	\N	3	f
4230	2024-06-19 23:25:00	4387	2	4	t	\N	2	f
4231	2024-07-27 00:53:00	9485	4	3	t	\N	2	t
4232	2024-04-17 01:05:00	6918	4	3	f	\N	2	t
4233	2024-04-06 07:28:00	7358	5	2	f	1	1	f
4234	2024-03-17 21:28:00	8695	5	2	f	\N	1	f
4235	2024-01-20 14:43:00	8448	5	1	f	\N	4	t
4236	2024-01-01 07:52:00	1760	4	4	t	\N	2	t
4237	2024-06-18 18:57:00	1653	4	4	t	\N	4	f
4238	2024-07-24 07:45:00	6309	1	1	t	1	2	t
4239	2024-06-30 14:32:00	2691	5	1	f	2	4	t
4240	2024-08-13 22:13:00	9542	5	4	t	\N	3	f
4241	2024-01-11 05:54:00	5480	4	3	t	\N	1	f
4242	2024-02-23 15:24:00	5314	4	2	t	\N	1	t
4243	2024-08-13 20:32:00	9918	1	3	f	\N	4	f
4244	2024-09-03 15:34:00	3848	4	1	t	\N	1	t
4245	2024-05-15 10:09:00	7171	2	4	f	\N	4	f
4246	2024-07-01 21:26:00	7201	1	4	t	\N	1	f
4247	2024-08-12 09:22:00	6985	5	3	t	\N	4	t
4248	2024-02-11 02:54:00	2275	2	4	f	2	4	f
4249	2024-01-05 23:39:00	9465	3	4	f	1	1	t
4250	2024-05-26 05:23:00	5121	5	4	t	1	3	t
4251	2024-06-29 12:26:00	7165	3	1	f	\N	3	f
4252	2024-08-21 22:33:00	4651	2	4	f	\N	1	f
4253	2024-08-18 19:36:00	9460	1	3	f	\N	4	f
4254	2024-05-09 02:28:00	7649	4	2	f	1	4	t
4255	2024-01-10 21:12:00	6781	3	3	f	\N	1	t
4256	2024-08-30 01:40:00	6653	2	1	f	\N	2	f
4257	2024-07-22 22:06:00	8976	4	4	t	\N	1	t
4258	2024-01-12 02:10:00	8898	4	3	t	2	3	f
4259	2024-05-21 21:06:00	1108	2	4	f	1	4	t
4260	2024-08-17 22:45:00	9222	5	1	f	\N	2	f
4261	2024-06-20 02:59:00	3276	2	2	f	\N	4	f
4262	2024-05-09 03:05:00	8207	2	2	t	\N	4	f
4263	2024-01-06 12:24:00	3713	5	3	f	\N	1	t
4264	2024-01-10 09:40:00	4768	1	4	t	\N	4	f
4265	2024-05-01 11:34:00	2263	1	3	f	\N	3	t
4266	2024-04-22 15:12:00	9430	3	3	f	\N	1	f
4267	2024-01-10 17:09:00	5600	5	1	t	\N	3	t
4268	2024-06-13 14:59:00	4465	4	1	f	\N	1	f
4269	2024-05-29 19:14:00	3461	3	3	f	2	4	f
4270	2024-02-07 13:26:00	4062	2	3	f	2	4	f
4271	2024-03-12 23:46:00	3578	5	1	f	\N	2	t
4272	2024-01-03 10:16:00	6934	3	3	t	1	1	t
4273	2024-07-18 14:15:00	2938	5	1	f	\N	1	t
4274	2024-02-12 19:36:00	4773	3	1	f	\N	3	t
4275	2024-07-05 08:09:00	7793	2	4	f	1	1	f
4276	2024-02-29 14:32:00	6410	5	1	t	\N	4	t
4277	2024-02-21 23:03:00	2856	1	2	t	\N	4	t
4278	2024-06-10 06:57:00	8889	1	1	t	\N	2	f
4279	2024-03-17 17:59:00	8844	3	4	t	2	2	t
4280	2024-06-01 05:52:00	8848	5	3	t	2	2	f
4281	2024-07-11 22:34:00	4452	5	2	t	\N	1	f
4282	2024-08-20 22:18:00	3641	3	4	f	2	1	f
4283	2024-02-28 23:25:00	7732	5	2	f	2	4	f
4284	2024-05-12 18:18:00	1367	4	3	f	\N	2	t
4285	2024-06-08 11:21:00	4992	3	4	t	1	1	f
4286	2024-06-24 11:54:00	1706	3	1	f	\N	4	f
4287	2024-05-09 02:00:00	3095	5	3	t	\N	3	t
4288	2024-07-18 13:52:00	3639	1	4	t	\N	1	t
4289	2024-05-25 08:39:00	3207	3	3	t	\N	1	t
4290	2024-08-02 08:33:00	9399	1	4	f	1	2	t
4291	2024-01-03 21:45:00	1642	3	2	f	\N	3	t
4292	2024-07-24 17:45:00	3406	2	3	t	\N	2	f
4293	2024-02-17 17:51:00	1916	1	1	t	1	1	t
4294	2024-08-03 03:16:00	3725	3	3	t	\N	1	t
4295	2024-02-18 19:23:00	5231	4	4	f	\N	2	f
4296	2024-09-11 22:38:00	3949	4	2	f	2	4	f
4297	2024-08-08 07:06:00	9464	4	3	f	\N	3	t
4298	2024-03-20 11:25:00	7642	5	1	t	\N	4	t
4299	2024-04-25 07:05:00	1305	2	2	f	\N	1	t
4300	2024-03-10 21:28:00	5644	4	4	t	\N	3	t
4301	2024-05-14 20:54:00	2404	1	1	t	1	4	f
4302	2024-03-28 04:43:00	4548	3	4	t	\N	3	t
4303	2024-06-26 09:49:00	8359	4	4	t	1	1	f
4304	2024-06-06 06:07:00	8723	4	1	f	1	1	f
4305	2024-04-28 22:45:00	8891	1	2	f	2	1	t
4306	2024-07-20 04:52:00	3794	4	2	t	\N	1	f
4307	2024-08-15 04:04:00	4594	5	1	t	\N	2	f
4308	2024-04-20 09:19:00	7730	5	1	t	\N	4	t
4309	2024-01-01 00:31:00	3338	1	3	t	\N	2	t
4310	2024-01-25 17:27:00	3979	2	1	f	\N	2	f
4311	2024-06-03 14:19:00	9369	5	1	t	\N	2	f
4312	2024-06-13 02:33:00	5333	4	2	f	1	2	t
4313	2024-04-22 12:38:00	3747	4	4	t	2	2	f
4314	2024-07-12 12:45:00	6614	3	1	t	\N	2	t
4315	2024-08-08 03:13:00	8429	3	4	t	\N	4	t
4316	2024-04-04 21:59:00	2127	5	1	t	\N	1	t
4317	2024-05-03 09:47:00	4765	3	4	f	\N	2	t
4318	2024-02-09 08:27:00	7196	1	2	t	\N	1	t
4319	2024-01-25 10:48:00	7315	2	1	t	\N	2	f
4320	2024-01-02 04:52:00	3166	3	4	f	2	1	f
4321	2024-06-21 21:44:00	2778	3	4	t	\N	3	f
4322	2024-08-30 12:46:00	1271	5	4	f	\N	3	t
4323	2024-04-26 15:55:00	4315	5	3	t	\N	3	t
4324	2024-08-15 06:56:00	9564	4	4	f	\N	2	t
4325	2024-03-10 06:24:00	9263	2	4	f	\N	3	t
4326	2024-06-11 01:56:00	7877	4	1	t	2	1	f
4327	2024-07-01 10:33:00	3450	2	3	f	1	3	t
4328	2024-08-27 22:52:00	2577	4	4	f	\N	4	f
4329	2024-07-26 07:58:00	3906	1	3	t	\N	4	f
4330	2024-03-13 18:26:00	8796	4	2	t	\N	4	t
4331	2024-01-13 07:21:00	1639	2	1	f	\N	3	f
4332	2024-01-01 21:53:00	9706	2	3	t	\N	1	t
4333	2024-02-22 10:18:00	9246	1	1	t	\N	2	t
4334	2024-03-22 14:35:00	2925	2	1	t	2	2	t
4335	2024-03-21 04:35:00	2526	1	1	t	\N	3	t
4336	2024-06-30 02:42:00	8901	5	1	t	1	3	t
4337	2024-06-11 17:28:00	3135	5	1	t	2	3	f
4338	2024-08-12 22:00:00	9835	1	1	f	\N	2	f
4339	2024-02-11 14:08:00	1019	2	2	t	\N	4	f
4340	2024-04-08 23:07:00	8069	2	4	f	\N	2	t
4341	2024-08-16 08:26:00	9553	5	1	f	\N	1	f
4342	2024-06-27 08:16:00	7892	3	4	f	\N	4	f
4343	2024-03-30 10:05:00	7068	5	2	f	\N	4	t
4344	2024-07-01 13:06:00	1711	5	1	f	\N	3	f
4345	2024-03-10 10:55:00	9680	2	1	t	\N	2	t
4346	2024-05-30 05:23:00	8028	5	1	f	\N	1	f
4347	2024-02-13 21:47:00	4759	2	1	t	1	2	f
4348	2024-07-04 09:27:00	8899	3	4	t	1	4	t
4349	2024-05-24 10:30:00	7246	5	4	t	\N	3	f
4350	2024-03-19 09:05:00	6742	4	1	t	\N	4	t
4351	2024-01-10 08:14:00	2600	2	1	f	1	1	t
4352	2024-06-09 01:35:00	7971	4	1	f	1	3	f
4353	2024-09-05 08:28:00	3193	1	3	f	\N	4	f
4354	2024-05-22 23:01:00	5170	5	2	f	\N	1	t
4355	2024-09-13 07:41:00	8817	5	2	f	\N	2	t
4356	2024-04-24 07:45:00	4809	1	2	t	1	1	f
4357	2024-06-30 18:38:00	2373	1	4	f	1	3	f
4358	2024-02-07 17:33:00	5641	5	4	t	2	3	t
4359	2024-07-24 09:03:00	9908	3	2	t	\N	2	f
4360	2024-07-06 15:52:00	7695	5	3	t	\N	4	f
4361	2024-07-02 05:20:00	5223	2	3	t	1	4	f
4362	2024-06-14 04:37:00	4096	3	4	f	\N	2	f
4363	2024-03-15 16:54:00	1089	5	3	f	\N	1	f
4364	2024-08-04 11:59:00	1116	4	3	f	2	3	t
4365	2024-04-08 16:27:00	9561	3	1	f	2	1	f
4366	2024-03-04 01:10:00	2930	5	3	t	2	4	t
4367	2024-09-07 08:12:00	9515	5	1	f	\N	3	f
4368	2024-07-26 07:02:00	1117	4	4	t	\N	3	f
4369	2024-01-04 09:16:00	7144	3	3	f	1	1	f
4370	2024-01-20 02:08:00	4365	4	2	f	2	1	f
4371	2024-05-24 09:22:00	6175	5	3	f	2	2	t
4372	2024-04-22 00:27:00	7698	5	2	t	\N	1	t
4373	2024-04-17 02:52:00	6935	4	2	t	\N	2	t
4374	2024-08-16 01:28:00	2746	5	1	f	1	2	t
4375	2024-06-18 18:40:00	3535	4	2	f	2	2	t
4376	2024-07-04 02:12:00	7980	3	1	f	\N	2	t
4377	2024-01-09 00:05:00	5155	1	2	f	2	1	f
4378	2024-07-10 03:18:00	5281	3	3	t	\N	1	t
4379	2024-07-23 02:26:00	9783	4	2	t	\N	3	t
4380	2024-04-13 04:44:00	7939	1	1	f	2	3	f
4381	2024-04-13 12:29:00	6990	4	4	f	\N	2	f
4382	2024-03-23 20:51:00	5514	1	4	f	\N	3	t
4383	2024-08-08 04:28:00	7511	1	3	f	2	2	t
4384	2024-01-23 13:48:00	4337	4	2	f	2	2	t
4385	2024-06-13 11:53:00	7770	2	3	f	\N	1	t
4386	2024-07-18 11:00:00	8904	5	2	t	\N	4	t
4387	2024-08-07 07:18:00	3928	2	2	f	2	4	t
4388	2024-06-08 03:25:00	7065	3	3	f	1	2	t
4389	2024-01-30 06:23:00	8925	5	4	t	2	1	f
4390	2024-08-24 17:39:00	5157	4	1	f	2	2	f
4391	2024-06-22 22:30:00	6024	1	2	f	\N	3	t
4392	2024-05-06 16:49:00	6641	5	4	f	\N	1	f
4393	2024-03-07 14:41:00	7522	3	1	f	\N	4	t
4394	2024-02-01 11:22:00	3262	3	1	f	\N	4	t
4395	2024-07-11 15:37:00	2951	1	3	t	\N	2	t
4396	2024-04-13 07:32:00	4764	5	4	f	\N	1	t
4397	2024-03-20 02:34:00	8317	2	4	t	\N	1	t
4398	2024-07-20 06:31:00	3650	1	3	t	\N	1	f
4399	2024-02-18 23:12:00	2642	1	3	t	\N	3	t
4400	2024-04-12 22:55:00	4513	5	1	t	\N	4	f
4401	2024-03-10 14:30:00	9328	1	4	f	2	3	t
4402	2024-02-14 02:03:00	7562	5	4	t	1	3	f
4403	2024-04-20 05:28:00	6544	5	2	f	\N	3	t
4404	2024-04-13 04:47:00	1852	5	1	t	\N	2	f
4405	2024-04-09 15:55:00	3633	3	3	t	\N	1	f
4406	2024-03-05 17:47:00	7375	3	3	t	2	4	t
4407	2024-07-23 07:31:00	1086	4	3	f	1	2	f
4408	2024-01-06 20:59:00	2492	4	3	t	\N	4	f
4409	2024-06-19 09:51:00	3381	4	4	t	1	1	t
4410	2024-02-02 03:03:00	8727	4	1	t	\N	3	t
4411	2024-08-18 21:04:00	8133	4	4	t	\N	3	f
4412	2024-04-19 04:31:00	2444	4	2	f	\N	1	f
4413	2024-08-03 14:27:00	2049	5	4	t	\N	1	f
4414	2024-04-13 11:09:00	5310	1	1	t	\N	3	f
4415	2024-08-23 03:19:00	4633	3	4	f	1	4	f
4416	2024-03-24 16:25:00	7075	2	3	t	1	2	f
4417	2024-04-07 13:12:00	2311	3	4	t	\N	2	f
4418	2024-05-09 02:10:00	1618	1	2	f	2	1	t
4419	2024-03-27 14:34:00	7296	4	4	t	\N	4	f
4420	2024-01-31 10:27:00	7564	5	1	f	\N	4	f
4421	2024-07-04 00:18:00	9536	5	3	t	\N	3	f
4422	2024-02-15 02:06:00	5693	4	1	f	\N	3	f
4423	2024-08-08 08:36:00	1941	5	3	f	\N	4	t
4424	2024-01-17 00:00:00	3871	1	3	t	\N	1	f
4425	2024-07-30 10:52:00	9099	2	1	f	1	4	t
4426	2024-01-07 17:22:00	8192	5	1	t	\N	1	f
4427	2024-01-15 12:59:00	1175	4	3	f	\N	4	f
4428	2024-09-10 15:40:00	4304	4	3	t	2	4	f
4429	2024-02-17 13:04:00	9489	3	4	f	\N	2	t
4430	2024-05-18 05:34:00	5685	3	1	f	\N	3	t
4431	2024-03-14 10:31:00	4190	5	1	t	1	1	f
4432	2024-08-21 13:33:00	1550	4	3	t	\N	1	t
4433	2024-02-17 18:12:00	9364	4	1	f	1	1	f
4434	2024-09-13 17:08:00	9451	5	1	t	1	3	t
4435	2024-06-20 04:03:00	4795	2	4	t	\N	2	t
4436	2024-01-10 21:56:00	3776	2	2	f	\N	4	f
4437	2024-01-15 10:25:00	1590	2	2	t	\N	4	t
4438	2024-08-24 15:35:00	6893	1	4	t	\N	4	f
4439	2024-03-08 20:09:00	4919	5	3	t	\N	2	f
4440	2024-03-06 12:28:00	1004	3	1	t	\N	4	f
4441	2024-01-05 14:33:00	3579	3	1	t	\N	4	t
4442	2024-03-01 16:28:00	2422	2	2	t	\N	4	t
4443	2024-02-22 13:18:00	5520	3	4	t	2	2	f
4444	2024-08-26 18:05:00	7544	4	1	t	2	3	t
4445	2024-05-16 01:00:00	6785	1	2	f	\N	1	f
4446	2024-06-21 02:34:00	7474	2	1	f	2	3	t
4447	2024-04-06 22:35:00	7642	4	2	t	2	1	t
4448	2024-08-12 05:49:00	4281	4	3	f	\N	4	f
4449	2024-01-30 14:07:00	9482	2	3	t	\N	2	f
4450	2024-08-04 16:44:00	1251	3	4	f	\N	2	t
4451	2024-08-26 05:38:00	2124	2	1	t	\N	2	t
4452	2024-08-29 12:02:00	2477	2	1	f	\N	4	f
4453	2024-01-06 13:40:00	5661	5	4	f	\N	2	t
4454	2024-05-28 22:09:00	6703	1	1	f	\N	3	t
4455	2024-04-25 21:23:00	6693	3	1	f	2	3	f
4456	2024-05-16 14:17:00	5530	1	4	t	1	2	f
4457	2024-06-24 03:43:00	4707	2	1	t	1	2	t
4458	2024-01-05 17:37:00	4187	1	3	f	\N	1	t
4459	2024-01-10 15:23:00	8450	3	3	t	1	2	t
4460	2024-06-22 03:11:00	7618	1	2	f	\N	2	t
4461	2024-02-01 18:51:00	1076	1	3	f	2	2	t
4462	2024-04-18 03:10:00	5277	1	2	f	\N	1	f
4463	2024-05-01 11:24:00	3867	4	3	t	2	1	t
4464	2024-04-17 23:29:00	7670	2	2	t	1	1	t
4465	2024-03-02 02:34:00	9294	3	3	t	\N	1	f
4466	2024-03-16 13:12:00	2744	1	2	f	\N	2	t
4467	2024-03-13 19:21:00	2185	4	4	t	1	3	f
4468	2024-04-17 00:16:00	9243	2	1	t	\N	2	f
4469	2024-08-15 22:39:00	5821	4	3	f	\N	4	t
4470	2024-01-21 12:26:00	6570	2	2	t	1	3	f
4471	2024-04-13 19:29:00	2917	1	1	t	2	2	f
4472	2024-04-16 07:54:00	9409	1	4	f	\N	4	t
4473	2024-05-27 17:06:00	5222	2	3	f	\N	1	t
4474	2024-05-13 13:38:00	9813	2	3	f	1	4	t
4475	2024-07-25 19:51:00	5098	3	3	f	\N	2	f
4476	2024-01-06 20:34:00	8254	4	3	t	\N	2	t
4477	2024-07-05 02:02:00	7178	5	1	t	\N	4	t
4478	2024-08-26 06:28:00	8923	2	1	t	1	3	f
4479	2024-01-24 17:24:00	4985	3	3	f	1	2	f
4480	2024-02-09 20:16:00	6565	5	2	t	\N	1	t
4481	2024-04-13 02:17:00	8517	1	2	f	\N	1	t
4482	2024-02-04 08:07:00	8548	2	1	f	\N	2	f
4483	2024-02-20 16:55:00	1448	1	3	f	\N	3	f
4484	2024-04-27 12:53:00	8896	1	3	t	\N	4	t
4485	2024-09-02 18:03:00	2904	4	4	t	2	3	f
4486	2024-01-06 07:37:00	5224	4	2	f	1	1	t
4487	2024-02-27 17:18:00	2106	2	1	t	\N	4	t
4488	2024-09-02 06:25:00	7269	1	2	t	\N	3	t
4489	2024-02-10 06:40:00	4610	1	4	f	\N	1	f
4490	2024-05-26 15:02:00	4767	3	4	t	\N	1	f
4491	2024-08-26 08:10:00	6172	4	2	t	\N	2	t
4492	2024-03-31 11:24:00	7757	3	3	f	\N	3	t
4493	2024-02-24 10:05:00	6785	1	1	t	2	2	f
4494	2024-04-28 09:56:00	9462	3	2	t	1	1	f
4495	2024-09-07 19:11:00	9776	3	2	t	\N	1	f
4496	2024-06-09 03:42:00	1159	2	3	f	2	4	f
4497	2024-08-20 19:12:00	5314	4	2	f	\N	1	f
4498	2024-02-18 00:20:00	5067	2	3	t	\N	2	t
4499	2024-09-05 08:48:00	5706	1	1	t	1	2	t
4500	2024-02-15 14:04:00	2523	1	1	t	\N	3	t
4501	2024-02-09 01:20:00	7536	2	2	t	\N	2	f
4502	2024-05-12 00:27:00	6603	3	4	f	\N	4	f
4503	2024-08-26 21:18:00	2245	4	2	f	\N	4	t
4504	2024-05-31 00:39:00	3924	3	4	f	\N	1	t
4505	2024-08-22 05:24:00	8807	2	3	f	\N	1	t
4506	2024-08-18 14:11:00	6142	2	2	f	1	3	t
4507	2024-06-10 02:08:00	6792	1	3	f	2	2	f
4508	2024-02-10 17:42:00	4580	5	3	t	\N	1	t
4509	2024-01-01 09:07:00	5408	1	3	t	\N	1	t
4510	2024-03-08 16:39:00	3994	1	4	t	\N	3	f
4511	2024-01-13 22:56:00	4115	4	1	t	\N	1	t
4512	2024-05-23 16:57:00	9175	4	4	t	\N	1	t
4513	2024-05-23 22:04:00	4271	4	3	t	1	3	f
4514	2024-06-11 17:31:00	4847	2	3	f	\N	4	t
4515	2024-04-08 18:05:00	4965	2	3	f	\N	3	f
4516	2024-08-28 14:12:00	5348	4	3	t	1	2	t
4517	2024-03-02 12:53:00	4387	2	2	t	1	2	t
4518	2024-07-16 08:27:00	4755	3	2	t	\N	4	t
4519	2024-08-21 00:10:00	4322	2	2	t	\N	2	f
4520	2024-02-16 12:04:00	5091	2	2	t	\N	3	t
4521	2024-06-12 02:56:00	6833	3	3	t	2	1	t
4522	2024-06-13 13:22:00	3555	5	1	f	\N	3	t
4523	2024-05-20 04:39:00	2747	4	1	t	\N	2	t
4524	2024-09-01 05:42:00	2964	2	4	f	\N	4	f
4525	2024-03-16 01:40:00	2285	5	1	f	\N	4	t
4526	2024-03-30 09:44:00	9071	5	3	f	1	1	f
4527	2024-07-10 18:31:00	1108	4	4	t	2	4	f
4528	2024-08-02 14:02:00	9871	4	3	f	\N	3	f
4529	2024-06-19 16:53:00	1692	2	2	t	\N	1	f
4530	2024-02-29 01:30:00	8901	2	2	f	\N	1	t
4531	2024-08-24 20:07:00	7081	3	4	t	\N	2	f
4532	2024-07-23 04:08:00	6167	5	4	t	\N	3	t
4533	2024-06-04 21:37:00	9066	5	2	t	\N	3	t
4534	2024-02-16 04:53:00	5501	3	2	f	\N	1	f
4535	2024-06-10 00:47:00	9041	2	4	f	\N	3	t
4536	2024-05-20 05:44:00	3996	5	3	t	\N	2	f
4537	2024-03-25 23:17:00	9374	3	4	f	2	2	f
4538	2024-08-13 05:45:00	5591	4	4	t	\N	3	f
4539	2024-08-07 15:17:00	7518	2	1	t	2	3	f
4540	2024-07-29 20:49:00	4638	3	4	t	\N	2	t
4541	2024-06-02 21:01:00	3101	3	1	f	1	2	f
4542	2024-01-04 17:01:00	1887	2	1	f	\N	1	f
4543	2024-02-07 19:13:00	9613	4	3	t	1	2	f
4544	2024-01-14 02:14:00	7933	2	1	t	\N	3	t
4545	2024-02-18 07:16:00	8836	4	2	f	1	3	t
4546	2024-08-19 03:39:00	9859	2	1	f	\N	3	t
4547	2024-06-15 12:49:00	1533	1	3	f	2	2	f
4548	2024-02-11 13:07:00	9232	1	4	t	1	3	f
4549	2024-05-29 21:14:00	6689	4	2	f	1	1	f
4550	2024-02-24 08:01:00	7450	2	2	t	\N	2	f
4551	2024-06-03 03:25:00	3863	2	2	f	\N	1	t
4552	2024-08-06 04:06:00	8490	2	4	f	\N	1	f
4553	2024-05-05 07:58:00	2972	3	2	f	2	2	t
4554	2024-02-20 18:24:00	9490	4	3	f	\N	2	f
4555	2024-07-01 14:26:00	8537	5	3	t	\N	2	f
4556	2024-06-20 13:13:00	6171	3	4	t	\N	3	t
4557	2024-03-22 08:27:00	1137	3	2	t	1	3	f
4558	2024-02-19 10:45:00	1193	3	2	t	\N	2	f
4559	2024-08-10 22:25:00	4452	3	4	t	\N	2	t
4560	2024-02-10 03:53:00	7216	3	2	f	\N	1	t
4561	2024-08-12 01:15:00	2650	5	4	t	1	1	f
4562	2024-01-13 00:10:00	6331	3	2	t	\N	1	t
4563	2024-04-24 02:12:00	6924	2	3	t	\N	4	f
4564	2024-05-23 18:08:00	5254	3	3	t	1	4	f
4565	2024-06-20 03:24:00	4066	3	1	t	1	4	t
4566	2024-01-04 08:08:00	9987	2	1	t	1	2	t
4567	2024-09-09 15:56:00	5306	5	3	t	1	2	f
4568	2024-03-20 14:32:00	4885	5	3	f	1	1	t
4569	2024-07-02 18:19:00	5413	5	4	t	\N	2	t
4570	2024-04-17 12:10:00	8722	4	3	t	\N	4	f
4571	2024-01-27 02:23:00	6621	3	4	f	1	1	t
4572	2024-06-13 04:28:00	6995	3	2	f	\N	1	t
4573	2024-07-11 06:04:00	4013	1	4	t	\N	2	f
4574	2024-09-12 14:04:00	9171	3	1	f	2	4	t
4575	2024-01-22 17:44:00	7945	3	3	t	1	1	f
4576	2024-03-27 16:15:00	4449	1	1	f	2	2	t
4577	2024-02-06 05:54:00	7866	3	4	f	\N	3	f
4578	2024-08-18 01:36:00	7099	4	3	t	2	4	t
4579	2024-04-08 16:54:00	6981	3	3	f	2	2	f
4580	2024-04-25 00:53:00	7563	2	1	f	\N	3	t
4581	2024-02-13 09:49:00	5581	5	1	t	\N	4	t
4582	2024-06-28 15:13:00	8384	1	3	t	\N	1	f
4583	2024-03-21 22:08:00	3947	1	2	f	1	4	t
4584	2024-07-12 17:43:00	3148	3	3	f	2	2	t
4585	2024-05-26 08:42:00	4744	2	4	f	\N	1	f
4586	2024-01-15 15:12:00	2636	3	1	f	2	2	t
4587	2024-08-13 15:15:00	5422	4	4	t	\N	2	t
4588	2024-05-08 17:49:00	4863	2	1	t	\N	3	t
4589	2024-01-30 13:10:00	8081	1	1	f	\N	2	f
4590	2024-05-20 07:28:00	7240	5	1	t	\N	4	f
4591	2024-02-09 15:17:00	4212	3	1	f	\N	4	t
4592	2024-04-28 11:59:00	3389	5	2	f	2	1	f
4593	2024-05-25 17:06:00	3450	2	1	f	2	2	f
4594	2024-06-06 13:27:00	8749	1	1	f	\N	4	f
4595	2024-05-27 09:47:00	1159	5	2	f	\N	4	t
4596	2024-02-19 13:24:00	3893	5	3	t	\N	2	f
4597	2024-05-28 16:19:00	7906	4	2	t	\N	3	f
4598	2024-04-22 07:40:00	9185	3	4	t	\N	3	t
4599	2024-04-20 04:42:00	3203	4	3	t	1	4	f
4600	2024-03-24 08:06:00	9470	1	1	f	1	4	f
4601	2024-09-16 20:15:00	9748	2	4	t	\N	4	f
4602	2024-02-11 13:32:00	6172	3	2	f	\N	1	t
4603	2024-04-14 21:59:00	8972	4	4	t	\N	3	f
4604	2024-01-13 22:07:00	5915	3	2	t	\N	1	t
4605	2024-03-19 14:37:00	5111	2	2	t	\N	3	t
4606	2024-02-08 04:11:00	1781	1	3	f	\N	4	t
4607	2024-03-14 03:00:00	7527	1	3	t	1	3	t
4608	2024-04-14 05:55:00	2621	1	4	f	\N	3	f
4609	2024-05-24 20:12:00	3676	4	2	t	\N	2	f
4610	2024-02-05 19:42:00	1983	2	4	f	1	3	f
4611	2024-07-14 23:50:00	4530	3	1	f	\N	3	f
4612	2024-05-30 05:18:00	5166	4	1	t	\N	3	f
4613	2024-02-14 19:51:00	8807	2	2	t	\N	3	t
4614	2024-01-24 03:42:00	2577	3	3	f	\N	4	f
4615	2024-08-09 18:23:00	8370	2	3	t	\N	3	f
4616	2024-05-04 05:02:00	6483	1	3	t	\N	1	f
4617	2024-05-07 23:20:00	5256	1	2	t	\N	2	f
4618	2024-07-10 00:07:00	6914	1	1	f	\N	4	f
4619	2024-08-20 01:51:00	6903	4	3	f	\N	2	f
4620	2024-01-10 22:52:00	5222	3	4	f	1	3	f
4621	2024-02-17 00:21:00	6638	1	1	f	\N	3	t
4622	2024-03-24 00:19:00	1324	5	4	f	\N	3	f
4623	2024-03-30 21:09:00	7746	3	2	f	\N	3	t
4624	2024-06-28 16:33:00	2986	2	4	t	2	1	t
4625	2024-06-07 17:19:00	6752	5	1	f	\N	3	f
4626	2024-05-17 10:18:00	4259	5	1	f	\N	4	t
4627	2024-04-11 19:45:00	9821	4	1	f	1	1	t
4628	2024-02-08 05:45:00	3859	3	2	f	\N	2	t
4629	2024-05-02 17:06:00	5663	5	4	f	1	1	f
4630	2024-03-28 21:45:00	6818	3	2	f	1	1	f
4631	2024-06-04 13:54:00	6326	3	1	t	\N	2	f
4632	2024-08-26 03:28:00	9363	5	4	t	\N	2	f
4633	2024-03-22 10:16:00	8987	1	2	t	2	1	f
4634	2024-04-07 16:49:00	8322	2	2	f	2	3	f
4635	2024-03-11 08:05:00	2284	3	4	f	\N	4	f
4636	2024-06-08 00:59:00	7243	4	1	t	\N	3	t
4637	2024-04-05 14:09:00	5694	1	4	t	1	1	t
4638	2024-02-21 03:54:00	8598	2	4	f	1	3	f
4639	2024-04-20 06:00:00	3373	2	4	t	\N	4	t
4640	2024-03-21 23:45:00	3745	5	3	f	\N	2	t
4641	2024-01-28 00:45:00	6527	3	3	f	\N	2	f
4642	2024-09-03 02:16:00	7911	4	4	f	\N	2	t
4643	2024-07-09 11:42:00	7631	1	3	t	\N	3	t
4644	2024-03-30 22:00:00	2168	2	2	f	\N	2	t
4645	2024-06-01 09:58:00	2296	3	1	t	\N	2	f
4646	2024-05-15 01:02:00	3654	3	4	t	2	4	t
4647	2024-02-06 22:31:00	6629	2	2	t	\N	4	f
4648	2024-05-19 05:24:00	4739	5	2	f	\N	4	t
4649	2024-07-07 00:53:00	6136	5	2	f	\N	3	f
4650	2024-02-08 00:23:00	6191	1	2	t	\N	3	t
4651	2024-02-14 20:56:00	5773	5	1	f	\N	2	f
4652	2024-06-18 04:39:00	5382	2	4	f	1	1	t
4653	2024-05-23 11:26:00	7479	3	2	f	1	2	f
4654	2024-09-15 16:31:00	5444	4	3	t	\N	1	f
4655	2024-08-14 06:51:00	8289	3	1	f	2	1	f
4656	2024-04-17 08:45:00	6950	2	4	t	\N	1	f
4657	2024-02-01 07:23:00	9535	4	2	f	\N	2	f
4658	2024-08-07 08:13:00	8377	1	4	t	\N	3	t
4659	2024-02-06 10:12:00	7782	4	3	f	\N	3	f
4660	2024-01-26 07:17:00	3741	2	2	t	\N	4	f
4661	2024-02-18 16:21:00	4012	3	3	t	\N	3	f
4662	2024-06-09 21:55:00	1378	2	3	f	\N	2	f
4663	2024-07-19 14:38:00	3048	5	4	t	\N	1	t
4664	2024-04-27 05:06:00	4844	5	2	t	\N	1	f
4665	2024-08-30 23:07:00	5122	3	2	t	\N	4	t
4666	2024-02-14 21:02:00	2311	4	4	f	\N	3	t
4667	2024-05-18 00:58:00	4450	5	3	t	\N	2	t
4668	2024-07-18 11:25:00	3734	4	2	t	\N	3	t
4669	2024-07-12 20:03:00	7505	4	3	f	\N	1	t
4670	2024-02-03 11:40:00	2687	1	2	t	\N	1	f
4671	2024-02-15 14:09:00	2565	4	1	t	\N	3	f
4672	2024-02-02 21:02:00	2045	5	3	t	\N	2	f
4673	2024-09-14 18:47:00	8752	5	1	t	\N	2	t
4674	2024-05-22 07:17:00	9985	4	2	f	\N	4	f
4675	2024-05-06 16:01:00	1881	1	3	t	2	2	t
4676	2024-08-25 01:16:00	1431	4	1	t	\N	4	f
4677	2024-02-29 01:35:00	7504	2	1	f	\N	1	t
4678	2024-03-09 20:58:00	9584	4	3	t	\N	2	f
4679	2024-06-01 03:36:00	2363	3	1	t	\N	3	t
4680	2024-07-21 02:43:00	2702	1	2	t	1	4	t
4681	2024-03-05 04:32:00	5300	5	3	f	\N	1	f
4682	2024-05-25 21:37:00	3544	2	3	f	\N	1	t
4683	2024-07-26 08:42:00	2381	5	1	t	\N	3	f
4684	2024-03-23 06:37:00	7387	1	2	t	2	2	f
4685	2024-01-15 18:23:00	6068	4	4	f	\N	4	t
4686	2024-07-18 23:39:00	4757	1	2	t	\N	3	f
4687	2024-09-11 12:24:00	5053	5	3	t	\N	1	t
4688	2024-02-02 19:45:00	5655	4	1	t	\N	2	f
4689	2024-05-17 20:36:00	8260	3	2	t	\N	2	t
4690	2024-02-27 16:29:00	3071	5	4	t	2	1	t
4691	2024-06-01 04:44:00	3150	4	2	t	\N	4	t
4692	2024-05-18 13:37:00	9630	5	3	f	\N	4	t
4693	2024-03-16 15:10:00	3795	3	2	t	\N	3	t
4694	2024-05-05 06:32:00	1468	4	4	t	\N	4	t
4695	2024-07-22 08:40:00	1575	5	1	t	2	1	f
4696	2024-02-11 19:19:00	6846	3	4	f	\N	1	f
4697	2024-04-03 17:38:00	6328	1	3	t	\N	1	t
4698	2024-08-02 14:18:00	8801	5	1	t	\N	2	f
4699	2024-03-24 20:23:00	8654	5	3	t	2	2	f
4700	2024-03-03 18:49:00	9856	5	3	f	2	3	t
4701	2024-03-13 17:00:00	5463	2	1	f	\N	2	f
4702	2024-02-09 00:45:00	9987	3	2	f	2	4	t
4703	2024-01-03 01:53:00	8288	5	2	f	\N	3	t
4704	2024-04-13 07:07:00	3213	2	4	f	\N	4	f
4705	2024-02-07 12:20:00	9835	2	1	t	\N	1	t
4706	2024-04-06 01:11:00	3900	5	1	f	\N	4	f
4707	2024-07-10 16:57:00	8480	4	2	t	\N	4	t
4708	2024-03-08 17:15:00	8126	5	1	t	\N	1	t
4709	2024-08-02 17:06:00	9576	5	2	f	1	3	t
4710	2024-03-31 20:32:00	9745	3	4	f	\N	2	t
4711	2024-01-31 20:03:00	6073	5	1	f	1	1	f
4712	2024-08-15 21:24:00	6688	2	2	t	\N	1	t
4713	2024-03-17 22:02:00	8891	4	2	f	\N	4	f
4714	2024-06-15 05:20:00	9841	2	2	f	\N	2	t
4715	2024-01-23 08:27:00	4721	1	2	f	\N	1	f
4716	2024-08-06 09:58:00	2467	1	2	t	2	3	f
4717	2024-03-17 01:35:00	8239	1	4	t	\N	2	t
4718	2024-02-27 06:08:00	6044	4	3	f	1	3	f
4719	2024-07-25 11:40:00	6992	1	3	f	\N	3	t
4720	2024-05-28 10:51:00	7753	2	3	t	\N	1	f
4721	2024-06-08 17:51:00	5256	2	1	f	2	2	t
4722	2024-08-16 14:43:00	3551	5	2	t	\N	3	f
4723	2024-02-11 18:40:00	5973	2	2	f	1	3	t
4724	2024-07-24 07:07:00	1172	5	4	f	2	4	t
4725	2024-07-03 16:36:00	1001	1	4	t	\N	2	f
4726	2024-03-21 02:11:00	9574	4	1	t	2	3	f
4727	2024-06-28 05:29:00	3233	5	4	t	2	4	t
4728	2024-08-09 05:58:00	6634	3	4	t	2	1	t
4729	2024-03-10 00:55:00	5698	1	4	t	\N	2	t
4730	2024-04-09 23:44:00	8687	1	1	t	\N	1	t
4731	2024-08-30 02:01:00	9767	3	4	t	\N	2	t
4732	2024-03-23 10:25:00	1136	2	4	f	\N	3	f
4733	2024-03-13 12:39:00	9059	3	3	t	\N	2	f
4734	2024-08-05 20:17:00	8816	5	3	t	2	2	t
4735	2024-08-13 09:24:00	5908	4	2	t	2	4	f
4736	2024-07-10 09:13:00	1149	1	1	t	2	2	f
4737	2024-05-02 00:16:00	8052	4	4	t	\N	2	t
4738	2024-03-21 10:52:00	5799	4	1	t	\N	1	t
4739	2024-05-28 22:08:00	4788	1	4	t	\N	4	t
4740	2024-06-07 01:37:00	1118	1	4	t	\N	1	t
4741	2024-06-26 17:12:00	9981	4	1	f	\N	1	f
4742	2024-02-02 00:02:00	7121	1	2	t	1	1	t
4743	2024-06-03 08:50:00	4089	3	3	f	2	4	t
4744	2024-02-19 12:54:00	7745	2	2	t	2	3	f
4745	2024-08-09 19:27:00	8161	5	2	f	\N	2	f
4746	2024-06-10 11:52:00	7467	5	2	f	1	3	f
4747	2024-02-11 16:34:00	5094	5	1	f	\N	3	f
4748	2024-05-18 00:48:00	3675	3	2	f	\N	4	f
4749	2024-08-06 21:01:00	7385	5	3	t	\N	3	t
4750	2024-09-02 00:54:00	7199	3	1	t	\N	1	t
4751	2024-02-20 22:57:00	4614	3	1	f	\N	1	t
4752	2024-03-21 09:34:00	5308	2	4	f	2	2	t
4753	2024-08-04 07:29:00	2297	3	1	t	\N	3	f
4754	2024-08-27 12:13:00	7917	4	3	t	\N	4	t
4755	2024-02-18 13:53:00	4924	5	3	t	2	4	f
4756	2024-02-02 17:12:00	9464	4	2	t	\N	1	f
4757	2024-05-28 08:33:00	5454	2	2	f	\N	1	f
4758	2024-02-05 10:01:00	5664	4	1	f	2	3	t
4759	2024-07-30 05:27:00	9715	2	1	t	1	4	f
4760	2024-05-05 17:36:00	5404	2	2	f	\N	2	t
4761	2024-05-07 02:43:00	7765	1	4	t	2	1	t
4762	2024-07-30 08:36:00	4080	4	2	t	\N	3	f
4763	2024-07-12 04:04:00	2121	5	3	t	1	1	f
4764	2024-08-04 19:54:00	3988	3	4	f	\N	3	t
4765	2024-08-13 07:13:00	3238	1	3	f	\N	4	f
4766	2024-06-07 10:19:00	5744	3	3	t	\N	3	f
4767	2024-02-03 22:02:00	2808	2	4	t	\N	2	t
4768	2024-04-28 09:54:00	8460	1	4	t	\N	3	f
4769	2024-07-19 16:26:00	8418	3	4	t	\N	4	f
4770	2024-08-24 02:18:00	5458	1	3	t	1	1	t
4771	2024-03-13 09:18:00	9060	1	4	f	\N	4	f
4772	2024-08-11 12:18:00	4076	3	3	f	\N	4	t
4773	2024-03-03 23:14:00	6253	4	3	t	\N	4	f
4774	2024-01-05 10:52:00	1317	3	1	f	\N	1	f
4775	2024-05-09 00:35:00	3492	4	3	t	\N	2	t
4776	2024-04-16 09:23:00	1813	4	4	t	\N	1	f
4777	2024-07-26 06:25:00	9764	2	3	f	\N	4	t
4778	2024-04-01 13:38:00	1362	4	1	f	1	3	f
4779	2024-05-22 11:56:00	4046	1	3	t	\N	2	t
4780	2024-01-09 06:35:00	2675	1	2	f	2	1	t
4781	2024-08-02 05:18:00	5622	2	3	t	\N	4	t
4782	2024-04-15 20:40:00	5410	1	2	t	\N	1	t
4783	2024-02-15 23:24:00	3048	2	3	f	2	1	f
4784	2024-02-20 12:07:00	8183	5	3	f	\N	2	f
4785	2024-02-14 10:30:00	1134	3	2	f	1	4	t
4786	2024-08-26 15:34:00	4814	3	3	t	\N	1	f
4787	2024-09-12 08:20:00	2477	4	1	f	\N	4	f
4788	2024-08-07 09:48:00	3468	4	3	t	\N	3	f
4789	2024-06-17 18:03:00	1241	1	1	t	\N	4	f
4790	2024-04-30 00:25:00	9086	4	1	t	\N	1	f
4791	2024-02-28 13:03:00	4558	1	3	t	2	4	f
4792	2024-02-17 11:16:00	6601	1	3	f	2	2	f
4793	2024-03-14 17:47:00	7885	2	3	t	\N	3	f
4794	2024-05-18 08:49:00	6104	4	4	f	\N	1	t
4795	2024-06-09 06:15:00	9165	4	3	t	\N	2	t
4796	2024-03-24 23:01:00	7084	4	1	f	\N	4	f
4797	2024-02-23 21:10:00	8597	5	3	t	1	1	f
4798	2024-02-29 08:57:00	1519	4	4	f	2	2	t
4799	2024-03-15 17:53:00	6410	3	3	f	\N	3	f
4800	2024-03-25 18:02:00	2314	5	2	t	\N	3	f
4801	2024-05-22 14:25:00	3393	5	3	t	\N	2	t
4802	2024-04-19 19:09:00	1918	3	2	t	2	4	f
4803	2024-01-17 22:33:00	5366	1	3	t	1	2	t
4804	2024-01-24 01:47:00	7429	2	3	f	\N	2	f
4805	2024-05-31 01:50:00	2169	1	2	f	\N	3	t
4806	2024-07-15 01:02:00	9899	3	2	t	2	2	f
4807	2024-08-24 11:11:00	8702	1	1	t	2	2	t
4808	2024-04-22 00:55:00	3975	5	2	t	2	3	t
4809	2024-09-06 06:21:00	4148	3	2	f	\N	3	f
4810	2024-02-01 19:43:00	5097	5	4	t	\N	1	t
4811	2024-03-19 03:28:00	7251	3	1	f	\N	3	t
4812	2024-05-10 12:10:00	1206	2	2	t	\N	1	f
4813	2024-08-09 02:21:00	2998	1	4	t	\N	1	f
4814	2024-07-12 12:39:00	5078	5	3	f	\N	2	f
4815	2024-04-19 10:50:00	7304	2	1	t	\N	1	f
4816	2024-06-12 08:06:00	8257	3	3	t	\N	4	f
4817	2024-07-18 16:38:00	5049	4	4	f	\N	3	f
4818	2024-05-20 09:43:00	1549	5	4	f	2	1	f
4819	2024-07-19 17:07:00	4263	2	4	t	\N	4	f
4820	2024-04-11 06:54:00	8550	1	2	t	\N	3	t
4821	2024-05-07 23:18:00	2539	3	2	t	2	2	f
4822	2024-08-20 07:26:00	9538	1	3	t	\N	1	f
4823	2024-06-16 13:43:00	4415	4	2	f	\N	4	t
4824	2024-08-12 01:35:00	8746	1	1	f	\N	3	t
4825	2024-09-15 12:48:00	7375	4	1	f	\N	1	t
4826	2024-05-20 08:14:00	6113	4	4	f	2	1	f
4827	2024-07-30 02:26:00	6293	5	4	t	\N	2	f
4828	2024-08-15 18:13:00	3598	1	1	t	\N	2	f
4829	2024-07-03 18:21:00	1691	4	1	t	2	4	t
4830	2024-02-25 04:23:00	9534	2	1	f	2	1	f
4831	2024-01-09 12:28:00	3001	3	4	t	\N	2	f
4832	2024-04-18 13:59:00	5150	3	4	t	\N	2	f
4833	2024-05-09 07:35:00	8884	4	2	t	\N	3	f
4834	2024-04-25 11:51:00	5895	4	1	t	\N	2	t
4835	2024-03-09 06:11:00	4255	5	2	f	\N	3	f
4836	2024-04-14 10:09:00	6905	4	4	f	2	3	t
4837	2024-01-19 19:15:00	1853	3	4	t	\N	1	f
4838	2024-06-28 23:18:00	4568	5	3	f	2	2	f
4839	2024-03-23 11:04:00	2850	2	2	t	1	1	f
4840	2024-07-20 03:50:00	4866	5	3	f	1	4	t
4841	2024-06-06 10:52:00	8113	5	1	t	\N	2	t
4842	2024-04-27 13:25:00	6316	5	3	f	\N	1	t
4843	2024-08-31 08:48:00	1246	1	4	t	1	2	t
4844	2024-08-02 13:13:00	3742	3	1	t	1	4	t
4845	2024-07-13 18:00:00	5523	2	4	t	\N	3	f
4846	2024-04-29 14:30:00	2960	4	2	f	\N	1	f
4847	2024-03-13 06:33:00	7484	2	1	f	\N	3	t
4848	2024-08-07 13:09:00	4982	2	3	f	\N	1	t
4849	2024-04-10 02:49:00	1146	4	4	f	\N	4	f
4850	2024-02-13 15:31:00	1688	3	2	f	\N	1	f
4851	2024-02-11 09:20:00	8786	3	2	f	1	1	t
4852	2024-04-20 00:17:00	3539	5	3	t	\N	3	f
4853	2024-05-19 07:23:00	7084	1	3	t	2	1	t
4854	2024-06-15 13:59:00	2466	5	1	t	\N	4	f
4855	2024-07-21 20:37:00	5075	2	3	t	\N	2	t
4856	2024-07-03 17:21:00	3583	3	1	t	1	4	f
4857	2024-02-03 06:11:00	9190	3	1	t	\N	4	f
4858	2024-01-15 06:41:00	2497	1	2	t	\N	2	f
4859	2024-08-10 00:24:00	6544	3	3	t	\N	4	t
4860	2024-06-23 02:05:00	1983	5	4	f	1	1	f
4861	2024-02-19 05:26:00	1979	1	4	f	1	4	t
4862	2024-05-15 01:50:00	6824	3	4	t	\N	3	f
4863	2024-07-11 02:50:00	3521	1	2	f	\N	4	t
4864	2024-08-24 00:25:00	9787	2	1	f	\N	1	t
4865	2024-06-08 02:10:00	2759	3	1	t	2	3	t
4866	2024-01-20 20:45:00	3061	4	3	t	\N	3	f
4867	2024-04-11 03:38:00	8992	3	1	f	\N	1	f
4868	2024-06-06 06:03:00	4812	2	1	f	\N	3	t
4869	2024-04-17 23:25:00	6189	3	2	f	\N	1	f
4870	2024-01-07 20:05:00	6690	2	4	t	1	1	f
4871	2024-01-01 08:37:00	8187	3	2	f	\N	3	f
4872	2024-08-02 01:14:00	4161	2	4	t	\N	1	t
4873	2024-06-23 14:27:00	1349	4	3	f	\N	1	f
4874	2024-03-03 07:49:00	7189	4	4	t	\N	2	f
4875	2024-01-24 01:03:00	6868	1	1	f	1	2	t
4876	2024-07-13 07:14:00	3207	3	1	t	\N	2	t
4877	2024-03-24 03:30:00	5107	5	1	t	\N	2	t
4878	2024-08-25 03:22:00	1646	4	1	t	1	1	f
4879	2024-02-07 00:31:00	8951	4	1	t	\N	2	f
4880	2024-01-31 07:02:00	8168	3	3	t	2	2	t
4881	2024-02-27 21:01:00	5828	3	4	t	\N	2	t
4882	2024-07-22 06:40:00	9892	4	4	f	\N	4	t
4883	2024-01-19 03:45:00	9029	2	2	f	2	3	t
4884	2024-09-03 01:25:00	4109	4	1	f	\N	4	f
4885	2024-01-18 19:21:00	4057	3	1	f	\N	2	f
4886	2024-09-05 08:33:00	9906	1	1	t	\N	2	f
4887	2024-03-27 21:23:00	6696	3	3	t	\N	4	f
4888	2024-06-27 14:39:00	6303	2	3	f	\N	4	f
4889	2024-04-23 21:38:00	8674	3	3	t	\N	4	f
4890	2024-05-11 02:32:00	5510	5	4	t	2	2	f
4891	2024-08-10 07:44:00	3627	2	2	f	\N	2	f
4892	2024-09-10 08:38:00	2128	2	2	f	1	4	f
4893	2024-06-28 15:55:00	9702	3	1	f	1	3	t
4894	2024-02-09 16:53:00	3539	1	2	t	2	1	f
4895	2024-09-15 22:47:00	8362	3	3	t	1	2	f
4896	2024-05-25 16:40:00	5844	4	1	f	\N	2	f
4897	2024-08-23 10:19:00	5314	4	1	t	\N	2	f
4898	2024-09-03 15:51:00	9873	1	3	f	2	3	t
4899	2024-08-07 14:40:00	7014	5	4	f	\N	1	f
4900	2024-09-15 03:32:00	8439	5	4	f	\N	2	t
4901	2024-02-22 08:46:00	1011	4	4	f	\N	1	f
4902	2024-06-27 11:31:00	9289	3	4	f	\N	2	f
4903	2024-06-13 01:49:00	7210	2	3	f	\N	1	t
4904	2024-01-16 10:27:00	4039	2	3	f	1	3	t
4905	2024-04-09 23:45:00	1306	4	4	f	\N	1	f
4906	2024-03-07 10:11:00	6965	1	1	t	\N	4	f
4907	2024-01-10 15:55:00	4912	2	3	t	\N	3	f
4908	2024-07-04 10:16:00	6254	1	1	f	\N	2	t
4909	2024-01-31 21:39:00	2037	3	1	f	\N	3	f
4910	2024-07-13 05:45:00	9830	1	1	f	1	2	f
4911	2024-02-27 13:14:00	7348	4	3	f	\N	1	t
4912	2024-03-14 18:23:00	4110	3	3	t	\N	3	f
4913	2024-02-20 20:05:00	9586	2	2	t	1	3	t
4914	2024-04-24 13:34:00	9151	2	4	f	\N	1	f
4915	2024-02-28 05:11:00	3525	1	1	t	\N	3	f
4916	2024-02-14 12:27:00	5638	4	4	t	\N	2	t
4917	2024-09-09 10:31:00	6285	4	2	f	\N	3	f
4918	2024-06-04 03:40:00	7714	3	1	t	\N	1	f
4919	2024-03-29 15:13:00	6276	1	3	f	1	4	t
4920	2024-08-16 14:34:00	2809	1	2	t	\N	2	f
4921	2024-09-16 07:48:00	2577	1	1	t	\N	1	f
4922	2024-07-15 09:25:00	9572	5	1	t	2	4	t
4923	2024-08-21 16:27:00	2092	2	2	t	\N	4	t
4924	2024-03-02 00:55:00	1717	5	4	f	2	3	f
4925	2024-06-25 00:56:00	3126	2	3	f	2	1	t
4926	2024-05-08 06:24:00	3926	1	1	t	\N	2	t
4927	2024-04-30 10:16:00	1512	3	2	t	\N	4	f
4928	2024-04-16 22:30:00	4310	3	1	t	1	4	f
4929	2024-03-19 03:10:00	2753	5	1	t	\N	2	t
4930	2024-07-17 17:51:00	8952	4	4	f	\N	1	f
4931	2024-06-19 07:41:00	4139	5	1	f	\N	2	t
4932	2024-02-17 06:44:00	2617	5	4	f	\N	4	f
4933	2024-02-03 22:32:00	1521	1	2	f	\N	3	f
4934	2024-03-08 01:24:00	7366	3	3	f	2	4	t
4935	2024-01-31 06:23:00	9026	5	3	t	\N	3	f
4936	2024-04-01 11:51:00	9615	3	4	t	\N	3	f
4937	2024-07-08 16:45:00	5193	1	1	f	\N	4	t
4938	2024-01-18 09:21:00	1804	5	4	f	\N	4	f
4939	2024-06-26 16:46:00	7002	2	4	f	\N	1	t
4940	2024-07-20 03:58:00	4616	3	4	t	2	4	f
4941	2024-04-28 16:20:00	2161	2	2	t	\N	1	t
4942	2024-01-22 15:42:00	1214	4	1	f	\N	1	f
4943	2024-01-16 23:00:00	4419	1	4	t	\N	3	f
4944	2024-04-09 01:45:00	9051	3	4	t	\N	3	t
4945	2024-02-25 04:27:00	2310	4	3	t	1	2	t
4946	2024-04-25 20:33:00	8668	3	1	f	\N	2	f
4947	2024-06-03 23:12:00	1994	2	1	f	\N	4	t
4948	2024-05-21 22:07:00	6913	1	4	f	\N	1	f
4949	2024-01-25 20:39:00	7814	3	2	t	\N	3	f
4950	2024-04-30 09:17:00	7046	5	3	t	\N	3	f
4951	2024-03-14 00:40:00	1955	2	3	t	\N	1	f
4952	2024-05-03 05:24:00	5355	1	2	t	1	4	f
4953	2024-06-09 18:19:00	9667	4	3	t	1	4	t
4954	2024-02-07 21:08:00	1666	4	3	t	\N	4	f
4955	2024-08-08 20:56:00	2153	2	3	t	\N	4	f
4956	2024-05-08 22:38:00	5979	3	4	t	\N	1	f
4957	2024-03-15 00:21:00	2276	2	4	t	\N	2	t
4958	2024-03-15 01:14:00	4537	1	2	t	\N	2	f
4959	2024-03-23 21:38:00	9511	3	1	f	\N	4	f
4960	2024-05-14 01:04:00	2591	4	2	f	2	2	t
4961	2024-05-26 09:21:00	2658	5	4	f	\N	4	t
4962	2024-08-21 01:09:00	4784	3	2	t	\N	2	t
4963	2024-03-10 08:39:00	9710	2	3	t	1	1	t
4964	2024-05-02 20:01:00	7313	4	3	t	\N	3	t
4965	2024-09-11 23:15:00	4104	2	4	t	\N	4	t
4966	2024-03-23 06:42:00	4164	5	1	f	\N	2	t
4967	2024-06-08 20:30:00	9621	3	4	t	\N	1	t
4968	2024-09-15 03:42:00	5075	5	2	f	2	3	t
4969	2024-08-09 15:19:00	3931	1	4	t	\N	3	f
4970	2024-08-05 03:41:00	7802	3	3	f	\N	4	t
4971	2024-09-03 19:18:00	2728	2	1	f	\N	1	f
4972	2024-01-11 22:13:00	6864	5	1	t	2	2	t
4973	2024-05-17 15:26:00	8515	4	3	t	\N	4	t
4974	2024-03-03 22:31:00	7997	2	1	t	1	3	t
4975	2024-03-18 13:43:00	2705	2	1	t	\N	1	t
4976	2024-07-18 18:22:00	3733	3	2	t	\N	1	t
4977	2024-03-29 14:06:00	3955	4	4	t	\N	3	t
4978	2024-05-27 06:40:00	7579	5	1	t	\N	2	f
4979	2024-07-22 17:51:00	9268	5	2	t	\N	1	f
4980	2024-04-22 01:39:00	6529	1	4	t	\N	3	f
4981	2024-06-02 14:33:00	3591	1	3	f	\N	2	f
4982	2024-08-05 17:31:00	9747	4	4	f	\N	1	f
4983	2024-03-04 17:43:00	8258	1	3	t	\N	4	t
4984	2024-07-04 03:18:00	6772	4	4	t	\N	3	t
4985	2024-07-08 11:39:00	6163	2	4	f	\N	1	t
4986	2024-03-17 17:21:00	6319	4	1	t	\N	2	t
4987	2024-04-07 18:57:00	7090	2	1	f	\N	4	t
4988	2024-08-21 19:16:00	7755	1	3	f	1	2	t
4989	2024-01-23 06:07:00	8054	2	2	t	1	1	f
4990	2024-06-17 15:06:00	6299	4	4	t	\N	2	t
4991	2024-06-06 05:18:00	4943	3	2	f	\N	2	f
4992	2024-05-26 00:54:00	9939	1	2	t	1	2	t
4993	2024-07-24 03:36:00	4504	2	4	t	\N	4	t
4994	2024-04-02 04:25:00	7145	2	3	t	\N	2	f
4995	2024-06-28 22:53:00	5162	1	3	t	\N	3	f
4996	2024-07-08 06:13:00	6898	5	2	f	\N	3	t
4997	2024-02-07 11:30:00	8412	3	3	t	\N	3	t
4998	2024-08-20 00:38:00	8331	5	3	t	\N	4	t
4999	2024-08-26 11:05:00	7505	1	4	t	\N	1	f
5000	2024-02-09 01:27:00	1003	5	4	t	2	1	f
5001	2025-04-27 11:10:12.777865	1001	5	1	f	\N	1	f
5002	2025-04-27 11:15:47.549785	1001	5	1	t	2	1	f
5004	2025-04-27 11:35:44.253485	1001	1	1	f	\N	1	f
5005	2025-04-30 15:56:46.094802	1001	5	1	t	2	1	f
5006	2025-04-30 15:58:29.774908	1001	5	1	t	2	1	f
5007	2025-04-30 15:59:27.478616	1001	5	1	t	2	1	f
\.


--
-- Data for Name: weather; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.weather (weather_id, weather_conditions) FROM stdin;
1	Stormy
2	Rainy
3	Sunny
4	Cloudy
\.


--
-- Name: categories_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categories_category_id_seq', 1, false);


--
-- Name: paymentmethods_method_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.paymentmethods_method_id_seq', 1, false);


--
-- Name: promotions_promotion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.promotions_promotion_id_seq', 1, false);


--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transactions_transaction_id_seq', 5007, true);


--
-- Name: weather_weather_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.weather_weather_id_seq', 1, false);


--
-- Name: categories categories_category_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_category_name_key UNIQUE (category_name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (category_id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);


--
-- Name: demandforecast demandforecast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandforecast
    ADD CONSTRAINT demandforecast_pkey PRIMARY KEY (forecast_date, store_id, product_id);


--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (store_id, product_id);


--
-- Name: paymentmethods paymentmethods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paymentmethods
    ADD CONSTRAINT paymentmethods_pkey PRIMARY KEY (method_id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: promotionapplications promotionapplications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.promotionapplications
    ADD CONSTRAINT promotionapplications_pkey PRIMARY KEY (transaction_id, promotion_id);


--
-- Name: promotions promotions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.promotions
    ADD CONSTRAINT promotions_pkey PRIMARY KEY (promotion_id);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (store_id);


--
-- Name: transactiondetails transactiondetails_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactiondetails
    ADD CONSTRAINT transactiondetails_pkey PRIMARY KEY (transaction_id, product_id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (transaction_id);


--
-- Name: weather weather_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.weather
    ADD CONSTRAINT weather_pkey PRIMARY KEY (weather_id);


--
-- Name: idx_demandforecast_store_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_demandforecast_store_id ON public.demandforecast USING btree (store_id);


--
-- Name: idx_inventory_store_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_inventory_store_id ON public.inventory USING btree (store_id);


--
-- Name: idx_transactions_store_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_store_id ON public.transactions USING btree (store_id);


--
-- Name: transactiondetails trg_update_inventory_after_detail; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_inventory_after_detail AFTER INSERT ON public.transactiondetails FOR EACH ROW EXECUTE FUNCTION public.update_inventory_after_detail();


--
-- Name: demandforecast demandforecast_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandforecast
    ADD CONSTRAINT demandforecast_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


--
-- Name: demandforecast demandforecast_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandforecast
    ADD CONSTRAINT demandforecast_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id);


--
-- Name: inventory inventory_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


--
-- Name: inventory inventory_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id);


--
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(category_id);


--
-- Name: promotionapplications promotionapplications_promotion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.promotionapplications
    ADD CONSTRAINT promotionapplications_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(promotion_id);


--
-- Name: promotionapplications promotionapplications_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.promotionapplications
    ADD CONSTRAINT promotionapplications_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(transaction_id);


--
-- Name: transactiondetails transactiondetails_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactiondetails
    ADD CONSTRAINT transactiondetails_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


--
-- Name: transactiondetails transactiondetails_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactiondetails
    ADD CONSTRAINT transactiondetails_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(transaction_id);


--
-- Name: transactions transactions_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id);


--
-- Name: transactions transactions_payment_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES public.paymentmethods(method_id);


--
-- Name: transactions transactions_promotion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(promotion_id);


--
-- Name: transactions transactions_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id);


--
-- Name: transactions transactions_weather_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_weather_id_fkey FOREIGN KEY (weather_id) REFERENCES public.weather(weather_id);


--
-- Name: demandforecast; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.demandforecast ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;

--
-- Name: demandforecast rls_forecast_1; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY rls_forecast_1 ON public.demandforecast TO store_user_1 USING ((store_id = 1)) WITH CHECK ((store_id = 1));


--
-- Name: demandforecast rls_forecast_2; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY rls_forecast_2 ON public.demandforecast TO store_user_2 USING ((store_id = 2)) WITH CHECK ((store_id = 2));


--
-- Name: inventory rls_inventory_1; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY rls_inventory_1 ON public.inventory TO store_user_1 USING ((store_id = 1)) WITH CHECK ((store_id = 1));


--
-- Name: inventory rls_inventory_2; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY rls_inventory_2 ON public.inventory TO store_user_2 USING ((store_id = 2)) WITH CHECK ((store_id = 2));


--
-- Name: transactions rls_transactions_1; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY rls_transactions_1 ON public.transactions TO store_user_1 USING ((store_id = 1)) WITH CHECK ((store_id = 1));


--
-- Name: transactions rls_transactions_2; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY rls_transactions_2 ON public.transactions TO store_user_2 USING ((store_id = 2)) WITH CHECK ((store_id = 2));


--
-- Name: transactions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: walmart_publication; Type: PUBLICATION; Schema: -; Owner: postgres
--

CREATE PUBLICATION walmart_publication FOR ALL TABLES WITH (publish = 'insert, update, delete, truncate');


ALTER PUBLICATION walmart_publication OWNER TO postgres;

--
-- Name: walmartp; Type: PUBLICATION; Schema: -; Owner: postgres
--

CREATE PUBLICATION walmartp WITH (publish = 'insert, update, delete, truncate');


ALTER PUBLICATION walmartp OWNER TO postgres;

--
-- Name: TABLE demandforecast; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.demandforecast TO store_user_1;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.demandforecast TO store_user_2;


--
-- Name: TABLE inventory; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.inventory TO store_user_1;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.inventory TO store_user_2;


--
-- Name: TABLE transactions; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.transactions TO store_user_1;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.transactions TO store_user_2;


--
-- PostgreSQL database dump complete
--

