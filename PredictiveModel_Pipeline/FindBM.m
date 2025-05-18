function countout = FindBM(data,threin,period)
% FINDBM2 Calculate body movement intervals with threshold adaptation
%   countout = FindBM2(data, threin, period) computes time-since-last-detection
%   counters for dual-channel body movement monitoring systems
%
%   Inputs:
%       data   - N×2 matrix of sensor measurements (column-wise signals)
%       threin - N×2 adaptive thresholds matrix (channel-specific)
%       period - Maximum tracking period (in samples)
%   Output:
%       countout - N×2 counters since last detection (clipped at period)
    
    % Initialize counters with maximum period value
    countout=period*ones(size(data));
    for i=1:size(data,1)
        % Find last threshold-exceeding index in channel 1 history
        countmp1=find(data(1:i,1)>threin(1:i,1),1,'last');
        if ~isempty(countmp1)
            countout(i,1)=i-countmp1; % Compute elapsed samples
            countout(i,1)=min(countout(i,1),period); % Apply upper bound
        end

        % Repeat process for second sensor channel
        countmp2=find(data(1:i,2)>threin(1:i,2),1,'last');
        if ~isempty(countmp2)
            countout(i,2)=i-countmp2;
            countout(i,2)=min(countout(i,2),period);
        end
    end

end

