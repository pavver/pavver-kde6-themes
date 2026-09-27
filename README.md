# Pavver KDE 6 Themes

Monorepository for the Pavver KDE Plasma 6 visual family. SDDM and
KScreenLocker use one capability-driven QML implementation, while their
platform-specific directories contain only API adapters, entry points,
metadata, installers, and previews.

## Layout

```text
pavver-kde6-themes/
├── shared/PavverTheme/       # Single source of truth for visual QML
│   ├── Theme.qml             # Colors, typography, geometry, and motion
│   ├── AuthCard.qml          # Capability-driven authentication card
│   ├── AnimatedBackground.qml
│   ├── Clock.qml
│   ├── LoginLoader.qml
│   ├── VirtualKeyboard.qml
│   ├── assets/
│   └── fonts/
├── sddm/                     # SDDM Qt 6 target and adapter
├── lockscreen/               # Plasma 6 KScreenLocker target and adapter
└── wallpaper/                # Reserved for the wallpaper/screensaver target
```

The `PavverTheme` entries inside the targets are relative development
symlinks. Their installers dereference those links, so every installed target
is a standalone package and does not depend on this source tree.

## Appearance

Edit [`shared/PavverTheme/Theme.qml`](shared/PavverTheme/Theme.qml) to
customize the complete family. For example, changing `clockText` changes the
clock color in every target:

```qml
property color clockText: "#ff3030"
```

The same file contains brand colors, text and surface colors, action states,
font source, radii, button dimensions, and animation timings.

## Capability Contract

`AuthCard.qml` contains no direct SDDM or KScreenLocker calls. Targets provide
optional models and capabilities:

- a user model enables user selection;
- `allowManualUsername` enables manual login names;
- a session model enables session selection;
- `passwordlessMode` replaces password input with confirmation;
- power capability flags control action visibility;
- keyboard layout and Caps Lock state are supplied by the target adapter.

System operations are exposed as QML signals. `SddmBackend.qml` and
`LockScreenBackend.qml` are the only components that access platform APIs.

## Development Tests

```bash
qml6 shared/demo/Preview.qml
qml6 shared/demo/Preview.qml -- --compact
```

```bash
cd sddm
qml6 demo/Preview.qml
sddm-greeter-qt6 --test-mode --theme .
```

```bash
cd lockscreen
qml6 demo/Preview.qml
qml6 demo/PasswordlessPreview.qml
```

Run the target installers from their respective directories when the visual
and integration tests are complete.
