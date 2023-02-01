-- This code is used to calculate the percentage of revenue coming from per sales class (sales class year is used)
-- Also, to show the percentage of products per sales class and percentafe of orders
-- shipped within the number of days

SELECT             ltm.product_id                                                      AS product_id,
                   order_id                                                            AS ORDER_ID,
                   day_name                                                            AS day_name,
                   qty                                                                 AS qty,
                   pcyr.label                                                          AS sales_class,
                   

                   -- extract the information whether it is a weekday or weekend 
                   CASE WHEN day_name  in ('Saturday', 'Sunday') 
                        THEN 'YES' ELSE 'NO' 
                         END AS IS_WEEKEND,
                   
                   -- extract date from order date 
                   DATE(order_date) as order_date,
                   line_total_ex_vat,
                   shipped_in,

FROM `hbl-online.gcp_sql_bi.ORDER_DATA_LTM`  ltm 


-- take only the sales class year

LEFT JOIN `hbl-online.api.product_classifications` pcyr
ON pcyr.product_id = ltm.product_id AND pcyr.period = 'year' AND pcyr.type = 'sales'

WHERE 
      -- only take sales order and follow up shipment

      order_type in ('sales_order', 'follow_up_shipment')

      AND status >= 2

      -- only take current year and last year data
      AND EXTRACT(year from order_date) >= EXTRACT(year from current_date()) -1 

      -- exlcude the negative ids to only calculate the physical products
      AND ltm.product_id >0

      -- to exclude rma like orders
      AND qty > 0