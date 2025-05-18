function STWratio_prev = FindSTW(duration)
% FINDSTW Calculate breath-to-apnea ratio in preceding respiratory cycles
%   STWratio_prev = FindSTW(duration) computes the ratio of normal breathing
%   duration to apnea duration in previous respiratory cycles
%
%   Input:
%       duration - Vector of apnea durations (samples at 1Hz)
%   Output:
%       STWratio_prev - Ratio vector 
    
    % Significant apnea detection (≥4.9s duration)
    [pks,locs]=findpeaks(duration,'MinPeakProminence',4.9);
    
    % Initialize tracking variables
    count=0;
    prev_index=1;  % Previous apnea peak index
    prev_prev_index=1; % Previous-previous apnea peak index 
    STWratio_prev=zeros(size(duration));
    
    if length(locs)<2
        STWratio_prev(:,:)=120; % Default normal breathing ratio
    else
        for i=2:length(locs)
            curr_index=locs(i);
            prev_index=locs(i-1);
            
            % Identify spontaneous breathing window between apnea events
            zero_start=find(duration(prev_prev_index:prev_index)==0,1,"first");
            zero_end=find(duration(prev_prev_index:prev_index)==0,1,"last");
            period_stw=zero_end-zero_start; % Calculate spontaneous breathing duration
            if isempty(period_stw)
                period_stw=0;
            end

            % Compute STW ratio (breathing duration / apnea duration)
            STWratio_prev(prev_index:curr_index-1)=period_stw/pks(i-1);
            prev_prev_index=prev_index;
        end
        % Initialize beginning segment with maximum observed ratio
        STWratio_prev(1:locs(1)-1)=max(STWratio_prev);
    end

end

