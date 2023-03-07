-- the code is created for legal team to report the sales of France 
-- for the year 2022
-- contains product id, product name, root category, category and qty of items shipped
-- convert all products into child ids

SELECT product_id                           as product_id,
       MAX(product_name)                    as product_name, 
       root_category,
       category,

       country,

       SUM(quantity_sold)                   as quantity_sold,
       
            FROM

            (    -- take all the product information for reporting 
                 -- take only the child ids

                  SELECT product_id                           as product_id,
                         -- take a single name for a product id 
                         MAX(ltm.description)                 as product_name,
                         root_category,
                         category,
                         CASE WHEN website_id = 7 THEN 'NL'
                         ELSE 'FR' END 
                                                              as country,
                         SUM(qty)                             as quantity_sold


                  FROM `hbl-online.gcp_sql_bi.ORDER_DATA_LTM` ltm

                        WHERE ltm.status = 5
                        AND ltm.year_number  = 2022 
                        AND ltm.order_type in ('sales_order')
                        AND website_id in (7, 8)
                        AND product_id not in (SELECT parent_product_id FROM `hbl-online.api.product_set_items`)
                        AND product_id >0
                        GROUP BY 1,3,4,5
                  
                  
                        

                  UNION ALL

                  -- take all the product information for reporting 
                  -- only for the parent products 
                  -- convert the parent products into child ids 
                  SELECT psi.child_product_id                 as product_id, 

                         -- take a single name for a product id 
                         MAX(ltm.description)                 as product_name,
                         root_category,
                         category,
                        CASE WHEN website_id = 7 THEN 'NL'
                         ELSE 'FR' END 
                                                              as country,
                        -- convert the quantities to child ids without any parent ids
                         SUM(ltm.qty * psi.quantity)          as quantity_sold

                  FROM `hbl-online.gcp_sql_bi.ORDER_DATA_LTM` ltm

                  INNER JOIN `hbl-online.api.product_set_items` psi 
                  ON ltm.product_id = psi.parent_product_id

                  WHERE ltm.status = 5 
                        AND ltm.year_number  = 2022 
                        AND ltm.line_type = 'COMPOSITION'
                        AND ltm.order_type in ('sales_order')
                        AND website_id in (7, 8)
                        AND product_id >0
                        AND product_id  in (SELECT parent_product_id FROM `hbl-online.api.product_set_items`)
                  
                  GROUP BY 1,3,4,5) as t1


      

            
      GROUP BY 1,3,4,5
      ORDER BY 6 DESC;
