# vim: set ft=make :
# These are recipes that are generic and should be available in bluefin, aurora,
# bluefin-lts, and dakota

# Toggle LUKS auto-unlock via TPM2
[group('System')]
toggle-tpm2:
    @/usr/bin/luks-tpm2-autounlock
