clear all;close all;
%% Load data
folderPath='.\PreparedSlides'; % Set storage path for extracted feature dataset  
filePattern=fullfile(folderPath,'*.mat');  
fileList=dir(filePattern); 
numFiles=1:numel(fileList); 

% Read all features and merge into a single table variable
FeatureData=[];
for j=1:length(numFiles)  
    filePath=fullfile(folderPath,fileList(j).name);

    matData=load(filePath);
    FeatureData=[FeatureData;matData.FeatureData];
end

Fdata_1=splitvars(FeatureData);  % Ensure each column represents one variable

labelName="label";
DataTable=convertvars(Fdata_1,labelName,"categorical");% Convert label variable to categorical type

columnNames=DataTable.Properties.VariableNames;
DataLabel=DataTable.label;
%% Train-test split
cv_split=cvpartition(DataTable.label,'HoldOut',0.3,'Stratify',true);
tblTrain=DataTable(cv_split.training,:);
tblTest=DataTable(cv_split.test,:);

% Display label distribution in training and test set
disp(['Raw Train:', num2str(height(tblTrain)), ' samples']);
tabulate(tblTrain.label)
disp(newline);
disp(['Raw Test: ', num2str(height(tblTest)), ' samples']);
tabulate(tblTest.label)
disp(newline);

% Normalize training and test data
XTrain=tblTrain{:,1:end-1};
XTrain1mean=mean(XTrain);
XTrain1std=std(XTrain);
XTrain1=(XTrain-XTrain1mean)./XTrain1std;
featureTrain=table();
featureTrain{:,tblTrain.Properties.VariableNames(1:end-1)}=XTrain1;
featureTrain=[featureTrain,tblTrain(:,end)];

XTest=tblTest{:,1:end-1};
XTest1=(XTest-XTrain1mean)./XTrain1std;
featureTest0=table();
featureTest0{:,tblTrain.Properties.VariableNames(1:end-1)}=XTest1;
featureTest0=[featureTest0,tblTest(:,end)];
%% Feature Selection
% Read pre-generated feature weight results from n iterations 
table_collection=datastore('.\FeatureWeight.xlsx','type','spreadsheet');
myTable1=table_collection.readall;
FeatureList=myTable1.Features;
FeatureList=strrep(FeatureList, '''', '');
FeatureList=categorical(FeatureList);
FeatureWeight=myTable1{:,2:end};

% Sort feature weights by mean value in descending order 
mean_weights=mean(FeatureWeight,2);
[~,sorted_idx]=sort(mean_weights,'descend');
sorted_weights=FeatureWeight(sorted_idx,:);
sorted_mean_weights=mean_weights(sorted_idx);% Get sorted feature
sorted_names=FeatureList(sorted_idx); % Get sorted feature names
sorted_names=categorical(sorted_names,sorted_names,'Ordinal',true);

% Select features by threshold based on sorted weights  
var2keep=FeatureList(mean_weights>1.5);% threshold=1.5, can be changed
featureTraining=[featureTrain(:,ismember(featureTrain.Properties.VariableNames,var2keep)),featureTrain(:,end)];
featureTest=[featureTest0(:,ismember(featureTest0.Properties.VariableNames,var2keep)),featureTest0(:,end)];
%% Build model and perform initial testing
% Implement 5-fold validation with Bayesian parameter optimization
% classificationLearner;

% Export as trainClassifier function
addpath('.\PredictiveModel\'); % Set model storage path

% Validate on test set
[trainedClassifier,validationAccuracy]=trainClassifier(featureTraining);
[predictedLabels,scores]=trainedClassifier.predictFcn(featureTest);

actualLabels=featureTest.label;
accuracy=sum(predictedLabels==actualLabels)/length(actualLabels);
fprintf('Validation Accuracy: %.2f%%\n',validationAccuracy*100);
fprintf('Test Accuracy: %.2f%%\n',accuracy*100);