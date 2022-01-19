function c = createNbCluster

% Create generic cluster profile
c = parallel.cluster.Generic;
c.IntegrationScriptsLocation = pwd;
c.NumWorkers = 10;
c.OperatingSystem = 'unix';
c.HasSharedFilesystem = true;
jsl = fullfile(getenv('HOME'),'jsl');
if ~exist(jsl)
    mkdir(jsl)
end
c.JobStorageLocation = jsl;
c.AdditionalProperties.UseSmpd = false;
c.AdditionalProperties.RemoteQueue = 'iil_critical';
c.AdditionalProperties.RemoteQslot = '/admin/nambar';
c.AdditionalProperties.MachineClass = 'SLES12';
c.saveAsProfile('netbatch')
c.saveProfile('Description', 'netbatch')

end
