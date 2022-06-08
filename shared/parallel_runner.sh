#!/bin/bash

# Since ssh is the default launcher, mpiexec use -x when running it. Get rid of -x since we don't
# need it when running the 'nbjob prun' command.
#
# Also, ssh launcher adds quotes to the 1st arg - 'hydra_pmi_proxy'.  The ssh command escapes these
# quotes. This creates a bad command for 'nbjob prun', so we need to remove the quotes from all
# arguments.

for arg do
    shift
    [ "$arg" = "-x" ] && continue
    arg=$(echo $arg | sed 's/"//g')
    set -- "$@" "$arg"
done

nbjob prun --mode interactive --host "$@"
