# Build the bluefin-common container locally
build:
    buildah build -t localhost/bluefin-common:latest -f ./Containerfile .

# Inspect the directory structure of an OCI image
tree IMAGE="localhost/bluefin-common:latest":
    echo "FROM alpine:latest" > TreeContainerfile
    echo "RUN apk add --no-cache tree" >> TreeContainerfile
    echo "COPY --from={{IMAGE}} / /mnt/root" >> TreeContainerfile
    echo "CMD tree /mnt/root" >> TreeContainerfile
    podman build -t tree-temp -f TreeContainerfile .
    podman run --rm tree-temp
    rm TreeContainerfile
    podman rmi tree-temp
