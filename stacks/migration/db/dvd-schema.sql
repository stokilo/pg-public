--
-- PostgreSQL database dump
--

-- Dumped from database version 13.4
-- Dumped by pg_dump version 14.4

-- Started on 2022-09-06 20:21:07 +04

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 3 (class 2615 OID 2200)
-- Name: app_public. Type: SCHEMA; Schema: -; Owner: -
--



--
-- TOC entry 681 (class 1247 OID 40972)
-- Name: mpaa_rating; Type: TYPE; Schema: app_public. Owner: -
--

CREATE TYPE app_public.mpaa_rating AS ENUM (
    'G',
    'PG',
    'PG-13',
    'R',
    'NC-17'
);


--
-- TOC entry 684 (class 1247 OID 40984)
-- Name: year; Type: DOMAIN; Schema: app_public. Owner: -
--

CREATE DOMAIN app_public.year AS integer
	CONSTRAINT year_check CHECK (((VALUE >= 1901) AND (VALUE <= 2155)));


--
-- TOC entry 241 (class 1255 OID 40986)
-- Name: _group_concat(text, text); Type: FUNCTION; Schema: app_public. Owner: -
--

CREATE FUNCTION app_public._group_concat(text, text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT CASE
  WHEN $2 IS NULL THEN $1
  WHEN $1 IS NULL THEN $2
  ELSE $1 || ', ' || $2
END
$_$;


--
-- TOC entry 242 (class 1255 OID 40987)
-- Name: film_in_stock(integer, integer); Type: FUNCTION; Schema: app_public. Owner: -
--

CREATE FUNCTION app_public.film_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
     SELECT inventory_id
     FROM inventory
     WHERE film_id = $1
     AND store_id = $2
     AND inventory_in_stock(inventory_id);
$_$;


--
-- TOC entry 243 (class 1255 OID 40988)
-- Name: film_not_in_stock(integer, integer); Type: FUNCTION; Schema: app_public. Owner: -
--

CREATE FUNCTION app_public.film_not_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
    SELECT inventory_id
    FROM inventory
    WHERE film_id = $1
    AND store_id = $2
    AND NOT inventory_in_stock(inventory_id);
$_$;


--
-- TOC entry 256 (class 1255 OID 40989)
-- Name: get_customer_balance(integer, timestamp without time zone); Type: FUNCTION; Schema: app_public. Owner: -
--

CREATE FUNCTION app_public.get_customer_balance(p_customer_id integer, p_effective_date timestamp without time zone) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
       --#OK, WE NEED TO CALCULATE THE CURRENT BALANCE GIVEN A CUSTOMER_ID AND A DATE
       --#THAT WE WANT THE BALANCE TO BE EFFECTIVE FOR. THE BALANCE IS:
       --#   1) RENTAL FEES FOR ALL PREVIOUS RENTALS
       --#   2) ONE DOLLAR FOR EVERY DAY THE PREVIOUS RENTALS ARE OVERDUE
       --#   3) IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST
       --#   4) SUBTRACT ALL PAYMENTS MADE BEFORE THE DATE SPECIFIED
DECLARE
    v_rentfees DECIMAL(5,2); --#FEES PAID TO RENT THE VIDEOS INITIALLY
    v_overfees INTEGER;      --#LATE FEES FOR PRIOR RENTALS
    v_payments DECIMAL(5,2); --#SUM OF PAYMENTS MADE PREVIOUSLY
BEGIN
    SELECT COALESCE(SUM(film.rental_rate),0) INTO v_rentfees
    FROM film, inventory, rental
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(IF((rental.return_date - rental.rental_date) > (film.rental_duration * '1 day'::interval),
        ((rental.return_date - rental.rental_date) - (film.rental_duration * '1 day'::interval)),0)),0) INTO v_overfees
    FROM rental, inventory, film
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(payment.amount),0) INTO v_payments
    FROM payment
    WHERE payment.payment_date <= p_effective_date
    AND payment.customer_id = p_customer_id;

    RETURN v_rentfees + v_overfees - v_payments;
END
$$;


--
-- TOC entry 257 (class 1255 OID 40990)
-- Name: inventory_held_by_customer(integer); Type: FUNCTION; Schema: app_public. Owner: -
--

CREATE FUNCTION app_public.inventory_held_by_customer(p_inventory_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_customer_id INTEGER;
BEGIN

  SELECT customer_id INTO v_customer_id
  FROM rental
  WHERE return_date IS NULL
  AND inventory_id = p_inventory_id;

  RETURN v_customer_id;
END $$;


--
-- TOC entry 258 (class 1255 OID 40991)
-- Name: inventory_in_stock(integer); Type: FUNCTION; Schema: app_public. Owner: -
--

CREATE FUNCTION app_public.inventory_in_stock(p_inventory_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rentals INTEGER;
    v_out     INTEGER;
BEGIN
    -- AN ITEM IS IN-STOCK IF THERE ARE EITHER NO ROWS IN THE rental TABLE
    -- FOR THE ITEM OR ALL ROWS HAVE return_date POPULATED

    SELECT count(*) INTO v_rentals
    FROM rental
    WHERE inventory_id = p_inventory_id;

    IF v_rentals = 0 THEN
      RETURN TRUE;
    END IF;

    SELECT COUNT(rental_id) INTO v_out
    FROM inventory LEFT JOIN rental USING(inventory_id)
    WHERE inventory.inventory_id = p_inventory_id
    AND rental.return_date IS NULL;

    IF v_out > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
END $$;


--
-- TOC entry 259 (class 1255 OID 40992)
-- Name: last_day(timestamp without time zone); Type: FUNCTION; Schema: app_public. Owner: -
--

CREATE FUNCTION app_public.last_day(timestamp without time zone) RETURNS date
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
  SELECT CASE
    WHEN EXTRACT(MONTH FROM $1) = 12 THEN
      (((EXTRACT(YEAR FROM $1) + 1) operator(pg_catalog.||) '-01-01')::date - INTERVAL '1 day')::date
    ELSE
      ((EXTRACT(YEAR FROM $1) operator(pg_catalog.||) '-' operator(pg_catalog.||) (EXTRACT(MONTH FROM $1) + 1) operator(pg_catalog.||) '-01')::date - INTERVAL '1 day')::date
    END
$_$;


--
-- TOC entry 260 (class 1255 OID 40993)
-- Name: last_updated(); Type: FUNCTION; Schema: app_public. Owner: -
--

CREATE FUNCTION app_public.last_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.last_update = CURRENT_TIMESTAMP;
    RETURN NEW;
END $$;


--
-- TOC entry 202 (class 1259 OID 40994)
-- Name: customer_customer_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.customer_customer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


SET default_table_access_method = heap;

--
-- TOC entry 203 (class 1259 OID 40996)
-- Name: customer; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.customer (
    customer_id integer DEFAULT nextval('app_public.customer_customer_id_seq'::regclass) NOT NULL,
    store_id smallint NOT NULL,
    first_name character varying(45) NOT NULL,
    last_name character varying(45) NOT NULL,
    email character varying(50),
    address_id smallint NOT NULL,
    activebool boolean DEFAULT true NOT NULL,
    create_date date DEFAULT ('now'::text)::date NOT NULL,
    last_update timestamp without time zone DEFAULT now(),
    active integer
);


--
-- TOC entry 261 (class 1255 OID 41003)
-- Name: rewards_report(integer, numeric); Type: FUNCTION; Schema: app_public. Owner: -
--

CREATE FUNCTION app_public.rewards_report(min_monthly_purchases integer, min_dollar_amount_purchased numeric) RETURNS SETOF app_public.customer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
    last_month_start DATE;
    last_month_end DATE;
rr RECORD;
tmpSQL TEXT;
BEGIN

    /* Some sanity checks... */
    IF min_monthly_purchases = 0 THEN
        RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        RAISE EXCEPTION 'Minimum monthly dollar amount purchased parameter must be > $0.00';
    END IF;

    last_month_start := CURRENT_DATE - '3 month'::interval;
    last_month_start := to_date((extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'),'YYYY-MM-DD');
    last_month_end := LAST_DAY(last_month_start);

    /*
    Create a temporary storage area for Customer IDs.
    */
    CREATE TEMPORARY TABLE tmpCustomer (customer_id INTEGER NOT NULL PRIMARY KEY);

    /*
    Find all customers meeting the monthly purchase requirements
    */

    tmpSQL := 'INSERT INTO tmpCustomer (customer_id)
        SELECT p.customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN '||quote_literal(last_month_start) ||' AND '|| quote_literal(last_month_end) || '
        GROUP BY customer_id
        HAVING SUM(p.amount) > '|| min_dollar_amount_purchased || '
        AND COUNT(customer_id) > ' ||min_monthly_purchases ;

    EXECUTE tmpSQL;

    /*
    Output ALL customer information of matching rewardees.
    Customize output as needed.
    */
    FOR rr IN EXECUTE 'SELECT c.* FROM tmpCustomer AS t INNER JOIN customer AS c ON t.customer_id = c.customer_id' LOOP
        RETURN NEXT rr;
    END LOOP;

    /* Clean up */
    tmpSQL := 'DROP TABLE tmpCustomer';
    EXECUTE tmpSQL;

RETURN;
END
$_$;


--
-- TOC entry 770 (class 1255 OID 41004)
-- Name: group_concat(text); Type: AGGREGATE; Schema: app_public. Owner: -
--

CREATE AGGREGATE app_public.group_concat(text) (
    SFUNC = app_public._group_concat,
    STYPE = text
);


--
-- TOC entry 204 (class 1259 OID 41005)
-- Name: actor_actor_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.actor_actor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 205 (class 1259 OID 41007)
-- Name: actor; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.actor (
    actor_id integer DEFAULT nextval('app_public.actor_actor_id_seq'::regclass) NOT NULL,
    first_name character varying(45) NOT NULL,
    last_name character varying(45) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 206 (class 1259 OID 41012)
-- Name: category_category_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.category_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 207 (class 1259 OID 41014)
-- Name: category; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.category (
    category_id integer DEFAULT nextval('app_public.category_category_id_seq'::regclass) NOT NULL,
    name character varying(25) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 208 (class 1259 OID 41019)
-- Name: film_film_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.film_film_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 209 (class 1259 OID 41021)
-- Name: film; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.film (
    film_id integer DEFAULT nextval('app_public.film_film_id_seq'::regclass) NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    release_year app_public.year,
    language_id smallint NOT NULL,
    rental_duration smallint DEFAULT 3 NOT NULL,
    rental_rate numeric(4,2) DEFAULT 4.99 NOT NULL,
    length smallint,
    replacement_cost numeric(5,2) DEFAULT 19.99 NOT NULL,
    rating app_public.mpaa_rating DEFAULT 'G'::app_public.mpaa_rating,
    last_update timestamp without time zone DEFAULT now() NOT NULL,
    special_features text[],
    fulltext tsvector NOT NULL
);


--
-- TOC entry 210 (class 1259 OID 41033)
-- Name: film_actor; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.film_actor (
    actor_id smallint NOT NULL,
    film_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 211 (class 1259 OID 41037)
-- Name: film_category; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.film_category (
    film_id smallint NOT NULL,
    category_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 212 (class 1259 OID 41041)
-- Name: actor_info; Type: VIEW; Schema: app_public. Owner: -
--

CREATE VIEW app_public.actor_info AS
 SELECT a.actor_id,
    a.first_name,
    a.last_name,
    app_public.group_concat(DISTINCT (((c.name)::text || ': '::text) || ( SELECT app_public.group_concat((f.title)::text) AS group_concat
           FROM ((app_public.film f
             JOIN app_public.film_category fc_1 ON ((f.film_id = fc_1.film_id)))
             JOIN app_public.film_actor fa_1 ON ((f.film_id = fa_1.film_id)))
          WHERE ((fc_1.category_id = c.category_id) AND (fa_1.actor_id = a.actor_id))
          GROUP BY fa_1.actor_id))) AS film_info
   FROM (((app_public.actor a
     LEFT JOIN app_public.film_actor fa ON ((a.actor_id = fa.actor_id)))
     LEFT JOIN app_public.film_category fc ON ((fa.film_id = fc.film_id)))
     LEFT JOIN app_public.category c ON ((fc.category_id = c.category_id)))
  GROUP BY a.actor_id, a.first_name, a.last_name;


--
-- TOC entry 213 (class 1259 OID 41046)
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.address_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 214 (class 1259 OID 41048)
-- Name: address; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.address (
    address_id integer DEFAULT nextval('app_public.address_address_id_seq'::regclass) NOT NULL,
    address character varying(50) NOT NULL,
    address2 character varying(50),
    district character varying(20) NOT NULL,
    city_id smallint NOT NULL,
    postal_code character varying(10),
    phone character varying(20) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 215 (class 1259 OID 41053)
-- Name: city_city_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.city_city_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 216 (class 1259 OID 41055)
-- Name: city; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.city (
    city_id integer DEFAULT nextval('app_public.city_city_id_seq'::regclass) NOT NULL,
    city character varying(50) NOT NULL,
    country_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 217 (class 1259 OID 41060)
-- Name: country_country_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.country_country_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 218 (class 1259 OID 41062)
-- Name: country; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.country (
    country_id integer DEFAULT nextval('app_public.country_country_id_seq'::regclass) NOT NULL,
    country character varying(50) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 219 (class 1259 OID 41067)
-- Name: customer_list; Type: VIEW; Schema: app_public. Owner: -
--

CREATE VIEW app_public.customer_list AS
 SELECT cu.customer_id AS id,
    (((cu.first_name)::text || ' '::text) || (cu.last_name)::text) AS name,
    a.address,
    a.postal_code AS "zip code",
    a.phone,
    city.city,
    country.country,
        CASE
            WHEN cu.activebool THEN 'active'::text
            ELSE ''::text
        END AS notes,
    cu.store_id AS sid
   FROM (((app_public.customer cu
     JOIN app_public.address a ON ((cu.address_id = a.address_id)))
     JOIN app_public.city ON ((a.city_id = city.city_id)))
     JOIN app_public.country ON ((city.country_id = country.country_id)));


--
-- TOC entry 220 (class 1259 OID 41072)
-- Name: film_list; Type: VIEW; Schema: app_public. Owner: -
--

CREATE VIEW app_public.film_list AS
 SELECT film.film_id AS fid,
    film.title,
    film.description,
    category.name AS category,
    film.rental_rate AS price,
    film.length,
    film.rating,
    app_public.group_concat((((actor.first_name)::text || ' '::text) || (actor.last_name)::text)) AS actors
   FROM ((((app_public.category
     LEFT JOIN app_public.film_category ON ((category.category_id = film_category.category_id)))
     LEFT JOIN app_public.film ON ((film_category.film_id = film.film_id)))
     JOIN app_public.film_actor ON ((film.film_id = film_actor.film_id)))
     JOIN app_public.actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;


--
-- TOC entry 221 (class 1259 OID 41077)
-- Name: inventory_inventory_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.inventory_inventory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 222 (class 1259 OID 41079)
-- Name: inventory; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.inventory (
    inventory_id integer DEFAULT nextval('app_public.inventory_inventory_id_seq'::regclass) NOT NULL,
    film_id smallint NOT NULL,
    store_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 223 (class 1259 OID 41084)
-- Name: language_language_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.language_language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 224 (class 1259 OID 41086)
-- Name: language; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.language (
    language_id integer DEFAULT nextval('app_public.language_language_id_seq'::regclass) NOT NULL,
    name character(20) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 225 (class 1259 OID 41091)
-- Name: nicer_but_slower_film_list; Type: VIEW; Schema: app_public. Owner: -
--

CREATE VIEW app_public.nicer_but_slower_film_list AS
 SELECT film.film_id AS fid,
    film.title,
    film.description,
    category.name AS category,
    film.rental_rate AS price,
    film.length,
    film.rating,
    app_public.group_concat((((upper("substring"((actor.first_name)::text, 1, 1)) || lower("substring"((actor.first_name)::text, 2))) || upper("substring"((actor.last_name)::text, 1, 1))) || lower("substring"((actor.last_name)::text, 2)))) AS actors
   FROM ((((app_public.category
     LEFT JOIN app_public.film_category ON ((category.category_id = film_category.category_id)))
     LEFT JOIN app_public.film ON ((film_category.film_id = film.film_id)))
     JOIN app_public.film_actor ON ((film.film_id = film_actor.film_id)))
     JOIN app_public.actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;


--
-- TOC entry 226 (class 1259 OID 41096)
-- Name: payment_payment_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.payment_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 227 (class 1259 OID 41098)
-- Name: payment; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.payment (
    payment_id integer DEFAULT nextval('app_public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id smallint NOT NULL,
    staff_id smallint NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp without time zone NOT NULL
);


--
-- TOC entry 228 (class 1259 OID 41102)
-- Name: rental_rental_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.rental_rental_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 229 (class 1259 OID 41104)
-- Name: rental; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.rental (
    rental_id integer DEFAULT nextval('app_public.rental_rental_id_seq'::regclass) NOT NULL,
    rental_date timestamp without time zone NOT NULL,
    inventory_id integer NOT NULL,
    customer_id smallint NOT NULL,
    return_date timestamp without time zone,
    staff_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 230 (class 1259 OID 41109)
-- Name: sales_by_film_category; Type: VIEW; Schema: app_public. Owner: -
--

CREATE VIEW app_public.sales_by_film_category AS
 SELECT c.name AS category,
    sum(p.amount) AS total_sales
   FROM (((((app_public.payment p
     JOIN app_public.rental r ON ((p.rental_id = r.rental_id)))
     JOIN app_public.inventory i ON ((r.inventory_id = i.inventory_id)))
     JOIN app_public.film f ON ((i.film_id = f.film_id)))
     JOIN app_public.film_category fc ON ((f.film_id = fc.film_id)))
     JOIN app_public.category c ON ((fc.category_id = c.category_id)))
  GROUP BY c.name
  ORDER BY (sum(p.amount)) DESC;


--
-- TOC entry 231 (class 1259 OID 41114)
-- Name: staff_staff_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.staff_staff_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 232 (class 1259 OID 41116)
-- Name: staff; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.staff (
    staff_id integer DEFAULT nextval('app_public.staff_staff_id_seq'::regclass) NOT NULL,
    first_name character varying(45) NOT NULL,
    last_name character varying(45) NOT NULL,
    address_id smallint NOT NULL,
    email character varying(50),
    store_id smallint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    username character varying(16) NOT NULL,
    password character varying(40),
    last_update timestamp without time zone DEFAULT now() NOT NULL,
    picture bytea
);


--
-- TOC entry 233 (class 1259 OID 41125)
-- Name: store_store_id_seq; Type: SEQUENCE; Schema: app_public. Owner: -
--

CREATE SEQUENCE app_public.store_store_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 234 (class 1259 OID 41127)
-- Name: store; Type: TABLE; Schema: app_public. Owner: -
--

CREATE TABLE app_public.store (
    store_id integer DEFAULT nextval('app_public.store_store_id_seq'::regclass) NOT NULL,
    manager_staff_id smallint NOT NULL,
    address_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 235 (class 1259 OID 41132)
-- Name: sales_by_store; Type: VIEW; Schema: app_public. Owner: -
--

CREATE VIEW app_public.sales_by_store AS
 SELECT (((c.city)::text || ','::text) || (cy.country)::text) AS store,
    (((m.first_name)::text || ' '::text) || (m.last_name)::text) AS manager,
    sum(p.amount) AS total_sales
   FROM (((((((app_public.payment p
     JOIN app_public.rental r ON ((p.rental_id = r.rental_id)))
     JOIN app_public.inventory i ON ((r.inventory_id = i.inventory_id)))
     JOIN app_public.store s ON ((i.store_id = s.store_id)))
     JOIN app_public.address a ON ((s.address_id = a.address_id)))
     JOIN app_public.city c ON ((a.city_id = c.city_id)))
     JOIN app_public.country cy ON ((c.country_id = cy.country_id)))
     JOIN app_public.staff m ON ((s.manager_staff_id = m.staff_id)))
  GROUP BY cy.country, c.city, s.store_id, m.first_name, m.last_name
  ORDER BY cy.country, c.city;


--
-- TOC entry 236 (class 1259 OID 41137)
-- Name: staff_list; Type: VIEW; Schema: app_public. Owner: -
--

CREATE VIEW app_public.staff_list AS
 SELECT s.staff_id AS id,
    (((s.first_name)::text || ' '::text) || (s.last_name)::text) AS name,
    a.address,
    a.postal_code AS "zip code",
    a.phone,
    city.city,
    country.country,
    s.store_id AS sid
   FROM (((app_public.staff s
     JOIN app_public.address a ON ((s.address_id = a.address_id)))
     JOIN app_public.city ON ((a.city_id = city.city_id)))
     JOIN app_public.country ON ((city.country_id = country.country_id)));


--
-- TOC entry 3891 (class 2606 OID 41143)
-- Name: actor actor_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.actor
    ADD CONSTRAINT actor_pkey PRIMARY KEY (actor_id);


--
-- TOC entry 3906 (class 2606 OID 41145)
-- Name: address address_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- TOC entry 3894 (class 2606 OID 41147)
-- Name: category category_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (category_id);


--
-- TOC entry 3909 (class 2606 OID 41149)
-- Name: city city_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.city
    ADD CONSTRAINT city_pkey PRIMARY KEY (city_id);


--
-- TOC entry 3912 (class 2606 OID 41151)
-- Name: country country_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.country
    ADD CONSTRAINT country_pkey PRIMARY KEY (country_id);


--
-- TOC entry 3886 (class 2606 OID 41153)
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (customer_id);


--
-- TOC entry 3901 (class 2606 OID 41155)
-- Name: film_actor film_actor_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.film_actor
    ADD CONSTRAINT film_actor_pkey PRIMARY KEY (actor_id, film_id);


--
-- TOC entry 3904 (class 2606 OID 41157)
-- Name: film_category film_category_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.film_category
    ADD CONSTRAINT film_category_pkey PRIMARY KEY (film_id, category_id);


--
-- TOC entry 3897 (class 2606 OID 41159)
-- Name: film film_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.film
    ADD CONSTRAINT film_pkey PRIMARY KEY (film_id);


--
-- TOC entry 3915 (class 2606 OID 41161)
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id);


--
-- TOC entry 3917 (class 2606 OID 41163)
-- Name: language language_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.language
    ADD CONSTRAINT language_pkey PRIMARY KEY (language_id);


--
-- TOC entry 3922 (class 2606 OID 41165)
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);


--
-- TOC entry 3926 (class 2606 OID 41167)
-- Name: rental rental_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.rental
    ADD CONSTRAINT rental_pkey PRIMARY KEY (rental_id);


--
-- TOC entry 3928 (class 2606 OID 41169)
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);


--
-- TOC entry 3931 (class 2606 OID 41171)
-- Name: store store_pkey; Type: CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.store
    ADD CONSTRAINT store_pkey PRIMARY KEY (store_id);


--
-- TOC entry 3895 (class 1259 OID 41172)
-- Name: film_fulltext_idx; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX film_fulltext_idx ON app_public.film USING gist (fulltext);


--
-- TOC entry 3892 (class 1259 OID 41173)
-- Name: idx_actor_last_name; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_actor_last_name ON app_public.actor USING btree (last_name);


--
-- TOC entry 3887 (class 1259 OID 41174)
-- Name: idx_fk_address_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_address_id ON app_public.customer USING btree (address_id);


--
-- TOC entry 3907 (class 1259 OID 41175)
-- Name: idx_fk_city_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_city_id ON app_public.address USING btree (city_id);


--
-- TOC entry 3910 (class 1259 OID 41176)
-- Name: idx_fk_country_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_country_id ON app_public.city USING btree (country_id);


--
-- TOC entry 3918 (class 1259 OID 41177)
-- Name: idx_fk_customer_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_customer_id ON app_public.payment USING btree (customer_id);


--
-- TOC entry 3902 (class 1259 OID 41178)
-- Name: idx_fk_film_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_film_id ON app_public.film_actor USING btree (film_id);


--
-- TOC entry 3923 (class 1259 OID 41179)
-- Name: idx_fk_inventory_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_inventory_id ON app_public.rental USING btree (inventory_id);


--
-- TOC entry 3898 (class 1259 OID 41180)
-- Name: idx_fk_language_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_language_id ON app_public.film USING btree (language_id);


--
-- TOC entry 3919 (class 1259 OID 41181)
-- Name: idx_fk_rental_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_rental_id ON app_public.payment USING btree (rental_id);


--
-- TOC entry 3920 (class 1259 OID 41182)
-- Name: idx_fk_staff_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_staff_id ON app_public.payment USING btree (staff_id);


--
-- TOC entry 3888 (class 1259 OID 41183)
-- Name: idx_fk_store_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_fk_store_id ON app_public.customer USING btree (store_id);


--
-- TOC entry 3889 (class 1259 OID 41184)
-- Name: idx_last_name; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_last_name ON app_public.customer USING btree (last_name);


--
-- TOC entry 3913 (class 1259 OID 41185)
-- Name: idx_store_id_film_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_store_id_film_id ON app_public.inventory USING btree (store_id, film_id);


--
-- TOC entry 3899 (class 1259 OID 41186)
-- Name: idx_title; Type: INDEX; Schema: app_public. Owner: -
--

CREATE INDEX idx_title ON app_public.film USING btree (title);


--
-- TOC entry 3929 (class 1259 OID 41187)
-- Name: idx_unq_manager_staff_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE UNIQUE INDEX idx_unq_manager_staff_id ON app_public.store USING btree (manager_staff_id);


--
-- TOC entry 3924 (class 1259 OID 41188)
-- Name: idx_unq_rental_rental_date_inventory_id_customer_id; Type: INDEX; Schema: app_public. Owner: -
--

CREATE UNIQUE INDEX idx_unq_rental_rental_date_inventory_id_customer_id ON app_public.rental USING btree (rental_date, inventory_id, customer_id);


--
-- TOC entry 3953 (class 2620 OID 41189)
-- Name: film film_fulltext_trigger; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER film_fulltext_trigger BEFORE INSERT OR UPDATE ON app_public.film FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('fulltext', 'pg_catalog.english', 'title', 'description');


--
-- TOC entry 3951 (class 2620 OID 41190)
-- Name: actor last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.actor FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3957 (class 2620 OID 41191)
-- Name: address last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.address FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3952 (class 2620 OID 41192)
-- Name: category last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.category FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3958 (class 2620 OID 41193)
-- Name: city last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.city FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3959 (class 2620 OID 41194)
-- Name: country last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.country FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3950 (class 2620 OID 41195)
-- Name: customer last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.customer FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3954 (class 2620 OID 41196)
-- Name: film last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.film FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3955 (class 2620 OID 41197)
-- Name: film_actor last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.film_actor FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3956 (class 2620 OID 41198)
-- Name: film_category last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.film_category FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3960 (class 2620 OID 41199)
-- Name: inventory last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.inventory FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3961 (class 2620 OID 41200)
-- Name: language last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.language FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3962 (class 2620 OID 41201)
-- Name: rental last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.rental FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3963 (class 2620 OID 41202)
-- Name: staff last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.staff FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3964 (class 2620 OID 41203)
-- Name: store last_updated; Type: TRIGGER; Schema: app_public. Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON app_public.store FOR EACH ROW EXECUTE FUNCTION app_public.last_updated();


--
-- TOC entry 3932 (class 2606 OID 41204)
-- Name: customer customer_address_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.customer
    ADD CONSTRAINT customer_address_id_fkey FOREIGN KEY (address_id) REFERENCES app_public.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3934 (class 2606 OID 41209)
-- Name: film_actor film_actor_actor_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.film_actor
    ADD CONSTRAINT film_actor_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES app_public.actor(actor_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3935 (class 2606 OID 41214)
-- Name: film_actor film_actor_film_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.film_actor
    ADD CONSTRAINT film_actor_film_id_fkey FOREIGN KEY (film_id) REFERENCES app_public.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3936 (class 2606 OID 41219)
-- Name: film_category film_category_category_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.film_category
    ADD CONSTRAINT film_category_category_id_fkey FOREIGN KEY (category_id) REFERENCES app_public.category(category_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3937 (class 2606 OID 41224)
-- Name: film_category film_category_film_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.film_category
    ADD CONSTRAINT film_category_film_id_fkey FOREIGN KEY (film_id) REFERENCES app_public.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3933 (class 2606 OID 41229)
-- Name: film film_language_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.film
    ADD CONSTRAINT film_language_id_fkey FOREIGN KEY (language_id) REFERENCES app_public.language(language_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3938 (class 2606 OID 41234)
-- Name: address fk_address_city; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.address
    ADD CONSTRAINT fk_address_city FOREIGN KEY (city_id) REFERENCES app_public.city(city_id);


--
-- TOC entry 3939 (class 2606 OID 41239)
-- Name: city fk_city; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.city
    ADD CONSTRAINT fk_city FOREIGN KEY (country_id) REFERENCES app_public.country(country_id);


--
-- TOC entry 3940 (class 2606 OID 41244)
-- Name: inventory inventory_film_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.inventory
    ADD CONSTRAINT inventory_film_id_fkey FOREIGN KEY (film_id) REFERENCES app_public.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3941 (class 2606 OID 41249)
-- Name: payment payment_customer_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.payment
    ADD CONSTRAINT payment_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES app_public.customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3942 (class 2606 OID 41254)
-- Name: payment payment_rental_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.payment
    ADD CONSTRAINT payment_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES app_public.rental(rental_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 3943 (class 2606 OID 41259)
-- Name: payment payment_staff_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.payment
    ADD CONSTRAINT payment_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES app_public.staff(staff_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3944 (class 2606 OID 41264)
-- Name: rental rental_customer_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.rental
    ADD CONSTRAINT rental_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES app_public.customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3945 (class 2606 OID 41269)
-- Name: rental rental_inventory_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.rental
    ADD CONSTRAINT rental_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES app_public.inventory(inventory_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3946 (class 2606 OID 41275)
-- Name: rental rental_staff_id_key; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.rental
    ADD CONSTRAINT rental_staff_id_key FOREIGN KEY (staff_id) REFERENCES app_public.staff(staff_id);


--
-- TOC entry 3947 (class 2606 OID 41280)
-- Name: staff staff_address_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.staff
    ADD CONSTRAINT staff_address_id_fkey FOREIGN KEY (address_id) REFERENCES app_public.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3948 (class 2606 OID 41285)
-- Name: store store_address_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.store
    ADD CONSTRAINT store_address_id_fkey FOREIGN KEY (address_id) REFERENCES app_public.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3949 (class 2606 OID 41293)
-- Name: store store_manager_staff_id_fkey; Type: FK CONSTRAINT; Schema: app_public. Owner: -
--

ALTER TABLE ONLY app_public.store
    ADD CONSTRAINT store_manager_staff_id_fkey FOREIGN KEY (manager_staff_id) REFERENCES app_public.staff(staff_id) ON UPDATE CASCADE ON DELETE RESTRICT;


-- Completed on 2022-09-06 20:21:16 +04

--
-- PostgreSQL database dump complete
--

