function createTaskConfFile(outputFilename, remoteQueue, remoteQslot)
% Create the task configuration file to be loaded to the feeder


dctSchedulerMessage(5, '%s: Creating task configuration file %s at %s', mfilename, outputFilename);

% Open file in binary mode to make it cross-platform.
fid = fopen(outputFilename, 'w');
if fid < 0
    error('parallelexamples:GenericNetbatch:FileError', ...
        'Failed to open file %s for writing', outputFilename);
end

fprintf(fid, 'JobsTask {\n');
fprintf(fid, '  Queue %s {\n', remoteQueue);
fprintf(fid, '    Qslot %s\n', remoteQslot);
fprintf(fid, '  }\n');
fprintf(fid, '  Jobs {\n');
fprintf(fid, '  }\n');
fprintf(fid, '}\n');

% Close the file
fclose(fid);
