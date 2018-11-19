clear all
close all


%% Initialization
% initializes simulation parameters and generates the structure prmQAMTxRx. 
prmQAMTxRx = system_init; % QAM system parameters 



coder.extrinsic('createScopes','runScopes','releaseScopes')

    QAMTx = QAMTransmitter(...
        'UpsamplingFactor', prmQAMTxRx.Upsampling, ...
        'ModulationOrder', prmQAMTxRx.M, ...
        'FrameSize', prmQAMTxRx.FrameSize,...
        'TransmitterFilterCoefficients',prmQAMTxRx.TransmitterFilterCoefficients);

    QAMChan = Channel('PhaseOffset', prmQAMTxRx.PhaseOffset, ...
        'SignalPower', 1/prmQAMTxRx.Upsampling, ...
        'UpsamplingFactor', prmQAMTxRx.Upsampling, ...
        'EbNo', prmQAMTxRx.EbNo, ...
        'BitsPerSymbol', prmQAMTxRx.M, ...
        'FrequencyOffset', prmQAMTxRx.FrequencyOffset, ...
        'SampleRate', prmQAMTxRx.Fs);
 
    QAMRx = QAMReceiver('DesiredAmplitude', 1/sqrt(prmQAMTxRx.Upsampling), ...
        'ModulationOrder', prmQAMTxRx.M, ...
        'DownsamplingFactor', prmQAMTxRx.Downsampling, ...
        'PhaseRecoveryDampingFactor', prmQAMTxRx.PhaseRecoveryDampingFactor, ...
        'PhaseRecoveryLoopBandwidth', prmQAMTxRx.PhaseRecoveryLoopBandwidth, ...
        'TimingRecoveryDampingFactor', prmQAMTxRx.TimingRecoveryDampingFactor, ...
        'TimingRecoveryLoopBandwidth', prmQAMTxRx.TimingRecoveryLoopBandwidth, ...
        'TimingErrorDetectorGain', prmQAMTxRx.TimingErrorDetectorGain, ...
        'PostFilterOversampling', prmQAMTxRx.Upsampling/prmQAMTxRx.Downsampling, ...
        'SampleRate', prmQAMTxRx.Fs, ...
        'ReceiverFilterCoefficients', prmQAMTxRx.ReceiverFilterCoefficients);    
%  
     QAMScopes = createScopes;

t(1) = 0;
ff = [-prmQAMTxRx.FrameSize*prmQAMTxRx.Upsampling/2:prmQAMTxRx.FrameSize*prmQAMTxRx.Upsampling/2-1]*prmQAMTxRx.Fs/prmQAMTxRx.FrameSize/prmQAMTxRx.Upsampling;

while(1)
    transmittedSignal = step(QAMTx); % Transmitter

    corruptSignal = step(QAMChan,transmittedSignal);

    [RCRxSignal,frequencyOffsetCompensate,timingRecBuffer,ProcessConstellation,temp] = step(QAMRx,corruptSignal); % Receiver

    subplot(2,3,1)
    plot(real(RCRxSignal),imag(RCRxSignal),'.');
    axis([-2,2,-2,2]);
    subplot(2,3,2)
    plot(real(frequencyOffsetCompensate),imag(frequencyOffsetCompensate),'.')
    axis([-2,2,-2,2]);
    subplot(2,3,3)
       plot(real(ProcessConstellation),imag(ProcessConstellation),'.')
    axis([-2,2,-2,2]);
    subplot(2,3,4)
    t = [1:length(temp)]*prmQAMTxRx.Ts + t(end);
    plot(t,mod(temp,pi/2))
    hold on
    plot(t,mod(-2*pi*prmQAMTxRx.FrequencyOffset*t - prmQAMTxRx.PhaseOffset,pi/2),'r')
    hold off
    subplot(2,3,5)
    semilogy(abs(fftshift(fft(RCRxSignal))))
    subplot(2,3,6)
    plot(timingRecBuffer)
    axis([0,length(timingRecBuffer),-0.5,1.5])
    drawnow
   % stepScopes(QAMScopes,RCRxSignal,frequencyOffsetCompensate,timingRecBuffer,ProcessConstellation); % Plots all the scopes
    
end

