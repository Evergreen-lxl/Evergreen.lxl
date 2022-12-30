# Evergreen
> 🌳 Treesitter support for Lite XL.

Evergreen adds Treesitter syntax highlighting support for Lite XL.
It is work in progress, but functions well.

# Showcase

| Without Evergreen                              | With Evergreen                                 |
| ---------------------------------------------- | ---------------------------------------------- |
| ![](https://safe.kashima.moe/6b3frqkk0q93.png) | ![](https://safe.kashima.moe/97eefjivjyza.png) |

# Supported Languages
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

# Setting Up Parsers
Install supported treesitter parsers to `~/.local/share/tree-sitter/parsers`, example:
```
mkdir -p ~/.local/share/tree-sitter/parsers/
cd ~/.local/share/tree-sitter/parsers
git clone https://github.com/tree-sitter/tree-sitter-go
cd tree-sitter-go
make
```

Some (or most) parsers may not have a Makefile. So instead of running make,
you can run this command:  
```
gcc -o parser.so -shared src/*.c -Os -I./src -fPIC
```

# License
MIT

[tree-sitter-go]: https://github.com/tree-sitter/tree-sitter-go
[tree-sitter-lua]: https://github.com/MunifTanjim/tree-sitter-lua
