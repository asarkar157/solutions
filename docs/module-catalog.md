---
layout: default
title: Module Catalog
nav_order: 2
permalink: module-catalog/
---

<link rel="stylesheet" href="{{ '/assets/css/module-catalog.css' | relative_url }}">

<div id="catalog-app">

  <div class="catalog-hero">
    <h1>Module Catalog</h1>
    <p class="catalog-subtitle">Discover, explore, and compose production-ready Terraform modules for AI Operations. Filter by tag, copy the source URL, and wire modules into your IaC root.</p>
  </div>

  <!-- Search + Filter Bar -->
  <div class="catalog-toolbar">
    <div class="catalog-search">
      <svg class="search-icon" viewBox="0 0 20 20" fill="currentColor" width="18" height="18"><path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd"/></svg>
      <input type="text" id="module-search" placeholder="Search modules…" autocomplete="off">
    </div>
    <div class="tag-typeahead">
      <div class="tag-input-container">
        <input type="text" id="tag-input" placeholder="Filter by tags (e.g. aws, sre)…" autocomplete="off">
        <div id="tag-dropdown" class="tag-dropdown hidden"></div>
      </div>
      <div class="active-tags" id="active-tags"></div>
    </div>
  </div>

  <!-- Layer sections -->
  <div id="layer-0" class="catalog-layer">
    <div class="layer-header"><span class="layer-badge l0">Layer 0</span> Foundation</div>
    <div class="module-grid" id="grid-layer-0"></div>
  </div>
  <div id="layer-1" class="catalog-layer">
    <div class="layer-header"><span class="layer-badge l1">Layer 1</span> Integrations</div>
    <div class="module-grid" id="grid-layer-1"></div>
  </div>
  <div id="layer-2" class="catalog-layer">
    <div class="layer-header"><span class="layer-badge l2">Layer 2</span> Agents</div>
    <div class="module-grid" id="grid-layer-2"></div>
  </div>

  <div id="no-results" class="no-results" style="display:none">
    <p>No modules match your filters. Try removing a tag or clearing the search.</p>
  </div>

</div>

<script src="{{ '/assets/js/module-data.js' | relative_url }}"></script>
<script src="{{ '/assets/js/module-catalog.js' | relative_url }}"></script>
