function nb = createNbCluster(qslot,queue)

profile = 'netbatch';    

% Delete old profile if it exists
try %#ok<TRYNC>
    parallel.internal.ui.MatlabProfileManager.removeProfile(profile)
end
    
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
nb.NumThreads = 1;
nb.NumWorkers = 192;
nb.OperatingSystem = 'unix';
% MW: Need to fix
nb.PluginScriptsLocation = pwd;

%% AdditionalProperties
nb.AdditionalProperties.MachineClass = 'SLES12';
nb.AdditionalProperties.MemPerCpu = '';
nb.AdditionalProperties.ProcsPerNode = 1;
nb.AdditionalProperties.RemoteQslot = qslot;
nb.AdditionalProperties.RemoteQueue = queue;
nb.AdditionalProperties.UseSmpd = false;

%% Save profile
nb.saveAsProfile(profile)
nb.saveProfile('Description', profile)

end
