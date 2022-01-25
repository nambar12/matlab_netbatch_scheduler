function state = getJobStateFcn(cluster, job, state)
%GETJOBSTATEFCN Gets the state of a job from Netbatch
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you query the state of a job.

% Copyright 2010-2020 The MathWorks, Inc.

% Store the current filename for the errors, warnings and
% dctSchedulerMessages
currFilename = mfilename;
if ~isa(cluster, 'parallel.Cluster')
    error('parallelexamples:GenericNetbatch:SubmitFcnError', ...
        'The function %s is for use with clusters created using the parcluster command.', currFilename)
end
if ~cluster.HasSharedFilesystem
    error('parallelexamples:GenericNetbatch:NotSharedFileSystem', ...
        'The function %s is for use with shared filesystems.', currFilename)
end

% Get the information about the actual cluster used
data = cluster.getJobClusterData(job);
if isempty(data)
    % This indicates that the job has not been submitted, so just return
    dctSchedulerMessage(1, '%s: Job cluster data was empty for job with ID %d.', currFilename, job.ID);
    return
end
% Shortcut if the job state is already finished or failed
jobInTerminalState = strcmp(state, 'finished') || strcmp(state, 'failed');
if jobInTerminalState
    return
end
[schedulerIDs, numSubmittedTasks] = getSimplifiedSchedulerIDsForJob(job);

%% RSN: TODO: Check if we need to parse this differently
%%            "jobid==<number>||jobid==<number2>"
%%            ids = sprintf('jobid==%d||', jobIDs{:});
%%            ids(end-1:end) = [];
feederName = getFeederName();
commandToRun = sprintf('nbstatus jobs --target %s --format script --fields jobid,status,exitstatus "%s"', feederName, sprintf('%s ', schedulerIDs{:}));
dctSchedulerMessage(4, '%s: Querying cluster for job state using command:\n\t%s', currFilename, commandToRun);

try
    % We will ignore the status returned from the state command because
    % a non-zero status is returned if the job no longer exists
    % Make the shelled out call to run the command.
    [~, cmdOut] = runSchedulerCommand(commandToRun);
catch err
    ex = MException('parallelexamples:GenericNetbatch:FailedToGetJobState', ...
        'Failed to get job state from cluster.');
    ex = ex.addCause(err);
    throw(ex);
end

clusterState = iExtractJobState(cmdOut, numSubmittedTasks);
dctSchedulerMessage(6, '%s: State %s was extracted from cluster output.', currFilename, clusterState);

% If we could determine the cluster's state, we'll use that, otherwise
% stick with MATLAB's job state.
if ~strcmp(clusterState, 'unknown')
    state = clusterState;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function state = iExtractJobState(nbstatusOut, numSlaves)
% Function to extract the job state from the output of nbstatus
% How many Waiting jobs
numPending = numel(regexp(nbstatusOut, 'Wait'));
% How many Running jobs
numRunning = numel(regexp(nbstatusOut, 'Run'));
% How many Failed jobs
numFailed = numel(regexp(nbstatusOut, 'EXIT|ZOMBI'));
% How many Completed
numFinished = numel(regexp(nbstatusOut, 'Comp')) - numel(regexp(nbstatusOut,':'));

% If the number of finished jobs is the same as the number of jobs that we
% asked about then the entire job has finished.
if numFinished == numSlaves && numFinished > 0
    state = 'finished';
    return
end

% Any running indicates that the job is running
if numRunning > 0
    state = 'running';
    return
end
% We know numRunning == 0 so if there are some still pending then the
% job must be queued again, even if there are some finished
if numPending > 0
    state = 'queued';
    return
end
% Deal with any tasks that have failed
if numFailed > 0
    % Set this job to be failed
    state = 'failed';
    return
end

state = 'unknown';
