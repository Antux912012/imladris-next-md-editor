project('imladris', 'vala', 'c',
  version: '0.3.0',
  default_options: ['warning_level=1']
)

gnome = import('gnome')

deps = [
  dependency('gtk4', version: '>= 4.12'),
  dependency('libadwaita-1', version: '>= 1.5'),
  dependency('gtksourceview-5', version: '>= 5.10'),
  dependency('webkitgtk-6.0'),
  dependency('gio-2.0'),
  dependency('glib-2.0'),
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
  'src/DocumentPage.vala',
  'src/ExecutionEngine.vala',
  'src/Window.vala',
)

executable('imladris',
  sources,
  resources,
  dependencies: deps,
  vala_args: ['--target-glib=2.76'],
  install: true
)

install_data(
  'data/org.gnome.Imladris.desktop',
  install_dir: get_option('datadir') / 'applications'
)

install_data(
  'data/org.gnome.Imladris.metainfo.xml',
  install_dir: get_option('datadir') / 'metainfo'
)

install_subdir(
  'data/icons/hicolor',
  install_dir: get_option('datadir') / 'icons'
)

