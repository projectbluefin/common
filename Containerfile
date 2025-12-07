FROM docker.io/library/alpine:latest AS build

RUN apk add just
RUN install -d /out/usr/share/bash-completion/completions /out/usr/share/zsh/site-functions /out/usr/share/fish/vendor_completions.d/ && \
  just --completions bash | sed -E 's/([\(_" ])just/\1ujust/g' > /out/usr/share/bash-completion/completions/ujust && \
  just --completions zsh | sed -E 's/([\(_" ])just/\1ujust/g' > /out/usr/share/zsh/site-functions/_ujust && \
  just --completions fish | sed -E 's/([\(_" ])just/\1ujust/g' > /out/usr/share/fish/vendor_completions.d/ujust.fish

FROM scratch AS ctx
COPY /system_files/bluefin /system_files/bluefin

COPY /system_files/shared /system_files/shared/

COPY --from=build /out/ /system_files/shared
