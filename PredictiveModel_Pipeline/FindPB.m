function pbcount = FindPB(duration,minperiod,maxperiod)
% FINDPB Detect periodic breathing (PB) episodes from apnea duration sequence
%   pbcount = FindPB(duration, minperiod, maxperiod) identifies periodic
%   breathing patterns based on inter-apnea intervals in duration vector
%
%   Inputs:
%       duration   - Vector of apnea durations (in samples, Fs=1Hz)
%       minperiod   - Minimum valid PB cycle length (samples)
%       maxperiod   - Maximum valid PB cycle length (samples)
%   Output:
%       pbcount    - PB episode duration vector (>0: PB active, 0: inactive)

    % Significant apnea detection (≥4.9s duration)
    [~,locs]=findpeaks(duration,'MinPeakProminence',4.9);
    
    % Initialize PB tracking variables
    period_count=0;
    prev_index=1;
    pbcount=zeros(size(duration));
    
    % Periodicity analysis
    for i=1:length(locs)
        curr_index=locs(i);
        countdiff=abs(curr_index-prev_index);
        
        % Validate PB cycle duration constraints
        if countdiff>minperiod & countdiff<maxperiod 
            period_count=period_count+1; % Increment valid PB cycles
        else
            period_count=0; % Reset counter for non-PB
        end    
        
        % Mark PB region between consecutive valid peaks
        pbcount(prev_index:curr_index-1)=period_count;
        prev_index=curr_index; % Update reference position  
    end
    pbcount(pbcount<3)=0; % Require ≥3 consecutive PB cycles

end

