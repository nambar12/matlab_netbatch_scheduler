function submitString = getSubmitString(jobName, quotedLogFile, quotedCommand, ...
    additionalSubmitArgs, jobArrayString)
%GETSUBMITSTRING Gets the correct nbjob command for a Netbatch cluster

% Copyright 2010-2019 The MathWorks, Inc.

% Submit to Netbatch using nbjob.  Note the following:
% "-J " - specifies the job name
% "-o" - specifies where standard output goes to (and standard error, when -e is not specified)
% Note that extra spaces in the nbjob command are permitted

%{
% RSN: No current support for JAs
if ~isempty(jobArrayString)
    jobArrayString = strcat('[', jobArrayString, ']');
end
%}

submitString = sprintf('nbjob run --properties name=%s --log-file %s --target matlab --class SLES12 --task 1 %s %s', jobName, quotedLogFile, additionalSubmitArgs, quotedCommand);
