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

# Notes to themers and customizers

- `support.class.insertion` will color `$`, `${}`, and `THING` in `$THING`, `${THING:}`
- `variable.language.this` will color the builtin/special `$VAR` things
- for level-2 customization:
    - for just varible names: `variable.other.normal support.class.insertion`
    - for just `$`'s: `punctuation.section.insertion.dollar support.class.insertion`
    - for just `{}`'s: `punctuation.section.insertion.dollar punctuation.section.insertion.bracket`
- for level-3 customization:
    - for numeric variables e.g. `1` in `$1` `variable.other.normal.numeric support.class.insertion`
    - for `$` in `$VAR` but not `${VAR:}` use `punctuation.section.insertion.dollar.connected support.class.insertion`
    - for `$` in `${VAR:}` but not `$VAR` use `punctuation.section.insertion.dollar.interpolated support.class.insertion`
    - do to things for specific insertions use:
        - `meta.insertion.simple` for `$1`
        - `meta.insertion.default` for `${1:default}`
        - `meta.insertion.choice` for `${name|a,b,c|}`
        - `meta.insertion.variable-transform` for `${VAR/find/replace/g}`

# Before and After (XD Theme)

Before                     | After 
:-------------------------:|:-------------------------:
<img width="658" alt="before" src="https://user-images.githubusercontent.com/17692058/199324680-558c7489-2e12-4afb-8ccc-5d43b74f224a.png"> | <img width="665" alt="after" src="https://user-images.githubusercontent.com/17692058/199324673-3c548580-ddf8-484b-b3b7-b14036fc6284.png">

## Contributing
If you'd like to help improve the syntax, take a look at `main/main.rb`. And make sure to take a look at `CONTRIBUTING.md` to get a better idea of how code works.