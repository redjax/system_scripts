# Yazi

[Yazi](https://github.com/sxyazi/yazi) is a terminal/TUI file explorer for Windows, Mac, and Linux.

## Setup

### Linux

### Windows

#### Scoop

Install dependencies:

```shell
scoop install ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick ghostscript
```

Install Yazi

```shell
scoop install yazi
```

Set shim for `file` executable:

```shell
scoop shim add file $env:USERPROFILE\scoop\apps\git\current\usr\bin\file.exe
```

#### Winget

Install dependencies:

```shell
winget install Gyan.FFmpeg 7zip.7zip jqlang.jq oschwartz10612.Poppler sharkdp.fd BurntSushi.ripgrep.MSVC junegunn.fzf ajeetdsouza.zoxide ImageMagick.ImageMagick
```

Install Yazi:

```shell
winget install sxyazi.yazi
```

## Config

The Yazi repository has the [default config files](https://github.com/sxyazi/yazi/tree/shipped/yazi-config/preset) that you can copy/paste into your config path.

## Themes

Yazi maintains a repository with [community themes for Yazi](https://github.com/yazi-rs/flavors). To add a package, you can use `ya pkg add`.

For example, to install the [Kanagawa.yazi theme](https://github.com/dangooddd/kanagawa.yazi):

```shell
ya pkg add dangooddd/kanagawa
```

Then, edit your Yazi's `themes.toml` (`~/.config/yazi/themes.toml` on Linux/Mac, `$env:APPDATA\yazi\config\themes.toml` on Windows) and set the `[flavor]` options.
