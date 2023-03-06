-- this code can be used to estimate expected sales for 160 days
with t1 as (SELECT  DISTINCT(p.product_id)                               AS PRODUCT_ID, 

                    CASE WHEN pl.label = 'new' THEN pl.label
                         ELSE 'default' END                              AS NEW_PRODUCT_OR_NOT, 

                    p.name_nl                                            AS PRODUCT_NAME,
                    p.cost                                               AS PURCHASE_PRICE,
                    s.name                                               AS DEFAULT_SUPPLIER,

                    ltm.root_category                                    AS ROOT_CATEGORY, 
                    pc1.label                                            AS SALES_CLASS_YEAR,  

                    pc1.absolute                                         AS TOTAL_SALES_LAST_YEAR,
                    ROUND(pc1.mean,2)                                    AS AVG_DAILY_SALES_LAST_YEAR,

                    pc.absolute                                          AS TOTAL_SALES_IN_STOCK_LAST_YEAR,
                    ROUND(pc.mean,2)                                     AS AVG_DAILY_SALES_WHILE_IN_STOCK,
        
                    p.stock_magento                                      AS STOCK_MAGENTO,

                    -- the code is used for purchasing items for 160 days

                    ROUND(pc.mean*160)                                   AS PRIMARY_QTY                              





FROM `hbl-online.api.products` p

LEFT JOIN `hbl-online.api.manufacturers` m
ON p.manufacturer_id = m.manufacturer_id

LEFT JOIN `hbl-online.gcp_sql_bi.ORDER_DATA_LTM` ltm 
ON p.product_id = ltm.product_id

LEFT JOIN `hbl-online.api.product_classifications` pc
ON pc.product_id = p.product_id AND pc.period = 'year' AND pc.type = 'sales_in_stock'

LEFT JOIN `hbl-online.api.product_classifications` pc1
ON pc1.product_id = p.product_id AND pc1.period = 'year' AND pc1.type = 'sales'


LEFT JOIN `hbl-online.api.suppliers` s
ON p.default_supplier_id= s.supplier_id

LEFT JOIN `hbl-online.api.product_labels` pl
ON p.product_id = pl.product_id




WHERE p.product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`) 
      AND pc1.absolute > 0
      AND m.name = 'Festool'

),

t2 as (SELECT DISTINCT ppo.product_id, 
              CASE WHEN ppo.status_id = 4 THEN SUM(ppo.qty)  ELSE 0 END AS CONFIRMED

        FROM `hbl-online.gcp_sql_bi.pending_purchase_orders` ppo 

        WHERE ppo.product_id in (SELECT product_id
                           FROM t1) AND 
                           ppo.status_id = 4 AND ppo._sdc_deleted_at IS NULL
        GROUP BY  status_id, product_id),

t3 as (SELECT DISTINCT product_id, 
              CASE WHEN ppo.status_id = 2 THEN SUM(ppo.qty)  ELSE 0 END AS BACKORDER,
             

        FROM `hbl-online.gcp_sql_bi.pending_purchase_orders` ppo 
        WHERE product_id in (SELECT product_id
                           FROM t1) AND 
                          ppo.status_id = 2 AND ppo._sdc_deleted_at IS NULL
        GROUP BY  status_id, product_id),


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
       CASE WHEN STOCK_MAGENTO >= 0 AND  (STOCK_MAGENTO + CONFIRMED+BACKORDER) < PRIMARY_QTY      THEN PRIMARY_QTY-(CONFIRMED+BACKORDER+STOCK_MAGENTO)
            WHEN STOCK_MAGENTO < 0  AND  (CONFIRMED+BACKORDER) < (PRIMARY_QTY+ABS(STOCK_MAGENTO)) THEN PRIMARY_QTY+ABS(STOCK_MAGENTO)-(CONFIRMED+BACKORDER)
            ELSE 0
            END AS ORDER_QTY
          FROM t4)
      
SELECT *,
     ROUND(ORDER_QTY*PURCHASE_PRICE) AS ORDER_VALUE
FROM t5
WHERE DEFAULT_SUPPLIER != 'EOL / Discontinued' AND ORDER_QTY > 0
ORDER BY ROUND(ORDER_QTY*PURCHASE_PRICE) DESC

     
