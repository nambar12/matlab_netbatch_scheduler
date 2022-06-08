function jobID = extractJobId(cmdOut)
% Extracts the job ID from the nbjob command output for Netbatch

% Copyright 2010-2019 The MathWorks, Inc.

% The output of nbjob will be:
% Your job has been queued (JobID 3588037261, Class @, Queue iil_normal, Slot /admin)
jobIDCell = regexp(cmdOut, 'JobID ([0-9]+)', 'tokens', 'once');
jobID = jobIDCell{1};
dctSchedulerMessage(0, '%s: Job ID %s was extracted from nbjob output %s.', mfilename, jobID, cmdOut);
