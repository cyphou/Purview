const searchForm = document.getElementById("searchForm");
const searchInput = document.getElementById("searchInput");
const searchResults = document.getElementById("searchResults");
const governedResults = document.getElementById("governedResults");
const objectFilters = document.getElementById("objectFilters");
const discoveryTree = document.getElementById("discoveryTree");

const refreshBtn = document.getElementById("refreshBtn");

const selectedObjectHint = document.getElementById("selectedObjectHint");
const selectedObjectCard = document.getElementById("selectedObjectCard");
const lineageBox = document.getElementById("lineageBox");

const template = document.getElementById("resultItemTemplate");

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
    selectedObjectCard.innerHTML = `<p class="error">Erreur: ${err.message}</p>`;
    renderError(governedResults, err.message);
    lineageBox.innerHTML = `<p class="error">Erreur lineage: ${err.message}</p>`;
  }
}

function normalizeGroupObject(item) {
  if (!item) {
    return null;
  }

  if (item.objectKind) {
    return item;
  }

  return {
    objectKind: "dataProduct",
    id: item.id,
    name: item.name,
    description: item.description || "",
    entityType: item.status || "DataProduct"
  };
}

function createTreeSection(title, items, emptyText) {
  const details = document.createElement("details");
  details.className = "tree-section";
  details.open = true;

  const summary = document.createElement("summary");
  summary.textContent = `${title} (${items.length})`;
  details.appendChild(summary);

  const list = document.createElement("ul");
  list.className = "tree-list";

  if (!items.length) {
    const li = document.createElement("li");
    li.className = "hint";
    li.textContent = emptyText;
    list.appendChild(li);
  } else {
    items.forEach((raw) => {
      const item = normalizeGroupObject(raw);
      if (!item) {
        return;
      }

      const li = document.createElement("li");
      const button = document.createElement("button");
      button.type = "button";
      button.className = "tree-item";
      button.textContent = item.name || "(sans nom)";
      button.addEventListener("click", async () => {
        await loadObjectDetails(item.objectKind, item.id);
      });
      li.appendChild(button);
      list.appendChild(li);
    });
  }

  details.appendChild(list);
  return details;
}

async function loadDiscoveryTree() {
  discoveryTree.innerHTML = "<p>Chargement arbre...</p>";

  try {
    const [dataProductsData, glossaryData, assetsData] = await Promise.all([
      api("/api/data-products"),
      api("/api/objects/search?query=&types=businessTerm,businessDomain&limit=500"),
      api("/api/objects/search?query=&types=dataAsset,dataQuality&limit=500")
    ]);

    const dataProducts = Array.isArray(dataProductsData.value) ? dataProductsData.value : [];
    const glossary = Array.isArray(glossaryData.value) ? glossaryData.value : [];
    const assets = Array.isArray(assetsData.value) ? assetsData.value : [];

    const terms = glossary.filter((item) => item.objectKind === "businessTerm");
    const domains = glossary.filter((item) => item.objectKind === "businessDomain");
    const dataAssets = assets.filter((item) => item.objectKind === "dataAsset");
    const dq = assets.filter((item) => item.objectKind === "dataQuality");

    clearElement(discoveryTree);
    discoveryTree.appendChild(createTreeSection("Data Products", dataProducts, "Aucun data product"));
    discoveryTree.appendChild(createTreeSection("Glossary Terms", terms, "Aucun terme"));
    discoveryTree.appendChild(createTreeSection("Business Domains", domains, "Aucun domaine"));
    discoveryTree.appendChild(createTreeSection("Data Assets", dataAssets, "Aucun asset"));
    discoveryTree.appendChild(createTreeSection("Data Quality", dq, "Aucun indicateur DQ"));
  } catch (err) {
    discoveryTree.innerHTML = `<p class="error">Erreur: ${err.message}</p>`;
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

searchForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const query = searchInput.value.trim();
  await runSearch(query);
});

objectFilters.addEventListener("change", async () => {
  const query = searchInput.value.trim();
  await runSearch(query);
});

refreshBtn.addEventListener("click", async () => {
  await Promise.all([loadDiscoveryTree(), runSearch(searchInput.value.trim())]);
});

(async function init() {
  await Promise.all([loadDiscoveryTree(), runSearch("")]);
})();
