import os

from setuptools import find_packages, setup

# Read the contents of your README file
PACKAGE_DIR = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(PACKAGE_DIR, 'README.md'), encoding='utf-8') as f:
    LONG_DESCRIPTION = f.read()


def package_files(directory):
    paths = []
    for (path, directories, filenames) in os.walk(directory):
        for filename in filenames:
            paths.append(os.path.join('..', path, filename))
    return paths


extra_files = package_files('pyemc/emc')

setup(
    name='emc-pypi',
    version='2023.8.1',
    long_description=LONG_DESCRIPTION,
    long_description_content_type='text/markdown',
    description='Python interface for the Enhanced Monte Carlo (EMC) package',
    keywords=['EMC', 'Molecular Dynamics', 'LAMMPS', 'SMILES', 'Simulation'],
    url='https://github.com/kevinshen56714/emc-pypi',
    author='Kuan-Hsuan (Kevin) Shen',
    author_email='kevinshen56714@gmail.com',
    classifiers=[
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Operating System :: OS Independent",
        "Topic :: Software Development",
        "Topic :: Utilities",
    ],
    packages=find_packages(),
    package_data={'': extra_files},
    zip_safe=False)
