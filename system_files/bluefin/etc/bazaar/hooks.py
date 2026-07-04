# See https://github.com/kolunmi/bazaar/blob/main/docs/overview.md#hooks

import os, subprocess, sys

unix_timestamp      = os.getenv('BAZAAR_HOOK_INITIATED_UNIX_STAMP')
unix_timestamp_usec = os.getenv('BAZAAR_HOOK_INITIATED_UNIX_STAMP_USEC')

hook_id            = os.getenv('BAZAAR_HOOK_ID')
hook_type          = os.getenv('BAZAAR_HOOK_TYPE')
was_aborted        = os.getenv('BAZAAR_HOOK_WAS_ABORTED')
dialog_id          = os.getenv('BAZAAR_HOOK_DIALOG_ID')
dialog_response_id = os.getenv('BAZAAR_HOOK_DIALOG_RESPONSE_ID')

non_transaction_appid = os.getenv('BAZAAR_APPID')
transaction_appid     = os.getenv('BAZAAR_TS_APPID')
transaction_type      = os.getenv('BAZAAR_TS_TYPE')

stage     = os.getenv('BAZAAR_HOOK_STAGE')
stage_idx = os.getenv('BAZAAR_HOOK_STAGE_IDX')

# ---

def spawn_and_detach(args):
    subprocess.Popen(args, start_new_session=True, stdout=subprocess.DEVNULL)

def spawn_ujust(id):
    spawn_and_detach(['flatpak-spawn', '--host', 'xdg-terminal-exec', '-x', f'ujust {id}'])

def spawn_brew_tap_cask(tap, app):
    brew = '/home/linuxbrew/.linuxbrew/bin/brew'
    spawn_and_detach([
        'flatpak-spawn', '--host', 'xdg-terminal-exec', '-x',
        'bash', '-c', f'{brew} tap --trust {tap} && {brew} install --cask {app}'
    ])

def spawn_brew_formula(formula):
    brew = '/home/linuxbrew/.linuxbrew/bin/brew'
    spawn_and_detach([
        'flatpak-spawn', '--host', 'xdg-terminal-exec', '-x',
        'bash', '-c', f'{brew} install {formula}'
    ])

GUI_CASK_HOOKS = {
    'code': {
        'appids': ('com.visualstudio.code', 'com.vscodium.codium'),
        'tap': 'ublue-os/tap',
        'casks': {
            'com.visualstudio.code': 'visual-studio-code-linux',
            'com.vscodium.codium': 'vscodium-linux',
        },
    },
    'zed': {
        'appids': ('dev.zed.Zed',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {
            'dev.zed.Zed': 'zed-linux',
        },
    },
    'emacs': {
        'appids': ('org.gnu.emacs',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {
            'org.gnu.emacs': 'emacs-app-linux',
        },
    },
    'clion': {
        'appids': ('com.jetbrains.CLion',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'com.jetbrains.CLion': 'clion-linux'},
    },
    'datagrip': {
        'appids': ('com.jetbrains.DataGrip',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'com.jetbrains.DataGrip': 'datagrip-linux'},
    },
    'goland': {
        'appids': ('com.jetbrains.GoLand',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'com.jetbrains.GoLand': 'goland-linux'},
    },
    'intellij': {
        'appids': ('com.jetbrains.IntelliJ-IDEA-Community',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'com.jetbrains.IntelliJ-IDEA-Community': 'intellij-idea-linux'},
    },
    'phpstorm': {
        'appids': ('com.jetbrains.PhpStorm',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'com.jetbrains.PhpStorm': 'phpstorm-linux'},
    },
    'pycharm': {
        'appids': ('com.jetbrains.PyCharm-Community', 'com.jetbrains.PyCharm-Professional'),
        'tap': 'ublue-os/experimental-tap',
        'casks': {
            'com.jetbrains.PyCharm-Community': 'pycharm-linux',
            'com.jetbrains.PyCharm-Professional': 'pycharm-linux',
        },
    },
    'rider': {
        'appids': ('com.jetbrains.Rider',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'com.jetbrains.Rider': 'rider-linux'},
    },
    'rubymine': {
        'appids': ('com.jetbrains.RubyMine',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'com.jetbrains.RubyMine': 'rubymine-linux'},
    },
    'rustrover': {
        'appids': ('com.jetbrains.RustRover',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'com.jetbrains.RustRover': 'rustrover-linux'},
    },
    'webstorm': {
        'appids': ('com.jetbrains.WebStorm',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'com.jetbrains.WebStorm': 'webstorm-linux'},
    },
    'opencode-desktop': {
        'appids': ('ai.opencode.opencode',),
        'tap': 'ublue-os/experimental-tap',
        'casks': {'ai.opencode.opencode': 'opencode-desktop-linux'},
    },
    'lm-studio': {
        'appids': ('ai.lmstudio.lm-studio',),
        'tap': 'ublue-os/tap',
        'casks': {'ai.lmstudio.lm-studio': 'lm-studio-linux'},
    },
}

def handle_gui_cask_hook(hook_cfg):
    appids = hook_cfg['appids']
    tap = hook_cfg['tap']
    casks = hook_cfg['casks']

    match stage:
        case 'setup':
            if transaction_type == 'install' and transaction_appid in appids:
                return 'ok'
            else:
                return 'pass'

        case 'setup-dialog':
            return 'ok'

        case 'teardown-dialog':
            if dialog_response_id == 'download':
                return 'ok'
            else:
                return 'abort'

        case 'catch':
            return 'abort'

        case 'action':
            try:
                cask = casks[transaction_appid]
                spawn_brew_tap_cask(tap, cask)
            except:
                pass
            return ''

        case 'teardown':
            return 'deny'

def handle_jetbrains():

    def appid_is_jetbrains(appid):
        direct_jetbrains_appids = (
            'com.jetbrains.CLion',
            'com.jetbrains.DataGrip',
            'com.jetbrains.GoLand',
            'com.jetbrains.IntelliJ-IDEA-Community',
            'com.jetbrains.PhpStorm',
            'com.jetbrains.PyCharm-Community',
            'com.jetbrains.PyCharm-Professional',
            'com.jetbrains.Rider',
            'com.jetbrains.RubyMine',
            'com.jetbrains.RustRover',
            'com.jetbrains.WebStorm',
        )
        if appid in direct_jetbrains_appids:
            return False
        return appid.startswith('com.jetbrains.') or appid == ('com.google.AndroidStudio')

    match stage:
        case 'setup':
            if transaction_type == 'install' and appid_is_jetbrains(transaction_appid):
                return 'ok'
            else:
                return 'pass'

        case 'setup-dialog':
            return 'ok'

        case 'teardown-dialog':
            if dialog_response_id == 'run-ujust':
                return 'ok'
            else:
                return 'abort'

        case 'catch':
            return 'abort'

        case 'action':
            try:
                spawn_ujust('install-jetbrains-toolbox')
            except:
                pass
            return ''

        case 'teardown':
            # always prevent installation of JetBrains flatpaks
            return 'deny'

def handle_cli_editor(appid_match, formula):

    match stage:
        case 'setup':
            if transaction_type == 'install' and transaction_appid == appid_match:
                return 'ok'
            else:
                return 'pass'

        case 'setup-dialog':
            return 'ok'

        case 'teardown-dialog':
            if dialog_response_id == 'download':
                return 'ok'
            else:
                return 'abort'

        case 'catch':
            return 'abort'

        case 'action':
            try:
                spawn_brew_formula(formula)
            except:
                pass
            return ''

        case 'teardown':
            return 'deny'

def handle_neovim():
    return handle_cli_editor('io.neovim.nvim', 'nvim')

def handle_helix():
    return handle_cli_editor('com.helix_editor.Helix', 'helix')

def handle_vim():
    return handle_cli_editor('org.vim.Vim', 'vim')

def handle_micro():
    return handle_cli_editor('io.github.zyedidia.micro', 'micro')

# ---

response = 'pass'
match hook_id:
    case 'jetbrains-toolbox':
        response = handle_jetbrains()
    case (
        'code'
        | 'zed'
        | 'emacs'
        | 'clion'
        | 'datagrip'
        | 'goland'
        | 'intellij'
        | 'phpstorm'
        | 'pycharm'
        | 'rider'
        | 'rubymine'
        | 'rustrover'
        | 'webstorm'
        | 'opencode-desktop'
        | 'lm-studio'
    ):
        response = handle_gui_cask_hook(GUI_CASK_HOOKS[hook_id])
    case 'neovim':
        response = handle_neovim()
    case 'helix':
        response = handle_helix()
    case 'vim':
        response = handle_vim()
    case 'micro':
        response = handle_micro()

print(response)
sys.exit(0)
