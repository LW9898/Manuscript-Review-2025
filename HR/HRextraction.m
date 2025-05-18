% Example signal: A segment of newborn participant data (anonymized) 
% Note: Database I/O and processing steps are omitted for privacy protection.
% All personally identifiable information has been removed.

clear all;close all;
%% Load data
data=load('Example_HR.mat');

t=data.t; % radar timestamps
data_i=data.data_i; % radar I channel signal
data_q=data.data_q; % radar Q channel signal
fs=data.fs; % sampling rate of radar signals
tr=data.tr; % ref timestamps (sampling rate about 1 Hz)
ref_HR=data.ref_HR; % ref HR data

fc=24e9; % radar frequency
lambda=3e8/fc; % wavelength
%% Calibration
Data4DC=[data_i,data_q];
result=circleFitting(Data4DC);% return circle center and radius
Si=(data_i-result(1))./result(3);
Sq=(data_q-result(2))./result(3);
%% Demodulation
NL=length(Si);
phi=zeros(NL,1);
for i=2:NL
    for k=2:i
        phi(i)=phi(i)+(Si(k-1)*Sq(k)-Si(k)*Sq(k-1));
    end
end
Disp=phi.*lambda./(4*pi);

% detrend
xtrend=sgolayfilt(Disp,3,501);
Disp1=Disp-xtrend;
%% HR Calculation
% Bandpass filter
FIR_n=200;
fstart=1;
fend=5;
b=fir1(FIR_n,2*[fstart,fend]./fs,'bandpass');
Disp3=filter(b,1,Disp1);

% Phase adjustment for standardization
upcount=length(find(Disp3>mean(Disp3)));
downcount=length(find(Disp3<mean(Disp3)));
if upcount>downcount
    Disp3=-1*Disp3;
end

% Find peaks
[pks1,locs1]=findpeaks(Disp3,fs,'MinPeakProminence',2e-5);   
interv1=diff(locs1);
tRRV1=locs1(2:end);
RRV1=60./interv1;
RRV1=movmean(RRV1,[10-1,0]);

% Resample
trr=t(1)+seconds(tRRV1);
t1=(tr(20):seconds(1):tr(end))';% Generate a sequence of datetime values for each second from signal stabilization to end
HR_r=zeros(length(t1),1);
HR_ref=zeros(length(t1),1);

for i=1:length(t1)
    % Find time indices in radar signal and reference signal corresponding to current second
    idx1=trr>=t1(i) & trr<t1(i)+seconds(1);
    idx2=tr>=t1(i) & tr<t1(i)+seconds(1);
    
    % For radar HR: if current second has valid index, take mean RRV; else use nearest RRV
    if any(idx1)
        HR_r(i)=mean(RRV1(idx1));
    else
        [~, nearestIdx]=min(abs(trr-t1(i)));
        HR_r(i)=RRV1(nearestIdx);
    end

    % For ref HR: if current second has valid index, take mean HR; else use nearest HR
    if any(idx2)
        HR_ref(i)=mean(ref_HR(idx2));
    else
        [~, nearestIdx]=min(abs(tr-t1(i)));
        HR_ref(i)=ref_HR(nearestIdx);
    end
end

figure;
plot(t1,HR_r,'-o');
hold on
plot(t1,HR_ref,'-^');
legend('Radar','Ref');
xlim([t1(1),t1(end)]);
ylim([0,200]);
ylabel('Resampled HR (bpm)');
xlabel('Time(HH:MM:SS)');
%% HRV calculation
RR_differences=diff(60*1000./HR_r);

SDNN=std(RR_differences) % SDNN: Standard Deviation of all NN intervals

RMSSD=sqrt(mean(RR_differences.^2)) % RMSSD: Root Mean Square of Successive RR interval differences

% PNN50: Percentage of adjacent normal RR intervals with >50ms difference
pNN50_count=sum(abs(RR_differences)>50);
total_intervals=length(RR_differences); 
pNN50=(pNN50_count/total_intervals)*100