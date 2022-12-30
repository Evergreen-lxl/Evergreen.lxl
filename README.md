# Evergreen
> 🌳 Treesitter support for Lite XL.

Evergreen adds Treesitter syntax highlighting support for Lite XL.
It is work in progress, but functions well.

> **Warning**
> Evergreen is only tested on Linux and will definitely not work on Windows.

# Showcase

| Without Evergreen                              | With Evergreen                                 |
| ---------------------------------------------- | ---------------------------------------------- |
| ![](https://safe.kashima.moe/6b3frqkk0q93.png) | ![](https://safe.kashima.moe/97eefjivjyza.png) |

# Supported Languages
- [x] [C][tree-sitter-c]
- [x] [C++][tree-sitter-cpp]
- [x] [Go][tree-sitter-go]
- [x] [Lua][tree-sitter-lua]

If you want more languages supported, open an issue.

# Requirements
- Lite XL 2.1+
- ltreesitter master via Luarocks (`luarocks install ltreesitter --local --dev`)

# Install
## Express Install
Evergreen can be easily installed with [Miq](https://github.com/TorchedSammy/Miq) by
adding this to your plugin declaration:
```lua
	{'TorchedSammy/Evergreen.lxl', run = 'luarocks install ltreesitter --local --dev'},
```

## Manually
- Git clone Evergreen into Lite XL plugins directory
Or symlink:  
```
cd ~/Downloads
git clone https://github.com/TorchedSammy/Evergreen.lxl
ln -s ~/Downloads/Evergreen.lxl ~/.config/lite-xl/plugins/evergreen
```

# Usage
To use Evergreen, you have to install the parser for your language of choice.
This can be done with the `Evergreen: Install` command.  

Once there is a log that the install has completed, you can start coding
with Treesitter highlighting! It's that easy.

# License
MIT

[tree-sitter-c]: https://github.com/tree-sitter/tree-sitter-c
[tree-sitter-cpp]: https://github.com/tree-sitter/tree-sitter-cpp
[tree-sitter-go]: https://github.com/tree-sitter/tree-sitter-go
[tree-sitter-lua]: https://github.com/MunifTanjim/tree-sitter-lua
