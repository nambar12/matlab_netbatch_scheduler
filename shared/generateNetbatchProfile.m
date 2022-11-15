function nb = generateNetbatchProfile(queue,qslot)
%GENERATENETBATCHPROFILE Create Netbatch profile
% NB = GENERATENETBATCHPROFILE(QUEUE,QSLOT)
%
% Copyright 2022 The Mathworks, Inc.

if nargin~=2
   error('Must provide RemoteQueue and RemoteQslot.')
end

profile = 'netbatch';

% Create generic cluster profile
nb = parallel.cluster.Generic;

rootd = fileparts(prefdir);
release = ['R' version('-release')];
jsl = fullfile(rootd,'3p_cluster_jobs',release);

if exist(jsl,'dir')==false
    [status,err,eid] = mkdir(jsl);
    if status==false
        error(eid,'Can''t make directory %s: %s',jsl,err)
    end
end

nb.HasSharedFilesystem = true;
nb.JobStorageLocation = jsl;
nb.NumWorkers = 10000;
nb.OperatingSystem = 'unix';
nb.PluginScriptsLocation = fileparts(mfilename("fullpath"));

%% AdditionalProperties
nb.AdditionalProperties.MachineClass = 'SLES12';
nb.AdditionalProperties.MemPerCpu = 0;
nb.AdditionalProperties.RemoteQslot = qslot;
nb.AdditionalProperties.RemoteQueue = queue;

%% Save profile
wasdefault = iDeleteOldProfile(profile);
nb.saveAsProfile(profile)
nb.saveProfile('Description', profile)
if wasdefault==true
    dp_fh = iGetClusterProfileInfo;
    % Was previously the default profile, so set it back to the default
    dp_fh(profile);
end

end


function tf = iDeleteOldProfile(profile)

tf = false;

% Delete the profile (if it exists)
% In order to delete the profile, check first if it's an existing profile.  If
% so, check if it's the default profile.  If so, set the default profile to
% "local" (otherwise, MATLAB will throw the following warning)
%
%  Warning: The value of DefaultProfile is 'name-of-profile-we-want-to-delete' which is not the name of an existing profile.  Setting the DefaultProfile to 'local' at the user level.  Valid profile names are:
%  	  'local' 'profile1' 'profile2' ...
%
% This way, we bypass the warning message.  Then remove the old incarnation
% of the profile (that we're going to eventually create.)

[dp_fh, cp] = iGetClusterProfileInfo;

if any(strcmp(profile,cp))
    % The profile exists

    % Check if it's the default profile.
    tf = strcmp(profile,feval(dp_fh));

    % Disable warning
    state = warning('off', 'parallel:settings:CollapsedDefaultProfileNoLongerExists');

    % Delete the profile
    parallel.internal.ui.MatlabProfileManager.removeProfile(profile)

    % Reset warning
    warning(state)
end


end


function [dp_fh, cp] = iGetClusterProfileInfo(~)

if verLessThan('matlab','9.13')
    % R2022a and older
    % Handle to function returning list of cluster profiles
    cp = parallel.clusterProfiles;
    % Handle to function returning default cluster profile
    dp_fh = @parallel.defaultClusterProfile;
else
    % R2022b and newer
    % Handle to function returning list of cluster profiles
    cp = parallel.listProfiles;
    % Handle to function returning default cluster profile
    dp_fh = @parallel.defaultProfile;
end

end
