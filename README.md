# Evergreen
> 🌳 Treesitter support for Lite XL.

This is a plugn which adds Treesitter support to Lite XL. It is work
in progress, definitely not user friendly yet and has a few glaring
bugs.

Currently it only does syntax highlighting, but will be the backbone
for an easy Lite XL treesitter interface in the future.

# Showcase

| Without Evergreen                              | With Evergreen                                 |
| ---------------------------------------------- | ---------------------------------------------- |
| ![](https://safe.kashima.moe/6b3frqkk0q93.png) | ![](https://safe.kashima.moe/97eefjivjyza.png) |

# Setup
This only works with Go files at the moment. So for a sample, checkout
the [Hilbish](https://github.com/Rosettea/Hilbish) repo.

Also only tested on Lite XL master.

Install luarocks if you don't have it.

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

# License
MIT
