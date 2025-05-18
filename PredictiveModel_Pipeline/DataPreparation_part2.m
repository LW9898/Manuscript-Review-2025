clear all;close all;
%% load data
predictionHorizon=20; % Predicts desaturation onset time in seconds (adjustable prediction horizon)

folderPath=['.\DataSlides'];  % Folder path for storing all preprocessed data from the first step
filePattern=fullfile(folderPath,'*.mat');  % Find and match all MAT files in the target directory
fileList=dir(filePattern);  
numFiles=numel(fileList);  
%% Perform feature extraction on each data segment
for j=1:numFiles
    % Load corresponding signal segment
    filePath=fullfile(folderPath,fileList(j).name);
    matData=load(filePath);

    data_i=matData.data_i;
    data_q=matData.data_q;
    itrend=sgolayfilt(data_i,3,301);           
    data_i=data_i-itrend;
    qtrend=sgolayfilt(data_q,3,301);            
    data_q=data_q-qtrend; 
                         
    spo2=matData.spo2;
    t_r=matData.t_r;
    t_s=matData.t_s;
    fs=matData.fs;

    %% Generate Label
    [~,label]=Findlabel(spo2,predictionHorizon);

    %% Extract features based on empirical knowledge 
    % Extract radar signal high-frequency components 
    FIR_n=200;
    fstart=10;
    a=fir1(FIR_n,2*fstart./fs,'high'); % Using Type-I FIR filter
    adddata1=flip(data_i(1:FIR_n/2,:)); 
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
    period=120; 
    std_1s=zeros(length(label),2);
    zc_1s=zeros(length(label),2);
    hs=zeros(length(label),2);
    xcorrf_5s=zeros(length(label),10);
    std_30s=zeros(length(label),2);
    pbcount=zeros(length(label),2);
    stwratio=zeros(length(label),2);
    sz=[length(label),1];
    data_i_features=table('Size',sz,'VariableTypes', repmat({'cell'},1,1));
    data_q_features=table('Size',sz,'VariableTypes', repmat({'cell'},1,1));
    
    % Find all radar signals corresponding to the 30-second mark in the reference signal
    indxi_1s=FindDatetime(t_r,t_s(30)); 
    indxi=indxi_1s(end);

    % Sliding window loop for feature extraction, reserve first 30 seconds as preprocessing duration
    for i=30:length(label)+29
        %1s signal window
        ind_1s=indxi-fs+1:indxi;
        data_1s=[data_i(ind_1s),data_q(ind_1s)]; % Find all radar signals in 1s signal window
        data_i_features{i-29,1}={table(data_i(ind_1s))}; % Store 1-second window data for subsequent standard time-frequency feature extraction
        data_q_features{i-29,1}={table(data_q(ind_1s))};
        std_1s(i-29,:)=std(data_1s); % Calculate varience of the historical 1s radar signals
        zc_1s(i-29,1)=ZeroCrossingRate(data_1s(:,1),fs); % Caculate zero crossing rate
        zc_1s(i-29,2)=ZeroCrossingRate(data_1s(:,2),fs);
        %5s signal window
        ind_5s=indxi-5*fs+1:indxi;
        data_i_5s=data_i(ind_5s); 
        data_q_5s=data_q(ind_5s); % Find all radar signals in 5s signal window
        xcorrf_5s(i-29,1:5)=CorrFeatures(data_i_5s,fs); % Generate autocorrelation features
        xcorrf_5s(i-29,6:10)=CorrFeatures(data_q_5s,fs);
        data_h=[datai_h(ind_5s),dataq_h(ind_5s)];
        hs(i-29,:)=max(data_h,[],1); % Extract higher-amplitude high-frequency components from I/Q signals
        %>=30s (period) signal window
        if i<=period
            indx_period=1:indxi;
        else
            indx_period=max(indxi-period*fs+1,1):indxi;
        end
        data_period=[data_i(indx_period),data_q(indx_period)]; % Find all radar signals in signal window lasting period (s) 
        std_30s(i-29,:)=std(data_period,0,1); % Calculate varience of the historical radar signals
        indxi=indxi+fs;
    end
    
    % Calculate durations after body motions (up to period seconds)
    BM_dura=FindBM(hs,std_30s,period);

    % Caculate potential respiratory events
    duration=FindDuration(std_1s,std_30s); 
    
    % Detect potential PB episodes with respiratory events detected by low
    % thresholds
    pbcount(:,1)=FindPB(duration(:,3),8,22); 
    pbcount(:,2)=FindPB(duration(:,4),8,22);
    
    % Calculate breath-to-apnea ratio in preceding respiratory cycles with 
    % respiratory events detected by low thresholds
    stwratio(:,1)=FindSTW(duration(:,3));
    stwratio(:,2)=FindSTW(duration(:,4));
    %% Extract features based on standard time-frequency analysis 
    label=label';

    data_i_features=addvars(data_i_features,label);
    data_q_features=addvars(data_q_features,label);
    
    % Extract features from the I-signal 
    FeatureTable1=diagnosticFeatures(data_i_features);
    % Extract features from the Q-signal (renamed variables to distinguish from I-signal features) 
    FeatureTable2=diagnosticFeatures(data_q_features);
    newVarNames=cellfun(@(x) [x(1:3),'2',x(5:end)],FeatureTable2.Properties.VariableNames,'UniformOutput',false);
    FeatureTable2.Properties.VariableNames=newVarNames;
    %% Remove invalid samples

    % Find samples where label equals zero
    rowsToDelete1=find(label==0);

    % Find samples where post-movement interval is less than 10s from movement signal
    column1=find(BM_dura(:,1)<10); 
    column2=find(BM_dura(:,2)<10);
    rowsToDelete2=union(column1,column2);

    % Expand index regions where adjacent movement intervals are less than 60s
    if ~isempty(rowsToDelete2)
        sortedRows=sort(rowsToDelete2(:));
        mergedIntervals=[];
        start=sortedRows(1);
        endIdx=start;
        
        for i=2:length(sortedRows)
            if sortedRows(i)-endIdx<=60
                endIdx=sortedRows(i); % Extend interval endpoints
            else
                mergedIntervals=[mergedIntervals;[start,endIdx]];
                start=sortedRows(i); % Reset starting points
                endIdx=start;
            end
        end
        mergedIntervals=[mergedIntervals;[start, endIdx]];
        
        % Generate all row indices to be deleted
        extendedRows=[];
        for k=1:size(mergedIntervals,1)
            extendedRows=[extendedRows;(mergedIntervals(k,1):mergedIntervals(k,2))'];
        end
        rowsToDelete2=unique(extendedRows); % Remove duplicates
    end

    % Get the union set
    rowsToDelete=union(rowsToDelete1,rowsToDelete2);
    
    % Finalize respiratory event detection
    duration_1=zeros(size(duration));
    for i=1:4
        duration_1(:,i)=find_overlapping_events(duration(:,i),rowsToDelete2);
    end
    % Find previous event durations and inter-event intervals
    [duration_last,dista]=FindPreviousDuration(duration_1);
    
    % Merge all generated features and remove invalid samples
    Fdata=table(std_1s,zc_1s,hs,xcorrf_5s,std_30s,BM_dura,duration_1,duration_last,dista,pbcount,stwratio,label);
    FeatureData=[FeatureTable1(:,2:end),FeatureTable2(:,2:end),Fdata];
    FeatureData(rowsToDelete,:)=[];
    %% Save data for next step processing
    filePath=fullfile('PreparedSlides\','Example_Features.mat');

    save(filePath,'FeatureData');

    fprintf('File No.%d Done.\n',j);
end
