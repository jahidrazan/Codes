-- this code is used to track current stock health 
-- table t1 takes the product ids (excludes the parent product ids and excludes products that have stock_magento <0 ), and other product related information
-- by joining the product table with other associated api tables

with t1 as (
  
  SELECT            p.PRODUCT_ID                                                        AS PRODUCT_ID, 
                    p.name_nl                                                           AS PRODUCT_NAME,
                    pcyr.label                                                          AS SALES_CLASS_YEAR,
                    pc42.label                                                          AS SALES_CLASS_LAST_42_DAYS,
                    
                    CASE WHEN pcyr_in_stock.mean <= 0 THEN 0 
                         ELSE pcyr_in_stock.mean END                                    AS AVG_SALES_IN_STOCK_365_DAYS,

                    CASE WHEN pc42_in_stock.mean <= 0 THEN 0 
                          ELSE pc42_in_stock.mean END                                  AS AVG_SALES_IN_STOCK_42_DAYS,

                    CASE WHEN pc7_in_stock.mean <= 0 THEN 0
                         ELSE pc7_in_stock.mean 
                         END                                                            AS AVG_SALES_IN_STOCK_7_DAYS_DAYS,


                    CASE WHEN pls.label IS NULL 
                         THEN 'NONE' ELSE pls.label END                                 AS LABEL,


                    p.status                                                            AS ZICHTBAARHEID,

                    CASE WHEN p.product_id = ssp.product_id THEN 'YES'
                    ELSE 'NO'   END                                                     AS IS_SUPER_SALES_ITEM,

                    m.name                                                              AS BRAND,  

                    main_categories.name_nl                                             AS CATEGORY,

                    root_categories.name_nl                                             AS ROOT_CATEGORY,
                    
                    CASE WHEN s.name IS NULL THEN 'NONE'
                        ELSE s.name END                                                 AS DEFAULT_SUPPLIER,
                    

                    p.cost_net                                                          AS PER_UNIT_COST,

                    p.stock_magento                                                     AS STOCK_MAGENTO,

                    CASE WHEN pc42_in_stock.mean <= 0 THEN 0
                         ELSE p.stock_magento / pc42_in_stock.mean
                         END                                                            AS ESTIMATED_STOCK_DAYS, 

                    ROUND(p.cost_net * p.stock_magento,2)                               AS STOCK_VALUE, 





FROM `hbl-online.api.products` p

LEFT JOIN `hbl-online.api.manufacturers` m
ON p.manufacturer_id = m.manufacturer_id

LEFT JOIN `hbl-online.api.product_labels` pls
ON p.product_id = pls.product_id

LEFT JOIN `hbl-online.purchase_queries.super_sale_products_for_purchase` ssp
ON p.product_id = ssp.product_id


LEFT JOIN `hbl-online.api.suppliers` s
ON p.default_supplier_id= s.supplier_id


LEFT JOIN `hbl-online.api.product_classifications` pcyr_in_stock
ON pcyr_in_stock.product_id = p.product_id AND pcyr_in_stock.period = 'year' AND pcyr_in_stock.type = 'sales_in_stock'

LEFT JOIN `hbl-online.api.product_classifications` pc42_in_stock
ON pc42_in_stock.product_id = p.product_id AND pc42_in_stock.period = '42_days' AND pc42_in_stock.type = 'sales_in_stock'


LEFT JOIN `hbl-online.api.product_classifications` pc7_in_stock
ON pc7_in_stock.product_id = p.product_id AND pc7_in_stock.period = 'week' AND pc7_in_stock.type = 'sales_in_stock'



LEFT JOIN `hbl-online.api.product_classifications` pcyr
ON pcyr.product_id = p.product_id AND pcyr.period = 'year' AND pcyr.type = 'sales'

LEFT JOIN `hbl-online.api.product_classifications` pc42
ON pc42.product_id = p.product_id AND pc42.period = '42_days' AND pc42.type = 'sales'


LEFT JOIN `hbl-online.api.categories` AS main_categories
ON main_categories.category_id = p.main_category_id


LEFT JOIN `hbl-online.api.categories` AS root_categories
ON root_categories.category_id = main_categories.root_category_id





WHERE stock_magento >0 

      AND p.product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`)

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
ORDER BY  STOCK_VALUE DESC),


t2 as (

  SELECT product_id,

                      
        SUM(ltm.qty)                                                        AS QTY_SOLD,

        SUM(line_total_ex_vat)                                              AS TOTAL_REVENUE,
        SUM(margin_total_net)                                               AS TOTAL_MARGIN,


        CASE WHEN SUM(line_total_ex_vat) > 0 THEN
        
          ROUND(100*SUM(margin_total_net)/ SUM(line_total_ex_vat),2) 
          ELSE 0 END                                                         AS GROSS_MARGIN_PERCENTAGE

       FROM `hbl-online.gcp_sql_bi.ORDER_DATA_LM` ltm 
      
       WHERE ltm.product_id in (SELECT product_id from t1) 
             AND EXTRACT(date from order_date) >= DATE_SUB(current_date(), INTERVAL 29 DAY) 

       GROUP BY 1



),

t3 as (SELECT t1.*, 

       CASE WHEN t2.QTY_SOLD IS NULL THEN 0 ELSE t2.QTY_SOLD END                              AS QTY_SOLD,

       CASE WHEN t2.TOTAL_REVENUE IS NULL THEN 0 ELSE t2.TOTAL_REVENUE END                    AS TOTAL_REVENUE ,

       CASE WHEN t2.TOTAL_MARGIN IS NULL THEN 0 ELSE t2.TOTAL_MARGIN END                      AS TOTAL_MARGIN,
       CASE WHEN t2.GROSS_MARGIN_PERCENTAGE IS NULL THEN 0
            ELSE t2.GROSS_MARGIN_PERCENTAGE END                                               AS GROSS_MARGIN_PERCENTAGE

FROM t1
LEFT JOIN t2
ON t1.PRODUCT_ID = t2.product_id),


t4 as (

SELECT *,

      CASE 
        WHEN STOCK_VALUE = 0 THEN 0 
          
        WHEN STOCK_VALUE >0 AND AVG_SALES_IN_STOCK_42_DAYS = 0 AND AVG_SALES_IN_STOCK_365_DAYS > 0 THEN STOCK_VALUE 
        
        ELSE 0 
        END     AS SUM_OF_NON_MOVING_42_DAYS,


      CASE 

        WHEN STOCK_VALUE = 0 THEN 0 
        
        WHEN STOCK_VALUE >0 AND AVG_SALES_IN_STOCK_42_DAYS >0 AND  ESTIMATED_STOCK_DAYS < 31   THEN STOCK_VALUE 

        WHEN STOCK_VALUE >0 AND AVG_SALES_IN_STOCK_42_DAYS >0 AND  ESTIMATED_STOCK_DAYS > 30   THEN (30 * STOCK_VALUE)  / ESTIMATED_STOCK_DAYS 
        
        ELSE 0 
        END  AS SUM_OF_0_30_DGN,


      CASE 
        WHEN STOCK_VALUE = 0 THEN 0 

        WHEN STOCK_VALUE >0 AND AVG_SALES_IN_STOCK_42_DAYS >0 AND  (ESTIMATED_STOCK_DAYS > 30 AND ESTIMATED_STOCK_DAYS < 91)   
        
              THEN ((ESTIMATED_STOCK_DAYS-30) * STOCK_VALUE)  / ESTIMATED_STOCK_DAYS 

        WHEN STOCK_VALUE >0 AND (AVG_SALES_IN_STOCK_42_DAYS >0 AND  ESTIMATED_STOCK_DAYS > 90 )   
              THEN ((90-30) * STOCK_VALUE)  / ESTIMATED_STOCK_DAYS 
              
        ELSE 0 
        END  AS SUM_OF_31_90_DGN,


   

      CASE 
        WHEN STOCK_VALUE = 0 THEN 0 
        WHEN STOCK_VALUE >0 AND AVG_SALES_IN_STOCK_42_DAYS >0 AND  (ESTIMATED_STOCK_DAYS > 90 AND ESTIMATED_STOCK_DAYS < 181)   THEN ((ESTIMATED_STOCK_DAYS-90) * STOCK_VALUE)  / ESTIMATED_STOCK_DAYS 
        WHEN STOCK_VALUE >0 AND (AVG_SALES_IN_STOCK_42_DAYS >0 AND  ESTIMATED_STOCK_DAYS > 180 )   THEN ((180-90) * STOCK_VALUE)  / ESTIMATED_STOCK_DAYS 
        ELSE 0 
        END  AS SUM_OF_91_180_DGN,


      CASE 
        WHEN STOCK_VALUE = 0 THEN 0 
        WHEN STOCK_VALUE >0 AND AVG_SALES_IN_STOCK_42_DAYS >0 AND  (ESTIMATED_STOCK_DAYS > 180 AND ESTIMATED_STOCK_DAYS < 366)    THEN ((ESTIMATED_STOCK_DAYS-180) * STOCK_VALUE)  / ESTIMATED_STOCK_DAYS 
        WHEN STOCK_VALUE >0 AND (AVG_SALES_IN_STOCK_42_DAYS >0 AND  ESTIMATED_STOCK_DAYS > 365)  THEN ((365-180) * STOCK_VALUE)  / ESTIMATED_STOCK_DAYS 
        ELSE 0
        END  AS SUM_OF_180_365_DGN,



      CASE 
        WHEN STOCK_VALUE = 0 THEN 0 
        WHEN STOCK_VALUE >0 AND (AVG_SALES_IN_STOCK_42_DAYS >0 AND ESTIMATED_STOCK_DAYS > 365)  THEN ((ESTIMATED_STOCK_DAYS-365) * STOCK_VALUE)  / ESTIMATED_STOCK_DAYS 
        ELSE 0 
        END AS MORE_THAN_365_DGN,

      CASE 
        WHEN STOCK_VALUE >0 AND (AVG_SALES_IN_STOCK_42_DAYS = 0 AND AVG_SALES_IN_STOCK_365_DAYS = 0) THEN STOCK_VALUE 
        ELSE 0 
        END  AS SUM_OF_NON_MOVING_365_DAYS
      
FROM t3
ORDER BY STOCK_VALUE DESC)

SELECT *
FROM t4
