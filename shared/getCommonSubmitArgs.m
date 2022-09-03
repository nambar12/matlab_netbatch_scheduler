function commonSubmitArgs = getCommonSubmitArgs(cluster)
% Get any additional submit arguments for the Netbatch nbjob command
% that are common to both independent and communicating jobs.

% Copyright 2016-2020 The MathWorks, Inc.

commonSubmitArgs = '';

% Append any arguments provided by the AdditionalSubmitArgs field of cluster.AdditionalProperties.
if isprop(cluster.AdditionalProperties, 'AdditionalSubmitArgs')
    extraArgs = cluster.AdditionalProperties.AdditionalSubmitArgs;
    if ~isempty(extraArgs) && ischar(extraArgs)
        commonSubmitArgs = strtrim([commonSubmitArgs, ' ', extraArgs]);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CUSTOMIZATION MAY BE REQUIRED %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% You may wish to support further cluster.AdditionalProperties fields here
% and modify the submission command arguments accordingly.

% Class Reservation
class_reservation = sprintf('--class-reservation cores=%d', cluster.NumThreads);
if isprop(cluster.AdditionalProperties, 'MemPerCpu')
    memPerCpu = cluster.AdditionalProperties.MemPerCpu;
    if ~isempty(memPerCpu) && isnumeric(memPerCpu) && memPerCpu>0
        class_reservation = sprintf('%s,memory=%d', memPerCpu);
    end
end
commonSubmitArgs = strtrim([commonSubmitArgs, ' ' class_reservation]);
