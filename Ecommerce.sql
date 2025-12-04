CREATE DATABASE Ecommerce;
USE Ecommerce;

-- 1. Regions (no dependencies)
CREATE TABLE Regions (
    RegionID INT PRIMARY KEY,
    RegionName VARCHAR(100),
    Country VARCHAR(100)
);

-- 2. Customers (references Regions)
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    CustomerName VARCHAR(100),
    Email VARCHAR(100),
    Phone VARCHAR(30),
    RegionID INT,
    CreatedAt DATE,
    FOREIGN KEY (RegionID) REFERENCES Regions(RegionID)
);

-- 3. Products (no dependencies)
CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(100),
    Category VARCHAR(100),
    Price DECIMAL(10, 2)
);

-- 4. Orders (references Customers)
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT,
    OrderDate DATE,
    IsReturned BOOLEAN,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

-- 5. OrderDetails (references Orders and Products)
CREATE TABLE OrderDetails (
    OrderDetailID INT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);

-- GENERAL SALES INSIGHTS
-- 1. Total revenue generated over the entire period
SELECT SUM(od.Quantity * p.Price) AS total_revenue
FROM OrderDetails od
JOIN Products p ON od.ProductID = p.ProductID;

-- 2. Revenue excluding returned orders 
SELECT SUM(od.Quantity * p.Price) AS revenue_excluding_returns
FROM OrderDetails od
JOIN Orders o      ON od.OrderID = o.OrderID
JOIN Products p    ON od.ProductID = p.ProductID
WHERE o.IsReturned = FALSE;

-- 3. Total Revenue per Year / Month
SELECT YEAR(o.OrderDate) AS year, MONTH(o.OrderDate) AS month, SUM(od.Quantity * p.Price) AS revenue
FROM OrderDetails od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
WHERE o.IsReturned = FALSE
GROUP BY year, month
ORDER BY year, month;

-- 4. Revenue by Product / Category
SELECT p.Category, p.ProductName, SUM(od.Quantity * p.Price) AS revenue
FROM OrderDetails od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
WHERE o.IsReturned = FALSE
GROUP BY p.Category,p.ProductName
ORDER BY revenue DESC;

-- 5. Average Order Value (AOV) across all orders
SELECT AVG(TotalOrderValue) AS AOV
FROM(SELECT o.orderid, SUM(od.Quantity * p.Price) AS TotalOrderValue
 FROM Orders o
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    JOIN Products p      ON od.ProductID = p.ProductID
    WHERE o.IsReturned = FALSE
 GROUP BY o.OrderID) AS T;
 
 -- 6. AOV per Year / Month
SELECT YEAR(OrderDate) AS year, MONTH(OrderDate) AS month,  AVG(TotalOrderValue) AS AOV
FROM(SELECT o.orderid,O.OrderDate, SUM(od.Quantity * p.Price) AS TotalOrderValue
 FROM Orders o
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    JOIN Products p      ON od.ProductID = p.ProductID
    WHERE o.IsReturned = FALSE
 GROUP BY o.OrderID) AS T
 GROUP BY year, month
 ORDER BY year, month;
 
-- 7. Average order size by region (avg quantity of items per order)
SELECT RegionName,AVG(order_quantity) AS avg_items_per_order
FROM (SELECT o.OrderID, c.RegionID,SUM(od.Quantity) AS order_quantity
    FROM Orders o
    JOIN Customers c ON o.CustomerID = c.CustomerID
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    WHERE o.IsReturned = FALSE
    GROUP BY o.OrderID, c.RegionID
) AS t
JOIN Regions r ON t.RegionID = r.RegionID
GROUP BY r.RegionName
ORDER BY avg_items_per_order DESC;

-- CUSTOMER INSIGHTS
-- 8. Top 10 customers by total revenue spent
SELECT c.CustomerID,c.CustomerName,SUM(od.Quantity * p.Price) AS totalRevenuespent
FROM Customers c
JOIN Orders o ON c.CustomerID = o.CustomerID
JOIN OrderDetails od ON o.OrderID = od.OrderID
JOIN Products p ON od.ProductID = p.ProductID
WHERE o.IsReturned = FALSE
GROUP BY c.CustomerID, c.CustomerName
ORDER BY totalRevenuespent DESC
LIMIT 10;


-- 9. Repeat customer rate
-- = (customers with >= 2 orders) / (customers with >= 1 order)
SELECT (COUNT(DISTINCT CASE WHEN order_count > 1 THEN CustomerID END)/ COUNT(DISTINCT CustomerID)) AS repeat_customer_rate
FROM (SELECT CustomerID,COUNT(OrderID) AS order_count
    FROM Orders
    GROUP BY CustomerID
) AS t;


-- 10. Average time between two consecutive orders for the same customer, Region-wise (in days)
WITH customer_order_gaps AS (
    SELECT o.CustomerID,c.RegionID,o.OrderDate,
        LAG(o.OrderDate) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS prev_order_date
    FROM Orders o
    JOIN Customers c ON o.CustomerID = c.CustomerID
)
SELECT r.RegionID,r.RegionName,AVG(DATEDIFF(OrderDate, prev_order_date)) AS avg_days_between_orders
FROM customer_order_gaps cog
JOIN Regions r ON cog.RegionID = r.RegionID
-- WHERE prev_order_date IS NOT NULL
GROUP BY r.RegionID, r.RegionName
ORDER BY avg_days_between_orders;

-- 11. Customer Segment (based on total spend)
-- Platinum: > 1500, Gold: 1000–1500, Silver: 500–999, Bronze: < 500
WITH customer_spend AS (
    SELECT c.CustomerID,c.CustomerName,SUM(od.Quantity * p.Price) AS total_spent
    FROM Customers c
    JOIN Orders o       ON c.CustomerID = o.CustomerID
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    JOIN Products p     ON od.ProductID = p.ProductID
    WHERE o.IsReturned = FALSE
    GROUP BY c.CustomerID, c.CustomerName
)
SELECT CustomerID,CustomerName,total_spent,
    CASE 
        WHEN total_spent > 1500 THEN 'Platinum'
        WHEN total_spent BETWEEN 1000 AND 1500 THEN 'Gold'
        WHEN total_spent BETWEEN 500 AND 999 THEN 'Silver'
        ELSE 'Bronze'
    END AS segment
FROM customer_spend
ORDER BY total_spent DESC;

-- 12. Customer Lifetime Value (CLV)
-- Here: CLV = total revenue per customer 
SELECT c.CustomerID,c.CustomerName,SUM(od.Quantity * p.Price) AS CLV
FROM Customers c
JOIN Orders o       ON c.CustomerID = o.CustomerID
JOIN OrderDetails od ON o.OrderID = od.OrderID
JOIN Products p     ON od.ProductID = p.ProductID
WHERE o.IsReturned = FALSE
GROUP BY c.CustomerID, c.CustomerName
ORDER BY clv DESC;

-- PRODUCT & ORDER INSIGHTS
-- 13. Top 10 most sold products (by quantity)
SELECT p.ProductID,p.ProductName,SUM(od.Quantity) AS total_quantity_sold
FROM OrderDetails od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
WHERE o.IsReturned = FALSE
GROUP BY p.ProductID, p.ProductName
ORDER BY total_quantity_sold DESC
LIMIT 10;

-- 14. Top 10 most sold products (by revenue)
SELECT p.ProductID,p.ProductName,SUM(od.Quantity * p.Price) AS total_revenue
FROM OrderDetails od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
WHERE o.IsReturned = FALSE
GROUP BY p.ProductID, p.ProductName
ORDER BY total_revenue DESC
LIMIT 10;

-- 15. Products with the highest return rate
-- Return rate = returned_orders / total_orders (per product)
SELECT p.ProductID,p.ProductName,COUNT(DISTINCT o.OrderID) AS total_orders,COUNT(DISTINCT CASE WHEN o.IsReturned = TRUE THEN o.OrderID END) AS returned_orders,
COUNT(DISTINCT CASE WHEN o.IsReturned = TRUE THEN o.OrderID END)/ COUNT(DISTINCT o.OrderID) AS return_rate
FROM OrderDetails od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName
HAVING total_orders > 0
ORDER BY return_rate DESC, total_orders DESC;

-- 16. Return Rate by Category
SELECT p.Category,COUNT(DISTINCT o.OrderID) AS total_orders,COUNT(DISTINCT CASE WHEN o.IsReturned = TRUE THEN o.OrderID END) AS returned_orders,
    COUNT(DISTINCT CASE WHEN o.IsReturned = TRUE THEN o.OrderID END)/ COUNT(DISTINCT o.OrderID) AS return_rate
FROM OrderDetails od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
GROUP BY p.Category
HAVING total_orders > 0
ORDER BY return_rate DESC;

-- 17. Average price of products per region
-- Interpreted as: average price of products that customers in a region actually bought
SELECT r.RegionID,r.RegionName, AVG(p.Price) AS avg_product_price_purchased
FROM OrderDetails od
JOIN Orders o    ON od.OrderID = o.OrderID
JOIN Products p  ON od.ProductID = p.ProductID
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Regions r   ON c.RegionID = r.RegionID
WHERE o.IsReturned = FALSE
GROUP BY r.RegionID, r.RegionName
ORDER BY avg_product_price_purchased DESC;

-- 18. Sales trend for each product category (monthly revenue)
SELECT p.Category,YEAR(o.OrderDate) AS year,MONTH(o.OrderDate) AS month,SUM(od.Quantity * p.Price) AS revenue
FROM OrderDetails od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
WHERE o.IsReturned = FALSE
GROUP BY p.Category, YEAR(o.OrderDate), MONTH(o.OrderDate)
ORDER BY year, month,p.Category;

-- TEMPORAL TRENDS
-- 19. Monthly sales trends over the past year (last 12 months from today)
SELECT YEAR(o.OrderDate) AS year,MONTH(o.OrderDate) AS month,SUM(od.Quantity * p.Price) AS revenue
FROM OrderDetails od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
WHERE o.IsReturned = FALSE
  AND o.OrderDate >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY YEAR(o.OrderDate), MONTH(o.OrderDate)
ORDER BY year, month;


-- 20. How does AOV change by week
SELECT YEAR(OrderDate) AS year, WEEK(OrderDate) AS week,AVG(order_revenue) AS AOV
FROM (SELECT o.OrderID,o.OrderDate,SUM(od.Quantity * p.Price) AS order_revenue
    FROM Orders o
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    JOIN Products p      ON od.ProductID = p.ProductID
    WHERE o.IsReturned = FALSE
    GROUP BY o.OrderID, o.OrderDate) AS t
GROUP BY YEAR(OrderDate),WEEK(OrderDate)
ORDER BY year,week;

-- REGIONAL INSIGHTS
-- 21. Regions with highest / lowest order volume
SELECT r.RegionID,r.RegionName,COUNT(DISTINCT o.OrderID) AS order_count
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Regions r   ON c.RegionID = r.RegionID
GROUP BY r.RegionID, r.RegionName
ORDER BY order_count DESC;   -- top = highest, bottom = lowest

-- 22. Revenue per region and comparison across regions
SELECT r.RegionID,r.RegionName,SUM(od.Quantity * p.Price) AS revenue
FROM OrderDetails od
JOIN Orders o    ON od.OrderID = o.OrderID
JOIN Products p  ON od.ProductID = p.ProductID
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Regions r   ON c.RegionID = r.RegionID
WHERE o.IsReturned = FALSE
GROUP BY r.RegionID, r.RegionName
ORDER BY revenue DESC;

-- RETURN & REFUND INSIGHTS
-- 23. Overall return rate by product category
-- (same logic as "Return Rate by Category")
SELECT p.Category,COUNT(DISTINCT o.OrderID) AS total_orders,COUNT(DISTINCT CASE WHEN o.IsReturned = TRUE THEN o.OrderID END) AS returned_orders,
    COUNT(DISTINCT CASE WHEN o.IsReturned = TRUE THEN o.OrderID END)/ COUNT(DISTINCT o.OrderID) AS return_rate
FROM OrderDetails od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
GROUP BY p.Category
HAVING total_orders > 0
ORDER BY return_rate DESC;


-- 24. Overall return rate by region
SELECT r.RegionID,r.RegionName,COUNT(DISTINCT o.OrderID) AS total_orders,COUNT(DISTINCT CASE WHEN o.IsReturned = TRUE THEN o.OrderID END) AS returned_orders,
    COUNT(DISTINCT CASE WHEN o.IsReturned = TRUE THEN o.OrderID END)/ COUNT(DISTINCT o.OrderID) AS return_rate
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Regions r   ON c.RegionID = r.RegionID
GROUP BY r.RegionID, r.RegionName
HAVING total_orders > 0
ORDER BY return_rate DESC;

-- 25. Customers making frequent returns
-- "Frequent" = at least 2 returned orders (you can adjust threshold)
SELECT c.CustomerID,c.CustomerName,COUNT(*) AS returned_orders
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE o.IsReturned = TRUE
GROUP BY c.CustomerID, c.CustomerName
HAVING returned_orders >= 2
ORDER BY returned_orders DESC
LIMIT 10;



