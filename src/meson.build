sources = files(
  'main.vala',
  'application.vala',
  'RibbonFactory.vala',
  'window.vala',
  'core/document_model.vala',
  'core/file_manager.vala',
  'core/markdown_parser.vala',
  'core/frontmatter_parser.vala',
  'core/notebook_serializer.vala',
  'core/project_scaffolder.vala',
  'core/view_manager.vala',
  'ui/coding_view.vala',
  'ui/preview_view.vala',
  'ui/contextual_popover.vala',
  'ui/new_project_dialog.vala',
  'ui/tab_page_content.vala',
  'ui/terminal_view.vala',
)

dependencies = [
  glib_dep,
  gio_dep,
  gtk4_dep,
  adw_dep,
  gtksource_dep,
  webkit_dep,
  vte_dep,
  json_glib_dep,
  gee_dep,
  cmark_dep,
]

executable(
  'imladris',
  sources,
  resources,
  dependencies: dependencies,
  install: true
)
