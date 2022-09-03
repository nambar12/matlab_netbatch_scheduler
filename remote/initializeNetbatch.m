function taskId = initializeNetbatch(cluster, jsl, jobFolder, jobName)
% Initializes the Netbatch cluster
%  TASKID = INITIALIZENETBATCH(CLUSTER, JSL) initializes the Netbatch cluster, based on the
%  RemoteQueue (CLUSTER), RemoteQslot (CLUSTER), and JobStorageLocation (JSL).  Steps include:
%   1. create the task configure file
%   2. start the nbfeeder
%   3. load the task configuration file into the nbfeeder

% Copyright 2022 The MathWorks, Inc.

if isprop(cluster.AdditionalProperties, 'RemoteQueue') ...
        && (ischar(cluster.AdditionalProperties.RemoteQueue) || isstring(cluster.AdditionalProperties.RemoteQueue))
    remoteQueue = cluster.AdditionalProperties.RemoteQueue;
else
    error('parallelexamples:GenericNetbatch:IncorrectArguments', ...
          'RemoteQueue must be a character string');
end

if isprop(cluster.AdditionalProperties, 'RemoteQslot') ...
        && (ischar(cluster.AdditionalProperties.RemoteQslot) || isstring(cluster.AdditionalProperties.RemoteQslot))
    remoteQslot = cluster.AdditionalProperties.RemoteQslot;
else
    error('parallelexamples:GenericNetbatch:IncorrectArguments', ...
          'RemoteQslot must be a character string');
end

% Generate task configuration file
%tokens = regexp(jsl, '\{(.*?)\}', 'tokens');
%Extract the second token (UNIX, not PC)
%folder = tokens{2};
outputFilename = [jsl '/' jobFolder '/task.conf'];
createTaskConfFile(outputFilename, remoteQueue, remoteQslot, jobName);

% Create feeder name
feederName = getFeederName();

% Start feeder
commandToRun = sprintf('nbfeeder start --join --name %s', feederName);
% Execute the command on the remote host.
[cmdFailed, cmdOut] = remoteConnection.runCommand(commandToRun);
if cmdFailed
    error('parallelexamples:GenericNetbatch:CreateFeeder', ...
          'Failed to create feeder to Netbatch using command:\n\t%s.\nReason: %s', ...
          commandToRun, cmdOut);
end

% Load configuration file
commandToRun = sprintf('nbtask load --target %s %s', feederName, outputFilename);
% Execute the command on the remote host.
[cmdFailed, cmdOut] = remoteConnection.runCommand(commandToRun);
if cmdFailed
    error('parallelexamples:GenericNetbatch:TaskLoadFailed', ...
          'Failed to load task to Netbatch using command:\n\t%s.\nReason: %s', ...
          commandToRun, cmdOut);
end

taskId = extractTaskId(cmdOut);

end
