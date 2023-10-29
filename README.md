# Evergreen
> 🌳 Treesitter support for Lite XL.

Evergreen adds Treesitter syntax highlighting support for Lite XL.
It is work in progress, but functions well.

> **Warning**
> Evergreen is only tested on Linux and will definitely not work on Windows.

# Showcase

| Without Evergreen                              | With Evergreen                                 |
| ---------------------------------------------- | ---------------------------------------------- |
| ![](before.png)                                |                                 ![](after.png) |

# Supported Languages

Any language supported by `tree-sitter` should (in theory) be supported as well.

It is possible to use grammar installed locally or directly from their git repository. Additionally 
it is possible to specify where to find the queries of the language as well as use sub path for projects
containing more then one language.
## Default grammars

A few grammars have default configurations, pre-compiled parsers and custom queries:

The supported languages are:
 
- [C][tree-sitter-c]
- [C++][tree-sitter-cpp]
- [D][tree-sitter-d]
- [Diff][tree-sitter-diff]
- [Go][tree-sitter-go]
- [go.mod][tree-sitter-go-mod]
- [Javascript/JSX][tree-sitter-javascript]
- [Julia][tree-sitter-julia]
- [Lua][tree-sitter-lua]
- [Rust][tree-sitter-rust]
- [Zig][tree-sitter-zig]

To use any of this grammars simply add this to your conifg 

```lua
local egconfig = require "plugins.evergreen.config"

egconfig.addGrammar {
  lang = "LANGUAGE",
  precompiled = true -- optional: default true, if false use default git repository to install grammar
}
```


## Locally installed grammars

To add a grammar to lite-xl simply add the following configuration to your `init.lua` script:

```lua
local egconfig = require "plugins.evergreen.config"

egconfig.addGrammar {
  path = "YOUR GRAMMAR LOCAL PATH",
  lang = "LANGUAGE NAME",
  extensions = "FILE EXTENSIONS", -- optional for extension name based
  filename = "FILE NAME", -- optional for file name based 
  queries = "QUERIES SUB PATH", -- optional sub path of grammar queries, default = 'queries'
}
```

## From git repository 
To add a grammar directly from a git repository add this to your `init.lua` scripts:

```lua
local egconfig = require "plugins.evergreen.config"
egconfig.addGrammar {
  git = "GIT REPO",
  lang = "LANGUAGE NAME",
  extensions = "FILE EXTENSIONS", -- optional for extension name based
  filename = "FILE NAME", -- optional for file name based 
  queries = "QUERIES SUB PATH", -- optional sub path of grammar queries, default = 'queries'
  subpath = "GRAMMAR SUB PATH", -- optional sub path if grammar is nested, default = nil
  revision = "SPECIFIC GIT REVISION", -- optional version of the code to clone
}
```

## Example 

```lua
local egconfig = require "plugins.evergreen.config"

egconfig.addGrammar {
  path = "~/.grammars/tree-sitter-epics/epics-db",
  lang = "epics_db",
  extensions = "db,vdb",
}

egconfig.addGrammar {
  git = "https://github.com/tree-sitter/tree-sitter-cpp.git",
  lang = "cpp",
  extensions = "cpp,hpp,cc",
}

egconfig.addGrammar {
  git = "https://github.com/tree-sitter/tree-sitter-c.git",
  lang = "c",
  extensions = "c,h",
}

```

# Requirements
- Lite XL 2.1+ or [Pragtical](https://github.com/pragtical/pragtical)
- [ltreesitter](#ltreesitter-installation) (automatic, manually or via LuaRocks)

# Install
## Express Install
Evergreen can be easily installed with [Miq](https://github.com/TorchedSammy/Miq) by
adding this to your plugin declaration:
```lua
{'TorchedSammy/Evergreen.lxl'},
```

## Manually
- Git clone Evergreen into Lite XL plugins directory
Or symlink:  
```
cd ~/Downloads
git clone https://github.com/TorchedSammy/Evergreen.lxl
ln -s ~/Downloads/Evergreen.lxl ~/.config/lite-xl/plugins/evergreen
```

## ltreesitter Installation
### Automatic
The easiest way to install ltreesitter is by not installing it at all!
Evergreen will automatically download a compatible ltreesitter build and
reload itself.

If it fails to download for any reason though, that should be reported
as an issue here. In the mean time, ltreesitter can be installed manually.

### Manual Install
The simplest way to install ltreesitter is to run the following command
(assuming LuaRocks is installed):

```sh
luarocks install ltreesitter --local --dev
```

This may work, but ltreesitter does not officially support Lite XL.
You may encounter problems when installing it via LuaRocks
which might return error messages similar to these or cause crashes:

```
Sat Jun 17 13:36:37 2023 [ERROR] Failed loading /home/user/.luarocks/lib/lua/5.4/ltreesitter.so: /home/user/.luarocks/lib/lua/5.4/ltreesitter.so: undefined symbol: lua_checkstack at /home/user/.local/bin/lite-xl/data/core/init.lua:1226

stack traceback:
[C]: in function 'system.load_native_plugin'
[C]: in function 'require'
...hacuber2a03/.config/lite-xl/plugins/evergreen/parser.lua:2: in main chunk
[C]: in function 'require'
.../user/.config/lite-xl/plugins/evergreen/init.lua:21: in main chunk
[C]: in function 'require'
[C]: in function 'xpcall'
/home/user/.local/bin/lite-xl/data/core/init.lua:1225: in function 'core.try'
/home/user/.local/bin/lite-xl/data/core/init.lua:1013: in function 'core.load_plugins'
/home/user/.local/bin/lite-xl/data/core/init.lua:793: in function 'core.init'
[string "local core..."]:8: in function <[string "local core..."]:2>
[C]: in function 'xpcall'
[string "local core..."]:2: in main chunk
```

In that case, you need to install a special version of ltreesitter for Lite XL.

> **Note**
> You **must** upgrade to the [`master`](https://github.com/lite-xl/lite-xl/tree/master) version of Lite XL.

You can either compile ltreesitter via the command below:
```sh
git clone --recursive -b lite-xl-plugin-api https://github.com/takase1121/ltreesitter.git
cd ltreesitter
make ltreesitter.so
cp ltreesitter.so ~/.config/lite-xl/ltreesitter.so
```

Or download an appropriate release from [here](https://github.com/TorchedSammy/evergreen-builds/releases/tag/ltreesitter),
where ltreesitter.so is Linux, and ltreesitter.dll is Windows.

# Usage
To use Evergreen, you have to install the parser for your language of choice.
This can be done with the `Evergreen: Install` command.  

The next thing to do is add style variables for the highlighting groups in
your config. This can be done like:
```lua
local style = require 'core.style'

style.syntax['<name>'] = '#ffffff'
```

There are a lot of highlight groups to have better control over what specific
parts to highlight. This may be overwhelming for some people though, so
some of these have aliases to the default Lite XL style variables,
and groups like `keyword.return` will default to the `keyword` group,
`conditional.ternary` will default to `conditional` if its set, etc.

Evergreen will warn in the log if there are any groups missing, you can
look at this to see what to set to highlight.

These are the available highlight groups:  
- `attribute`
- `boolean`: A group to highlight booleans specifically
- `character`
- `comment`
- `comment.documentation`: Doc comments
- `conditional`: Keywords relating to conditionals (`if`/`else`)
- `conditional.ternary`
- `constant`
- `constant.builtin`: Constants that are builtins to the language (Go's `iota`, `nil`)
- `constructor`: Constructors (like `new` functions)
- `define`
- `exception`: Keywords relating to exceptions (`try` and `catch`)
- `field`: Like a field in a Lua table
- `float`
- `function`: Function declaration
- `function.call`: Function call
- `function.macro`
- `include`: Keywords related to including modules/packages
- `keyword.function`: The function operator in a language (like `func` in Go)
- `keyword.operator`: Operators that are words (like `and`, `or` in Lua)
- `keyword.return`: The `return` operator
- `label`
- `method`
- `method.call`
- `namespace`
- `number`
- `operator`
- `parameter`: Parameters to a function (in declaration)
- `preproc`: Preprocessor directives (`#if` in C)
- `punctuation.delimiter`: Punctuation that delimits items (`,` and `:`)
- `punctuation.brackets`: Brackets of all kinds (`()` or `{}`, etc)
- `punctuation.special`: `#` in rust, treated as an operator by default
- `repeat`: Keywords relating to loops (`while`, `for`)
- `storageclass`: `static`, `const` in C
- `storageclass.lifetime`: Specifically for lifetimes in Rust currently
- `string`
- `tag`: HTML/JSX tags
- `tag.delimiter`: <>
- `tag.attribute`: Tag attributes
- `text.diff.add`: Highlights additions in diffs
- `text.diff.delete`: Highlights deletions in diffs
- `type`
- `type.builtin`: Builtin types (`int`, `bool`)
- `type.definition`
- `type.qualifier`: Type qualifiers (`private`, `public`)
- `variable`
- `variable.builtin`: Builtin variables (`this`, `self`)

# License
MIT

[tree-sitter-c]: https://github.com/tree-sitter/tree-sitter-c
[tree-sitter-cpp]: https://github.com/tree-sitter/tree-sitter-cpp
[tree-sitter-d]: https://github.com/CyberShadow/tree-sitter-d
[tree-sitter-diff]: https://github.com/the-mikedavis/tree-sitter-diff
[tree-sitter-go]: https://github.com/tree-sitter/tree-sitter-go
[tree-sitter-go-mod]: https://github.com/camdencheek/tree-sitter-go-mod
[tree-sitter-javascript]: https://github.com/tree-sitter/tree-sitter-javascript
[tree-sitter-julia]: https://github.com/tree-sitter/tree-sitter-julia
[tree-sitter-lua]: https://github.com/MunifTanjim/tree-sitter-lua
[tree-sitter-rust]: https://github.com/tree-sitter/tree-sitter-rust
[tree-sitter-zig]: https://github.com/maxxnino/tree-sitter-zig

