/*
===============================================================================
Project: AdventureWorks Internet Sales Analysis
Author: Ahmed Gomaa
Description: 
    This script performs ETL (Extract, Transform, Load) tasks for the Power BI Dashboard.
    It includes:
    1. Data Exploration & Schema Checks.
    2. Data Quality Checks (Duplicates & Logic validation).
    3. Transformation Logic (Customer Segmentation, Loyalty Analysis).
    4. Final Data Extraction for Power BI.
===============================================================================
*/

USE AdventureWorksDW2022;
GO

-- =============================================================================
-- 1. DATA EXPLORATION
-- =============================================================================

-- Check available tables
SELECT * FROM INFORMATION_SCHEMA.TABLES;

-- Check Column structures for Fact and Dimension tables
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'FactInternetSales';
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DimCustomer';
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME IN ('DimProduct', 'DimProductCategory', 'DimProductSubcategory');


-- =============================================================================
-- 2. DATA QUALITY CHECKS
-- =============================================================================

-- Check for Duplicates in FactInternetSales using Window Functions
SELECT *
FROM (
    SELECT 
        *,
        RANK() OVER (PARTITION BY SalesOrderNumber, SalesOrderLineNumber ORDER BY ProductKey) AS Ranking
    FROM FactInternetSales
) AS t
WHERE Ranking > 1;

-- Check for Logic Errors (e.g., Production Cost > Sales Price)
SELECT 
    ProductStandardCost - TotalProductCost AS CostDiff
FROM FactInternetSales
WHERE ProductStandardCost - TotalProductCost > 0;

-- Check for Negative Margins (Sales Amount < Unit Price)
SELECT 
    SalesAmount - UnitPrice AS MarginDiff
FROM FactInternetSales
WHERE SalesAmount - UnitPrice < 0;


-- =============================================================================
-- 3. CUSTOMER ANALYSIS (TRANSFORMATION)
-- =============================================================================

-- Calculate Customer Loyalty (Recency & Frequency) using CTEs
WITH Loyalty AS (
    SELECT 
        CustomerKey,
        COUNT(*) AS Total_Orders,
        MAX(OrderDate) AS Last_Order
    FROM FactInternetSales
    GROUP BY CustomerKey
)
SELECT 
    CustomerKey,
    Total_Orders,
    CAST(Last_Order AS DATE) AS Last_Order_Date,
    DATEDIFF(DAY, Last_Order, (SELECT MAX(OrderDate) FROM FactInternetSales)) AS Days_Since_Last_Order
FROM Loyalty;


-- =============================================================================
-- 4. FINAL DATA EXTRACTION (For Power BI)
-- =============================================================================

-- 4.1 Extract FactInternetSales (Filtered by Date Range)
SELECT 
    f.ProductKey, 
    f.CustomerKey, 
    f.SalesOrderNumber, 
    f.OrderQuantity, 
    f.UnitPrice, 
    f.TotalProductCost, 
    f.SalesAmount, 
    f.TaxAmt, 
    f.Freight,
    f.OrderDate, 
    f.DueDate, 
    f.ShipDate, 
    t.SalesTerritoryCountry, 
    t.SalesTerritoryGroup,
    t.SalesTerritoryRegion
FROM dbo.FactInternetSales AS f
LEFT JOIN dbo.DimSalesTerritory AS t
    ON f.SalesTerritoryKey = t.SalesTerritoryKey
WHERE f.OrderDate BETWEEN '2012-01-01' AND '2013-12-31';

-- 4.2 Extract DimProduct (Enriched with Category & Subcategory)
SELECT 
    p.ProductKey, 
    p.EnglishProductName AS ProductName, 
    p.Color, 
    p.Size, 
    s.EnglishProductSubcategoryName AS SubcategoryName, 
    c.EnglishProductCategoryName AS CategoryName 
FROM DimProduct AS p
LEFT JOIN DimProductSubcategory AS s
    ON p.ProductSubcategoryKey = s.ProductSubcategoryKey
LEFT JOIN DimProductCategory AS c
    ON s.ProductCategoryKey = c.ProductCategoryKey;

-- 4.3 Extract DimCustomer (With Derived "Status" Column)
SELECT 
    cust.CustomerKey, 
    cust.FirstName, 
    cust.MiddleName, 
    cust.LastName, 
    cust.BirthDate, 
    cust.Gender, 
    cust.MaritalStatus, 
    cust.DateFirstPurchase, 
    geo.City, 
    geo.StateProvinceName,
    geo.EnglishCountryRegionName,
    CASE 
        WHEN YEAR(cust.DateFirstPurchase) >= 2011 THEN 'New'
        WHEN YEAR(cust.DateFirstPurchase) < 2012 THEN 'Old'
    END AS CustomerStatus
FROM dbo.DimCustomer AS cust
LEFT JOIN dbo.DimGeography AS geo
    ON cust.GeographyKey = geo.GeographyKey;