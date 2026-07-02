# Developer Experience (DX)

Welcome to the **Developer Experience (DX)** in Project Bluefin! Bluefin provides an out-of-the-box, world-class cloud-native workstation. Rather than layering developer packages on the host system, we leverage **Developer Mode** to turn on developer tools in-place using Homebrew and Flatpaks.

---

## Developer Flatpaks (Exposed from Brewfiles)

Click any app name to open its installation card directly in Bazaar and install it onto your system:

### Core Developer Tools (Exposed from system-dx-flatpaks.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/org/gnome/Builder/18ce275bf2230a495c992e08b5fbf088/icons/128x128/org.gnome.Builder.png" width="48" height="48" style="margin-bottom: 8px;" alt="GNOME Builder">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">GNOME Builder</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Elegant, native GNOME IDE built for GTK4 development.</div>
    <a href="appstream://org.gnome.Builder" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/me/iepure/devtoolbox/640a058cc8ec23f49c5b63ac55b669d0/icons/128x128/me.iepure.devtoolbox.png" width="48" height="48" style="margin-bottom: 8px;" alt="Dev Toolbox">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Dev Toolbox</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Offline hub containing hashes, formatting, and conversion utilities.</div>
    <a href="appstream://me.iepure.devtoolbox" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/de/leopoldluley/Clapgrep/2c342b98ecd697635b29746840224f16/icons/128x128/de.leopoldluley.Clapgrep.png" width="48" height="48" style="margin-bottom: 8px;" alt="Clapgrep">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Clapgrep</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Highly responsive, visual search UI powered by ripgrep.</div>
    <a href="appstream://de.leopoldluley.Clapgrep" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/io/github/getnf.embellish/4abc21c0b6a1fad3d85d29fcaeb9afcc/icons/128x128/io.github.getnf.embellish.png" width="48" height="48" style="margin-bottom: 8px;" alt="Embellish">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Embellish</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Install and configure custom Nerd Fonts effortlessly.</div>
    <a href="appstream://io.github.getnf.embellish" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPGRlZnM+CiAgICA8IS0tIEJhY2tncm91bmQgcGxhdGUgZ3JhZGllbnQ6IGRhcmsgd2FybSBjaGFyY29hbCB0byBkZWVwIHNsYXRlIC0tPgogICAgPGxpbmVhckdyYWRpZW50IGlkPSJiZ0dyYWQiIHgxPSIwIiB5MT0iMCIgeDI9IjAiIHkyPSIxIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzJkMmEyNiIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0b3AtY29sb3I9IiMxODE2MTUiLz4KICAgIDwvbGluZWFyR3JhZGllbnQ+CiAgICAKICAgIDwhLS0gR29sZCB3b29kL2FjY2VudCBncmFkaWVudCAtLT4KICAgIDxsaW5lYXJHcmFkaWVudCBpZD0iZ29sZEdyYWQiIHgxPSIwIiB5MT0iMCIgeDI9IjAiIHkyPSIxIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iI2U4YTMxNyIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0b3AtY29sb3I9IiNhMDY0MGMiLz4KICAgIDwvbGluZWFyR3JhZGllbnQ+CgogICAgPCEtLSBCZWVyL0xpcXVpZCBncmFkaWVudCAoQW1iZXIgQWxlKSAtLT4KICAgIDxsaW5lYXJHcmFkaWVudCBpZD0iYmVlckdyYWQiIHgxPSIwIiB5MT0iMCIgeDI9IjAiIHkyPSIxIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iI2Y3YjczMSIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjUwJSIgc3RvcC1jb2xvcj0iI2ViOTgxMiIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0b3AtY29sb3I9IiNhODVhMDMiLz4KICAgIDwvbGluZWFyR3JhZGllbnQ+CiAgICAKICAgIDwhLS0gR2xhc3MgSGlnaGxpZ2h0IGdyYWRpZW50IC0tPgogICAgPGxpbmVhckdyYWRpZW50IGlkPSJnbGFzc0hpZ2hsaWdodCIgeDE9IjAiIHkxPSIwIiB4Mj0iMSIgeTI9IjAiPgogICAgICA8c3RvcCBvZmZzZXQ9IjAlIiBzdG9wLWNvbG9yPSIjZmZmZmZmIiBzdG9wLW9wYWNpdHk9IjAuNiIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjMwJSIgc3RvcC1jb2xvcj0iI2ZmZmZmZiIgc3RvcC1vcGFjaXR5PSIwLjEiLz4KICAgICAgPHN0b3Agb2Zmc2V0PSI3MCUiIHN0b3AtY29sb3I9IiNmZmZmZmYiIHN0b3Atb3BhY2l0eT0iMC4wIi8+CiAgICAgIDxzdG9wIG9mZnNldD0iMTAwJSIgc3RvcC1jb2xvcj0iI2ZmZmZmZiIgc3RvcC1vcGFjaXR5PSIwLjQiLz4KICAgIDwvbGluZWFyR3JhZGllbnQ+CgogICAgPCEtLSBGb2FtIGdyYWRpZW50IC0tPgogICAgPGxpbmVhckdyYWRpZW50IGlkPSJmb2FtR3JhZCIgeDE9IjAiIHkxPSIwIiB4Mj0iMCIgeTI9IjEiPgogICAgICA8c3RvcCBvZmZzZXQ9IjAlIiBzdG9wLWNvbG9yPSIjZmZmZmZmIi8+CiAgICAgIDxzdG9wIG9mZnNldD0iMTAwJSIgc3RvcC1jb2xvcj0iI2YxZjJmNiIvPgogICAgPC9saW5lYXJHcmFkaWVudD4KICAgIAogICAgPCEtLSBGb2FtIHNoYWRvdyAtLT4KICAgIDxmaWx0ZXIgaWQ9InNoYWRvdyIgeD0iLTEwJSIgeT0iLTEwJSIgd2lkdGg9IjEyMCUiIGhlaWdodD0iMTIwJSI+CiAgICAgIDxmZURyb3BTaGFkb3cgZHg9IjAiIGR5PSI0IiBzdGREZXZpYXRpb249IjQiIGZsb29kLWNvbG9yPSIjMDAwMDAwIiBmbG9vZC1vcGFjaXR5PSIwLjMiLz4KICAgIDwvZmlsdGVyPgogIDwvZGVmcz4KCiAgPCEtLSBSb3VuZGVkIGJhc2UgcGxhdGUgKEdOT01FIEFwcCBJY29uIFN0eWxlKSAtLT4KICA8cmVjdCB4PSI4IiB5PSI4IiB3aWR0aD0iMTEyIiBoZWlnaHQ9IjExMiIgcng9IjI2IiBmaWxsPSJ1cmwoI2JnR3JhZCkiIHN0cm9rZT0iIzExMGYwZSIgc3Ryb2tlLXdpZHRoPSIxLjUiIGZpbHRlcj0idXJsKCNzaGFkb3cpIi8+CiAgCiAgPCEtLSBPdXRlciBnbG93aW5nIGFjY2VudCByaW5nIC0tPgogIDxyZWN0IHg9IjExIiB5PSIxMSIgd2lkdGg9IjEwNiIgaGVpZ2h0PSIxMDYiIHJ4PSIyMyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ1cmwoI2dvbGRHcmFkKSIgc3Ryb2tlLXdpZHRoPSIyIiBvcGFjaXR5PSIwLjgiLz4KCiAgPCEtLSBCZWVyIE11ZyBHcm91cCAtLT4KICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgwLCA0KSI+CiAgICA8IS0tIE11ZyBIYW5kbGUgLS0+CiAgICA8cGF0aCBkPSJNIDgwIDUwIFEgMTAyIDUwIDEwMiA3MCBRIDEwMiA5MCA4MCA5MCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjZTFiMTJjIiBzdHJva2Utd2lkdGg9IjEyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIGZpbHRlcj0idXJsKCNzaGFkb3cpIi8+CiAgICA8cGF0aCBkPSJNIDgwIDUwIFEgMTAyIDUwIDEwMiA3MCBRIDEwMiA5MCA4MCA5MCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjZmJjNTMxIiBzdHJva2Utd2lkdGg9IjYiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPHBhdGggZD0iTSA4MCA1MCBRIDEwMiA1MCAxMDIgNzAgUSAxMDIgOTAgODAgOTAiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2ZmZmZmZiIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIG9wYWNpdHk9IjAuNCIvPgoKICAgIDwhLS0gTXVnIEJvZHkgKEFtYmVyIEJlZXIgR2xhc3MpIC0tPgogICAgPHJlY3QgeD0iMzYiIHk9IjQwIiB3aWR0aD0iNDgiIGhlaWdodD0iNTgiIHJ4PSIxMCIgZmlsbD0idXJsKCNiZWVyR3JhZCkiIHN0cm9rZT0iIzgzNGMwMyIgc3Ryb2tlLXdpZHRoPSIyIiBmaWx0ZXI9InVybCgjc2hhZG93KSIvPgoKICAgIDwhLS0gVmVydGljYWwgR2xhc3MgSGlnaGxpZ2h0cyAoUmlkZ2VzKSAtLT4KICAgIDxyZWN0IHg9IjQyIiB5PSI0NCIgd2lkdGg9IjgiIGhlaWdodD0iNTAiIHJ4PSI0IiBmaWxsPSIjZmZmZmZmIiBvcGFjaXR5PSIwLjE1Ii8+CiAgICA8cmVjdCB4PSI1NiIgeT0iNDQiIHdpZHRoPSI4IiBoZWlnaHQ9IjUwIiByeD0iNCIgZmlsbD0iI2ZmZmZmZiIgb3BhY2l0eT0iMC4yIi8+CiAgICA8cmVjdCB4PSI3MCIgeT0iNDQiIHdpZHRoPSI4IiBoZWlnaHQ9IjUwIiByeD0iNCIgZmlsbD0iI2ZmZmZmZiIgb3BhY2l0eT0iMC4xNSIvPgogICAgCiAgICA8IS0tIEN1cnZlZCBiYXNlIGhpZ2hsaWdodCAtLT4KICAgIDxwYXRoIGQ9Ik0gNDAgOTAgUSA2MCA5NSA4MCA5MCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjZmZmZmZmIiBzdHJva2Utd2lkdGg9IjMiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgb3BhY2l0eT0iMC4yNSIvPgoKICAgIDwhLS0gR2xhc3MgUmltIC8gVG9wIEhpZ2hsaWdodCAtLT4KICAgIDxyZWN0IHg9IjM2IiB5PSI0MCIgd2lkdGg9IjQ4IiBoZWlnaHQ9IjU4IiByeD0iMTAiIGZpbGw9Im5vbmUiIHN0cm9rZT0idXJsKCNnbGFzc0hpZ2hsaWdodCkiIHN0cm9rZS13aWR0aD0iMiIvPgoKICAgIDwhLS0gU3RhciAvIFNwYXJrbGUgb2YgZnJlc2huZXNzIC0tPgogICAgPHBhdGggZD0iTSAzMCAzNSBMIDMyIDQwIEwgMzcgNDIgTCAzMiA0NCBMIDMwIDQ5IEwgMjggNDQgTCAyMyA0MiBMIDI4IDQwIFoiIGZpbGw9IiNmYmM1MzEiIG9wYWNpdHk9IjAuOSIvPgogICAgCiAgICA8IS0tIEZvYW0gSGVhZCAoRmx1ZmZ5IHdoaXRlIGJ1YmJsZXMgb3ZlcmZsb3dpbmcpIC0tPgogICAgPCEtLSBTaGFkb3cgZm9yIHRoZSBmb2FtIC0tPgogICAgPGcgZmlsdGVyPSJ1cmwoI3NoYWRvdykiPgogICAgICA8Y2lyY2xlIGN4PSI0NCIgY3k9IjM4IiByPSIxMiIgZmlsbD0idXJsKCNmb2FtR3JhZCkiLz4KICAgICAgPGNpcmNsZSBjeD0iNjAiIGN5PSIzNCIgcj0iMTQiIGZpbGw9InVybCgjZm9hbUdyYWQpIi8+CiAgICAgIDxjaXJjbGUgY3g9Ijc2IiBjeT0iMzgiIHI9IjEyIiBmaWxsPSJ1cmwoI2ZvYW1HcmFkKSIvPgogICAgICA8Y2lyY2xlIGN4PSI1MCIgY3k9IjI4IiByPSIxMSIgZmlsbD0idXJsKCNmb2FtR3JhZCkiLz4KICAgICAgPGNpcmNsZSBjeD0iNjgiIGN5PSIyOCIgcj0iMTEiIGZpbGw9InVybCgjZm9hbUdyYWQpIi8+CiAgICAgIDxjaXJjbGUgY3g9IjM2IiBjeT0iNDQiIHI9IjgiIGZpbGw9InVybCgjZm9hbUdyYWQpIi8+CiAgICAgIDxjaXJjbGUgY3g9Ijg0IiBjeT0iNDQiIHI9IjgiIGZpbGw9InVybCgjZm9hbUdyYWQpIi8+CiAgICA8L2c+CgogICAgPCEtLSBGb2FtIElubmVyIEhpZ2hsaWdodHMgKGdpdmluZyBkZXB0aCB0byBidWJibGVzKSAtLT4KICAgIDxjaXJjbGUgY3g9IjQyIiBjeT0iMzYiIHI9IjEwIiBmaWxsPSIjZmZmZmZmIiBvcGFjaXR5PSIwLjYiLz4KICAgIDxjaXJjbGUgY3g9IjU4IiBjeT0iMzIiIHI9IjEyIiBmaWxsPSIjZmZmZmZmIiBvcGFjaXR5PSIwLjYiLz4KICAgIDxjaXJjbGUgY3g9Ijc0IiBjeT0iMzYiIHI9IjEwIiBmaWxsPSIjZmZmZmZmIiBvcGFjaXR5PSIwLjYiLz4KICAgIDxjaXJjbGUgY3g9IjQ4IiBjeT0iMjYiIHI9IjkiIGZpbGw9IiNmZmZmZmYiIG9wYWNpdHk9IjAuNiIvPgogICAgPGNpcmNsZSBjeD0iNjYiIGN5PSIyNiIgcj0iOSIgZmlsbD0iI2ZmZmZmZiIgb3BhY2l0eT0iMC42Ii8+CiAgICAKICAgIDwhLS0gTGl0dGxlIGZsb2F0aW5nIGZvYW0gYnViYmxlcyAtLT4KICAgIDxjaXJjbGUgY3g9IjMyIiBjeT0iMjIiIHI9IjMiIGZpbGw9IiNmZmZmZmYiLz4KICAgIDxjaXJjbGUgY3g9Ijg4IiBjeT0iMjgiIHI9IjQiIGZpbGw9IiNmZmZmZmYiLz4KICAgIDxjaXJjbGUgY3g9Ijc4IiBjeT0iMTgiIHI9IjIiIGZpbGw9IiNmZmZmZmYiLz4KICA8L2c+Cjwvc3ZnPgo=" width="48" height="48" style="margin-bottom: 8px;" alt="Tavern">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Tavern</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">A lightweight flatpak application manager and companion tool.</div>
    <a href="appstream://com.github.tuna_os.Tavern" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

### Kubernetes & Container Management (Exposed from cncf.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/io/podman_desktop/PodmanDesktop/569123bc656b5391894690837db722c3/icons/128x128/io.podman_desktop.PodmanDesktop.png" width="48" height="48" style="margin-bottom: 8px;" alt="Podman Desktop">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Podman Desktop</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Graphical management tool for containers, pods, and volumes.</div>
    <a href="appstream://io.podman_desktop.PodmanDesktop" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/io/kinvolk/Headlamp/b1795a2d5e9a6cb6b7b94b48acd842ea/icons/128x128/io.kinvolk.Headlamp.png" width="48" height="48" style="margin-bottom: 8px;" alt="Headlamp">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Headlamp</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">A beautiful, highly extensible dashboard for your Kubernetes clusters.</div>
    <a href="appstream://io.kinvolk.Headlamp" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/dev/k8slens/OpenLens/0deca74adfe62ba9e8176f860db1b6a4/icons/128x128/dev.k8slens.OpenLens.png" width="48" height="48" style="margin-bottom: 8px;" alt="OpenLens">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">OpenLens</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Powerful, fully featured desktop IDE for Kubernetes workflows.</div>
    <a href="appstream://dev.k8slens.OpenLens" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

### System Utilities (Exposed from system-flatpaks.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/com/github/tchx84.Flatseal/462bde383c024a52b3132ae3df79704a/icons/128x128/com.github.tchx84.Flatseal.png" width="48" height="48" style="margin-bottom: 8px;" alt="Flatseal">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Flatseal</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Graphical permission editor for sandboxed Flatpak applications.</div>
    <a href="appstream://com.github.tchx84.Flatseal" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/io/github/flattool.Warehouse.desktop/e0c756d408a1a2aa2653a7f78004e6b4/icons/128x128/io.github.flattool.Warehouse.desktop.png" width="48" height="48" style="margin-bottom: 8px;" alt="Warehouse">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Warehouse</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Manage installed Flatpaks, manage user data, and clean up orphan runtimes.</div>
    <a href="appstream://io.github.flattool.Warehouse" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/com/mattjakeman/ExtensionManager/325202b426bf0272893528da55c472e4/icons/128x128/com.mattjakeman.ExtensionManager.png" width="48" height="48" style="margin-bottom: 8px;" alt="Extension Manager">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Extension Manager</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Search, install, and configure GNOME shell extensions.</div>
    <a href="appstream://com.mattjakeman.ExtensionManager" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/io/missioncenter/MissionCenter/859f0a40abb2053f905c69a6b77ac1ce/icons/128x128/io.missioncenter.MissionCenter.png" width="48" height="48" style="margin-bottom: 8px;" alt="Mission Center">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Mission Center</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Native GTK system monitor for hardware resource tracking.</div>
    <a href="appstream://io.missioncenter.MissionCenter" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/io/github/flattool.Ignition/c49a951d14b6979b9ddc6662b026dfa7/icons/128x128/io.github.flattool.Ignition.png" width="48" height="48" style="margin-bottom: 8px;" alt="Ignition">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Ignition</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Setup and configure your Flatpak permissions and configurations.</div>
    <a href="appstream://io.github.flattool.Ignition" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

### AI & Machine Learning (Exposed from ai-tools.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/ai/jan/Jan/77d1323d14299cb2da05004dc9ee69bf/icons/128x128/ai.jan.Jan.png" width="48" height="48" style="margin-bottom: 8px;" alt="Jan AI">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Jan AI</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Run open-source LLMs locally on your workstation with a gorgeous native UI.</div>
    <a href="appstream://ai.jan.Jan" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

### GNOME Circle & Desktop Enhancements (Exposed from full-desktop.Brewfile)

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin-top: 12px; margin-bottom: 20px;">
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/be/alexandervanhee/gradia/ff2ae6a0dd47a7712e804704e5eeb323/icons/128x128/be.alexandervanhee.gradia.png" width="48" height="48" style="margin-bottom: 8px;" alt="Gradia">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Gradia</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Dynamic custom styling and CSS gradient compiler for GTK.</div>
    <a href="appstream://be.alexandervanhee.gradia" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/app/drey/Damask/bcb487f7abaecf056fd4dea104831711/icons/128x128/app.drey.Damask.png" width="48" height="48" style="margin-bottom: 8px;" alt="Damask">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Damask</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Elegant automatic wallpaper scheduler and rotater.</div>
    <a href="appstream://app.drey.Damask" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/app/drey/Elastic/7a314469673939e32e09f7937c6e5998/icons/128x128/app.drey.Elastic.png" width="48" height="48" style="margin-bottom: 8px;" alt="Elastic">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Elastic</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Design spring physics and curves for native GTK4 animations.</div>
    <a href="appstream://app.drey.Elastic" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/app/fotema/Fotema/15af3e4e200c0fde7e8bb729bda4ceb8/icons/128x128/app.fotema.Fotema.png" width="48" height="48" style="margin-bottom: 8px;" alt="Fotema">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Fotema</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Modern, privacy-first photo gallery and viewer.</div>
    <a href="appstream://app.fotema.Fotema" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/io/gitlab/adhami3310.Impression/8edf94dc739213c8ef592ca0cafd3f9e/icons/128x128/io.gitlab.adhami3310.Impression.png" width="48" height="48" style="margin-bottom: 8px;" alt="Impression">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Impression</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">Write OCI images and ISOs to USB drives with absolute simplicity.</div>
    <a href="appstream://io.gitlab.adhami3310.Impression" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
  <div style="flex: 1 1 200px; max-width: 220px; border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; align-items: center; text-align: center; background-color: rgba(128, 128, 128, 0.05); box-sizing: border-box;">
    <img src="https://dl.flathub.org/media/it/mijorus/smile/7a368f57897c656f5a36e8bf54cfc4b9/icons/128x128/it.mijorus.smile.png" width="48" height="48" style="margin-bottom: 8px;" alt="Smile">
    <div style="font-weight: bold; font-size: 1.0em; margin-bottom: 4px;">Smile</div>
    <div style="font-size: 0.8em; line-height: 1.25em; margin-bottom: 12px; flex-grow: 1; opacity: 0.85;">The best native emoji picker for the GNOME desktop.</div>
    <a href="appstream://it.mijorus.smile" style="text-decoration: none; background-color: #3584e4; color: white; padding: 4px 12px; border-radius: 4px; font-weight: bold; font-size: 0.85em; display: inline-block; width: 85%;">Install</a>
  </div>
</div>

---

## Command-Line Utilities (Homebrew)

Bluefin integrates Homebrew directly on the host to provide lightning-fast shell environments. Click any of the CLI tools to explore their Homebrew Formula page, or run the command below to install them:

```bash
brew install gh just uv neovim k9s lima
```

### Essential CLI Utilities (Exposed from system-cli.Brewfile & cli.Brewfile)
*   [gh](https://formulae.brew.sh/formula/gh) — GitHub's official command-line CLI.
*   [just](https://formulae.brew.sh/formula/just) — Fast and modern project task runner.
*   [uv](https://formulae.brew.sh/formula/uv) — Blazing-fast Python package and workspace manager.
*   [neovim](https://formulae.brew.sh/formula/neovim) — Vim-fork focused on extensibility and usability.
*   [k9s](https://formulae.brew.sh/formula/k9s) — Terminal-based UI for interacting with Kubernetes clusters.
*   [lima](https://formulae.brew.sh/formula/lima) — Linux Virtual Machines with automatic file sharing and port forwarding.

### Modern Shell Tools
*   [atuin](https://formulae.brew.sh/formula/atuin) — Magical shell history database.
*   [bat](https://formulae.brew.sh/formula/bat) — A cat clone with syntax highlighting and Git integration.
*   [chezmoi](https://formulae.brew.sh/formula/chezmoi) — Securely manage dotfiles across multiple machines.
*   [direnv](https://formulae.brew.sh/formula/direnv) — Shell extension to load/unload environment variables per directory.
*   [eza](https://formulae.brew.sh/formula/eza) — A modern, feature-rich replacement for 'ls'.
*   [fd](https://formulae.brew.sh/formula/fd) — Simple, fast, and user-friendly alternative to 'find'.
*   [ripgrep](https://formulae.brew.sh/formula/ripgrep) — High-performance regex search utility.
*   [yq](https://formulae.brew.sh/formula/yq) — Portable command-line YAML/XML/JSON processor.
*   [zoxide](https://formulae.brew.sh/formula/zoxide) — Smarter directory navigation tracker.
*   [mise](https://formulae.brew.sh/formula/mise) — Polyglot development tool, environment variable, and task runner.

### Cloud Native & CNCF Ecosystem (Exposed from cncf.Brewfile)
*   [kubectl](https://formulae.brew.sh/formula/kubernetes-cli) — Command-line tool for controlling Kubernetes clusters.
*   [helm](https://formulae.brew.sh/formula/helm) — Kubernetes package manager.
*   [kind](https://formulae.brew.sh/formula/kind) — Run local Kubernetes clusters using Docker container nodes.
*   [minikube](https://formulae.brew.sh/formula/minikube) — Run a single-node local Kubernetes cluster.
*   [argo](https://formulae.brew.sh/formula/argo) — Workflow engine for Kubernetes.
*   [argocd](https://formulae.brew.sh/formula/argocd) — Declarative continuous delivery engine for Kubernetes.
*   [virtctl](https://formulae.brew.sh/formula/virtctl) — CLI utility for managing KubeVirt virtual machines.
*   [k8sgpt](https://formulae.brew.sh/formula/k8sgpt) — Give your Kubernetes cluster superpowers via AI diagnostics.

---

## Product Lore & Design Principles

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

Project Bluefin commits to creating an ergonomic developer environment where the system gets out of the way. All tools are sandboxed, isolated, reproducible, and blazing fast.

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Project Bluefin's **Developer Experience (DX)** is crafted specifically to empower modern engineers with cloud-native primitives, reproducible terminal environments, and robust container workflows, making it the premier workstation operating system.
