function taskID = extractTaskId(cmdOut)
% Extracts the job ID from the nbjob command output for Netbatch

% Copyright 2010-2019 The MathWorks, Inc.

% The output of nbjob will be:
% Your task has been queued (TaskID: 5, Name: nambar.5)
taskIDCell = regexp(cmdOut, 'TaskID: ([0-9]+)', 'tokens', 'once');
taskID = taskIDCell{1};
dctSchedulerMessage(0, '%s: Task ID %s was extracted from nbtask load output %s.', mfilename, taskID, cmdOut);
