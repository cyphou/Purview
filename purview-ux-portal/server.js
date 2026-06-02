const express = require("express");
const path = require("path");
const fs = require("fs/promises");
const { exec } = require("child_process");
const { promisify } = require("util");

const execAsync = promisify(exec);

const app = express();
app.disable("x-powered-by");
app.use((req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "SAMEORIGIN");
  res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  next();
});
app.use(express.json({ limit: "1mb" }));
app.use(express.static(path.join(__dirname, "public")));

const purviewAccount = process.env.PURVIEW_ACCOUNT_NAME || "pdedemopurv";
const dgApiVersion = process.env.PURVIEW_API_VERSION || "2026-03-20-preview";
const port = Number(process.env.PORT || 7071);
const baseUrl = `https://${purviewAccount}.purview.azure.com`;
const configPath = path.join(__dirname, "scenario-environment.config.json");

const defaultScenarioConfig = {
  scenarios: {
    s1: {
      name: "Scenario 1 - KPI explainability",
      requiredSearchTerms: [
        "Profitability Net Profit Margin",
        "Profitability Gross Profit Margin",
        "Profitability Return on Investment"
      ]
    },
    s2: {
      name: "Scenario 2 - Domaine + Data Product",
      requiredDataProducts: [
        "Customer 360",
        "Executive Financial Dashboards",
        "Workforce Analytics Dashboard"
      ]
    },
    s3: {
      name: "Scenario 3 - Asset gouverne",
      requiredSearchTerms: [
        "Customer Master ID",
        "Email Address",
        "Customer Lifetime Value",
        "GL Account Number"
      ]
    },
    s4: {
      name: "Scenario 4 - Roles et adoption",
      requiredPersonas: ["cdo", "financeowner", "dq.lead", "dpo"],
      requiredEvidenceFiles: [
        "docs/scenario4_admin_adoption_evidence.md",
        "docs/scenario4_admin_adoption_evidence.json"
      ]
    }
  }
};

async function getPurviewToken() {
  if (process.env.PURVIEW_BEARER_TOKEN) {
    return process.env.PURVIEW_BEARER_TOKEN.trim();
  }

  const azCandidates = [
    "az",
    "az.cmd",
    "az.exe",
    '"C:\\Program Files\\Microsoft SDKs\\Azure\\CLI2\\wbin\\az.cmd"'
  ];
  let lastError = "";

  for (const azBin of azCandidates) {
    try {
      const command = `${azBin} account get-access-token --resource https://purview.azure.net --query accessToken -o tsv`;
      const { stdout } = await execAsync(command, { windowsHide: true });
      const token = (stdout || "").trim();
      if (token) {
        return token;
      }
      lastError = `Token empty with ${azBin}`;
    } catch (err) {
      lastError = err && err.message ? err.message : String(err);
    }
  }

  try {
    throw new Error(lastError || "No az executable found in PATH.");
  } catch (err) {
    const message = err && err.message ? err.message : String(err);
    throw new Error(
      `Failed to get Azure token. Try 'az login', ensure az is in PATH for Node, or set PURVIEW_BEARER_TOKEN. Details: ${message}`
    );
  }
}

async function purviewGet(relativePath) {
  const token = await getPurviewToken();
  const response = await fetch(`${baseUrl}${relativePath}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    }
  });

  if (!response.ok) {
    const bodyText = await response.text();
    throw new Error(`Purview GET ${relativePath} failed (${response.status}): ${bodyText}`);
  }

  return response.json();
}

async function purviewPost(relativePath, payload) {
  const token = await getPurviewToken();
  const response = await fetch(`${baseUrl}${relativePath}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    const bodyText = await response.text();
    throw new Error(`Purview POST ${relativePath} failed (${response.status}): ${bodyText}`);
  }

  return response.json();
}

function normalizeList(result) {
  if (!result) {
    return [];
  }
  if (Array.isArray(result.value)) {
    return result.value;
  }
  if (Array.isArray(result.assets)) {
    return result.assets;
  }
  if (Array.isArray(result)) {
    return result;
  }
  return [];
}

function normalizeText(value) {
  return String(value || "").trim();
}

function includesQuery(item, query) {
  const q = query.toLowerCase();
  const haystack = [item.name, item.description, item.entityType, item.objectKind, item.searchTokens]
    .map((v) => normalizeText(v).toLowerCase())
    .join(" ");
  return haystack.includes(q);
}

function toSearchShape(item, objectKind, extras = {}) {
  return {
    id: item.id,
    name: normalizeText(item.name),
    description: normalizeText(item.description),
    entityType: normalizeText(item.entityType || item.assetType || item.status || objectKind),
    objectKind,
    searchTokens: normalizeText(extras.searchTokens || ""),
    sourceAssetId: normalizeText(extras.sourceAssetId || "")
  };
}

function extractDataQualityTags(classifications) {
  if (!Array.isArray(classifications)) {
    return [];
  }

  const normalized = classifications.map((c) => normalizeText(c)).filter(Boolean);
  return normalized.filter((tag) => {
    const lower = tag.toLowerCase();
    return (
      lower.startsWith("dq") ||
      lower.includes("dataquality") ||
      lower.includes("quality")
    );
  });
}

async function getUnifiedObjects() {
  const [dataProductsRaw, dataAssetsRaw, termsRaw, domainsRaw] = await Promise.all([
    purviewGet(`/datagovernance/catalog/dataproducts?api-version=${dgApiVersion}&top=500`),
    purviewGet(`/datagovernance/catalog/dataAssets?api-version=${dgApiVersion}&top=2000`),
    purviewGet(`/datagovernance/catalog/terms?api-version=${dgApiVersion}&top=1000`),
    purviewGet(`/datagovernance/catalog/businessdomains?api-version=${dgApiVersion}&top=500`)
  ]);

  const dataProducts = normalizeList(dataProductsRaw).map((item) =>
    toSearchShape(
      {
        id: item.id,
        name: item.name,
        description: item.description,
        entityType: item.status || "DataProduct"
      },
      "dataProduct"
    )
  );

  const dataAssets = normalizeList(dataAssetsRaw).map((item) =>
    toSearchShape(
      {
        id: item.id,
        name: item.name,
        description: item.description,
        entityType: item.assetType || "DataAsset"
      },
      "dataAsset",
      {
        searchTokens: Array.isArray(item.classifications) ? item.classifications.join(" ") : ""
      }
    )
  );

  const dataQuality = [];
  normalizeList(dataAssetsRaw).forEach((item) => {
    const dqTags = extractDataQualityTags(item.classifications);
    dqTags.forEach((dqTag) => {
      const dqId = `dq:${item.id}:${dqTag}`;
      dataQuality.push(
        toSearchShape(
          {
            id: dqId,
            name: `${item.name} - ${dqTag}`,
            description: `Signal Data Quality detecte sur asset ${item.name}`,
            entityType: dqTag
          },
          "dataQuality",
          {
            searchTokens: `${dqTag} ${item.name}`,
            sourceAssetId: item.id
          }
        )
      );
    });
  });

  const terms = normalizeList(termsRaw).map((item) =>
    toSearchShape(
      {
        id: item.id,
        name: item.name,
        description: item.description,
        entityType: "BusinessTerm"
      },
      "businessTerm"
    )
  );

  const domains = normalizeList(domainsRaw).map((item) =>
    toSearchShape(
      {
        id: item.id,
        name: item.name,
        description: item.description,
        entityType: "BusinessDomain"
      },
      "businessDomain"
    )
  );

  return [...dataProducts, ...dataAssets, ...terms, ...domains, ...dataQuality].filter(
    (item) => item.id && item.name
  );
}

async function getObjectByTypeAndId(objectKind, id) {
  if (objectKind === "dataProduct") {
    const all = await purviewGet(`/datagovernance/catalog/dataproducts?api-version=${dgApiVersion}&top=500`);
    return normalizeList(all).find((item) => item.id === id) || null;
  }
  if (objectKind === "dataAsset") {
    const all = await purviewGet(`/datagovernance/catalog/dataAssets?api-version=${dgApiVersion}&top=2000`);
    return normalizeList(all).find((item) => item.id === id) || null;
  }
  if (objectKind === "businessTerm") {
    const all = await purviewGet(`/datagovernance/catalog/terms?api-version=${dgApiVersion}&top=1000`);
    return normalizeList(all).find((item) => item.id === id) || null;
  }
  if (objectKind === "businessDomain") {
    const all = await purviewGet(`/datagovernance/catalog/businessdomains?api-version=${dgApiVersion}&top=500`);
    return normalizeList(all).find((item) => item.id === id) || null;
  }
  if (objectKind === "dataQuality") {
    const all = await purviewGet(`/datagovernance/catalog/dataAssets?api-version=${dgApiVersion}&top=2000`);
    const parts = id.split(":");
    if (parts.length < 3) {
      return null;
    }
    const sourceAssetId = parts[1];
    const dqTag = parts.slice(2).join(":");
    const sourceAsset = normalizeList(all).find((item) => item.id === sourceAssetId);
    if (!sourceAsset) {
      return null;
    }
    return {
      id,
      name: `${sourceAsset.name} - ${dqTag}`,
      description: `Signal Data Quality detecte sur asset ${sourceAsset.name}`,
      assetType: dqTag,
      sourceAssetId
    };
  }
  return null;
}

async function getDataProductAssets(dataProductId) {
  const rel = await purviewGet(
    `/datagovernance/catalog/dataproducts/${dataProductId}/relationships?entityType=DataAsset&api-version=${dgApiVersion}`
  );
  const allAssetsRaw = await purviewGet(
    `/datagovernance/catalog/dataAssets?api-version=${dgApiVersion}&top=2000`
  );
  const allAssets = normalizeList(allAssetsRaw);
  const byId = new Map(allAssets.map((a) => [a.id, a]));

  return normalizeList(rel)
    .map((r) => r.entityId || r.id)
    .filter(Boolean)
    .map((assetId) => byId.get(assetId))
    .filter(Boolean)
    .map((asset) => ({
      id: asset.id,
      name: asset.name,
      objectKind: "dataAsset",
      entityType: asset.assetType || "DataAsset"
    }))
    .sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
}

async function getAssetLineage(assetId) {
  const token = await getPurviewToken();
  const endpoints = [
    `${baseUrl}/catalog/api/atlas/v2/lineage/${encodeURIComponent(assetId)}?direction=BOTH&depth=3`,
    `${baseUrl}/catalog/api/atlas/v2/lineage/${encodeURIComponent(assetId)}?direction=INPUT&depth=3`,
    `${baseUrl}/catalog/api/atlas/v2/lineage/${encodeURIComponent(assetId)}?direction=OUTPUT&depth=3`
  ];

  for (const url of endpoints) {
    try {
      const response = await fetch(url, {
        method: "GET",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json"
        }
      });

      if (!response.ok) {
        continue;
      }

      const raw = await response.json();
      const guidEntityMap = raw.guidEntityMap || {};
      const relations = Array.isArray(raw.relations) ? raw.relations : [];

      const nodes = Object.keys(guidEntityMap).map((guid) => {
        const entity = guidEntityMap[guid] || {};
        const attrs = entity.attributes || {};
        return {
          id: guid,
          name: attrs.name || entity.displayText || guid,
          typeName: entity.typeName || "Unknown"
        };
      });

      const edges = relations
        .map((rel) => ({
          fromEntityId: rel.fromEntityId || rel.fromEntityGuid || "",
          toEntityId: rel.toEntityId || rel.toEntityGuid || "",
          relationshipType: rel.relationshipType || "lineage"
        }))
        .filter((e) => e.fromEntityId && e.toEntityId);

      return {
        nodes,
        edges,
        hasLineage: nodes.length > 0 && edges.length > 0
      };
    } catch (_err) {
      // Try next endpoint variant.
    }
  }

  return {
    nodes: [],
    edges: [],
    hasLineage: false
  };
}

async function readFileIfExists(filePath) {
  try {
    return await fs.readFile(filePath, "utf8");
  } catch (err) {
    if (err && err.code === "ENOENT") {
      return null;
    }
    throw err;
  }
}

async function loadScenarioConfig() {
  const raw = await readFileIfExists(configPath);
  if (!raw) {
    return defaultScenarioConfig;
  }

  try {
    const parsed = JSON.parse(raw);
    return {
      scenarios: {
        ...defaultScenarioConfig.scenarios,
        ...(parsed.scenarios || {})
      }
    };
  } catch (_err) {
    return defaultScenarioConfig;
  }
}

async function searchTermExists(term) {
  const payload = {
    keywords: term,
    limit: 5
  };

  const result = await purviewPost(
    "/catalog/api/search/query?api-version=2022-08-01-preview",
    payload
  );

  return normalizeList(result).length > 0;
}

function computeStatus(readyCount, totalCount) {
  if (totalCount === 0) {
    return "unknown";
  }
  if (readyCount === totalCount) {
    return "ready";
  }
  if (readyCount > 0) {
    return "partial";
  }
  return "missing";
}

async function getScenario4EvidenceData() {
  const docsDir = path.join(__dirname, "..", "docs");
  const mdPath = path.join(docsDir, "scenario4_admin_adoption_evidence.md");
  const jsonPath = path.join(docsDir, "scenario4_admin_adoption_evidence.json");

  const [mdContent, jsonContent] = await Promise.all([
    readFileIfExists(mdPath),
    readFileIfExists(jsonPath)
  ]);

  let parsedJson = null;
  if (jsonContent) {
    try {
      parsedJson = JSON.parse(jsonContent);
    } catch (_err) {
      parsedJson = null;
    }
  }

  const searchCorpus = `${mdContent || ""}\n${jsonContent || ""}`.toLowerCase();
  const personaChecks = {
    cdo: searchCorpus.includes("cdo"),
    financeowner: searchCorpus.includes("financeowner"),
    "dq.lead": searchCorpus.includes("dq.lead"),
    dpo: searchCorpus.includes("dpo")
  };

  return {
    files: {
      md: Boolean(mdContent),
      json: Boolean(jsonContent)
    },
    personaChecks,
    jsonKeys: parsedJson && typeof parsedJson === "object" ? Object.keys(parsedJson).slice(0, 20) : [],
    mdPreview: mdContent ? mdContent.split(/\r?\n/).slice(0, 8) : []
  };
}

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, purviewAccount, dgApiVersion });
});

app.get("/api/overview", async (_req, res) => {
  try {
    const [dataProducts, dataAssets, terms, domains] = await Promise.all([
      purviewGet(`/datagovernance/catalog/dataproducts?api-version=${dgApiVersion}&top=500`),
      purviewGet(`/datagovernance/catalog/dataAssets?api-version=${dgApiVersion}&top=2000`),
      purviewGet(`/datagovernance/catalog/terms?api-version=${dgApiVersion}&top=500`),
      purviewGet(`/datagovernance/catalog/businessdomains?api-version=${dgApiVersion}&top=200`)
    ]);

    const assets = normalizeList(dataAssets);
    const snowflakeCount = assets.filter((a) => a.assetType === "snowflake_table").length;

    res.json({
      counts: {
        dataProducts: normalizeList(dataProducts).length,
        dataAssets: assets.length,
        terms: normalizeList(terms).length,
        businessDomains: normalizeList(domains).length,
        snowflakeTables: snowflakeCount
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/scenarios/config", async (_req, res) => {
  try {
    const config = await loadScenarioConfig();
    res.json(config);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/scenarios/readiness", async (_req, res) => {
  try {
    const config = await loadScenarioConfig();
    const dpResult = await purviewGet(
      `/datagovernance/catalog/dataproducts?api-version=${dgApiVersion}&top=500`
    );
    const dpNames = new Set(
      normalizeList(dpResult)
        .map((d) => String(d.name || "").trim())
        .filter(Boolean)
    );

    const s1Terms = config.scenarios.s1.requiredSearchTerms || [];
    const s1Checks = await Promise.all(
      s1Terms.map(async (term) => ({ term, exists: await searchTermExists(term) }))
    );
    const s1Ready = s1Checks.filter((c) => c.exists).length;

    const s2Dps = config.scenarios.s2.requiredDataProducts || [];
    const s2Checks = s2Dps.map((name) => ({ name, exists: dpNames.has(name) }));
    const s2Ready = s2Checks.filter((c) => c.exists).length;

    const s3Terms = config.scenarios.s3.requiredSearchTerms || [];
    const s3Checks = await Promise.all(
      s3Terms.map(async (term) => ({ term, exists: await searchTermExists(term) }))
    );
    const s3Ready = s3Checks.filter((c) => c.exists).length;

    const evidence = await getScenario4EvidenceData();
    const personaChecks = config.scenarios.s4.requiredPersonas || [];
    const s4Checks = personaChecks.map((p) => ({
      persona: p,
      exists: Boolean(evidence.personaChecks[p])
    }));
    const filesReady = [evidence.files.md, evidence.files.json].filter(Boolean).length;
    const s4Ready = s4Checks.filter((c) => c.exists).length + filesReady;
    const s4Total = s4Checks.length + 2;

    const scenarios = {
      s1: {
        name: config.scenarios.s1.name,
        status: computeStatus(s1Ready, s1Checks.length),
        ready: s1Ready,
        total: s1Checks.length,
        checks: s1Checks
      },
      s2: {
        name: config.scenarios.s2.name,
        status: computeStatus(s2Ready, s2Checks.length),
        ready: s2Ready,
        total: s2Checks.length,
        checks: s2Checks
      },
      s3: {
        name: config.scenarios.s3.name,
        status: computeStatus(s3Ready, s3Checks.length),
        ready: s3Ready,
        total: s3Checks.length,
        checks: s3Checks
      },
      s4: {
        name: config.scenarios.s4.name,
        status: computeStatus(s4Ready, s4Total),
        ready: s4Ready,
        total: s4Total,
        files: evidence.files,
        checks: s4Checks
      }
    };

    res.json({ generatedAt: new Date().toISOString(), scenarios });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/data-products", async (_req, res) => {
  try {
    const result = await purviewGet(
      `/datagovernance/catalog/dataproducts?api-version=${dgApiVersion}&top=500`
    );
    const items = normalizeList(result)
      .map((item) => ({
        id: item.id,
        name: item.name,
        description: item.description || "",
        status: item.status || ""
      }))
      .sort((a, b) => a.name.localeCompare(b.name));

    res.json({ value: items });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/data-products/:id/assets", async (req, res) => {
  try {
    const dataProductId = req.params.id;
    const rel = await getDataProductAssets(dataProductId);

    const linked = rel.map((asset) => ({
      id: asset.id,
      name: asset.name,
      assetType: asset.entityType || "",
      qualifiedName: ""
    }));

    res.json({ value: linked });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/objects/search", async (req, res) => {
  try {
    const query = normalizeText(req.query.query);
    const requestedTypes = normalizeText(req.query.types)
      .split(",")
      .map((v) => normalizeText(v))
      .filter(Boolean);
    const allowedTypes = new Set([
      "dataProduct",
      "dataAsset",
      "businessTerm",
      "businessDomain",
      "dataQuality"
    ]);
    const selectedTypes = requestedTypes.length > 0
      ? requestedTypes.filter((t) => allowedTypes.has(t))
      : Array.from(allowedTypes);
    const limit = Math.max(1, Math.min(Number(req.query.limit || 200), 500));

    const allObjects = await getUnifiedObjects();
    const filtered = allObjects
      .filter((item) => selectedTypes.includes(item.objectKind))
      .filter((item) => (query ? includesQuery(item, query) : true))
      .sort((a, b) => a.name.localeCompare(b.name))
      .slice(0, limit);

    res.json({
      value: filtered,
      meta: {
        total: filtered.length,
        query,
        selectedTypes
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/objects/:objectKind/:id", async (req, res) => {
  try {
    const objectKind = normalizeText(req.params.objectKind);
    const id = normalizeText(req.params.id);
    const found = await getObjectByTypeAndId(objectKind, id);

    if (!found) {
      return res.status(404).json({ error: "Object not found" });
    }

    let related = [];
    if (objectKind === "dataProduct") {
      related = await getDataProductAssets(id);
    } else if (objectKind === "dataQuality") {
      const sourceAssetId = found.sourceAssetId || "";
      if (sourceAssetId) {
        related = [
          {
            id: sourceAssetId,
            name: "Asset source",
            objectKind: "dataAsset",
            entityType: "DataAsset"
          }
        ];
      }
    }

    res.json({
      object: {
        id: found.id,
        name: found.name || "",
        description: found.description || "",
        objectKind,
        entityType: found.assetType || found.status || objectKind,
        sourceAssetId: found.sourceAssetId || ""
      },
      related
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/objects/:objectKind/:id/lineage", async (req, res) => {
  try {
    const objectKind = normalizeText(req.params.objectKind);
    const id = normalizeText(req.params.id);

    let effectiveObjectKind = objectKind;
    let effectiveId = id;

    if (objectKind === "dataQuality") {
      const found = await getObjectByTypeAndId("dataQuality", id);
      if (found && found.sourceAssetId) {
        effectiveObjectKind = "dataAsset";
        effectiveId = found.sourceAssetId;
      }
    }

    if (effectiveObjectKind !== "dataAsset") {
      return res.json({
        hasLineage: false,
        nodes: [],
        edges: [],
        message: "Lineage disponible uniquement pour les Data Assets dans ce portail."
      });
    }

    const lineage = await getAssetLineage(effectiveId);
    res.json(lineage);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/search", async (req, res) => {
  try {
    const query = String(req.query.query || "").trim();
    if (!query) {
      return res.status(400).json({ error: "query is required" });
    }

    const payload = {
      keywords: query,
      limit: 25
    };

    const result = await purviewPost(
      "/catalog/api/search/query?api-version=2022-08-01-preview",
      payload
    );

    const items = normalizeList(result)
      .map((item) => {
        const attrs = item.asset || item.entity || item;
        return {
          id: attrs.id || attrs.guid || "",
          name: attrs.name || attrs.displayText || "",
          entityType: attrs.entityType || attrs.objectType || "",
          description:
            (attrs.description || "") ||
            (attrs.attributes && attrs.attributes.description ? attrs.attributes.description : "")
        };
      })
      .filter((item) => item.name);

    res.json({ value: items });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/api/scenario4/evidence", async (_req, res) => {
  try {
    res.json(await getScenario4EvidenceData());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("*", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.listen(port, () => {
  console.log(`Purview UX portal running on http://localhost:${port}`);
});
