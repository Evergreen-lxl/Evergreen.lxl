project('tree-sitter-rust',
    ['c'],
    version : 'GIT',
    license : 'MIT',
    meson_version : '>= 0.56',
    default_options : ['c_std=c11']
)

library_suffix = []

# On macOS the default suffix is .dylib but we need .so
if host_machine.system() == 'darwin'
    library_suffix = 'so'
endif

shared_library('tree-sitter-rust',
    [
        'src/parser.c',
        'src/scanner.c'
    ],
    name_suffix: library_suffix,
    include_directories: [include_directories('src')],
    install_dir: join_paths(get_option('data_dir'), 'tree-sitter', 'parsers'),
    install: true,
)
