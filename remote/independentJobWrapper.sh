#!/bin/sh
# This wrapper script is intended to support independent execution.
#
# This script uses the following environment variables set by the submit MATLAB code:
# PARALLEL_SERVER_MATLAB_EXE  - the MATLAB executable to use
# PARALLEL_SERVER_MATLAB_ARGS - the MATLAB args to use

# Copyright 2010-2020 The MathWorks, Inc.

# If PARALLEL_SERVER_ environment variables are not set, assign any
# available values with form MDCE_ for backwards compatibility
PARALLEL_SERVER_MATLAB_EXE=${PARALLEL_SERVER_MATLAB_EXE:="${MDCE_MATLAB_EXE}"}
PARALLEL_SERVER_MATLAB_ARGS=${PARALLEL_SERVER_MATLAB_ARGS:="${MDCE_MATLAB_ARGS}"}

: <<EOF
# RSN: TODO: Add support for JAs later.
if [ ! -z "${LSB_JOBINDEX}" ] && [ "${LSB_JOBINDEX}" -ne "0" ] ; then
    # Use job arrays
    export PARALLEL_SERVER_TASK_LOCATION="${PARALLEL_SERVER_JOB_LOCATION}/Task${LSB_JOBINDEX}";
    export MDCE_TASK_LOCATION="${MDCE_JOB_LOCATION}/Task${LSB_JOBINDEX}";
fi
EOF

echo "Executing: ${PARALLEL_SERVER_MATLAB_EXE} ${PARALLEL_SERVER_MATLAB_ARGS}"
eval "${PARALLEL_SERVER_MATLAB_EXE}" ${PARALLEL_SERVER_MATLAB_ARGS}
EXIT_CODE=${?}
echo "Exiting with code: ${EXIT_CODE}"
exit ${EXIT_CODE}
