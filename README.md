# Enhanced Monte Carlo (EMC) Python Interface

This Python module is a thin layer around the [EMC](http://montecarlo.sourceforge.net/emc/Welcome.html) package that allows you to use EMC with ease.

The package should work out of the box without any configuration as the pre-compiled EMC executable files are included. Please open an issue if you find something missing or not working as expected.

[![PyPI version shields.io](https://img.shields.io/pypi/v/emc-pypi.svg?style=for-the-badge&logo=PyPI&logoColor=blue)](https://pypi.python.org/pypi/emc-pypi/)
[![PyPI download month](https://img.shields.io/pypi/dm/emc-pypi.svg?style=for-the-badge&logo=PyPI)](https://pypi.python.org/pypi/emc-pypi/)
[![PyPI download day](https://img.shields.io/pypi/dd/emc-pypi.svg?style=for-the-badge&logo=PyPI)](https://pypi.python.org/pypi/emc-pypi/)

## Installation

```bash
pip install emc-pypi
```


## Usage

```python
import pyemc

# Run the emc_setup.pl and prepare the build.emc file for the following build command
pyemc.setup('your-setup-file.esh')

# Run the emc executable
pyemc.build('build.emc')
```