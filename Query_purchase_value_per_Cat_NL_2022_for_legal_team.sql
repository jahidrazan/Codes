-- This code I have used to create a summary report for the legal team
-- contains the product sold in different category, in NL (website id = 7)
-- for different suppliers (i.e. OEM, traders etc.)


with t1 AS (SELECT  ltm.product_id                       AS PRODUCT_ID, 
                    ltm.description                      AS PRODUCT_NAME, 
                    ltm.brand                            AS PRODUCT_BRAND, 
                    ltm.category                         AS CATEGORY, 
                    s.name                               AS DEFAULT_SUPPLIER, 
                    CASE WHEN s.type IS NULL THEN 'unknown' 
                    ELSE s.type END                      AS SUPPLIER_TYPE, 
                    SUM(purchase_net)                    AS TOTAL_PURCHASE_VALUE,


FROM `hbl-online.gcp_sql_bi.ORDER_DATA_LTM` ltm

LEFT JOIN `hbl-online.api.products` p
ON p.product_id = ltm.product_id

LEFT JOIN `hbl-online.api.suppliers` s
ON p.default_supplier_id = s.supplier_id

WHERE EXTRACT (year from order_date) = 2022 AND ltm.status = 5 
      AND ltm.product_id >0 
      AND website_id = 7

GROUP BY 1,2,3,4,5,6)

SELECT DEFAULT_SUPPLIER, 
       SUPPLIER_TYPE, 
       CATEGORY, 
       SUM(TOTAL_PURCHASE_VALUE) AS TOTAL_PURCHASE_VALUE

FROM t1

GROUP BY 1,2,3