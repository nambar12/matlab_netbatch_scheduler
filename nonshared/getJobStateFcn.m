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
if cluster.HasSharedFilesystem
    error('parallelexamples:GenericNetbatch:NotNonSharedFileSystem', ...
        'The function %s is for use with nonshared filesystems.', currFilename)
end

% Get the information about the actual cluster used
data = cluster.getJobClusterData(job);
if isempty(data)
    % This indicates that the job has not been submitted, so just return
    dctSchedulerMessage(1, '%s: Job cluster data was empty for job with ID %d.', currFilename, job.ID);
    return
end
try
    hasDoneLastMirror = data.HasDoneLastMirror;
catch err
    ex = MException('parallelexamples:GenericNetbatch:FailedToRetrieveRemoteParameters', ...
        'Failed to retrieve remote parameters from the job cluster data.');
    ex = ex.addCause(err);
    throw(ex);
end
% Shortcut if the job state is already finished or failed
jobInTerminalState = strcmp(state, 'finished') || strcmp(state, 'failed');
% and we have already done the last mirror
if jobInTerminalState && hasDoneLastMirror
    return
end
remoteConnection = getRemoteConnection(cluster);
[schedulerIDs, numSubmittedTasks] = getSimplifiedSchedulerIDsForJob(job);

% Required format: "jobid==<number>||jobid==<number2>"
ids = sprintf('jobid==%s||', schedulerIDs{:});
ids(end-1:end) = [];
feederName = getFeederName();
commandToRun = sprintf('nbstatus jobs --target %s --format script --fields jobid,status,exitstatus "%s"', feederName, sprintf('%s', ids));
dctSchedulerMessage(4, '%s: Querying cluster for job state using command:\n\t%s', currFilename, commandToRun);

try
    % We will ignore the status returned from the state command because
    % a non-zero status is returned if the job no longer exists
    % Execute the command on the remote host.
    [~, cmdOut] = remoteConnection.runCommand(commandToRun);
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
% Decide what to do with mirroring based on the cluster's version of job state and whether or not
% the job is currently being mirrored:
% If job is not being mirrored, and job is not finished, resume the mirror
% If job is not being mirrored, and job is finished, do the last mirror
% If the job is being mirrored, and job is finished, do the last mirror.
% Otherwise (if job is not finished, and we are mirroring), do nothing
isBeingMirrored = remoteConnection.isJobUsingConnection(job.ID);
isJobFinished = strcmp(state, 'finished') || strcmp(state, 'failed');
if ~isBeingMirrored && ~isJobFinished
    % resume the mirror
    dctSchedulerMessage(4, '%s: Resuming mirror for job %d.', currFilename, job.ID);
    try
        remoteConnection.resumeMirrorForJob(job);
    catch err
        warning('parallelexamples:GenericNetbatch:FailedToResumeMirrorForJob', ...
            'Failed to resume mirror for job %d.  Your local job files may not be up-to-date.\nReason: %s', ...
            err.getReport);
    end
elseif isJobFinished
    dctSchedulerMessage(4, '%s: Doing last mirror for job %d.', currFilename, job.ID);
    try
        remoteConnection.doLastMirrorForJob(job);
        % Store the fact that we have done the last mirror so we can shortcut in the future
        data.HasDoneLastMirror = true;
        cluster.setJobClusterData(job, data);
    catch err
        warning('parallelexamples:GenericNetbatch:FailedToDoFinalMirrorForJob', ...
            'Failed to do last mirror for job %d.  Your local job files may not be up-to-date.\nReason: %s', ...
            err.getReport);
    end
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
