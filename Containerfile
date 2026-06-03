FROM docker.io/library/alpine:latest@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS build

COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:e4d74fa741ce9ff03a6a60440a58c31cef6c0fc145182357d243580ba239f810 / /out/bluefin/usr/share

RUN apk add just curl

# artwork repo points to ~/.local/share for metadata
RUN mkdir -p /out/bluefin/usr/share/backgrounds/bluefin && \
  mv /out/bluefin/usr/share/*.jxl /out/bluefin/usr/share/*.xml /out/bluefin/usr/share/backgrounds/bluefin && \
  sed -i 's|~\/\.local\/share|\/usr\/share|' /out/bluefin/usr/share/backgrounds/bluefin/*.xml /out/bluefin/usr/share/gnome-background-properties/*.xml

RUN install -d /out/shared/usr/share/bash-completion/completions /out/shared/usr/share/zsh/site-functions /out/shared/usr/share/fish/vendor_completions.d/ && \
  just --completions bash | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/bash-completion/completions/ujust && \
  just --completions zsh | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/zsh/site-functions/_ujust && \
  just --completions fish | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/fish/vendor_completions.d/ujust.fish

RUN curl -fsSLo tmp/game-devices-udev-1.0.tar.gz https://codeberg.org/fabiscafe/game-devices-udev/archive/1.0.tar.gz && \
    echo "642315c110f427d0765abe66369f3080604c3fb7243c07d1aa77303b31f6dc6d  tmp/game-devices-udev-1.0.tar.gz" | sha256sum -c && \
    tar xzvf tmp/game-devices-udev-1.0.tar.gz -C tmp/ && \
    for f in tmp/game-devices-udev/src/*.rules; do \
      install -Dpm0644 "$f" "out/shared/usr/lib/udev/rules.d/71-${f##*/}"; \
    done && \
  curl -fsSLo /out/shared/usr/lib/udev/rules.d/70-u2f.rules https://raw.githubusercontent.com/Yubico/libfido2/b974e7cf2ee7392134cc12c08b76a068cf250dd8/udev/70-u2f.rules && \
    echo "eb5ab4db095e5bbc841b023ad3281a22f6d86fefccfaae06fc3f0e1db6cf8152  /out/shared/usr/lib/udev/rules.d/70-u2f.rules" | sha256sum -c

FROM scratch AS ctx
COPY /aurorafin-shared/system_files/shared /system_files/shared/
COPY /bluefin-branding/system_files /system_files/bluefin
COPY /system_files/bluefin /system_files/bluefin
COPY /aurorafin-shared/system_files/nvidia /system_files/nvidia/

COPY --from=build /out/shared /system_files/shared
COPY --from=build /out/bluefin /system_files/bluefin
