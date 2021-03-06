#!/bin/sh
# This wrapper script is intended to be submitted to Netbatch to support
# communicating jobs.
#
# This script uses the following environment variables set by the submit MATLAB code:
# PARALLEL_SERVER_CMR         - the value of ClusterMatlabRoot (may be empty)
# PARALLEL_SERVER_MATLAB_EXE  - the MATLAB executable to use
# PARALLEL_SERVER_MATLAB_ARGS - the MATLAB args to use
# PARALLEL_SERVER_DEBUG       - used to debug problems on the cluster
#
# The following environment variables are forwarded through mpiexec:
# PARALLEL_SERVER_DECODE_FUNCTION     - the decode function to use
# PARALLEL_SERVER_STORAGE_LOCATION    - used by decode function
# PARALLEL_SERVER_STORAGE_CONSTRUCTOR - used by decode function
# PARALLEL_SERVER_JOB_LOCATION        - used by decode function
#
# The following environment variables are set by Netbatch:
# NB_PARALLEL_JOB_HOSTS - list of hostnames with their associated number of processors allocated to this Netbatch job

# Copyright 2006-2021 The MathWorks, Inc.

# If PARALLEL_SERVER_ environment variables are not set, assign any
# available values with form MDCE_ for backwards compatibility
PARALLEL_SERVER_CMR=${PARALLEL_SERVER_CMR:="${MDCE_CMR}"}
PARALLEL_SERVER_MATLAB_EXE=${PARALLEL_SERVER_MATLAB_EXE:="${MDCE_MATLAB_EXE}"}
PARALLEL_SERVER_MATLAB_ARGS=${PARALLEL_SERVER_MATLAB_ARGS:="${MDCE_MATLAB_ARGS}"}
PARALLEL_SERVER_DEBUG=${PARALLEL_SERVER_DEBUG:="${MDCE_DEBUG}"}

# Echo the resources that the scheduler has allocated to this job:
echo -e "The scheduler has allocated the following resources to this job (format is [hostname] [number of processors on host]):\n${NB_PARALLEL_JOB_HOSTS:?"Host list undefined"}"

# Create full path to mw_mpiexec if needed.
FULL_MPIEXEC=${PARALLEL_SERVER_CMR:+${PARALLEL_SERVER_CMR}/bin/}mw_mpiexec

# Label stdout/stderr with the rank of the process
MPI_VERBOSE=-l

# Increase the verbosity of mpiexec if PARALLEL_SERVER_DEBUG is set and not false
if [ ! -z "${PARALLEL_SERVER_DEBUG}" ] && [ "${PARALLEL_SERVER_DEBUG}" != "false" ] ; then
    MPI_VERBOSE="${MPI_VERBOSE} -v -print-all-exitcodes"
fi

HOSTS=`echo ${NB_PARALLEL_JOB_HOSTS} | tr " " ","`
export HOSTNAME=`echo ${NB_PARALLEL_JOB_HOSTS} | awk '{print $1}'`

# Get dir name of the current script
DIRNAME='/usr/bin/dirname'
BASENAME='/bin/basename'
if [ ! -x "$BASENAME" ]; then
      BASENAME='/usr/bin/basename'
fi
BIN_DIR=`$DIRNAME "${BASH_SOURCE[0]}"`

# Construct the command to run.
# Override default launcher, ssh, with call to 'nbjob prun'.
CMD="\"${FULL_MPIEXEC}\" -bind-to core ${MPI_VERBOSE} -launcher-exec ${BIN_DIR}/parallel_runner.sh -hosts ${HOSTS} \"${PARALLEL_SERVER_MATLAB_EXE}\" ${PARALLEL_SERVER_MATLAB_ARGS}"

# Echo the command so that it is shown in the output log.
echo $CMD

# Execute the command.
eval $CMD

MPIEXEC_EXIT_CODE=${?}
if [ ${MPIEXEC_EXIT_CODE} -eq 42 ] ; then
    # Get here if user code errored out within MATLAB. Overwrite this to zero in
    # this case.
    echo "Overwriting MPIEXEC exit code from 42 to zero (42 indicates a user-code failure)"
    MPIEXEC_EXIT_CODE=0
fi
echo "Exiting with code: ${MPIEXEC_EXIT_CODE}"
exit ${MPIEXEC_EXIT_CODE}
