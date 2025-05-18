function xcorrf = CorrFeatures(x,fs)
% CORRFEATURES Calculate multi-domain features from signal autocorrelation
%   xcorrf = CorrFeatures(x, fs) computes temporal and spectral parameters 
%   from autocorrelation analysis of input signal x with sampling rate fs
%
%   Features include:
%       - pknum: Number of temporal autocorrelation peaks
%       - min_distance: Average inter-peak interval (samples) in temporal domain
%       - fmaxloc: Dominant spectral frequency (Hz) in 0.3-3.5Hz band
%       - resp_PAR: Power ratio (0.3-1.5Hz band) to total spectrum
%       - hb_PAR: Power ratio (1.5-3.3Hz band) to total spectrum
%
%   Methodology:
%     1. Temporal peak detection using autocorrelation sequence
%     2. Chirp-Z Transform for enhanced spectral resolution
%     3. Band-specific energy distribution analysis

    % Compute autocorrelation and temporal domain features
    [corr,lags]=xcorr(x);
    
    [pks1,locs1]=findpeaks(corr);
    pknum=length(pks1);
    if pknum==1
        min_distance=0; % Handle single-peak case
    else
        peak_distances=diff(lags(locs1));
        min_distance=mean(peak_distances); % Mean inter-peak distance
    end
    
    % Chirp-Z Transform Configuration
    m=1024*5; % Transform length
    f11=0.3; % Start frequency (Hz)
    f21=3.5; % End frequency (Hz)
    w=exp(-j*2*pi*(f21-f11)/(m*fs));
    a=exp(j*2*pi*f11/fs);
    fn=(0:m-1)'/m;
    fz=(f21-f11)*fn+f11;
    
    % Spectral Analysis
    z=czt(corr,m,w,a)';
    z=abs(z);
    [pks,locs]=findpeaks(z,'MinPeakDistance',0.007); % Peak detection
    if length(pks)<1
        fmaxloc=0;  % No spectral peaks detected
    else
        [sortedPeaks,sortedIndex]=sort(pks,'descend');
        zmax=sortedPeaks(1); % Highest peak magnitude
        locmax=locs(sortedIndex(1)); % Corresponding frequency index
        fmaxloc=fz(locmax); % Convert index to Hz
    end
    
    % Power Distribution Analysis
    zmean=mean(z);
    totalz=sum(z);
    
    % Respiratory band (0.3-1.5Hz) power ratio
    resp_indices=find(fz>0.3 & fz<1.5);
    resp_sum=sum(z(resp_indices));
    resp_PAR=resp_sum/totalz;

    % Heartbeat band (1.5-3.3Hz) power ratio
    hb_indices=find(fz>1.5 & fz<3.3);
    hb_sum=sum(z(hb_indices));
    hb_PAR=hb_sum/totalz;
    
    % Compile feature vector
    xcorrf=[pknum,min_distance,fmaxloc,resp_PAR,hb_PAR];
end