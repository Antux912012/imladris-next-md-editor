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

# Desktop File & Metainfo installation for Flatpak
install_data(
  'data/org.gnome.Imladris.desktop',
  install_dir: get_option('datadir') / 'applications'
)

install_data(
  'data/org.gnome.Imladris.metainfo.xml',
  install_dir: get_option('datadir') / 'metainfo'
)

install_data(
  'data/icons/scalable/apps/org.gnome.Imladris.svg',
  install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps'
)

icon_sizes = ['16x16', '24x24', '32x32', '48x48', '64x64', '128x128', '256x256', '512x512']
foreach size : icon_sizes
  install_data(
    'data/icons/hicolor' / size / 'apps/org.gnome.Imladris.png',
    install_dir: get_option('datadir') / 'icons/hicolor' / size / 'apps'
  )
endforeach

install_data(
  'data/org.gnome.Imladris.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0/schemas'
)

gnome.post_install(
  glib_compile_schemas: true,
  update_desktop_database: true,
  gtk_update_icon_cache: true,
)

# Validation Tests
desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test('validate-desktop', desktop_file_validate, args: [meson.current_source_dir() / 'data/org.gnome.Imladris.desktop'])
endif

appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test('validate-metainfo', appstreamcli, args: ['validate', '--no-net', meson.current_source_dir() / 'data/org.gnome.Imladris.metainfo.xml'])
endif

subdir('src')
