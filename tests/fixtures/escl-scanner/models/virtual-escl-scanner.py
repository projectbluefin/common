# Hardware-free eSCL scanner model for the OpenPrinting go-mfp simulator.
#
# `mfp-virtual -m <this file>` executes this as a Python script with the
# `escl`, `dnssd`, `ipp` and `usb` modules pre-bound as globals; whatever
# globals it assigns are imported back into the Go model.
#
# Geometry. eSCL expresses lengths in 1/300 inch units, so the platen below
# is A4/Letter:
#
#     2550 / 300 = 8.5 in      (Letter width)
#     3508 / 300 = 11.69 in    (A4 height)
#
# A full-platen capture at 600 DPI is therefore exactly 5100 x 7016 px,
# which is the size of the deterministic synthetic page go-mfp embeds
# (internal/testutils/data/testpage-5100x7016.png) and the resolution its
# virtual scanner template reports. Scanning at 600 DPI is a 1:1 copy of
# that page -- no resampling -- which is what makes the capture byte-stable.
#
# DNS-SD. Advertising over DNS-SD needs a reachable avahi daemon, which is
# not present in every environment, so it is opt-in: the simulator's own
# eSCL HTTP endpoint works without it. Set ESCL_FIXTURE_DNSSD=1 to publish.

import os
from uuid import UUID

DEVICE_NAME = 'OpenPrinting Virtual MFP'
DEVICE_UUID = UUID('9f2b7c1e-4a6d-4f3b-8c5e-1d0a2b3c4d5e')

# Resolutions offered to clients. 600 DPI is the fixture's canonical
# resolution; 300 is kept so the device looks like ordinary hardware and
# so sane-airscan's own default-resolution probing has something to pick.
_RESOLUTIONS = [300, 600]


def _discrete(color_mode):
    return escl.SupportedResolutions(
        ColorMode = color_mode,
        DiscreteResolutions = [
            escl.DiscreteResolution(XResolution = dpi, YResolution = dpi)
            for dpi in _RESOLUTIONS
        ],
    )


escl.scanner = escl.ScannerCapabilities(
    Version = '2.9',
    MakeAndModel = DEVICE_NAME,
    SerialNumber = 'VIRTUAL-0001',
    Uuid = DEVICE_UUID,
    Platen = escl.Platen(
        PlatenInputCaps = escl.InputSourceCaps(
            MinWidth = 300,
            MaxWidth = 2550,
            MinHeight = 300,
            MaxHeight = 3508,
            MaxOpticalXResolution = 600,
            MaxOpticalYResolution = 600,
            MaxScanRegions = 1,
            MaxPhysicalWidth = 2550,
            MaxPhysicalHeight = 3508,
            SupportedIntents = [
                escl.Document,
                escl.TextAndGraphic,
                escl.Photo,
                escl.Preview,
            ],
            SettingProfiles = [
                escl.SettingProfile(
                    ColorModes = [
                        escl.RGB24,
                        escl.Grayscale8,
                        escl.BlackAndWhite1,
                    ],
                    ContentTypes = [
                        escl.Photo,
                        escl.Text,
                        escl.TextAndPhoto,
                    ],
                    DocumentFormats = [
                        'image/jpeg',
                        'application/pdf',
                    ],
                    DocumentFormatsExt = [
                        'image/jpeg',
                        'application/pdf',
                    ],
                    SupportedResolutions = [
                        _discrete(escl.RGB24),
                        _discrete(escl.Grayscale8),
                        _discrete(escl.BlackAndWhite1),
                    ],
                ),
            ],
        ),
    ),
)

if os.environ.get('ESCL_FIXTURE_DNSSD', '0') == '1':
    # sane-airscan discovers eSCL scanners through the _uscan._tcp service
    # type; `rs` tells it which path under the advertised host serves eSCL.
    # The simulator rewrites each HTTP endpoint's host and port to the
    # address it actually listens on, so the placeholder below is fine.
    dnssd.device = dnssd.Device(
        instance = DEVICE_NAME,
        UUID = DEVICE_UUID,
        services = [
            dnssd.Service(
                types = [
                    '_uscan._tcp',
                    '_uscans._tcp',
                ],
                TXT = [
                    'txtvers=1',
                    'ty=' + DEVICE_NAME,
                    'rs=eSCL',
                    'pdl=image/jpeg,application/pdf',
                    'cs=color,grayscale,binary',
                    'is=platen',
                    'duplex=F',
                    'UUID=' + str(DEVICE_UUID),
                ],
                endpoints = [
                    'http://127.0.0.1:50000/eSCL',
                ],
            ),
        ],
    )
