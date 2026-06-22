# Bluefin-Common Style Guide

This document defines the coding and configuration standards for the bluefin-common repository.

## Repository Overview

Bluefin-common is a minimal OCI layer containing shared configuration files for all Bluefin variants. It contains no compiled code—only configuration files, shell scripts, and Just recipes.

## File Organization

### Directory Structure Standards

**Always maintain the two-tier structure:**
- `system_files/bluefin/` - Bluefin-specific configurations (GNOME, desktop settings, branding)
- `system_files/shared/` - Distribution-agnostic configurations (shared with Aurora and other images)

**Placement rules:**
- Desktop/GNOME-specific files → `system_files/bluefin/`
- Reusable system configurations → `system_files/shared/`
- When in doubt, prefer `shared/` unless it requires GNOME or Bluefin branding

**Preserve target system paths:**
Files must mirror their final destination paths:
```
system_files/shared/usr/share/ublue-os/just/example.just
system_files/bluefin/etc/dconf/db/distro.d/01-setting
```

## Shell Scripts (.sh)

### Shebang
Use `#!/usr/bin/bash` or `#!/usr/bin/env bash` consistently.

### Style
- Use lowercase for local variables: `local_var="value"`
- Use UPPERCASE for environment variables: `SETUP_CHECKER_FILE="${HOME}/.local/share/ublue/setup_versioning.json"`
- Always quote variable expansions: `"${VARIABLE}"`
- Use `[[ ]]` for conditionals, not `[ ]`

### Example
```bash
#!/usr/bin/bash

TARGET_VERSION=1
CONFIG_FILE="${HOME}/.config/myapp.conf"

if [[ -f "${CONFIG_FILE}" ]]; then
    echo "Configuration found"
fi
```

### Error Handling
Include basic error checking for critical operations:
```bash
if [ ! -e "${SETUP_CHECKER_FILE}" ] ; then
    mkdir -p "$(dirname "${SETUP_CHECKER_FILE}")"
    echo "{}" > "${SETUP_CHECKER_FILE}"
fi
```

## Just Recipes (.just)

### File Header
Start Just files with:
```just
# vim: set ft=make :
```

### Recipe Naming
- Use lowercase with hyphens: `toggle-tpm2`, `install-flatpaks`
- Be descriptive: prefer `configure-nvidia` over `nvidia`

### Recipe Groups
Organize recipes with group annotations:
```just
[group('System')]
toggle-tpm2:
    @/usr/bin/luks-tpm2-autounlock
```

Common groups: `System`, `Apps`, `Update`, `Developer`

### Recipe Documentation
Add a brief comment above each recipe:
```just
# Factory reset this device (experimental)
[group('System')]
powerwash:
    #!/usr/bin/bash
    # ... implementation
```

### Inline Scripts
For multi-line recipes, use bash shebang:
```just
example-recipe:
    #!/usr/bin/bash
    echo "Step 1"
    echo "Step 2"
```

### Settings
Standard settings for entry-point Just files:
```just
set allow-duplicate-recipes := true
set ignore-comments := true
```

## JSON Configuration Files

### Formatting
- Use **tabs** for indentation (matching existing files)
- Keep JSON minimal and readable
- One property per line

### Example
```json
{
	"logo-directory": "/usr/share/ublue-os/bluefin-logos/symbols",
	"shuffle-logo": true
}
```

### Validation
All JSON files must be valid. Check with:
```bash
jq . < file.json
```

## YAML Configuration Files

### Formatting
- Use **2 spaces** for indentation
- Use kebab-case for keys: `yaml-blocklist-paths`
- Keep files focused on a single configuration purpose

### Example
```yaml
yaml-blocklist-paths:
  - /run/host/etc/bazaar/blocklist.yaml

curated-config-paths:
  - /run/host/etc/bazaar/curated.yaml
```

## Containerfile

### Style
- Use explicit tags for base images: `FROM docker.io/library/alpine:latest`
- Use uppercase for Dockerfile instructions: `COPY`, `RUN`, `FROM`
- Group related `RUN` commands with `&&` for layer efficiency
- Add line continuations for readability with `\`

### Multi-stage Pattern
```dockerfile
FROM docker.io/library/alpine:latest AS build
RUN apk add just curl

# Processing steps...
RUN install -d /out/shared/usr/share && \
  just --completions bash > /out/shared/usr/share/bash-completion/completions/ujust

FROM scratch AS ctx
COPY /system_files/shared /system_files/shared/
COPY /system_files/bluefin /system_files/bluefin
COPY --from=build /out/shared /system_files/shared
```

### Comments
Add comments for non-obvious operations:
```dockerfile
# artwork repo points to ~/.local/share for metadata
RUN sed -i 's|~/\.local/share|/usr/share|' /out/bluefin/usr/share/backgrounds/bluefin/*.xml
```

## Homebrew Brewfiles

### Naming Convention
- Use lowercase with hyphens: `system-flatpaks.Brewfile`
- Be descriptive: `full-desktop.Brewfile`, `ai-tools.Brewfile`

### Format
One application per line, grouped by type with comments:
```ruby
# Core Applications
cask "firefox"
cask "thunderbird"

# Development Tools
cask "visual-studio-code"
```

### Location
Place Brewfiles in `system_files/shared/usr/share/ublue-os/homebrew/`

## Git Commit Messages

### Format
Follow [Conventional Commits](https://www.conventionalcommits.org/):
```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types
- `feat:` - New feature or configuration
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `chore:` - Maintenance (dependencies, cleanup)
- `refactor:` - Code restructuring
- `ci:` - CI/CD changes

### Scope
Use meaningful scopes:
- `just` - Just recipe changes
- `flatpak` - Flatpak configurations
- `firefox` - Firefox settings
- `gnome` - GNOME/desktop settings
- `setup` - Setup hook scripts
- `brew` - Homebrew Brewfile changes

### Examples
```
feat(flatpak): add VSCode Wayland support override

fix(just): correct path to system-flatpaks Brewfile

docs(readme): update directory structure documentation

chore(deps): update bluefin-wallpapers to latest
```

### AI Attribution
AI-assisted commits must include attribution:
```
feat(just): add new system management recipe

Assisted-by: Claude 3.5 Sonnet via GitHub Copilot
```

## Comments and Documentation

### When to Comment
- Configuration files: Explain non-obvious settings
- Shell scripts: Document complex logic or version-based behavior
- Just recipes: Brief description of what the recipe does
- Containerfile: Clarify transformations or path changes

### When NOT to Comment
- Self-explanatory code
- Simple variable assignments
- Standard patterns

### Example - Good Comments
```bash
# Meant to be used at the start of any setup service script
# Will version your script accordingly on $SETUP_CHECKER_FILE
function version-script() {
    # ... implementation
}
```

## File Permissions

### Executable Scripts
Scripts intended to be executed must be executable:
```bash
chmod +x system_files/shared/usr/bin/ublue-image-info.sh
```

### Configuration Files
Non-executable files (JSON, YAML, text) should be 644:
```bash
chmod 644 system_files/bluefin/etc/ublue-os/fastfetch.json
```

## Testing and Validation

### Local Build Testing
Always test builds locally before pushing:
```bash
just build
```

### Syntax Validation
- **Just files**: `just check`
- **JSON files**: `find system_files -name "*.json" -exec jq . {} \;`
- **Shell scripts**: `bash -n script.sh`

### Structure Inspection
Verify the built image structure:
```bash
just tree
```

## Pull Request Guidelines

### PR Title
Use conventional commit format:
```
feat(flatpak): add system flatpak overrides for Bazaar
```

### PR Description
Include:
1. What changed
2. Why it changed
3. Testing performed (local build, validation)

### Changes
- Keep PRs focused on a single logical change
- Maintain existing file structure
- Don't mix refactoring with feature changes

## Naming Conventions

### Files
- **Just recipes**: lowercase with hyphens (`system.just`, `toggle-tpm2`)
- **Shell scripts**: lowercase with hyphens (`libsetup.sh`, `ublue-image-info.sh`)
- **Config files**: lowercase with hyphens or dots (`fastfetch.json`, `mimeapps.list`)
- **Brewfiles**: descriptive with hyphens (`system-flatpaks.Brewfile`, `full-desktop.Brewfile`)

### Variables (Shell)
- Local: `lowercase_with_underscores`
- Environment: `UPPERCASE_WITH_UNDERSCORES`
- Consistent naming: `TARGET_VERSION`, `SETUP_CHECKER_FILE`

### Functions (Shell)
- Use lowercase with hyphens: `version-script`
- Be descriptive: `check-version`, `install-flatpaks`

## What NOT to Do

❌ **Don't add complex build dependencies** - This repo is intentionally minimal
❌ **Don't compile code** - This is a configuration-only layer
❌ **Don't modify the scratch→ctx build pattern** - It's essential for the OCI layer
❌ **Don't add linters/formatters** - Keep tooling minimal (Just, jq, bash only)
❌ **Don't break existing directory structure** - Maintain `bluefin/` vs `shared/` separation
❌ **Don't add unnecessary comments** - Comment only when clarification is needed

## Editor Configuration

### Vim Modelines
Include for Just files:
```just
# vim: set ft=make :
```

### Recommended Settings
- **Tabs for JSON**: 1 tab = indentation unit
- **Spaces for YAML**: 2 spaces per level
- **Shell scripts**: 2 or 4 space indentation (be consistent within file)
- **Just recipes**: 4 space indentation

## Consistency Principles

1. **Follow existing patterns** - Look at similar files in the repo
2. **Mirror destination paths** - Maintain the target filesystem structure
3. **Keep it simple** - This is intentionally a minimal repository
4. **Validate before committing** - Run local builds and syntax checks
5. **Preserve the two-tier structure** - `bluefin/` vs `shared/` is fundamental

## Questions?

When unsure about where a file belongs or how to structure it:
1. Check similar existing files in the repository
2. Refer to `AGENTS.md` for detailed repository context
3. Default to simplicity and existing patterns
4. Ask in pull request reviews
