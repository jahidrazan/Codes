-- takes the product id and per unit cost from the products
-- product set items table is joined to exclude the parent product id columns 

with t1 as (
            SELECT  p.PRODUCT_ID                                                        AS PRODUCT_ID, 
                    p.cost                                                              AS PER_UNIT_COST


FROM `hbl-online.api.products` p

LEFT JOIN `hbl-online.api.product_set_items` psi
ON p.product_id = psi.parent_product_id

WHERE (p.product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`))), 



-- take only the confirmed quantity of the prodcuts from pending purchase order table 
-- for the products in t1

t2 as (SELECT DISTINCT ppo.product_id, 
              CASE WHEN ppo.status_id = 4 THEN SUM(ppo.qty)  ELSE 0 END AS CONFIRMED

        FROM `hbl-online.gcp_sql_bi.pending_purchase_orders` ppo 

        WHERE ppo.product_id in (SELECT product_id
                           FROM t1) AND 
                           ppo.status_id = 4 AND ppo._sdc_deleted_at IS NULL
        GROUP BY  status_id, product_id),

-- take only the ordered quantity of the prodcuts from pending purchase order table 
-- for the products in t1

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


-- take only the back order quantity of the prodcuts from pending purchase order table 
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

t6 as (SELECT t1.*, 
              

               CASE WHEN t3.ORDERED IS NULL THEN 0 ELSE t3.ORDERED     END                               AS ORDERED,
               CASE WHEN t2.CONFIRMED IS NULL THEN 0 ELSE t2.CONFIRMED END                               AS CONFIRMED, 
               CASE WHEN t4.BACKORDER IS NULL THEN 0 ELSE t4.BACKORDER END                               AS BACKORDER, 
               CASE WHEN (t5.RECEIVED IS NULL OR t5.RECEIVED <0) THEN 0 ELSE t5.RECEIVED END             AS RECEIVED, 



            FROM t1


            LEFT JOIN t2
            ON t1.product_id = t2.product_id

            LEFT JOIN t3
            ON t1.product_id = t3.product_id

            LEFT JOIN t4
            ON t1.product_id = t4.product_id

            LEFT JOIN t5
            ON t1.product_id = t5.product_id


            GROUP BY 1,2,3,4,5,6)
SELECT *
FROM t6