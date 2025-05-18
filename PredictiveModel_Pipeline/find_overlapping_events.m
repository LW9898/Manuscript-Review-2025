function result = find_overlapping_events(RespiratoryEvent,BM)
% FINDOVERLAPPINGEVENTS Finalize respiratory event detection with exclusion criteria
%   result = find_overlapping_events(RespiratoryEvent, BM) refines potential
%   respiratory events by applying duration and motion exclusion filters
%
%   Inputs:
%       RespiratoryEvent - Preliminary event vector (1: potential event)
%       BM               - Body movement event indices (samples)
%   Output:
%       result - Final event vector with:
%                - Duration ≥5 seconds
%                - Exclusion zones post-body movement (30s after BM events)

    % Create binary mask of potential events
    overlap_mask=(RespiratoryEvent>0);
    
    % Label connected event regions using morphological component analysis
    [labeled_mask,num_events]=bwlabel(overlap_mask);
    
    result=zeros(size(RespiratoryEvent));
    period=30; % Post-motion exclusion duration (seconds)
    C1=union(BM,BM+period); % Generate exclusion zone indices
    
    % Process each candidate event
    for event_id=1:num_events
        % Extract event temporal boundaries
        event_indices=find(labeled_mask==event_id);
        start_idx=event_indices(1);
        end_idx=event_indices(end);
        
        % Calculate event duration (in samples, assuming 1Hz sampling)
        duration=end_idx-start_idx+1;

        % Apply exclusion criteria
        if duration >=5 & ~ismember(start_idx,C1) & ~ismember(end_idx,C1)
            result(start_idx:end_idx)=1:duration;
        end
    end
end