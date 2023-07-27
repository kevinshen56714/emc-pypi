# Enhanced Monte Carlo (EMC) Python Interface

[![PyPI version shields.io](https://img.shields.io/pypi/v/emc-pypi.svg?style=for-the-badge&logo=PyPI&logoColor=blue)](https://pypi.python.org/pypi/emc-pypi/)
[![PyPI download month](https://img.shields.io/pypi/dm/emc-pypi.svg?style=for-the-badge&logo=PyPI)](https://pypi.python.org/pypi/emc-pypi/)

This module is a thin Python wrapper library of the [EMC](http://montecarlo.sourceforge.net/emc/Welcome.html) package that allows you to use all EMC functionalities with Python interface.

EMC creates input structures from SMILES strings and LAMMPS input files for particle simulations with atomistic force fields - Born, COMPASS, PCFF, CHARMM, OPLS, TraPPE or coarse-grained force fields - DPD, Martini, SDK.

- See the [example input files](https://github.com/kevinshen56714/emc-pypi/tree/main/pyemc/emc/examples/setup) on how to prepare EMC input (.esh) files.
- See the [docs](https://github.com/kevinshen56714/emc-pypi/blob/main/pyemc/emc/docs/emc.pdf) to understand more about EMC.

The package works out of the box without pre-installation of EMC or any configuration. Please open an issue if you find something missing or not working as expected.

## Installation

```bash
pip install emc-pypi
```

## Usage

```python
import pyemc

# Run the emc_setup.pl and generate the build.emc file for the build command
pyemc.setup('your-setup-file.esh')

# Or you can pass in arguments like this
pyemc.setup('your-setup-file.esh', '-ntotal=1000', '-field=opls-aa')

# Finally, run the emc executable to create simulation input files
pyemc.build('build.emc')
```

## Example

Example input files are provided in the [example](https://github.com/kevinshen56714/emc-pypi/tree/main/example). Once installed, you can run the example by:

```python
cd example
python example.py
```

The example.esh file creates a system with 80% m/m water and 20% m/m alcohol. More examples are available [here](https://github.com/kevinshen56714/emc-pypi/tree/main/pyemc/emc/examples/setup)

## Citation

In any publication of scientific results based in part or completely on the use of EMC, please cite the original paper:
P.J. in 't Veld and G.C. Rutledge, Macromolecules 2003, 36, 7358 [[link](https://pubs.acs.org/doi/full/10.1021/ma0346658)] [[pdf](https://pubs.acs.org/doi/pdf/10.1021/ma0346658)]
