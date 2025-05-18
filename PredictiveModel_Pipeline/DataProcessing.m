function [data2predict,rowsToDelete,lengnum] = DataProcessing(dataStruct,meanx,stdx)
% DATAPROCESSING Radar signal feature engineering
%   [data2predict, rowsToDelete, lengnum] = DataProcessing(dataStruct, meanx, stdx)
%   processes radar IQ signals to generate normalized features for machine learning
%
%   Inputs:
%       dataStruct - Structure containing radar data components:
%                    .IQ: N×2 matrix of complex IQ signals
%                    .fs: Sampling frequency (Hz)
%       meanx      - Feature-wise means from training set for normalization
%       stdx       - Feature-wise std deviations from training set for normalization
%
%   Outputs:
%       data2predict  - M×P matrix of normalized features (M: valid samples)
%       rowsToDelete  - Logical vector marking invalid samples (noise/artifacts)
%       lengnum       - Signal duration used for feature generation (seconds)
    %% Load data
    data_i=dataStruct.data_i;
    data_q=dataStruct.data_q;
    itrend=sgolayfilt(data_i,3,301);           
    data_i=data_i-itrend;
    qtrend=sgolayfilt(data_q,3,301);            
    data_q=data_q-qtrend;
    
    fs=dataStruct.fs;
    
    lengnum=fix(length(data_q)/fs)-29;
    %% Extract features based on empirical knowledge
    % Extract radar signal high-frequency components 
    FIR_n=200;
    fstart=10;
    a=fir1(FIR_n,2*fstart./fs,'high');
    adddata1=flip(data_i(1:FIR_n/2,:)); % Using Type-I FIR filter
    adddata2=flip(data_i(end-FIR_n/2+1:end,:)); 
    datai_h=filter(a,1,[adddata1;data_i;adddata2]);
    datai_h=datai_h(FIR_n+1:end,:);
    adddata1=flip(data_q(1:FIR_n/2,:)); 
    adddata2=flip(data_q(end-FIR_n/2+1:end,:)); 
    dataq_h=filter(a,1,[adddata1;data_q;adddata2]);
    dataq_h=dataq_h(FIR_n+1:end,:);
    datai_h(1:fs)=flip(datai_h(fs:2*fs-1));
    datai_h(end-fs:end)=flip(datai_h(end-2*fs:end-fs));
    dataq_h(1:fs)=flip(dataq_h(fs:2*fs-1));
    dataq_h(end-fs:end)=flip(dataq_h(end-2*fs:end-fs));

    % Preallocate feature storage array
    std_1s=zeros(lengnum,2);
    zc_1s=zeros(lengnum,2);
    hs=zeros(lengnum,2);
    xcorrf_5s=zeros(lengnum,10);
    period=120;
    std_30s=zeros(lengnum,2);
    pbcount=zeros(lengnum,2);
    stwratio=zeros(lengnum,2);
    sz=[lengnum,1];
    data_i_features=table('Size',sz,'VariableTypes', repmat({'cell'},1,1));
    data_q_features=table('Size',sz,'VariableTypes', repmat({'cell'},1,1));
    
    % Sliding window loop for feature extraction
    indxi=30*fs-1;
    for i=30:lengnum+29
        %1s signal window
        ind_1s=indxi-fs+1:indxi;
        if indxi>length(data_q)
            ind_1s=indxi-fs+1:length(data_q);
        end
        data_1s=[data_i(ind_1s),data_q(ind_1s)];% Find all radar signals in 1s signal window
        data_i_features{i-29,1}={table(data_i(ind_1s))};% Store 1-second window data for subsequent standard time-frequency feature extraction
        data_q_features{i-29,1}={table(data_q(ind_1s))};
        std_1s(i-29,:)=std(data_1s);% Calculate varience of the historical 1s radar signals
        zc_1s(i-29,1)=ZeroCrossingRate(data_1s(:,1),fs);% Caculate zero crossing rate
        zc_1s(i-29,2)=ZeroCrossingRate(data_1s(:,2),fs);
        %5s signal window
        ind_5s=indxi-5*fs+1:indxi;
        data_i_5s=data_i(ind_5s);
        data_q_5s=data_q(ind_5s);% Find all radar signals in 5s signal window
        xcorrf_5s(i-29,1:5)=CorrFeatures(data_i_5s,fs);% Generate autocorrelation features
        xcorrf_5s(i-29,6:10)=CorrFeatures(data_q_5s,fs);
        data_h=[datai_h(ind_5s),dataq_h(ind_5s)];
        hs(i-29,:)=max(data_h,[],1); % Extract higher-amplitude high-frequency components from I/Q signals
        %>=30s (period) signal window
        if i<=period
            indx_period=1:indxi;
        else
            indx_period=max(indxi-period*fs+1,1):indxi;
        end
        data_period=[data_i(indx_period),data_q(indx_period)];
        std_30s(i-29,:)=std(data_period,0,1);
        indxi=indxi+fs;
    end
    
    % Calculate durations after body motions (up to period seconds)
    BM_dura=FindBM(hs,std_30s,period);
    
    % Caculate potential respiratory events
    [duration,~,~]=FindDuration(std_1s,std_30s);
    
    % Detect potential PB episodes with respiratory events detected by low
    % thresholds
    pbcount(:,1)=FindPB(duration(:,3),8,22);
    pbcount(:,2)=FindPB(duration(:,4),8,22);
    
    % Calculate breath-to-apnea ratio in preceding respiratory cycles with 
    % respiratory events detected by low thresholds
    stwratio(:,1)=FindSTW(duration(:,3));
    stwratio(:,2)=FindSTW(duration(:,4));
    %% Extract features based on standard time-frequency analysis 
    % Randomly generate labels for diagnosticFeatures input (standardized interface), but not used subsequently
    label=randi([1,3],lengnum,1);
    
    data_i_features=addvars(data_i_features,label);
    data_q_features=addvars(data_q_features,label);
    
    % Extract features from the I-signal 
    FeatureTable1=diagnosticFeatures(data_i_features);
    % Extract features from the Q-signal (renamed variables to distinguish from I-signal features) 
    FeatureTable2=diagnosticFeatures(data_q_features);
    newVarNames = cellfun(@(x) [x(1:3),'2',x(5:end)],FeatureTable2.Properties.VariableNames,'UniformOutput',false);
    FeatureTable2.Properties.VariableNames=newVarNames;
    %% Remove invalid samples
    
    % Find samples where post-movement interval is less than 10s from movement signal
    column1=find(BM_dura(:,1)<10); 
    column2=find(BM_dura(:,2)<10);
    rowsToDelete=union(column1,column2); % 位置的并集
    
    % Expand index regions where adjacent movement intervals are less than 60s
    if ~isempty(rowsToDelete)
        sortedRows = sort(rowsToDelete(:));
        mergedIntervals = [];
        start = sortedRows(1);
        endIdx = start;
        
        for i = 2:length(sortedRows)
            if sortedRows(i) - endIdx <= 60
                endIdx = sortedRows(i); % Extend interval endpoints
            else
                mergedIntervals = [mergedIntervals; [start, endIdx]]; % 保存当前区间
                start = sortedRows(i); % Reset starting points
                endIdx = start;
            end
        end
        mergedIntervals = [mergedIntervals; [start, endIdx]]; % 添加最后一个区间
        
        % Generate all row indices to be deleted
        extendedRows = [];
        for k = 1:size(mergedIntervals, 1)
            extendedRows = [extendedRows; (mergedIntervals(k,1):mergedIntervals(k,2))'];
        end
        rowsToDelete = unique(extendedRows); % Remove duplicates
    end
    
    % Finalize respiratory event detection
    duration_1=zeros(size(duration));
    for i=1:4
        duration_1(:,i)=find_overlapping_events(duration(:,i),rowsToDelete);
    end
    % Find previous event durations and inter-event intervals
    [duration_last,dista]=FindPreviousDuration(duration_1);
    
    % Merge all generated features and remove invalid samples
    Fdata=table(std_1s,zc_1s,hs,xcorrf_5s,std_30s,BM_dura,duration_1,duration_last,dista,pbcount,stwratio);
    FeatureData=[FeatureTable1(:,2:end),FeatureTable2(:,2:end),Fdata];
    FeatureData(rowsToDelete,:)=[];
    
    FeatureData=splitvars(FeatureData);
    
    % Normalization with Feature-wise parameters from training set 
    X=FeatureData{:,:};
    X1=(X-meanx)./stdx;
    data2predict=table();
    data2predict{:,FeatureData.Properties.VariableNames}=X1;

    % Output invalid sample index
    rowsToDelete=rowsToDelete+29;
end

