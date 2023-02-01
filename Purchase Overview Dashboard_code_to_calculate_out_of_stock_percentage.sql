-- The code is used to show the out of stock percentage per sales class trend over the 90 days period
-- To gather the revelvant product information required for the analysis 
-- product history table that contains the historical record of stock values has been joined 
-- with by joining the product table, manufacturer, suppliers, product classifications and categories table
-- class D products and products with avg daily sales of last 42 days <0.05 have been excluded from this analysis

SELECT      DISTINCT p.product_id                          AS PRODUCT_ID, 
            date, 
            m.name                                         AS BRAND,  
            main_categories.name_nl                        AS CATEGORY,
            root_categories.name_nl                        AS ROOT_CATEGORY,

            CASE WHEN p.stock_magento IS NULL THEN 0

                  ELSE p.stock_magento END                 AS STOCK_MAGENTO, 



             p.cost_net, 
             pc.label                                      AS SALES_CLASS_YEAR

FROM `hbl-online.api_history.products` p



LEFT JOIN `hbl-online.api.products` products 
ON p.product_id = products.product_id 


LEFT JOIN `hbl-online.api.categories` AS main_categories
ON main_categories.category_id = products.main_category_id


LEFT JOIN `hbl-online.api.categories` AS root_categories
ON root_categories.category_id = main_categories.root_category_id

LEFT JOIN `hbl-online.api.manufacturers` m
ON products.manufacturer_id = m.manufacturer_id



LEFT JOIN `hbl-online.api.suppliers` s
ON products.default_supplier_id = s.supplier_id


LEFT JOIN `hbl-online.api.product_classifications` pc
ON pc.product_id = p.product_id AND pc.period = 'year' AND pc.type = 'sales'


LEFT JOIN `hbl-online.api.product_classifications` pc42
ON pc42.product_id = p.product_id AND pc42.period = '42_days' AND pc.type = 'sales'


WHERE 
      -- exclude parent product ids
      p.product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`) 

      -- exclude low sales products that we are not purchasing 
      AND pc42.mean >= 0.05

      -- exluce hidden products
      AND products.status != 'hidden'

      -- exclude super sales items
      AND p.product_id NOT IN (SELECT product_id FROM `hbl-online.purchase_queries.super_sale_products_for_purchase`)
     
       -- exclude EOL items 
      AND s.name != 'EOL / Discontinued'

      -- last 90 days history only
      AND date >= current_date()-90
