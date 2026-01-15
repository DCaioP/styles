# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Overview

This is a personal IDE customization repository that centralizes visual styling for VSCode and JetBrains IDEs. The repository focuses on maintaining visual consistency across development environments with custom themes, CSS/JS injections, and compositor configurations.

**Primary Language**: Configuration files (CSS, JS, JSONC, ICLS), Shell scripts
**Target Environment**: Linux (Arch Linux with Hyprland compositor)

## Repository Structure

```
├── vscode/              # VSCode customizations
│   ├── custom.css       # Main CSS customizations (cursor animations, transparency, UI tweaks)
│   ├── custom.js        # Command palette blur effects and DOM manipulation
│   ├── transparency.css # Hyprland-specific transparency styles
│   ├── apply_transparency.sh  # Script to apply transparency to VSCode windows
│   ├── vscode_hyprland.conf   # Hyprland compositor rules for VSCode
│   └── settings.json    # Complete VSCode settings configuration
├── jetbrains/           # JetBrains IDE themes
│   └── jeet_brains_theme.icls  # "One Dark Vivid" color scheme
└── zen/                 # Zen Browser customizations (various subdirectories)
```

## VSCode Configuration Architecture

### Custom Styling System
The VSCode customizations work through the **Custom CSS and JS Loader** extension, which injects external CSS/JS files into the VSCode UI:

1. **custom.css**: Core visual customizations
   - Cursor animations (breathing effect)
   - Code comment styling with custom fonts (Operator Mono Lig)
   - Sidebar transparency with backdrop blur
   - File explorer styling
   - Scrollbar customizations
   - Tooltip/hover styling

2. **custom.js**: Interactive UI enhancements
   - Monitors command palette (.quick-input-widget) visibility
   - Adds backdrop blur effect when command palette is open
   - Handles escape key to remove blur
   - Manages sticky widget visibility

3. **transparency.css**: Additional transparency layers for Hyprland integration

### Running VSCode with Custom Styles

To apply custom CSS/JS on Linux, VSCode needs elevated permissions:

```zsh
xhost +local:root
sudo --preserve-env=DISPLAY,WAYLAND_DISPLAY,XDG_RUNTIME_DIR,DBUS_SESSION_BUS_ADDRESS,XAUTHORITY \
     code --no-sandbox --user-data-dir=/tmp/vscode-root
```

**⚠️ Security Note**: Only use this for configuring styles, not for regular development work.

### Applying VSCode Customizations

1. Install required extensions:
```bash
code --install-extension s-nlf-fh.glassit
code --install-extension be5invis.vscode-custom-css
```

2. Configure Custom CSS imports in settings.json:
```json
"vscode_custom_css.imports": [
    "file:///home/caiop/programing/style/vscode/custom.css",
    "file:///home/caiop/programing/style/vscode/transparency.css"
]
```

3. Enable Custom CSS via Command Palette:
   - Press `Ctrl+Shift+P`
   - Run: "Custom CSS and JS: Enable"
   - Restart VSCode

### Hyprland Integration

To enable transparency in Hyprland:

1. Source the configuration:
```zsh
# Add to ~/.config/hypr/hyprland.conf
source = ~/programing/personal/style/vscode/vscode_hyprland.conf
```

2. Or apply transparency dynamically:
```bash
./vscode/apply_transparency.sh
```

This script sets:
- Window opacity to 0.85 for VSCode windows
- Blur effects (size: 10, passes: 4)
- Restarts VSCode to apply changes

## JetBrains Theme Installation

1. Copy theme file to IDE's color directory:
```zsh
cp jetbrains/jeet_brains_theme.icls ~/.config/JetBrains/<IDE_NAME>/colors/
```

2. Apply via IDE settings:
   - File → Settings → Editor → Color Scheme
   - Select "One Dark Vivid"

## Key Design Patterns

### Font Stack
The repository uses a specific font hierarchy:
- **Code**: Operator Mono Lig (with ligatures), Geist Mono, JetBrains Mono, Fira Code
- **Terminal**: JetBrainsMono Nerd Font Mono
- **Comments**: Operator Mono Lig (italicized)

### Color Scheme
Primary accent color: `#6f4e37` (brown/coffee tone)
- Used for: scrollbars, sidebar titles, and highlights

### Transparency Philosophy
- Background opacity: 0.7-0.85
- Backdrop blur enabled for legibility
- Different opacity levels for active/inactive windows

## Important Files

- `vscode/settings.json`: Complete VSCode configuration (editor behavior, formatters, extensions)
- `vscode/custom.css`: Main visual styling (200+ lines of customizations)
- `vscode/custom.js`: Command palette blur behavior
- `vscode/vscode_hyprland.conf`: Hyprland window rules and decoration settings

## Notes for Development

- This is a **personal configuration repository** with no tests or build processes
- Changes should be tested by:
  1. Reloading VSCode window (`Ctrl+R` or Command Palette → "Reload Window")
  2. Running `hyprctl reload` for Hyprland changes
  3. Reopening JetBrains IDE for theme changes
- CSS changes require re-enabling Custom CSS extension after modifications
- All file paths are absolute and specific to `/home/caiop/programing/` — adjust when forking

## Dependencies

### VSCode Extensions
- Custom CSS and JS Loader (be5invis.vscode-custom-css)
- GlassIt-VSC (s-nlf-fh.glassit)
- Prettier (esbenp.prettier-vscode)

### System Requirements
- Linux with Hyprland compositor
- xhost (for X11 forwarding permissions)
- Custom fonts: Operator Mono Lig, Geist Mono, JetBrains Mono, Fira Code
