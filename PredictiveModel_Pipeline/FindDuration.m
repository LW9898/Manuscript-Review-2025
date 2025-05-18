function duration_now = FindDuration(std_1s,std_30s)
% FINDDURATION Preliminary respiratory event detection through STD comparison
%   duration_now = FindDuration(std_1s, std_30s) identifies potential respiratory
%   events by comparing 1-second window STD with ≥30-second historical STD
%
%   Inputs:
%       std_1s  - Vector of standard deviations from 1-second sliding windows
%       std_30s - Reference standard deviation from ≥30-second baseline window
%
%   Output:
%       duration_now - N×4 matrix tracking cumulative event durations:
%                      Column 1 and 2: General respiratory event counters of I and Q signals
%                      Column 3 and 4: Potential apnea event counters of I and Q signals

    thre_1=0.8*std_30s; % threshold for general event
    thre_2=0.3*std_30s; % threshold for potential apnea
    below_thre=[std_1s<thre_1,std_1s<thre_2]; % Create boolean matrices for threshold crossings
    duration_now=zeros(size(below_thre));
    
    for i=2:size(below_thre,1)
        dura_last_tmp=duration_now(i-1,:); % Retrieve previous time step's duration state
        inx=find(below_thre(i,:)==1); % Current threshold violations
        dura_now_tmp=zeros(4,1);
        dura_now_tmp(inx)=dura_last_tmp(inx)+1; % Update durations for active events
        duration_now(i,:)=dura_now_tmp; % Apply progressive duration tracking
    end

end

