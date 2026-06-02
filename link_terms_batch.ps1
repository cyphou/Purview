$base = "https://pdedemopurv.purview.azure.com"
$token = (az account get-access-token --resource 'https://purview.azure.net' --query accessToken -o tsv)
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Link($termGuid, $label, $entityGuids) {
    foreach ($eg in $entityGuids) {
        $body = "[{`"guid`":`"$eg`"}]"
        try {
            Invoke-RestMethod -Uri "$base/catalog/api/atlas/v2/glossary/terms/$termGuid/assignedEntities?api-version=2022-08-01-preview" -Headers $headers -Method POST -Body $body | Out-Null
            Write-Output "OK   $label -> $eg"
        } catch {
            Write-Output "FAIL $label -> $eg : $($_.ErrorDetails.Message)"
        }
    }
}

# --- Entity GUIDs ---
# Tables
$TPCH_CUSTOMER    = "183cdb2a-dd72-497f-8a10-44f6f6f60000"
$TPCH_ORDERS      = "040af482-eef1-477a-9f8d-f5f6f6f60000"
$TPCH_LINEITEM    = "bf8d0719-0ba5-45d9-a96c-1df6f6f60000"
$TPCDS_CUSTOMER   = "ff85faf3-8863-479e-a443-bff6f6f60000"
$TPCDS_STORE_SALES= "2e61c851-0afb-4580-84af-c3f6f6f60000"

# TPCH columns
$C_CUSTKEY        = "183cdb2a-dd72-497f-8a10-44f6f6f60001"
$C_MKTSEGMENT     = "183cdb2a-dd72-497f-8a10-44f6f6f60002"
$C_ACCTBAL        = "183cdb2a-dd72-497f-8a10-44f6f6f60003"
$C_PHONE          = "183cdb2a-dd72-497f-8a10-44f6f6f60004"
$C_ADDRESS        = "183cdb2a-dd72-497f-8a10-44f6f6f60005"
$O_TOTALPRICE     = "040af482-eef1-477a-9f8d-f5f6f6f60009"
$L_EXTENDEDPRICE  = "bf8d0719-0ba5-45d9-a96c-1df6f6f60008"
$L_DISCOUNT       = "bf8d0719-0ba5-45d9-a96c-1df6f6f60009"

# TPCDS columns
$CD_CUSTOMER_ID   = "ff85faf3-8863-479e-a443-bff6f6f60002"
$CD_CUSTOMER_SK   = "ff85faf3-8863-479e-a443-bff6f6f60003"
$CD_EMAIL         = "ff85faf3-8863-479e-a443-bff6f6f60004"
$CD_PREF_FLAG     = "ff85faf3-8863-479e-a443-bff6f6f60001"
$SS_EXT_SALES     = "2e61c851-0afb-4580-84af-c3f6f6f60008"
$SS_NET_PROFIT    = "2e61c851-0afb-4580-84af-c3f6f6f6000d"
$SS_NET_PAID      = "2e61c851-0afb-4580-84af-c3f6f6f60015"

# --- Atlas Term GUIDs (from Customer & Finance glossaries) ---
Write-Output "=== GLOSSARY TERM LINKING ==="

# Churn Rate -> CUSTOMER tables
Link "b6c12d11-d70e-479f-a251-651418981218" "Churn Rate" @($TPCH_CUSTOMER, $TPCDS_CUSTOMER)

# Sales Pipeline -> LINEITEM, STORE_SALES, ORDERS
Link "ceee41f2-f823-4b3b-9225-a3378daf7c00" "Sales Pipeline" @($TPCH_LINEITEM, $TPCDS_STORE_SALES, $TPCH_ORDERS)

# Customer Satisfaction -> CUSTOMER tables
Link "97da7ffa-60a0-4324-af36-ed5bac750dd2" "Customer Satisfaction" @($TPCH_CUSTOMER, $TPCDS_CUSTOMER)

# Net Revenue -> O_TOTALPRICE, L_EXTENDEDPRICE, SS_EXT_SALES_PRICE
Link "9ae458ec-1baf-449d-9cf4-a2505086c4b4" "Net Revenue" @($O_TOTALPRICE, $L_EXTENDEDPRICE, $SS_EXT_SALES)

# Net Profit Margin -> SS_NET_PROFIT
Link "54049fb7-eb75-4487-ab9f-5f87f1c6de29" "Net Profit Margin" @($SS_NET_PROFIT)

# Profitability -> STORE_SALES
Link "2c070b36-1435-43e9-932f-2fd5bd8b2ab4" "Profitability" @($TPCDS_STORE_SALES)

# CRM -> CUSTOMER tables
Link "8916e381-9e6b-40dd-8f2a-988ac8a291bb" "CRM" @($TPCH_CUSTOMER, $TPCDS_CUSTOMER)

# CSAT -> CUSTOMER table (TPCH)
Link "a6c7b06c-6167-4580-a0f6-d2bcd4018786" "CSAT" @($TPCH_CUSTOMER)

# ARPU -> O_TOTALPRICE, SS_EXT_SALES
Link "5d09b90d-0a33-4bef-b5db-7707b0ac17ca" "ARPU" @($O_TOTALPRICE, $SS_EXT_SALES)

# Customer KPI -> CUSTOMER tables
Link "01bcc32b-ab03-4cbc-a7f6-b92c4c9b50fb" "Customer KPI" @($TPCH_CUSTOMER, $TPCDS_CUSTOMER)

# Opportunity -> ORDERS, STORE_SALES
Link "f4faffff-76f8-4dee-b7a8-3101a5402d92" "Opportunity" @($TPCH_ORDERS, $TPCDS_STORE_SALES)

# Win Rate -> ORDERS
Link "b26614f3-bcde-4077-ac3a-cfdded9ab6fe" "Win Rate" @($TPCH_ORDERS)

# Lead -> LINEITEM
Link "fffb24ef-b230-4e60-b627-786900aeb8bb" "Lead" @($TPCH_LINEITEM)

# EBITDA -> SS_NET_PROFIT, SS_NET_PAID
Link "455d0cbe-fb14-41ca-9f17-d1f62231a1ab" "EBITDA" @($SS_NET_PROFIT, $SS_NET_PAID)

# Cash Flow -> O_TOTALPRICE, SS_NET_PAID
Link "8cc7f354-6a65-430b-81ac-565d74790922" "Cash Flow" @($O_TOTALPRICE, $SS_NET_PAID)

# Gross Profit Margin -> L_EXTENDEDPRICE, L_DISCOUNT
Link "db2a849b-af63-4491-a133-c6dd33790530" "Gross Profit Margin" @($L_EXTENDEDPRICE, $L_DISCOUNT)

# Operating Expenses -> SS_NET_PROFIT
Link "267ba2e2-8918-42a0-842a-ef4a9f29376c" "Operating Expenses" @($SS_NET_PROFIT)

Write-Output "=== DONE ==="
