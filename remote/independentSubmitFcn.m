function independentSubmitFcn(cluster, job, environmentProperties)
%INDEPENDENTSUBMITFCN Submit a MATLAB job to a Netbatch cluster
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you submit an independent job.
%
% See also parallel.cluster.generic.independentDecodeFcn.

% Copyright 2010-2021 The MathWorks, Inc.

% Store the current filename for the errors, warnings and
% dctSchedulerMessages.
currFilename = mfilename;
if ~isa(cluster, 'parallel.Cluster')
    error('parallelexamples:GenericNetbatch:NotClusterObject', ...
        'The function %s is for use with clusters created using the parcluster command.', currFilename)
end

decodeFunction = 'parallel.cluster.generic.independentDecodeFcn';

if ~cluster.HasSharedFilesystem
    error('parallelexamples:GenericNetbatch:NotSharedFileSystem', ...
        'The function %s is for use with shared filesystems.', currFilename)
end

if ~strcmpi(cluster.OperatingSystem, 'unix')
    error('parallelexamples:GenericNetbatch:UnsupportedOS', ...
        'The function %s only supports clusters with unix OS.', currFilename)
end

remoteConnection = getRemoteConnection(cluster);
[useJobArrays, maxJobArraySize] = iGetJobArrayProps(cluster, remoteConnection);
% Store data for future reference
cluster.UserData.UseJobArrays = useJobArrays;
if useJobArrays
    cluster.UserData.MaxJobArraySize = maxJobArraySize;
end

% Determine the debug setting. Setting to true makes the MATLAB workers
% output additional logging. If EnableDebug is set in the cluster object's
% AdditionalProperties, that takes precedence. Otherwise, look for the
% PARALLEL_SERVER_DEBUG and MDCE_DEBUG environment variables in that order.
% If nothing is set, debug is false.
enableDebug = 'false';
if isprop(cluster.AdditionalProperties, 'EnableDebug') ...
        && islogical(cluster.AdditionalProperties.EnableDebug)
    % Use AdditionalProperties.EnableDebug, if it is set
    enableDebug = char(string(cluster.AdditionalProperties.EnableDebug));
else
    % Otherwise check the environment variables set locally on the client
    environmentVariablesToCheck = {'PARALLEL_SERVER_DEBUG', 'MDCE_DEBUG'};
    for idx = 1:numel(environmentVariablesToCheck)
        debugValue = getenv(environmentVariablesToCheck{idx});
        if ~isempty(debugValue)
            enableDebug = debugValue;
            break
        end
    end
end

% Get the correct quote and file separator for the Cluster OS.
% This check is unnecessary in this file because we explicitly
% checked that the ClusterOsType is unix.  This code is an example
% of how to deal with clusters that can be unix or pc.
if strcmpi(cluster.OperatingSystem, 'unix')
    quote = '''';
    fileSeparator = '/';
else
    quote = '"';
    fileSeparator = '\';
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
    'PARALLEL_SERVER_STORAGE_LOCATION', environmentProperties.StorageLocation};
% Trim the environment variables of empty values.
nonEmptyValues = cellfun(@(x) ~isempty(strtrim(x)), variables(:,2));
variables = variables(nonEmptyValues, :);

% The local job directory
localJobDirectory = cluster.getJobFolder(job);
% Find out how we should refer to the job storage location on the cluster.
remoteJobDirectory = cluster.getJobFolderOnCluster(job);

% The script name is independentJobWrapper.sh
scriptName = 'independentJobWrapper.sh';
% The wrapper script is in the same directory as this file
dirpart = fileparts(mfilename('fullpath'));
localScript = fullfile(dirpart, scriptName);
% Copy the local wrapper script to the job directory
copyfile(localScript, localJobDirectory);

% The command that will be executed on the remote host to run the job.
remoteScriptName = sprintf('%s%s%s', remoteJobDirectory, fileSeparator, scriptName);
quotedScriptName = sprintf('%s%s%s', quote, remoteScriptName, quote);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CUSTOMIZATION MAY BE REQUIRED %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
additionalSubmitArgs = '';
commonSubmitArgs = getCommonSubmitArgs(cluster);
if ~isempty(commonSubmitArgs) && ischar(commonSubmitArgs)
    additionalSubmitArgs = strtrim([additionalSubmitArgs, ' ', commonSubmitArgs]);
end

% Only keep and submit tasks that are not cancelled. Cancelled tasks
% will have errors.
isPendingTask = cellfun(@isempty, get(job.Tasks, {'Error'}));
tasks = job.Tasks(isPendingTask);
taskIDs = cell2mat(get(tasks, {'ID'}));
numberOfTasks = numel(tasks);

% Only use job arrays when you can get enough use out of them.
if numberOfTasks < 2 || maxJobArraySize <= 0
    useJobArrays = false;
end

if useJobArrays
    % Netbatch places a limit on the number of jobs that may be submitted as a
    % single job array. The default value is 1,000, or 10,000 if the cluster
    % has been configured with the HIGH_THROUGHPUT template. If there are
    % more tasks in this job than will fit in a single job array, submit
    % the tasks as several smaller job arrays. Netbatch accepts job arrays with
    % indices greater than maxJobArraySize, providing the number of indices
    % is less than maxJobArraySize.  For example, if maxJobArraySize is
    % 1000, then indices [1001-2000] would be valid.
    taskIDGroupsForJobArrays = iCalculateTaskIDGroupsForJobArrays(taskIDs, maxJobArraySize);
    
    jobName = sprintf('Job%d',job.ID);
    numJobArrays = numel(taskIDGroupsForJobArrays);
    commandsToRun = cell(numJobArrays, 1);
    jobIDs = cell(numJobArrays, 1);
    schedulerJobArrayIndices = cell(numJobArrays, 1);
    for ii = 1:numJobArrays
        schedulerJobArrayIndices{ii} = taskIDGroupsForJobArrays{ii};
        
        % Create a character vector with the ranges of IDs to submit.
        jobArrayString = iCreateJobArrayString(schedulerJobArrayIndices{ii});
        
        logFileName = 'Task%I.log';
        % Choose a file for the output. Please note that currently,
        % JobStorageLocation refers to a directory on disk, but this may
        % change in the future.
        logFile = sprintf('%s%s%s', remoteJobDirectory, fileSeparator, logFileName);
        quotedLogFile = sprintf('%s%s%s', quote, logFile, quote);
        dctSchedulerMessage(5, '%s: Using %s as log file', currFilename, quotedLogFile);
        
        environmentVariables = variables;
        % Create a script to submit a Netbatch job - this
        % will be created in the job directory
        dctSchedulerMessage(5, '%s: Generating script for job array %i', currFilename, ii);
        commandsToRun{ii} = iGetCommandToRun(localJobDirectory, remoteJobDirectory, fileSeparator, quote, jobName, ...
            quotedLogFile, quotedScriptName, environmentVariables, additionalSubmitArgs, taskId, machineClass, jobArrayString);
    end
else
    % Do not use job arrays and submit each task individually.
    taskLocations = environmentProperties.TaskLocations(isPendingTask);
    jobIDs = cell(1, numberOfTasks);
    commandsToRun = cell(numberOfTasks, 1);
    % Loop over every task we have been asked to submit
    for ii = 1:numberOfTasks
        taskLocation = taskLocations{ii};
        % Add the task location to the environment variables
        environmentVariables = [variables; ...
            {'PARALLEL_SERVER_TASK_LOCATION', taskLocation}];
        
        % Choose a file for the output. Please note that currently,
        % JobStorageLocation refers to a directory on disk, but this may
        % change in the future.
        logFile = sprintf('%s%s%s', remoteJobDirectory, fileSeparator, sprintf('Task%d.log', taskIDs(ii)));
        quotedLogFile = sprintf('%s%s%s', quote, logFile, quote);
        dctSchedulerMessage(5, '%s: Using %s as log file', currFilename, quotedLogFile);
        
        % Submit one task at a time
        jobName = sprintf('Job%d.%d', job.ID, taskIDs(ii));
        
        % Create a script to submit a Netbatch job - this will be created in
        % the job directory
        dctSchedulerMessage(5, '%s: Generating script for task %i', currFilename, ii);
        commandsToRun{ii} = iGetCommandToRun(localJobDirectory, remoteJobDirectory, fileSeparator, quote, jobName, ...
            quotedLogFile, quotedScriptName, environmentVariables, additionalSubmitArgs, taskId, machineClass);
    end
end


for ii=1:numel(commandsToRun)
    commandToRun = commandsToRun{ii};
    jobIDs{ii} = iSubmitJobUsingCommand(remoteConnection, job, commandToRun);
end

% Define the schedulerIDs
if useJobArrays
    % The scheduler ID of each task is a combination of the job ID and the
    % scheduler array index. cellfun pairs each job ID with its
    % corresponding scheduler array indices in schedulerJobArrayIndices and
    % returns the combination of both. For example, if jobIDs = {1,2} and
    % schedulerJobArrayIndices = {[1,2];[3,4]}, the schedulerID is given by
    % combining 1 with [1,2] and 2 with [3,4], in the canonical form of the
    % scheduler.
    schedulerIDs = cellfun(@(jobID,arrayIndices) jobID + "[" + arrayIndices + "]", ...
        jobIDs, schedulerJobArrayIndices, 'UniformOutput', false);
    schedulerIDs = vertcat(schedulerIDs{:});
else
    % The scheduler ID of each task is the job ID.
    schedulerIDs = convertCharsToStrings(jobIDs);
end

% Set the scheduler ID for each task
set(tasks, 'SchedulerID', schedulerIDs);

% Set the cluster host on the job cluster data
jobData = struct('type', 'generic', ...
    'RemoteHost',  remoteConnection.Hostname);
cluster.setJobClusterData(job, jobData);

function [useJobArrays, maxJobArraySize] = iGetJobArrayProps(cluster, remoteConnection)
% Look for useJobArrays and maxJobArray size in the following order:
% 1.  Additional Properties
% 2.  User Data
% 3.  Query scheduler for MaxJobArraySize
% Set defaults
useJobArrays = false;
maxJobArraySize = 0;
return

if isprop(cluster.AdditionalProperties, 'UseJobArrays')
    if ~islogical(cluster.AdditionalProperties.UseJobArrays)
        error('parallelexamples:GenericNetbatch:IncorrectArguments', ...
            'UseJobArrays must be a logical scalar');
    end
    useJobArrays = cluster.AdditionalProperties.UseJobArrays;
elseif isfield(cluster.UserData,'UseJobArrays')
    % If no user preference, then use job arrays by default.
    useJobArrays = cluster.UserData.UseJobArrays;
end

if ~useJobArrays
    return;
end

%% RSN: TODO: Add support for JAs later.
if isprop(cluster.AdditionalProperties, 'MaxJobArraySize')
    if ~isnumeric(cluster.AdditionalProperties.MaxJobArraySize) || ...
            cluster.AdditionalProperties.MaxJobArraySize < 1
        error('parallelexamples:GenericNetbatch:IncorrectArguments', ...
            'MaxJobArraySize must be a positive integer');
    end
    maxJobArraySize = cluster.AdditionalProperties.MaxJobArraySize;
    return
end
if isfield(cluster.UserData,'MaxJobArraySize')
    maxJobArraySize = cluster.UserData.MaxJobArraySize;
    return
end

[useJobArrays, maxJobArraySize] = iGetJobArrayPropsFromScheduler(remoteConnection);

function [useJobArrays, maxJobArraySize] = iGetJobArrayPropsFromScheduler (remoteConnection)
% get job array information by querying the scheduler.
commandToRun = 'bparams -a';
try
    % Execute the command on the remote host.
    [cmdFailed, cmdOut] = remoteConnection.runCommand(commandToRun);
catch err
    cmdFailed = true;
    cmdOut = err.message;
end
if cmdFailed
    error('parallelexamples:GenericNetbatch:FailedToRetrieveInfo', ...
        'Failed to retrieve Netbatch configuration information using command:\n\t%s.\nReason: %s', ...
        commandToRun, cmdOut);
end

maxJobArraySize = 0;
% Extract the maximum array size for job arrays. For Netbatch, the configuration
% line that contains the maximum array size looks like this:
% MAX_JOB_ARRAY_SIZE = 1000
% Use a regular expression to extract this parameter.
tokens = regexp(cmdOut,'MAX_JOB_ARRAY_SIZE\s*=\s*(\d+)', ...
    'tokens','once');

if isempty(tokens)
    % No job array support.
    useJobArrays = false;
    return;
end

useJobArrays = true;
% Set the maximum array size.
maxJobArraySize = str2double(tokens{1});

function commandToRun = iGetCommandToRun(localJobDirectory, remoteJobDirectory, fileSeparator, quote, jobName, ...
    quotedLogFile, quotedScriptName, environmentVariables, additionalSubmitArgs, taskId, machineClass, jobArrayString)
if nargin < 12
    jobArrayString = [];
end

localScriptName = tempname(localJobDirectory);
[~, scriptName] = fileparts(localScriptName);
remoteScriptLocation = sprintf('%s%s%s%s%s', quote, remoteJobDirectory, fileSeparator, scriptName, quote);
createSubmitScript(localScriptName, jobName, quotedLogFile, quotedScriptName, ...
    environmentVariables, additionalSubmitArgs, taskId, machineClass, jobArrayString);
% Create the command to run on the remote host.
commandToRun = sprintf('sh %s', remoteScriptLocation);

function jobID = iSubmitJobUsingCommand(remoteConnection, job, commandToRun)
currFilename = mfilename;
% Ask the cluster to run the submission command.
dctSchedulerMessage(4, '%s: Submitting job %d using command:\n\t%s', currFilename, job.ID, commandToRun);
% Execute the command on the remote host.
[cmdFailed, cmdOut] = remoteConnection.runCommand(commandToRun);
if cmdFailed
    error('parallelexamples:GenericNetbatch:FailedToSubmitJob', ...
        'Failed to submit job to Netbatch using command:\n\t%s.\nReason: %s', ...
        commandToRun, cmdOut);
end

jobID = extractJobId(cmdOut);
if isempty(jobID)
       warning('parallelexamples:GenericNetbatch:FailedToParseSubmissionOutput', ...
        'Failed to parse the job identifier from the submission output: "%s"', ...
        cmdOut);
end

function taskIDGroupsForJobArrays = iCalculateTaskIDGroupsForJobArrays(taskIDsToSubmit, maxJobArraySize)
% Calculates the groups of task IDs to be submitted as job arrays.

% The number of tasks in each job array must be less than maxJobArraySize.
numTasks = numel(taskIDsToSubmit);
jobArraySizes = iCalculateJobArraySizes(numTasks, maxJobArraySize);
taskIDGroupsForJobArrays = mat2cell(taskIDsToSubmit, jobArraySizes);

function jobArraySizes = iCalculateJobArraySizes(numTasks, maxJobArraySize)
if isinf(maxJobArraySize)
    numJobArrays = 1;
else
    numJobArrays = ceil(numTasks./maxJobArraySize);
end
jobArraySizes = repmat(maxJobArraySize, 1, numJobArrays);
remainder = mod(numTasks, maxJobArraySize);
if remainder > 0
    jobArraySizes(end) = remainder;
end

function rangesString = iCreateJobArrayString(taskIDs)
% Create a character vector with the ranges of task IDs to submit
if taskIDs(end) - taskIDs(1) + 1 == numel(taskIDs)
    % There is only one range.
    rangesString = sprintf('%d-%d',taskIDs(1),taskIDs(end));
else
    % There are several ranges.
    % Calculate the step size between task IDs.
    step = diff(taskIDs);
    % Where the step changes, a range ends and another starts. Include
    % the initial and ending IDs in the ranges as well.
    isStartOfRange = [true; step > 1];
    isEndOfRange   = [step > 1; true];
    rangesString = strjoin(compose('%d-%d', ...
        taskIDs(isStartOfRange),taskIDs(isEndOfRange)),',');
end
