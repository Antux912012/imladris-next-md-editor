sources = files(
  'main.vala',
  'application.vala',
  'window.vala',
  'core/document_model.vala',
  'core/file_manager.vala',
  'core/markdown_parser.vala',
  'core/view_manager.vala',
  'ui/coding_view.vala',
  'ui/preview_view.vala',
  'ui/contextual_popover.vala',
  'ui/tab_page_content.vala',
)

dependencies = [
  glib_dep,
  gio_dep,
  gtk4_dep,
  adw_dep,
  gtksource_dep,
  webkit_dep,
  gee_dep,
  cmark_dep,
]

executable(
  'imladris',
  sources,
  resources,
  dependencies: dependencies,
  vala_args: [
    '--pkg', 'cmark',
  ],
  install: true
)
