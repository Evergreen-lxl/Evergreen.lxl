project('Evergreen',
    version : '2.0.0',
    license : 'MIT',
    meson_version : '>= 0.56'
)

data_dir = get_option('data_dir')

subproject('ltreesitter', default_options: [
    'data_dir='+data_dir,
    'use_system_lua='+get_option('use_system_lua').to_string(),
    'jit='+get_option('use_system_lua').to_string(),
])

subproject('tree-sitter-c', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-cpp', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-d', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-diff', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-go', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-go-mod', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-javascript', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-julia', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-lua', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-rust', default_options: ['data_dir='+data_dir])
subproject('tree-sitter-zig', default_options: ['data_dir='+data_dir])

evergreen_files = [
    'config.lua', 'highlights.lua', 'init.lua', 'installer.lua',
    'languages.lua', 'LICENSE', 'parser.lua', 'README.md', 'style.lua',
    'util.lua'
]

foreach evergreen_file : evergreen_files
    install_data(evergreen_file,
        install_dir: join_paths(get_option('data_dir'), 'plugins' / 'evergreen')
    )
endforeach

install_subdir('queries',
    install_dir: join_paths(get_option('data_dir'), 'plugins' / 'evergreen')
)
