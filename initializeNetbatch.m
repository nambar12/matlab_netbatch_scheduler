function taskId = initializeNetbatch(cluster, jsl)
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
tokens = regexp(jsl, '\{(.*?)\}', 'tokens');
% Extract the second token (UNIX, not PC)
folder = tokens{2};
outputFilename = [folder '/' environmentProperties.JobLocation '/task.conf'];
createTaskConfFile(outputFilename, remoteQueue, remoteQslot);

% Create feeder name
feederName = getFeederName();

% Start feeder
commandToRun = sprintf('nbfeeder start --join --name %s', feederName);
try
    % Make the shelled out call to run the command.
    [cmdFailed, cmdOut] = runSchedulerCommand(commandToRun);
catch err
    cmdFailed = true;
    cmdOut = err.message;
end
if cmdFailed
    error('parallelexamples:GenericNetbatch:CreateFeeder', ...
          'Failed to create feeder with the following message:\n%s', cmdOut);
end

% Load configuration file
commandToRun = sprintf('nbtask load --target %s %s', feederName, outputFilename);
try
    % Make the shelled out call to run the command.
    [cmdFailed, cmdOut] = runSchedulerCommand(commandToRun);
catch err
    cmdFailed = true;
    cmdOut = err.message;
end
if cmdFailed
    error('parallelexamples:GenericNetbatch:TaskLoadFailed', ...
          'Task load failed with the following message:\n%s', cmdOut);
end
taskId = extractTaskId(cmdOut);

end
