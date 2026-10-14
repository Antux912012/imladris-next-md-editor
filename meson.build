project(
  'imladris',
  ['c', 'vala'],
  version: '0.1.0',
  meson_version: '>= 0.60.0',
  default_options: [
    'warning_level=2',
    'werror=false',
    'c_std=gnu11',
  ]
)

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
  ['--vapidir', meson.current_source_dir() / 'src/vapi'],
  language: 'vala'
)

glib_dep = dependency('glib-2.0', version: '>= 2.74')
gio_dep = dependency('gio-2.0')
gtk4_dep = dependency('gtk4', version: '>= 4.10')
adw_dep = dependency('libadwaita-1', version: '>= 1.4')
gtksource_dep = dependency('gtksourceview-5', version: '>= 5.6')
webkit_dep = dependency('webkitgtk-6.0', version: '>= 2.40')
gee_dep = dependency('gee-0.8')
cmark_dep = dependency('libcmark', fallback: ['cmark', 'cmark_dep'])

resources = gnome.compile_resources(
  'imladris-resources',
  'data/org.gnome.Imladris.gresource.xml',
  source_dir: 'data',
  c_name: 'imladris'
)

subdir('src')
