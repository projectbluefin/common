# Bluefin animated wallpaper with Hidamari

Bluefin ships an original 1080p looping movie for Hidamari. On a Bluefin
image containing the movie, install the **Video Wallpaper** bundle from
ChairLift’s Applications page, then copy the movie into Hidamari’s video
folder as described below.

## Copy the movie

Run these commands in a host terminal as your normal user (without `sudo`):

```bash
videos_dir="$(xdg-user-dir VIDEOS)" &&
    test -n "$videos_dir" &&
    mkdir -p "$videos_dir/Hidamari" &&
    cp -i /usr/share/backgrounds/bluefin/bluefin-hidamari.webm \
        "$videos_dir/Hidamari/bluefin-hidamari.webm"
```

This uses your configured Videos directory, including localized names and
paths containing spaces. If a copy already exists, `cp -i` asks before
replacing it. If the source file is missing, update to a Bluefin image that
includes the movie, reboot into it, and try again.

Open (or reopen) Hidamari and select `bluefin-hidamari.webm` under **Local
Video**, then apply it to your display.

The [Hidamari Flatpak manifest](https://github.com/flathub/io.github.jeffshee.Hidamari/blob/master/io.github.jeffshee.Hidamari.json)
grants access to the `Hidamari` subfolder of your Videos directory. A copy is
needed because the system background directory is outside that permission;
a symlink to the original file will not work. No Flatpak permission override
is needed.

To remove the movie from Hidamari, choose another wallpaper, then delete
`bluefin-hidamari.webm` from that Videos subfolder. The system copy remains
available if you want to use it again.

For render settings and regeneration instructions, see the
[Hidamari wallpaper maintainer guide](skills/hidamari-wallpaper.md).
