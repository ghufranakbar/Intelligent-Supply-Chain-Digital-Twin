with orders as (
    select * from {{ ref('stg_orders') }}
),

items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

joined as (
    select
        -- Order Info
        orders.order_id,
        orders.customer_id,
        orders.order_status,
        orders.ordered_at,
        orders.delivered_at,
        
        orders.estimated_delivery_at,
        DATE_PART('day', orders.delivered_at - orders.estimated_delivery_at) as delay_days,

        -- Item Info
        items.price,
        items.freight_value,
        
        products.weight_g,
        products.length_cm,
        products.height_cm,
        products.width_cm,
        products.category

    from orders
    left join items on orders.order_id = items.order_id
    left join products on items.product_id = products.product_id
)

select * from joined