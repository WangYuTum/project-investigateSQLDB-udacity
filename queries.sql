/********** Queries 1 - used for 1st insight **********/

WITH family_films AS
	(SELECT f.film_id AS film_id, f.title AS film_title, c.name AS category_name
	FROM film_category fc
	JOIN category c
	ON c.category_id = fc.category_id
	AND c.name IN('Animation', 'Children', 'Classics', 'Comedy', 'Family', 'Music')
	JOIN film f
	ON f.film_id = fc.film_id),
	
	rental_counts AS
	(SELECT f.film_id AS film_id, COUNT(*) rental_cnt
	FROM rental r
	JOIN inventory i
	ON r.inventory_id = i.inventory_id
	JOIN film f
	ON i.film_id = f.film_id
	GROUP BY 1),
	
	family_film_rentals AS
	(SELECT f.film_title AS film_title,
		   f.category_name AS category_name,
		   r.rental_cnt AS rental_cnt
	FROM family_films f
	JOIN rental_counts r
	ON f.film_id = r.film_id
	ORDER BY 2, 1)

-- show the result table
SELECT *
FROM family_film_rentals

-- create table for visualisation
SELECT category_name, SUM(rental_cnt) AS rental_total
FROM family_film_rentals
GROUP BY 1
ORDER BY 2 DESC;


/********** Queries 2 - used for 2nd insight **********/

WITH film_quartiles AS
	(SELECT f.title film_title, c.name category_name, f.rental_duration,
	NTILE(4) OVER (ORDER BY f.rental_duration) AS standard_quartile
	FROM film f
	JOIN film_category fc
	ON f.film_id = fc.film_id
	JOIN category c
	ON fc.category_id = c.category_id),
	
	family_quartiles AS
	(SELECT *
	FROM film_quartiles
	WHERE category_name IN('Animation', 'Children', 'Classics', 'Comedy', 'Family', 'Music')),
	
	result_tbl AS
	(SELECT fq.category_name AS name, fq.standard_quartile, COUNT(*) count
	FROM family_quartiles fq
	GROUP BY 1, 2
	ORDER BY 1, 2)

-- show the result table
SELECT *
FROM result_tbl

-- create table for visualisation
SELECT *
FROM(SELECT rt.name AS category_name,
	LEAD(rt.count, 0) OVER(PARTITION BY name ORDER BY rt.standard_quartile) AS duration_q1,
	LEAD(rt.count, 1) OVER(PARTITION BY name ORDER BY rt.standard_quartile) AS duration_q2,
	LEAD(rt.count, 2) OVER(PARTITION BY name ORDER BY rt.standard_quartile) AS duration_q3,
	LEAD(rt.count, 3) OVER(PARTITION BY name ORDER BY rt.standard_quartile) AS duration_q4
	FROM result_tbl rt) AS sub_tbl
WHERE duration_q4 IS NOT null


/********** Queries 3 - used for 3rd insight **********/

WITH result_tbl AS
	(SELECT DATE_PART('month', r.rental_date) AS month, 
	DATE_PART('year', r.rental_date) AS year, 
	s.store_id, COUNT(*) count_rentals
	FROM rental r
	JOIN store s
	ON r.staff_id = s.manager_staff_id
	GROUP BY 1, 2, 3
	ORDER BY 4 DESC)

-- show the result table
SELECT *
FROM result_tbl

-- create table for visualisation
SELECT CONCAT(sub_tbl.year, '/', sub_tbl.month) AS year_mon,
sub_tbl.store_1, sub_tbl.store_2
FROM(SELECT year, month,
	LEAD(count_rentals, 0) OVER(PARTITION BY month, year ORDER BY store_id) AS store_1,
	LEAD(count_rentals, 1) OVER(PARTITION BY month, year ORDER BY store_id) AS store_2
	FROM result_tbl) AS sub_tbl
WHERE sub_tbl.store_2 IS NOT null
ORDER BY 1


/********** Queries 4 - used for 4th insight **********/

WITH customer_payments AS
	(SELECT DATE_TRUNC('month', p.payment_date) AS year_month,
	p.customer_id, COUNT(*) pay_count, SUM(p.amount) pay_amount
	FROM payment p
	WHERE DATE_PART('year', p.payment_date) = 2007
	GROUP BY 1, 2),
	
	top_customers AS
	(SELECT p.customer_id, (c.first_name || ' ' || c.last_name) AS full_name,
	SUM(p.amount) total_amt
	FROM payment p
	JOIN customer c
	ON p.customer_id = c.customer_id
	GROUP BY 1,2
	ORDER BY 3 DESC
	LIMIT 10),
	
	result_tbl AS
	(SELECT cp.year_month AS pay_mon, tc.full_name AS full_name,
	cp.pay_count AS pay_countpermon, cp.pay_amount AS pay_amount
	FROM customer_payments cp
	JOIN top_customers tc
	ON cp.customer_id = tc.customer_id 
	ORDER BY 2, 1)

-- show result table
SELECT *
FROM result_tbl

-- create table for visualisation
SELECT full_name, Feb, Mar, April, COALESCE(May, 0) as May
FROM(SELECT ROW_NUMBER() OVER(PARTITION BY full_name ORDER BY pay_mon) AS row_id,
	full_name,
	LEAD(pay_amount, 0) OVER(PARTITION BY full_name ORDER BY pay_mon) AS Feb,
	LEAD(pay_amount, 1) OVER(PARTITION BY full_name ORDER BY pay_mon) AS Mar,
	LEAD(pay_amount, 2) OVER(PARTITION BY full_name ORDER BY pay_mon) AS April,
	LEAD(pay_amount, 3) OVER(PARTITION BY full_name ORDER BY pay_mon) AS May
	FROM result_tbl) AS sub_tbl
WHERE sub_tbl.row_id = 1

