function [duration_last,dista] = FindPreviousDuration(duration_now)
% FINDPREVIOUSDURATION Track inter-event timing
%   [duration_last, dista] = FindPreviousDuration(duration_now) calculates:
%       - duration_last: Previous event durations
%       - dista: Inter-event intervals for current events
%
%   Input:
%       duration_now - N×4 matrix of event progression markers:
%                       Columns represent respiratory events detected in 2
%                       channels with 2 thresholds
%                       Non-zero values indicate ongoing events
%   Outputs:
%       duration_last - N×4 matrix of preceding event durations
%       dista         - N×4 matrix of time since last event (samples)
    
    % Convert progression markers to binary activation states
    below_thre=duration_now;
    below_thre(below_thre>0)=1;

    % Initialize output matrices
    duration_last=zeros(size(below_thre));
    dista=zeros(size(below_thre));
    
    event_diff=diff([0,0,0,0;below_thre],1);
    for i=1:4
        event_begin=find(event_diff(:,i)==1); % Event initiation points
        event_end=find(event_diff(:,i)<0); % Event termination points
        if length(event_end)<length(event_begin)
            event_end=[event_end;size(event_diff,1)];
        end

        % Calculate inter-event metrics for sequential events
        for j=2:length(event_begin)
            % Time between current event start and previous event end
            dista(event_begin(j):event_end(j),i)=event_begin(j)-event_end(j-1);
            % Duration of preceding event
            duration_last(event_begin(j):event_end(j),i)=event_end(j-1)-event_begin(j-1);
        end
    end

end

