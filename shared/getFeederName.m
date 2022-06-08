function feederName = getFeederName
%GETFEEDERNAME Gets the feeder name a Netbatch cluster

% Copyright 2022 The MathWorks, Inc.

if ispc
    var = 'USERNAME';
else
    % Linux or macOS
    var = 'USER';
end
user = getenv(var);
if isempty(user)
    error('Failed to get username.')
end
[FAILED, hn] = system('hostname');
if FAILED
    error('Failed to get hostname.\n%s', hn)
end

feederName = [user '_' strtrim(hn) '_matlab'];

end
