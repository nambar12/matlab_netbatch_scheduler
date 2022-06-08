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
