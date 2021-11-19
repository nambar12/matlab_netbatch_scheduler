function OK = cancelTaskFcn(cluster, task)
%CANCELTASKFCN Cancels a task on Netbatch
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you cancel a task.

% Copyright 2020 The MathWorks, Inc.

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
data = cluster.getJobClusterData(task.Parent);
if isempty(data)
    % This indicates that the parent job has not been submitted, so return true
    dctSchedulerMessage(1, '%s: Job cluster data was empty for the parent job with ID %d.', currFilename, task.Parent.ID);
    OK = true;
    return
end
% We can't cancel a single task of a communicating job on the scheduler
% without cancelling the entire job, so warn and return in this case
if ~strcmpi(task.Parent.Type, 'independent')
    OK = false;
    warning('parallelexamples:GenericNetbatch:FailedToCancelTask', ...
        'Unable to cancel a single task of a communicating job. If you want to cancel the entire job, use the cancel function on the job object instead.');
    return
end

% Get the cluster to delete the task
schedulerID = task.SchedulerID;
erroredTaskAndCauseString = '';
%% RSN: TODO: Extract "target" name.  Don't hardcode 'matlab'.
commandToRun = sprintf('nbjob remove --target matlab %d', jobID);
dctSchedulerMessage(4, '%s: Canceling task on cluster using command:\n\t%s.', currFilename, commandToRun);
try
    % Make the shelled out call to run the command.
    [cmdFailed, cmdOut] = runSchedulerCommand(commandToRun);
catch err
    cmdFailed = true;
    cmdOut = err.message;
end
if cmdFailed
    % Record if the task errored when being cancelled, either through a bad
    % exit code or if an error was thrown. We'll report this as a warning.
    erroredTaskAndCauseString = sprintf('Job ID: %s\tReason: %s', schedulerID, strtrim(cmdOut));
    dctSchedulerMessage(1, '%s: Failed to cancel task %s on cluster.  Reason:\n\t%s', currFilename, schedulerID, cmdOut);
end

% Warn if task cancellation failed.
OK = isempty(erroredTaskAndCauseString);
if ~OK
    warning('parallelexamples:GenericNetbatch:FailedToCancelTask', ...
        'Failed to cancel the task on the cluster:\n  %s\n', ...
        erroredTaskAndCauseString);
end
