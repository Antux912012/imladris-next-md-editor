project('imladris', 'vala', 'c',
  version: '0.11.0',
  default_options: ['warning_level=1']
)

gnome = import('gnome')
cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required: false)

deps = [
  dependency('gtk4', version: '>= 4.12'),
  dependency('libadwaita-1', version: '>= 1.5'),
  dependency('gtksourceview-5', version: '>= 5.10'),
  dependency('webkitgtk-6.0'),
  dependency('libsoup-3.0'),
  dependency('json-glib-1.0'),
  dependency('gee-0.8'),
  dependency('gio-2.0'),
  dependency('glib-2.0'),
  m_dep,
]

resources = gnome.compile_resources(
  'imladris-resources',
  'data/imladris.gresource.xml',
  source_dir: 'data',
  c_name: 'imladris'
)

sources = files(
  'src/main.vala',
  'src/Application.vala',
  'src/RibbonFactory.vala',
  'src/PopoverFactory.vala',
  'src/SmartRibbonHelpers.vala',
  'src/DocumentPage.vala',
  'src/ExecutionEngine.vala',
  'src/AiClient.vala',
  'src/ai/ElrondEngineController.vala',
  'src/ai/AiCompletionProvider.vala',
  'src/McpServer.vala',
  'src/AssistantPanel.vala',
  'src/Window.vala',
  'src/console/ReplBridge.vala',
  'src/editor/ChunkExecutionEngine.vala',
  'src/core/frontmatter_parser.vala',
  'src/core/notebook_serializer.vala',
  'src/core/project_scaffolder.vala',
  'src/core/MallornManager.vala',
  'src/core/ChunkParser.vala',
  'src/adapters/DocumentAdapter.vala',
  'src/services/RecoveryService.vala',
  'src/services/WorkspaceStateManager.vala',
  'src/services/SandboxController.vala',
  'src/services/PersistentSessionManager.vala',
  'src/services/ExportService.vala',
  'src/services/PackageIndexCache.vala',
  'src/core/layout/DockTypes.vala',
  'src/ui/PersistentPanelRegistry.vala',
  'src/ui/RStudioDockGrid.vala',
  'src/ui/new_project_dialog.vala',
  'src/ui/PackagesRibbonBar.vala',
  'src/ui/InlineChunkOutputWidget.vala',
  'src/ui/WebViewFactory.vala',
  'src/ui/PreferencesDialog.vala',
  'src/ui/ThemeSelectorWidget.vala',
  'src/ui/AccentColorSelectorWidget.vala',
  'src/ui/AiSettingsDialog.vala',
  'src/ui/ToolchainSetupDialog.vala',
  'src/core/SettingsManager.vala',
  'src/core/AiConfigManager.vala',
  'src/core/PlatformUtils.vala',
  'src/core/ToolchainManager.vala',
)

executable('imladris',
  sources,
  resources,
  dependencies: deps,
  vala_args: ['--target-glib=2.76'],
  install: true
)

install_data(
  'data/io.github.Antux912012.Imladris.desktop',
  install_dir: get_option('datadir') / 'applications'
)

install_data(
  'data/io.github.Antux912012.Imladris.metainfo.xml',
  install_dir: get_option('datadir') / 'metainfo'
)

install_data(
  'data/io.github.Antux912012.Imladris.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

gnome.post_install(glib_compile_schemas: true)

install_data(
  'scripts/install-llama-server.sh',
  install_dir: get_option('datadir') / 'imladris' / 'scripts'
)

install_subdir(
  'data/icons/hicolor',
  install_dir: get_option('datadir') / 'icons'
)

test_sources = files(
  'tests/test_mallorn_sandbox.vala',
  'src/core/frontmatter_parser.vala',
  'src/core/notebook_serializer.vala',
  'src/core/project_scaffolder.vala',
  'src/core/MallornManager.vala',
  'src/adapters/DocumentAdapter.vala',
  'src/services/SandboxController.vala',
  'src/services/PersistentSessionManager.vala',
  'src/services/ExportService.vala',
  'src/core/ChunkParser.vala',
  'src/console/ReplBridge.vala',
  'src/editor/ChunkExecutionEngine.vala',
  'src/core/PlatformUtils.vala',
  'src/core/ToolchainManager.vala',
)

test_exe = executable('test_mallorn_sandbox',
  test_sources,
  dependencies: deps,
  vala_args: ['--target-glib=2.76'],
)

test('mallorn_sandbox_tests', test_exe, timeout: 120)

ai_test_sources = files(
  'tests/test_ai_integration.vala',
  'src/core/AiConfigManager.vala',
  'src/core/SettingsManager.vala',
  'src/core/PlatformUtils.vala',
  'src/core/ToolchainManager.vala',
)

ai_test_exe = executable('test_ai_integration',
  ai_test_sources,
  dependencies: deps,
  vala_args: ['--target-glib=2.76'],
)

test('ai_integration_tests', ai_test_exe, timeout: 30)


