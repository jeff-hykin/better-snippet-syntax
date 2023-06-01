# What does this do?
Highlights the snippets-json file for VS Code snippets. Its Incredibly useful for bash/shell/perl snippets or really anything that includes $'s.

### Like this extension?
You'll probably like this as well: [The Better Syntax Megapack](https://marketplace.visualstudio.com/items?itemName=jeff-hykin.better-syntax)


NOTE: The default VS Code theme does not color much. Switch to the Dark+ theme (installed by default) or use a theme like one of the following to benefit from the changes:
- [XD Theme](https://marketplace.visualstudio.com/items?itemName=jeff-hykin.xd-theme)
- [Noctis](https://marketplace.visualstudio.com/items?itemName=liviuschera.noctis)
- [Kary Pro Colors](https://marketplace.visualstudio.com/items?itemName=karyfoundation.theme-karyfoundation-themes)
- [Material Theme](https://marketplace.visualstudio.com/items?itemName=Equinusocio.vsc-material-theme)
- [One Monokai Theme](https://marketplace.visualstudio.com/items?itemName=azemoh.one-monokai)
- [Winteriscoming](https://marketplace.visualstudio.com/items?itemName=johnpapa.winteriscoming)
- [Popping and Locking](https://marketplace.visualstudio.com/items?itemName=hedinne.popping-and-locking-vscode)
- [Syntax Highlight Theme](https://marketplace.visualstudio.com/items?itemName=peaceshi.syntax-highlight)
- [Default Theme Enhanced](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools-themes)

## How do I use it?
Just install the VS Code extension and the changes will automatically be applied to all relevent files.

# Before and After (XD Theme)

Before                     | After 
:-------------------------:|:-------------------------:
<img width="658" alt="before" src="https://user-images.githubusercontent.com/17692058/199324680-558c7489-2e12-4afb-8ccc-5d43b74f224a.png"> | <img width="665" alt="after" src="https://user-images.githubusercontent.com/17692058/199324673-3c548580-ddf8-484b-b3b7-b14036fc6284.png">

# Notes to themers and customizers

Prefix every TM scope below with `source.json.comments`

Level-1 customization
- For insertions: `keyword.operator.insertion`
- For special vars: `variable.language.this`
- For escapes:
    - the 1st backslash in backslash-backslash is the "escaper"
    - the 2nd backslash in backslash-backslash is the "escapee"
    - for the double-escaper (defaults to comment-color): `punctuation.section.insertion.escape.escaper comment.block punctuation.definition.comment.insertion.escape`
    - for the double-escapee (defaults to normal string-color): `punctuation.section.insertion.escape.escapee string.regexp.insertion.escape string.quoted.double`

Level-2 customization
- To highlight something in a specific area:
    - prefix with `meta.insertion.simple` to cover all characters in `$var`-like insertions
    - prefix with `meta.insertion.brackets` to cover all characters in `${...}`-like insertions
- For coloring var names (and not the $):
    - use `custom.variable.other.normal` for non-builtin vars
    - use `variable.language.this` for builtin vars
    - use `punctuation variable.language.this` to change the `$` color of builtin vars

Level-3 customization
- To color numeric vars differently
    - For simple numeric vars like $1 use `meta.insertion.format.simple.numeric keyword.operator.insertion`
    - For bracket-ed numeric vars, just use `meta.insertion.brackets` and then have `meta.insertion.brackets meta.insertion.variable` for non-numeric bracket insertions
- To color `$` differently
    - For `$` in `$VAR` but not `${VAR:}` use `punctuation.section.insertion.dollar.simple keyword.operator.insertion`
    - For `$` in `${VAR:}` but not `$VAR` use `punctuation.section.insertion.dollar.brackets keyword.operator.insertion`
- Here are some misc other scopes:
    - `meta.insertion.choice` for `${name|a,b,c|}`
    - `meta.insertion.transform` for the `/find/replace/g` within `${VAR/find/replace/g}`
    - `variable.language.special.transform` for the /upcase /downcase, etc options
    - `constant.other.option` for the `a` in `${name|a,b,c|}`
    - `punctuation.separator.colon`
    - `punctuation.section.insertion.bracket`
    - `custom.punctuation.separator.choice`
    - `meta.insertion.tabstop`
    - `meta.insertion.tabstop.simple`
    - `meta.insertion.tabstop.bracket`
    - `meta.insertion.tabstop.transform`
    - `meta.insertion.format`
    - `meta.insertion.format.simple`
    - `meta.insertion.format.transform`
    - `meta.insertion.format.plus`
    - `meta.insertion.format.conditional`
    - `meta.insertion.format.remove`
    - `meta.insertion.format.default`
    - `meta.insertion.placeholder`

## Contributing
If you'd like to help improve the syntax, take a look at `main/main.rb`. And make sure to take a look at `CONTRIBUTING.md` to get a better idea of how code works.