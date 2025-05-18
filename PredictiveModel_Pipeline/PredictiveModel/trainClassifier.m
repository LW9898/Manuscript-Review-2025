function [trainedClassifier, validationAccuracy] = trainClassifier(trainingData)
% TRAINCLASSIFIER Train machine learning model and evaluate performance
%   [trainedClassifier, validationAccuracy] = trainClassifier(trainingData)
%   returns a trained classifier and its validation accuracy. This code
%   recreates the classification model trained in Classification Learner app. 
%
%   Input:
%       trainingData - Table containing predictor and response variables
%   
%   Output:
%       trainedClassifier - Struct containing trained model with prediction function
%       validationAccuracy - Double representing cross-validation accuracy percentage
%
%   Usage Examples:
%       % Retrain model with original data T
%       [trainedClassifier, validationAccuracy] = trainClassifier(T)
%
%       % Predict new data T2
%       yfit = trainedClassifier.predictFcn(T2)

% Extract predictors and response
% This code processes the data into the right shape for training the
% model.
inputTable = trainingData;
predictorNames = {'hs_1', 'xcorrf_5s_4', 'std_30s_1', 'BM_dura_1', 'duration_1_1', 'duration_1_2', 'dista_1', 'dista_2', 'pbcount_1', 'pbcount_2', 'stwratio_1', 'stwratio_2'};
predictors = inputTable(:, predictorNames);
response = inputTable.label;
isCategoricalPredictor = [false, false, false, false, false, false, false, false, false, false, false, false];

% Train a classifier
% This code specifies all the classifier options and trains the classifier.
template = templateTree(...
    'MaxNumSplits', 8909, ...
    'NumVariablesToSample', 'all');
classificationEnsemble = fitcensemble(...
    predictors, ...
    response, ...
    'Method', 'RUSBoost', ...
    'NumLearningCycles', 483, ...
    'Learners', template, ...
    'LearnRate', 0.7782, ...
    'ClassNames', categorical({'1'; '2'; '3'}));

% Create the result struct with predict function
predictorExtractionFcn = @(t) t(:, predictorNames);
ensemblePredictFcn = @(x) predict(classificationEnsemble, x);
trainedClassifier.predictFcn = @(x) ensemblePredictFcn(predictorExtractionFcn(x));

% Add additional fields to the result struct
trainedClassifier.RequiredVariables = {'BM_dura_1', 'dista_1', 'dista_2', 'duration_1_1', 'duration_1_2', 'hs_1', 'pbcount_1', 'pbcount_2', 'std_30s_1', 'stwratio_1', 'stwratio_2', 'xcorrf_5s_4'};
trainedClassifier.ClassificationEnsemble = classificationEnsemble;
trainedClassifier.About = 'This struct is a trained model exported from Classification Learner R2024a.';
trainedClassifier.HowToPredict = sprintf('To make predictions on a new table, T, use: \n  [yfit,scores] = c.predictFcn(T) \nreplacing ''c'' with the name of the variable that is this struct, e.g. ''trainedModel''. \n \nThe table, T, must contain the variables returned by: \n  c.RequiredVariables \nVariable formats (e.g. matrix/vector, datatype) must match the original training data. \nAdditional variables are ignored. \n \nFor more information, see <a href="matlab:helpview(fullfile(docroot, ''stats'', ''stats.map''), ''appclassification_exportmodeltoworkspace'')">How to predict using an exported model</a>.');

% Extract predictors and response
% This code processes the data into the right shape for training the
% model.
inputTable = trainingData;
predictorNames = {'hs_1', 'xcorrf_5s_4', 'std_30s_1', 'BM_dura_1', 'duration_1_1', 'duration_1_2', 'dista_1', 'dista_2', 'pbcount_1', 'pbcount_2', 'stwratio_1', 'stwratio_2'};
predictors = inputTable(:, predictorNames);
response = inputTable.label;
isCategoricalPredictor = [false, false, false, false, false, false, false, false, false, false, false, false];

% Perform cross-validation
partitionedModel = crossval(trainedClassifier.ClassificationEnsemble, 'KFold', 5);

% Compute validation predictions
[validationPredictions, validationScores] = kfoldPredict(partitionedModel);

% Compute validation accuracy
validationAccuracy = 1 - kfoldLoss(partitionedModel, 'LossFun', 'ClassifError');
