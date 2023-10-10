function varargout = highpass(x,varargin)
%HIGHPASS Filter signals with a highpass filter
%   Y = HIGHPASS(X,Wpass) filters input X with a highpass filter that has a
%   passband frequency Wpass given in normalized units of
%   pi*radians/sample. Wpass must be a value in the (0,1) interval. X can
%   be a vector or a matrix containing double or single precision data.
%   When X is a matrix, each column is filtered independently.
%
%   HIGHPASS performs zero phase filtering on input X using a highpass
%   filter with a stopband attenuation of 60 dB. The highpass filter
%   attenuates frequencies below the specified passband frequency. HIGHPASS
%   compensates for the delay introduced by the filter, and returns output
%   Y having the same dimensions as X.
%
%   Y = HIGHPASS(X,Fpass,Fs) specifies Fs as a positive numeric scalar
%   corresponding to the sample rate of X in units of hertz. Fpass is the
%   passband frequency of the filter in units of hertz.
%
%   YT = HIGHPASS(XT,Fpass) filters the data in timetable XT with a
%   highpass filter that has a passband frequency of Fpass hertz, and
%   returns a timetable YT of the same size as XT. XT must contain numeric
%   double or single precision data. The row times must be durations in
%   seconds with increasing, finite, and uniformly spaced values. All
%   variables in the timetable and the columns inside each variable are
%   filtered independently.
%
%   HIGHPASS(...,'Steepness',S) specifies the transition band steepness
%   factor, S, as a scalar with a value in the [0.5, 1) interval. As S
%   increases, the filter response increasingly approaches the ideal
%   highpass response, but the resulting filter length and the
%   computational cost of the filtering operation also increase. When not
%   specified, Steepness defaults to 0.85. See the documentation to learn
%   more about the filter design used in this function.
%
%   HIGHPASS(...,'StopbandAttenuation',A) specifies stopband attenuation,
%   A, of the filter as a positive scalar in dB. When not specified,
%   StopbandAttenuation defaults to 60 dB.
%
%   HIGHPASS(...,'ImpulseResponse',R) specifies the type of impulse
%   response of the filter, R, as 'auto', 'fir', or 'iir'. If R is set to
%   'fir', LOWPASSFILT designs a minimum-order FIR filter. In this case,
%   the input signal must be more than twice as long as the filter required
%   to meet the specifications. If R is set to 'iir', HIGHPASS designs a
%   IIR filter and uses the FILTFILT function to perform zero-phase
%   filtering. If R is set to 'auto', HIGHPASS designs a minimum-order FIR
%   filter if the input signal is long enough, and a IIR filter otherwise.
%   When not specified ImpulseResponse defaults to 'auto'.
%
%   [Y,D] = HIGHPASS(...) returns the digital filter, D, used to filter the
%   signal. Call fvtool(D) to visualize the filter response. Call
%   filter(D,X) to filter data.
%
%   HIGHPASS(...) with no output arguments plots the original and filtered
%   signals in time and frequency domains.
%
%   % EXAMPLE 1:
%      % Create a signal sampled at 1 kHz. The signal contains two tones,
%      % at 50 and 250 Hz, and additive noise. Highpass filter the signal
%      % to remove the 50 Hz tone.
%      Fs = 1e3;
%      t = (0:1000)'/Fs;
%      x = sin(2*pi*[50 250].*t);
%      x = sum(x,2) + 0.001*randn(size(t));
%      highpass(x,150,Fs)
%
%   % EXAMPLE 2:
%      % Filter white noise with a highpass filter with a passband frequency
%      % of 0.3*pi rad/sample.
%      x = randn(1000,1);
%      highpass(x,0.3)
%
%   % EXAMPLE 3:
%      % Filter white noise sampled at 1 kHz with a highpass filter with a
%      % passband frequency of 300 Hz. Use different steepness values.
%      % Plot the spectra of the filtered signals as well as the responses
%      % of the resulting filters. 
%      Fs = 1000;
%      x = randn(2000,1);
%      [y1, D1] = highpass(x,300,Fs,'Steepness',0.5);
%      [y2, D2] = highpass(x,300,Fs,'Steepness',0.8);
%      [y3, D3] = highpass(x,300,Fs,'Steepness',0.95);
%      pspectrum([y1 y2 y3], Fs)
%      legend('Steepness = 0.5','Steepness = 0.8','Steepness = 0.95')
%      fvt = fvtool(D1,D2,D3);
%      legend(fvt,'Steepness = 0.5','Steepness = 0.8','Steepness = 0.95')
%
%   See also LOWPASS, BANDPASS, BANDSTOP, FILTER, DESIGNFILT, DIGITALFILTER

%   Copyright 2017 MathWorks, Inc.

narginchk(1,9);
nargoutchk(0,2);

opts = signal.internal.filteringfcns.parseAndValidateInputs(x,'highpass',varargin);

% Design filter
opts = designFilter(opts);
if opts.IsSinglePrecision
    opts.FilterObject = single(opts.FilterObject);
end

% Filter the data
y = signal.internal.filteringfcns.filterData(x,opts);

if nargout > 0
    varargout{1} = y;
    if nargout > 1
        varargout{2} = opts.FilterObject;
    end
else
    % Plot input and output data
    signal.internal.filteringfcns.conveniencePlot(x,y,opts);
end

%--------------------------------------------------------------------------
function opts = designFilter(opts)

opts.IsFIR = true;
Fs = opts.Fs;
Wpass = opts.Wpass;
WpassNormalized = opts.WpassNormalized;
Apass = opts.PassbandRipple;
Astop = opts.StopbandAttenuation;

% All stop filter if Wpass is >= 1
if WpassNormalized >= 1
    d = dfilt.dffir(0);
    opts.FilterObject = digitalFilter(d);
    warning(message('signal:internal:filteringfcns:ForcedAllstopDesign'));
    return;
end

% All pass filter if signal length is <=3
if opts.SignalLength <= 3
    d = dfilt.dffir(1);
    opts.FilterObject = digitalFilter(d);
    warning(message('signal:internal:filteringfcns:AllPassBecauseSignalIsTooShort',num2str(3)));
    return;
end

% Compute Tw and Wstop
Tw = opts.TwPercentage * WpassNormalized;
WstopNormalized = WpassNormalized - Tw;
Wstop = WstopNormalized * (Fs/2);

opts.Wstop = Wstop;
opts.WstopNormalized = WstopNormalized;

% Try to design an FIR filter, if order too large for input signal length,
% then try an IIR filter.

% Calculate the required min FIR order from the parameters
NreqFir = kaiserord([Wstop Wpass], [0 1], [opts.StopbandAttenuationLinear opts.PassbandRippleLinear], Fs);

impRespType = signal.internal.filteringfcns.selectImpulseResponse(NreqFir, opts);    

if strcmp(impRespType,'iir')
    % IIR design
    
    opts.IsFIR = false;
    
    % Get the min order of an elliptical IIR filter that will meet the
    % specs and see if signal length is > 3*order otherwise, truncate order
    N = getIIRMinOrder(WpassNormalized,WstopNormalized,Apass,Astop);
    
    if opts.SignalLength <= 3*N
        N = max(2,floor(opts.SignalLength/3));
        
        if N > 1 && 3*N == opts.SignalLength
            N = N-1;
        end
        
        params = {'highpassiir', 'FilterOrder', N,...
            'PassbandFrequency', Wpass, 'StopbandAttenuation', Astop,...
            'PassbandRipple', Apass,'DesignMethod', 'ellip'};
        
        warning(message('signal:internal:filteringfcns:SignalLengthForIIR'));
    else
        params = {'highpassiir', 'StopbandFrequency', Wstop,...
            'PassbandFrequency', Wpass,'StopbandAttenuation', Astop,...
            'PassbandRipple', Apass,'DesignMethod', 'ellip'};
    end
else
    % FIR design
    params = {'highpassfir', 'StopbandFrequency', Wstop,...
        'PassbandFrequency', Wpass,'StopbandAttenuation', Astop,...
        'PassbandRipple', Apass,'DesignMethod', 'kaiserwin',...
        'MinOrder','even'};
end

if ~opts.IsNormalizedFreq
    params = [params {'SampleRate',Fs}];
end
opts.FilterObject = designfilt(params{:});

%--------------------------------------------------------------------------
function N = getIIRMinOrder(WpassNormalized,WstopNormalized,Apass, Astop)
% Compute analog frequencies
%   WpassNormalized, WstopNormalized are passband and stopband normalized
%   frequencies Apass, and Astop are ripple and attenuation in linear units

% Analog frequencies
aWpass = cot(pi*WpassNormalized/2);
aWstop = cot(pi*WstopNormalized/2);
[N, ~] = signal.internal.filteringfcns.getMinIIREllipOrder(aWpass,aWstop,Apass,Astop);

