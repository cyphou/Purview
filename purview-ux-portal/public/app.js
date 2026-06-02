const metricsGrid = document.getElementById("metricsGrid");
const readinessBoard = document.getElementById("readinessBoard");
const scenarioNav = document.getElementById("scenarioNav");
const presetQueries = document.getElementById("presetQueries");

const searchForm = document.getElementById("searchForm");
const searchInput = document.getElementById("searchInput");
const searchResults = document.getElementById("searchResults");
const governedResults = document.getElementById("governedResults");
const objectFilters = document.getElementById("objectFilters");

const dataProducts = document.getElementById("dataProducts");
const assetsForProduct = document.getElementById("assetsForProduct");
const assetHint = document.getElementById("assetHint");

const refreshBtn = document.getElementById("refreshBtn");
const loadEvidenceBtn = document.getElementById("loadEvidenceBtn");
const evidenceBox = document.getElementById("evidenceBox");

const scenarioTitle = document.getElementById("scenarioTitle");
const scenarioObjective = document.getElementById("scenarioObjective");
const scenarioSteps = document.getElementById("scenarioSteps");
const scenarioSay = document.getElementById("scenarioSay");
const scenarioBackup = document.getElementById("scenarioBackup");

const selectedObjectHint = document.getElementById("selectedObjectHint");
const selectedObjectCard = document.getElementById("selectedObjectCard");
const lineageBox = document.getElementById("lineageBox");

const template = document.getElementById("resultItemTemplate");

let activeDataProductId = "";
let activeScenarioId = "explorer";
let scenarioModels = {};
let activeObjectKey = "";

async function api(path) {
  const response = await fetch(path);
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body.error || `Request failed: ${response.status}`);
  }
  return body;
}

function clearElement(el) {
  while (el.firstChild) {
    el.removeChild(el.firstChild);
  }
}

function renderError(target, message) {
  clearElement(target);
  const li = document.createElement("li");
  li.className = "error";
  li.textContent = message;
  target.appendChild(li);
}

function metricCard(label, value) {
  const div = document.createElement("div");
  div.className = "metric";
  const p = document.createElement("p");
  p.textContent = label;
  const strong = document.createElement("strong");
  strong.textContent = String(value);
  div.appendChild(p);
  div.appendChild(strong);
  return div;
}

function readinessCard(label, status, ready, total) {
  const div = document.createElement("div");
  div.className = `readiness-card status-${status}`;

  const title = document.createElement("p");
  title.className = "readiness-title";
  title.textContent = label;

  const badge = document.createElement("span");
  badge.className = "readiness-badge";
  badge.textContent = String(status || "unknown").toUpperCase();

  const score = document.createElement("p");
  score.className = "readiness-score";
  score.textContent = `${ready}/${total}`;

  div.appendChild(title);
  div.appendChild(badge);
  div.appendChild(score);
  return div;
}

function makeResultItem({ name, type, desc, onClick, isActive = false }) {
  const fragment = template.content.cloneNode(true);
  const li = fragment.querySelector("li");
  li.querySelector(".name").textContent = name || "(sans nom)";
  li.querySelector(".type-tag").textContent = type || "unknown";
  li.querySelector(".desc").textContent = desc || "";
  if (isActive) {
    li.classList.add("active");
  }
  if (typeof onClick === "function") {
    li.style.cursor = "pointer";
    li.addEventListener("click", onClick);
  }
  return li;
}

function objectLabel(kind) {
  const map = {
    dataProduct: "Data Product",
    dataAsset: "Data Asset",
    dataQuality: "Data Quality",
    businessTerm: "Business Term",
    businessDomain: "Business Domain"
  };
  return map[kind] || kind;
}

function createScenarioModel(id, raw) {
  const searchTerms = Array.isArray(raw.requiredSearchTerms) ? raw.requiredSearchTerms : [];
  const dataProductsNeeded = Array.isArray(raw.requiredDataProducts) ? raw.requiredDataProducts : [];
  const personas = Array.isArray(raw.requiredPersonas) ? raw.requiredPersonas : [];

  if (searchTerms.length > 0) {
    return {
      id,
      title: raw.name || id,
      objective: "Utiliser la recherche catalogue pour retrouver rapidement les objets metier.",
      steps: [
        "Choisir une requete de reference ci-dessous.",
        "Executer la recherche et ouvrir le meilleur resultat.",
        "Verifier definition, ownership et contexte d'usage."
      ],
      say: "Je reponds a une question metier rapidement a partir du catalogue.",
      backup: searchTerms.slice(1).join(" -> ") || "Utiliser une requete alternative",
      presets: searchTerms,
      focus: "search"
    };
  }

  if (dataProductsNeeded.length > 0) {
    return {
      id,
      title: raw.name || id,
      objective: "Explorer des Data Products et leurs assets relies pour faciliter la reutilisation.",
      steps: [
        "Selectionner un Data Product dans l'explorateur.",
        "Verifier assets, description et statut.",
        "Confirmer la pertinence pour le besoin metier."
      ],
      say: "Je navigue en langage metier et je valide la reutilisation en quelques clics.",
      backup: dataProductsNeeded.slice(1).join(" -> ") || "Changer de Data Product",
      presets: dataProductsNeeded,
      focus: "dataproduct"
    };
  }

  if (personas.length > 0) {
    return {
      id,
      title: raw.name || id,
      objective: "Verifier la readiness role/adoption a partir des artefacts de preuve.",
      steps: [
        "Charger la preuve scenario 4.",
        "Verifier fichiers et personas requis.",
        "Conclure sur la readiness go-live."
      ],
      say: "Meme portail, droits differents, et adoption mesurable.",
      backup: "S'appuyer sur les artefacts disponibles",
      presets: [],
      focus: "evidence"
    };
  }

  return {
    id,
    title: raw.name || id,
    objective: "Scenario personnalise charge depuis la configuration.",
    steps: ["Adapter les actions selon le besoin metier."],
    say: "Je peux adapter ce scenario au contexte client.",
    backup: "Passer en mode Explorateur",
    presets: [],
    focus: "search"
  };
}

function renderScenarioGuide(model) {
  scenarioTitle.textContent = model.title;
  scenarioObjective.textContent = model.objective;
  scenarioSay.textContent = model.say;
  scenarioBackup.textContent = model.backup;

  clearElement(scenarioSteps);
  model.steps.forEach((step) => {
    const li = document.createElement("li");
    li.textContent = step;
    scenarioSteps.appendChild(li);
  });
}

function renderScenarioButtons() {
  clearElement(scenarioNav);

  Object.values(scenarioModels).forEach((model) => {
    const btn = document.createElement("button");
    btn.className = "scenario-btn";
    btn.dataset.scenario = model.id;
    btn.textContent = model.title;
    btn.addEventListener("click", () => {
      switchScenario(model.id);
    });
    scenarioNav.appendChild(btn);
  });
}

function renderPresetQueries(model) {
  clearElement(presetQueries);

  if (!Array.isArray(model.presets) || model.presets.length === 0) {
    const hint = document.createElement("p");
    hint.className = "hint";
    hint.textContent = "Aucune requete predefinie pour ce scenario. Utilise la recherche libre.";
    presetQueries.appendChild(hint);
    return;
  }

  model.presets.forEach((preset) => {
    const btn = document.createElement("button");
    btn.className = "pill";
    btn.type = "button";
    btn.dataset.query = preset;
    btn.textContent = preset;
    btn.addEventListener("click", async () => {
      searchInput.value = preset;
      await runSearch(preset);
    });
    presetQueries.appendChild(btn);
  });
}

function markActiveScenarioButton(id) {
  Array.from(scenarioNav.querySelectorAll(".scenario-btn")).forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.scenario === id);
  });
}

function getSelectedObjectTypes() {
  const checks = Array.from(objectFilters.querySelectorAll("input[type=checkbox]:checked"));
  const values = checks.map((checkbox) => checkbox.value);
  return values.length > 0
    ? values
    : ["dataProduct", "dataAsset", "dataQuality", "businessTerm", "businessDomain"];
}

function renderObjectCard(object) {
  selectedObjectHint.textContent = `Objet selectionne: ${object.name}`;
  selectedObjectCard.innerHTML = "";

  const h4 = document.createElement("h4");
  h4.textContent = object.name;
  const p1 = document.createElement("p");
  p1.className = "hint";
  p1.textContent = `${objectLabel(object.objectKind)} - ${object.entityType || "Unknown"}`;
  const p2 = document.createElement("p");
  p2.textContent = object.description || "Aucune description disponible.";

  selectedObjectCard.appendChild(h4);
  selectedObjectCard.appendChild(p1);
  selectedObjectCard.appendChild(p2);
}

function renderLineage(lineage, objectKind) {
  lineageBox.innerHTML = "";

  if (objectKind !== "dataAsset") {
    const p = document.createElement("p");
    p.textContent = "Lineage disponible uniquement pour les Data Assets.";
    lineageBox.appendChild(p);
    return;
  }

  if (!lineage.hasLineage || !lineage.nodes.length || !lineage.edges.length) {
    const p = document.createElement("p");
    p.textContent = "Aucun lineage detecte pour cet asset.";
    lineageBox.appendChild(p);
    return;
  }

  const summary = document.createElement("p");
  summary.className = "hint";
  summary.textContent = `Noeuds: ${lineage.nodes.length} - Relations: ${lineage.edges.length}`;
  lineageBox.appendChild(summary);

  const maxEdges = lineage.edges.slice(0, 20);
  const byId = new Map(lineage.nodes.map((n) => [n.id, n]));
  const ul = document.createElement("ul");
  ul.className = "lineage-list";

  maxEdges.forEach((edge) => {
    const from = byId.get(edge.fromEntityId);
    const to = byId.get(edge.toEntityId);
    const li = document.createElement("li");
    li.textContent = `${from ? from.name : edge.fromEntityId} -> ${to ? to.name : edge.toEntityId}`;
    ul.appendChild(li);
  });

  lineageBox.appendChild(ul);
}

async function loadObjectDetails(objectKind, id) {
  activeObjectKey = `${objectKind}:${id}`;
  selectedObjectCard.innerHTML = "<p>Chargement objet...</p>";
  governedResults.innerHTML = "<li>Chargement relations...</li>";
  lineageBox.innerHTML = "<p>Chargement lineage...</p>";

  try {
    const [details, lineage] = await Promise.all([
      api(`/api/objects/${encodeURIComponent(objectKind)}/${encodeURIComponent(id)}`),
      api(`/api/objects/${encodeURIComponent(objectKind)}/${encodeURIComponent(id)}/lineage`)
    ]);

    renderObjectCard(details.object);

    clearElement(governedResults);
    if (!details.related || details.related.length === 0) {
      renderError(governedResults, "Aucun objet relie pour cette entite.");
    } else {
      details.related.forEach((related) => {
        const key = `${related.objectKind}:${related.id}`;
        governedResults.appendChild(
          makeResultItem({
            name: related.name,
            type: `${objectLabel(related.objectKind)} / ${related.entityType || "Unknown"}`,
            desc: "Cliquer pour naviguer.",
            isActive: activeObjectKey === key,
            onClick: async () => {
              await loadObjectDetails(related.objectKind, related.id);
            }
          })
        );
      });
    }

    renderLineage(lineage, objectKind);
  } catch (err) {
    selectedObjectCard.innerHTML = `<p class=\"error\">Erreur: ${err.message}</p>`;
    renderError(governedResults, err.message);
    lineageBox.innerHTML = `<p class=\"error\">Erreur lineage: ${err.message}</p>`;
  }
}

async function switchScenario(id) {
  const model = scenarioModels[id];
  if (!model) {
    return;
  }

  activeScenarioId = id;
  markActiveScenarioButton(id);
  renderScenarioGuide(model);
  renderPresetQueries(model);

  if (model.focus === "search" && model.presets.length > 0) {
    const preset = model.presets[0];
    searchInput.value = preset;
    await runSearch(preset);
  }

  if (model.focus === "evidence") {
    await loadScenario4Evidence();
  }
}

async function loadOverview() {
  metricsGrid.textContent = "Chargement...";
  try {
    const { counts } = await api("/api/overview");
    clearElement(metricsGrid);
    metricsGrid.appendChild(metricCard("Data Products disponibles", counts.dataProducts));
    metricsGrid.appendChild(metricCard("Assets catalogues", counts.dataAssets));
    metricsGrid.appendChild(metricCard("Termes gouvernes", counts.terms));
    metricsGrid.appendChild(metricCard("Domaines metier", counts.businessDomains));

    const readiness =
      counts.dataProducts >= 3 && counts.terms >= 20 && counts.businessDomains >= 2 ? "READY" : "CHECK";
    metricsGrid.appendChild(metricCard("Statut demo", readiness));
  } catch (err) {
    metricsGrid.textContent = `Erreur: ${err.message}`;
  }
}

async function loadReadiness() {
  readinessBoard.textContent = "Chargement readiness...";

  try {
    const data = await api("/api/scenarios/readiness");
    const scenarios = data.scenarios || {};
    clearElement(readinessBoard);

    Object.keys(scenarios).forEach((id) => {
      const s = scenarios[id];
      readinessBoard.appendChild(readinessCard(s.name || id, s.status, s.ready, s.total));
    });
  } catch (err) {
    readinessBoard.textContent = `Erreur readiness: ${err.message}`;
  }
}

async function loadDataProducts() {
  dataProducts.textContent = "Chargement...";
  try {
    const { value } = await api("/api/data-products");
    clearElement(dataProducts);

    if (!value.length) {
      renderError(dataProducts, "Aucun Data Product trouve.");
      return;
    }

    value.forEach((dp, index) => {
      const item = makeResultItem({
        name: dp.name,
        type: dp.status || "DataProduct",
        desc: dp.description || "",
        isActive: activeDataProductId === dp.id,
        onClick: async () => {
          activeDataProductId = dp.id;
          await loadDataProducts();
          await loadAssetsForProduct(dp.id, dp.name);
          await loadObjectDetails("dataProduct", dp.id);
        }
      });
      dataProducts.appendChild(item);

      if (!activeDataProductId && index === 0) {
        activeDataProductId = dp.id;
      }
    });

    if (activeDataProductId) {
      const selected = value.find((v) => v.id === activeDataProductId) || value[0];
      await loadAssetsForProduct(selected.id, selected.name);
    }
  } catch (err) {
    renderError(dataProducts, err.message);
  }
}

async function loadAssetsForProduct(id, name) {
  assetsForProduct.textContent = "Chargement...";
  assetHint.textContent = `Assets lies au Data Product: ${name}`;

  try {
    const { value } = await api(`/api/data-products/${id}/assets`);
    clearElement(assetsForProduct);

    if (!value.length) {
      renderError(assetsForProduct, "Aucun asset relie pour ce Data Product.");
      return;
    }

    value.forEach((asset) => {
      const desc = asset.qualifiedName || "Asset lie sans qualifiedName visible";
      assetsForProduct.appendChild(
        makeResultItem({
          name: asset.name,
          type: asset.assetType || "DataAsset",
          desc,
          onClick: async () => {
            await loadObjectDetails("dataAsset", asset.id);
          }
        })
      );
    });
  } catch (err) {
    renderError(assetsForProduct, err.message);
  }
}

async function runSearch(query) {
  searchResults.textContent = "Recherche en cours...";
  try {
    const selectedTypes = getSelectedObjectTypes();
    const qs = new URLSearchParams({
      query,
      types: selectedTypes.join(","),
      limit: "200"
    });

    const { value } = await api(`/api/objects/search?${qs.toString()}`);
    clearElement(searchResults);

    if (!value.length) {
      renderError(searchResults, "Aucun resultat.");
      return;
    }

    value.forEach((item) => {
      const key = `${item.objectKind}:${item.id}`;
      searchResults.appendChild(
        makeResultItem({
          name: item.name,
          type: `${objectLabel(item.objectKind)} / ${item.entityType || "Unknown"}`,
          desc: item.description || "Description non disponible",
          isActive: activeObjectKey === key,
          onClick: async () => {
            await loadObjectDetails(item.objectKind, item.id);
          }
        })
      );
    });
  } catch (err) {
    renderError(searchResults, err.message);
  }
}

async function loadScenario4Evidence() {
  evidenceBox.textContent = "Chargement de la preuve...";
  try {
    const data = await api("/api/scenario4/evidence");
    const checks = data.personaChecks || {};
    const lines = [
      `Fichier JSON: ${data.files && data.files.json ? "OK" : "absent"}`,
      `Fichier MD: ${data.files && data.files.md ? "OK" : "absent"}`,
      `cdo: ${checks.cdo ? "mentionne" : "non trouve"}`,
      `financeowner: ${checks.financeowner ? "mentionne" : "non trouve"}`,
      `dq.lead: ${checks["dq.lead"] ? "mentionne" : "non trouve"}`,
      `dpo: ${checks.dpo ? "mentionne" : "non trouve"}`
    ];

    evidenceBox.innerHTML = "";
    const ul = document.createElement("ul");
    ul.className = "scenario-steps";
    lines.forEach((line) => {
      const li = document.createElement("li");
      li.textContent = line;
      ul.appendChild(li);
    });
    evidenceBox.appendChild(ul);

    if (Array.isArray(data.mdPreview) && data.mdPreview.length) {
      const p = document.createElement("p");
      p.className = "hint";
      p.textContent = `Apercu preuve: ${data.mdPreview.slice(0, 2).join(" | ")}`;
      evidenceBox.appendChild(p);
    }
  } catch (err) {
    evidenceBox.textContent = `Erreur: ${err.message}`;
  }
}

async function loadScenariosFromConfig() {
  const config = await api("/api/scenarios/config");
  const rawScenarios = config.scenarios || {};

  scenarioModels = {
    explorer: {
      id: "explorer",
      title: "Explorateur libre",
      objective: "Mode generique pour tout besoin business hors scenario predefini.",
      steps: [
        "Saisir une recherche libre dans le catalogue.",
        "Explorer Data Products et assets lies.",
        "Utiliser les preuves si necessaire."
      ],
      say: "Je peux couvrir des cas metier non prevus initialement.",
      backup: "Revenir a un scenario configure",
      presets: [],
      focus: "search"
    }
  };

  Object.keys(rawScenarios).forEach((id) => {
    scenarioModels[id] = createScenarioModel(id, rawScenarios[id]);
  });

  renderScenarioButtons();
}

searchForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const query = searchInput.value.trim();
  if (!query) {
    return;
  }
  await runSearch(query);
});

objectFilters.addEventListener("change", async () => {
  const query = searchInput.value.trim();
  if (!query) {
    return;
  }
  await runSearch(query);
});

loadEvidenceBtn.addEventListener("click", async () => {
  await loadScenario4Evidence();
});

refreshBtn.addEventListener("click", async () => {
  await Promise.all([loadOverview(), loadDataProducts(), loadReadiness()]);
  const model = scenarioModels[activeScenarioId];
  if (model && model.focus === "evidence") {
    await loadScenario4Evidence();
  }

  const query = searchInput.value.trim();
  if (query) {
    await runSearch(query);
  }
});

(async function init() {
  await loadScenariosFromConfig();
  await Promise.all([loadOverview(), loadDataProducts(), loadReadiness()]);
  await switchScenario("explorer");
  searchInput.value = "Profitability Net Profit Margin";
  await runSearch(searchInput.value);
})();
