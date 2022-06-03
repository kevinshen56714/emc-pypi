import os
import sys
from setuptools import setup, find_packages

# Read the contents of your README file
PACKAGE_DIR = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(PACKAGE_DIR, 'README.md'), encoding='utf-8') as f:
    LONG_DESCRIPTION = f.read()


def get_exclude_bins():
    if sys.platform == 'linux' or sys.platform == 'linux2':
        emc_exec = 'emc_linux64'
    elif sys.platform == 'darwin':
        emc_exec = 'emc_macos'
    elif sys.platform == 'win32':
        emc_exec = 'emc_win32.exe'


def package_files(directory):
    paths = []
    for (path, directories, filenames) in os.walk(directory):
        for filename in filenames:
            paths.append(os.path.join('..', path, filename))
    return paths


extra_files = package_files('pyemc/emc')

setup(
    name='pyemc',
    version='9.4.4',
    long_description=LONG_DESCRIPTION,
    long_description_content_type='text/markdown',
    description='Python interface for the Enhanced Monte Carlo (EMC) package',
    keywords=['EMC'],
    url='https://github.com/kevinshen56714/pyemc',
    author='Kevin Shen',
    author_email='kevinshen56714@gmail.com',
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: OS Independent",
    ],
    packages=find_packages(),
    package_data={'': extra_files},
    zip_safe=True)
