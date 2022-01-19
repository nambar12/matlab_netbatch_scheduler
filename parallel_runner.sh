#!/bin/bash

# RSN: TODO: Remove hardcoded path (i.e., R2021a) to hydra_pmi_proxy
# RSN: TODO: Comment (1) -x and (2) hydra_pmi_proxy

for arg do
    shift
    [ "$arg" = "-x" ] && continue
    arg=$(echo $arg | sed 's/"//g')
    set -- "$@" "$arg"
done

nbjob prun --mode interactive --host "$@"
