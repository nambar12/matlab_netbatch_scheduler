function communicatingSubmitFcn(cluster, job, environmentProperties)
%COMMUNICATINGSUBMITFCN Submit a communicating MATLAB job to a Netbatch cluster
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you submit a communicating job.
%
% See also parallel.cluster.generic.communicatingDecodeFcn.

% Copyright 2010-2020 The MathWorks, Inc.

% Store the current filename for the errors, warnings and dctSchedulerMessages
currFilename = mfilename;
if ~isa(cluster, 'parallel.Cluster')
    error('parallelexamples:GenericNetbatch:NotClusterObject', ...
        'The function %s is for use with clusters created using the parcluster command.', currFilename)
end

decodeFunction = 'parallel.cluster.generic.communicatingDecodeFcn';

if ~cluster.HasSharedFilesystem
    error('parallelexamples:GenericNetbatch:NotSharedFileSystem', ...
        'The function %s is for use with shared filesystems.', currFilename)
end

if ~strcmpi(cluster.OperatingSystem, 'unix')
        error('parallelexamples:GenericNetbatch:UnsupportedOS', ...
            'The function %s only supports clusters with unix OS.', currFilename)
end


enableDebug = 'false';

% cluster.AdditionalProperties.EnableDebug overrides any local debug
% environment variables on the client
if isprop(cluster.AdditionalProperties, 'EnableDebug') ...
        && islogical(cluster.AdditionalProperties.EnableDebug) ...
        && cluster.AdditionalProperties.EnableDebug
    enableDebug = 'true';
else
    % Local client environment variables to check for debug settings
    environmentVariablesToCheck = {'PARALLEL_SERVER_DEBUG', 'MDCE_DEBUG'};
    for idx = 1:numel(environmentVariablesToCheck)
        debugValue = getenv(environmentVariablesToCheck{idx});
        if ~isempty(debugValue)
            enableDebug = debugValue;
            break
        end
    end
end

% Deduce the correct quote to use based on the OS of the current machine
if ispc
    quote = '"';
else
    quote = '''';
end

% The job specific environment variables
% Remove leading and trailing whitespace from the MATLAB arguments
matlabArguments = strtrim(environmentProperties.MatlabArguments);

variables = {'PARALLEL_SERVER_DECODE_FUNCTION', decodeFunction; ...
    'PARALLEL_SERVER_STORAGE_CONSTRUCTOR', environmentProperties.StorageConstructor; ...
    'PARALLEL_SERVER_JOB_LOCATION', environmentProperties.JobLocation; ...
    'PARALLEL_SERVER_MATLAB_EXE', environmentProperties.MatlabExecutable; ...
    'PARALLEL_SERVER_MATLAB_ARGS', matlabArguments; ...
    'PARALLEL_SERVER_DEBUG', enableDebug; ...
    'MLM_WEB_LICENSE', environmentProperties.UseMathworksHostedLicensing; ...
    'MLM_WEB_USER_CRED', environmentProperties.UserToken; ...
    'MLM_WEB_ID', environmentProperties.LicenseWebID; ...
    'PARALLEL_SERVER_LICENSE_NUMBER', environmentProperties.LicenseNumber; ...
    'PARALLEL_SERVER_STORAGE_LOCATION', environmentProperties.StorageLocation; ...
    'PARALLEL_SERVER_CMR', cluster.ClusterMatlabRoot; ...
    'PARALLEL_SERVER_TOTAL_TASKS', num2str(environmentProperties.NumberOfTasks); ...
    'PARALLEL_SERVER_NUM_THREADS', num2str(cluster.NumThreads)};

% The local job directory
localJobDirectory = cluster.getJobFolder(job);

% generate task configuration file
remoteQueue = cluster.AdditionalProperties.RemoteQueue;
remoteQslot = cluster.AdditionalProperties.RemoteQslot;
jsl = environmentProperties.StorageLocation;
sidx = strfind(jsl,'{');
eidx = strfind(jsl,'}');
folder = environmentProperties.StorageLocation(sidx(end)+1:eidx(end)-1);
outputFilename = [folder '/' environmentProperties.JobLocation '/task.conf'];
createTaskConfFile(outputFilename, remoteQueue, remoteQslot);

feederName = getFeederName();
commandToRun = ['nbfeeder start --join --name ' feederName];
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


commandToRun = ['nbtask load --target ' feederName ' ' outputFilename];
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


% Specify the job wrapper script to use.
if isprop(cluster.AdditionalProperties, 'UseSmpd') && cluster.AdditionalProperties.UseSmpd
    scriptName = 'communicatingJobWrapperSmpd.sh';
else
    scriptName = 'communicatingJobWrapper.sh';
end
% The wrapper script is in the same directory as this file
dirpart = fileparts(mfilename('fullpath'));
quotedScriptName = sprintf('%s%s%s', quote, fullfile(dirpart, scriptName), quote);

% Choose a file for the output. Please note that currently, JobStorageLocation refers
% to a directory on disk, but this may change in the future.
logFile = cluster.getLogLocation(job);
quotedLogFile = sprintf('%s%s%s', quote, logFile, quote);
dctSchedulerMessage(5, '%s: Using %s as log file', currFilename, quotedLogFile);

jobName = sprintf('Job%d', job.ID);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CUSTOMIZATION MAY BE REQUIRED %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% You may wish to customize this section to match your cluster,
% for example if you wish to limit the number of nodes that
% can be used for a single job.
%% RSN: TODO: Don't hardcode slots_per_host
additionalSubmitArgs = sprintf('--parallel slots=%d,slots_per_host=1', environmentProperties.NumberOfTasks+1);
dctSchedulerMessage(4, '%s: Requesting %d slots.', currFilename, environmentProperties.NumberOfTasks);
commonSubmitArgs = getCommonSubmitArgs(cluster);
if ~isempty(commonSubmitArgs) && ischar(commonSubmitArgs)
    additionalSubmitArgs = strtrim([additionalSubmitArgs, ' ', commonSubmitArgs]);
end
% Create a script to submit a Netbatch job - this will be created in the job directory
dctSchedulerMessage(5, '%s: Generating script for task.', currFilename);
localScriptName = tempname(localJobDirectory);
machineClass = cluster.AdditionalProperties.MachineClass;
createSubmitScript(localScriptName, jobName, quotedLogFile, quotedScriptName, ...
    variables, additionalSubmitArgs, taskId, machineClass);
% Create the command to run
commandToRun = sprintf('sh %s', localScriptName);

% Now ask the cluster to run the submission command
dctSchedulerMessage(4, '%s: Submitting job using command:\n\t%s', currFilename, commandToRun);
try
    % Make the shelled out call to run the command.
    [cmdFailed, cmdOut] = runSchedulerCommand(commandToRun);
catch err
    cmdFailed = true;
    cmdOut = err.message;
end
if cmdFailed
    error('parallelexamples:GenericNetbatch:SubmissionFailed', ...
        'Submit failed with the following message:\n%s', cmdOut);
end

dctSchedulerMessage(1, '%s: Job output will be written to: %s\nSubmission output: %s\n', currFilename, logFile, cmdOut);

jobIDs = extractJobId(cmdOut);
% jobIDs must be a cell array
if isempty(jobIDs)
    warning('parallelexamples:GenericNetbatch:FailedToParseSubmissionOutput', ...
        'Failed to parse the job identifier from the submission output: "%s"', ...
        cmdOut);
end
if ~iscell(jobIDs)
    jobIDs = {jobIDs};
end
if numel(job.Tasks) == 1
    schedulerIDs = jobIDs{1};
else
    schedulerIDs = repmat(jobIDs, size(job.Tasks));
end
set(job.Tasks, 'SchedulerID', schedulerIDs);

cluster.setJobClusterData(job, struct('type', 'generic'));
