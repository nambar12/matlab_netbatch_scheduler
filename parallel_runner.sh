#!/bin/bash

# since ssh is the default launcher, mpiexec use -x when running it
# get rid of it since we don't need it when running the nbjob prun command
#
# Also, ssh launcher adds quotes to the 1st arg - hydra_pmi_proxy.
# The ssh command escapes these qoutes. This creates bad command for the
# nbjob prun so need to remove the quotes from all arguments
#

for arg do
    shift
    [ "$arg" = "-x" ] && continue
    arg=$(echo $arg | sed 's/"//g')
    set -- "$@" "$arg"
done

nbjob prun --mode interactive --host "$@"
