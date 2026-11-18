pref("gfx.webrender.all", true);
pref("media.hardware-video-decoding.force-enabled", true);
// xdg-native-messaging-proxy is disabled by default in Firefox; enable it so
// Flatpak Firefox can reach the host proxy (https://phabricator.services.mozilla.com/D277804)
pref("widget.use-xdg-desktop-portal.native-messaging-proxy", 2);
