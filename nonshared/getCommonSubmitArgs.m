function commonSubmitArgs = getCommonSubmitArgs(cluster)
% Get any additional submit arguments for the Netbatch nbjob command
% that are common to both independent and communicating jobs.

% Copyright 2016-2022 The MathWorks, Inc.

commonSubmitArgs = '';
ap = cluster.AdditionalProperties;

% Append any arguments provided by the AdditionalSubmitArgs field of cluster.AdditionalProperties.
extraArgs = validatedPropValue(ap, 'AdditionalSubmitArgs', 'char');
if ~isempty(extraArgs)
    commonSubmitArgs = strtrim(sprintf('%s %s', commonSubmitArgs, extraArgs));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CUSTOMIZATION MAY BE REQUIRED %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% You may wish to support further cluster.AdditionalProperties fields here
% and modify the submission command arguments accordingly.

% Class Reservation
class_reservation = sprintf('--class-reservation cores=%d', cluster.NumThreads);
memPerCpu = validatedPropValue(ap, 'MemPerCpu', 'double');
if ~isempty(memPerCpu) && memPerCpu>0
    class_reservation = sprintf('%s,memory=%d', class_reservation, memPerCpu);
end
commonSubmitArgs = strtrim(sprintf('%s %s', commonSubmitArgs, class_reservation));
