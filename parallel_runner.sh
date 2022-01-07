#!/bin/bash


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
