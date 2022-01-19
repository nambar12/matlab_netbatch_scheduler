function submitString = getSubmitString(jobName, quotedLogFile, quotedCommand, ...
    additionalSubmitArgs, taskId, machineClass, jobArrayString)
%GETSUBMITSTRING Gets the correct nbjob command for a Netbatch cluster

% Copyright 2010-2019 The MathWorks, Inc.

% Submit to Netbatch using nbjob.  Note the following:
% "-J " - specifies the job name
% "-o" - specifies where standard output goes to (and standard error, when -e is not specified)
% Note that extra spaces in the nbjob command are permitted

%{
%% RSN: TODO: Add support for JAs later.
if ~isempty(jobArrayString)
    jobArrayString = strcat('[', jobArrayString, ']');
end
%}

feederName = getFeederName();
submitString = sprintf('nbjob run --properties name=%s --log-file %s --target %s --class "%s" --task %s %s %s', jobName, quotedLogFile, feederName, machineClass, taskId, additionalSubmitArgs, quotedCommand);
