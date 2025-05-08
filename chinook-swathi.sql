use chinook;
-- 1. The missing values in the customer table are handled in the following manner
SELECT 
	customer_id,first_name,last_name,
	COALESCE (company,'N\A') AS company,
	address,city,COALESCE (state,'Unknown') as state,
	COALESCE (postal_code,'N\A') AS postal_code,
	COALESCE (phone,'Not Provided') AS phone,
	COALESCE (fax,'N\A') AS fax,
	email,support_rep_id
FROM customer;

-- The missing values in the Employee table are handled in the following manner
SELECT 
	employee_id,last_name,first_name,title,
	COALESCE (reports_to,'None') AS reports_to,
    birthdate,hire_date,address,city,
    state,country,postal_code,phone,fax,email
FROM employee;

-- The missing values in the track table are handled in the following manner

SELECT 
	Track_id,name,album_id,media_type_id,genre_id,
    COALESCE (composer,'no composer') as composer,
    milliseconds,bytes,unit_price
FROM track;

-- Finding Duplicate values
SELECT *, COUNT(*) AS count  
FROM track  
GROUP BY track_id  
HAVING COUNT(*) > 1;

-- 2. Find the top-selling tracks and top artist in the USA and identify their most famous genres.
SELECT
t.name AS Track_Name,
SUM(i.total) AS Total_Sales,
ar.name AS Artist_Name,
g.name AS  Genre
FROM track t
JOIN invoice_line il ON t.track_id=il.track_id
JOIN invoice i ON i.invoice_id=il.invoice_id
JOIN genre g ON t.genre_id=g.genre_id
JOIN album am ON t.album_id=am.album_id
JOIN artist ar ON am.artist_id=ar.artist_id
WHERE i.billing_country = "USA"
GROUP BY t.name,ar.name,g.name
ORDER BY Total_Sales DESC;

-- 3. What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?
SELECT billing_country, 
       COUNT(DISTINCT customer_id) AS No_of_Customers,
       SUM(total) AS Total_Sales
FROM invoice
GROUP BY billing_country
ORDER BY Total_Sales DESC;

-- 4. Calculate the total revenue and number of invoices for each country, state, and city:

SELECT
	billing_country AS Country,
	billing_state AS State,
	billing_city AS City,
	SUM(total) AS Total_Revenue,
	COUNT(invoice_id) AS No_of_Invoices
FROM invoice
GROUP BY billing_country,billing_state,billing_city
ORDER BY billing_country,billing_state,billing_city;

-- 5. Find the top 5 customers by total revenue in each country

WITH CountryRanking AS(
SELECT 
	i.billing_country AS Country,
	CONCAT(c.first_name,' ',c.last_name) AS CustomerName,
	SUM(i.total) AS TotalRevenue,
RANK() OVER(PARTITION BY i.billing_country ORDER BY SUM(i.total) DESC) AS rnk
FROM customer c
JOIN invoice i ON c.customer_id=i.customer_id
GROUP BY CustomerName,i.billing_country
ORDER BY country,TotalRevenue DESC
)
SELECT 
	Country,CustomerName,TotalRevenue 
FROM CountryRanking 
WHERE rnk <=5;

-- 6. Identify the top-selling track for each customer

WITH Top_Tracks AS (
	SELECT CONCAT(c.first_name,' ',c.last_name) AS CustomerName,
	t.name AS TrackName,
	SUM(i.total) AS TotalSales,
RANK() OVER(PARTITION BY CONCAT(c.first_name,' ',c.last_name) ORDER BY SUM(i.total) DESC, t.name ASC) AS rnk
FROM customer c
JOIN invoice i ON c.customer_id=i.customer_id
JOIN invoice_line il ON i.invoice_id=il.invoice_id
JOIN track t ON il.track_id=t.track_id
GROUP BY CONCAT(c.first_name,' ',c.last_name), t.name
ORDER BY CustomerName 
)
SELECT CustomerName,TrackName
FROM Top_Tracks
WHERE rnk = 1;

-- 7. Are there any patterns or trends in customer purchasing behaviour 

SELECT 
	MONTH (invoice_date) as Month,
	COUNT(DISTINCT invoice_id) as Purchase_num,
	ROUND(AVG(total),2) as AvgOrderValue
FROM invoice
GROUP BY month
ORDER BY Month;

-- 8. What is the customer churn rate

SELECT 
    ((COUNT(DISTINCT CASE WHEN invoice_date BETWEEN '2017-01-01' AND '2017-03-31' 
        THEN customer_id END) 
    - COUNT(DISTINCT CASE WHEN invoice_date BETWEEN '2020-11-01' AND '2020-12-31' 
        THEN customer_id END)) 
    / COUNT(DISTINCT CASE WHEN invoice_date BETWEEN '2017-01-01' AND '2017-03-31' 
        THEN customer_id END)) * 100 AS churn_rate
FROM invoice;

-- 9. Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.

WITH Genre_Rank AS (
	SELECT
		ar.name AS ArtistName, g.name AS Genre, SUM(i.total) as TotalSales,
		ROUND(((SUM(i.total))/ (SELECT SUM(total) FROM invoice)) *100,2) AS PercentageSales,
RANK() OVER(PARTITION BY g.name ORDER BY SUM(i.total) DESC) AS rnk
FROM track t
JOIN invoice_line il ON t.track_id=il.track_id
JOIN invoice i ON i.invoice_id=il.invoice_id
JOIN genre g ON t.genre_id=g.genre_id
JOIN album am ON t.album_id=am.album_id
JOIN artist ar ON am.artist_id=ar.artist_id
WHERE i.billing_country = "USA"
GROUP BY ar.name,g.name
)
SELECT 
	ArtistName,Genre,TotalSales,PercentageSales 
FROM Genre_Rank
WHERE rnk = 1 
ORDER BY PercentageSales DESC;

-- 10. Find customers who have purchased tracks from at least 3 different genres

SELECT 
	c.Customer_id,
	CONCAT(c.first_name,' ',c.last_name) AS Customer_Name,
	COUNT(distinct t.genre_id) AS Number
FROM track t
JOIN invoice_line il ON t.track_id=il.track_id
JOIN invoice i ON i.invoice_id=il.invoice_id
JOIN customer c ON c.customer_id=i.customer_id
GROUP BY  c.customer_id,c.first_name
HAVING COUNT(DISTINCT t.genre_id) >= 3
ORDER BY c.customer_id;

-- 11. Rank genres based on their sales performance in the USA

SELECT
	g.name AS GenreName,
	SUM(i.total) AS TotalSales,
RANK() OVER(ORDER BY SUM(i.total) DESC) AS GenreRank
FROM track t
JOIN invoice_line il ON t.track_id=il.track_id
JOIN invoice i ON i.invoice_id=il.invoice_id
JOIN genre g ON t.genre_id=g.genre_id
WHERE i.billing_country = "USA"
GROUP BY g.name;

-- 12. Identify customers who have not made a purchase in the last 3 months
SELECT c.Customer_id, c.First_name, c.Last_name
FROM customer c
WHERE NOT EXISTS (
    SELECT 1
    FROM invoice i
    WHERE i.customer_id = c.customer_id
	AND i.invoice_date >= date_add(curdate(), interval -3 month)
);

-- 1.Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.

SELECT am.title AS AlbumName,
       g.name AS Genre,
       SUM(i.total) AS TotalSales
FROM track t
JOIN invoice_line il ON t.track_id = il.track_id
JOIN invoice i ON i.invoice_id = il.invoice_id
JOIN genre g ON t.genre_id = g.genre_id
JOIN album am ON t.album_id = am.album_id
WHERE i.billing_country = "USA"
GROUP BY am.title, g.name
ORDER BY TotalSales 
limit 3;

-- 2. Determine the top-selling genres in countries other than the USA and identify any commonalities or differences

SELECT
	g.name as GenreName,
	SUM(i.total) as TotalSales
FROM track t
JOIN invoice_line il ON t.track_id = il.track_id
JOIN invoice i ON i.invoice_id = il.invoice_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE i.billing_country <> "USA"
GROUP BY g.name
ORDER BY TotalSales DESC;

-- 3. Customer Purchasing Behavior Analysis

WITH Details AS (
    SELECT 
        i.customer_id,
        MIN(i.invoice_date) AS first_date,
        MAX(i.invoice_date) AS last_date,
        TIMESTAMPDIFF(MONTH, MIN(i.invoice_date), MAX(i.invoice_date)) AS CustomerDuration,
        SUM(i.total) AS TotalSpending,
        SUM(il.quantity) AS BasketSize,
        COUNT(i.invoice_id) AS Frequency
    FROM invoice i
    LEFT JOIN invoice_line il ON il.invoice_id = i.invoice_id
    GROUP BY i.customer_id
), 
average_duration AS (
    SELECT AVG(CustomerDuration) AS AvgDuration FROM Details
) 
SELECT 
    CASE 
        WHEN CustomerDuration > (SELECT AvgDuration FROM average_duration) 
        THEN 'Long term Customer' 
        ELSE 'Short term Customer' 
    END AS category,
    SUM(TotalSpending) AS TotalSpending,
    SUM(BasketSize) AS BasketSize,
    COUNT(Frequency) AS Frequency
FROM Details
GROUP BY category;

-- 4. Product Affinity Analysis
SELECT
    g.name AS Purchased_Genre,
    al.title AS Recommended_Album,
    ar.name AS Recommended_Artist,
    COUNT(DISTINCT il.invoice_id) AS Number_of_Copurchases
FROM invoice_line il
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
WHERE EXISTS (
    SELECT 1
    FROM invoice_line il_inner
    JOIN track t_inner ON il_inner.track_id = t_inner.track_id
    WHERE il_inner.invoice_id = il.invoice_id
      AND t_inner.genre_id <> t.genre_id
)
GROUP BY Purchased_Genre, Recommended_Album, Recommended_Artist
ORDER BY Purchased_Genre, Number_of_Copurchases DESC;

-- 5. Regional Market Analysis

SELECT 
    billing_country AS Country,
    COUNT(DISTINCT customer_id) AS Num_customers,
    ROUND(COALESCE((COUNT(DISTINCT customer_id) - LAG(COUNT(DISTINCT customer_id)) 
    OVER (ORDER BY billing_country)) / COUNT(DISTINCT customer_id) * 100, 0), 2) 
    AS Percent_ChurnRate
FROM invoice
GROUP BY billing_country
ORDER BY Percent_ChurnRate;

-- 6. Customer Risk Profiling
SELECT 
    i.customer_id,
    CONCAT(first_name, " ", last_name) AS customer_name,
    billing_country,
    invoice_date,
    SUM(total) AS totalspending,
    COUNT(invoice_id) AS numoforders
FROM invoice i
LEFT JOIN customer c ON c.customer_id = i.customer_id
GROUP BY i.customer_id,customer_name,billing_country,invoice_date
ORDER BY customer_name;

-- 7. Customer Lifetime Value Modeling: 

SELECT 
    customer_id,
    billing_country AS country,
    TIMESTAMPDIFF(MONTH, MIN(invoice_date), MAX(invoice_date)) AS customer_tenure_months,
    COUNT(DISTINCT invoice_id) AS total_purchases,
    SUM(total) AS total_spent
FROM invoice
GROUP BY customer_id, billing_country
ORDER BY country, customer_id;

-- 10. How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album?

ALTER TABLE Album
ADD COLUMN ReleaseYear INTEGER;

-- 11. Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. 
WITH cp AS (
    SELECT
        cu.country,
        cu.customer_id,
        SUM(inv.total) AS total_spent,
        COUNT(DISTINCT il.track_id) AS tracks_purchased
    FROM customer cu
    LEFT JOIN invoice inv ON cu.customer_id = inv.customer_id
    LEFT JOIN invoice_line il ON inv.invoice_id = il.invoice_id
    GROUP BY cu.country, cu.customer_id
)
SELECT
    cp.country AS Country,
    COUNT(DISTINCT cp.customer_id) AS No_of_Customers,
    ROUND(AVG(cp.total_spent), 2) AS Avg_Spent,
    ROUND(AVG(cp.tracks_purchased), 2) AS Avg_Tracks_Purchased
FROM cp
GROUP BY cp.country
ORDER BY cp.country;


