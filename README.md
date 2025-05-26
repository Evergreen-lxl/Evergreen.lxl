# Evergreen
> 🌳 Treesitter support for Lite XL.

Evergreen adds Treesitter syntax highlighting support for Lite XL.
It is work in progress, but functions well.

> [!NOTE]
> Evergreen is only extensively tested on Linux,
> but it should work correctly on MacOS and Windows based on brief testing.

# Showcase

| Without Evergreen                              | With Evergreen                                 |
| ---------------------------------------------- | ---------------------------------------------- |
| ![](before.png)                                |                                 ![](after.png) |

# Requirements
- [Lite XL](https://lite-xl.com) 2.1+ or [Pragtical](https://pragtical.dev)
- `lua_tree_sitter` library

# Installation
## Plugin Manager

### Miq
Evergreen can be easily installed with [Miq](https://github.com/TorchedSammy/Miq) by
adding this to your plugin declaration:
```lua
{'Evergreen-lxl/Evergreen.lxl'},
```

### lpm / ppm
Evergreen can be installed using [lpm](https://github.com/lite-xl/lite-xl-plugin-manager)
for Lite XL or [ppm](https://github.com/pragtical/plugin-manager) for Pragtical:
```
lpm install evergreen
ppm install evergreen
```

## Manual
- Git clone Evergreen into Lite XL plugins directory
- Or symlink:  
```
cd ~/Downloads
git clone https://github.com/Evergreen-lxl/Evergreen.lxl
ln -s ~/Downloads/Evergreen.lxl ~/.config/lite-xl/plugins/evergreen
```

## `lua_tree_sitter` Installation
### Plugin Manager

Plugin managers will handle the installation of the `lua_tree_sitter` library
automatically.

### Manual Install

You can download the library from
[here](https://github.com/Evergreen-lxl/lite-xl-tree-sitter/releases), and then place
it inside the `libraries/tree_sitter` directory inside your user directory.
Rename the binary to `init.so`.

# Usage

## Installing support for languages

### Pre-packaged plugins

Automated builds for some languages are available in
[evergreen-languages](https://github.com/Evergreen-lxl/evergreen-languages).
Follow the instructions inside the README there to install.

### Manual

Languages can also be manually configured as such:
```lua
local evergreenLangs = require 'plugins.evergreen.languages'

evergreenLangs.addDef {
	name = 'foo',
	files = { '%.foo$', '%.bar$' },
	path = '~/tree-sitter-foo',
	soFile = 'parser{SOEXT}',
	queryFiles = {
		highlights = 'queries/highlights.scm',
	},
}
```

| Option                  | Default                    | Description
| ----------------------  | -------------------------- | -----------
| `name`                  |                            | identifier for the language. must be unique
| `files`                 | `{}`                       | list of patterns that matches filenames of this language
| `path`                  |                            | directory where the shared library and queries are located
| `soFile`                | `'parser{SOEXT}'`          | location of the shared library inside `path`
| `queryFiles.highlights` | `'queries/highlights.scm'` | location of the highlights query inside `path`

For `soFile`, the placeholder `{SOEXT}` will be replaced with
the [configured](#configuration-options) shared library extension.

It is perfectly fine to have the parser not exist,
as long as the `files` option is an empty list or left out.
This implies that the language definition is only used for
inheritance from its queries.

## Syntax highlighting groups

Evergreen extends the set of highlight groups that Lite XL provides.
You can set individual colors for these groups in the `style.syntax` table,
just as you would with regular syntax types in Lite XL:
```lua
local common = require 'core.common'
local style = require 'core.style'

style.syntax['<name>'] = { common.color '#ffffff' }
style.syntax['<name>.<subcategory>'] = { common.color '#123456' }
```

By default, Evergreen has a fallback mechanism for a limited set of highlights.
The fallbacks cover groups defined by Nvim (see [here](nvim-ts-highlight-groups)).
A warning is generated if any fallbacks were used.

Evergreen will try to use the colors from default Lite XL syntax types
to set these fallbacks.
However, due to not having a close approximate, the fallbacks for these groups
may not make sense, and you may want to set them explicitly:
- `diff.plus`
- `diff.minus`
- `diff.delta`
- `comment.error`
- `comment.warning`
- `comment.todo`
- `comment.note`

Additionally, since there are a lot of groups to give more fine-grained control,
some may find that they do not need to set all of them explicitly.
If you wish to disable the fallback mechanism or the warning,
set the respective [configuration options](#configuration-options) correspondingly.

## Configuration options

Set configuration options for Evergreen by adding this to your user module:
```lua
local evergreenConfig = require 'plugins.evergreen.config'

evergreenConfig.option1 = false
evergreenConfig.option2 = 1000
```

| Option               | Default      | Description
| -------------------- | ------------ | -----------
| `useFallbackColors`  | `true`       | set fallbacks for missing colors
| `warnFallbackColors` | `true`       | warn when fallback colors are used
| `soExt`              | `.so`/`.dll` | shared library extension (`.dll` on Windows, `.so` otherwise)
| `maxParseTime`       | `2000`       | maximum time spent parsing before deferring it (in µs). set to 0 to disable deferring

# License
MIT

[nvim-ts-highlight-groups]: https://neovim.io/doc/user/treesitter.html#_treesitter-syntax-highlighting:~:text=The%20following%20is%20a%20list%20of%20standard%20captures%20used%20in%20queries%20for%20Nvim
