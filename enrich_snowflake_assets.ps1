# enrich_snowflake_assets.ps1
# Enriches Snowflake table and column assets in Purview with descriptions, calculation explanations, and glossary term links.

$base = "https://pdedemopurv.purview.azure.com"
$token = (az account get-access-token --resource 'https://purview.azure.net' --query accessToken -o tsv)
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

# ---- Helper: Update entity description ----
function Set-Desc($typeName, $qn, $name, $desc) {
    $body = @{ entity = @{ typeName = $typeName; attributes = @{ qualifiedName = $qn; name = $name; userDescription = $desc } } } | ConvertTo-Json -Depth 5
    try {
        $r = Invoke-RestMethod -Uri "$base/catalog/api/atlas/v2/entity?api-version=2022-08-01-preview" -Headers $headers -Method POST -Body $body
        Write-Host "  OK $name"
    } catch { Write-Host "  FAIL $name : $($_.ErrorDetails.Message)" }
}

# ---- Helper: Link glossary term to entity ----
function Add-TermLink($entityGuid, $termGuid, $termName) {
    $body = @{ termGuid = $termGuid } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "$base/catalog/api/atlas/v2/glossary/terms/$termGuid/assignedEntities?api-version=2022-08-01-preview" -Headers $headers -Method POST -Body "[$body]" | Out-Null
        Write-Host "  LINK $termName -> entity $entityGuid"
    } catch { Write-Host "  LINK-FAIL $termName : $($_.ErrorDetails.Message)" }
}

$sfQnBase = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas"

# =============================================================================
# SECTION 1: TPCH_SF1 TABLE DESCRIPTIONS
# =============================================================================
Write-Host "`n=== TPCH_SF1 TABLE DESCRIPTIONS ==="

$tpchBase = "$sfQnBase/TPCH_SF1/tables"

Set-Desc "snowflake_table" "$tpchBase/CUSTOMER" "CUSTOMER" @"
Customer master table from TPC-H benchmark (Scale Factor 1). Contains 150,000 customer records with demographics, account balance, market segment, and geographic references.
Primary key: C_CUSTKEY. Joins to ORDERS via O_CUSTKEY and to NATION via C_NATIONKEY.

FR: Table maitresse clients (benchmark TPC-H, SF1). 150 000 enregistrements clients avec donnees demographiques, solde de compte, segment de marche et references geographiques. Cle primaire : C_CUSTKEY. Jointures : ORDERS (O_CUSTKEY), NATION (C_NATIONKEY).
"@

Set-Desc "snowflake_table" "$tpchBase/ORDERS" "ORDERS" @"
Customer orders table from TPC-H benchmark (SF1). Contains 1.5 million order records with total price, order status, priority, and clerk assignment.
Primary key: O_ORDERKEY. Foreign key: O_CUSTKEY references CUSTOMER.
Calculation: O_TOTALPRICE = SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT) * (1 + L_TAX)) across all line items of the order.

FR: Table des commandes clients (TPC-H SF1). 1,5M de commandes avec prix total, statut, priorite et affectation. Calcul : O_TOTALPRICE = somme de L_EXTENDEDPRICE * (1 - L_DISCOUNT) * (1 + L_TAX) sur toutes les lignes.
"@

Set-Desc "snowflake_table" "$tpchBase/LINEITEM" "LINEITEM" @"
Order line items from TPC-H benchmark (SF1). Contains 6 million line-level details: quantity, pricing, discount, tax, shipping dates, and return status.
Composite key: (L_ORDERKEY, L_LINENUMBER).
Key calculations:
- L_EXTENDEDPRICE = L_QUANTITY x unit_price (from PARTSUPP)
- Revenue = L_EXTENDEDPRICE * (1 - L_DISCOUNT)
- Net amount = Revenue * (1 + L_TAX)

FR: Lignes de commande (TPC-H SF1). 6M de lignes de detail. Calculs cles : L_EXTENDEDPRICE = L_QUANTITY x prix_unitaire ; Revenu = L_EXTENDEDPRICE * (1 - L_DISCOUNT) ; Montant net = Revenu * (1 + L_TAX).
"@

Set-Desc "snowflake_table" "$tpchBase/NATION" "NATION" @"
Reference table of 25 nations from TPC-H benchmark. Primary key: N_NATIONKEY. Foreign key: N_REGIONKEY references REGION. Used to group customers and suppliers by country.

FR: Table de reference des 25 nations (TPC-H). Cle primaire : N_NATIONKEY. Utilisee pour regrouper clients et fournisseurs par pays.
"@

Set-Desc "snowflake_table" "$tpchBase/REGION" "REGION" @"
Reference table of 5 world regions from TPC-H benchmark (Africa, America, Asia, Europe, Middle East). Primary key: R_REGIONKEY. Parent of NATION table.

FR: Table de reference des 5 regions du monde (TPC-H). Cle primaire : R_REGIONKEY. Table parente de NATION.
"@

Set-Desc "snowflake_table" "$tpchBase/SUPPLIER" "SUPPLIER" @"
Supplier master table from TPC-H benchmark (SF1). Contains 10,000 supplier records with contact info, account balance, and nation reference.
Primary key: S_SUPPKEY. Foreign key: S_NATIONKEY references NATION.

FR: Table maitresse fournisseurs (TPC-H SF1). 10 000 fournisseurs avec coordonnees, solde de compte et reference nation.
"@

Set-Desc "snowflake_table" "$tpchBase/PART" "PART" @"
Product parts catalog from TPC-H benchmark (SF1). Contains 200,000 part records with brand, type, size, container, and retail price.
Primary key: P_PARTKEY.

FR: Catalogue de pieces/produits (TPC-H SF1). 200 000 articles avec marque, type, taille, contenant et prix de detail. Cle primaire : P_PARTKEY.
"@

Set-Desc "snowflake_table" "$tpchBase/PARTSUPP" "PARTSUPP" @"
Part-supplier relationship table from TPC-H benchmark (SF1). Contains 800,000 records linking parts to suppliers with supply cost and availability.
Composite key: (PS_PARTKEY, PS_SUPPKEY). Foreign keys reference PART and SUPPLIER.

FR: Table de relation pieces-fournisseurs (TPC-H SF1). 800 000 enregistrements reliant articles et fournisseurs avec cout d'approvisionnement et disponibilite.
"@

# =============================================================================
# SECTION 2: TPCDS_SF10TCL TABLE DESCRIPTIONS
# =============================================================================
Write-Host "`n=== TPCDS_SF10TCL TABLE DESCRIPTIONS ==="

$tpcdsBase = "$sfQnBase/TPCDS_SF10TCL/tables"

Set-Desc "snowflake_table" "$tpcdsBase/CUSTOMER" "CUSTOMER" @"
Customer dimension table from TPC-DS benchmark (Scale Factor 10TB). Contains customer demographics, preferences, and SCD attributes. 18 columns including birth date components, preferred customer flag, and email.
Primary key: C_CUSTOMER_SK (surrogate). Business key: C_CUSTOMER_ID.
Foreign keys: C_CURRENT_CDEMO_SK -> CUSTOMER_DEMOGRAPHICS, C_CURRENT_HDEMO_SK -> HOUSEHOLD_DEMOGRAPHICS, C_CURRENT_ADDR_SK -> CUSTOMER_ADDRESS.

FR: Table dimension clients (TPC-DS SF10TB). Donnees demographiques, preferences et attributs SCD. Cle primaire : C_CUSTOMER_SK (cle de substitution). Cle metier : C_CUSTOMER_ID.
"@

Set-Desc "snowflake_table" "$tpcdsBase/CUSTOMER_ADDRESS" "CUSTOMER_ADDRESS" @"
Customer address dimension from TPC-DS benchmark. Contains geographic hierarchy (street, city, county, state, zip, country) and location type.
Primary key: CA_ADDRESS_SK. Referenced by CUSTOMER.C_CURRENT_ADDR_SK.

FR: Dimension adresse client (TPC-DS). Contient la hierarchie geographique (rue, ville, comte, etat, code postal, pays). Cle primaire : CA_ADDRESS_SK.
"@

Set-Desc "snowflake_table" "$tpcdsBase/CUSTOMER_DEMOGRAPHICS" "CUSTOMER_DEMOGRAPHICS" @"
Customer demographics dimension from TPC-DS benchmark. Contains demographic attributes: gender, marital status, education, purchase estimate, credit rating, dependency counts.
Primary key: CD_DEMO_SK. Referenced by CUSTOMER.C_CURRENT_CDEMO_SK and STORE_SALES.SS_CDEMO_SK.

FR: Dimension demographique client (TPC-DS). Attributs : genre, statut marital, education, estimation d'achat, notation credit. Cle primaire : CD_DEMO_SK.
"@

Set-Desc "snowflake_table" "$tpcdsBase/STORE_SALES" "STORE_SALES" @"
Store sales fact table from TPC-DS benchmark (SF10TB). Central fact table with 23 columns capturing in-store transactions.
Composite key: (SS_ITEM_SK, SS_TICKET_NUMBER).
Key calculations:
- SS_EXT_SALES_PRICE = SS_SALES_PRICE * SS_QUANTITY (extended sales amount)
- SS_EXT_DISCOUNT_AMT = SS_LIST_PRICE * SS_QUANTITY - SS_EXT_SALES_PRICE (total discount given)
- SS_EXT_WHOLESALE_COST = SS_WHOLESALE_COST * SS_QUANTITY (total wholesale cost)
- SS_NET_PAID = SS_EXT_SALES_PRICE - SS_COUPON_AMT (amount paid after coupon)
- SS_NET_PAID_INC_TAX = SS_NET_PAID + SS_EXT_TAX (amount paid including tax)
- SS_NET_PROFIT = SS_NET_PAID - SS_EXT_WHOLESALE_COST (profit after cost deduction)

FR: Table de faits ventes en magasin (TPC-DS SF10TB). 23 colonnes de transactions en magasin. Calculs cles : SS_NET_PROFIT = SS_NET_PAID - SS_EXT_WHOLESALE_COST ; SS_NET_PAID = SS_EXT_SALES_PRICE - SS_COUPON_AMT ; SS_NET_PAID_INC_TAX = SS_NET_PAID + SS_EXT_TAX.
"@

Set-Desc "snowflake_table" "$tpcdsBase/STORE_RETURNS" "STORE_RETURNS" @"
Store returns fact table from TPC-DS benchmark. Captures returned items with return quantity, amounts, fees, and net loss.
Key calculations:
- SR_RETURN_AMT = refund amount to customer
- SR_NET_LOSS = SR_RETURN_AMT + SR_RETURN_TAX + fees - original wholesale cost

FR: Table de faits retours en magasin (TPC-DS). Capture les articles retournes avec quantite, montants, frais et perte nette.
"@

Set-Desc "snowflake_table" "$tpcdsBase/ITEM" "ITEM" @"
Item/product dimension from TPC-DS benchmark. Contains product attributes: brand, class, category, manufacturer, size, color, and pricing.
Primary key: I_ITEM_SK (surrogate). Business key: I_ITEM_ID.
Slowly changing dimension (SCD Type 2) with I_REC_START_DATE / I_REC_END_DATE.

FR: Dimension article/produit (TPC-DS). Attributs : marque, classe, categorie, fabricant, taille, couleur et tarification. Dimension a changement lent (SCD Type 2).
"@

Set-Desc "snowflake_table" "$tpcdsBase/STORE" "STORE" @"
Store dimension from TPC-DS benchmark. Contains physical store attributes: name, hours, manager, market, geography, floor space, and employee count.
Primary key: S_STORE_SK. Referenced by STORE_SALES.SS_STORE_SK.

FR: Dimension magasin (TPC-DS). Attributs : nom, horaires, responsable, marche, geographie, surface et effectifs. Cle primaire : S_STORE_SK.
"@

Set-Desc "snowflake_table" "$tpcdsBase/PROMOTION" "PROMOTION" @"
Promotion dimension from TPC-DS benchmark. Contains promotion channel mix (email, TV, radio, print, events), discount type, purpose, and cost.
Primary key: P_PROMO_SK. Referenced by STORE_SALES.SS_PROMO_SK.

FR: Dimension promotion (TPC-DS). Mix canal (email, TV, radio, presse, evenements), type de remise, objectif et cout. Cle primaire : P_PROMO_SK.
"@

Set-Desc "snowflake_table" "$tpcdsBase/REASON" "REASON" @"
Return reason dimension from TPC-DS benchmark. Lookup table with reason codes and descriptions for product returns.
Primary key: R_REASON_SK. Referenced by STORE_RETURNS.

FR: Dimension motif de retour (TPC-DS). Table de reference des codes et descriptions de motifs de retour produit.
"@

# =============================================================================
# SECTION 3: TPCH_SF1 COLUMN DESCRIPTIONS
# =============================================================================
Write-Host "`n=== TPCH_SF1 COLUMN DESCRIPTIONS ==="

$custColBase = "$sfQnBase/TPCH_SF1/tables/CUSTOMER/columns"

Set-Desc "snowflake_table_column" "$custColBase/C_CUSTKEY" "C_CUSTKEY" "Unique customer identifier (surrogate key). Integer, auto-generated. Used as primary key and referenced by ORDERS.O_CUSTKEY for order-customer joins. FR: Identifiant client unique (cle de substitution). Reference par ORDERS.O_CUSTKEY."

Set-Desc "snowflake_table_column" "$custColBase/C_NAME" "C_NAME" "Customer full name. Format: 'Customer#NNNNNNNNNN'. Used for display and reporting. FR: Nom complet du client. Format : 'Customer#NNNNNNNNNN'."

Set-Desc "snowflake_table_column" "$custColBase/C_ADDRESS" "C_ADDRESS" "Customer mailing address (street-level). Variable-length string. May contain PII requiring GDPR compliance measures. FR: Adresse postale du client. Peut contenir des DCP necessitant la conformite RGPD."

Set-Desc "snowflake_table_column" "$custColBase/C_NATIONKEY" "C_NATIONKEY" "Foreign key to NATION table. Links customer to their country of origin. Used for geographic segmentation and regional analysis. FR: Cle etrangere vers NATION. Relie le client a son pays d'origine pour la segmentation geographique."

Set-Desc "snowflake_table_column" "$custColBase/C_PHONE" "C_PHONE" "Customer phone number. Format: 'CC-NNNNNNNNNN' where CC is country code. PII field subject to data privacy regulations. FR: Numero de telephone client. Format : 'CC-NNNNNNNNNN'. Donnee personnelle soumise a la reglementation sur la vie privee."

Set-Desc "snowflake_table_column" "$custColBase/C_ACCTBAL" "C_ACCTBAL" "Customer account balance. Decimal value representing current credit balance. Positive = credit available, negative = amount owed. Used in credit risk analysis and customer segmentation. FR: Solde du compte client. Positif = credit disponible, negatif = montant du. Utilise pour l'analyse du risque de credit et la segmentation client."

Set-Desc "snowflake_table_column" "$custColBase/C_MKTSEGMENT" "C_MKTSEGMENT" "Market segment classification. One of: AUTOMOBILE, BUILDING, FURNITURE, HOUSEHOLD, MACHINERY. Used for customer segmentation and targeted marketing analysis. FR: Segment de marche : AUTOMOBILE, BUILDING, FURNITURE, HOUSEHOLD, MACHINERY. Utilise pour la segmentation client et l'analyse marketing ciblee."

Set-Desc "snowflake_table_column" "$custColBase/C_COMMENT" "C_COMMENT" "Free-text customer comment. Variable-length text field for notes and observations. FR: Commentaire client en texte libre."

# ORDERS columns
$ordColBase = "$sfQnBase/TPCH_SF1/tables/ORDERS/columns"

Set-Desc "snowflake_table_column" "$ordColBase/O_ORDERKEY" "O_ORDERKEY" "Unique order identifier (primary key). Integer. Referenced by LINEITEM.L_ORDERKEY. FR: Identifiant de commande unique (cle primaire). Reference par LINEITEM.L_ORDERKEY."

Set-Desc "snowflake_table_column" "$ordColBase/O_CUSTKEY" "O_CUSTKEY" "Foreign key to CUSTOMER.C_CUSTKEY. Links order to the purchasing customer. Essential for customer-order joins and revenue-per-customer calculations. FR: Cle etrangere vers CUSTOMER.C_CUSTKEY. Essentiel pour les jointures client-commande et le calcul du revenu par client."

Set-Desc "snowflake_table_column" "$ordColBase/O_ORDERSTATUS" "O_ORDERSTATUS" "Order fulfillment status. Values: F (Fulfilled), O (Open), P (Partially fulfilled). Used for order lifecycle tracking and fulfillment KPIs. FR: Statut de realisation : F (Terminee), O (Ouverte), P (Partiellement realisee). Utilise pour le suivi du cycle de vie des commandes."

Set-Desc "snowflake_table_column" "$ordColBase/O_TOTALPRICE" "O_TOTALPRICE" "Total order amount. Calculation: SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT) * (1 + L_TAX)) across all line items. Represents the net revenue including tax after discounts. FR: Montant total de la commande. Calcul : SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT) * (1 + L_TAX)) sur toutes les lignes. Revenu net taxes incluses apres remises."

Set-Desc "snowflake_table_column" "$ordColBase/O_ORDERDATE" "O_ORDERDATE" "Date the order was placed. DATE type. Used for time-series analysis, trend reporting, and fiscal period aggregation. FR: Date de la commande. Utilisee pour l'analyse temporelle, le reporting de tendances et l'agregation par periode fiscale."

Set-Desc "snowflake_table_column" "$ordColBase/O_ORDERPRIORITY" "O_ORDERPRIORITY" "Order priority level. Values: 1-URGENT, 2-HIGH, 3-MEDIUM, 4-NOT SPECIFIED, 5-LOW. Drives fulfillment sequencing and SLA tracking. FR: Niveau de priorite : 1-URGENT, 2-HIGH, 3-MEDIUM, 4-NOT SPECIFIED, 5-LOW."

Set-Desc "snowflake_table_column" "$ordColBase/O_CLERK" "O_CLERK" "Clerk who recorded the order. Format: 'Clerk#NNNNNNNNNN'. Used for sales rep performance tracking. FR: Commis ayant enregistre la commande. Utilise pour le suivi de performance des representants."

Set-Desc "snowflake_table_column" "$ordColBase/O_SHIPPRIORITY" "O_SHIPPRIORITY" "Shipping priority indicator. Integer value affecting delivery scheduling. Higher values indicate higher shipping priority. FR: Indicateur de priorite d'expedition. Valeur entiere affectant l'ordonnancement des livraisons."

Set-Desc "snowflake_table_column" "$ordColBase/O_COMMENT" "O_COMMENT" "Free-text order comment. Contains notes about the order. FR: Commentaire libre sur la commande."

# LINEITEM key columns
$liColBase = "$sfQnBase/TPCH_SF1/tables/LINEITEM/columns"

Set-Desc "snowflake_table_column" "$liColBase/L_ORDERKEY" "L_ORDERKEY" "Foreign key to ORDERS.O_ORDERKEY. Part of composite primary key (L_ORDERKEY, L_LINENUMBER). FR: Cle etrangere vers ORDERS.O_ORDERKEY. Partie de la cle primaire composite."

Set-Desc "snowflake_table_column" "$liColBase/L_PARTKEY" "L_PARTKEY" "Foreign key to PART.P_PARTKEY. Identifies the product in this line item. FR: Cle etrangere vers PART.P_PARTKEY. Identifie le produit de cette ligne."

Set-Desc "snowflake_table_column" "$liColBase/L_SUPPKEY" "L_SUPPKEY" "Foreign key to SUPPLIER.S_SUPPKEY. Identifies the supplier for this line item. FR: Cle etrangere vers SUPPLIER.S_SUPPKEY. Identifie le fournisseur."

Set-Desc "snowflake_table_column" "$liColBase/L_LINENUMBER" "L_LINENUMBER" "Line number within the order. Part of composite primary key (L_ORDERKEY, L_LINENUMBER). Sequential integer starting at 1. FR: Numero de ligne dans la commande. Partie de la cle primaire composite."

Set-Desc "snowflake_table_column" "$liColBase/L_QUANTITY" "L_QUANTITY" "Quantity of parts ordered. Decimal value. Used in extended price calculation: L_EXTENDEDPRICE = L_QUANTITY * unit_price. FR: Quantite commandee. Utilisee dans le calcul du prix etendu : L_EXTENDEDPRICE = L_QUANTITY * prix_unitaire."

Set-Desc "snowflake_table_column" "$liColBase/L_EXTENDEDPRICE" "L_EXTENDEDPRICE" "Extended price before discounts and taxes. Calculation: L_QUANTITY * unit_price (from PARTSUPP). Base amount for revenue calculations. Revenue = L_EXTENDEDPRICE * (1 - L_DISCOUNT). FR: Prix etendu avant remises et taxes. Calcul : L_QUANTITY * prix_unitaire. Montant de base pour le calcul du revenu."

Set-Desc "snowflake_table_column" "$liColBase/L_DISCOUNT" "L_DISCOUNT" "Discount percentage applied to this line item. Decimal between 0 and 0.10 (0% to 10%). Used in revenue calculation: Revenue = L_EXTENDEDPRICE * (1 - L_DISCOUNT). FR: Pourcentage de remise applique. Decimal entre 0 et 0,10. Utilise dans : Revenu = L_EXTENDEDPRICE * (1 - L_DISCOUNT)."

Set-Desc "snowflake_table_column" "$liColBase/L_TAX" "L_TAX" "Tax rate applied to this line item. Decimal between 0 and 0.08 (0% to 8%). Applied after discount: Net = L_EXTENDEDPRICE * (1 - L_DISCOUNT) * (1 + L_TAX). FR: Taux de taxe applique. Decimal entre 0 et 0,08. Applique apres remise : Net = L_EXTENDEDPRICE * (1 - L_DISCOUNT) * (1 + L_TAX)."

Set-Desc "snowflake_table_column" "$liColBase/L_RETURNFLAG" "L_RETURNFLAG" "Return status flag. Values: R (Returned), A (Accepted/delivered), N (Not yet shipped as of cut-off date). Used for return rate analysis. FR: Indicateur de retour : R (Retourne), A (Accepte/livre), N (Non encore expedie)."

Set-Desc "snowflake_table_column" "$liColBase/L_LINESTATUS" "L_LINESTATUS" "Line item shipping status. Values: O (Open - not yet shipped), F (Fulfilled - shipped). FR: Statut d'expedition de la ligne : O (Ouverte), F (Realisee/expediee)."

Set-Desc "snowflake_table_column" "$liColBase/L_SHIPDATE" "L_SHIPDATE" "Actual shipment date. DATE type. Used to calculate shipping delays: delay = L_SHIPDATE - L_COMMITDATE. FR: Date d'expedition effective. Utilisee pour calculer les retards : retard = L_SHIPDATE - L_COMMITDATE."

Set-Desc "snowflake_table_column" "$liColBase/L_COMMITDATE" "L_COMMITDATE" "Promised delivery date. DATE type. Compared with L_SHIPDATE to measure fulfillment performance. FR: Date de livraison promise. Comparee a L_SHIPDATE pour mesurer la performance de livraison."

Set-Desc "snowflake_table_column" "$liColBase/L_RECEIPTDATE" "L_RECEIPTDATE" "Date item was received by customer. DATE type. Used for lead time calculation: lead_time = L_RECEIPTDATE - L_SHIPDATE. FR: Date de reception par le client. Delai = L_RECEIPTDATE - L_SHIPDATE."

Set-Desc "snowflake_table_column" "$liColBase/L_SHIPINSTRUCT" "L_SHIPINSTRUCT" "Shipping instructions. Values: DELIVER IN PERSON, COLLECT COD, NONE, TAKE BACK RETURN. FR: Instructions d'expedition : DELIVER IN PERSON, COLLECT COD, NONE, TAKE BACK RETURN."

Set-Desc "snowflake_table_column" "$liColBase/L_SHIPMODE" "L_SHIPMODE" "Shipping mode/carrier. Values: AIR, FOB, MAIL, RAIL, REG AIR, SHIP, TRUCK. Affects delivery time and cost analysis. FR: Mode d'expedition : AIR, FOB, MAIL, RAIL, REG AIR, SHIP, TRUCK."

Set-Desc "snowflake_table_column" "$liColBase/L_COMMENT" "L_COMMENT" "Free-text line item comment. FR: Commentaire libre sur la ligne de commande."

# =============================================================================
# SECTION 4: TPCDS_SF10TCL COLUMN DESCRIPTIONS (KEY COLUMNS)
# =============================================================================
Write-Host "`n=== TPCDS_SF10TCL COLUMN DESCRIPTIONS ==="

# CUSTOMER columns
$tcdsCustBase = "$sfQnBase/TPCDS_SF10TCL/tables/CUSTOMER/columns"

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_CUSTOMER_SK" "C_CUSTOMER_SK" "Surrogate key for the customer dimension. Auto-generated integer. Primary key used in all fact table joins. FR: Cle de substitution de la dimension client. Cle primaire utilisee dans toutes les jointures de tables de faits."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_CUSTOMER_ID" "C_CUSTOMER_ID" "Business key / natural key for the customer. Alphanumeric string (e.g., 'AAAAAAAABAAAAAAA'). Persists across SCD changes, unlike C_CUSTOMER_SK. FR: Cle metier / cle naturelle du client. Persiste a travers les changements SCD, contrairement a C_CUSTOMER_SK."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_CURRENT_CDEMO_SK" "C_CURRENT_CDEMO_SK" "Foreign key to current CUSTOMER_DEMOGRAPHICS record. Links to demographic attributes (gender, education, credit rating). FR: Cle etrangere vers le profil demographique actuel du client (genre, education, notation credit)."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_CURRENT_HDEMO_SK" "C_CURRENT_HDEMO_SK" "Foreign key to current HOUSEHOLD_DEMOGRAPHICS record. Links to household attributes (income band, size, vehicle count). FR: Cle etrangere vers la demographie du menage actuel (tranche de revenu, taille, nombre de vehicules)."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_CURRENT_ADDR_SK" "C_CURRENT_ADDR_SK" "Foreign key to current CUSTOMER_ADDRESS. Links to the customer's current geographic location. FR: Cle etrangere vers l'adresse actuelle du client."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_FIRST_NAME" "C_FIRST_NAME" "Customer first name. PII field. Used for personalization and customer identification. FR: Prenom du client. Donnee personnelle. Utilise pour la personnalisation et l'identification client."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_LAST_NAME" "C_LAST_NAME" "Customer last name. PII field. Combined with C_FIRST_NAME for full name display. FR: Nom de famille du client. Donnee personnelle. Combine avec C_FIRST_NAME pour le nom complet."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_PREFERRED_CUST_FLAG" "C_PREFERRED_CUST_FLAG" "Preferred customer flag. Values: Y/N. Indicates VIP or loyalty program status. Used for customer tier segmentation. FR: Indicateur client prefere : Y/N. Indique le statut VIP ou programme de fidelite."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_BIRTH_YEAR" "C_BIRTH_YEAR" "Customer birth year. Integer. Used to calculate age for demographic segmentation: age = current_year - C_BIRTH_YEAR. FR: Annee de naissance. Utilise pour calculer l'age : age = annee_courante - C_BIRTH_YEAR."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_BIRTH_COUNTRY" "C_BIRTH_COUNTRY" "Customer country of birth. Used for geographic origin analysis and diversity reporting. FR: Pays de naissance du client. Utilise pour l'analyse d'origine geographique."

Set-Desc "snowflake_table_column" "$tcdsCustBase/C_EMAIL_ADDRESS" "C_EMAIL_ADDRESS" "Customer email address. PII field subject to GDPR/privacy regulations. Used for digital communications and campaign targeting. FR: Adresse email du client. Donnee personnelle soumise au RGPD. Utilisee pour les communications digitales et le ciblage marketing."

# STORE_SALES key columns
$ssColBase = "$sfQnBase/TPCDS_SF10TCL/tables/STORE_SALES/columns"

Set-Desc "snowflake_table_column" "$ssColBase/SS_SOLD_DATE_SK" "SS_SOLD_DATE_SK" "Foreign key to DATE_DIM. Transaction date surrogate key. Essential for time-series analysis and fiscal period reporting. FR: Cle etrangere vers DATE_DIM. Essentiel pour l'analyse temporelle et le reporting par periode fiscale."

Set-Desc "snowflake_table_column" "$ssColBase/SS_CUSTOMER_SK" "SS_CUSTOMER_SK" "Foreign key to CUSTOMER.C_CUSTOMER_SK. Links transaction to customer. Required for customer-level revenue, CLV, and churn analysis. FR: Cle etrangere vers CUSTOMER.C_CUSTOMER_SK. Requis pour l'analyse du revenu par client, CLV et attrition."

Set-Desc "snowflake_table_column" "$ssColBase/SS_ITEM_SK" "SS_ITEM_SK" "Foreign key to ITEM.I_ITEM_SK. Part of composite primary key (SS_ITEM_SK, SS_TICKET_NUMBER). Identifies the product sold. FR: Cle etrangere vers ITEM.I_ITEM_SK. Partie de la cle primaire composite. Identifie le produit vendu."

Set-Desc "snowflake_table_column" "$ssColBase/SS_STORE_SK" "SS_STORE_SK" "Foreign key to STORE.S_STORE_SK. Identifies the physical store where the sale occurred. Used for store-level performance analysis. FR: Cle etrangere vers STORE.S_STORE_SK. Identifie le magasin physique. Utilise pour l'analyse de performance par magasin."

Set-Desc "snowflake_table_column" "$ssColBase/SS_QUANTITY" "SS_QUANTITY" "Number of items sold in this line. Integer. Used in extended amount calculations. FR: Nombre d'articles vendus. Utilise dans les calculs de montants etendus."

Set-Desc "snowflake_table_column" "$ssColBase/SS_SALES_PRICE" "SS_SALES_PRICE" "Actual unit selling price after any negotiation. Decimal. Typically between SS_WHOLESALE_COST and SS_LIST_PRICE. FR: Prix de vente unitaire reel apres negociation. Generalement entre SS_WHOLESALE_COST et SS_LIST_PRICE."

Set-Desc "snowflake_table_column" "$ssColBase/SS_LIST_PRICE" "SS_LIST_PRICE" "Listed/catalog unit price before discount. Decimal. Used to calculate discount: discount_pct = 1 - (SS_SALES_PRICE / SS_LIST_PRICE). FR: Prix catalogue unitaire avant remise. Calcul remise : taux_remise = 1 - (SS_SALES_PRICE / SS_LIST_PRICE)."

Set-Desc "snowflake_table_column" "$ssColBase/SS_WHOLESALE_COST" "SS_WHOLESALE_COST" "Unit wholesale cost (cost of goods). Decimal. Used for margin calculation: margin = SS_SALES_PRICE - SS_WHOLESALE_COST. FR: Cout de revient unitaire. Calcul marge : marge = SS_SALES_PRICE - SS_WHOLESALE_COST."

Set-Desc "snowflake_table_column" "$ssColBase/SS_EXT_SALES_PRICE" "SS_EXT_SALES_PRICE" "Extended sales amount. Calculation: SS_SALES_PRICE * SS_QUANTITY. Total revenue from this line item before coupons and tax. FR: Montant de vente etendu. Calcul : SS_SALES_PRICE * SS_QUANTITY. Revenu total de cette ligne avant coupons et taxes."

Set-Desc "snowflake_table_column" "$ssColBase/SS_EXT_DISCOUNT_AMT" "SS_EXT_DISCOUNT_AMT" "Total discount amount. Calculation: (SS_LIST_PRICE - SS_SALES_PRICE) * SS_QUANTITY. Represents revenue lost to discounts. FR: Montant total de remise. Calcul : (SS_LIST_PRICE - SS_SALES_PRICE) * SS_QUANTITY. Represente le revenu perdu par les remises."

Set-Desc "snowflake_table_column" "$ssColBase/SS_EXT_WHOLESALE_COST" "SS_EXT_WHOLESALE_COST" "Extended wholesale cost. Calculation: SS_WHOLESALE_COST * SS_QUANTITY. Total cost of goods sold for this line. FR: Cout de revient etendu. Calcul : SS_WHOLESALE_COST * SS_QUANTITY."

Set-Desc "snowflake_table_column" "$ssColBase/SS_EXT_TAX" "SS_EXT_TAX" "Extended tax amount on the sale. Applied to SS_NET_PAID. FR: Montant de taxe etendu sur la vente. Applique sur SS_NET_PAID."

Set-Desc "snowflake_table_column" "$ssColBase/SS_COUPON_AMT" "SS_COUPON_AMT" "Coupon discount amount applied to this transaction. Reduces net paid: SS_NET_PAID = SS_EXT_SALES_PRICE - SS_COUPON_AMT. FR: Montant du coupon de reduction. Reduit le montant net : SS_NET_PAID = SS_EXT_SALES_PRICE - SS_COUPON_AMT."

Set-Desc "snowflake_table_column" "$ssColBase/SS_NET_PAID" "SS_NET_PAID" "Net amount paid after coupons, before tax. Calculation: SS_EXT_SALES_PRICE - SS_COUPON_AMT. Represents actual cash collected from the customer (ex-tax). FR: Montant net paye apres coupons, avant taxes. Calcul : SS_EXT_SALES_PRICE - SS_COUPON_AMT."

Set-Desc "snowflake_table_column" "$ssColBase/SS_NET_PAID_INC_TAX" "SS_NET_PAID_INC_TAX" "Net amount paid including tax. Calculation: SS_NET_PAID + SS_EXT_TAX. Total amount collected from the customer. FR: Montant net paye taxes incluses. Calcul : SS_NET_PAID + SS_EXT_TAX. Montant total collecte aupres du client."

Set-Desc "snowflake_table_column" "$ssColBase/SS_NET_PROFIT" "SS_NET_PROFIT" "Net profit from this sale. Calculation: SS_NET_PAID - SS_EXT_WHOLESALE_COST. Key profitability metric at the line-item level. Negative values indicate a loss. FR: Profit net de cette vente. Calcul : SS_NET_PAID - SS_EXT_WHOLESALE_COST. Indicateur cle de rentabilite. Valeur negative = perte."

# =============================================================================
# SECTION 5: GLOSSARY TERM LINKS
# =============================================================================
Write-Host "`n=== GLOSSARY TERM LINKS ==="

# Atlas Glossary Term GUIDs (Customer + Finance glossaries)
$termMap = @{
    # Customer glossary (dbbb44b9-8f48-43f6-a44a-47aec06bed9b)
    "Customer Segment"               = "0f9b76b4-40f2-4563-aebd-6b6baeeb6c19"
    "CLV"                            = "a3fcf47f-ec2e-45da-b3fc-930e80e6e981"
    "Churn Rate"                     = "b6c12d11-d70e-479f-a251-651418981218"
    "CSAT"                           = "a6c7b06c-6167-4580-a0f6-d2bcd4018786"
    "Customer Satisfaction"          = "97da7ffa-60a0-4324-af36-ed5bac750dd2"
    "CRM"                            = "8916e381-9e6b-40dd-8f2a-988ac8a291bb"
    "NPS"                            = "fa5e6c07-7688-40ea-9a16-6eba823c8ecc"
    "Sales Pipeline"                 = "ceee41f2-f823-4b3b-9225-a3378daf7c00"
    "ARPU"                           = "5d09b90d-0a33-4bef-b5db-7707b0ac17ca"
    "Customer KPI"                   = "01bcc32b-ab03-4cbc-a7f6-b92c4c9b50fb"
    "Opportunity"                    = "f4faffff-76f8-4dee-b7a8-3101a5402d92"
    "Win Rate"                       = "b26614f3-bcde-4077-ac3a-cfdded9ab6fe"
    "Lead"                           = "fffb24ef-b230-4e60-b627-786900aeb8bb"
    # Finance glossary (cd9471d5-13d3-45a8-9305-8b415e5b0618)
    "Net Revenue"                    = "9ae458ec-1baf-449d-9cf4-a2505086c4b4"
    "Profitability"                  = "2c070b36-1435-43e9-932f-2fd5bd8b2ab4"
    "Net Profit Margin"              = "54049fb7-eb75-4487-ab9f-5f87f1c6de29"
    "Gross Profit Margin"            = "db2a849b-af63-4491-a133-c6dd33790530"
    "EBITDA"                         = "455d0cbe-fb14-41ca-9f17-d1f62231a1ab"
    "Cash Flow"                      = "8cc7f354-6a65-430b-81ac-565d74790922"
    "Operating Expenses"             = "267ba2e2-8918-42a0-842a-ef4a9f29376c"
    "COGS"                           = "3e2da9c5-6a76-4bae-9d32-82425defbbfc"
}

# Entity GUIDs
$entityMap = @{
    # TPCH_SF1
    "TPCH_CUSTOMER"        = "183cdb2a-dd72-497f-8a10-44f6f6f60000"
    "TPCH_ORDERS"          = "040af482-eef1-477a-9f8d-f5f6f6f60000"
    "TPCH_LINEITEM"        = "bf8d0719-0ba5-45d9-a96c-1df6f6f60000"
    # TPCH_SF1 columns
    "C_CUSTKEY"            = "183cdb2a-dd72-497f-8a10-44f6f6f60006"
    "C_MKTSEGMENT"         = "183cdb2a-dd72-497f-8a10-44f6f6f60002"
    "C_ACCTBAL"            = "183cdb2a-dd72-497f-8a10-44f6f6f60003"
    "C_PHONE"              = "183cdb2a-dd72-497f-8a10-44f6f6f60004"
    "C_ADDRESS"            = "183cdb2a-dd72-497f-8a10-44f6f6f60007"
    "O_TOTALPRICE"         = "040af482-eef1-477a-9f8d-f5f6f6f60009"
    "L_EXTENDEDPRICE"      = "bf8d0719-0ba5-45d9-a96c-1df6f6f60008"
    "L_DISCOUNT"           = "bf8d0719-0ba5-45d9-a96c-1df6f6f60007"
    # TPCDS_SF10TCL
    "TPCDS_CUSTOMER"       = "ff85faf3-8863-479e-a443-bff6f6f60000"
    "TPCDS_STORE_SALES"    = "2e61c851-0afb-4580-84af-c3f6f6f60000"
    # TPCDS columns
    "C_CUSTOMER_ID"        = "ff85faf3-8863-479e-a443-bff6f6f60003"
    "C_CUSTOMER_SK"        = "ff85faf3-8863-479e-a443-bff6f6f60005"
    "C_EMAIL_ADDRESS"      = "ff85faf3-8863-479e-a443-bff6f6f60010"
    "C_PREFERRED_CUST_FLAG" = "ff85faf3-8863-479e-a443-bff6f6f60001"
    "SS_EXT_SALES_PRICE"   = "2e61c851-0afb-4580-84af-c3f6f6f60008"
    "SS_NET_PROFIT"        = "2e61c851-0afb-4580-84af-c3f6f6f6000d"
    "SS_NET_PAID"          = "2e61c851-0afb-4580-84af-c3f6f6f60015"
}

# Linking: term -> entities (using assignedEntities API)
function Link-Term($termGuid, $termName, $entityGuids) {
    $entities = @()
    foreach ($eg in $entityGuids) {
        $entities += @{ guid = $eg }
    }
    $body = $entities | ConvertTo-Json -Depth 3
    if ($entities.Count -eq 1) { $body = "[$body]" }
    try {
        Invoke-RestMethod -Uri "$base/catalog/api/atlas/v2/glossary/terms/$termGuid/assignedEntities?api-version=2022-08-01-preview" -Headers $headers -Method POST -Body $body | Out-Null
        Write-Host "  LINKED $termName -> $($entityGuids.Count) entities"
    } catch { Write-Host "  LINK-FAIL $termName : $($_.ErrorDetails.Message)" }
}

# Customer Segment -> C_MKTSEGMENT, C_PREFERRED_CUST_FLAG
Link-Term $termMap["Customer Segment"] "Customer Segment" @($entityMap["C_MKTSEGMENT"], $entityMap["C_PREFERRED_CUST_FLAG"])

# CLV -> C_ACCTBAL, SS_NET_PAID
Link-Term $termMap["CLV"] "CLV" @($entityMap["C_ACCTBAL"], $entityMap["SS_NET_PAID"])

# Churn Rate -> CUSTOMER tables
Link-Term $termMap["Churn Rate"] "Churn Rate" @($entityMap["TPCH_CUSTOMER"], $entityMap["TPCDS_CUSTOMER"])

# Sales Pipeline -> LINEITEM, STORE_SALES, ORDERS
Link-Term $termMap["Sales Pipeline"] "Sales Pipeline" @($entityMap["TPCH_LINEITEM"], $entityMap["TPCDS_STORE_SALES"], $entityMap["TPCH_ORDERS"])

# Customer Satisfaction -> CUSTOMER tables
Link-Term $termMap["Customer Satisfaction"] "Customer Satisfaction" @($entityMap["TPCH_CUSTOMER"], $entityMap["TPCDS_CUSTOMER"])

# Net Revenue -> O_TOTALPRICE, L_EXTENDEDPRICE, SS_EXT_SALES_PRICE
Link-Term $termMap["Net Revenue"] "Net Revenue" @($entityMap["O_TOTALPRICE"], $entityMap["L_EXTENDEDPRICE"], $entityMap["SS_EXT_SALES_PRICE"])

# Net Profit Margin -> SS_NET_PROFIT
Link-Term $termMap["Net Profit Margin"] "Net Profit Margin" @($entityMap["SS_NET_PROFIT"])

# Profitability -> STORE_SALES
Link-Term $termMap["Profitability"] "Profitability" @($entityMap["TPCDS_STORE_SALES"])

# CRM -> CUSTOMER tables
Link-Term $termMap["CRM"] "CRM" @($entityMap["TPCH_CUSTOMER"], $entityMap["TPCDS_CUSTOMER"])

# CSAT -> CUSTOMER table
Link-Term $termMap["CSAT"] "CSAT" @($entityMap["TPCH_CUSTOMER"])

# ARPU -> O_TOTALPRICE, SS_EXT_SALES_PRICE
Link-Term $termMap["ARPU"] "ARPU" @($entityMap["O_TOTALPRICE"], $entityMap["SS_EXT_SALES_PRICE"])

# Customer KPI -> CUSTOMER tables
Link-Term $termMap["Customer KPI"] "Customer KPI" @($entityMap["TPCH_CUSTOMER"], $entityMap["TPCDS_CUSTOMER"])

# Opportunity -> ORDERS, STORE_SALES
Link-Term $termMap["Opportunity"] "Opportunity" @($entityMap["TPCH_ORDERS"], $entityMap["TPCDS_STORE_SALES"])

# Win Rate -> ORDERS
Link-Term $termMap["Win Rate"] "Win Rate" @($entityMap["TPCH_ORDERS"])

# Lead -> LINEITEM
Link-Term $termMap["Lead"] "Lead" @($entityMap["TPCH_LINEITEM"])

# EBITDA -> SS_NET_PROFIT, SS_NET_PAID
Link-Term $termMap["EBITDA"] "EBITDA" @($entityMap["SS_NET_PROFIT"], $entityMap["SS_NET_PAID"])

# Cash Flow -> O_TOTALPRICE, SS_NET_PAID
Link-Term $termMap["Cash Flow"] "Cash Flow" @($entityMap["O_TOTALPRICE"], $entityMap["SS_NET_PAID"])

# Gross Profit Margin -> L_EXTENDEDPRICE, L_DISCOUNT
Link-Term $termMap["Gross Profit Margin"] "Gross Profit Margin" @($entityMap["L_EXTENDEDPRICE"], $entityMap["L_DISCOUNT"])

# Operating Expenses -> SS_NET_PROFIT
Link-Term $termMap["Operating Expenses"] "Operating Expenses" @($entityMap["SS_NET_PROFIT"])

Write-Host "`n=== ENRICHMENT COMPLETE ==="
