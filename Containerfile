FROM docker.io/library/golang:alpine@sha256:3ad57304ad93bbec8548a0437ad9e06a455660655d9af011d58b993f6f615648 AS motd-build
RUN apk add git && \
    git clone https://github.com/projectbluefin/motd /src && \
    git -C /src checkout 405e86c532aed42931b2d398e2761c24b70e978c
WORKDIR /src
RUN go build -ldflags="-s -w" -o /umotd .

FROM docker.io/library/alpine:latest@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS build

COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:e4d74fa741ce9ff03a6a60440a58c31cef6c0fc145182357d243580ba239f810 / /out/bluefin/usr/share

RUN apk add just curl libjxl-tools

# artwork repo points to ~/.local/share for metadata
RUN mkdir -p /out/bluefin/usr/share/backgrounds/bluefin && \
  mv /out/bluefin/usr/share/*.jxl /out/bluefin/usr/share/*.xml /out/bluefin/usr/share/backgrounds/bluefin && \
  sed -i 's|~\/\.local\/share|\/usr\/share|' /out/bluefin/usr/share/backgrounds/bluefin/*.xml /out/bluefin/usr/share/gnome-background-properties/*.xml

RUN install -d /out/shared/usr/share/bash-completion/completions /out/shared/usr/share/zsh/site-functions /out/shared/usr/share/fish/vendor_completions.d/ && \
  just --completions bash | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/bash-completion/completions/ujust && \
  just --completions zsh | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/zsh/site-functions/_ujust && \
  just --completions fish | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/fish/vendor_completions.d/ujust.fish

# Fetch game-devices-udev rules as individual raw files at a fixed commit SHA.
# Codeberg/Gitea archive tarballs are generated on demand and their checksums
# drift across infra changes, so per-file raw fetches with sha256 pins are used
# instead (same pattern as the Yubico 70-u2f.rules fetch below).
RUN install -d /tmp/gdu-rules /out/shared/usr/lib/udev/rules.d && \
    cd /tmp/gdu-rules && \
    { \
      echo "e48e973a533fb6ff81a2bdb6d4588f2234c18135e3148842a4bb6fdf7f90a1a7  8bitdo-gdu.rules"; \
      echo "996ea3c3f94bdfaf5182c913e8708f4524c910b77faf8ca3312e49fa15bdb50e  alpha_imaging_technology_co-gdu.rules"; \
      echo "7cb7db5d13b9965e6c80dae79f388b37c78f4fb6de617c5680ecafc21edf8d61  astro_gaming-gdu.rules"; \
      echo "c9cfaaecf6dc92174aee33fdfbe6f085930f45d200eb109405431d661a6f8167  betop-gdu.rules"; \
      echo "92da3b11898b456f901758bc79209850e21a87c1ecb612d5fed24e9a22ec384e  bigscreen-gdu.rules"; \
      echo "74978426606903ea593f3e0fb3917ed222eb05d48223bcd409372510977ec145  cypress_semiconductor_corp-gdu.rules"; \
      echo "7f5a375be50d1cd6070b4d0246e95eacfe3e3de6a6185209872b9ca00033cad1  google-gdu.rules"; \
      echo "eba1bcabf1a7df7ce4508cda25f36d1dd07033bcc89b023ccbcc0b7e80b68007  hori-gdu.rules"; \
      echo "5e19844e8a7d33db171d29370f736db0b19bb5e98dfb6f3e3136018e6b17399e  htc-gdu.rules"; \
      echo "1ff45a458e1928f778635518895a0cb27cb14a4901e74ee4bf764760aaef52e3  logitech-gdu.rules"; \
      echo "b903659ef447e81085ca5df2e009baa4841f5396b4e73bf2e644be83f0d23dd3  mad_catz-gdu.rules"; \
      echo "d28fd8a7660c6ab9a4b4f8590c9f4229034517c4d6ed9f209ce802022c7f3170  microsoft-gdu.rules"; \
      echo "3a8fc67400a453944e28c259a27213ea71b186c538ade7fb062fdc5f9558c2b2  nacon-gdu.rules"; \
      echo "3101166f9b044b5495706c8012e185fc55a13f1c71b04775be94f5094f6ef682  nintendo-gdu.rules"; \
      echo "c2fb9df8927b23795370b42410ec986d0ba35273498ec2d84976486f72801751  nvidia-gdu.rules"; \
      echo "8a771b73d3cd1b4e94c99c97ccc0df22cf4cba8cecdcbe7e71e99e14b11fba6b  pdp-gdu.rules"; \
      echo "9ed2b3130a4b496df120ebd6532ba119c51db84b8c13b2a1a73be9ac01d79f30  personal_communication_systems_inc-gdu.rules"; \
      echo "b1b8aadc84849868e2db474d0aa8f5b7b0a560054fdabc4b6bbd5d69660ee2ff  pid_codes-gdu.rules"; \
      echo "4f230ea9cf4d27e5cfbf7665c060cd7011bd2626ee417434e9acc4914928370b  powera-gdu.rules"; \
      echo "f327d9d8f97d9a90312c4b22bf855c06f3ea61cff13c6c30cab6181a2078134d  raspberry_pi_ltd-gdu.rules"; \
      echo "a28520e485cb899d5dbefcb77b22e4e5820090a8f6f7c0530442d7add65f0335  razer-gdu.rules"; \
      echo "a8a64b7edf4c79da74394f8734eb6d6c466804b24aee83dc6d4fd7b020e9f5a2  sony-gdu.rules"; \
      echo "ca4b097607f666cf1b127fd6a20e241550ad7e6c22cf551795441c3ce747cbc6  thrustmaster-gdu.rules"; \
      echo "5183445ebd71af6e44353671e64fa885e619b64fd3c3eaf66af9569b038f1fa1  uinput-dev-early-creation.rules"; \
      echo "139f1b25429aa87786c1175b68fd70c5efe8babd6cbd39a7c06949fb4ee6c100  valve-gdu.rules"; \
      echo "a10746e36f240795bff096baa2b93e4885d99a281d216027f148642503e65d9f  vkb_sim-gdu.rules"; \
      echo "4db215f77201f1c2346a513cd1aea077eaf0805887100d9c05c9ae0527d6a171  zeroplus_technology_corporation-gdu.rules"; \
    } > checksums.txt && \
    for file in $(awk '{print $2}' checksums.txt); do \
      curl -fsSLo "$file" "https://codeberg.org/fabiscafe/game-devices-udev/raw/aaaf684043b33a330630335a3782b02ecf87a52e/src/$file"; \
    done && \
    sha256sum -c checksums.txt && \
    for f in *.rules; do install -Dpm0644 "$f" "/out/shared/usr/lib/udev/rules.d/71-$f"; done && \
  curl -fsSLo /out/shared/usr/lib/udev/rules.d/70-u2f.rules https://raw.githubusercontent.com/Yubico/libfido2/b974e7cf2ee7392134cc12c08b76a068cf250dd8/udev/70-u2f.rules && \
    echo "eb5ab4db095e5bbc841b023ad3281a22f6d86fefccfaae06fc3f0e1db6cf8152  /out/shared/usr/lib/udev/rules.d/70-u2f.rules" | sha256sum -c

# Convert Bazaar JXL banners to PNG to prevent stable Bazaar v0.8.2 from crashing
COPY bluefin-branding/system_files/etc/bazaar /tmp/bazaar-banners
RUN set -e && mkdir -p /out/bluefin/etc/bazaar && \
    for f in /tmp/bazaar-banners/*.jxl; do \
      name=$(basename "$f" .jxl); \
      djxl "$f" "/out/bluefin/etc/bazaar/${name}.png" --color_space=sRGB; \
    done

COPY --from=motd-build /umotd /out/shared/usr/bin/umotd

FROM scratch AS ctx
COPY /system_files/shared /system_files/shared/
COPY /bluefin-branding/system_files /system_files/bluefin
COPY /system_files/bluefin /system_files/bluefin
COPY /system_files/nvidia /system_files/nvidia/

COPY --from=build /out/shared /system_files/shared
COPY --from=build /out/bluefin /system_files/bluefin
