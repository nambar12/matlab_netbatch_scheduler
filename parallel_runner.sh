#!/bin/bash

# RSN: TODO: Remove hardcoded path (i.e., R2021a) to hydra_pmi_proxy
# RSN: TODO: Comment (1) -x and (2) hydra_pmi_proxy

for arg do
    shift
    [ "$arg" = "-x" ] && continue
    if [ "$arg" = "\"/nfs/site/disks/crt_tool_rtl001/matlab/R2021a/bin/glnxa64/hydra_pmi_proxy\"" ]
    then
        arg="/nfs/site/disks/crt_tool_rtl001/matlab/R2021a/bin/glnxa64/hydra_pmi_proxy"
    fi
    set -- "$@" "$arg"
done

nbjob prun --mode interactive --host "$@"
