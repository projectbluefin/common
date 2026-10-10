FROM docker.io/library/golang:alpine@sha256:738d1cf061836894ff6bb8c33881080ac66de8cf0586615012a0c8f592649cfa AS umotd-build
RUN apk add git && \
    git clone https://github.com/projectbluefin/umotd /src && \
    git -C /src checkout 97520c61e8fca7eae7359bf3d329542078f17412
WORKDIR /src
RUN go build -ldflags="-s -w" -o /umotd .

FROM docker.io/library/golang:alpine@sha256:738d1cf061836894ff6bb8c33881080ac66de8cf0586615012a0c8f592649cfa AS uwelcome-build
RUN apk add git && \
    git clone https://github.com/projectbluefin/uwelcome /src && \
    git -C /src checkout d260ccbb56db820f78b0b2a18b07c1a213918ce1
WORKDIR /src
RUN go build -ldflags="-s -w" -o /uwelcome .

FROM docker.io/library/alpine:latest@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 AS build

COPY --from=ghcr.io/projectbluefin/bluefin-wallpapers-gnome:latest@sha256:df4902d0db359d93bcbfd44bad98a2bfe62743b5189e11af5c221c2f5d1eb9a7 / /out/bluefin/usr/share

RUN apk add just curl

# ChairLift ships only as a user-scoped Homebrew cask, which cannot install
# root-owned files. Install the pkexec helper, its PolicyKit policy and the
# three GSettings schemas from the release archive so every image gets them
# from common; the composed image runs glib-compile-schemas after overlaying
# system_files. The release's checksums.txt is verified against its Sigstore
# bundle, signed by ChairLift's release workflow for exactly this tag, and the
# archive against its checksums.txt entry, so a bump changes CHAIRLIFT_RELEASE only.
ARG CHAIRLIFT_RELEASE=v26.10.4
ARG TARGETARCH
COPY --from=ghcr.io/sigstore/cosign/cosign:v3.1.3@sha256:9e5c2f2edc34351160407ca3416c61855bdf9403c3c5936e0f0be7fc261611b8 /ko-app/cosign /usr/local/bin/cosign
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64|arm64) ;; \
      *) echo "no ChairLift release archive for TARGETARCH '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    version="${CHAIRLIFT_RELEASE#v}"; \
    archive="chairlift_${version}_linux_${TARGETARCH}.tar.gz"; \
    install -d /tmp/chairlift-release; \
    cd /tmp/chairlift-release; \
    for asset in checksums.txt checksums.txt.sigstore.json "$archive"; do \
      curl --fail --silent --show-error --location --retry 5 --retry-all-errors --retry-delay 2 \
        --output "$asset" \
        "https://github.com/projectbluefin/chairlift/releases/download/${CHAIRLIFT_RELEASE}/${asset}"; \
    done; \
    cosign verify-blob --bundle checksums.txt.sigstore.json \
      --certificate-identity "https://github.com/projectbluefin/chairlift/.github/workflows/release.yml@refs/tags/${CHAIRLIFT_RELEASE}" \
      --certificate-oidc-issuer https://token.actions.githubusercontent.com \
      checksums.txt; \
    awk -v archive="$archive" 'NF == 2 && $2 == archive' checksums.txt > "$archive.sha256"; \
    if [ "$(wc -l < "$archive.sha256")" -ne 1 ]; then \
      echo "checksums.txt has no single entry for $archive" >&2; exit 1; \
    fi; \
    sha256sum -c "$archive.sha256"; \
    install -d /tmp/chairlift; \
    tar -xzf "$archive" -C /tmp/chairlift \
      chairlift-helper \
      data/io.projectbluefin.chairlift.ublue.policy \
      data/io.projectbluefin.chairlift.livery.gschema.xml \
      data/io.projectbluefin.chairlift.updates.gschema.xml \
      data/io.projectbluefin.chairlift.firstrun.gschema.xml; \
    policy=/tmp/chairlift/data/io.projectbluefin.chairlift.ublue.policy; \
    grep -qF '<annotate key="org.freedesktop.policykit.exec.path">/usr/bin/chairlift-helper</annotate>' "$policy"; \
    if grep -F 'org.freedesktop.policykit.exec.path' "$policy" | grep -vqF '>/usr/bin/chairlift-helper<'; then \
      echo "ChairLift policy authorizes a helper other than /usr/bin/chairlift-helper" >&2; exit 1; \
    fi; \
    install -Dm0755 /tmp/chairlift/chairlift-helper /out/shared/usr/bin/chairlift-helper; \
    install -Dm0644 "$policy" /out/shared/usr/share/polkit-1/actions/io.projectbluefin.chairlift.ublue.policy; \
    install -Dm0644 /tmp/chairlift/data/io.projectbluefin.chairlift.livery.gschema.xml /out/shared/usr/share/glib-2.0/schemas/io.projectbluefin.chairlift.livery.gschema.xml; \
    install -Dm0644 /tmp/chairlift/data/io.projectbluefin.chairlift.updates.gschema.xml /out/shared/usr/share/glib-2.0/schemas/io.projectbluefin.chairlift.updates.gschema.xml; \
    install -Dm0644 /tmp/chairlift/data/io.projectbluefin.chairlift.firstrun.gschema.xml /out/shared/usr/share/glib-2.0/schemas/io.projectbluefin.chairlift.firstrun.gschema.xml

# Artwork repo points to ~/.local/share for metadata
RUN mkdir -p /out/bluefin/usr/share/backgrounds/bluefin && \
  mv /out/bluefin/usr/share/*.jxl /out/bluefin/usr/share/*.svg /out/bluefin/usr/share/*.xml /out/bluefin/usr/share/backgrounds/bluefin && \
  sed -i 's|~\/\.local\/share|\/usr\/share|' /out/bluefin/usr/share/backgrounds/bluefin/*.xml /out/bluefin/usr/share/gnome-background-properties/*.xml

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
      curl --fail --silent --show-error --location --retry 5 --retry-all-errors --retry-delay 2 \
        --output "$file" "https://codeberg.org/fabiscafe/game-devices-udev/raw/aaaf684043b33a330630335a3782b02ecf87a52e/src/$file"; \
    done && \
    sha256sum -c checksums.txt && \
    for f in *.rules; do install -Dpm0644 "$f" "/out/shared/usr/lib/udev/rules.d/71-$f"; done && \
  curl -fsSLo /out/shared/usr/lib/udev/rules.d/70-u2f.rules https://raw.githubusercontent.com/Yubico/libfido2/b974e7cf2ee7392134cc12c08b76a068cf250dd8/udev/70-u2f.rules && \
    echo "eb5ab4db095e5bbc841b023ad3281a22f6d86fefccfaae06fc3f0e1db6cf8152  /out/shared/usr/lib/udev/rules.d/70-u2f.rules" | sha256sum -c

COPY --from=umotd-build /umotd /out/shared/usr/bin/umotd
COPY --from=uwelcome-build /uwelcome /out/shared/usr/bin/uwelcome

# Ujust gate: the tailored completions checked into system_files/shared must bind `ujust`
# & /out/shared must not ship files at the same paths to avoid shadow by ctx overlay.
COPY system_files/shared/usr/share/bash-completion/completions/ujust \
     system_files/shared/usr/share/zsh/site-functions/_ujust \
     system_files/shared/usr/share/fish/vendor_completions.d/ujust.fish \
     system_files/shared/usr/share/ublue-os/just/ujust-flags \
     /tmp/ujust-gate/
RUN set -e; \
    grep -qE '^complete -F _ujust ujust$' /tmp/ujust-gate/ujust; \
    grep -qE '^#compdef ujust$' /tmp/ujust-gate/_ujust; \
    grep -qE '^complete -c ujust ' /tmp/ujust-gate/ujust.fish; \
    grep -qE '^[[:space:]]*local flags_file=.*ujust-flags' /tmp/ujust-gate/ujust; \
    grep -qE '^[[:space:]]*local flags_file=.*ujust-flags' /tmp/ujust-gate/_ujust; \
    grep -qE '^[[:space:]]*echo .*ujust-flags' /tmp/ujust-gate/ujust.fish; \
    grep -qx -- '--version' /tmp/ujust-gate/ujust-flags; \
    if grep -qF 'JUST_COMPLETE' /tmp/ujust-gate/ujust /tmp/ujust-gate/_ujust /tmp/ujust-gate/ujust.fish; then echo "ujust completion is a just dynamic-loader shim" >&2; exit 1; fi; \
    for f in usr/share/bash-completion/completions/ujust usr/share/zsh/site-functions/_ujust usr/share/fish/vendor_completions.d/ujust.fish usr/share/ublue-os/just/ujust-flags; do \
        if [ -e "/out/shared/${f}" ]; then echo "ujust completion shadowed by /out/shared/${f}" >&2; exit 1; fi; \
    done

FROM scratch AS ctx
COPY /system_files/shared /system_files/shared/
COPY /bluefin-branding/system_files /system_files/bluefin
COPY /system_files/bluefin /system_files/bluefin

COPY --from=build /out/shared /system_files/shared
COPY --from=build /out/bluefin /system_files/bluefin
