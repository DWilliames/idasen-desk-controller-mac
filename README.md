![App icon](/images/Icon.png)

# Idåsen Desk Controller – Mac app

A Mac Status Bar application for controlling your [IKEA IDÅSEN (Linak) sit/stand desk](https://www.ikea.com/au/en/p/idasen-desk-sit-stand-black-beige-s79280979/).

If you find this at least a little bit useful:
* Star this project
* Shout the original author a cup of coffee via [PayPal](https://paypal.me/dtw/5)
* Follow him on Twitter [@davidwilliames](https://twitter.com/davidwilliames)

[**Download the latest release**](../../releases/latest)

---

![Animated example](/images/example.gif)

![Preferences example](/images/preferences_example.png)


## Why?

The best way I've found to get myself to use my sit/stand desk more is to remove as much friction around moving it as possible.

The Linak 'Desk Control' mobile app lets you set favourite positions — but then you need to open the app, and press **and hold** the up/down arrow until it gets into position. Having to hold the button the whole time was annoying, and I found myself changing height positions less.

I found a couple of different solutions across GitHub, but no truly native Mac apps. So this is one.

I'm already on my Mac while sitting/standing at my desk, so why not control the desk from here without needing the mobile app or the physical controller?


## Features

* Easy access from the Mac status bar
* View the current desk height
* Save sit/stand height positions
* Move up/down without holding the button
* Optional **automatic** sit/stand schedule, with a toggle to send a **notification** (with Stand / Sit action buttons) instead of moving the desk automatically
* Calibration offset for desks that report a position that doesn't match the real world
* Launch at login (toggleable in Preferences)
* AppleScript support (great for an [Alfred](https://www.alfredapp.com) workflow or Shortcuts)

![Status-bar example](/images/status_bar_example.png)


## Requirements

* Apple Silicon Mac (M1 or later)
* macOS 13 Ventura or newer

If you need an Intel build, the older 1.0.x releases still work on macOS 10.15+.


## Getting started

* [Download the latest release](../../releases/latest) and move `Desk Controller.app` to your `Applications` folder
* Double-click to open it
* It will show up in your status bar

If the release you downloaded is unsigned (no Apple Developer ID — typical for CI-built artifacts), macOS will mark it as quarantined. Remove the quarantine attribute once:

```sh
xattr -dr com.apple.quarantine "/Applications/Desk Controller.app"
```

To open Preferences either right-click the status-bar icon and click `Preferences`, or click the icon and then the gear icon in the bottom right. To quit, right-click the status-bar icon and click `Quit`.


## Stand reminders

Turn on the auto-stand schedule in Preferences to alternate sitting and standing on a fixed cycle: **Stand every** *N* minutes (sit duration), **Stand for** *M* minutes (stand duration), repeat. The status-bar icon turns blue while sitting and green while standing, and the popover shows a live countdown to the next transition.

If a scheduled move would arrive while you're idle longer than the **Activity timeout**, the stand-up is skipped (the sit-down still fires). If you'd rather decide for yourself, toggle **Notify instead of moving the desk** — the app posts a macOS notification at each transition with `Stand` / `Sit` action buttons that move the desk when you tap them.


## Troubleshooting

* Make sure no other phones / computers currently have one of the 'Desk Control' apps open and connected to your desk. If they do, simply quit that app and this Desk Controller app should work.
* The auto-discovery heuristic looks for the word "desk" (case-insensitive) in the Bluetooth device name. If you renamed your desk to something that doesn't contain "desk", rename it back using the Linak "Desk Control" app.
* `"Desk Controller.app" is damaged and can't be opened` — that's macOS's quarantine flag on an unsigned/CI-built download. Run the `xattr -dr com.apple.quarantine ...` command from the "Getting started" section.
* If it's still not finding your desk, try resetting the desk:
    1. Lower your desk as low as it goes.
    2. Hold the physical down button past the bottom; after a second or two it will jog down and back up.
    3. Hold the 'bluetooth' button on the front of the physical controller for a few seconds, until the blue light starts blinking.

---

## Interacting with AppleScript

You can talk to the app from AppleScript. Great for an [Alfred App](https://www.alfredapp.com) workflow, a Shortcut, or your own scripts.

#### Commands

`move "to-sit"`: Move to the saved sitting position

`move "to-stand"`: Move to the saved standing position

`move "up"`: Nudge the desk up a tiny bit

`move "down"`: Nudge the desk down a tiny bit

`move "120cm"`: Move to 120 cm (also works inside `move to "..."`)

`move "55in"`: Move to 55 inches (also works inside `move to "..."`)

`move "80"`: Move to 80 cm or 80 in depending on your Preferences

`move to "120cm"`: Original syntax — still supported

Example:

```applescript
tell application "Desk Controller"
    move "to-sit"
end tell
```


## Debug logging

The app has an opt-in file-based debug log for situations where something needs deeper diagnosis (BLE connection issues, button-handler timing, etc.). It's **off by default**.

Enable:

```sh
defaults write com.davidwilliames.Desk-Controller debugLoggingEnabled -bool true
```

Disable:

```sh
defaults write com.davidwilliames.Desk-Controller debugLoggingEnabled -bool false
```

While enabled, the app appends to:

```
~/Library/Containers/com.davidwilliames.Desk-Controller/Data/Library/Application Support/DeskControllerDebug/debug.log
```

The toggle takes effect immediately — no app restart needed.


## Building from source

```sh
git clone <this repository>
cd idasen-desk-controller-mac
open "Desk Controller.xcodeproj"
```

Requires Xcode 16+ on an Apple Silicon Mac.

CLI build:

```sh
xcodebuild -project "Desk Controller.xcodeproj" -scheme "Desk Controller" \
  -configuration Release -derivedDataPath build \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" build
```

Releases are produced automatically: pushing a `v*` tag triggers a GitHub Actions workflow that builds an ad-hoc-signed `.app`, zips it, and publishes it as a GitHub Release.


## Credits

* Original app by [David Williames](https://github.com/DWilliames).
* Auto-stand scheduling by Johan Eklund ([@meck](https://github.com/meck)).
* Swift Concurrency / @MainActor modernization and UI redesign by [@MartinRybergLaude](https://github.com/MartinRybergLaude).
* Position-offset bug fixes by [@ashumeet](https://github.com/ashumeet).
* AppleScript improvements and notifications by [@akucharczyk](https://github.com/akucharczyk).
* macOS 13+ port, CI/Release workflows, sit/stand cycle redesign, status-bar phase icon, popover countdown, and About window by [@marcobazzani](https://github.com/marcobazzani).


## License

See [LICENSE.md](LICENSE.md).
