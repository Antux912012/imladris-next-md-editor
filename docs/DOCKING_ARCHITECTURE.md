# Phase 1.1.3 RStudio 4-Quadrant Drag-and-Drop Docking System Architecture

To implement the **Phase 1.1.3 RStudio 4-Quadrant Drag-and-Drop Docking System** without causing editor re-mounts, losing undo/redo stacks, or dropping below 60 FPS during splitter dragging, the system decouples **Panel Registry State** from the **Layout / Split Engine**.

---

## 1. Component Hierarchy & Host Registry Strategy

The critical challenge in transitioning between **Apostrophe Mode** (single-pane) and **RStudio Mode** (4-quadrant) is keeping the core Editor instance alive in memory and widget tree so cursor state and history are preserved. We solve this using a **Host Registry / Widget Re-parenting Pattern**.

```
<WorkspaceLayoutProvider>                 // Global layout state & persistence (WorkspaceStateManager)
 └── <WorkbenchShell>                     // Switches between ApostropheShell & RStudioGrid
      ├── <TopRibbonBar />                // Context-aware toolbar + Layout Switcher
      ├── <PersistentPanelRegistry />     // Keeps Editor/Preview/Console instances alive across layouts
      └── <RStudioDockGrid>               // 2x2 Resizable Split Grid (Active in RStudio Mode)
           ├── <SplitAxis orientation="horizontal" ratio={colRatio}>
           │    ├── <SplitAxis orientation="vertical" ratio={leftRowRatio}>
           │    │    ├── <DockQuadrant id="Q1_TOP_LEFT" />      // Default: Source Editor
           │    │    └── <DockQuadrant id="Q2_BOTTOM_LEFT" />   // Default: Console / Terminal
           │    └── <SplitAxis orientation="vertical" ratio={rightRowRatio}>
           │         ├── <DockQuadrant id="Q3_TOP_RIGHT" />     // Default: Environment / TOC / Citations
           │         └── <DockQuadrant id="Q4_BOTTOM_RIGHT" />  // Default: Preview / Plots / Files
           └── <DragDropOverlay />        // Visual drop-zone indicator (Header / Center Body)
```

### Inside Each `<DockQuadrant/>`:

```
<DockQuadrant id="Q3_TOP_RIGHT">
 ├── <QuadrantHeader>
 │    ├── <DraggableTabList>              // Reorderable & cross-quadrant draggable tabs (Gtk.DragSource / DropTarget)
 │    │    ├── <DockTab id="environment" title="Environment" />
 │    │    ├── <DockTab id="outline" title="Outline" />
 │    │    └── <DockTab id="citations" title="Citations" />
 │    └── <QuadrantWindowControls>        // Minimize, Maximize, Restore buttons + contextual notebook controls
 └── <QuadrantViewport>                   // Host container where the active panel widget is mounted
```

---

## 2. State Schema & Data Structures

Defined in `src/core/layout/DockTypes.vala` and `src/services/WorkspaceStateManager.vala`:

- **`QuadrantId`:** `Q1_TOP_LEFT`, `Q2_BOTTOM_LEFT`, `Q3_TOP_RIGHT`, `Q4_BOTTOM_RIGHT`
- **`PanelId`:**
  - `source-editor`: `.Rmd`, `.Qmd`, `.ipynb` cells, or `.md` buffer
  - `live-preview`: Rendered HTML / Quarto / Notebook preview
  - `console`: R / Python / Jupyter kernel execution log & REPL (`In [n]:` / `Out [n]:`)
  - `terminal`: System shell
  - `environment`: Active dataframe / variable inspector
  - `outline`: Document AST Table of Contents
  - `citations`: BibTeX / CSL bibliography manager
  - `plots`: Rendered graphic outputs / zoomable figures
  - `files`: Project directory browser
  - `help`: Documentation viewer
- **`QuadrantSizeState`:** `NORMAL`, `MINIMIZED`, `MAXIMIZED`
- **`SplitterRatios`:**
  - `mainVertical`: Left column vs Right column (`0.15` to `0.85`, default `0.55`)
  - `leftHorizontal`: Q1 vs Q2 height ratio (`0.15` to `0.85`, default `0.68`)
  - `rightHorizontal`: Q3 vs Q4 height ratio (`0.15` to `0.85`, default `0.45`)

---

## 3. Drag-and-Drop Mechanics & State Transitions

| Interaction | Trigger | State Transition Logic |
| --- | --- | --- |
| **Intra-Quadrant Tab Reorder** | Dragging `<DockTab/>` horizontally within the same `<QuadrantHeader/>` | Splice `tabs` array of the target `QuadrantId` from `sourceIndex` to `destinationIndex`. Keep `activeTab` unchanged. |
| **Cross-Quadrant Tab Move** | Dragging `<DockTab/>` and dropping onto another quadrant's header or center viewport | 1. Remove `PanelId` from `sourceQuadrant.tabs`.<br>2. If `sourceQuadrant.activeTab == panelId`, fallback to `sourceQuadrant.tabs[0] ?? null`.<br>3. Insert/append `PanelId` into `targetQuadrant.tabs` and set `targetQuadrant.activeTab = panelId`. |
| **Empty Quadrant Auto-Collapse** | Last remaining tab is dragged out of a quadrant | Automatically set `sourceQuadrant.sizeState = MINIMIZED` so its sibling quadrant expands to `100%` of that column until a tab is dragged back into the collapsed dock bar. |

---

## 4. 60 FPS Splitter Resizing Engine

- Uses hardware-accelerated `Gtk.Paned` containers synchronized with clamped ratios $\in [0.15, 0.85]$ and a 4-way center crosshair drag controller (`Gtk.GestureDrag`) at the intersection of the vertical and horizontal splitters, allowing simultaneous diagonal resizing of `mainVertical`, `leftHorizontal`, and `rightHorizontal`.
- Persists `RStudioDockLayoutState` (ratios, quadrant tab assignments, active tabs, and size states) to `~/.config/imladris/dock-layout.json` on drag completion.

---

## 5. `.ipynb` Adaptation in RStudio Mode

1. **Quadrant 1 (`source-editor`):** Renders the notebook cell stack with inline "Run Cell (`Ctrl+Enter`)" and "Run All" actions in the quadrant toolbar.
2. **Quadrant 2 (`console`):** Streams cell execution `stdout`, `stderr`, and traceback logs sequentially with cell execution counters (`In [1]:`, `Out [1]:`).
3. **Quadrant 3 (`environment`):** Displays inspected variables/dataframes parsed from the execution state or notebook metadata alongside the Markdown header Outline.
4. **Quadrant 4 (`plots` / `live-preview`):** Routes rich MIME outputs (`image/png`, `image/svg+xml`, `text/html` interactive tables) from `.ipynb` cell outputs directly into the **Plots** and **Preview** tabs.
