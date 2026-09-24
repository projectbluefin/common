# See https://github.com/bazaar-org/bazaar/blob/main/docs/overview.md#hooks

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

def make_popup_terminal_argv(cmd):
    brew_env = 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null)"'
    pause = 'echo; echo "------------------"; echo "Process completed. Press ENTER to close..."; read -r'
    full_cmd = f'{brew_env}; {cmd}; {pause}'
    return [
        'flatpak-spawn', '--host',
        'xdg-terminal-exec',
        '--app-id=io.github.kolunmi.Bazaar',
        '--title=Bazaar',
        '--',
        'bash', '-c', full_cmd
    ]

def spawn_ujust(command):
    spawn_and_detach(make_popup_terminal_argv(f'ujust {command}'))

def spawn_brew(app, tap='ublue-os/tap'):
    brew = '/home/linuxbrew/.linuxbrew/bin/brew'
    cmd = f'{brew} tap {tap}; {brew} trust {tap}; {brew} install --cask {app}'
    spawn_and_detach(make_popup_terminal_argv(cmd))

def handle_jetbrains():
    def appid_is_jetbrains(appid):
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
            if dialog_response_id in ('run-ujust', 'run-devmode'):
                return 'ok'
            else:
                return 'abort'

        case 'catch':
            return 'abort'

        case 'action':
            try:
                if dialog_response_id == 'run-devmode':
                    spawn_ujust('devmode')
                else:
                    spawn_ujust('install-jetbrains-toolbox')
            except:
                pass
            return ''

        case 'teardown':
            return 'deny'

def handle_vscode():
    def appid_is_vscode(appid):
        return appid == 'com.visualstudio.code'

    match stage:
        case 'setup':
            if transaction_type == 'install' and appid_is_vscode(transaction_appid):
                return 'ok'
            else:
                return 'pass'

        case 'setup-dialog':
            return 'ok'

        case 'teardown-dialog':
            if dialog_response_id in ('download', 'run-devmode'):
                return 'ok'
            else:
                return 'abort'

        case 'catch':
            return 'abort'

        case 'action':
            try:
                if dialog_response_id == 'run-devmode':
                    spawn_ujust('devmode')
                else:
                    spawn_brew('ublue-os/tap/visual-studio-code-linux')
            except:
                pass
            return ''

        case 'teardown':
            return 'deny'

def handle_vscodium():
    def appid_is_vscodium(appid):
        return appid == 'com.vscodium.codium'

    match stage:
        case 'setup':
            if transaction_type == 'install' and appid_is_vscodium(transaction_appid):
                return 'ok'
            else:
                return 'pass'

        case 'setup-dialog':
            return 'ok'

        case 'teardown-dialog':
            if dialog_response_id in ('download', 'run-devmode'):
                return 'ok'
            else:
                return 'abort'

        case 'catch':
            return 'abort'

        case 'action':
            try:
                if dialog_response_id == 'run-devmode':
                    spawn_ujust('devmode')
                else:
                    spawn_brew('ublue-os/tap/vscodium-linux')
            except:
                pass
            return ''

        case 'teardown':
            return 'deny'

def handle_zed():
    def appid_is_zed(appid):
        return appid.startswith('dev.zed.Zed')

    match stage:
        case 'setup':
            if transaction_type == 'install' and appid_is_zed(transaction_appid):
                return 'ok'
            else:
                return 'pass'

        case 'setup-dialog':
            return 'ok'

        case 'teardown-dialog':
            if dialog_response_id in ('download', 'run-devmode'):
                return 'ok'
            else:
                return 'abort'

        case 'catch':
            return 'abort'

        case 'action':
            try:
                if dialog_response_id == 'run-devmode':
                    spawn_ujust('devmode')
                else:
                    spawn_brew('ublue-os/tap/zed-linux')
            except:
                pass
            return ''

        case 'teardown':
            return 'deny'

# ---

response = 'pass'
match hook_id:
    case 'jetbrains-toolbox':
        response = handle_jetbrains()
    case 'vscode':
        response = handle_vscode()
    case 'vscodium':
        response = handle_vscodium()
    case 'zed':
        response = handle_zed()

print(response)
sys.exit(0)
