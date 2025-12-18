with source as (
    -- Read from the raw table defined in sources.yml
    select * from {{ source('supply_chain_raw', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        order_status,
        -- FIX: Cast text columns to timestamp so we can do math later
        cast(order_purchase_timestamp as timestamp) as ordered_at,
        cast(order_approved_at as timestamp) as approved_at,
        cast(order_delivered_carrier_date as timestamp) as shipped_at,
        cast(order_delivered_customer_date as timestamp) as delivered_at,
        cast(order_estimated_delivery_date as timestamp) as estimated_delivery_at
    from source
)

select * from renamed