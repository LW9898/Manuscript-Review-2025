function zc=ZeroCrossingRate(x,fs)
% ZEROCROSSINGRATE Calculate zero-crossing rate per second of input signal
%   zc = ZeroCrossingRate(x, fs) computes the number of zero-axis crossings
%   per second in signal vector x with sampling rate fs. The calculation
%   excludes DC offset by removing the signal mean prior to processing.
%
%   Inputs:
%       x  - Input signal vector (1×N or N×1)
%       fs - Sampling frequency in Hz
%   Output:
%       zc - Zero-crossing rate (crossings/second)
    
    x=x-mean(x); % Remove DC offset for accurate zero-crossing detection

    zeroCrossingCount=0;
    for i=2:length(x)
        % Detect sign change between consecutive samples
        if (x(i-1)>=0 && x(i)<0) || (x(i-1)<0&&x(i)>=0)
            zeroCrossingCount=zeroCrossingCount+1;
        end
    end
    
    % Compute zero-crossing rate (crossings per second)
    Duration=length(x)/fs;
    zc=zeroCrossingCount/Duration;
end