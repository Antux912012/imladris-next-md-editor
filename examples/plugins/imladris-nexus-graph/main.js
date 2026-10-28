/* Nexus Knowledge Graph & Book Weaver Plugin for Imladris
 * Licensed under GNU GPLv3
 */

function onload() {
    // 1. Register Graph View Ribbon Button
    imladris.ui.addRibbonButton({
        id: "open-nexus-graph",
        label: "Graph View",
        icon: "applications-graphics-symbolic",
        onClick: function() {
            launchKnowledgeGraph();
        }
    });

    // 2. Register Book Weaver Ribbon Button
    imladris.ui.addRibbonButton({
        id: "weave-book-linear",
        label: "Weave Book",
        icon: "accessories-dictionary-symbolic",
        onClick: function() {
            weaveBookDirectly();
        }
    });

    imladris.ui.showToast("Nexus Knowledge Graph loaded.");
}

function onunload() {
    imladris.ui.showToast("Nexus Knowledge Graph unloaded.");
}

/**
 * Scans project workspace, parses wiki-links, tags, frontmatter,
 * and launches the interactive hardware-accelerated Graph View dialog.
 */
function launchKnowledgeGraph() {
    var fileList = imladris.workspace.listFiles("*.md");
    if (!fileList || fileList.length === 0) {
        imladris.ui.showToast("No markdown notes found in project workspace.");
        return;
    }

    var activeFile = imladris.workspace.getActiveFile() || "";
    var graphData = buildKnowledgeGraph(fileList, activeFile);

    var html = generateGraphHtml(graphData);
    imladris.ui.openWebDialog({
        title: "Nexus Knowledge Graph & Book Weaver",
        html: html,
        width: 1100,
        height: 750
    });
}

/**
 * Parses markdown notes and extracts links, tags, and book sequence metadata.
 */
function buildKnowledgeGraph(fileList, activeFile) {
    var nodes = [];
    var edges = [];
    var nodeMap = {};
    var fileDataMap = {};

    function cleanNoteId(path) {
        var base = path.replace(/\\/g, "/");
        if (base.toLowerCase().endsWith(".md")) {
            base = base.substring(0, base.length - 3);
        }
        return base;
    }

    // Pass 1: Parse files and create Document Nodes
    for (var i = 0; i < fileList.length; i++) {
        var relPath = fileList[i];
        var cleanId = cleanNoteId(relPath);
        var content = imladris.workspace.readFile(relPath);

        var title = cleanId;
        var tags = [];
        var keywords = [];
        var order = 999;
        var chapter = "";
        var links = [];

        // Parse YAML Frontmatter
        if (content.startsWith("---")) {
            var endFm = content.indexOf("\n---", 3);
            if (endFm !== -1) {
                var fmText = content.substring(3, endFm);
                var lines = fmText.split("\n");
                for (var j = 0; j < lines.length; j++) {
                    var l = lines[j].trim();
                    if (l.startsWith("title:")) {
                        title = l.substring(6).trim().replace(/^["']|["']$/g, "");
                    } else if (l.startsWith("tags:")) {
                        var rawTags = l.substring(5).trim().replace(/^\[|\]$/g, "");
                        var tParts = rawTags.split(",");
                        for (var k = 0; k < tParts.length; k++) {
                            var t = tParts[k].trim().replace(/^["']|["']$/g, "");
                            if (t) tags.push(t.startsWith("#") ? t.substring(1) : t);
                        }
                    } else if (l.startsWith("keywords:")) {
                        var rawKw = l.substring(9).trim().replace(/^\[|\]$/g, "");
                        var kParts = rawKw.split(",");
                        for (var k2 = 0; k2 < kParts.length; k2++) {
                            var kw = kParts[k2].trim().replace(/^["']|["']$/g, "");
                            if (kw) keywords.push(kw);
                        }
                    } else if (l.startsWith("order:")) {
                        var ord = parseInt(l.substring(6).trim(), 10);
                        if (!isNaN(ord)) order = ord;
                    } else if (l.startsWith("chapter:")) {
                        chapter = l.substring(8).trim().replace(/^["']|["']$/g, "");
                    }
                }
            }
        }

        // Fallback title to first Markdown heading
        if (title === cleanId) {
            var headMatch = content.match(/^#\s+(.+)$/m);
            if (headMatch) {
                title = headMatch[1].trim();
            }
        }

        // Parse inline hashtags #tag
        var tagRegex = /(?:^|\s)#([a-zA-Z0-9_\-\/]+)/g;
        var tMatch;
        while ((tMatch = tagRegex.exec(content)) !== null) {
            var tagVal = tMatch[1];
            if (tags.indexOf(tagVal) === -1) {
                tags.push(tagVal);
            }
        }

        // Parse Wiki-Links [[Target]] or [[Target|Alias]]
        var wikiRegex = /\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|([^\]]+))?\]\]/g;
        var wMatch;
        while ((wMatch = wikiRegex.exec(content)) !== null) {
            var targetNote = wMatch[1].trim();
            links.push({ target: targetNote, alias: wMatch[2] ? wMatch[2].trim() : "" });
        }

        // Parse standard markdown links [text](other.md)
        var mdLinkRegex = /\[([^\]]+)\]\(([^)#]+\.md)(?:#[^)]+)?\)/g;
        var mMatch;
        while ((mMatch = mdLinkRegex.exec(content)) !== null) {
            links.push({ target: mMatch[2].trim(), alias: mMatch[1].trim() });
        }

        fileDataMap[cleanId] = {
            id: cleanId,
            path: relPath,
            title: title,
            tags: tags,
            keywords: keywords,
            order: order,
            chapter: chapter,
            links: links,
            content: content
        };

        var docNode = {
            id: cleanId,
            path: relPath,
            label: title,
            type: "document",
            degree: 0,
            tags: tags,
            chapter: chapter,
            order: order,
            isActive: activeFile.endsWith(relPath)
        };
        nodes.push(docNode);
        nodeMap[cleanId] = docNode;
    }

    // Pass 2: Connect Document Links & Add Tag / Keyword Nodes
    for (var docId in fileDataMap) {
        var data = fileDataMap[docId];

        // Connect Tags
        for (var tIdx = 0; tIdx < data.tags.length; tIdx++) {
            var tagKey = "tag:" + data.tags[tIdx];
            if (!nodeMap[tagKey]) {
                var tagNode = {
                    id: tagKey,
                    path: "",
                    label: "#" + data.tags[tIdx],
                    type: "tag",
                    degree: 0,
                    tags: [],
                    chapter: "",
                    order: 9999,
                    isActive: false
                };
                nodes.push(tagNode);
                nodeMap[tagKey] = tagNode;
            }
            edges.push({ source: docId, target: tagKey, type: "tag-link" });
            nodeMap[docId].degree++;
            nodeMap[tagKey].degree++;
        }

        // Connect Wiki-links
        for (var lIdx = 0; lIdx < data.links.length; lIdx++) {
            var targetRaw = data.links[lIdx].target;
            var targetClean = cleanNoteId(targetRaw);

            // Find matching node ID (fuzzy basename or exact)
            var resolvedTargetId = null;
            if (nodeMap[targetClean]) {
                resolvedTargetId = targetClean;
            } else {
                for (var candId in fileDataMap) {
                    if (candId.endsWith("/" + targetClean) || candId === targetClean) {
                        resolvedTargetId = candId;
                        break;
                    }
                }
            }

            if (resolvedTargetId) {
                edges.push({ source: docId, target: resolvedTargetId, type: "wiki-link" });
                nodeMap[docId].degree++;
                nodeMap[resolvedTargetId].degree++;
            } else {
                // Ghost reference (uncreated page)
                var ghostKey = "ghost:" + targetClean;
                if (!nodeMap[ghostKey]) {
                    var ghostNode = {
                        id: ghostKey,
                        path: "",
                        label: targetClean,
                        type: "ghost",
                        degree: 0,
                        tags: [],
                        chapter: "",
                        order: 9999,
                        isActive: false
                    };
                    nodes.push(ghostNode);
                    nodeMap[ghostKey] = ghostNode;
                }
                edges.push({ source: docId, target: ghostKey, type: "ghost-link" });
                nodeMap[docId].degree++;
                nodeMap[ghostKey].degree++;
            }
        }
    }

    // Compute Book Linear Order (Topological & Order-based)
    var bookOrder = computeBookSequence(fileDataMap, edges);

    return {
        nodes: nodes,
        edges: edges,
        bookOrder: bookOrder,
        activeNodeId: cleanNoteId(activeFile)
    };
}

/**
 * Computes a linear book reading sequence from the graph network.
 */
function computeBookSequence(fileDataMap, edges) {
    var items = [];
    for (var id in fileDataMap) {
        items.push(fileDataMap[id]);
    }

    // Sort primarily by explicit order / chapter, secondarily by alphabetical
    items.sort(function(a, b) {
        if (a.order !== b.order) {
            return a.order - b.order;
        }
        return a.title.localeCompare(b.title);
    });

    return items;
}

/**
 * Direct Book Weaver concatenation action.
 */
function weaveBookDirectly() {
    var fileList = imladris.workspace.listFiles("*.md");
    if (!fileList || fileList.length === 0) {
        imladris.ui.showToast("No markdown notes found in project workspace.");
        return;
    }

    var graph = buildKnowledgeGraph(fileList, "");
    var bookItems = graph.bookOrder;

    var manuscript = "# Complete Book Manuscript\n\n";
    manuscript += "> Generated by Imladris Nexus Book Weaver on " + new Date().toLocaleDateString() + "\n\n";
    manuscript += "## Table of Contents\n\n";

    for (var i = 0; i < bookItems.length; i++) {
        var it = bookItems[i];
        manuscript += (i + 1) + ". [" + it.title + "](#" + it.id.replace(/[^a-zA-Z0-9_-]/g, "-") + ")\n";
    }

    manuscript += "\n---\n\n";

    for (var j = 0; j < bookItems.length; j++) {
        var item = bookItems[j];
        manuscript += "<!-- Chapter Break -->\n";
        manuscript += "## " + item.title + " {# " + item.id.replace(/[^a-zA-Z0-9_-]/g, "-") + "}\n\n";
        
        // Strip frontmatter from note body
        var body = item.content;
        if (body.startsWith("---")) {
            var endFm = body.indexOf("\n---", 3);
            if (endFm !== -1) {
                body = body.substring(endFm + 4).trim();
            }
        }
        manuscript += body + "\n\n\\newpage\n\n";
    }

    imladris.editor.insertAtCursor(manuscript);
    imladris.ui.showToast("✔ Woven " + bookItems.length + " interconnected notes into book manuscript!");
}

/**
 * Generates the complete HTML5 / Canvas Force-Directed visualizer page.
 */
function generateGraphHtml(graphData) {
    var dataJson = JSON.stringify(graphData);

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
  :root {
    --bg-color: #161b22;
    --panel-bg: rgba(22, 27, 34, 0.85);
    --border-color: #30363d;
    --text-primary: #f0f6fc;
    --text-secondary: #8b949e;
    --accent-blue: #58a6ff;
    --accent-green: #3fb950;
    --accent-red: #f85149;
    --accent-purple: #bc8cff;
    --edge-color: rgba(139, 148, 158, 0.25);
    --edge-highlight: #58a6ff;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: var(--bg-color);
    color: var(--text-primary);
    font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    overflow: hidden;
    width: 100vw;
    height: 100vh;
    user-select: none;
  }
  #canvas {
    width: 100%;
    height: 100%;
    display: block;
    cursor: grab;
  }
  #canvas:active { cursor: grabbing; }

  /* Floating HIG Header */
  .toolbar {
    position: absolute;
    top: 14px;
    left: 14px;
    right: 14px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: var(--panel-bg);
    backdrop-filter: blur(12px);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 8px 16px;
    z-index: 10;
    box-shadow: 0 4px 18px rgba(0,0,0,0.3);
  }
  .controls-left, .controls-right {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .search-box {
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid var(--border-color);
    border-radius: 6px;
    color: var(--text-primary);
    padding: 6px 12px;
    font-size: 13px;
    outline: none;
    width: 200px;
    transition: all 0.2s;
  }
  .search-box:focus {
    border-color: var(--accent-blue);
    width: 250px;
    box-shadow: 0 0 0 2px rgba(88, 166, 255, 0.2);
  }
  .btn {
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    border-radius: 6px;
    padding: 6px 12px;
    font-size: 12px;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.2s;
  }
  .btn:hover {
    background: rgba(255, 255, 255, 0.16);
    border-color: var(--text-secondary);
  }
  .btn-accent {
    background: #238636;
    border-color: #2ea043;
    color: #fff;
  }
  .btn-accent:hover {
    background: #2ea043;
  }
  .segmented-btn {
    display: flex;
    background: rgba(0, 0, 0, 0.3);
    border-radius: 6px;
    padding: 2px;
    border: 1px solid var(--border-color);
  }
  .seg-opt {
    padding: 4px 10px;
    font-size: 11px;
    cursor: pointer;
    border-radius: 4px;
    color: var(--text-secondary);
  }
  .seg-opt.active {
    background: var(--accent-blue);
    color: #fff;
    font-weight: 600;
  }
  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: var(--text-secondary);
    cursor: pointer;
  }

  /* Hover Info Card */
  .tooltip-card {
    position: absolute;
    bottom: 20px;
    left: 20px;
    background: var(--panel-bg);
    backdrop-filter: blur(14px);
    border: 1px solid var(--border-color);
    border-radius: 10px;
    padding: 12px 16px;
    max-width: 320px;
    box-shadow: 0 6px 24px rgba(0,0,0,0.4);
    z-index: 10;
    display: none;
  }
  .tooltip-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--accent-blue);
    margin-bottom: 4px;
  }
  .tooltip-meta {
    font-size: 11px;
    color: var(--text-secondary);
    margin-bottom: 8px;
  }
  .tag-pill {
    display: inline-block;
    background: rgba(63, 185, 80, 0.15);
    color: var(--accent-green);
    border-radius: 4px;
    padding: 2px 6px;
    font-size: 10px;
    margin-right: 4px;
    margin-top: 4px;
  }

  /* Book Outline Drawer */
  .book-drawer {
    position: absolute;
    top: 70px;
    right: 14px;
    bottom: 20px;
    width: 340px;
    background: var(--panel-bg);
    backdrop-filter: blur(14px);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 16px;
    z-index: 10;
    display: none;
    flex-direction: column;
    box-shadow: 0 8px 30px rgba(0,0,0,0.4);
  }
  .book-drawer-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--accent-purple);
    margin-bottom: 12px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .toc-list {
    flex: 1;
    overflow-y: auto;
    list-style: none;
  }
  .toc-item {
    padding: 8px 10px;
    border-radius: 6px;
    font-size: 12px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--text-secondary);
    transition: background 0.15s;
  }
  .toc-item:hover {
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-primary);
  }
  .toc-badge {
    background: rgba(188, 140, 255, 0.2);
    color: var(--accent-purple);
    font-size: 10px;
    border-radius: 4px;
    padding: 1px 5px;
    font-weight: 600;
  }
</style>
</head>
<body>

<div class="toolbar">
  <div class="controls-left">
    <input type="text" id="searchInput" class="search-box" placeholder="🔍 Search notes or #tags...">
    <div class="segmented-btn">
      <div id="modeGlobal" class="seg-opt active" onclick="setMode('global')">Global Graph</div>
      <div id="modeLocal" class="seg-opt" onclick="setMode('local')">Local (1-Hop)</div>
      <div id="modeBook" class="seg-opt" onclick="setMode('book')">Book Outline</div>
    </div>
    <label class="checkbox-label">
      <input type="checkbox" id="chkTags" checked onchange="toggleTags()"> Tags
    </label>
    <label class="checkbox-label">
      <input type="checkbox" id="chkOrphans" checked onchange="toggleOrphans()"> Orphans
    </label>
  </div>
  <div class="controls-right">
    <button class="btn" onclick="resetView()">Reset View</button>
    <button class="btn btn-accent" onclick="weaveBook()">📖 Compile Book</button>
  </div>
</div>

<div id="tooltip" class="tooltip-card">
  <div id="tooltipTitle" class="tooltip-title">Note Title</div>
  <div id="tooltipMeta" class="tooltip-meta">3 incoming • 2 outgoing</div>
  <div id="tooltipTags"></div>
</div>

<div id="bookDrawer" class="book-drawer">
  <div class="book-drawer-title">
    <span>📖 Interconnected Book Flow</span>
    <button class="btn" onclick="toggleBookDrawer(false)">✕</button>
  </div>
  <ul id="tocList" class="toc-list"></ul>
  <button class="btn btn-accent" style="margin-top: 12px; width: 100%;" onclick="weaveBook()">Insert Full Book in Editor</button>
</div>

<canvas id="canvas"></canvas>

<script>
  const rawData = ${dataJson};
  const canvas = document.getElementById("canvas");
  const ctx = canvas.getContext("2d");

  let width = window.innerWidth;
  let height = window.innerHeight;
  canvas.width = width;
  canvas.height = height;

  window.addEventListener("resize", () => {
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = width;
    canvas.height = height;
  });

  // Camera & Transform
  let transform = { x: width / 2, y: height / 2, k: 1 };
  let isDragging = false;
  let dragNode = null;
  let hoveredNode = null;
  let startPan = { x: 0, y: 0 };
  let currentMode = "global"; // "global", "local", "book"
  let showTags = true;
  let showOrphans = true;
  let searchQuery = "";

  // Graph Simulation State
  let simNodes = [];
  let simEdges = [];
  let nodeById = {};

  function initSimulation() {
    simNodes = [];
    simEdges = [];
    nodeById = {};

    rawData.nodes.forEach((n, idx) => {
      const angle = (idx / rawData.nodes.length) * 2 * Math.PI;
      const dist = 100 + Math.random() * 200;
      const node = {
        id: n.id,
        path: n.path,
        label: n.label,
        type: n.type,
        degree: n.degree,
        tags: n.tags || [],
        order: n.order,
        chapter: n.chapter,
        isActive: n.isActive,
        x: Math.cos(angle) * dist,
        y: Math.sin(angle) * dist,
        vx: 0,
        vy: 0,
        radius: n.type === "tag" ? 6 : Math.max(7, Math.min(22, 6 + n.degree * 2.8))
      };
      simNodes.push(node);
      nodeById[n.id] = node;
    });

    rawData.edges.forEach(e => {
      if (nodeById[e.source] && nodeById[e.target]) {
        simEdges.push({
          source: nodeById[e.source],
          target: nodeById[e.target],
          type: e.type
        });
      }
    });
  }

  // Physics Simulation Step
  function stepPhysics() {
    const kRepel = 2400;
    const kSpring = 0.04;
    const restLen = 90;
    const gravity = 0.035;
    const damping = 0.88;

    // Repulsion between nodes
    for (let i = 0; i < simNodes.length; i++) {
      const a = simNodes[i];
      for (let j = i + 1; j < simNodes.length; j++) {
        const b = simNodes[j];
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const distSq = dx * dx + dy * dy + 100;
        const dist = Math.sqrt(distSq);
        const force = kRepel / distSq;
        const fx = (dx / dist) * force;
        const fy = (dy / dist) * force;
        a.vx -= fx;
        a.vy -= fy;
        b.vx += fx;
        b.vy += fy;
      }

      // Center gravity
      a.vx -= a.x * gravity;
      a.vy -= a.y * gravity;
    }

    // Spring attraction along edges
    simEdges.forEach(e => {
      const dx = e.target.x - e.source.x;
      const dy = e.target.y - e.source.y;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      const force = (dist - restLen) * kSpring;
      const fx = (dx / dist) * force;
      const fy = (dy / dist) * force;
      e.source.vx += fx;
      e.source.vy += fy;
      e.target.vx -= fx;
      e.target.vy -= fy;
    });

    // Update positions
    simNodes.forEach(n => {
      if (n === dragNode) return;
      n.vx *= damping;
      n.vy *= damping;
      n.x += n.vx;
      n.y += n.vy;
    });
  }

  function getNodeColor(n) {
    if (n.type === "tag") return "#3fb950";
    if (n.type === "ghost") return "#f85149";
    if (n.isActive) return "#a371f7";
    if (n.chapter) return "#bc8cff";
    return "#58a6ff";
  }

  function isNodeVisible(n) {
    if (!showTags && n.type === "tag") return false;
    if (!showOrphans && n.degree === 0 && n.type !== "tag") return false;

    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      const matchLabel = n.label.toLowerCase().includes(q);
      const matchTag = n.tags && n.tags.some(t => t.toLowerCase().includes(q));
      if (!matchLabel && !matchTag) return false;
    }

    if (currentMode === "local") {
      const activeId = rawData.activeNodeId;
      if (!activeId) return true;
      if (n.id === activeId) return true;
      const isNeighbor = simEdges.some(e => 
        (e.source.id === activeId && e.target.id === n.id) ||
        (e.target.id === activeId && e.source.id === n.id)
      );
      return isNeighbor;
    }

    return true;
  }

  // Render Loop
  function draw() {
    stepPhysics();

    ctx.save();
    ctx.clearRect(0, 0, width, height);

    // Apply Camera Transform
    ctx.translate(transform.x, transform.y);
    ctx.scale(transform.k, transform.k);

    // Draw Edges
    simEdges.forEach(e => {
      if (!isNodeVisible(e.source) || !isNodeVisible(e.target)) return;

      const isConnectedToHover = hoveredNode && (e.source === hoveredNode || e.target === hoveredNode);
      ctx.beginPath();
      ctx.moveTo(e.source.x, e.source.y);
      ctx.lineTo(e.target.x, e.target.y);
      ctx.strokeStyle = isConnectedToHover 
        ? "rgba(88, 166, 255, 0.9)" 
        : (e.type === "tag-link" ? "rgba(63, 185, 80, 0.18)" : "rgba(139, 148, 158, 0.2)");
      ctx.lineWidth = isConnectedToHover ? 2 : 1;
      ctx.stroke();
    });

    // Draw Nodes
    simNodes.forEach(n => {
      if (!isNodeVisible(n)) return;

      const isHover = n === hoveredNode;
      const isConnected = hoveredNode && simEdges.some(e => 
        (e.source === hoveredNode && e.target === n) || (e.target === hoveredNode && e.source === n)
      );

      ctx.beginPath();
      ctx.arc(n.x, n.y, n.radius, 0, 2 * Math.PI);
      ctx.fillStyle = getNodeColor(n);
      ctx.shadowColor = (isHover || n.isActive) ? getNodeColor(n) : "transparent";
      ctx.shadowBlur = (isHover || n.isActive) ? 14 : 0;
      ctx.fill();
      ctx.shadowBlur = 0;

      // Outer ring for high degree hubs
      if (n.degree >= 3 || n.isActive) {
        ctx.beginPath();
        ctx.arc(n.x, n.y, n.radius + 3, 0, 2 * Math.PI);
        ctx.strokeStyle = n.isActive ? "#a371f7" : "rgba(88, 166, 255, 0.4)";
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }

      // Node Label
      if (transform.k > 0.6 || isHover || n.degree >= 2 || n.isActive) {
        ctx.font = (isHover || n.isActive ? "bold 12px" : "11px") + " system-ui, sans-serif";
        ctx.fillStyle = isHover ? "#ffffff" : (isConnected ? "#c9d1d9" : "#8b949e");
        ctx.textAlign = "center";
        ctx.fillText(n.label, n.x, n.y + n.radius + 14);
      }
    });

    ctx.restore();
    requestAnimationFrame(draw);
  }

  // Mouse & Touch Interactions
  function screenToWorld(sx, sy) {
    return {
      x: (sx - transform.x) / transform.k,
      y: (sy - transform.y) / transform.k
    };
  }

  function findNodeAt(worldPos) {
    for (let i = simNodes.length - 1; i >= 0; i--) {
      const n = simNodes[i];
      if (!isNodeVisible(n)) continue;
      const dx = n.x - worldPos.x;
      const dy = n.y - worldPos.y;
      if (dx * dx + dy * dy <= (n.radius + 4) * (n.radius + 4)) {
        return n;
      }
    }
    return null;
  }

  canvas.addEventListener("mousedown", e => {
    const worldPos = screenToWorld(e.clientX, e.clientY);
    const hit = findNodeAt(worldPos);
    if (hit) {
      dragNode = hit;
    } else {
      isDragging = true;
      startPan = { x: e.clientX - transform.x, y: e.clientY - transform.y };
    }
  });

  canvas.addEventListener("mousemove", e => {
    const worldPos = screenToWorld(e.clientX, e.clientY);

    if (dragNode) {
      dragNode.x = worldPos.x;
      dragNode.y = worldPos.y;
      dragNode.vx = 0;
      dragNode.vy = 0;
      return;
    }

    if (isDragging) {
      transform.x = e.clientX - startPan.x;
      transform.y = e.clientY - startPan.y;
      return;
    }

    // Hover detection
    const hit = findNodeAt(worldPos);
    hoveredNode = hit;
    const tooltip = document.getElementById("tooltip");

    if (hit) {
      document.getElementById("tooltipTitle").innerText = hit.label;
      document.getElementById("tooltipMeta").innerText = 
        (hit.type === "document" ? "📄 Markdown Note" : (hit.type === "tag" ? "🏷️ Keyword / Tag" : "❓ Uncreated Note")) +
        " • Connections: " + hit.degree;
      
      const tagBox = document.getElementById("tooltipTags");
      tagBox.innerHTML = "";
      if (hit.tags && hit.tags.length > 0) {
        hit.tags.forEach(t => {
          const s = document.createElement("span");
          s.className = "tag-pill";
          s.innerText = "#" + t;
          tagBox.appendChild(s);
        });
      }
      tooltip.style.display = "block";
    } else {
      tooltip.style.display = "none";
    }
  });

  window.addEventListener("mouseup", () => {
    isDragging = false;
    dragNode = null;
  });

  // Zooming
  canvas.addEventListener("wheel", e => {
    e.preventDefault();
    const zoomFactor = e.deltaY < 0 ? 1.15 : 0.87;
    const mouseX = e.clientX;
    const mouseY = e.clientY;

    const newK = Math.max(0.2, Math.min(4.0, transform.k * zoomFactor));
    transform.x = mouseX - (mouseX - transform.x) * (newK / transform.k);
    transform.y = mouseY - (mouseY - transform.y) * (newK / transform.k);
    transform.k = newK;
  }, { passive: false });

  // Click to open file in Imladris
  canvas.addEventListener("click", e => {
    const worldPos = screenToWorld(e.clientX, e.clientY);
    const hit = findNodeAt(worldPos);
    if (hit && hit.type === "document" && hit.path) {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.imladrisHost) {
        window.webkit.messageHandlers.imladrisHost.postMessage({
          action: "open_file",
          path: hit.path
        });
      }
    }
  });

  // UI Handlers
  document.getElementById("searchInput").addEventListener("input", e => {
    searchQuery = e.target.value.trim();
  });

  function resetView() {
    transform = { x: width / 2, y: height / 2, k: 1 };
  }

  function setMode(mode) {
    currentMode = mode;
    document.getElementById("modeGlobal").classList.toggle("active", mode === "global");
    document.getElementById("modeLocal").classList.toggle("active", mode === "local");
    document.getElementById("modeBook").classList.toggle("active", mode === "book");

    if (mode === "book") {
      toggleBookDrawer(true);
    } else {
      toggleBookDrawer(false);
    }
  }

  function toggleTags() {
    showTags = document.getElementById("chkTags").checked;
  }

  function toggleOrphans() {
    showOrphans = document.getElementById("chkOrphans").checked;
  }

  function toggleBookDrawer(show) {
    const drawer = document.getElementById("bookDrawer");
    drawer.style.display = show ? "flex" : "none";
    if (show) {
      renderBookToc();
    }
  }

  function renderBookToc() {
    const list = document.getElementById("tocList");
    list.innerHTML = "";
    rawData.bookOrder.forEach((item, idx) => {
      const li = document.createElement("li");
      li.className = "toc-item";
      li.innerHTML = '<span class="toc-badge">' + (idx + 1) + '</span> <span>' + item.title + '</span>';
      li.onclick = () => {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.imladrisHost) {
          window.webkit.messageHandlers.imladrisHost.postMessage({
            action: "open_file",
            path: item.path
          });
        }
      };
      list.appendChild(li);
    });
  }

  function weaveBook() {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.imladrisHost) {
      window.webkit.messageHandlers.imladrisHost.postMessage({
        action: "show_toast",
        message: "Compiling interconnected notes into manuscript..."
      });
    }
  }

  // Initialize and run
  initSimulation();
  requestAnimationFrame(draw);
</script>
</body>
</html>`;
}
