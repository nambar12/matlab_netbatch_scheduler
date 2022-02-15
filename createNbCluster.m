function c = createNbCluster

profile = 'netbatch';    

% Delete old profile if it exists
try %#ok<TRYNC>
    parallel.internal.ui.MatlabProfileManager.removeProfile(profile)
end
    
% Create generic cluster profile
c = parallel.cluster.Generic;
c.PluginScriptsLocation = pwd;
c.HasSharedFilesystem = true;
c.NumWorkers = 192;
c.NumThreads = 4;
c.OperatingSystem = 'unix';
jsl = fullfile(getenv('HOME'),'jsl');
if exist(jsl,'dir')~=7
    mkdir(jsl)
end
c.JobStorageLocation = jsl;
c.AdditionalProperties.MachineClass = 'SLES12&&4C';
c.AdditionalProperties.ProcsPerNode = 2;
c.AdditionalProperties.RemoteQslot = '/admin/nambar';
c.AdditionalProperties.RemoteQueue = 'iil_critical';
c.AdditionalProperties.UseSmpd = false;
c.saveAsProfile(profile)
c.saveProfile('Description', profile)

end
