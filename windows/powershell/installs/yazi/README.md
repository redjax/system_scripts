# Yazi

[Yazi](https://github.com/sxyazi/yazi) is a terminal/TUI file explorer for Windows, Mac, and Linux.

## Automated Installation Scripts

This directory contains PowerShell scripts for automated Yazi installation and configuration on Windows:

- **Install-YaziComplete.ps1** - One-click complete setup (recommended)
- **Install-Yazi.ps1** - Main Yazi installation using Scoop
- **Install-YaziDependencies.ps1** - Install required and optional dependencies
- **Install-YaziThemes.ps1** - Install curated theme collection
- **Install-YaziPlugins.ps1** - Install useful plugins

### Quick Start

**Option 1: Complete Installation (Recommended)**

```powershell
# Install everything in one command
.\Install-YaziComplete.ps1
```

**Option 2: Step-by-Step Installation**

```powershell
# Install Yazi with dependencies
.\Install-Yazi.ps1

# Install themes
.\Install-YaziThemes.ps1

# Install plugins
.\Install-YaziPlugins.ps1
```

See the [Script Documentation](#script-documentation) section below for detailed usage.

## Manual Setup

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

---

## Script Documentation

### Install-YaziComplete.ps1

**One-click complete setup** that runs all installation scripts in the correct order.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `SkipDependencies` | Switch | Skip dependencies installation |
| `SkipThemes` | Switch | Skip themes installation |
| `SkipPlugins` | Switch | Skip plugins installation |
| `DarkThemesOnly` | Switch | Install only dark themes |
| `LightThemesOnly` | Switch | Install only light themes |
| `EssentialOnly` | Switch | Install only essential dependencies |
| `SkipFonts` | Switch | Skip Nerd Fonts installation |

**Examples:**

```powershell
# Complete installation
.\Install-YaziComplete.ps1

# Minimal installation (Yazi + essential dependencies only)
.\Install-YaziComplete.ps1 -SkipThemes -SkipPlugins -EssentialOnly

# Dark theme setup with essential dependencies
.\Install-YaziComplete.ps1 -DarkThemesOnly -EssentialOnly -SkipFonts
```

---

### Install-Yazi.ps1

Installs Yazi file manager using Scoop with automatic dependency checking.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `Force` | Switch | Force reinstallation even if already installed |
| `SkipDependencies` | Switch | Skip dependency installation prompt |

**Examples:**

```powershell
# Basic installation
.\Install-Yazi.ps1

# Force reinstall
.\Install-Yazi.ps1 -Force

# Install without dependency prompts
.\Install-Yazi.ps1 -SkipDependencies
```

---

### Install-YaziDependencies.ps1

Installs dependencies that enhance Yazi's functionality via Scoop.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `SkipFonts` | Switch | Skip Nerd Fonts installation |
| `Essential` | Switch | Install only essential dependencies |

**Dependencies:**

**Essential:**
- 7zip, jq, ripgrep, fd, fzf

**Optional:**
- ffmpeg, poppler, imagemagick, zoxide

**Fonts:**
- FiraCode-NF, JetBrainsMono-NF

**Examples:**

```powershell
# Install all dependencies
.\Install-YaziDependencies.ps1

# Essential only
.\Install-YaziDependencies.ps1 -Essential -SkipFonts
```

---

### Install-YaziThemes.ps1

Installs curated collection of Yazi themes using the `ya` package manager.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `ThemeList` | String[] | Custom array of themes to install |
| `DarkOnly` | Switch | Install only dark themes |
| `LightOnly` | Switch | Install only light themes |

**Included Themes:**
- **Dark:** Kanagawa, Catppuccin (Macchiato/Frappe), Dracula, Gruvbox, Rose Pine, VS Code Dark, and more
- **Light:** Catppuccin Latte, Kanagawa Lotus, Flexoki Light, Rose Pine Dawn, VS Code Light

**Examples:**

```powershell
# Install all themes
.\Install-YaziThemes.ps1

# Dark themes only
.\Install-YaziThemes.ps1 -DarkOnly

# Specific themes
.\Install-YaziThemes.ps1 -ThemeList @("dangooddd/kanagawa")
```

---

### Install-YaziPlugins.ps1

Installs useful Yazi plugins to extend functionality.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `PluginList` | String[] | Custom array of plugins to install |

**Included Plugins:**
- `smart-enter` - Open files/dirs with Enter
- `smart-paste` - Paste into hovered directory
- `mount` - Mount/eject drives
- `vcs-files` - Git status display
- `smart-filter` - Enhanced filtering
- `chmod` - File permissions
- `mime-ext` - Fast MIME detection
- `diff` - File comparison

**Examples:**

```powershell
# Install all plugins
.\Install-YaziPlugins.ps1

# Specific plugins
.\Install-YaziPlugins.ps1 -PluginList @("yazi-rs/plugins:smart-enter")
```

---

## Additional Resources

- [Yazi Official Documentation](https://yazi-rs.github.io/)
- [Yazi GitHub Repository](https://github.com/sxyazi/yazi)
- [Yazi Plugins](https://github.com/yazi-rs/plugins)
- [Yazi Themes](https://github.com/yazi-rs/flavors)
- [Scoop Package Manager](https://scoop.sh/)
