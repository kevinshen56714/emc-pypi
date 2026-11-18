import os
import re
import shutil
import tempfile
from pathlib import Path

import pyemc

example = Path(__file__).resolve().parents[2] / 'example' / 'example.esh'
os.environ.pop('EMC_ROOT', None)
with tempfile.TemporaryDirectory() as tmp:
    original = Path.cwd()
    try:
        os.chdir(tmp)
        shutil.copyfile(example, 'example.esh')
        pyemc.setup('example.esh')
        if not Path('build.emc').stat().st_size:
            raise RuntimeError('EMC setup produced an empty build.emc')
        pyemc.build('build.emc')
        data = Path('example.data').read_text()
        if not re.search(r'^\s*[1-9]\d*\s+atoms\s*$', data, re.MULTILINE):
            raise RuntimeError('No atoms in the LAMMPS data file')
    finally:
        os.chdir(original)
