-- the code is used to calculate total stock (stock hbs) and stock magento value

SELECT product_id, 
       stock_magento, 
       stock_hbs, 
       cost_net


FROM `hbl-online.api.products`

WHERE 
    
    
    -- exclude the parent product ids from the product table by 
    -- filtering out the parent product ids 
    product_id NOT IN (SELECT DISTINCT(parent_product_id) FROM `hbl-online.api.product_set_items`) 

    -- exclude the products that have less than 0 stock
    AND stock_magento >= 0
