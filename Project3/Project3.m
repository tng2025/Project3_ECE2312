[s1,fs]= audioread('BrownFox.wav');   

% Plots the orginial signal 
plotSpec(s1, fs, "Original Signal [FS1]");

% Question 3 
targetFreq = 8000; 
samplingFreq = 44100/2; 
stopband_st = targetFreq/samplingFreq;
passband_end = (targetFreq - 2000)/samplingFreq;

F = [0 passband_end stopband_st 1];
A = [1 1 0 0];
lpf = firls(256, F, A);

filtered = filter(lpf, A, s1); % low pass
plotSpec(filtered, fs, 'Orignal Signal after LPF');

down = resample(filtered, 1, 2); % down sample, fs2
plotSpec(down, samplingFreq, 'FS2');

cutoff_freq = 1500;

% Question 4
high = highpass(down, cutoff_freq, 44100/2);
downHigh = resample(high, 1, 2);
plotSpec(downHigh, 44100/4, 'xH');

low = lowpass(down, cutoff_freq, 44100/2);
downLow = resample(low, 1, 2);
plotSpec(downLow, 44100/4, 'xL');
    
% Question 5
% xHH
xHH = highpass(downHigh, cutoff_freq, 44100/4);
xHHDown = resample(xHH, 1, 2);
plotSpec(xHHDown, 44100/8, 'xHH');

% xHL
xHL = lowpass(downHigh, cutoff_freq, 44100/4);
xHLDown = resample(xHL, 1, 2);
plotSpec(xHLDown, 44100/8, 'xHL');
    
% xLH
xLH = highpass(downLow, cutoff_freq, 44100)/4;
xLHDown = resample(xLH, 1, 2);
plotSpec(xLHDown, 44100/8, 'xLH');
    
% xLL
xLL = lowpass(downLow, cutoff_freq, 44100/4);
xLLDown = resample(xLL, 1, 2);
plotSpec(xLLDown, 44100/8, 'xLL');
    
% Question 6: Reassemble
% xHH
xHHUp = resample(xHHDown, 2, 1);
xHHhigh = highpass(xHHUp, cutoff_freq, 44100/4);
     
% xHL
xHLUp = resample(xHLDown, 2, 1);
xHLLow = lowpass(xHLUp, cutoff_freq, 44100/4);

% add for FS3 HIGH
FS3high = xHLLow + xHHhigh;
    
% xLH
xLHUP = resample(xLHDown, 2, 1);
xLHhigh = highpass(xLHUP, cutoff_freq, 44100/4);
  
% xLL
xLLUP = resample(xLLDown, 2, 1);
xLLLOW = lowpass(xLLUP, cutoff_freq, 44100/4);
    
% add for FS3 LOW
FS3low = xLHhigh + xLLLOW;
UPFS3high = resample(FS3high, 2, 1);
FS2high = highpass(UPFS3high, cutoff_freq, 44100/2);
UPFS3low = resample(FS3low, 2, 1);
FS2low = lowpass(UPFS3low, cutoff_freq, 44100/2);
    
% add FS2
FS2 = FS2high + FS2low;
UPFS2 = resample(FS2, 2, 1);
FS1 = lowpass(UPFS2, targetFreq, 44100);

% PLOT FS1
fs1 = FS1(:,1);
samplingFreq = 44100;
plotSpec(fs1, samplingFreq, 'Reassembled Original Signal vs Time' );

% Play reassemble audio
sound(fs1, samplingFreq);
    
% Save to WAV file
audiowrite('Ng_synthesized.wav', fs1, samplingFreq);
clear fs1 samplingFreq;
audioinfo('Ng_synthesized.wav');
[fs1,samplingFreq] = audioread('Ng_synthesized.wav');
