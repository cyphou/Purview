# 📚 Documentation Index — DemoPurview

**Microsoft Purview Unified Catalog Demo Automation**  
**Status**: ✅ Production Ready | **v2.0.0** (June 2026)

---

## 🎯 Start Here

Pick based on your role:

### 👤 I'm a **Decision Maker** (CDO, CRO, Executive)
1. [README.md](README.md) — 5-min overview of what gets deployed
2. [STATUS.md](STATUS.md) — Current project metrics and readiness
3. [demo_story_business.md](demo_story_business.md) — 12-min demo walkthrough script

### 🎯 I'm a **Solutions Architect**
1. [README.md](README.md) — Project architecture & deployment options
2. [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) — Full file/script reference
3. [docs/AGENTS.md](docs/AGENTS.md) — Multi-agent architecture & design patterns
4. [purview_governance_inventory.md](purview_governance_inventory.md) — REST API discoveries

### 🚀 I'm an **Operator** (Deploying/Running Scripts)
1. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — One-page cheat sheet of commands
2. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) — Step-by-step setup & troubleshooting
3. [STATUS.md](STATUS.md) — Current state & what each script does

### 👨‍💻 I'm a **Developer**
1. [CONTRIBUTING.md](CONTRIBUTING.md) — Development setup, coding standards, workflow
2. [docs/AGENTS.md](docs/AGENTS.md) — Multi-agent architecture & preceptorship loop
3. [.github/copilot-instructions.md](.github/copilot-instructions.md) — Hard constraints
4. [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) — All scripts & their purposes

---

## 📖 All Documentation Files

### 🎯 **Core Project Documentation**

| File | Purpose | Audience | Read Time |
|------|---------|----------|-----------|
| [README.md](README.md) | Project overview, quick start, domain architecture | Everyone | 10 min |
| [STATUS.md](STATUS.md) | **📊 COMPREHENSIVE STATUS**: All sprints, UC features, metrics, demo readiness | Decision makers, operators | 15 min |
| [CHANGELOG.md](CHANGELOG.md) | Release history v1.0.0 → v2.0.0 with all sprints documented | Developers, product managers | 10 min |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development setup, coding standards, workflow rules | Developers | 10 min |

### 🚀 **Deployment & Operations**

| File | Purpose | Audience | Read Time |
|------|---------|----------|-----------|
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | **📋 STEP-BY-STEP SETUP**: Prerequisites, 4 deployment paths, verification, troubleshooting | Operators, DevOps | 20 min |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | **⚡ ONE-PAGE CHEAT SHEET**: Commands, common tasks, diagnostic queries | Operators | 5 min |
| [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) | **📁 COMPLETE FILE REFERENCE**: All 100+ scripts, their purposes, dependencies | Developers, operators | 15 min |

### 🎬 **Demo & Business**

| File | Purpose | Audience | Read Time |
|------|---------|----------|-----------|
| [demo_story_business.md](demo_story_business.md) | **🎬 "MAYA'S MONDAY MORNING"**: 12-min demo script, scene-by-scene, talking points | Sales, demo leads | 10 min |

### 🏗️ **Architecture & Advanced**

| File | Purpose | Audience | Read Time |
|------|---------|----------|-----------|
| [docs/AGENTS.md](docs/AGENTS.md) | **🤖 MULTI-AGENT SYSTEM**: 14 agents, preceptorship loop, 5-star review process | Architects, advanced developers | 15 min |
| [purview_governance_inventory.md](purview_governance_inventory.md) | **🔍 REST API DISCOVERIES**: UC features, endpoint status, limitations, findings | Technical architects | 20 min |
| [SEMANTIC_LABS_FABRIC_RUNBOOK.md](SEMANTIC_LABS_FABRIC_RUNBOOK.md) | **📊 POWER BI METADATA**: Semantic Labs extraction workflow | Power BI engineers | 10 min |

### ⚙️ **Configuration & Reference**

| File | Purpose |
|------|---------|
| [.github/copilot-instructions.md](.github/copilot-instructions.md) | Hard constraints, workflow rules, testing requirements |
| [.github/agent-instructions.md](.github/agent-instructions.md) | Copilot agent setup |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | GitHub Actions CI/CD pipeline |
| [requirements.txt](requirements.txt) | Python dependencies |
| [demo_users.json](demo_users.json) | 15 governance demo personas |

---

## 🗺️ Documentation Map (Use This If Unsure)

```
START HERE: Choose your path
    │
    ├─ I need the QUICK VERSION
    │   └─→ README.md (5 min) + QUICK_REFERENCE.md (5 min)
    │
    ├─ I need COMPREHENSIVE DETAILS
    │   └─→ STATUS.md (15 min) → then pick specialty below
    │
    ├─ I want to DEPLOY IT
    │   └─→ DEPLOYMENT_GUIDE.md (step-by-step)
    │
    ├─ I want to RUN A DEMO
    │   └─→ demo_story_business.md (script)
    │       + QUICK_REFERENCE.md (commands)
    │
    ├─ I'm DEVELOPING/EXTENDING IT
    │   └─→ CONTRIBUTING.md (setup)
    │       + docs/AGENTS.md (architecture)
    │       + PROJECT_STRUCTURE.md (all files)
    │
    ├─ I'm ARCHITECTING A SOLUTION
    │   └─→ docs/AGENTS.md (design)
    │       + purview_governance_inventory.md (API reference)
    │       + PROJECT_STRUCTURE.md (full layout)
    │
    └─ I'm TROUBLESHOOTING
        └─→ DEPLOYMENT_GUIDE.md (troubleshooting section)
            + QUICK_REFERENCE.md (diagnostics)
```

---

## 📊 Content Summary by Topic

### **What Gets Deployed**
- **Domains**: 16 (5 Lines of Business + 11 sub-domains)
- **Glossary Terms**: 75 (with owner/steward/CDO contacts)
- **Data Products**: 6 (endorsed, enriched with docs)
- **OKRs**: 5 with 15 Key Results
- **Critical Data Elements**: 15 (linked to physical columns)
- **Relationships**: 85+ (term-term, DP-term, CDE-term, CDE-CDC)
- **Custom Metadata Groups**: 3 (11 attributes)
- **Business Processes**: 5 (cross-domain)
- **Demo Users**: 15 (governance personas)
- **DQ-Tiered Assets**: 85 (🟢🟡🟠)
- **Demo Scenarios**: 4 runnable (S1–S4)

→ **See**: [STATUS.md](STATUS.md) for full metrics

### **How to Deploy**
- **Option A**: Full wipe + rebuild (25 min) → [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Option B**: Sprint-by-sprint (45 min) → [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Option C**: Quick enrichment (10 min) → [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **Option D**: Portal + scenarios → [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

### **How to Use It**
- **Demo Script**: [demo_story_business.md](demo_story_business.md) (12 min walkthrough)
- **Common Commands**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md) (cheat sheet)
- **Portal**: `.\run_scenario_environment.ps1` (4 runnable scenarios)

### **How It Works**
- **Architecture**: [docs/AGENTS.md](docs/AGENTS.md) (14 agents, preceptorship loop)
- **REST APIs**: [purview_governance_inventory.md](purview_governance_inventory.md) (discoveries + limitations)
- **File Structure**: [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) (100+ scripts documented)

### **How to Extend It**
- **Development Setup**: [CONTRIBUTING.md](CONTRIBUTING.md)
- **Workflow Rules**: [.github/copilot-instructions.md](.github/copilot-instructions.md)
- **Testing**: `pytest tests/ --tb=short -q`

---

## 🔄 Common Reading Flows

### Flow 1: "I have 15 minutes"
1. [README.md](README.md) (5 min)
2. [STATUS.md](STATUS.md) — Status section only (5 min)
3. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — Commands section (5 min)

### Flow 2: "I need to deploy today"
1. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) — Prerequisites + Setup (10 min)
2. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) — Pick deployment path (25–45 min execution)
3. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) — Verification checklist (5 min)

### Flow 3: "I need to demo this tomorrow"
1. [demo_story_business.md](demo_story_business.md) — Full script (10 min)
2. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — Demo narrative talking points (5 min)
3. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — Pre-demo checklist (5 min)
4. Practice run (15 min)

### Flow 4: "I'm a developer joining the team"
1. [CONTRIBUTING.md](CONTRIBUTING.md) — Full setup (15 min)
2. [docs/AGENTS.md](docs/AGENTS.md) — Architecture overview (15 min)
3. [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) — File reference (10 min)
4. Pick a script, read it, understand the pattern

### Flow 5: "I need to troubleshoot"
1. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — Diagnostic queries section
2. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) — Troubleshooting section
3. [purview_governance_inventory.md](purview_governance_inventory.md) — REST API status (if API issue)

---

## 🎓 Learning Paths

### **Non-Technical Audience** (Executives, Business)
```
README.md (5 min)
    ↓
STATUS.md (skim for metrics, 5 min)
    ↓
demo_story_business.md (read full script, 10 min)
    ↓
[READY TO DEMO]
```
**Total**: 20 minutes

### **Technical Operator** (DevOps, Admin)
```
README.md (5 min)
    ↓
DEPLOYMENT_GUIDE.md (section 1-2, 10 min)
    ↓
QUICK_REFERENCE.md (5 min)
    ↓
[DEPLOY using chosen path]
    ↓
DEPLOYMENT_GUIDE.md (section 4, verification, 5 min)
    ↓
[VERIFY SUCCESS]
```
**Total**: 25 minutes + deployment execution time

### **Solutions Architect**
```
README.md (5 min)
    ↓
STATUS.md (full, 15 min)
    ↓
docs/AGENTS.md (15 min)
    ↓
purview_governance_inventory.md (20 min)
    ↓
PROJECT_STRUCTURE.md (optional deep dive, 15 min)
    ↓
[DESIGN custom solution]
```
**Total**: 70 minutes

### **Developer/Engineer**
```
CONTRIBUTING.md (15 min)
    ↓
docs/AGENTS.md (15 min)
    ↓
PROJECT_STRUCTURE.md (15 min)
    ↓
[PICK a script + source code]
    ↓
[EXTEND/MODIFY]
    ↓
pytest tests/ --tb=short -q
    ↓
[SUBMIT PR]
```
**Total**: 45 minutes + development time

---

## ✅ Quality Checklist

- ✅ All documentation files use consistent formatting (Markdown)
- ✅ Each document has a clear purpose and audience listed
- ✅ All files are cross-linked where relevant
- ✅ Quick reference available for common tasks
- ✅ Step-by-step guides for deployment
- ✅ Troubleshooting guide included
- ✅ Architecture documented for developers
- ✅ Business narrative documented for demos
- ✅ All 100+ scripts referenced with purpose
- ✅ API discoveries documented for architects
- ✅ README links to all key docs
- ✅ Status page tracks project metrics

---

## 🔗 Quick Links

| I want to... | Click here |
|-------------|-----------|
| Understand the project | [README.md](README.md) |
| See current status | [STATUS.md](STATUS.md) |
| Deploy it | [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) |
| Run a quick command | [QUICK_REFERENCE.md](QUICK_REFERENCE.md) |
| Demo it | [demo_story_business.md](demo_story_business.md) |
| Understand the architecture | [docs/AGENTS.md](docs/AGENTS.md) |
| Learn REST APIs | [purview_governance_inventory.md](purview_governance_inventory.md) |
| Review all files | [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) |
| Set up development | [CONTRIBUTING.md](CONTRIBUTING.md) |
| See version history | [CHANGELOG.md](CHANGELOG.md) |

---

## 📞 Support & Feedback

- **Questions?** Review the relevant section in this index
- **Bug Report?** See [CONTRIBUTING.md](CONTRIBUTING.md) for workflow
- **Feature Request?** See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution process
- **Documentation Issue?** Suggest improvement in PR

---

**Status**: ✅ Production Ready | **v2.0.0** | **Last Updated**: July 2, 2026

---

## 📄 Document Statistics

- **Total documentation files**: 10 main + 14 agent definitions
- **Total words**: ~50,000+ across all docs
- **Average read time per doc**: 5–20 minutes
- **Code coverage**: 100+ scripts documented
- **CI/CD**: GitHub Actions + pytest
- **Deployment paths**: 4 options
- **Demo scenarios**: 4 runnable

---

**Welcome! Start with your role above or use the Quick Links to jump to what you need. Everything you need to understand, deploy, and demo this solution is documented here.** 🚀
