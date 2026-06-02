# Client Demo Response Pack

This document answers the scenarios from:
- `C:\Users\pidoudet\OneDrive - Microsoft\Boulot\Client\Data Catalog Demonstration Scenarios.docx`

Based on the current Purview demo tenant and automation in this repository.

## 1) Executive Answer: Can the current demo answer the Client document?

Yes, for the core business scenarios (1, 2, 3) and most of the expected cross-scenario coverage.

Current readiness summary:
- Scenario 1 (KPI understanding from BI context): **Strong**
- Scenario 2 (domain/data product exploration): **Strong**
- Scenario 3 (data asset documentation and governance): **Strong with minor workflow limits**
- Scenario 4 (platform administration and adoption): **Partial (concise demo is possible, deep admin analytics is limited in this build)**

## 2) What We Can Demonstrate Today (Evidence-Based)

### Scenario 1 - Understand and explain a KPI from a BI report

Client asks to show:
- KPI discovery
- Business definition and calculation rules
- Ownership (owner/steward)
- Lineage KPI -> datasets -> sources
- Related assets and, if available, BI contextual access

What the current demo can show:
- KPI/term discovery through glossary search (example: ESG Disclosure Metric).
- Business definition and governance context on term pages.
- Owner/steward/CDO contacts on terms and data products.
- Data product to assets navigation and end-to-end lineage views in Purview.
- Related entities (term<->term, data product<->term, CDE<->term, CDE<->critical column) already pre-wired.

Proof in repository:
- `README.md`
- `demo_story_business.md`
- `purview_governance_inventory.md`
- `sprint_uc_h_relationships.ps1`
- `sprint_uc_i_critical_data_columns.ps1`

Notes/limits:
- Native in-report plugin behavior depends on the BI tool and tenant setup. The story should show seamless navigation from report context to catalog, but avoid promising a specific plugin flow unless validated live in your Client target toolchain.

### Scenario 2 - Explore a business domain/data product

Client asks to show:
- Business navigation (domains/data products)
- Discover datasets/tables/KPIs/dashboards
- Understand relationships/dependencies
- Ownership and metadata access
- Effective search for non-technical users

What the current demo can show:
- 5 LoB domain model and 11 sub-domains with business-first naming.
- 6 published data products with rich business descriptions, docs, terms of use, and endorsements.
- Discoverability of terms, products, and linked assets from one portal.
- Ownership visibility via contacts on terms/products.
- Search-first navigation and related panels for guided exploration.

Proof in repository:
- `README.md`
- `demo_story_business.md`
- `sprint2_domains_org.ps1`
- `sprint3_glossary.ps1`
- `sprint4_data_products.ps1`
- `enrich_data_products.ps1`
- `attach_terms_to_dps.ps1`

### Scenario 3 - Document and govern a data asset

Client asks to show:
- Ingest/register dataset
- Metadata enrichment (description, tags/classifications)
- Link to glossary
- Assign owner/steward
- Certification/validation workflow
- Collaboration features and evolution

What the current demo can show:
- Data assets are already cataloged and linked to governance objects.
- Metadata enrichment is demonstrated at scale (terms, custom metadata groups, classifications).
- Owner/steward assignment is automated and visible.
- Certification-like signal is shown via endorsed data products and quality tiers.
- Classification-based data quality tiers (Gold/Silver/Bronze) are available for business trust storytelling.

Proof in repository:
- `README.md`
- `add_business_features.ps1`
- `create_custom_metadata.ps1`
- `assign_owners.ps1`
- `verify_and_assign_owners.ps1`
- `sprint_uc_j_fake_data_quality.ps1`

Notes/limits:
- Some workflow capabilities are constrained by API surface in this demo (for example, certain custom metadata value updates are portal-only).
- Formal multi-step certification workflow should be presented as governance process + endorsement + stewardship controls unless you validate a dedicated approval flow in UI for Client.

### Scenario 4 - Platform administration and adoption (secondary)

Client asks to show briefly:
- User/role management
- Access control and security
- Monitoring, usage, adoption

What the current demo can show:
- Demo users and role assignments are scripted and repeatable.
- Governance roles and ownership model are explicit.
- Security and metadata governance structure can be explained clearly.

Proof in repository:
- `create_demo_users.ps1`
- `add_purview_roles.ps1`
- `grant_pbi_workspace_access.ps1`
- `demo_users.json`

Notes/limits:
- Advanced adoption analytics dashboards are not the strongest part of this current package; keep this block concise and focused on governance operating model and role clarity.

## 3) Coverage Matrix Against Client Evaluation Criteria

### Business usability
- Status: **Covered**
- Why: Persona-led story, business terms, product-centric navigation, non-technical entry points.

### Data understanding and trust
- Status: **Covered**
- Why: Definitions, ownership, lineage, CDE/critical columns, quality tiers.

### Effectiveness as a Data Portal
- Status: **Covered**
- Why: Single-entry catalog navigation across domains, terms, products, and assets.

### Governance and metadata management
- Status: **Covered (with known API limits)**
- Why: Strong on ownership, glossary, relationships, metadata structure; a subset of value updates/workflows remain portal-driven.

### Lineage and traceability
- Status: **Covered**
- Why: End-to-end lineage path and relationship graph are present and demonstrable.

### Integration within Client ecosystem
- Status: **Partially covered in this generic tenant**
- Why: Demo uses realistic retail-style assets and BI narratives, but not Client-native systems. Position as approach and map to Client systems during Q&A.

## 4) Recommended 90-Min Demo Plan for Client

- 0-10 min: Client framing and persona setup (Business User as lead persona).
- 10-35 min: Scenario 1 (KPI trust and discrepancy explanation, anchored in BI context).
- 35-55 min: Scenario 2 (domain exploration and data product reuse journey).
- 55-70 min: Scenario 3 (governance onboarding and stewardship story).
- 70-80 min: Scenario 4 concise admin/adoption segment.
- 80-90 min: Q&A and Client fit-gap discussion.

## 5) Suggested Demo Storyline (single coherent narrative)

Use one KPI thread across all personas:
- Persona 1 (Business User): starts from a KPI discrepancy in a dashboard.
- Persona 2 (Analyst): navigates domain/data products to locate reusable trusted data.
- Persona 3 (Data Steward): shows governance controls, ownership, and metadata quality.

This keeps the session aligned with Client' requirement: one coherent business story, not isolated feature blocks.

## 6) Talking Points for Known Gaps (transparent but controlled)

Use these concise statements if challenged:
- "For this demo tenant, certain metadata value operations are intentionally shown through portal workflows because corresponding REST endpoints are limited in preview behavior."
- "We demonstrate certification intent via endorsement, ownership, and governance controls; if Client needs strict approval workflow evidence, we can run that on a tenant configuration tailored to your governance model."
- "In-report catalog access depends on BI integration mode and tenant configuration; today we show the user journey end-to-end and can validate exact plugin behavior in your target BI stack."

## 7) Final Recommendation

Proceed with this demo as a valid response to the Client scenario document, with two execution rules:
- Keep Scenario 4 short and focused on role model/access governance.
- Be explicit on workflow/plugin specifics as "validated per Client target environment" rather than over-claiming.

If needed, the next step is to produce a Client-branded runbook version of this answer with speaker notes per minute and screenshot checklist.
