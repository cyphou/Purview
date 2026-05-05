# 📊 Microsoft Purview Data Governance — Tenant Inventory & Gap Analysis

**🌐 Account**: `pdedemopurv` | **📍 Region**: West US 2 | **💳 SKU**: Standard  
**🏢 Tenant**: `2bfad6b9-88f6-4129-a60f-457babf01498` | **📎 Subscription**: ME-MngEnvMCAP965390-pidoudet-1  
**📅 Date**: May 4, 2026 (Sprints 1-5 executed)

---

## 🎯 0. UNIFIED CATALOG — CURRENT STATE (Sprint 5)

### 🏗️ Domain Hierarchy (16 domains, no root wrapper)

```
💰 Finance and ESG [LoB] (da176475)
├── Accounting and Reporting [DataDomain] (2e6172a3) — 7 terms
├── Treasury and Risk [DataDomain] (3b41ca19) — 4 terms
└── ESG and Sustainability [DataDomain] (897ce3a4) — 6 terms
🤝 Customer and Sales [LoB] (f1b1d5fe)
├── CRM and Customer Data [DataDomain] (59a9c793) — 6 terms
└── Commercial Analytics [DataDomain] (9499d5ed) — 5 terms
👥 HR and People [LoB] (f64840cf)
├── Talent Management [DataDomain] (ce3259a5) — 5 terms
└── Workforce Analytics [DataDomain] (4aa514cd) — 5 terms
⚙️ Operations and Industrial [LoB] (84f0ee4c)
├── Industrial Assets [DataDomain] (2c339176) — 7 terms
└── Supply Chain and Logistics [DataDomain] (77cff024) — 5 terms
💻 Technology and Data Platform [LoB] (7f5695d1)
├── Data Engineering [DataDomain] (8e077509) — 5 terms
└── BI and Analytics [DataDomain] (68219526) — 5 terms
```

### 📖 Glossary Terms (75 UC terms with owner/steward/CDO contacts)

60 sub-domain terms (Sprint 5) + 15 LoB umbrella terms (Sprint UC-E) so every LoB root tile shows first-class entries (3 each):
- **Finance and ESG**: Enterprise Financial KPI (EFK), ESG Disclosure Metric (ESG, CSRD), Financial Reporting Period (FRP)
- **Customer and Sales**: Customer Master Record (CMR, MDM-C), Customer Engagement Event (CEE), Sales Performance Indicator (SPI)
- **HR and People**: Employee Master Record (EMR), Workforce Performance Indicator (WPI), People Lifecycle Event (PLE)
- **Operations and Industrial**: Industrial Asset Identifier (IAI), Operational Performance Indicator (OPI), Safety and Reliability Event (SRE)
- **Technology and Data Platform**: Data Platform Health Indicator (DPHI), Data Product Certification (DPC), Data Lineage Anchor (DLA)

All 75 terms are Published, each assigned to its parent domain with contacts for owner, steward, and CDO.

### 🔗 Sprint UC-F: DP→Term Bulk Linking (39 relationships)

Discovered the working REST endpoint for DP→Term relationships:
- `POST /datagovernance/catalog/dataproducts/{id}/relationships?entityType=Term&api-version=2026-03-20-preview`
- Body: `{"relationshipType":"Related","entityId":"<termId>"}`
- Returns 200; idempotent (re-POST returns 200, no duplicate created)
- Same endpoint with `entityType=DataAsset` lists/creates DP↔Asset links
- `entityType=CriticalDataColumn` returns 400 "not supported" (use `Term` instead)
- `GET .../relationships?entityType=Term` returns the current attached set

Term counts per DP after bulk attach (`attach_terms_to_dps.ps1`):

| Data Product | Terms attached |
|---|---|
| Executive Financial Dashboards | 7 (Enterprise Financial KPI, Financial Reporting Period, Revenue, EBITDA, Net Income, Cost Center, Budget Variance) |
| ESG and CSRD Reporting Pack | 6 (ESG Disclosure Metric, Enterprise Financial KPI, Carbon Footprint, ESG Score, CSRD Compliance, +1 prior) |
| Customer 360 | 11 (CMR, CEE, SPI, Customer ID, CLV, Churn Rate, NPS, Sales Pipeline, Lead Conversion Rate, AOV, +1 prior) |
| Workforce Analytics Dashboard | 6 (EMR, WPI, PLE, Employee ID, Headcount, Turnover Rate) |
| Operational Performance Hub | 5 (IAI, OPI, SRE, +2 prior) |
| Data Platform Health Monitor | 4 (DPHI, DPC, DLA, +1 prior) |

Result: each term attached now shows the DP under its **Related → Data products** panel; each DP shows its terms in its **Terms** section. "Market Segment" was the only term in the planned mapping that didn't exist (one of the 60 sub-domain terms was renamed at creation).

### 🏷️ Sprint UC-G: Custom Metadata via REST (3 groups, 11 named attributes)

**Breakthrough**: discovered `POST /datagovernance/catalog/customMetadata?api-version=2026-03-20-preview` accepts schema definitions WITH preserved attribute names (the old `/attributes` endpoint silently overwrote `name` with a GUID — see Sprint UC-D). This is the modern UC equivalent of "Custom attributes" / "Managed attributes".

Endpoint shape (a `customMetadata` is a **group** containing typed `attributes`, scoped to which entity types/domains/DP-types it applies to):

| Verb | Path | Notes |
|---|---|---|
| `GET` | `/customMetadata` | List all groups (works) |
| `GET` | `/customMetadata/{id}` | **405 Method Not Allowed** |
| `POST` | `/customMetadata` | Create group; `status="Published"` is REQUIRED (Draft/Disabled/Deleted enums all reject) |
| `PUT` | `/customMetadata/{id}` | Update; must send FULL body |
| `DELETE` | `/customMetadata/{id}` | **405 Method Not Allowed** — groups can only be renamed, not deleted via REST |

Schema body fields:
- `name`, `type` ("BusinessConcept"), `status` ("Published"), `description`
- `scope.applicableConstructs.businessConcepts` — `["DataProduct"]` / `["Term"]` / etc., or `includesAll=true`
- `scope.applicableConstructs.domains` — list of domain GUIDs or `includesAll=true`
- `scope.applicableConstructs.dataProductTypes` — `["Dataset","DashboardsOrReports","SemanticModel","AnalyticsModel"]` or `includesAll=true`
- `attributes[]` — each with `name`, `type` ("string"), `status` ("Published"), `isOptional`, `scope.inheritApplicableConstructsFromGroup=true`, `options`

Created groups (all Published, scope = all domains, all DP types):

| Group | Applies to | Attributes |
|---|---|---|
| **Data Product Operations** | DataProduct | Refresh Frequency, Data Classification, Business Criticality, SLA Target, Personal Data, Retention Period |
| **Data Product Compliance** | DataProduct | Regulatory Framework, Source System, Cost Center |
| **Glossary Term Governance** | Term | Calculation Rule, Regulatory Reference |

**Still portal-only**: applying VALUES to a specific DP. Tested PUT /dataproducts/{id} with `customMetadata: [...]` payload — HTTP 200 but value silently dropped on read-back. Same finding as Sprint UC-D for the old endpoint. Per-DP value entry remains a manual portal step.

### 🔄 Sprint UC-H: Wire the Documented Relationship APIs (32 relationships)

After reviewing the official UC REST surface (8 operation groups, doc updated 2026-04-24), exercised the `Add Related Entity` / `Create Relationship` endpoints we hadn't used.

**Allowed `relationshipType` values for term-term**: `Synonym` and `Related` ONLY (matches the two rows shown on a term's Related tab in the portal — `SeeAlso`, `Replaces`, `Translation`, `RelatedTo`, `ReplacedBy` all return HTTP 400).

**Allowed `entityType` values discovered (POST direction)**:
| Parent | Allowed inbound entityType for POST |
|---|---|
| `terms/{id}` | Term, DataAsset, DataProduct |
| `criticalDataElements/{id}` | Term, DataColumn, CriticalDataColumn |
| `dataproducts/{id}` | Term, DataAsset, DataProduct, CriticalDataColumn |

Note GET supports more entity types than POST on each resource (asymmetric): you can list relationships of an entityType you cannot create. Most notably **DP↔CDE cannot be created in either direction** — only via CriticalDataColumn (column-instance) intermediaries.

**Created 32 relationships** (`sprint_uc_h_relationships.ps1`):

Part 1 — Term-Term (17): umbrella↔detail term linking populates the "Related" panel on every term page.
- Finance: Revenue/EBITDA/Net Income/Cost Center → Enterprise Financial KPI; Carbon Footprint/ESG Score/CSRD Compliance → ESG Disclosure Metric
- Customer: CLV → Customer Master Record; NPS → Customer Engagement Event; Sales Pipeline/Lead Conversion/AOV → Sales Performance Indicator; Customer ID **synonym** Customer Master Record; CLV ↔ NPS
- HR: Headcount/Turnover Rate → Workforce Performance Indicator; Employee ID → Employee Master Record

Part 2 — CDE-Term (15): each CDE now points to its conceptual term (populates "Related terms" on every CDE).
- All 15 CDEs in our 5 LoB domains linked: GL Account Number, Fiscal Period, Reporting Currency, Customer Master ID, Email Address (PII), Customer Lifetime Value, Employee ID, Compensation Band, Cost Center, Equipment ID, Work Order Number, Material Number, Asset Sensitivity Label, Data Quality Score, Owner Email.

Part 3 — DP↔CDE: blocked both directions (REST limit, see table above). **Sprint UC-I unlocks the column-instance bridge below.**

### 🏛️ Sprint UC-I: CriticalDataColumn — Bridging CDEs to Data Assets (15 CDCs, 15 CDE→CDC links)

`CriticalDataColumn` (CDC) is the column-instance entity that materializes a CDE concept on a real `DataAsset` column. Created 1 CDC per CDE (15 total) via `sprint_uc_i_critical_data_columns.ps1`, then linked each CDE → its CDC.

**Endpoint shape**:

| Verb | Path | Notes |
|---|---|---|
| `POST` | `/datagovernance/catalog/criticalDataColumns` | Create. Body: `{ name, domain, assetId, assetName, columnName?, columnId?, criticalDataElementId?, status:"Published" }` |
| `GET`  | `/criticalDataColumns/{id}` | Read back — note `criticalDataElementId`, `columnId`, `columnName` are stored but NOT echoed (use `/relationships` to inspect link) |
| `DELETE` | `/criticalDataColumns/{id}` | 204 — but BLOCKED with HTTP 400 if any inbound relationships exist; unlink first |
| `POST` | `/dataAssets/query` | Required to discover valid `assetId` values (UC dataAsset GUIDs, NOT Atlas GUIDs) |

**Critical schema gotcha**: `assetId` MUST be a **UC `dataAsset.id`** (e.g. `26296e20-…`), NOT the underlying Atlas GUID (e.g. `0d401759-…` returned by `/catalog/api/search/query`). Using an Atlas GUID gets accepted at CDC creation time (HTTP 201) but blocks all downstream relationships with `DataCatalogNotFoundError: DataAsset with id … does not exist`. UC and Atlas have separate asset registries; use `GET /datagovernance/catalog/dataAssets` to enumerate UC-side IDs.

**Relationship matrix on `/criticalDataColumns/{id}/relationships?entityType=…`**:

| entityType | POST | GET |
|---|---|---|
| `CriticalDataElement` | ✅ 200 | ✅ 200 |
| `DataAsset` | ✅ allowed | ✅ |
| `Term` | ✅ allowed | ✅ |
| `DataProduct` | ❌ 400 — only `CriticalDataElement,DataAsset,Term` permitted (despite docs implying DP↔CDC support) |

So the **DP→CDE bridge** sought in UC-H Part 3 still cannot be created end-to-end via REST — the CDC layer connects CDE↔column but the DP↔CDC link itself is rejected (the DP-side endpoint says "must be `DataProduct,CriticalDataColumn`" but rejects `CriticalDataColumn` regardless; the CDC-side endpoint excludes `DataProduct`). DP→CDE indirect path through `Term` (DP→Term→CDE) remains the only working route.

**15 CDCs created**, each linked to a UC dataAsset that exists in the catalog (Power BI tables/datasets — this tenant has no schema-rich relational assets registered as UC dataAssets):

| CDE | CDC name | UC DataAsset |
|---|---|---|
| GL Account Number | Finance Report.account_id | Finance Report (powerbi_dataset) |
| Fiscal Period | dimension_date.fiscal_period | dimension_date (powerbi_table) |
| Reporting Currency | fact_sale.currency_code | fact_sale (powerbi_table) |
| Customer Master ID | dimension_customer.customer_id | dimension_customer (powerbi_table) |
| Email Address (PII) | dimension_customer.email | dimension_customer |
| Customer Lifetime Value | dimension_customer.ltv_score | dimension_customer |
| Employee ID | aggregate_sale_by_date_employee.employee_id | aggregate_sale_by_date_employee |
| Compensation Band | aggregate_sale_by_date_employee.comp_band | aggregate_sale_by_date_employee |
| Cost Center | aggregate_sale_by_date_employee.cost_center | aggregate_sale_by_date_employee |
| Equipment ID | wwilakehouse-DirectLake.equipment_id | wwilakehouse-DirectLake (powerbi_dataset) |
| Work Order Number | wwilakehouse-DirectLake.work_order_id | wwilakehouse-DirectLake |
| Material Number | wwilakehouse-DirectLake.material_id | wwilakehouse-DirectLake |
| Asset Sensitivity Label | Purview Hub.sensitivity | Purview Hub |
| Data Quality Score | exec_requests_history.dq_score | exec_requests_history |
| Owner Email | Purview Hub.owner_email | Purview Hub |

Result: each CDE page now shows its column instance under **Critical data columns**, and each CDC page shows its parent CDE. The 30 CDEs that were originally created with broken Atlas-asset references were cleaned up by first unlinking each CDE→CDC relationship (`DELETE /criticalDataColumns/{id}/relationships?entityType=CriticalDataElement&entityId=…` → 204) then deleting the CDC.

### 🟢🟡🟠 Sprint UC-J: Fake Data Quality (custom metadata + Atlas classifications)

Real DQ scoring requires the Spark scan service (managed identity, profiling, rules, scan run). The DQ REST surface in this account is **read-only**: the only routable path is `GET /datagovernance/quality/scores?filterId={id}` which returns `{"scores":[],"continuationToken":null}` until a scan executes (the service ignores `api-version`; all `POST/PUT /scores`, `/jobs`, `/rules`, `/profiles`, `/connections` etc. return 404). To still demonstrate DQ governance over assets, we used two REST-doable workarounds:

**1) New `Data Quality` customMetadata group** (group id `4ece4411-417f-433d-92a6-e18c03097f2e`) scoped to `DataProduct` only (the `businessConcepts` enum rejects `DataAsset`). Five string attributes: `Quality Score (0-100)`, `Quality Tier`, `Last Scan Date`, `Active Rules`, `Last Scan Findings`. Per UC-D limitation, values must still be entered in the portal — REST `PUT /dataproducts/{id}` accepts the `customMetadata` payload but silently drops it on read-back.

**2) Atlas classification typedefs `DQ_Gold` / `DQ_Silver` / `DQ_Bronze`** applied to 85/86 UC dataAssets' underlying Atlas entities. Hyphens are forbidden in classification names (`ATLAS-400-00-019: Names must consist of a letter followed by a sequence of letter, number, space, or _`), and the `POST /entity/guid/{guid}/classifications` endpoint requires a **bare JSON array** body `[{ typeName, propagate }]` — wrapping in `{ classifications: [...] }` returns 400 (`Cannot deserialize value of type java.util.ArrayList`). Tier mapping:

| Tier | Atlas typeName | Asset count | Examples |
|---|---|---|---|
| 🟢 Gold | `DQ_Gold` | 7 | Finance Report, FSI CCO Dashboard, fact_sale, dimension_customer, Purview Hub, wwilakehouse-DirectLake |
| 🟡 Silver | `DQ_Silver` | 6 | dimension_date, dimension_city, aggregate_sale_by_date_city, aggregate_sale_by_date_employee, exec_requests_history, fact_sale (1) |
| 🟠 Bronze | `DQ_Bronze` | 72 | everything else (default) |

These chips show in the Data Map asset view and in lineage. Script: `sprint_uc_j_fake_data_quality.ps1` (idempotent — re-runs PUT the customMetadata group and skip already-classified entities).

### 📦 Data Products (6 Published)

| Data Product | Domain | Owner | ID |
|-------------|--------|-------|-----|
| Executive Financial Dashboards | Accounting and Reporting | financeowner | `4baeadc4` |
| ESG and CSRD Reporting Pack | Finance and ESG | financeowner | `c5e22498` |
| Customer 360 | Customer and Sales | customer.owner | `dd58e805` |
| Workforce Analytics Dashboard | HR and People | hr.owner | `62ad4ddf` |
| Operational Performance Hub | Operations and Industrial | ops.owner | `4302076b` |
| Data Platform Health Monitor | Technology and Data Platform | tech.owner | `2493e522` |

### 🎯 Business Features (Sprint 5d) — OKRs, CDEs, Custom Attributes

**5 Objectives (OKRs) Published, one per LoB**, each with 3 Key Results (15 KRs total):

| LoB | Objective | KRs |
|-----|-----------|-----|
| Finance and ESG | Achieve top-quartile financial reporting accuracy and ESG transparency | Close cycle <5d, 100% CSRD coverage, -50% DQ incidents |
| Customer and Sales | Deliver a unified, trusted Customer 360 view across all channels | 100% touchpoint onboarding, +8 NPS, -30% ticket resolution time |
| HR and People | Build a data-driven, equitable, high-performing workforce | <8% attrition, 100% manager adoption, <2% pay gap |
| Operations and Industrial | Improve plant uptime, safety, and supply-chain visibility | OEE 85%, -25% downtime, TRIR=0 |
| Technology and Data Platform | Establish a trusted, governed, scalable enterprise data platform | 80% certified DPs, 95% classified, MTTD <2 days |

**15 Critical Data Elements (CDEs) Published**, distributed across LoBs:
- **Finance**: GL Account Number, Fiscal Period, Reporting Currency
- **Customer**: Customer Master ID, Email Address (PII), Customer Lifetime Value
- **HR**: Employee ID, Compensation Band, Cost Center
- **Operations**: Equipment ID, Work Order Number, Material Number
- **Technology**: Asset Sensitivity Label, Data Quality Score, Owner Email

**Custom Attributes** (10 portal-defined, no REST-creatable replacements possible — see Sprint D below):
- Portal-only attributes: Report Type, Technology, Reporting type, External Usage, Name (x2), Description (x2), Calculation Rule (x2). The 10 LoB-specific attributes attempted in Sprint 5d (Reporting Pillar, Materiality Tier, Channel, Consent Status, Confidentiality Class, Workforce Segment, Site Code, Criticality Class, Certification Level, Refresh Frequency) were **rolled back in Sprint D** — see API limitation note below.

### 👻 Ghost Entries (eventual consistency lag)
- 22 old Atlas-created domains still appear in UC list (Atlas GET returns 404 — truly deleted)
- 4 old data products still appear (Atlas GET returns 404 — truly deleted)
- 8 migrated terms from old Atlas glossaries still appear
- These should self-resolve; if persistent, requires support ticket

### ⚠️ Known API Limitations Discovered
- **UC term → asset linking**: Not supported via REST API (`2026-03-20-preview`). UC terms are not Atlas entities; Atlas `assignedEntities` endpoint returns 404. Must use portal.
- **Published object deletion**: Must PUT `status=Draft` first, then DELETE.
- **Domain PUT requires `id`**: Body must include `id` matching URL parameter.
- **Old Atlas objects**: Return 403 on UC API operations → use Atlas API `DELETE /entity/guid/{id}` as fallback.
- **Data product POST requires `type`**: Must include `type: "Dataset"` field.
- **PATCH not supported**: Returns MethodNotAllowed on all UC endpoints.

### ✅ Working Business-Feature APIs (Sprint 5d Discoveries)
- **Objectives (OKRs)**: `POST /datagovernance/catalog/objectives` with body `{ definition, domain, targetDate, contacts, status: "Draft" }`. Publish via `PUT /objectives/{id}` with full body + `status: "Published"`. Sub-resource: `POST /objectives/{id}/keyResults` with `{ definition, domainId, progress, goal, max, status: "OnTrack" }`.
- **Critical Data Elements**: `POST /datagovernance/catalog/criticalDataElements` with `{ name, description, dataType, domain, contacts, status: "Draft" }`. Publish via PUT. Note: CDEs cannot be linked directly to data products via REST (`entityType` must be `DataProduct` or `CriticalDataColumn`); CDEs link to columns, not DPs.
- **Custom Attributes**: `PUT /datagovernance/catalog/attributes/{newGuid}` (POST returns 405) with `{ id, name, description, fieldType, defaultValue, domain, isOptional, status: "Published" }`.
- **Data Product relationships**: `POST /datagovernance/catalog/dataproducts/{dpId}/relationships?entityType=DataAsset|Term|CriticalDataColumn` with body `{ entityId }` returns 200.

### 📝 Sprint 5e — Data Product Enrichment + DQ Discovery
- **DP enrichment via PUT**: Supported writable fields are `description`, `businessUse`, `termsOfUse[]` (`{name,url}`), `documentation[]` (`{name,url}`), `endorsed`, `contacts`. The portal-visible fields **`audience`**, **`useCases`**, **`updateFrequency`**, **`activeSubscribers`** are NOT accepted by the `2026-03-20-preview` PUT (audience returns enum-conversion errors with no public enum docs; the others return 200 but are not persisted) — these appear to be portal-only or pending GA on a newer API version.
- **All 6 LoB data products enriched** with rich `businessUse`, 1-2 `termsOfUse` policy links, 2-3 `documentation` links, and `endorsed=true`.
- **Data Quality**: The DQ service endpoints (`/datagovernance/dataquality/*`, `/datagovernance/quality/*`, `/datagovernance/health/dataquality/*`) all return 404 on this account across `2023-10-01-preview`, `2024-02-01-preview`, and `2026-03-20-preview`. The "Data quality score" tile on a DP requires the **separately billed Purview Data Quality feature** to be enabled, plus profiling jobs and rules to be published via the portal. There is no REST path to inject a synthetic DQ score on a DP.

### 🔄 Sprint 6 — Operating Model: Cross-Domain Business Processes
5 `Purview_BusinessProcess` entities created via Atlas, each linked to its owning `Purview_DataDomain` (`represents`) and the Application Services that implement it (`isImplementedBy_ApplicationService`):

| Business Process | Domain | Implemented by | GUID |
|------------------|--------|----------------|------|
| Plan-to-Report | Finance and ESG | RADAR | `16089eb0` |
| Order-to-Cash | Customer and Sales | TDF MVP SMINT | `5da382a9` |
| Hire-to-Retire | HR and People | *(no AS yet — manual systems)* | `43542364` |
| Equipment-to-Maintenance | Operations and Industrial | 4 SAP services + RAMSES + 9 PI-DA-RC sites | `c91a1778` |
| Data-Asset-to-Insight | Technology and Data Platform | TDF MVP SMINT | `24b3ece6` |

**API**: `POST /catalog/api/atlas/v2/entity` with `typeName=Purview_BusinessProcess`, `attributes={qualifiedName, name, description}`, `relationshipAttributes={represents: {guid, typeName: "Purview_DataDomain"}, isImplementedBy_ApplicationService: [{guid, typeName}]}`. Note: `isImplementedBy_ApplicationService` is heterogeneous — accepts both `Purview_ApplicationService` and `SAP application service` typeNames in the same array.

### 🏷️ Sprint UC-A/B/C — Term Acronyms, OKR Progress, DP→BP Probe
- **A.4 — 30 UC terms tagged with acronyms** via `PUT /terms/{id}` (full body required including id, name, status, domain, description, contacts, acronyms[]). Examples: `OEE`, `MTBF`, `EBITDA`, `Net Promoter Score`→NPS, `Customer Lifetime Value`→[CLV, LTV], `Active Users`→[MAU, DAU], `Carbon Footprint`→CO2e, `CSRD Compliance`→CSRD, `Headcount`→HC, etc.
- **C.1 — 12 KRs updated with realistic mid-Q2 progress** (PUT `/objectives/{id}/keyResults/{krId}` with `progress`, `goal`, `max`, `status`). Status mix: 4 OnTrack, 7 AtRisk, 1 zero-goal special-case (TRIR=0). 3 missing KRs added (`100% manager adoption`, `-30% ticket resolution time`, `MTTD <2 days`) — Sprint 5d had only created 12/15.
- **B.2 — DP → BusinessProcess linking BLOCKED**: tested `entityType` values `BusinessProcess`, `Purview_BusinessProcess`, `Process`, `Asset` against `POST /dataproducts/{id}/relationships?entityType=...` — all return HTTP 400. The DP relationships endpoint only accepts `DataAsset`, `Term`, `CriticalDataColumn` (confirmed in Sprint 5c). Cross-linking UC DPs to Atlas BusinessProcesses is **not currently supported via REST**; portal Lineage view may show an indirect link via shared assets.

### 🚫 Sprint UC-D — Custom Attribute Names + Values (BLOCKED)
Deep probe of the `/attributes` endpoint revealed two hard REST limits, leading to **rollback of the 10 Sprint 5d LoB attributes**:
1. **Attribute display name is not REST-settable**. PUT `/attributes/{newGuid}` accepts the body but silently overwrites the `name` field with a server-generated GUID. The actual `name` returned by GET is never the string passed in the body. This is true for both PUT-with-id-in-body and PUT-without-id-in-body. POST returns 405. Result: any attribute created via REST appears in the portal with a GUID label — unusable.
2. **Attribute values cannot be applied to DPs (or any UC entity) via REST**. Tested `attributes`, `customAttributes`, `additionalAttributes`, `metadata`, `tags`, `properties` as fields in the DP PUT body — all return HTTP 200 but are silently dropped on read-back. The portal must be used to assign attribute values to entities.
3. **Cleanup performed**: 27 GUID-named ghost attributes (Sprint 5d residue + Sprint D probe artifacts) deleted via DELETE `/attributes/{id}`. Also discovered: PUT-with-status=Draft on a non-existent id CREATES a new ghost (don't use Draft-then-Delete; just DELETE directly).
4. **Net result**: only the 10 original portal-created attributes (Report Type, Technology, Reporting type, External Usage, plus 2x Name / Description / Calculation Rule pairs scoped to portal-defined domains) remain. New attributes with proper names must be created in the portal.

---

## 🗃️ 1. CURRENT STATE INVENTORY

### 🏢 1.1 Collections (25 collections)

| Code | Friendly Name | Purpose |
|------|--------------|---------|
| pdedemopurv | Root | Root collection |
| ngmbgw | *(unnamed)* | Sub-collection |
| hklbqp | *(primary — 7,347 assets)* | Main asset collection (Power BI, Fabric, etc.) |
| 242twh | *(Snowflake/SQL — 209 assets)* | Snowflake & Azure SQL assets |
| mxxncp | *(17 assets)* | Small collection |
| tjayvd | *(unnamed)* | Empty/minimal |
| 0pftnt | *(unnamed)* | Empty/minimal |
| vwo17u | OnPrem (278 assets) | On-premises sources |
| 7qip1a | Dynamics via Dataverse (347 assets) | Dynamics/Dataverse integration |
| bpnc43 | Salesforce (2 assets) | Salesforce source |
| kdlaul | AWS (45 assets) | AWS S3/Redshift sources |
| ozssv7 | PREPROD POC TTE | Pre-production POC |
| lqycix | CLOUD AZURE | Azure cloud |
| juxu00 | LEGACY RC | Legacy release candidate |
| icer4k | PREPROD POC TTE V2 | Pre-production POC v2 |
| jm5wyf | CLOUD AZURE V2 | Azure cloud v2 |
| f8cxsg | CLOUD AWS | AWS cloud |
| oktkz3 | LEGACY RC (1 asset) | Legacy |
| 6zun08 | LIFT Tenant (5 assets) | Lift & shift |
| oww41l | FABRIC tenant test | Fabric testing |
| eepgpq | transverse apps | Cross-cutting applications |
| jtecfo | RC branch assets (14 assets) | Release candidate branch |
| 9eabrc | GCP | Google Cloud Platform |
| 5e7u19 | Company Bis | Company division |
| if18wt | PROD | Production |
| fmjxwb | Company B (1,141 assets) | Company B division |
| udc9c8 | Fabric new | New Fabric workspace |
| w8nhgp | test | Testing |
| 3a4jsh | Fabric | Microsoft Fabric |
| 1qwzla | lnca | *(unnamed)* |
| kxwjyq | Domain Global | Global governance domain |
| phakjy | Global 1 | Global collection |

### 📊 1.2 Catalog Assets — 9,541 Total

#### 📁 By Entity Type (Top 20)

| Entity Type | Count | % |
|------------|-------|---|
| fabric_lakehouse_path | 5,699 | 59.7% |
| azure_datalake_gen2_path | 784 | 8.2% |
| fabric_lakehouse_table | 661 | 6.9% |
| azure_datalake_gen2_resource_set | 387 | 4.1% |
| dataverse_table | 346 | 3.6% |
| powerbi_dataset | 204 | 2.1% |
| fabric_synapse_notebook | 175 | 1.8% |
| powerbi_report | 133 | 1.4% |
| fabric_workspace | 107 | 1.1% |
| fabric_lake_warehouse | 97 | 1.0% |
| fabric_lakehouse | 93 | 1.0% |
| postgresql_view | 89 | 0.9% |
| fabric_pipeline | 88 | 0.9% |
| snowflake_table | 86 | 0.9% |
| mssql_table | 82 | 0.9% |
| postgresql_table | 68 | 0.7% |
| fabric_data_warehouse | 34 | 0.4% |
| AtlasGlossaryTerm | 33 | 0.3% |
| aws_s3_v2_object | 32 | 0.3% |
| azure_blob_container | 29 | 0.3% |

#### 📂 By Collection (asset distribution)

| Collection | Assets | Share |
|-----------|--------|-------|
| hklbqp (Primary) | 7,347 | 77.0% |
| fmjxwb (Company B) | 1,141 | 12.0% |
| 7qip1a (Dynamics/Dataverse) | 347 | 3.6% |
| vwo17u (OnPrem) | 278 | 2.9% |
| 242twh (Snowflake/SQL) | 209 | 2.2% |
| pdedemopurv (Root) | 97 | 1.0% |
| kdlaul (AWS) | 45 | 0.5% |
| mxxncp | 17 | 0.2% |
| jtecfo (RC branch) | 14 | 0.1% |
| 6zun08 (LIFT) | 5 | 0.1% |
| bpnc43 (Salesforce) | 2 | <0.1% |
| oktkz3 (Legacy RC) | 1 | <0.1% |

### 📖 1.3 Glossary — 6 Glossaries, 113 Terms Total

| Glossary | Terms | Details |
|----------|-------|---------|
| **HR** | 25 | Original 14 + Sprint 3: Headcount, Attrition Rate, Time to Hire, Cost per Hire, Employee Engagement, Training Hours, Diversity Index, Absenteeism Rate, Internal Mobility, Succession Plan, Performance Rating |
| **Operations** | 20 | **New glossary (Sprint 3)**: Work Order, Equipment, Downtime, OEE, MTBF, MTTR, Preventive/Corrective Maintenance, Inspection, Safety Incident, Supply Chain Lead Time, Inventory Turn, Production Batch, Quality Control, Throughput, Turnaround, Process Safety, Yield, Energy Consumption, Flaring |
| **Global** | 20 | **Populated (Sprint 3)**: Revenue, Customer, Employee, Asset, Contract, Data Quality Score, SLA, KPI, Business Unit, Region, Country, Currency, Fiscal Year, Budget, Forecast, Data Steward, Data Product, Governance Domain, Lineage, Classification |
| **Finance** | 25 | Original 9 + Sprint 3: EBITDA, Cash Flow, Working Capital, COGS, OpEx, ESG Score, Carbon Footprint, CSRD Metric, Scope 1/2/3 Emissions, Audit Trail, Variance Analysis, Net Revenue, CapEx, Depreciation |
| **Customer** | 20 | Original 7 + Sprint 3: NPS, Churn Rate, ARPU, CLV, Customer Segment, Lead, Opportunity, Win Rate, Sales Pipeline, Customer Onboarding, Support Ticket, Resolution Time, CSAT |
| **TTE Glossary (old portal)** | 3 | Maintenance Notification, Maintenance Plan, Notification Number |

### 🏷️ 1.4 Classifications Applied

| Classification | Assets Tagged |
|---------------|--------------|
| MICROSOFT.PERSONAL.NAME | 16 |
| MICROSOFT.PERSONAL.PHYSICALADDRESS | 14 |
| MICROSOFT.PERSONAL.DATE_OF_BIRTH | 5 |
| MICROSOFT.PERSONAL.EMAIL | 4 |
| MICROSOFT.FINANCIAL.INTERNATIONAL.BANK_ACCOUNT_NUMBER | 3 |
| MICROSOFT.GOVERNMENT.CITY_NAME | 3 |
| MICROSOFT.GOVERNMENT.US.STATE | 2 |
| MICROSOFT.GOVERNMENT.US.ZIP_CODE | 2 |
| MICROSOFT.PERSONAL.AGE | 2 |
| MICROSOFT.PERSONAL.GENDER | 2 |
| MICROSOFT.PERSONAL.GEOLOCATION | 2 |

**Custom classifications created**: `Custom_French_Phone`, `Complaints Type`, `U.K. Phone`

### 🧩 1.5 Entity Type Definitions — 731 Total

| Service | Type Count |
|---------|-----------|
| Azure Synapse Analytics | 33 |
| SAP BW | 32 |
| **Fabric** | **32** |
| Erwin | 29 |
| Snowflake | 25 |
| **Oracle** | **25** |
| SAP S4HANA / SAP HANA / SAP ECC | 22 each |
| Looker | 21 |
| Qlik Sense | 19 |
| Teradata | 18 |
| Azure Data Factory | 15 |
| **Tableau Server** | **14** |
| DB2 | 13 |
| Amazon Redshift | 13 |

### 🔒 1.6 Policies — 32 Collection-Level Metadata Policies

All collections have associated metadata policies for access control.

### 🔌 1.7 Connectors / Sources Detected (Multi-Cloud)

- **☁️ Azure**: ADLS Gen2, Azure SQL, Azure Blob, Fabric (Lakehouse, Warehouse, Notebooks, Pipelines, KQL DB, ML)
- **❄️ Snowflake**: Tables, views, schemas, stored procedures
- **🟧 AWS**: S3, Redshift
- **🔵 GCP**: Collection exists (GCP)
- **🟣 Dynamics/Dataverse**: 347 tables scanned
- **☁️ Salesforce**: 2 assets
- **🏠 On-Premises**: SQL Server tables, PostgreSQL (tables + views)
- **📊 Power BI**: Datasets (204), Reports (133), Dashboards (22), Dataflows (12)
- **🔄 ADF**: Copy activities, pipelines, dataflow activities

### 🚫 1.8 Features NOT Accessible via REST API (403/401)

| Feature | Status | Notes |
|---------|--------|-------|
| Data Sources (Scan API) | 🚫 403 Forbidden | Needs Data Source Administrator role |
| Scan Rule Sets | 🚫 403 Forbidden | Needs Scan admin |
| Integration Runtimes | 🚫 403 Forbidden | Needs Purview admin |
| Managed Private Endpoints | 🚫 403 Forbidden | Needs network admin |
| Governance Domains (new API) | 🔒 401 Unauthorized | New Data Governance API endpoints not accessible with `purview.azure.net` token scope |
| Data Quality Rules (new API) | 🔒 401 Unauthorized | New Data Governance feature |
| Business Context / OKRs (new API) | 🔒 401 Unauthorized | New Data Governance feature |

> **Note**: Governance entities (Application Services, Data Products) ARE accessible via the Atlas v2 catalog/search API. Only the new dedicated Data Governance REST endpoints are blocked.

### 🏢 1.9 Governance Entities — Purview Business Assets (20 total)

#### ⚙️ Application Services (12 in RC branch + 6 SAP)

**RC Branch Assets** (collection: `jtecfo` — RC branch assets):

| Name | GUID | Description | Status |
|------|------|-------------|--------|
| TDF MVP SMINT | `c14d7d2e-...` | TDF MVP SMINT — Smart Integration platform for data pipeline orchestration and transformation workflows across the RC division | ACTIVE |
| PI-DA-RC-DE-LEU | `b139a1fd-...` | Germany (Leuna) — Data Analytics for RC division, Leuna site | ACTIVE |
| PI-DA-RC-FR-FZN | `b2b9207e-...` | France (Fos-sur-Mer/Zone) — Data Analytics for RC division, FZN site | ACTIVE |
| PI-DA-RC-BE-ANV | `2550907e-...` | Belgium (Antwerp) — Data Analytics for RC division, Antwerp site | ACTIVE |
| PI-DA-RC-FR-DGS | `1f8401ff-...` | France (Donges) — Data Analytics for RC division, Donges site | ACTIVE |
| PI-DA-RC-GB-LOR | `fed4a0de-...` | United Kingdom (Lindsey Oil Refinery) — Data Analytics for RC division | ACTIVE |
| PI-DA-RC-FR-NOR | `cffaccfd-...` | France (Normandy) — Data Analytics for RC division, Normandy site | ACTIVE |
| PI-DA-RC-FR-GPS | `207ef067-...` | France (Grandpuits) — Data Analytics for RC division, biofuels | ACTIVE |
| PI-DA-RC-US-PAR | `7ad47dfd-...` | United States (Port Arthur) — Data Analytics for RC division, TX site | ACTIVE |
| PI-DA-RC-FR-MED | `dd837cde-...` | France (Mediterranean) — Data Analytics for RC division, La Mede site | ACTIVE |
| RAMSES | `e1087329-...` | RAMSES — Event management for operational incidents and safety | ACTIVE |
| RADAR | `f0728644-...` | RADAR — Risk Assessment and Data Analytics Reporting platform | ACTIVE |

> All 12 descriptions updated in **Sprint 1** (was "This is the description" for 9 of 12).

**SAP Application Services** (collection: `6zun08` — LIFT Tenant):

| Name | Collection |
|------|-----------|
| SAP P8B Supply Refining | 6zun08 |
| SAP UNISOL | 6zun08 |
| SAP P3A | 6zun08 |
| SAP O02 | 6zun08 |
| SAP O02 Polymers Supply supply chain import csv v2 | 6zun08 |
| SAP RC collection of assets | oktkz3 |

#### 📦 Data Products (2)

**Test / Deprecated Products** (from initial setup):

| Name | Type | GUID | Status | Collection |
|------|------|------|--------|----------|
| [DEPRECATED] test PBIX | Purview_Product | `2d73c69a-...` | Deprecated in Sprint 4 | jtecfo |
| [DEPRECATED] TDF MVP RTPCA | Digital Product TDF | `62e575bc-...` | Deprecated in Sprint 4 | jtecfo |

**Production Data Products** (created in Sprint 4):

| Name | Domain | GUID | Description |
|------|--------|------|-------------|
| Executive Financial Dashboards | Finance and ESG | `c30a209a-...` | C-suite financial KPIs (P&L, Cash Flow, profitability) |
| ESG and CSRD Reporting Pack | Finance and ESG | `495072be-...` | Sustainability metrics, Scope 1/2/3, CSRD compliance |
| Customer 360 | Customer and Sales | `efb1058d-...` | Unified customer view (CRM + Salesforce + Dataverse) |
| Workforce Analytics | HR and People | `1ae39b7b-...` | Employee demographics, attrition, engagement, diversity |
| Operational Performance Hub | Operations and Industrial | `0d633bc1-...` | Equipment OEE, maintenance KPIs, safety tracking |
| Data Platform Health | Technology and Data Platform | `25db6129-...` | Pipeline status, data freshness, catalog completeness |

#### 🔗 Relationship Schema (from type definitions)

- **Purview_ApplicationService** can: `represents` a DataDomain, `has` Databases, `implements` BusinessProcesses, `isImplementedBy` Manual Sources, has glossary `meanings`
- **Purview_Product** can: `represents` a DataDomain, `isGroupedBy` LineOfBusiness, `isOfferedBy` Organization, has glossary `meanings`
- **Digital Product TDF** (custom): Same relationship schema as Purview_Product

#### ⚠️ Missing Governance Entity Types (type exists but 0 instances)

| Type | Description | Instances |
|------|-------------|-----------|
| Purview_DataDomain | Data governance domain | **5** (Sprint 2: Finance and ESG, Customer and Sales, HR and People, Operations and Industrial, Technology and Data Platform) |
| Purview_Organization | Organizational unit | **3** (Sprint 2: Group, RC Division, Company B) |
| Purview_LineOfBusiness | Business line grouping | **5** (Sprint 2: Supply Chain and Logistics, Digital Services, Analytics and BI, Industrial Operations, Corporate Functions) |
| Purview_Database | Database system | **0** |
| Purview_BusinessProcess | Business process definition | **0** |
| Purview_System | Physical IT system | **0** |
| Manual Source | Manual data source | **0** |
| ManualSourceTTE | Custom manual source (test) | **0** |

### 1.10 Lineage & Process Entities (27 total)

| Type | Count | Notes |
|------|-------|-------|
| ProcessCustomSnowflake (Snowflake query) | 24 | Auto-captured from Snowflake scan |
| SnowflakeStageProcess | 1 | Snowflake staging lineage |
| Process (API Management - Salesforce) | 1 | API-based lineage |
| Process (Synapse Spark process) | 1 | Spark notebook lineage |

### 1.11 Purview Business Type Definitions (9 custom/built-in)

| Type Name | Description |
|-----------|-------------|
| Purview_ApplicationService | Business function implemented by a software service |
| Purview_Product | Any offered product or service |
| Purview_BusinessProcess | Activities that jointly realize a business goal |
| Purview_System | Physical IT system including hardware and software |
| Purview_DataDomain | *(relationship target for governance domains)* |
| Purview_Organization | *(organizational hierarchy)* |
| Purview_LineOfBusiness | *(business line grouping)* |
| SAP application service | Custom type to group SAP apps |
| Digital Product TDF | Custom type — Digital Product TDF test |
| Manual Source | Manual data source |
| ManualSourceTTE | Custom test manual source |

---

## 2. GAP ANALYSIS & RECOMMENDATIONS

### GAP 1: ~~Governance Domains~~ RESOLVED (Sprint 2)
**Status**: CLOSED  
**Action taken**: Created 5 governance domains (Finance and ESG, Customer and Sales, HR and People, Operations and Industrial, Technology and Data Platform), 3 organizations (Group, RC Division, Company B), 5 lines of business. All 12 Application Services linked to their domains via `represents` relationship.  
**Remaining**: Assign named business stewards to each domain. Create `Purview_BusinessProcess` instances (Sprint 6).

### GAP 2: ~~Data Products Test-Only~~ RESOLVED (Sprint 4 + Sprint 5 UC + Sprint 5c attachments)
**Status**: CLOSED  
**Action taken**: Created 6 production data products in Data Map (Sprint 4) AND recreated 6 matching data products in Unified Catalog (Sprint 5). Each UC data product linked to its LoB domain with owner contacts. All Published. Then (Sprint 5c) attached 32 UC data assets and 6 UC glossary terms across the 6 DPs via the relationships endpoint.  
**API**: `POST /datagovernance/catalog/dataproducts/{dpId}/relationships?api-version=2026-03-20-preview&entityType=DataAsset|Term|CriticalDataElement` with body `{ "entityId": "<ucAssetOrTermId>" }` returns 200.  
**Per-DP attachments**: Executive Financial Dashboards (8 assets, 1 term), Customer 360 (8 assets, 1 term), Workforce Analytics Dashboard (7 assets), Operational Performance Hub (8 assets, 2 terms), ESG and CSRD Reporting Pack (1 term), Data Platform Health Monitor (1 asset, 1 term).  
**Remaining**: Publish quality scores once DQ rules are configured. Some cross-domain term attachments returned 403 — UC terms appear scoped to their owning domain.

### GAP 3: ~~Placeholder Descriptions~~ RESOLVED (Sprint 1)
**Status**: CLOSED  
**Action taken**: All 12 Application Service descriptions updated with real business context (site name, country, function). Each PI-DA-RC-XX-YYY service now describes its geographic site and division role. RAMSES and RADAR have expanded descriptions.  
**Remaining**: Assign `owner` attributes, link to glossary terms, connect to databases and business processes.

### GAP 4: ~~Business Glossary Sparse~~ RESOLVED (Sprint 3 + Sprint 5 UC + Sprint 5b linking)
**Severity**: LOW (reduced from MEDIUM-HIGH)  
**Current**: 113 classic glossary terms + 60 Unified Catalog terms (with owner/steward/CDO contacts). Total: 173 terms across Data Map and UC.  
**Action taken (Sprint 5b)**: Bulk-linked 14 classic Atlas glossary terms to ~46 catalog assets across `powerbi_dataset`, `powerbi_report`, `fabric_lakehouse_table`, `snowflake_table`, `mssql_table`, `postgresql_table`, `dataverse_table`, and ADLS Gen2 resource sets via Atlas `glossary/terms/{guid}/assignedEntities` endpoint. Verified terms now appear in asset details (e.g., `Customer` term shows on Customer / Contoso Coffee D365 datasets, `Revenue` term on Finance Report).  
**Method**: Classic Atlas glossary terms (`Revenue@Global`, `Customer@Global`, etc.) ARE linkable via `POST /catalog/api/atlas/v2/glossary/terms/{termGuid}/assignedEntities` (returns 204). UC-native terms are NOT in the Atlas graph and cannot be linked via REST — use classic Atlas terms for asset assignment.  
**Remaining**:
1. Expand keyword matching (currently only 14/113 terms matched assets — many domain-specific terms like `OEE`, `MTBF`, `Win Rate` need richer asset names or fuzzy matching)
2. Consider whether to maintain both classic and UC glossaries or consolidate

### GAP 5: Classification Coverage is Minimal
**Severity**: MEDIUM  
**Current**: Only ~56 assets have classifications applied (out of 9,541). Only 3 custom classifications.  
**Impact**: PII/sensitive data is likely untagged. Compliance risk.  
**Recommendation**:
1. Enable auto-classification scans on all data sources
2. Create custom classifications for domain-specific sensitive data:
   - `INTERNAL_CUSTOMER_ID`, `EMPLOYEE_ID`, `FINANCIAL_ACCOUNT_NUMBER`
   - Industry-specific: `MAINTENANCE_RECORD`, `EQUIPMENT_SERIAL_NUMBER`
3. Run scans with classification rules enabled on:
   - Snowflake tables (86 tables, 0 classified)
   - PostgreSQL tables (68 tables + 89 views, 0 classified)
   - Fabric Lakehouse tables (661 tables, few classified)

### GAP 6: Data Quality Rules NOT Configured
**Severity**: MEDIUM-HIGH  
**Current**: No data quality rules exist.  
**Impact**: No automated quality monitoring. No freshness/completeness/accuracy scores.  
**Recommendation**: Define DQ rules for critical datasets:
- **Freshness**: Fabric Lakehouse tables, Power BI datasets — data < 24h old
- **Completeness**: Customer tables — email, address fields non-null
- **Uniqueness**: Primary keys on Snowflake/SQL tables
- **Validity**: Date ranges, numeric bounds, enum values
- **Consistency**: Cross-source reconciliation (Snowflake ↔ Lakehouse)

### GAP 7: Collection Naming is Cryptic
**Severity**: LOW-MEDIUM  
**Current**: Collection IDs are auto-generated codes (`hklbqp`, `242twh`, `fmjxwb`). Some have friendly names, many don't.  
**Impact**: Hard to navigate. Users can't tell what collection holds what data.  
**Recommendation**: Rename collections with meaningful, hierarchical names:
- `hklbqp` → "Enterprise Analytics" or "Power BI & Fabric"
- `242twh` → "Cloud Databases (Snowflake/SQL)"
- `fmjxwb` → "Company B - Data Assets"
- `vwo17u` → "On-Premises Systems"
- Consolidate test/POC collections (ozssv7, icer4k, w8nhgp)

### GAP 8: Heavy Concentration in One Collection (77%)
**Severity**: MEDIUM  
**Current**: 77% of all assets (7,347) are in a single collection (`hklbqp`).  
**Impact**: No granular access control. All-or-nothing permissions. Hard to delegate stewardship.  
**Recommendation**: Break into sub-collections by domain or source:
- Power BI Reports & Datasets → separate collection
- Fabric Lakehouse & Warehouse → separate collection
- Data Engineering (notebooks, pipelines) → separate collection

### GAP 9: Lineage Partially Captured but Gaps Remain
**Severity**: MEDIUM  
**Current**: 27 process/lineage entities exist — 24 Snowflake queries (auto-captured), 1 Snowflake stage process, 1 Salesforce API Management process, 1 Synapse Spark process. However, no Fabric, ADF, or Power BI lineage processes are visible.  
**Impact**: Snowflake lineage is well-captured, but no end-to-end lineage for the dominant Fabric/Power BI pipeline (77% of assets).  
**Recommendation**:
1. Enable ADF lineage connector — copy & dataflow activities should generate Process entities
2. Enable Fabric lineage integration for notebooks, pipelines, and lakehouses
3. Verify Power BI dataset → source lineage is captured (204 datasets have no lineage processes)
4. Connect Application Services to databases and business processes via relationship attributes

### GAP 10: Multi-Cloud Sources Registered but Incomplete
**Severity**: MEDIUM  
**Current**: Collections exist for AWS, GCP, Salesforce, Dynamics, On-Prem, but asset counts are low.  
**Impact**: Incomplete catalog = incomplete governance.  
**Recommendation**:
- **AWS**: Scan more S3 buckets, Redshift schemas (currently only 32 S3 objects + 6 directories)
- **GCP**: Collection exists but 0 assets. Set up BigQuery/GCS scans
- **Salesforce**: Only 2 assets. Configure full scan
- **On-Premises**: Validate PostgreSQL scan covers all schemas (currently 68 tables + 89 views)

### GAP 11: No Data Access Policies Beyond Metadata
**Severity**: LOW-MEDIUM  
**Current**: Only metadata read/update policies exist on collections. No data-level access policies.  
**Impact**: Purview isn't being used to enforce data access governance.  
**Recommendation**:
- Enable Purview data access policies for Azure SQL, ADLS Gen2
- Leverage Purview policy integration with Fabric workspaces

---

## 3. BUSINESS-FOCUSED ROADMAP — Filling the Governance Gaps

### Guiding Principles
- **Business value first** — every action should make data easier to find, understand, trust, and use
- **Start with what exists** — fix the 18 governance entities already created before building new ones
- **Domain ownership drives everything** — no governance scales without accountable business owners
- **Glossary = shared language** — terms must be linked to assets or they're just a document

---

### SPRINT 1 — Establish Ownership & Fix What's Broken (Week 1-2)

**Goal**: Every existing governance entity has a real description, an owner, and a purpose.

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 1.1 | **Fix Application Service descriptions** | Replace *"This is the description"* on 9 RC branch services with real business function descriptions. Example: `PI-DA-RC-FR-DGS` → *"France Digital Services — manages data processing workflows for the RC division across French operations"* | Business Analyst + Domain SME | GAP 3 |
| 1.2 | **Assign owners to all 18 services** | Set the `owner` attribute on each Application Service and Data Product to the responsible business steward (name or email) | Data Governance Lead | GAP 3 |
| 1.3 | **Clarify RAMSES & RADAR** | RAMSES has a description ("Event management") but no owner. RADAR has placeholder text. Both need business context: what data flows through them, who uses the output, what decisions they support | Operations SME | GAP 3 |
| 1.4 | **Document SAP services** | 6 SAP services exist but only have names (P8B Supply Refining, UNISOL, P3A, O02…). Add descriptions: what SAP module, what business process, what data entities | SAP / ERP Lead | GAP 3 |
| 1.5 | **Decide on test entities** | `test PBIX` and `TDF MVP RTPCA` are test products. Either delete them or convert to real products. `ManualSourceTTE` and `Digital Product TDF` custom types — keep, formalize, or deprecate? | Data Governance Lead | GAP 2 |

**Deliverable**: All 18+ governance entities have meaningful descriptions and assigned owners.

---

### SPRINT 2 — Build the Business Backbone: Domains & Organization (Week 3-4)

**Goal**: A governance domain structure that mirrors how the business thinks about its data.

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 2.1 | **Create 5 Governance Domains** (`Purview_DataDomain`) | Instantiate domain entities in Purview. Proposed domains: | Data Governance Lead | GAP 1 |

**Proposed Governance Domains**:

| Domain | Scope | Data Steward Role | Key Assets |
|--------|-------|-------------------|------------|
| **Finance & ESG** | Financial reporting, ESG/CSRD compliance, profitability metrics | CFO office / Finance BI team | Finance glossary (9 terms), Power BI datasets, FSI dashboards |
| **Customer & Sales** | CRM, customer lifecycle, sales analytics, Salesforce | Commercial / CX team | Customer glossary (7 terms), Salesforce (2 assets), Dataverse (347 tables) |
| **HR & People** | Employee data, workforce analytics, compensation, benefits | HR / People Analytics | HR glossary (14 terms), employee datasets |
| **Operations & Industrial** | Maintenance, equipment, supply chain, SAP processes, IoT | Operations / TTE team | SAP services (6), RAMSES, On-prem (278 assets), TTE glossary (3 terms) |
| **Technology & Data Platform** | Fabric artifacts, lakehouses, pipelines, data engineering | Data Engineering / Platform | Fabric (5,699+ lakehouse paths), Snowflake (86 tables), notebooks (175) |

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 2.2 | **Link Application Services to Domains** | Use the `represents` relationship to assign each service to its domain. Example: RAMSES → Operations & Industrial, SAP services → Operations & Industrial, PI-DA-RC-* → determine per naming convention | Data Governance Lead | GAP 1 |
| 2.3 | **Create Organization & LineOfBusiness entities** | `Purview_Organization` — at minimum: parent org + the "RC" division + "Company B". `Purview_LineOfBusiness` — at minimum: Supply Chain, Digital Services, Analytics | Business Architecture | GAP 1 |
| 2.4 | **Link Products to Organization** | Use `isOfferedBy_Organization` and `isGroupedBy_LineOfBusiness` on each Data Product | Data Governance Lead | GAP 2 |
| 2.5 | **Appoint Domain Stewards** | Each domain gets a named business steward (not IT) who owns the glossary, quality, and access decisions for that domain's data | Executive Sponsor | GAP 1 |

**Deliverable**: 5 domains live in Purview, each with a steward, linked services, and clear scope.

---

### SPRINT 3 — Build the Shared Language: Glossary Expansion (Week 5-7)

**Goal**: Go from 33 terms to 100+ terms, all linked to catalog assets.

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 3.1 | **Populate Global glossary** | Currently empty. Add 15-20 cross-domain terms: `Revenue`, `Customer`, `Employee`, `Asset`, `Contract`, `Data Quality Score`, `SLA`, `KPI`, `Business Unit`, `Region`, `Country`, `Currency`, `Fiscal Year`, `Budget`, `Forecast` | Data Governance Lead | GAP 4 |
| 3.2 | **Expand Finance glossary** (9 → 25) | Add: `Revenue`, `EBITDA`, `Cash Flow`, `Working Capital`, `Net Profit Margin`, `Cost of Goods Sold`, `Operating Expenses`, `ESG Score`, `Carbon Footprint`, `CSRD Metric`, `Scope 1/2/3 Emissions`, `Sustainable Investment`, `Green Revenue`, `Audit Trail`, `Compliance Flag` | Finance Steward | GAP 4 |
| 3.3 | **Expand Customer glossary** (7 → 20) | Add: `NPS`, `Churn Rate`, `ARPU`, `CLV`, `Customer Segment`, `Lead`, `Opportunity`, `Win Rate`, `Sales Pipeline`, `Customer Onboarding`, `Support Ticket`, `Resolution Time`, `CSAT` | Customer Steward | GAP 4 |
| 3.4 | **Expand HR glossary** (14 → 25) | Add: `Headcount`, `Attrition Rate`, `Time to Hire`, `Cost per Hire`, `Employee Engagement`, `Training Hours`, `Diversity Index`, `Absenteeism Rate`, `Internal Mobility`, `Succession Plan`, `Performance Rating` | HR Steward | GAP 4 |
| 3.5 | **Create Operations/TTE glossary** (0 → 20) | New glossary: `Work Order`, `Equipment`, `Downtime`, `OEE`, `MTBF`, `MTTR`, `Preventive Maintenance`, `Corrective Maintenance`, `Inspection`, `Safety Incident`, `Supply Chain Lead Time`, `Inventory Turn`, `Production Batch`, `Quality Control` + expand existing 3 TTE terms | Operations Steward | GAP 4 |
| 3.6 | **Link terms to assets** | For each glossary term, attach it to the relevant catalog entities. Priority: Power BI datasets (204), Snowflake tables (86), Fabric lakehouse tables (661) — use `meanings` relationship | All Stewards | GAP 4 |

**Deliverable**: 100+ glossary terms organized by domain, linked to their corresponding data assets.

**Success metric**: Glossary coverage > 5% of assets (vs. current 0.35%).

---

### SPRINT 4 — Launch the Data Product Marketplace (Week 8-10)

**Goal**: Business users can discover, understand, and request access to curated data products.

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 4.1 | **Define 6 production Data Products** | Create `Purview_Product` entities for the highest-value consumable datasets: | Domain Stewards | GAP 2 |

**Proposed Data Products**:

| Data Product | Domain | Description | Key underlying assets | Business consumers |
|-------------|--------|-------------|----------------------|-------------------|
| **Executive Financial Dashboards** | Finance & ESG | Consolidated financial KPIs (P&L, Balance Sheet, Cash Flow) for C-suite | Power BI datasets + FSI reports | CEO, CFO, Board |
| **ESG & CSRD Reporting Pack** | Finance & ESG | Sustainability metrics, carbon footprint, social & governance scores for regulatory compliance | ESG Power BI reports, ADLS Gen2 data | Sustainability team, Auditors |
| **Customer 360** | Customer & Sales | Unified customer view combining CRM, Salesforce, and transactional data | Dataverse (347 tables), Salesforce (2 assets), Customer glossary | Sales, Marketing, CX |
| **Workforce Analytics** | HR & People | Employee demographics, attrition, engagement, compensation analytics | HR datasets, Agile HR Power BI reports | HR Business Partners, CHRO |
| **Operational Performance Hub** | Operations & Industrial | Equipment OEE, maintenance KPIs, supply chain metrics from SAP and IoT sources | SAP services, RAMSES, On-prem SQL/PostgreSQL | Plant Managers, Operations VP |
| **Data Platform Health** | Technology & Data Platform | Fabric pipeline runs, data freshness, quality scores, catalog completeness | Fabric lakehouse (5,699 paths), notebooks (175), pipelines (88) | Data Engineering, CDO |

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 4.2 | **Link each product to its domain** | `represents` → DataDomain, `isGroupedBy` → LineOfBusiness, `isOfferedBy` → Organization | Data Governance Lead | GAP 2 |
| 4.3 | **Write product descriptions** | Each product gets: purpose, refresh frequency, data sources, SLA, access request process, known limitations | Domain Stewards | GAP 2 |
| 4.4 | **Attach glossary terms** | Link relevant business terms to each product via `meanings` so users can search by business concept | Domain Stewards | GAP 2, 4 |
| 4.5 | **Clean up test products** | Delete or archive `test PBIX` and `TDF MVP RTPCA` — they confuse users browsing the catalog | Data Governance Lead | GAP 2 |

**Deliverable**: 6 production data products visible in Purview, each with description, domain, owner, glossary terms, and a clear SLA.

---

### SPRINT 5 — Data Quality & Business Trust (Week 11-13)

**Goal**: Business users can see a trust score for each critical dataset.

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 5.1 | **Define business-critical datasets** | With each domain steward, identify the 10-15 datasets where bad data = bad decisions. Priority: financial reports, customer master, employee records, production metrics | All Stewards | GAP 6 |
| 5.2 | **Define DQ rules per domain** | Work with business to define what "good data" means for each: | Domain Stewards + DQ Lead | GAP 6 |

**Proposed Data Quality Rules**:

| Domain | Dataset | Rule Type | Business Rule |
|--------|---------|-----------|--------------|
| Finance | Financial KPI dataset | **Freshness** | Updated within 24h of month-end close |
| Finance | ESG metrics | **Completeness** | All Scope 1/2/3 emission fields populated |
| Customer | Customer master | **Completeness** | Email OR phone present on 95%+ records |
| Customer | Customer master | **Uniqueness** | No duplicate customer IDs |
| HR | Employee table | **Validity** | Hire date ≤ today, salary > 0, department not null |
| HR | Employee table | **Completeness** | Manager field populated for 98%+ records |
| Operations | Equipment register | **Completeness** | Serial number, location, last maintenance date populated |
| Operations | Work orders (SAP) | **Freshness** | Synced within 4h of SAP update |
| Platform | Fabric lakehouse tables | **Freshness** | Pipeline last run < 24h ago |
| Platform | Snowflake tables | **Consistency** | Row counts match between Snowflake and Lakehouse replicas |

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 5.3 | **Configure DQ rules in Purview** | Implement the rules above using Purview Data Quality (if API access is resolved) or document as manual checks until then | DQ Lead | GAP 6 |
| 5.4 | **Publish quality scores on Data Products** | Each data product description should include its current quality score and last-measured date | Domain Stewards | GAP 2, 6 |
| 5.5 | **Set up quality review cadence** | Monthly data quality review per domain — steward reviews scores, flags issues, tracks improvement | Data Governance Lead | GAP 6 |

**Deliverable**: DQ rules defined for 10-15 critical datasets, quality scores published on data products.

---

### SPRINT 6 — Sustain & Scale: Governance Operating Model (Week 14-16)

**Goal**: Governance runs as a continuous business process, not a one-time project.

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 6.1 | **Define the governance RACI** | Document who is Responsible, Accountable, Consulted, Informed for: glossary terms, domain membership, data quality, access requests, product lifecycle | Data Governance Lead | All |
| 6.2 | **Create Business Process entities** | Instantiate `Purview_BusinessProcess` for key cross-domain processes: Order-to-Cash, Procure-to-Pay, Hire-to-Retire, Plan-to-Report, Equipment-to-Maintenance. Link each to the Application Services that implement it | Business Architecture | GAP 1 |
| 6.3 | **Establish OKRs per domain** | When API access is available, create OKRs in Purview. Until then, track in a shared document: | Domain Stewards | GAP 6 |

**Proposed OKRs**:

| Domain | Objective | Key Result |
|--------|-----------|------------|
| Finance & ESG | Data is audit-ready for CSRD | 100% of ESG metrics pass completeness DQ rules |
| Customer & Sales | Single source of truth for customer data | Customer 360 product adopted by 3+ teams |
| HR & People | Trusted workforce analytics | Attrition dashboard refresh < 24h, 0 data quality alerts/month |
| Operations | Real-time operational visibility | Equipment OEE dashboard live, maintenance data < 4h stale |
| Platform | Catalog is the front door for data | 80% of new data requests start in Purview catalog |

| # | Action | What to do | Owner | Gaps |
|---|--------|-----------|-------|------|
| 6.4 | **Quarterly governance review** | Each quarter: review domain health (glossary coverage, DQ scores, product adoption), onboard new assets, retire stale ones, update roadmap | CDO / Data Governance Lead | All |
| 6.5 | **Glossary term lifecycle** | Define process: who can propose new terms, who approves, how terms get linked to assets, when terms get retired | Data Governance Lead | GAP 4 |

**Deliverable**: Governance operating model documented and running — RACI, OKRs, review cadence, term lifecycle.

---

### Summary Timeline

```
Week  1-2   ████ Sprint 1: Fix existing entities (descriptions, owners)         ✅ DONE
Week  3-4   ████ Sprint 2: Governance domains & organization structure           ✅ DONE
Week  5-7   ██████ Sprint 3: Glossary expansion (33 → 113 terms)                ✅ DONE
Week  8-10  ██████ Sprint 4: Data product marketplace (6 products, Data Map)     ✅ DONE
Week 11-13  ██████ Sprint 5: Unified Catalog (16 domains, 60 terms, 6 DPs)      ✅ DONE
Week 14-16  ██████ Sprint 6: Cross-domain BusinessProcesses (5)                  ✅ DONE
```

### Key Success Metrics

| Metric | Before | Current (Sprint 5) | Sprint 6 Target |
|--------|--------|---------------------|-----------------|
| UC Governance domains | 0 | **16** (5 LoB + 11 DataDomain) | 16 (mature) |
| UC Glossary terms | 0 | **75** (60 sub-domain + 15 LoB umbrella) | 75+ |
| UC Data Products | 0 | **6** (Published) | 6 |
| Classic glossary terms | 33 | **113** | 113 |
| Data Map governance entities | 3 | **18+** | 18+ |
| Glossary terms linked to assets | 0 | **~46** (Sprint 5b — classic Atlas terms) | 50+ |
| Datasets with DQ rules | 0 | **0** (DQ feature not enabled — separately billed) | 15+ |
| Business processes documented | 0 | **5** (Sprint 6) | 5 |

---

## 4. RAW DATA EXPORTS

- Full catalog inventory: `purview_inventory.json`
- Governance entity details (14 entities + type definitions): `governance_entities_detail.json`
