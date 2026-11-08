# Initialize starship as the default prompt for fish.
# starship is installed by brew-preinstall at first login.
# If not yet available (first session before brew runs, or user removed it),
# fish falls back silently to the custom fish_prompt in vendor_functions.d/.
if command -q starship
    starship init fish | source
end
