# Evergreen
> 🌳 Treesitter support for Lite XL.

Evergreen adds syntax highlighting to Lite XL via Treesitter. It is *very*
work in progress. There are a few glaring bugs (#1 of them :^)) and it is
not as efficient as it can be.

It will be the backbone for an easy Lite XL treesitter interface in the
future.

# Showcase

| Without Evergreen                              | With Evergreen                                 |
| ---------------------------------------------- | ---------------------------------------------- |
| ![](https://safe.kashima.moe/6b3frqkk0q93.png) | ![](https://safe.kashima.moe/97eefjivjyza.png) |

# Supported Languages
- [x] Go
- [x] Lua
If you want more languages supported, open an issue.

# Requirements
- Lite XL master (upcoming 2.1 release)
- Luarocks

# Setup
```
luarocks install ltreesitter --local --dev
cd ~
mkdir -p ~/.local/share/tree-sitter/parsers
cd ~/.local/share/tree-sitter/parsers
git clone https://github.com/tree-sitter/tree-sitter-go
cd tree-sitter-go
make
```
- Git clone Evergreen into Lite XL plugins directory
Or symlink:  
```
cd ~/Downloads
git clone https://github.com/TorchedSammy/Evergreen.lxl
ln -s ~/Downloads/Evergreen.lxl ~/.config/lite-xl/plugins/evergreen
```

# License
MIT
