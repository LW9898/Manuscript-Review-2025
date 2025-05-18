clear all;close all;

FeatureWeight=[];
CountTime=5;% Number of repetitions for feature weight calculation

for ct=1:CountTime
    %% Load data
    folderPath='.\PreparedSlides';   % Set storage path for extracted feature dataset  
    filePattern=fullfile(folderPath,'*.mat');  
    fileList=dir(filePattern);  
    numFiles=numel(fileList);  
    
    % Read all features and merge into a single table variable
    FeatureData=[];
    for j=1:numFiles
        filePath=fullfile(folderPath,fileList(j).name);
    
        matData=load(filePath);
        FeatureData=[FeatureData;matData.FeatureData];
    end

    Fdata_1=splitvars(FeatureData);% Ensure each column represents one variable
    
    labelName="label";
    DataTable=convertvars(Fdata_1,labelName,"categorical");% Convert label variable to categorical type
    columnNames=DataTable.Properties.VariableNames;
    DataLabel=DataTable.label;
    %% Train-test split
    cv_split=cvpartition(DataTable.label,'HoldOut',0.3,'Stratify',true);
    tblTrain=DataTable(cv_split.training,:);
    tblTest=DataTable(cv_split.test,:);
    %% Feature selection: Cross-correlation
    %normalization
    XTrain=tblTrain{:,1:end-1};
    XTrain1mean=mean(XTrain);
    XTrain1std=std(XTrain);
    XTrain1=(XTrain-XTrain1mean)./XTrain1std;
    featureDataNormalized=table();
    featureDataNormalized{:,tblTrain.Properties.VariableNames(1:end-1)}=XTrain1;
    featureDataNormalized=[featureDataNormalized,tblTrain(:,end)];
    
    if ct==1 % If first-time feature filtering, compute feature cross-correlation
        rho=corr(featureDataNormalized{:,1:end-1});
        rhoB=zeros(size(rho));
        rhoB(abs(rho)>0.8)=1; % Set to 1 if cross-correlation > 0.8, otherwise 0

        DeleteIndx=[];
        i=1;
        while i <= size(rhoB,2)
            if rhoB(i,i)==0 % Remove all items with self-correlation ≠ 1 (may be NaN)
                DeleteIndx=[DeleteIndx;i];
            elseif i < size(rhoB,2)-1 && rhoB(i,i+1)==1 && rhoB(i+1,i+2)==1 % Detect and remove redundant consecutive correlated features
                if rhoB(i,i+2)==0
                    % Keep middle features, remove edge features
                    DeleteIndx=[DeleteIndx;i];
                    DeleteIndx=[DeleteIndx;i+2];
                    i=i+2;  % Jump to next feature
                else
                    DeleteIndx=[DeleteIndx;i+1];
                end
            elseif i < size(rhoB,2) && rhoB(i,i+1)==1
                DeleteIndx=[DeleteIndx;i+1];
            end
            i=i+1;
        end
    end
    
    featureReduced=featureDataNormalized;
    featureReduced(:,DeleteIndx)=[];
    %% Feature selection: Generate feature weights
    mdl=fscnca(featureReduced{:,1:end-1},featureReduced{:,end},'Solver','lbfgs');
    
    wt=mdl.FeatureWeights;
    FeatureWeight=[FeatureWeight,wt];
    % Save feature weight matrix to 'FeatureWeight.xlsx'
end