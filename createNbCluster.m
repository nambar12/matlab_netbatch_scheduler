function c = createNbCluster


% Create generic cluster profile
c = parallel.cluster.Generic;
c.IntegrationScriptsLocation = pwd;
c.NumWorkers = 10;
c.OperatingSystem = 'unix';
c.HasSharedFilesystem = true;
jsl = fullfile(getenv('HOME'),'jsl');
mkdir(jsl)
c.JobStorageLocation = jsl;
c.AdditionalProperties.UseSmpd = false;
c.saveAsProfile('netbatch')
c.saveProfile('Description', 'netbatch')



end
