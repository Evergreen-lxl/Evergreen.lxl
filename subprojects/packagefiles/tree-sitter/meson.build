project('tree-sitter',
    ['c'],
    version : 'GIT',
    license : 'MIT',
    meson_version : '>= 0.56',
    default_options : ['c_std=gnu99']
)

tree_sitter = static_library('tree-sitter',
    [
        'lib/src/alloc.c',
        'lib/src/get_changed_ranges.c',
        'lib/src/language.c',
        'lib/src/lexer.c',
        'lib/src/node.c',
        'lib/src/parser.c',
        'lib/src/query.c',
        'lib/src/stack.c',
        'lib/src/subtree.c',
        'lib/src/tree.c',
        'lib/src/tree_cursor.c',
    ],
    include_directories: [include_directories('lib/include')]
)

tree_sitter_dep = declare_dependency(
    link_with: tree_sitter,
    include_directories: include_directories('lib/include')
)
