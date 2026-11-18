import os
import platform
import subprocess
import sys

_BUNDLED_ROOT = os.path.join(os.path.dirname(__file__), 'emc')


def _get_exec() -> str:
    if sys.platform == 'linux' or sys.platform == 'linux2':
        arch = platform.machine()
        if arch == 'x86_64':
            emc_exec = 'emc_linux_x86_64'
        elif arch == 'aarch64':
            emc_exec = 'emc_linux_aarch64'
        else:
            raise Exception(f'Unsupported Linux architecture: {arch}')
    elif sys.platform == 'darwin':
        emc_exec = 'emc_macos'
    elif sys.platform == 'win32':
        emc_exec = 'emc_win32.exe'
    else:
        raise OSError(f'Unsupported platform: {sys.platform}')
    return emc_exec


def _emc_env():
    env = os.environ.copy()
    root = os.path.expanduser(env.get('EMC_ROOT', _BUNDLED_ROOT))
    if not os.path.isdir(root):
        raise FileNotFoundError(
            f'EMC_ROOT points to a missing directory: {root!r}. '
            'Unset EMC_ROOT to use the bundled EMC files.')
    env['EMC_ROOT'] = root
    return env


def setup(esh_file: str, *args):
    '''Method to run emc.pl of EMC

    Attributes:
        esh_file (str): emc.pl input file

    Returns:
        None
    '''
    emc_setup_file = os.path.join(_BUNDLED_ROOT, 'scripts', 'emc.pl')

    env = _emc_env()
    try:
        subprocess.run(['perl', emc_setup_file, esh_file, *args],
                       env=env,
                       check=True)
    except FileNotFoundError as exc:
        raise FileNotFoundError(
            'pyemc.setup requires Perl. Install Perl and make sure '
            'the perl command is on your PATH.') from exc


def build(build_file: str):
    '''Method to run EMC executable

    Attributes:
        build_file (str): EMC executable input file

    Returns:
        None
    '''
    emc_bin_file = os.path.join(_BUNDLED_ROOT, 'bin', _get_exec())

    subprocess.run([emc_bin_file, build_file], env=_emc_env(), check=True)
