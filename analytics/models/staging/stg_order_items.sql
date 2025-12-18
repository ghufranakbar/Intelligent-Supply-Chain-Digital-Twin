with source as (
    select * from {{ source('supply_chain_raw', 'items') }}
),

renamed as (
    select
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date as shipping_limit_at,
        price,
        freight_value
    from source
)

select * from renamed