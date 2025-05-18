% Example signal: A 25-minute anonymized neonatal physiological recording
% Note: Database I/O and processing steps are omitted for privacy protection.
% All personally identifiable information has been removed.

clear all;close all;
%% Load data
Data=load('Example_episode.mat'); % Replace with target dataset for analysis

fs=Data.fs; % sampling rate of radar signals (Hz)
t_r_0=Data.t_r_0; % radar timestamps
t_s_0=Data.t_s_0; % ref timestamps (sampling rate about 1 Hz)
data_i=Data.data_i_0; % radar I channel signal
data_q=Data.data_q_0; % radar Q channel signal
spo2_0=Data.spo2_0; % ref SpO2 data

fc=24e9; % radar frequency
lambda=3e8/fc; % wavelength
%% Data preprocess
% % Remove the signal outliers
% data_i=filloutliers(data_i,"linear");
% data_q=filloutliers(data_q,"linear");

% % Normalize radar signal timestamps
totaltime=seconds(datetime(t_r_0(end))-datetime(t_r_0(1)));
t0=1/fs:1/fs:totaltime;
t_r_0=t_r_0(1)+seconds(t0);
t_r=datestr(t_r_0,'yyyy-mm-dd HH:MM:ss'); 
t_r=datetime(t_r);

% % SpO2 data processing
t1=seconds(t_s_0-t_s_0(1));
t2=0:1:totaltime;
% Perform interpolation on non-zero SpO2 data
spo2_00=zeros(size(t2)); 
first_nonzero=find(spo2_0~=0,1,'first');% Find first non-zero index
if ~isempty(first_nonzero) % Process only non-zero segments
    t1_nonzero=t1(first_nonzero:end);
    spo2_nonzero=spo2_0(first_nonzero:end);        
    spo2_00(first_nonzero:end)=interp1(t1_nonzero,spo2_nonzero,t2(first_nonzero:end),'nearest','extrap');
end
% Mark outlier SpO2 values as NaN and perform nearest-neighbor gap filling
spo2_00(spo2_00<50 & spo2_00>100)=nan;
spo2=fillmissing(spo2_00,'nearest');
% Normalize ref signal timestamps
t_s_0=t_s_0(1)+seconds(t2);
t_s=datestr(t_s_0,'yyyy-mm-dd HH:MM:ss');
t_s=datetime(t_s);

% % visualization
t=(1:length(data_q))./fs;
figure;
subplot(2,1,1);
yyaxis left
plot(t,data_i,'Linewidth',2);
ylabel('I Signal (V)');
yyaxis right
plot(t2,spo2,'-o','Linewidth',2);
ylabel('SpO2 (%)');
xlim([min(t0) max(t0)]);
subplot(2,1,2);
yyaxis left
plot(t,data_q,'Linewidth',2);
ylabel('Q Signal (V)');
yyaxis right
plot(t2,spo2,'-o','Linewidth',2);
ylabel('SpO2 (%)');
xlim([min(t0) max(t0)]);
xlabel('Time (second)');
%% Save data for next step processing
filePath=fullfile('DataSlides\','Example_RawData.mat');
save(filePath,'t_r','data_i','data_q','fs','t_s','spo2');

fprintf('Done.\n');