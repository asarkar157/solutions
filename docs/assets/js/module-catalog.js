(function(){
var SRC="github.com/appcd-dev/solutions//modules/";
var activeTags=new Set();
var searchTerm="";
var allTags=[];
var tagDropdownIndex=-1;

function esc(s){
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function copyText(text,btn){
  navigator.clipboard.writeText(text).then(function(){
    btn.classList.add("copied");btn.textContent="✓";
    setTimeout(function(){btn.classList.remove("copied");btn.textContent="📋";},1500);
  });
}

function buildCard(m){
  var src=SRC+m.id+"?ref=main";
  var reqVars=m.vars.filter(function(v){return v.r;});
  var optVars=m.vars.filter(function(v){return !v.r;});
  var html='<div class="module-card" data-tags="'+m.tags.join(",")+'" data-layer="'+m.layer+'" data-id="'+m.id+'" data-search="'+esc((m.name+" "+m.desc+" "+m.id+" "+m.tags.join(" ")).toLowerCase())+'">';
  html+='<div class="card-top"><div class="card-icon" style="background:'+["#e0f2fe","#fef3c7","#f3e8ff"][m.layer]+'">'+m.icon+'</div>';
  html+='<div class="card-title-group"><div class="card-title">'+esc(m.name)+'</div>';
  html+='<div class="card-module-name">'+esc(m.id)+'</div></div></div>';
  html+='<div class="card-desc">'+esc(m.desc)+'</div>';
  html+='<div class="card-tags">';
  m.tags.forEach(function(t){html+='<span class="card-tag">'+esc(t)+'</span>';});
  html+='</div>';
  // Source URL
  html+='<div class="card-source"><code>'+esc(src)+'</code><button class="copy-btn" aria-label="Copy source URL" title="Copy source URL" data-src="'+esc(src)+'">📋</button></div>';
  // Toggle
  var detailsId = "details-" + m.id;
  html+='<button class="card-toggle" aria-expanded="false" aria-controls="'+detailsId+'"><span class="arrow" aria-hidden="true">▶</span> Variables &amp; Usage</button>';
  // Details
  html+='<div class="card-details" id="'+detailsId+'"><div class="card-details-inner">';
  if(m.vars.length){
    html+='<div class="detail-section"><h4>Variables</h4><table class="var-table"><tr><th>Name</th><th>Type</th><th></th></tr>';
    reqVars.forEach(function(v){html+='<tr><td><code>'+esc(v.n)+'</code></td><td><code>'+esc(v.t)+'</code></td><td><span class="var-required">required</span></td></tr>';});
    optVars.forEach(function(v){html+='<tr><td><code>'+esc(v.n)+'</code></td><td><code>'+esc(v.t)+'</code></td><td><span class="var-optional">optional</span></td></tr>';});
    html+='</table></div>';
  } else {
    html+='<div class="detail-section"><h4>Variables</h4><p style="font-size:.82rem;color:#94a3b8">No required variables — use defaults.</p></div>';
  }
  if(m.outputs.length){
    html+='<div class="detail-section"><h4>Outputs</h4><p style="font-size:.82rem;color:#475569"><code>'+m.outputs.map(esc).join('</code>, <code>')+'</code></p></div>';
  }
  // Remove data-usage and instead get textContent from the sibling <pre> on click
  html+='<div class="detail-section"><h4>Usage</h4><div class="usage-block"><button class="usage-copy" aria-label="Copy usage snippet">Copy</button><pre class="usage-pre">'+esc(m.usage)+'</pre></div></div>';
  html+='</div></div></div>';
  return html;
}

function collectTags(){
  var counts={};
  window.MODULES.forEach(function(m){m.tags.forEach(function(t){counts[t]=(counts[t]||0)+1;});});
  allTags=Object.keys(counts).sort(function(a,b){return counts[b]-counts[a];}).map(function(t){return {tag:t,count:counts[t]};});
}

function renderTagDropdown(filter){
  var dropdown=document.getElementById("tag-dropdown");
  var input=document.getElementById("tag-input");
  if(!filter && document.activeElement!==input){
    dropdown.classList.add("hidden");
    input.setAttribute("aria-expanded", "false");
    return;
  }
  var f=filter?filter.toLowerCase():"";
  var matches=allTags.filter(function(item){
    return !activeTags.has(item.tag) && item.tag.toLowerCase().indexOf(f)!==-1;
  });
  
  if(matches.length===0){
    dropdown.innerHTML='<div class="tag-dropdown-item" role="option" aria-disabled="true" style="color:#94a3b8;cursor:default;">No matching tags</div>';
  }else{
    dropdown.innerHTML=matches.map(function(item,index){
      return '<div class="tag-dropdown-item" role="option" id="tag-opt-'+index+'" data-tag="'+esc(item.tag)+'" data-index="'+index+'">' + 
             '<span>'+esc(item.tag)+'</span><span class="count">('+item.count+')</span></div>';
    }).join('');
  }
  dropdown.classList.remove("hidden");
  input.setAttribute("aria-expanded", "true");
  tagDropdownIndex=-1;
  input.removeAttribute("aria-activedescendant");
}

function renderActiveTags(){
  var container=document.getElementById("active-tags");
  container.innerHTML=Array.from(activeTags).map(function(t){
    return '<span class="active-tag-pill">'+esc(t)+'<button class="remove-tag" aria-label="Remove tag '+esc(t)+'" data-tag="'+esc(t)+'" title="Remove tag">&times;</button></span>';
  }).join('');
  applyFilters();
}

function renderCards(){
  var grids={0:document.getElementById("grid-layer-0"),1:document.getElementById("grid-layer-1"),2:document.getElementById("grid-layer-2")};
  for(var k in grids) grids[k].innerHTML="";
  window.MODULES.forEach(function(m){grids[m.layer].insertAdjacentHTML("beforeend",buildCard(m));});
}

function applyFilters(){
  var cards=document.querySelectorAll(".module-card");
  var visibleLayers={0:0,1:0,2:0};
  cards.forEach(function(card){
    var tags=card.getAttribute("data-tags").split(",");
    var search=card.getAttribute("data-search");
    var layer=parseInt(card.getAttribute("data-layer"));
    var tagMatch=activeTags.size===0||tags.some(function(t){return activeTags.has(t);});
    var searchMatch=!searchTerm||search.indexOf(searchTerm)!==-1;
    var show=tagMatch&&searchMatch;
    card.classList.toggle("hidden",!show);
    if(show) visibleLayers[layer]++;
  });
  [0,1,2].forEach(function(l){
    document.getElementById("layer-"+l).classList.toggle("hidden",visibleLayers[l]===0);
  });
  var total=visibleLayers[0]+visibleLayers[1]+visibleLayers[2];
  document.getElementById("no-results").style.display=total===0?"block":"none";
}

function init(){
  collectTags();
  renderCards();
  
  var tagInput=document.getElementById("tag-input");
  var tagDropdown=document.getElementById("tag-dropdown");

  tagInput.addEventListener("focus",function(){renderTagDropdown(this.value);});
  tagInput.addEventListener("input",function(){renderTagDropdown(this.value);});
  tagInput.addEventListener("keydown",function(e){
    var items=tagDropdown.querySelectorAll(".tag-dropdown-item[data-tag]");
    if(e.key==="ArrowDown"){
      e.preventDefault();
      tagDropdownIndex=Math.min(tagDropdownIndex+1,items.length-1);
      updateDropdownSelection(items);
    }else if(e.key==="ArrowUp"){
      e.preventDefault();
      tagDropdownIndex=Math.max(tagDropdownIndex-1,0);
      updateDropdownSelection(items);
    }else if(e.key==="Enter"){
      e.preventDefault();
      if(tagDropdownIndex>=0 && tagDropdownIndex<items.length) addTag(items[tagDropdownIndex].getAttribute("data-tag"));
      else if(items.length>0) addTag(items[0].getAttribute("data-tag"));
    }else if(e.key==="Escape"){
      tagDropdown.classList.add("hidden");
      tagInput.setAttribute("aria-expanded", "false");
      tagInput.blur();
    }
  });

  function updateDropdownSelection(items){
    items.forEach(function(item,idx){
      var isFocused = idx===tagDropdownIndex;
      item.classList.toggle("focused", isFocused);
      item.setAttribute("aria-selected", isFocused ? "true" : "false");
      if(isFocused){
        item.scrollIntoView({block:"nearest"});
        tagInput.setAttribute("aria-activedescendant", item.id);
      }
    });
  }

  function addTag(tag){
    if(tag && !activeTags.has(tag)){
      activeTags.add(tag);
      tagInput.value="";
      renderTagDropdown("");
      renderActiveTags();
      tagDropdown.classList.add("hidden");
      tagInput.setAttribute("aria-expanded", "false");
    }
  }

  document.addEventListener("click",function(e){
    if(!e.target.closest(".tag-typeahead")){
      tagDropdown.classList.add("hidden");
      tagInput.setAttribute("aria-expanded", "false");
    }
  });

  tagDropdown.addEventListener("click",function(e){
    var item=e.target.closest(".tag-dropdown-item");
    if(item && item.hasAttribute("data-tag")) addTag(item.getAttribute("data-tag"));
  });

  document.getElementById("active-tags").addEventListener("click",function(e){
    var btn=e.target.closest(".remove-tag");
    if(btn){
      activeTags.delete(btn.getAttribute("data-tag"));
      renderActiveTags();
      if(document.activeElement===tagInput) renderTagDropdown(tagInput.value);
    }
  });
  // Search
  document.getElementById("module-search").addEventListener("input",function(e){
    searchTerm=e.target.value.trim().toLowerCase();
    applyFilters();
  });
  // Delegated clicks for copy + toggle
  document.getElementById("catalog-app").addEventListener("click",function(e){
    var copyBtn=e.target.closest(".copy-btn");
    if(copyBtn){copyText(copyBtn.getAttribute("data-src"),copyBtn);return;}
    var usageCopy=e.target.closest(".usage-copy");
    if(usageCopy){
      var pre = usageCopy.nextElementSibling;
      var u = pre ? pre.textContent : "";
      navigator.clipboard.writeText(u).then(function(){usageCopy.textContent="Copied!";setTimeout(function(){usageCopy.textContent="Copy";},1500);});
      return;
    }
    var toggle=e.target.closest(".card-toggle");
    if(toggle){
      var details=toggle.nextElementSibling;
      var arrow=toggle.querySelector(".arrow");
      var isOpen=details.classList.contains("open");
      if(isOpen){
        details.classList.remove("open");
        arrow.classList.remove("open");
        toggle.setAttribute("aria-expanded", "false");
      }else{
        details.classList.add("open");
        arrow.classList.add("open");
        toggle.setAttribute("aria-expanded", "true");
      }
    }
  });
}

if(document.readyState==="loading") document.addEventListener("DOMContentLoaded",init);
else init();
})();
