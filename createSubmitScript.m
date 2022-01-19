function createSubmitScript(outputFilename, jobName, quotedLogFile, quotedScriptName, ...
    environmentVariables, additionalSubmitArgs, taskId, clazz, jobArrayString)
% Create a script that sets the correct environment variables and then
% executes the Netbatch nbjob command.

% Copyright 2010-2021 The MathWorks, Inc.

if nargin < 9
    jobArrayString = [];
end

dctSchedulerMessage(5, '%s: Creating submit script for %s at %s', mfilename, jobName, outputFilename);

% Open file in binary mode to make it cross-platform.
fid = fopen(outputFilename, 'w');
if fid < 0
    error('parallelexamples:GenericNetbatch:FileError', ...
        'Failed to open file %s for writing', outputFilename);
end

% Specify Shell to use
fprintf(fid, '#!/bin/sh\n');

% Write the commands to set and export environment variables
for ii = 1:size(environmentVariables, 1)
    fprintf(fid, 'export %s=''%s''\n', environmentVariables{ii,1}, environmentVariables{ii,2});
end

% Generate the command to run and write it.
commandToRun = getSubmitString(jobName, quotedLogFile, quotedScriptName, ...
    additionalSubmitArgs, taskId, clazz, jobArrayString);
fprintf(fid, '%s\n', commandToRun);

% Close the file
fclose(fid);
