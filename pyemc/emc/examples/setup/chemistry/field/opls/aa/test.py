import os
from subprocess import call

EMC_SETUP = os.environ.get('EMC_SETUP')
EMC_EXEC = os.environ.get('EMC_EXEC')

tmp_eshfile = 'name.esh'
try:
    call('perl {} {}'.format(EMC_SETUP, tmp_eshfile), shell=True)
except BaseException:
    print('problem setting up emc.')

try:
    call('{} build.emc'.format(EMC_EXEC), shell=True)
except BaseException:
    print('problem running emc.')
