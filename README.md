# bluefin-common

Shared OCI layer containing common configuration files used across all Bluefin variants (bluefin, bluefin-dx, bluefin-lts).

## What's Inside

This layer contains two main configuration directories:

### `/etc/ublue-os/` - System Configuration
- Bling - CLI theming settings
- Fastfetch settings - System information display configuration
- Setup configuration - First-boot and system setup parameters

### `/usr/share/ublue-os/` - User-Space Configuration
- Firefox defaults - Pre-configured Firefox settings
- Flatpak overrides - Application-specific Flatpak configurations
- Homebrew Brewfiles - Curated application bundles installable via `bbrew`
  - `full-desktop.Brewfile` - Full collection of GNOME Circle and community flatpak applications
  - Other specialized Brewfiles for fonts, CLI tools, AI tools, etc.
- Just recipes - Additional command recipes for system management
- MOTD templates - Message of the day and tips
- Setup hooks - Scripts for privileged, system, and user setup stages

## Usage in Containerfile

Reference this layer as a build stage and copy the directories you need:

### Copy everything:
```dockerfile
FROM ghcr.io/ublue-os/bluefin-common:latest AS bluefin-common

# Copy all system files
COPY --from=bluefin-common /system_files /
```

### Copy only system configuration:

This is what Aurora should use, gives shares the common set of files and keeps the images opinions seperate.

```dockerfile
FROM ghcr.io/ublue-os/bluefin-common:latest AS bluefin-common

# Copy only /etc configuration
COPY --from=bluefin-common /system_files/etc /etc
```

### Copy only the image opinion:
```dockerfile
FROM ghcr.io/ublue-os/bluefin-common:latest AS bluefin-common

# Copy only /usr/share configuration
COPY --from=bluefin-common /system_files/usr /usr
```

## Brewfiles

The `/usr/share/ublue-os/homebrew/` directory contains curated application bundles installable via [bbrew](https://github.com/Valkyrie00/homebrew-bbrew):

- **`full-desktop.Brewfile`** - Comprehensive collection of GNOME Circle and community flatpak applications for a full desktop experience
- **`fonts.Brewfile`** - Additional monospace fonts for development
- **`cli.Brewfile`** - CLI tools and utilities
- **`ai-tools.Brewfile`** - AI and machine learning tools
- **`cncf.Brewfile`** - Cloud Native Computing Foundation tools
- **`k8s-tools.Brewfile`** - Kubernetes tools
- **`ide.Brewfile`** - Integrated development environments
- **`artwork.Brewfile`** - Design and artwork applications

Users can install these bundles using the `ujust bbrew` command, which will prompt them to select a Brewfile.

## Building Locally

```bash
just build
```

## Rechunking for Bootc Images

If you're building a bootc (bootable container) image that uses bluefin-common as a base layer, it's recommended to rechunk your final image for optimal update performance. Rechunking reorganizes the image layers to improve download resumability and reduce update sizes.

### Using bootc-base-imagectl

After building your bootc image, add a rechunk step before pushing to the registry. Here's an example based on the workflow used by [zirconium-dev/zirconium](https://github.com/zirconium-dev/zirconium):

```yaml
- name: Build image
  id: build
  run: sudo podman build -t "${IMAGE_NAME}:${DEFAULT_TAG}" -f ./Containerfile .

- name: Rechunk Image
  run: |
    sudo podman run --rm --privileged \
      -v /var/lib/containers:/var/lib/containers \
      --entrypoint /usr/libexec/bootc-base-imagectl \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      rechunk --max-layers 67 \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}"

- name: Push to Registry
  run: sudo podman push "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" "${IMAGE_REGISTRY}/${IMAGE_NAME}:${DEFAULT_TAG}"
```

### Parameters

- `--max-layers`: Maximum number of layers for the rechunked image (typically 67 for optimal balance)
- The first image reference is the source (input)
- The second image reference is the destination (output)

### Benefits

- **Smaller updates**: 5-10x reduction in update size by removing replaced files from previous layers
- **Better resumability**: Evenly sized layers improve download resume capability
- **Optimized layer distribution**: Files are reorganized for efficient updates

### References

- [CoreOS rpm-ostree build-chunked-oci documentation](https://coreos.github.io/rpm-ostree/build-chunked-oci/)
- [bootc documentation](https://containers.github.io/bootc/)

**Note**: Rechunking is only applicable for bootc images. The bluefin-common layer itself does not need rechunking as it's only a configuration layer.

## Contributor Metrics

![Alt](https://repobeats.axiom.co/api/embed/45dffc43196101fdeb340b462af3f7babe39eee3.svg "Repobeats analytics image")
