# Enhanced Monte Carlo (EMC) Python Interface

The `pyemc` module is a thin Python layer around the [EMC](http://montecarlo.sourceforge.net/emc/Welcome.html) package that allows you to use EMC with ease.


## Installation

```bash
pip install pmd
```


## Usage

```python
import pyemc

# Equivalent to running ./emc_setup.pl your-setup-file.esh on the command line
pyemc.setup('your-setup-file.esh')

# Equivalent to running the emc executable
pyemc.build('build.emc')
```