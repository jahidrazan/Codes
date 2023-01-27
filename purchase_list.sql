


-- calculate the reorder point factor 

with reorder_point_factors as (

     SELECT hist.product_id,
     
            -- proporation of days when the product has less stock then 5 days calculated by: average sales last 42 days x 5 
            ROUND(100*SUM(CASE WHEN stock_magento > ROUND(pc42.mean * 5) THEN 0 ELSE 1 END)/28,2)   AS LOW_STOCK_PERCENTAGE_DAYS,

            -- the factor is added to 1 
            -- when the stock magento is greater than the last 42 days average sales (indicated by pc42.mean) then the days is not counted, and hence 0
            -- the reorder point factor > 1 for products with out-of-stock days in the last 28 days
            -- the reorder point factor = 0 for products with out-of-stock days in the last 28 days

            ROUND(1 + (SUM(CASE WHEN stock_magento > ROUND(pc42.mean * 5) THEN 0 ELSE 1 END)/28),2) AS REORDER_POINT_FACTOR

FROM `hbl-online.api_history.products` hist

LEFT JOIN `hbl-online.api.product_classifications` pcyr
ON pcyr.product_id = hist.product_id AND pcyr.period = 'year' AND pcyr.type = 'sales'


LEFT JOIN `hbl-online.api.product_classifications` pc42
ON pc42.product_id = hist.product_id AND pc42.period = '42_days' AND pc42.type = 'sales'


WHERE (hist.product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`)) 
AND ( pcyr.label in ('A+', 'A', 'B', 'C') )

AND DATE_DIFF(current_date(), hist.date, DAY) < 28

GROUP BY 1
ORDER BY reorder_point_factor

),


-- number of orders per product in the last 90 days, this is used if a product
-- is not a new product, has purchase suggestion but less than 3 orders in the last 90 days
-- the purchasers check that specific product and make a judgement is it is needed
-- it is used in the CHECK calculation in tableau

order_count AS (


  SELECT product_id,
         COUNT(DISTINCT(order_id)) as total_order_last_90_days


  FROM `hbl-online.gcp_sql_bi.ORDER_DATA_LTM`

  WHERE  DATE_DIFF(CURRENT_DATE(), EXTRACT(date from order_date), DAY) <= 90
         AND qty > 0
         AND product_id > 0
         AND order_type ='sales_order'
  
  GROUP BY product_id 

),

--- gathers all the required column from diffrent tables

t1 as (
            SELECT  p.PRODUCT_ID                                                        AS PRODUCT_ID, 
                    
                    -- sales class year
                    pcyr.label                                                          AS SALES_CLASS,
                    pc42_instock.label                                                  AS SALES_CLASS_IN_STOCK_42_DAYS,
                    p.name_nl                                                           AS PRODUCT_NAME,
                    p.ean                                                               AS EAN,
                    
                    -- label value 'new' indicates if the product is a new product
                    -- if the label is null then the product is not a new product
                    CASE WHEN pls.label IS NULL 
                         THEN 'NONE' ELSE pls.label END                                 AS LABEL,

               
                    p.status                                                            AS ZICHTBAARHEID,
                    
                    -- indicates if the product is a super sales items
                    -- these items are not purchased after the stock is finished
                    CASE WHEN p.product_id = ssp.product_id THEN 'YES'
                    ELSE 'NO'   END                                                     AS IS_SUPER_SALES_ITEM,

                    -- if it is a  automatisch uitschakelen items
                    -- if YES the product is not purchased after the stock is finished

                    CASE WHEN p.product_id = auto.product_id THEN 'YES'
                    ELSE 'NO'   END                                                     AS IS_AUTO_UIT_ITEM,
                     
                    
                    -- minimum order qty of a prouct : if the value is null then single item can be ordered
                    CASE WHEN p.product_id = moq.product_id THEN 
                          CAST(moq.minimum_qty AS INT64)
                         ELSE 1   END                                                   AS MOQ,

                 
                    -- minimum order qty of a prouct
                    CASE WHEN p.product_id = mdq.product_id THEN 
                          mdq.minimum_desired_qty ELSE 0
                    END                                                                 AS MIN_DESIRED_STOCK,


                    m.name                                                              AS BRAND,  
                    main_categories.name_nl                                             AS CATEGORY,
                    root_categories.name_nl                                             AS ROOT_CATEGORY,
                    
                    -- if there is no default supplier for a product (i.e the product is purhcased from traders) 
                    -- then 'NONE' is the value
                    CASE WHEN s.name IS NULL THEN 'NONE'
                        ELSE s.name END                                                 AS DEFAULT_SUPPLIER,

                    p.cost                                                              AS PER_UNIT_COST,
                    
                    CASE WHEN REORDER_POINT_FACTOR IS NULL THEN 1 ELSE
                              REORDER_POINT_FACTOR END                                  AS REORDER_POINT_FACTOR ,

                    CASE WHEN pc7.mean <= 0 THEN 0
                         ELSE ROUND(pc7.mean,2) END                                     AS AVG_SALES_LAST_7_DAYS, 

                    CASE WHEN pc42.mean <= 0 THEN 0
                         ELSE ROUND(pc42.mean,2) END                                    AS AVG_SALES_LAST_42_DAYS, 
    

                    CASE WHEN pcyr.mean <= 0 THEN 0
                         ELSE ROUND(pcyr.mean,2) END                                    AS AVG_SALES_LAST_365_DAYS,


                    CASE WHEN pcyr.label in ('A+', 'A', 'B') THEN 
                    
                                        CASE 

                                        -- average sales of last 42 days
                                        -- WHEN ROUND(pc42.mean,2) >0 THEN ROUND(pc42.mean,2) 
                                        
                                        -- take the max average of 7 and 42 days
                                        WHEN ROUND(GREATEST(pc7.mean,pc42.mean),2) >0 THEN  ROUND(GREATEST(pc7.mean,pc42.mean),2)
                                        ELSE 0   END

                          WHEN pcyr.label ='C' THEN 
                                       CASE WHEN ROUND(pc42.mean,2) >0 THEN  ROUND(pc42.mean,2) ELSE 0 END

                          WHEN pcyr.label = 'D' AND pls.label = 'new'
                                        THEN CASE WHEN ROUND(pc42.mean,2) >0 THEN  ROUND(pc42.mean,2) ELSE 0 END
                                       

                          ELSE 0

                    END AS   AVG_SALES_QTY,        
                    



                    p.stock_magento                                                     AS STOCK_MAGENTO,

                    CASE WHEN total_order_last_90_days IS NULL 
                         THEN 0 ELSE total_order_last_90_days END                       AS TOTAL_ORDER_LAST_90_DAYS,
                    
                    
                    -- when ZICHTBAARHEID = hidden then 0 order days
                    -- when ZICHTBAARHEID not hidden then order regular qty
                    
                    CASE WHEN p.status  != 'hidden' THEN 
                                        
                        CASE  WHEN s.name in ('Makita Nederland', 'Transferro B.V.', 'Transferro B.V. - Bosch') THEN 
                        
                                                                            (CASE WHEN pcyr.label in ('A+', 'A', 'B') THEN 10
                                                                                  WHEN pcyr.label = 'C' THEN 10
                                                                                  WHEN pcyr.label ='D' AND pls.label = 'new' THEN 10
                                                                                  ELSE 0 
                                                                                  END)
                                            
                                      ELSE 
                                            
                                            CASE  WHEN pcyr.label in ('A+', 'A') THEN 14
                                                  WHEN pcyr.label = 'B' THEN 7
                                                  WHEN pcyr.label = 'C' THEN 7
                                                  WHEN pcyr.label = 'D' AND pls.label = 'new' THEN 7
                                                  ELSE 0 END
                                        END 
                        
                           WHEN p.status  = 'hidden' THEN 0
                          

                    END AS ORDER_DAYS,
                   

                    -- corrected lead time is the lead time x reorder point factor
                    -- this is used to calculate reorder point 
                    -- since the lead time if often not reliable, a lead time has been assigned after the alingnment with the
                    -- stakeholders

                    CASE WHEN REORDER_POINT_FACTOR IS NOT NULL THEN
                         
                         -- regular reorder point
                         CASE WHEN s.name in ('Makita Nederland', 'Transferro B.V.', 'Transferro B.V. - Bosch') THEN 10*REORDER_POINT_FACTOR
                        
                         -- for low cash emergency the reorder point is 5 days for these suppliers to reduce stock magento value
                         -- CASE WHEN s.name in ('Makita Nederland', 'Transferro B.V.') THEN 5*REORDER_POINT_FACTOR

                       
                         -- regular reorder point for suppliers other than Transferro and Makita Nederland 
                         -- ELSE 28*REORDER_POINT_FACTOR

                         -- for low cash emergency the reorder point is 14 days
                         ELSE 14*REORDER_POINT_FACTOR

                         END 
   
                    ELSE 14  
                         
                    
                    END AS CORRECTED_LEAD_TIME

FROM `hbl-online.api.products` p

LEFT JOIN reorder_point_factors rpf
ON p.product_id = rpf.product_id

LEFT JOIN order_count oc
ON p.product_id = oc.product_id

LEFT JOIN `hbl-online.api.manufacturers` m
ON p.manufacturer_id = m.manufacturer_id

LEFT JOIN `hbl-online.api.product_labels` pls
ON p.product_id = pls.product_id

LEFT JOIN `hbl-online.api.product_set_items` psi
ON p.product_id = psi.parent_product_id

LEFT JOIN `hbl-online.purchase_queries.super_sale_products_for_purchase` ssp
ON p.product_id = ssp.product_id

LEFT JOIN `hbl-online.purchase_queries.minimum_order_qty_for_purchase` moq
ON p.product_id = moq.product_id

LEFT JOIN `hbl-online.purchase_queries.minimum_desired_qty_for_purchase` mdq
ON p.product_id = mdq.product_id


LEFT JOIN `hbl-online.purchase_queries.automatisch_uitschakelen_purchase` auto
ON p.product_id = auto.product_id

LEFT JOIN `hbl-online.api.suppliers` s
ON p.default_supplier_id= s.supplier_id

LEFT JOIN `hbl-online.api.product_classifications` pc7
ON pc7.product_id = p.product_id AND pc7.period = 'week' AND pc7.type = 'sales'


LEFT JOIN `hbl-online.api.product_classifications` pc42
ON pc42.product_id = p.product_id AND pc42.period = '42_days' AND pc42.type = 'sales'


LEFT JOIN `hbl-online.api.product_classifications` pc42_instock
ON pc42_instock.product_id = p.product_id AND pc42_instock.period = '42_days' AND pc42_instock.type = 'sales_in_stock'

LEFT JOIN `hbl-online.api.product_classifications` pcyr
ON pcyr.product_id = p.product_id AND pcyr.period = 'year' AND pcyr.type = 'sales'

LEFT JOIN `hbl-online.api.categories` AS main_categories
ON main_categories.category_id = p.main_category_id


LEFT JOIN `hbl-online.api.categories` AS root_categories
ON root_categories.category_id = main_categories.root_category_id




WHERE (p.product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`) 

-- exclude BF assortments : this is used immidately after the Black Friday period as due to high sales of the selected items
-- the Black Friday assortments can not be purchased at the last 42 days avg sales, 
-- rather needs to be purchased pre-BF avg sales qty basis 

-- AND (p.product_id NOT IN (SELECT DISTINCT product_id FROM `hbl-online.purchase_queries.BF_assortment_sales`))


-- only take A+, A, B and C product. Take D products only if the stock_magento < 0
AND ( pcyr.label in ('A+', 'A', 'B', 'C') OR (pcyr.label = 'D' AND p.stock_magento <0 ))) OR 

(pls.label ='new' AND pls.product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`))
),


-- confirmed qty for the products in t1
t2 as (SELECT DISTINCT ppo.product_id, 
              CASE WHEN ppo.status_id = 4 THEN SUM(ppo.qty)  ELSE 0 END AS CONFIRMED

        FROM `hbl-online.gcp_sql_bi.pending_purchase_orders` ppo 

        WHERE ppo.product_id in (SELECT product_id
                           FROM t1) AND 
                           ppo.status_id = 4 AND ppo._sdc_deleted_at IS NULL
        GROUP BY  status_id, product_id),

-- take only the ordered quantity of the prodcuts for the products in t1

t3 as (SELECT DISTINCT product_id, 
          CASE WHEN ppo.status_id = 3 THEN SUM(ppo.qty)  ELSE 0 END AS ORDERED
          

     FROM `hbl-online.gcp_sql_bi.pending_purchase_orders` ppo 
     WHERE product_id in (SELECT product_id
                         FROM t1) AND 
                         ppo.status_id = 3 AND ppo._sdc_deleted_at IS NULL
     GROUP BY  status_id, product_id),

-- take only the back order quantity of the prodcuts from pending purchase order table 
-- for the products in t1

    t4 as (SELECT DISTINCT product_id, 
              CASE WHEN ppo.status_id = 2 THEN SUM(ppo.qty)  ELSE 0 END AS BACKORDER,
             

        FROM `hbl-online.gcp_sql_bi.pending_purchase_orders` ppo 
        WHERE product_id in (SELECT product_id
                           FROM t1) AND 
                          ppo.status_id = 2 AND ppo._sdc_deleted_at IS NULL
        GROUP BY  status_id, product_id),


-- take only the received quantity of the prodcuts from pending purchase order table 
-- for the products in t1

    t5 as (SELECT DISTINCT product_id, 
              CASE WHEN ppo.status_id = 5 THEN SUM(ppo.qty)  ELSE 0 END AS RECEIVED,
             

        FROM `hbl-online.gcp_sql_bi.pending_purchase_orders` ppo 
        WHERE product_id in (SELECT product_id
                           FROM t1) AND 
                          ppo.status_id = 5 AND ppo._sdc_deleted_at IS NULL
        GROUP BY  status_id, product_id),

-- join t1, t2,t3,t4 to get all the product information
-- and order, backorder and confirmed quantity

-- calculate reorder point based on the formula: corrected lead time x average slaes last 42 days

t6 as (SELECT t1.*, 
              

               CASE WHEN t3.ORDERED IS NULL THEN 0 ELSE t3.ORDERED     END                               AS ORDERED,

               CASE WHEN t2.CONFIRMED IS NULL THEN 0 ELSE t2.CONFIRMED END                               AS CONFIRMED, 

               CASE WHEN t4.BACKORDER IS NULL THEN 0 ELSE t4.BACKORDER END                               AS BACKORDER, 

               CASE WHEN (t5.RECEIVED IS NULL OR t5.RECEIVED <0) THEN 0 
                    ELSE t5.RECEIVED END                                                                 AS RECEIVED, 

              CASE WHEN  t1.SALES_CLASS  in ('A+', 'A', 'B', 'C') THEN 
                         ROUND((t1.CORRECTED_LEAD_TIME*AVG_SALES_LAST_42_DAYS))

                         ELSE 0
                         END                                                                             AS REORDER_POINT,


            FROM t1


            LEFT JOIN t2
            ON t1.product_id = t2.product_id

            LEFT JOIN t3
            ON t1.product_id = t3.product_id

            LEFT JOIN t4
            ON t1.product_id = t4.product_id

            LEFT JOIN t5
            ON t1.product_id = t5.product_id


            GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23, 24,25,26,27,28,29),
t7 as (SELECT t6.*,
                                   
              -- when stock magento <= reorder point and if the product is not a super sales or  automatisch uitschakelen item
              -- then the primary qty is determined based on the avg_sales qty and the primary qty

              CASE   WHEN  STOCK_MAGENTO <= REORDER_POINT AND (IS_SUPER_SALES_ITEM = 'NO' AND IS_AUTO_UIT_ITEM = 'NO') THEN

                              ROUND((ORDER_DAYS* AVG_SALES_QTY))

                              ELSE 0
                        

              END                                                                        AS PRIMARY_QTY
       
FROM t6),

t8 as (SELECT *,
      CASE 
           -- if a product has some stock, and the ordered, confirmed, backorder and received qty is still smaller than the primary qty
           -- then the PRIMARY_QTY-(ORDERED+ CONFIRMED + BACKORDER + RECEIVED) needs to be ordered

           WHEN (STOCK_MAGENTO >= 0 AND ((ORDERED + CONFIRMED + BACKORDER + RECEIVED) < PRIMARY_QTY)) THEN PRIMARY_QTY-(ORDERED+ CONFIRMED + BACKORDER + RECEIVED)

           -- if a product has negative stock and the ordered, confirmed, backorder and received qty is still smaller than the primary qty
           -- then the the negative stock also needs to be made up

           WHEN (STOCK_MAGENTO <0 AND ((ORDERED + CONFIRMED + BACKORDER + RECEIVED) < (PRIMARY_QTY + ABS(STOCK_MAGENTO))))

                                           THEN (PRIMARY_QTY + ABS(STOCK_MAGENTO) -( ORDERED + CONFIRMED + BACKORDER + RECEIVED))
          
          -- if the above two conditions are not met then no need to order the product
          ELSE 0

     -- in tableau this is called ORDER_QTY_CALC to indicate this is from calculation 
     END AS ORDER_QTY
FROM t7),

t9 as (SELECT *,

      -- in tableau this is called ORDER_VALUE_CALC : currently this has no use therefore actually t9 part could be deleted
      ROUND(ORDER_QTY * PER_UNIT_COST) AS ORDER_VALUE,

           
FROM t8
ORDER BY ORDER_QTY DESC)


SELECT *
FROM t9

