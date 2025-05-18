function [spo2,labelout] = Findlabel(data,spo2_length)
%% FINDLABEL - SpO2 Label Generation Algorithm
% Label determination rules:
% 1) Primary labeling:
%    - Label = SpO2 value at [current sample + spo2_length] seconds
%
% 2) Artifact handling:
%    - Case 1: If SpO2 values are the same, and remain < 90% for ≥10s continuous duration:
%        * Data marked invalid (sensor likely detached during motion)
%        * Both SpO2 and label set to 0
%    - Case 2: If SpO2 < 50% (physiologically implausible):
%        * Same invalidation as Case 1
%
% 3) Variable definitions:
%    - data:        Complete SpO2 time series vector
%    - labelout:    Resulting 4-class labels (dimension-matched to input)
%                   Class 0: Invalid/motion artifact
%                   Class 1: Hypoxic (SpO2<80% & spo2>=50%)
%                   Class 2: Hypoxic (spo2>=80 & SpO2<90%)
%                   Class 3: Normoxic (SpO2≥90%)

    spo2=data(30+spo2_length:end); % reserve first 30 seconds as preprocessing duration
    
    count=0;
    len=length(spo2);
    for i=2:len
        if spo2(i)==spo2(i-1) && spo2(i)<90
            count=count+1;
        else
            if count>=10
                spo2(i-count:i-1)=0;
            end
            count=0;
        end
    end
    
    if count>=10
        spo2(len-count+1:len)=0;
    end
    
    labelout=(spo2<50)*0+(spo2>=90)*3+(spo2<90 & spo2>=80)*2+(spo2<80 & spo2>=50)*1;

end

