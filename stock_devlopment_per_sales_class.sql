-- take various revelvant product information by joining the product history table with
-- products, manufacturer, suppliers, product classifications and categories table


with t1 as (
  
  SELECT            p.PRODUCT_ID                                                        AS PRODUCT_ID, 
                    p.date                                                              AS DATE,
                    pcyr.label                                                          AS SALES_CLASS_YEAR,
                    pc42.label                                                          AS SALES_CLASS_LAST_42_DAYS,

                    m.name                                                              AS BRAND,  
                    main_categories.name_nl                                             AS CATEGORY,
                    root_categories.name_nl                                             AS ROOT_CATEGORY,



                    CASE WHEN pls.label IS NULL 
                         THEN 'NONE' ELSE pls.label END                                 AS LABEL,


                    CASE WHEN p.product_id = ssp.product_id THEN 'YES'
                    ELSE 'NO'   END                                                     AS IS_SUPER_SALES_ITEM,

                    

                    p.cost_net                                                          AS PER_UNIT_COST,

                    p.stock_magento                                                     AS STOCK_MAGENTO,

                    ROUND(CASE WHEN p.stock_magento> 0 THEN 
                               p.cost_net * p.stock_magento
                               ELSE 0 END, 2)                               AS STOCK_VALUE, 





FROM `hbl-online.api_history.products` p


LEFT JOIN `hbl-online.api.products` products 
ON p.product_id = products.product_id 


LEFT JOIN `hbl-online.api.categories` AS main_categories
ON main_categories.category_id = products.main_category_id


LEFT JOIN `hbl-online.api.categories` AS root_categories
ON root_categories.category_id = main_categories.root_category_id

LEFT JOIN `hbl-online.api.manufacturers` m
ON products.manufacturer_id = m.manufacturer_id

LEFT JOIN `hbl-online.api.product_labels` pls
ON p.product_id = pls.product_id

LEFT JOIN `hbl-online.purchase_queries.Jahid_super_sale_products` ssp
ON p.product_id = ssp.product_id




LEFT JOIN `hbl-online.api.product_classifications` pcyr
ON pcyr.product_id = p.product_id AND pcyr.period = 'year' AND pcyr.type = 'sales'

LEFT JOIN `hbl-online.api.product_classifications` pc42
ON pc42.product_id = p.product_id AND pc42.period = '42_days' AND pc42.type = 'sales'



-- exclude the product that have 0 or negative stock magento 

WHERE p.stock_magento >0 

-- exclude the parent product ids  
      AND p.product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`)

GROUP BY 1,2,3,4,5,6,7,8,9,10,11
ORDER BY  STOCK_VALUE DESC)

SELECT *
FROM t1