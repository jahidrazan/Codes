-- t1 collects all the products in the Bladblazer category
-- add brand, default supplier information
-- finds out total sales per during the period of Sep to December 

with t1 as (SELECT  ltm.product_id             AS PRODUCT_ID,
                    MAX(description)           AS DESCRIPTION, 
                    brand                      AS BRAND, 
                    s.name                     AS DEFAULT_SUPPLIER,
                    category                   AS CATEGORY,
                    root_category              AS ROOT_CATEGORY, 
                    p.cost_net                 AS COST_PER_UNIT,
                    p.stock_magento            AS STOCK_MAGENTO,

                     -- total sales in 2021: use it as a baseline for 2022
                    SUM(qty)                   AS TOTAL_QTY_SOLD_2021, 

                     -- avg sales per day during Sep to Dec period of 122 days
                    ROUND((SUM(qty)/ 121),2)   AS AVG_SALES_PER_DAY,


FROM `hbl-online.gcp_sql_bi.ORDER_DATA_LTM` ltm

LEFT JOIN `hbl-online.api.products` p
ON ltm.product_id = p.product_id

LEFT JOIN `hbl-online.api.suppliers` s
ON p.default_supplier_id= s.supplier_id

WHERE  EXTRACT (year from order_date) = 2021 

       -- only take Sep to December
       AND EXTRACT (month from order_date) in (9,10,11,12)
      
        -- do not include parent ids
       AND category like '%Bladblazer%' 
       
       -- only take the categories that are relaed to lamp
       AND ltm.product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`) 


GROUP BY 1,3,4,5,6,7,8
ORDER BY 5 DESC),

-- take the confirmed qty per product
t2 as (SELECT DISTINCT ppo.product_id, 
              CASE WHEN ppo.status_id = 4 THEN SUM(ppo.qty)  ELSE 0 END AS CONFIRMED

        FROM `hbl-online.gcp_sql_bi.pending_purchase_orders` ppo 

        WHERE ppo.product_id in (SELECT product_id
                           FROM t1) AND 
                           ppo.status_id = 4 AND ppo._sdc_deleted_at IS NULL
        GROUP BY  status_id, product_id),

-- take the backorder qty per product

t3 as (SELECT DISTINCT product_id, 
              CASE WHEN ppo.status_id = 2 THEN SUM(ppo.qty)  ELSE 0 END AS BACKORDER,
             

        FROM `hbl-online.gcp_sql_bi.pending_purchase_orders` ppo 
        WHERE product_id in (SELECT product_id
                           FROM t1) AND 
                          ppo.status_id = 2 AND ppo._sdc_deleted_at IS NULL
        GROUP BY  status_id, product_id),

-- add the confirmed and backorder information to all individual
-- products by joining table

t4 as (SELECT  t1.*, 
               CASE WHEN t2.CONFIRMED IS NULL THEN 0 ELSE t2.CONFIRMED END           AS CONFIRMED, 
               CASE WHEN t3.BACKORDER IS NULL THEN 0 ELSE t3.BACKORDER END           AS BACKORDER, 
               

            FROM t1

            LEFT JOIN t2
            ON t1.product_id = t2.product_id

            LEFT JOIN t3
            ON t1.product_id = t3.product_id
),


t5 as (SELECT *,

       -- consider the 2021 qty as baseline: subtruct CONFIRMED , BACKORDER and the existing STOCK_MAGENTO to find the future qty

       
       CASE WHEN STOCK_MAGENTO >= 0 AND  (STOCK_MAGENTO + CONFIRMED+BACKORDER) < TOTAL_QTY_SOLD_2021         THEN TOTAL_QTY_SOLD_2021 -(CONFIRMED+BACKORDER+STOCK_MAGENTO)

            -- when stock magento <0 then also add it to the 2021 sales
            WHEN STOCK_MAGENTO < 0  AND  (CONFIRMED+BACKORDER) < ( TOTAL_QTY_SOLD_2021+ABS(STOCK_MAGENTO))   THEN TOTAL_QTY_SOLD_2021 +ABS(STOCK_MAGENTO)-(CONFIRMED+BACKORDER)
            ELSE 0
            END AS ORDER_QTY
          FROM t4)
      
SELECT *,
     ROUND(ORDER_QTY*COST_PER_UNIT) AS ORDER_VALUE
FROM t5
--WHERE DEFAULT_SUPPLIER != 'EOL / Discontinued' AND ORDER_QTY > 0
ORDER BY ROUND(ORDER_QTY*COST_PER_UNIT) DESC




