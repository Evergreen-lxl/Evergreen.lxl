project('ltreesitter',
    ['c'],
    version : 'GIT',
    license : 'MIT',
    meson_version : '>= 0.56',
    default_options : ['c_std=c11']
)

cc = meson.get_compiler('c')

use_system_lua = get_option('use_system_lua')

lua_jit_found = false
if get_option('jit') and meson.get_compiler('c').get_id() != 'msvc'
    if not use_system_lua
        luajit_dep = subproject('luajit').get_variable('luajit_dep')
    else
        luajit_dep = dependency('luajit', required : false,
            default_options: ['default_library=static']
        )
    endif

    if luajit_dep.found()
        lua_jit_found = true
    endif
endif

if not use_system_lua and not lua_jit_found
    lua_dep = subproject('lua',
    default_options: default_fallback_options + [
            'default_library=static',
            'line_editing=disabled',
            'interpreter=false'
        ]
    ).get_variable('lua_dep')
elif not lua_jit_found
    # Lua has no official .pc file
    # so distros come up with their own names
    lua_names = [
        'lua5.4', # Debian
        'lua-5.4', # FreeBSD
        'lua',    # Fedora
    ]

    foreach lua : lua_names
        last_lua = (lua == lua_names[-1] or get_option('wrap_mode') == 'forcefallback')
        lua_dep = dependency(lua, fallback: last_lua ? ['lua', 'lua_dep'] : [], required : false,
            version: '>= 5.4',
            default_options: default_fallback_options + ['default_library=static', 'line_editing=false', 'interpreter=false']
        )
        if lua_dep.found()
            break
        endif

        if last_lua
            # If we could not find lua on the system and fallbacks are disabled
            # try the compiler as a last ditch effort, since Lua has no official
            # pkg-config support.
            lua_dep = cc.find_library('lua', required : true)
        endif
    endforeach
else
    lua_dep = luajit_dep
endif

library_suffix = []

# On macOS the default suffix is .dylib but we need .so
if host_machine.system() == 'darwin'
    library_suffix = 'so'
endif

ltreesitter = shared_library('ltreesitter',
    [
        'csrc/dynamiclib.c',
        'csrc/ltreesitter.c',
        'csrc/luautils.c',
        'csrc/node.c',
        'csrc/object.c',
        'csrc/parser.c',
        'csrc/query.c',
        'csrc/query_cursor.c',
        'csrc/tree.c',
        'csrc/tree_cursor.c',
        'csrc/types.c'
    ],
    name_prefix: '',
    name_suffix: library_suffix,
    include_directories: [include_directories('include')],
    dependencies: [
        lua_dep,
        dependency('tree-sitter'),
        cc.find_library('m', required: false)
    ],
    install_dir: join_paths(get_option('data_dir'), 'tree-sitter'),
    install: true,
)
