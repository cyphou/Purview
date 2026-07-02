# Changelog

## [2.0.0] — June 2026 — Unified Catalog Production Release

### Added
- **Unified Catalog Features**:
  - 15 LoB-level umbrella glossary terms (Sprint UC-E)
  - 39 DP↔Term bulk relationships via REST (Sprint UC-F)
  - 3 custom metadata groups with 11 named attributes (Sprint UC-G)
  - 32 cross-domain relationships (term-term, CDE-term, CDE-column) (Sprint UC-H)
  - 15 Critical Data Elements linked to 15 Critical Data Columns (Sprint UC-I)
  - 🟢🟡🟠 data quality tiers on 85 assets (Sprint UC-J)
- **Demo Infrastructure**:
  - Local scenario portal (`purview-ux-portal/`) with S1–S4 guides
  - "Maya's Monday Morning" 12-minute demo narrative with scene-by-scene walkthrough
  - 4 runnable scenarios with real-time Purview API validation
- **Semantic Labs Integration**:
  - Fabric Notebook extraction workflow for Power BI semantic model metadata
  - Finance Report semantic model sync to Purview via REST import
  - Full column lineage (Finance↔Snowflake↔Salesforce)
- **Documentation**:
  - `STATUS.md` — comprehensive project status, all sprints & UC features
  - `docs/AGENTS.md` — multi-agent architecture with preceptorship loop
  - `purview_governance_inventory.md` — UC inventory & REST endpoint discoveries
  - `SEMANTIC_LABS_FABRIC_RUNBOOK.md` — Semantic Labs extraction walkthrough
  - `demo_story_business.md` — full demo narrative & business messaging

### Changed
- **REST API Layer**: Identified modern UC endpoints (`POST /customMetadata`, `POST /datagovernance/catalog/dataproducts/{id}/relationships`)
- **Demo Messaging**: Aligned all sprints to business outcomes (not technical features)
- **CI/CD**: Enhanced GitHub Actions workflow with multi-version Python testing (3.12, 3.13)
- **Deployment Paths**: Four clear scenarios (full wipe, incremental sprints, portal launch, Fabric sync)

### Fixed
- Custom metadata attribute names now preserved (was silently overwritten by old `/attributes` endpoint)
- DP→Term relationships now fully bidirectional in portal UI
- CDE→CriticalDataColumn linking validated and tested

### Validated
- All 16 domains published with governance roles
- All 75 glossary terms with owner/steward/CDO contacts
- All 6 data products endorsed with documentation
- All 15 CDEs bridged to physical schema columns
- 85+ relationships wired and queryable
- 4 demo scenarios (S1 KPI, S2 Domain/DP, S3 Governed Asset, S4 Adoption) runnable
- Multi-agent preceptorship loop implemented and tested

---

## [1.0.0] — March 2026 — Core Governance Features

### Added
- **Sprints 1–5** (Feb–Mar 2026):
  - Sprint 1: Foundation (description fixes)
  - Sprint 2: Domain hierarchy (5 LoB + 11 sub-domains)
  - Sprint 3: Glossary (75 terms with governance contacts)
  - Sprint 4: Data Products (6 endorsed DPs with rich metadata)
  - Sprint 5: Unified Catalog features (OKRs, custom metadata, business processes)
- **Multi-Agent System**: 14 specialized agents in `.github/agents/` with preceptorship loop
- **Development Workflow**: `.github/copilot-instructions.md` with hard constraints (test after change, read before write, git hygiene)
- **Initial Demo Portal**: Node.js-based scenario environment

### Initial State
- 16 governance domains (5 LoB + 11 sub-domains)
- 75 glossary terms with owner/steward/CDO role assignments
- 6 endorsed data products with business descriptions
- 5 OKRs with 15 Key Results
- 5 cross-domain business processes
- 15 governance demo users with role bindings
- 85 assets with baseline data quality classifications

---

_This changelog follows [Keep a Changelog](https://keepachangelog.com/) format._
