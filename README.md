# Evergreen
> 🌳 Treesitter support for Lite XL.

This is a plugn which adds Treesitter support to Lite XL

This is VERY work in progress, and not the type where it's usable with some
bugs here and there; it is inefficient and also makes the doc look like a
mess.

So if you want to help, file some PRs!

# Setup
Currently this only works with Go files. So for a sample, checkout
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
