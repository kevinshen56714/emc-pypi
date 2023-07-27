import os
import subprocess
import sys


def _get_exec() -> None:
    '''Method to get executable file path

    Attributes:
        None

    Returns:
        None
    '''
    if sys.platform == 'linux' or sys.platform == 'linux2':
        emc_exec = 'emc_linux_x86_64'
    elif sys.platform == 'darwin':
        emc_exec = 'emc_macos'
    elif sys.platform == 'win32':
        emc_exec = 'emc_win32.exe'
        try:
            subprocess.run(['perl', '-v'], shell=True, check=True)
        except subprocess.CalledProcessError:
            raise Exception('You need to install Perl first, '
                            'see: https://www.perl.org/get.html')
    return emc_exec


def _get_path() -> str:
    '''Method to get the module path

    Attributes:
        None

    Returns:
        module_path (str): the path of the module
    '''
    return os.path.dirname(__file__)


def setup(esh_file: str, *args):
    '''Method to run emc_setup.pl of EMC

    Attributes:
        esh_file (str): emc_setup.pl input file

    Returns:
        None
    '''
    emc_setup_file = os.path.join(_get_path(), 'emc', 'scripts',
                                  'emc_setup.pl')

    command = ['perl', str(emc_setup_file), esh_file]
    for arg in args:
        command.append(arg)
    subprocess.run(command)


def build(build_file: str):
    '''Method to run EMC executable

    Attributes:
        build_file (str): EMC executable input file

    Returns:
        None
    '''
    emc_bin_file = os.path.join(_get_path(), 'emc', 'bin', _get_exec())

    subprocess.run([str(emc_bin_file), build_file])
