FROM docker.io/library/alpine:latest AS build

COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest / /out/bluefin/usr/share

RUN apk add just

# artwork repo points to ~/.local/share for metadata
RUN mkdir -p /out/bluefin/usr/share/backgrounds/bluefin && \
  mv /out/bluefin/usr/share/*.jxl /out/bluefin/usr/share/*.xml /out/bluefin/usr/share/backgrounds/bluefin && \
  sed -i 's|~\/\.local\/share|\/usr\/share|' /out/bluefin/usr/share/backgrounds/bluefin/*.xml /out/bluefin/usr/share/gnome-background-properties/*.xml

RUN install -d /out/shared/usr/share/bash-completion/completions /out/shared/usr/share/zsh/site-functions /out/shared/usr/share/fish/vendor_completions.d/ && \
  just --completions bash | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/bash-completion/completions/ujust && \
  just --completions zsh | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/zsh/site-functions/_ujust && \
  just --completions fish | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/fish/vendor_completions.d/ujust.fish

FROM scratch AS ctx
COPY /system_files/shared /system_files/shared/
COPY /system_files/bluefin /system_files/bluefin

COPY --from=build /out/shared /system_files/shared
COPY --from=build /out/bluefin /system_files/bluefin
