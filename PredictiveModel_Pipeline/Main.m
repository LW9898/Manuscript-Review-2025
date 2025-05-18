clear all;close all;
%% Generate the predition model
% % Run the following file to prepare raw data
edit DataPreparation_part1

% % To extract features.mat from raw data
edit DataPreparation_part2

% % To select features and train models
% Rely on randomly generated n-time feature weights for feature selection, move to the next step
edit FeatureWeightCount 
edit DataPreparation_part3

% %Finally, the model function <trainClassifier.m> will be generated and stored at dirpath
dirpath='.\PredictiveModel\';
%% load data to pretrain model
addpath(dirpath);

% % Load feature data
folderPath='.\PreparedSlides';  % Path to the feature dataset
filePattern=fullfile(folderPath,'*.mat'); 
fileList=dir(filePattern);  % Read the feature dataset
numFiles=numel(fileList);  
FeatureData=[];
for j=1:numFiles  % Merge all feature tables
    filePath=fullfile(folderPath,fileList(j).name);

    matData=load(filePath);
    FeatureData=[FeatureData;matData.FeatureData];
end

Fdata_1=splitvars(FeatureData); % Ensure each column represents one variable
featureAll=convertvars(Fdata_1,"label","categorical");% Convert label variable to categorical type

% % Train-test split
testFraction=0.1; % 10% for testing, 90% for training
cv_split=cvpartition(featureAll.label,'HoldOut',testFraction,'Stratify',true);
tblTrain=featureAll(cv_split.training,:);
tblTest=featureAll(cv_split.test,:);

% % Normalize training data
XTrain=tblTrain{:,1:end-1};
XTrain1mean=mean(XTrain);
XTrain1std=std(XTrain);
XTrain1=(XTrain-XTrain1mean)./XTrain1std;
featureTraining=table();
featureTraining{:,tblTrain.Properties.VariableNames(1:end-1)}=XTrain1;
featureTraining=[featureTraining,tblTrain(:,end)];

% % train the model
[trainedClassifier,validationacc]=trainClassifier(featureTraining);
fprintf('Validation accuracy: %.2f%%\n',validationacc*100);

% % Apply same normalization to test set
XTest=tblTest{:,1:end-1};
XTest1=(XTest-XTrain1mean)./XTrain1std;
featureTest=table();
featureTest{:,tblTest.Properties.VariableNames(1:end-1)}=XTest1;
featureTest=[featureTest,tblTest(:,end)];

% % Model validation
predictedLabels=trainedClassifier.predictFcn(featureTest);
actualLabels=featureTest.label;
acctmp=sum(predictedLabels==actualLabels)/length(actualLabels);
fprintf('Test accuracy: %.2f%%\n',acctmp*100);
%% Continuous Hypoxemia Evaluation
% This section performs continuous temporal hypoxia assessment on neonatal data 
% segments that are excluded from model pretraining.
%
% Implementation Note:
% - The pretrained model should be developed using the full neonatal hypoxia dataset
% - Evaluation is performed on randomly held-out temporal segments to simulate
%   real-world continuous monitoring scenarios
%
% Important Limitations:
% - The complete clinical dataset cannot be shared publicly
% - Consequently, no truly independent held-out test segments are provided
% in this demonstration

% % Load data
preData=load('*.mat'); % Replace with actual test episodes
win=30; % Preprocessing window length (s)
predictionHorizon=20; % early warning time (s)

% % Prediction
tic; 
[DataTable,rowsToDelete,lengnum]=DataProcessing(preData,XTrain1mean,XTrain1std);% Radar signal feature extraction
predictedLabels=trainedClassifier.predictFcn(DataTable);% Newly extracted features serve as model test set
executionTime=toc; % Runtime Performance Monitoring
fprintf('Execution Time: %.2f seconds\n',executionTime);

% % Continuous Accuracy Assessment
% Generate continuous prediction labels
preLabel=ones(win+lengnum-1,1)*-1;
preLabel(1:win-1)=0;
preLabel(rowsToDelete)=0;
preLabel(preLabel~=0)=predictedLabels;
preLabel(preLabel==0)=NaN; % Invalid samples (motion-affected) marked by NAN

% Generate continuous actual labels
spo2=preData.spo2;
[~,actualLabels]=Findlabel(spo2,0);
actualLabels=actualLabels';

% Comparison
prediction=preLabel(win:end-predictionHorizon);
reality=actualLabels(predictionHorizon+1:end);
acctmp=sum(prediction==reality)/length(reality);
fprintf('Test accuracy: %.2f%%\n',acctmp*100);