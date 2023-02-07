-- take all the columns from order data ltm
-- add marketing cost for BOL and ManoMano orders

with t1 as (SELECT  order_id, 
                    EXTRACT (date from order_date) as order_date,
                    EXTRACT (week from order_date) as week_nr,
                    ltm.product_id,
                    p.name_nl                      as product_name_nl,
                    pcyr.label                     as sales_class,
                    brand,
                    category,
                    root_category,
                    line_total,
                    line_total_ex_vat, 
                    margin_total_net, 
                    qty, 
                    website_id, 
                    channel, 
                    shipping_method,
                    ltm.status,

                    -- BOL has variable and fixed marketing cost 
                    
                        -- For the fixed commission the standard rule is: 
                        -- Selling price (incl. VAT) < €10 - the fixed commission is 0,20 (ex VAT). 
                        -- Selling price (incl. VAT) > €10 and < €20 - the fixed commission is € 0,40 (ex VAT)
                        -- Selling price (incl. VAT) > €20 - the fixed commission is €0,83 (ex VAT)


                    CASE WHEN channel = "BOL" THEN 

                              CASE WHEN ABS(line_total/qty) <= 10 THEN .20 * qty
                                   WHEN ABS(line_total/qty) >= 10 AND  ABS(line_total/qty) <= 20 THEN .40*qty
                                   WHEN ABS(line_total/qty) > 20 THEN .83*qty
                                   END 
                        ELSE 0 
                    END AS bol_fixed_cost_per_product,

                  -- add variable cost per product for bol orders
                    CASE WHEN channel = "BOL" THEN 
                              ROUND(line_total * bc.commission_percentage,2) 
                        ELSE 0 
                    END AS bol_variable_cost_per_product,
                  
                  -- if the product is from the 6 fixed brands ManoMano charges 12% commission 
                  CASE WHEN channel = "ManoMano" THEN 
                        CASE WHEN  brand in ('DeWALT', 'Makita', 'Metabo', 'Bosch', 'HiKOKI', 'Hitachi') THEN ROUND(line_total_ex_vat * 0.12,2)

                        -- else ManoMano charges 13% commission
                            ELSE ROUND(line_total_ex_vat * 0.13,2)
                            END 
                        ELSE 0 END AS ManoMano_marketing_cost_per_product,

                  
                  -- Amazon has a marketing cost of 13.48% 

                  CASE WHEN channel = "Amazon" THEN ROUND(line_total_ex_vat * 0.1348,2)
                       ELSE 0 END AS amazon_marketing_cost_per_product




FROM `hbl-online.gcp_sql_bi.ORDER_DATA_LTM` ltm 

LEFT JOIN  `hbl-online.api.products` p
ON ltm.product_id = p.product_id


LEFT JOIN `hbl-online.purchase_queries.Jahid_bol_commission` bc
ON ltm.product_id = bc.product_id

LEFT JOIN `hbl-online.api.product_classifications` pcyr
ON pcyr.product_id = ltm.product_id AND pcyr.period = 'year' AND pcyr.type = 'sales'

WHERE ltm.product_id not in (-11, -12) 
      AND order_type = 'sales_order'
      AND ltm.status >= 1
      AND qty > 0

      -- take all the orders from 2022 onward
      AND EXTRACT (year from order_date) >= 2022 

     --  select channels
      AND Channel in ('GCNL', 'FXBE', 'FXES', 'FXFR', 'FXDE', 'BOL', 'ManoMano', 'Showroom', 'Amazon')

      -- select website: 3: ES, 4: DE, 6: BE, 7: NL, 8: FR
      AND website_id in (3,4,6,7,8)
      
      
      ),

-- t2 takes all the columns from t1 add whether the product is a colli product or not
t2  as (SELECT t1.*, 
      
      CASE
        WHEN product_id IN (595, 55823, 56008, 56320, 64582, 64583, 74622, 75082, 75088, 75281, 76409, 77041, 77042, 78859, 79425, 79426, 79583, 79665, 79737, 79738, 79746, 80982, 81056, 81057, 81060, 81061, 81065, 81066, 81281, 82401, 83776, 83777, 83832, 83842, 104905, 105254, 107796, 107800, 107861, 108165, 108174, 111427, 111440, 111442, 111443, 111444, 111445, 111449, 111450, 111452, 111453, 111454, 111467, 111473, 111482, 111487, 111488, 111489, 111492, 111500, 111507, 111508, 111563, 111564, 111618, 111625, 111631, 111634, 111657, 111868, 113563, 113564, 113565, 113566, 113567, 113703, 113904, 114574, 114979, 114980, 115260, 115448, 118866, 118977, 118978, 119028, 120245, 121559, 121560, 122034, 122184, 122185, 122859, 123168, 123169, 123301, 123448, 123497, 123903, 124265, 124269, 124278, 124764, 128397, 129392, 129410, 129423, 129456, 130944, 132073, 132074, 133783, 142794, 142969, 142970, 142972, 142973, 142974, 142975, 142976, 142977, 142978, 142979, 142980, 142981, 142982, 142983, 142984, 142985, 142997, 142998, 142999, 143001, 143002, 143003, 143004, 143005, 143006, 143007, 143008, 143009, 143010, 143011, 143012, 143013, 143014, 143015, 143016, 143017, 143018, 143019, 143020, 143021, 143022, 143023, 143024, 143025, 143026, 143027, 143028, 143029, 143030, 143031, 143032, 143033, 143057, 143058, 143112, 143113, 143114, 143115, 143116, 143117, 143118, 143119, 143121, 143122, 143123, 143124, 143125, 147189, 151208, 151248, 152863, 153098, 153284, 153288, 153291, 153294, 153298, 153308, 153311, 153317, 153318, 153321, 153346, 153347, 153364, 153365, 153381, 153798, 157119, 157876, 157877, 158470, 158492, 158505, 161254, 161255, 162364, 162772, 162773, 163277, 163560, 163561, 163567, 164251, 164522, 166304, 166980, 167077, 167078, 167079, 167557, 167562, 168489, 168492, 168493, 168494, 168495, 168496, 168500, 168501, 168505, 168506, 168507, 168508, 168509, 168510, 168514, 168515, 168516, 172097, 172099, 172105, 172111, 172114, 172147, 172150, 172154, 172266, 172318, 172319, 172320, 172335, 172336, 172382, 172385, 172387, 172397, 172421, 172438, 172622, 173302, 174175, 177002, 177030, 177061, 177473, 177478, 177497, 177536, 177538, 179505, 179506, 179512, 180123, 180254, 181564, 186372, 186807, 188884, 189381, 196858, 196861, 197075, 197530, 198519, 198520, 198523, 198828, 198888, 199271, 200451, 200836, 200837, 200838, 200918, 201205, 201208, 202650, 202770, 202793, 202807, 202808, 202809, 202810, 202811, 202816, 202825, 202843, 202853, 202928, 203139, 203142, 203147, 203148, 203151, 203152, 203154, 203155, 203162, 203164, 203172, 203173, 203174, 203175, 203176, 203177, 203178, 203180, 203181, 203182, 203183, 203184, 203185, 203186, 203187, 203191, 203192, 203212, 203213, 203214, 203215, 203216, 203217, 203218, 203219, 203220, 203221, 203222, 203223, 203224, 203225, 203226, 203227, 203228, 203229, 203231, 203235, 203237, 203242, 203246, 203248, 203249, 203250, 203251, 203252, 203253, 203254, 203256, 203257, 203258, 203259, 203260, 203262, 203263, 203264, 203265, 203266, 203267, 203268, 203270, 203271, 203272, 203273, 203274, 203275, 203276, 203277, 203278, 203279, 203281, 203284, 203286, 203290, 203299, 203314, 203315, 203317, 203318, 203320, 203321, 203322, 203323, 203324, 203325, 203326, 203327, 203328, 203329, 203332, 203333, 203334, 203335, 203338, 203340, 203349, 203350, 203351, 203370, 203371, 203372, 203373, 203374, 203375, 203376, 203377, 203378, 203379, 203380, 203381, 203382, 203383, 203384, 203385, 203386, 203387, 203388, 203389, 203391, 203393, 203394, 203395, 203396, 203397, 203398, 203399, 203400, 203403, 203404, 203405, 203409, 203412, 203415, 203417, 203419, 203422, 203423, 203424, 203425, 203426, 203427, 203428, 203429, 203430, 203432, 203433, 203434, 203435, 203438, 203439, 203441, 203443, 203447, 203448, 203450, 203451, 203452, 203453, 203454, 203455, 203456, 203458, 203459, 203460, 203461, 203463, 203464, 203465, 203466, 203467, 203468, 203470, 203471, 203472, 203473, 203474, 203475, 203484, 203485, 203487, 203488, 203489, 203511, 203512, 203513, 203514, 203517, 203518, 203520, 203521, 203523, 203524, 203525, 203570, 203572, 203576, 203577, 203578, 203579, 203580, 203581, 203582, 203583, 203586, 203587, 203588, 203589, 203590, 203594, 203598, 203631, 203641, 203642, 203643, 204097, 205171, 205172, 205173, 205174, 205175, 205177, 205178, 205179, 205180, 205182, 205183, 205184, 205185, 205186, 205187, 205188, 205189, 205191, 205192, 205193, 205194, 205195, 205196, 205197, 205198, 205199, 205200, 205201, 205202, 205203, 205204, 205205, 205207, 205209, 205210, 205211, 205212, 205213, 205214, 205215, 205216, 205217, 205218, 205219, 205220, 205221, 205222, 205223, 205609, 206201, 206202, 206866, 208013, 208133, 208136, 208682, 208940, 209670, 212272, 212273, 212274, 212861, 214465, 215463, 216104, 216855, 216920, 217013, 217163, 217164, 217176, 217177, 217251, 217252, 217253, 217255, 217259, 217261, 217267, 217268, 217269, 217270, 217271, 217273, 217275, 217276, 217277, 217303, 218017, 218018, 218291, 218292, 218293, 218378, 218598, 218605, 218675, 218773, 218835, 218997, 219119, 219295, 219460, 219461, 219462, 219467, 219468, 219469, 221099, 221101, 221102, 221103, 221105, 221106, 221107, 221108, 221109, 221110, 221111, 221112, 221113, 221114, 221115, 221116, 221117, 221118, 221119, 221120, 221121, 221122, 221123, 221124, 221125, 221126, 221127, 221128, 221129, 221130, 221131, 221132, 221133, 221134, 221137, 221138, 221139, 221140, 221141, 221144, 221145, 221146, 221147, 221148, 221149, 221155, 221156, 221162, 221163, 221164, 221165, 221168, 221169, 221346, 221348, 221351, 221352, 221426, 221427, 221428, 221430, 221431, 221432, 221433, 221434, 221435, 221436, 221437, 221438, 221439, 221440, 221442, 221443, 221444, 221445, 221446, 221447, 221448, 221449, 221696, 221698, 222187, 228907, 228910, 230521, 230616, 236139, 236514, 241329, 243835, 244153, 245293, 245924, 249570, 249891, 249892, 249893, 249939, 249940, 249941, 249942, 250040, 250041, 250137, 251414, 251415, 253409, 253410, 253415, 253416, 253417, 253418, 253419, 253420, 254387, 256731, 310703, 310854, 311249, 311304, 311307, 311308, 312799, 312800, 312997, 313614, 315844, 315982, 318111, 318112, 318113, 318129, 318136, 318137, 318138, 318139, 318140, 318141, 318142, 318143, 318144, 318145, 318146, 318147, 318148, 318149, 318150, 318151, 318152, 318162, 318163, 318164, 318165, 318167, 318168, 318169, 318170, 318171, 318172, 318173, 318174, 318175, 318176, 318177, 318184, 318187, 318198, 318199, 318200, 318201, 318202, 318203, 318204, 318205, 318206, 318207, 318208, 318209, 318210, 318211, 318212, 318213, 318214, 318215, 318216, 318217, 318218, 318219, 318229, 318230, 318231, 318232, 318234, 318235, 318236, 318237, 318238, 318239, 318240, 318241, 318242, 318250, 318254, 318256, 318259, 318260, 318261, 318262, 318263, 318264, 318265, 318266, 318275, 318276, 318277, 318278, 318279, 318280, 318281, 318282, 318284, 318285, 318286, 318287, 318288, 318289, 318290, 318291, 318292, 318293, 318294, 318297, 318298, 318299, 318300, 318301, 318302, 318303, 318304, 318305, 318306, 318307, 318308, 318309, 318310, 318315, 318316, 318317, 318318, 318319, 318320, 318321, 318322, 318323, 318324, 318325, 318326, 318330, 318331, 318332, 318333, 318334, 318335, 318336, 318337, 318338, 318339, 318340, 318341, 318342, 318343, 318344, 318345, 318346, 318347, 318348, 318349, 318350, 318351, 318352, 318353, 318354, 318355, 318356, 318357, 318358, 318359, 318360, 318361, 318362, 318363, 318364, 318365, 318366, 318367, 318368, 318369, 318370, 318371, 318372, 318373, 318374, 318375, 318376, 318377, 318378, 318379, 318380, 318381, 318382, 318383, 318384, 318385, 318386, 318387, 318388, 318389, 318390, 318391, 318392, 318393, 318427, 318428, 318429, 318430, 318431, 318432, 318433, 318434, 318435, 318436, 318437, 318438, 318439, 318440, 318441, 318442, 318443, 318444, 318445, 318446, 318447, 318448, 318449, 318450, 318451, 318452, 318453, 318454, 318455, 318456, 318457, 318458, 318459, 318460, 318461, 318462, 318463, 318464, 318465, 318466, 318467, 318468, 318469, 318470, 318471, 318472, 318473, 318474, 318475, 318476, 318477, 318478, 318479, 318480, 318863, 318865, 319554, 319671, 319672, 319676, 319686, 319688, 319689, 322111, 322128, 325826, 325960, 325989, 326242, 327727, 327728, 333267, 333411, 334260, 341208, 343311) THEN 1
      ELSE 0 END AS is_coll_product
      FROM t1),

-- t3 aggregates number of order lines per order (count of discint product ids), 
-- total revenue per order
-- and checks if the product is a transmission colli product


t3 as (SELECT      DISTINCT (order_id)                                                    as order_id,

                   SUM((CASE WHEN product_id > 0 THEN 1 
                                            ELSE 0 END))                               as order_line,
                   
                   
                   
                   -- total_revenue_for_cost_share is used to distribute the costs
                   -- as the qty >0 the revenue should not be negative
                   -- however, if there is a strange case like (order id: 3106724) 
                   -- the product does not get cost share
                   -- also the negative ids get no share of WH cost, shipping cost, CS cost,  marketing cost and RMA related shipping cost
                   -- negative ids however get a share of the payment cost, RMA cost 


                   SUM(CASE WHEN (product_id >0 AND line_total_ex_vat >0) 
                            THEN line_total_ex_vat 
                            ELSE 0 END )                                                 as total_revenue_for_cost_share,

                   SUM(CASE WHEN is_coll_product > 0 THEN 1 ELSE 0 END ) as is_tm_colli,
                   website_id,
                   shipping_method,

                   
                   FROM t2
                   GROUP BY  order_id,
                             website_id,
                             shipping_method),

-- t4 takes all the orders from t3
-- adds shipping cost to the orders based on shipping method

t4 as (
SELECT t3.order_id,
       t3.order_line,
       t3.total_revenue_for_cost_share,
       t3.is_tm_colli,


      CASE
            WHEN t3.shipping_method IN ('pallet', 'pallet_manual') THEN 
                  CASE
                        WHEN t3.website_id = 7 THEN
                            CASE
                                WHEN (is_tm_colli > 0 AND is_tm_colli = order_line) THEN ROUND((is_tm_colli * 17.50) * 1.23,2) #ALL SEPERATE TM COLLI
                                WHEN (is_tm_colli > 0 AND is_tm_colli < order_line) THEN ROUND(33.90 * 1.23,2) #ASSUME IT ALL IS PLACED ON A PALLET
                                ELSE ROUND(33.90 * 1.23,2)
                            END #NETHERLANDS

                      WHEN t3.website_id = 6 THEN
                            CASE
                                WHEN (is_tm_colli > 0 AND is_tm_colli = order_line) THEN ROUND((is_tm_colli * 22.50) * 1.23,2) #ALL SEPERATE TM COLLI
                                WHEN (is_tm_colli > 0 AND is_tm_colli < order_line) THEN ROUND(50.70 * 1.23,2) #ASSUME IT ALL IS PLACED ON A PALLET
                                ELSE ROUND(50.70 * 1.23,2)
                      END #BELGIUM
                      
            WHEN t3.website_id = 8 THEN 135.00 #FRANCE
            WHEN t3.website_id = 3 THEN 135.00 #SPAIN
            WHEN t3.website_id = 4 THEN 135.00 #GERMANY
      END
      
      WHEN t3.shipping_method IN ('flatrate_flatrate') THEN 0.00
      ELSE
            CASE
                WHEN t3.website_id = 7 THEN 5.20 #NETHERLANDS
                WHEN t3.website_id = 6 THEN 5.95 #BELGIUM
                WHEN t3.website_id = 8 THEN 10.55 #FRANCE
                WHEN t3.website_id = 3 THEN 11.00 #SPAIN
                WHEN t3.website_id = 4 THEN 5.65 #GERMANY

                ELSE 7.00
            END
    END as shipping_cost_per_order



FROM t3

),


-- t5 takes all the columns from t1
-- add the total order revenue, and orderline per order
-- and add marketing cost for the marketplace orders

t5 as (SELECT  t1.order_id,
               t1.order_date,
               t1.week_nr,
               t1.product_id,
               t1.product_name_nl,
               t1.sales_class,
               t1.brand, 
               t1.category, 
               t1.root_category,
               qty, 
               website_id, 
               channel, 
               shipping_method, 
               shipping_cost_per_order,
               order_line,
               line_total,
               line_total_ex_vat, 
               margin_total_net, 
               total_revenue_for_cost_share,
               
                CASE    WHEN channel = 'BOL' THEN ROUND((bol_fixed_cost_per_product + bol_variable_cost_per_product),2)
                        WHEN channel = 'ManoMano' THEN ManoMano_marketing_cost_per_product
                        WHEN channel = 'Amazon' THEN amazon_marketing_cost_per_product
                        END as mktplace_marketing_cost

       FROM t1
       LEFT JOIN t4
       ON t1.order_id = t4.order_id),


-- these are orders like rma, that's why they have been excluded
t6 as (SELECT *
FROM t5
WHERE total_revenue_for_cost_share != 0),

-- t7 takes 

t7 as (SELECT *,
       
       -- for BOL, ManoMano and Amazon no payment cost
       CASE WHEN channel in ('BOL', 'ManoMano', 'Amazon') THEN 0 
       
      -- if the revenue is less than 0 no payment cost
      -- if the revenue is >0 then the revenue is applicable for the payment cost

            ELSE CASE WHEN line_total_ex_vat < 0 THEN 0 
                 ELSE line_total_ex_vat END
        END revenue_applicable_for_payment_cost,
      
      -- if the product id is 0 then the cost share fraction is 0
      -- else the ratio of individual product revenue and total revenue is used for calculating cost fraction
      -- this cost fraction is used to distribute cost 
      
       CASE WHEN product_id <0 THEN 0
            ELSE 
               CASE WHEN line_total_ex_vat < 0 THEN 0 
                    ELSE (line_total_ex_vat / total_revenue_for_cost_share) END 
            
       END as cost_fraction
FROM t6 )

SELECT *
FROM t7
