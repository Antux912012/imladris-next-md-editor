# License & Script Interface Exception Policy

Imladris is free and open-source software distributed under the terms of the **GNU General Public License version 3 (GPLv3)**.

---

## 1. GNU General Public License v3.0

Imladris gives users the freedom to:
- Run the program for any purpose, including commercial, academic, and governmental research.
- Study how the program works and modify it to suit their needs.
- Redistribute exact copies of the software to help colleagues.
- Distribute copies of your modified versions to the community under the same GPLv3 license.

The complete text of the license is available in the repository at [`LICENSE`](file:///home/antonio/Projects/imladris-next-md-editor/LICENSE).

---

## 2. JavaScriptCore Script Interface Clarification for Extensions

Imladris features a third-party extension and plugin engine based on `javascriptcoregtk-6.0` (`JSC.Context`).

To encourage an open, thriving scientific ecosystem, the Imladris maintainers provide the following formal clarification regarding third-party extensions:

> [!NOTE]
> **JavaScriptCore Script Interface Clarification**:
> Third-party plugins and extensions that communicate with Imladris exclusively through the documented `imladris.*` JavaScript API (and packaged as `.implugin` or `.zip` archives) are considered separate, independent works under copyright law.
> 
> Plugin authors are free to license their original JavaScript files (`main.js`, helper modules) under **any OSI-approved license of their choice**, including:
> - **GPLv3 / AGPLv3**
> - **MIT License**
> - **Apache License 2.0**
> - **BSD 2-Clause / 3-Clause**
> 
> Developing or distributing an extension that interfaces with Imladris via the JavaScriptCore bridge does not compel the extension author to license their plugin code under the GPLv3, provided the extension does not link against or incorporate internal compiled Vala/C binary code from Imladris.

---

## 3. Third-Party Project Credits & Inspirations

Imladris proudly acknowledges and builds upon inspirations from the wider scientific and open-source community:
- **RStudio / Posit**: Four-quadrant scientific workbench ergonomics and the `.Rproj` project format.
- **Project Jupyter**: Interactive notebook paradigms and reproducible computational science.
- **Apostrophe**: Calm, distraction-free markdown authoring interface.
- **Obsidian**: Modular, user-extensible JavaScript plugin architecture.
- **GNOME Foundation**: GTK4 and Libadwaita human interface guidelines.
- **LM Studio, Ollama & llama.cpp**: Offline, local, privacy-preserving AI inference.
- **Gemini Assistance**: Developed with Google DeepMind Advanced Agentic Coding assistance.
