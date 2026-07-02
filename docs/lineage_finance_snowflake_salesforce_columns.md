# Finance Report Column Lineage: Snowflake and Salesforce

Generated (UTC): 2026-06-02T11:31:34Z

## Scope
- Finance Report dataset GUID: 0d401759-00e0-4dd7-a703-c65994568beb
- Path: Salesforce fields -> Snowflake columns -> Finance Report Power BI columns

## Verification Summary
- Expected process mappings: 19
- Verified process entities: 19
- Verified Salesforce -> Snowflake mappings: 9
- Verified Snowflake -> Power BI mappings: 10

## Process Verification (input -> output)
- [salesforce_to_snowflake] LMAP_SF_TO_SNOW_CUSTOMER_ID: salesforce_field 'CUSTOMER_ID' -> snowflake_table_column 'C_CUSTKEY' (status=ok, lineageEntitiesFromProcess=7)
- [salesforce_to_snowflake] LMAP_SF_TO_SNOW_CUSTOMER_NAME: salesforce_field 'CUSTOMER_NAME' -> snowflake_table_column 'C_NAME' (status=ok, lineageEntitiesFromProcess=7)
- [salesforce_to_snowflake] LMAP_SF_TO_SNOW_CUSTOMER_SEGMENT: salesforce_field 'CUSTOMER_SEGMENT' -> snowflake_table_column 'C_MKTSEGMENT' (status=ok, lineageEntitiesFromProcess=7)
- [salesforce_to_snowflake] LMAP_SF_TO_SNOW_CUSTOMER_BALANCE: salesforce_field 'CUSTOMER_BALANCE' -> snowflake_table_column 'C_ACCTBAL' (status=ok, lineageEntitiesFromProcess=8)
- [salesforce_to_snowflake] LMAP_SF_TO_SNOW_CUSTOMER_ADDRESS: salesforce_field 'CUSTOMER_ADDRESS' -> snowflake_table_column 'C_ADDRESS' (status=ok, lineageEntitiesFromProcess=8)
- [salesforce_to_snowflake] LMAP_SF_TO_SNOW_CUSTOMER_PHONE: salesforce_field 'CUSTOMER_PHONE' -> snowflake_table_column 'C_PHONE' (status=ok, lineageEntitiesFromProcess=8)
- [salesforce_to_snowflake] LMAP_SF_TO_SNOW_NATION_KEY: salesforce_field 'NATION_KEY' -> snowflake_table_column 'C_NATIONKEY' (status=ok, lineageEntitiesFromProcess=8)
- [salesforce_to_snowflake] LMAP_SF_TO_SNOW_ORDER_ID: salesforce_field 'ORDER_ID' -> snowflake_table_column 'O_ORDERKEY' (status=ok, lineageEntitiesFromProcess=9)
- [salesforce_to_snowflake] LMAP_SF_TO_SNOW_ORDER_STATUS: salesforce_field 'ORDER_STATUS' -> snowflake_table_column 'O_ORDERSTATUS' (status=ok, lineageEntitiesFromProcess=9)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_CUSTOMER_ID: snowflake_table_column 'C_CUSTKEY' -> powerbi_column 'CUSTOMER_ID' (status=ok, lineageEntitiesFromProcess=16)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_CUSTOMER_NAME: snowflake_table_column 'C_NAME' -> powerbi_column 'CUSTOMER_NAME' (status=ok, lineageEntitiesFromProcess=16)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_CUSTOMER_SEGMENT: snowflake_table_column 'C_MKTSEGMENT' -> powerbi_column 'CUSTOMER_SEGMENT' (status=ok, lineageEntitiesFromProcess=16)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_ORDER_ID: snowflake_table_column 'O_ORDERKEY' -> powerbi_column 'ORDER_ID' (status=ok, lineageEntitiesFromProcess=5)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_ORDER_DATE: snowflake_table_column 'O_ORDERDATE' -> powerbi_column 'ORDER_DATE' (status=ok, lineageEntitiesFromProcess=6)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_TOTAL_REVENUE: snowflake_table_column 'O_TOTALPRICE' -> powerbi_column 'TOTAL_REVENUE' (status=ok, lineageEntitiesFromProcess=6)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_NET_REVENUE: snowflake_table_column 'L_EXTENDEDPRICE' -> powerbi_column 'NET_REVENUE' (status=ok, lineageEntitiesFromProcess=0)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_DISCOUNT_AMOUNT: snowflake_table_column 'L_DISCOUNT' -> powerbi_column 'DISCOUNT_AMOUNT' (status=ok, lineageEntitiesFromProcess=0)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_SHIP_DATE: snowflake_table_column 'L_SHIPDATE' -> powerbi_column 'SHIP_DATE' (status=ok, lineageEntitiesFromProcess=0)
- [snowflake_to_powerbi] LMAP_SNOW_TO_PBI_ORDER_STATUS: snowflake_table_column 'O_ORDERSTATUS' -> powerbi_column 'ORDER_STATUS' (status=ok, lineageEntitiesFromProcess=5)

## Salesforce -> Snowflake Column Mappings
- CUSTOMER_ID -> C_CUSTKEY
- CUSTOMER_NAME -> C_NAME
- CUSTOMER_SEGMENT -> C_MKTSEGMENT
- CUSTOMER_BALANCE -> C_ACCTBAL
- CUSTOMER_ADDRESS -> C_ADDRESS
- CUSTOMER_PHONE -> C_PHONE
- NATION_KEY -> C_NATIONKEY
- ORDER_ID -> O_ORDERKEY
- ORDER_STATUS -> O_ORDERSTATUS

## Snowflake -> Finance Report Column Mappings
- C_CUSTKEY -> CUSTOMER_ID
- C_NAME -> CUSTOMER_NAME
- C_MKTSEGMENT -> CUSTOMER_SEGMENT
- O_ORDERKEY -> ORDER_ID
- O_ORDERDATE -> ORDER_DATE
- O_TOTALPRICE -> TOTAL_REVENUE
- L_EXTENDEDPRICE -> NET_REVENUE
- L_DISCOUNT -> DISCOUNT_AMOUNT
- L_SHIPDATE -> SHIP_DATE
- O_ORDERSTATUS -> ORDER_STATUS

## Data Product Asset Attachment Check
- Data Product ID: 4baeadc4-224c-43be-93a5-819ed2fb9e97
- Finance Report (already linked)

Missing DataAsset records for Atlas GUIDs:
- ff85faf3-8863-479e-a443-bf5f6f6f6000
- 040af482-eef1-477a-9f8d-f5f6f6f60000
- bf8d0719-0ba5-45d9-a96c-1df6f6f60000
- eea7dfee-89a1-43fc-ab83-9cf6f6f60000
- 8d02c8fe-d541-4b95-bcb0-0cf6f6f60000
- 70818ae9-5e85-4fd2-90cb-a9f6f6f60000
