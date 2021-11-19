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
c.saveAsProfile('netbatch')
c.saveProfile('Description', 'netbatch')

end
