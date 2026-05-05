# Demo Story — "Maya's Monday Morning"
### A 12-minute Purview Unified Catalog walkthrough for business stakeholders

> **Persona**: Maya Chen, Chief Data Officer at *Helios Industries* — a multi-LoB enterprise (Finance, Customer/Sales, HR, Industrial Operations, Technology) that just rolled out Microsoft Purview Unified Catalog as its single pane of glass for data governance.

> **Audience**: CDOs, Chief Risk Officers, LoB heads, data-product owners, regulators. **Not** a click-by-click tech demo — this is the *business outcome* story the screenshots back up.

> **Tenant**: `pdedemopurv.purview.azure.com` — fully provisioned (5 LoBs · 11 sub-domains · 75 glossary terms · 6 data products · 15 CDEs · 15 CriticalDataColumns · 5 OKRs/15 KRs · 3 customMetadata groups · 85 assets tiered Gold/Silver/Bronze).

---

## The narrative arc (use this as your spoken script)

### Scene 1 · 09:02 — "Where do I even start?"
**Open the Unified Catalog home page → Governance domains tile.**

> *"On a typical Monday I used to open three SharePoints, two Excel trackers and ping four people on Teams just to know who owns what. Now I open Purview and see my whole company on one page."*

**Show**:
- The **5 LoB tiles** (Finance and ESG, Customer and Sales, HR and People, Operations and Industrial, Technology and Data Platform) — each with a count of terms, data products and OKRs.
- Drill into **Finance and ESG** → 17 terms, 2 data products, 1 OKR with 3 KRs.

**Business message**: *"Every line of business is governed by the same operating model — same domain shape, same vocabulary, same accountability."*

---

### Scene 2 · 09:04 — "I need to know if our ESG numbers are trustworthy"
**Glossary → search "ESG Disclosure Metric".**

> *"I have a board meeting Wednesday on CSRD readiness. Before I quote a number, I need to know what it means, who owns it, what feeds it."*

**Show on the term page**:
- **Acronyms**: ESG, CSRD (set via the `acronyms[]` field in Sprint UC-A.4)
- **Contacts** — Owner / Steward / CDO with names and emails
- **Related panel** — links to the **ESG and CSRD Reporting Pack** data product *and* to the underlying terms (Carbon Footprint, ESG Score, CSRD Compliance) — populated by Sprint UC-F (39 DP→term links) and Sprint UC-H (17 term-term links).

**Business message**: *"A glossary entry is only useful if it points to the data product I can actually consume — and to the human I can call. Both are one click away."*

---

### Scene 3 · 09:06 — "Show me the data product, not the data dump"
**Click through to the *ESG and CSRD Reporting Pack* data product page.**

**Show**:
- **Business use** — three rich paragraphs of plain-English description (Sprint 5e enrichment).
- **Terms of use** — clickable policy URLs (Acceptable Use, Data Sharing Agreement).
- **Documentation** — runbooks, data dictionary, sample queries.
- **Endorsement badge** — *"This data product is endorsed by the Finance and ESG governance domain."*
- **Critical data elements** — surfaces the linked CDEs (GL Account Number, Fiscal Period, Reporting Currency) via the term bridge.
- **Related → Data assets** — Power BI datasets and tables that physically deliver the numbers.

**Business message**: *"This is the difference between a 'data lake' and a 'data product'. A consumer can self-serve, a regulator can audit, and a producer is on the hook."*

---

### Scene 4 · 09:08 — "Are these numbers any good?"
**Open the **fact_sale** data asset (DQ_Gold) and the **wwilakehouse** asset (DQ_Bronze) side by side.**

**Show**:
- The **DQ_Gold** chip on `fact_sale` — *"green light, scanned, all critical rules passing"*.
- The **DQ_Bronze** chip on `wwilakehouse` — *"known issues or not yet scanned"*.
- The **Data Quality** custom-metadata group (Quality Score, Quality Tier, Last Scan Date, Active Rules, Last Scan Findings) on the data product — explain that these are populated by the DQ scanner once a managed-identity connection is configured.

**Business message**: *"Trust is not a vibe. Every consumer sees, in colour, whether the asset is fit for purpose. We never let a Bronze asset feed a board pack."*

---

### Scene 5 · 09:09 — "How are my critical data elements doing across the company?"
**Catalog → Critical data elements → filter by domain.**

**Show**:
- 15 CDEs across 5 LoBs (3 per LoB).
- Open **Customer Master ID** (Customer and Sales).
  - **Related terms** panel → "Customer Master Record" (Sprint UC-H Part 2).
  - **Critical data columns** panel → `dimension_customer.customer_id` (Sprint UC-I).
  - From the column, pivot to the asset — and you're back at the Data Quality tier.

**Business message**: *"A CDE is the policy. A CriticalDataColumn is the implementation. We can prove that 'Customer Master ID' isn't just a slide — it lives in column X of asset Y, governed by domain Z, owned by person W."*

---

### Scene 6 · 09:10 — "Are we hitting our data goals?"
**Catalog → Objectives → Customer and Sales → "Deliver a unified, trusted Customer 360 view".**

**Show 3 KRs with current progress (Sprint UC-C.1)**:
| KR | Goal | Current | Status |
|---|---|---|---|
| 100% touchpoint onboarding | 100% | 78% | At Risk |
| +8 NPS | +8 | +5 | At Risk |
| -30% ticket resolution time | -30% | -22% | On Track |

**Business message**: *"OKRs aren't in a separate tool from data. The data product *is* the OKR's source of truth, and the catalog shows progress in real time. When a KR slips, I know exactly which data product to drill into."*

---

### Scene 7 · 09:11 — "And the regulator just walked in"
**Pivot back to **ESG and CSRD Reporting Pack** → Lineage tab.**

**Show**:
- Upstream lakehouse → fabric workspace → Power BI dataset → report.
- Click into a column → see its CDE classification, its DQ tier, its term, its owner.
- Open the **Glossary Term Governance** custom-metadata group on the term — *Calculation Rule, Regulatory Reference* — populated for CSRD Compliance with the actual CSRD article reference.

**Business message**: *"From the boardroom slide back to the source byte, fully attributed, fully timestamped, fully audit-able. That's the test we now pass."*

---

## The five business outcomes to land at the close

1. **One operating model, every LoB** — same domain hierarchy, same roles (owner / steward / CDO), same vocabulary scaffolding. No bespoke per-LoB glossary projects.
2. **Data products, not data dumps** — every consumable is described, endorsed, classified, and linked to its glossary, CDEs, OKRs and lineage.
3. **Critical Data Elements bridged to reality** — the policy ("Customer Master ID matters") is wired to the implementation (`dimension_customer.customer_id`) via CriticalDataColumns. No more "we're working on it".
4. **Trust at a glance** — DQ tier chips on every asset; consumers don't have to read scan reports to know what's safe.
5. **OKRs that live in the data layer** — when a KR slips, the relevant data product is one click away, and so is its owner.

---

## Optional follow-on demo segments (10–20 min add-ons)

| Segment | What you show | Whom it lands with |
|---|---|---|
| **Self-service onboarding** | A new term created in Draft → routed to steward → published with auto-stamped contacts | Domain stewards, CDO office |
| **Regulatory traceability** | Click from CSRD Compliance term → Calculation Rule custom attribute → CDE → CriticalDataColumn → asset → lineage | CRO, Compliance, External auditor |
| **Workforce equity dashboard** | HR domain → Workforce Analytics DP → Compensation Band CDE → DQ tier of underlying asset | CHRO, Comp & Benefits committee |
| **Operational SLA pack** | Operations DP → SLA Target custom attribute → DQ tier → lineage to plant systems | COO, Plant ops leads |
| **DP sunset / endorsement workflow** | Toggle endorsement off → show what consumers see | Platform team, governance council |

---

## Speaker tips

- **Open in the portal, not in REST.** The story is about a CDO's morning, not a developer's. Use the catalog UI; only show JSON if a sceptic asks "is this real?"
- **Always close a scene with a person, not a screen.** *"…and that's why Helena, our finance steward, sleeps better."*
- **Hammer the reusability.** The same six tiles (terms, CDEs, DPs, OKRs, custom attributes, DQ tiers) repeat for every LoB. The platform doesn't get more complex as you scale; it gets more valuable.
- **End where you started.** Last screen = the home page with all 5 LoB tiles green. *"This is what good looks like on a Monday morning."*
