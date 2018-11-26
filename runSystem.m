clear all
close all


%% Initialization
% initializes simulation parameters and generates the structure prmQAMTxRx. 
prmQAMTxRx = system_init; % QAM system parameters 


    QAMTx = QAMTransmitter(...
        'UpsamplingFactor', prmQAMTxRx.TransmitterUpsampling, ...
        'ModulationOrder', prmQAMTxRx.M, ...
        'FrameSize', prmQAMTxRx.FrameSize,...
        'TransmitterFilterCoefficients',prmQAMTxRx.TransmitterFilterCoefficients);

    QAMChan = Channel('PhaseOffset', prmQAMTxRx.PhaseOffset, ...
        'SignalPower', 1/prmQAMTxRx.TransmitterUpsampling*prmQAMTxRx.ChannelDownsampling, ...
        'UpsamplingFactor',prmQAMTxRx.TransmitterUpsampling, ...
        'ChannelDownsampling',prmQAMTxRx.ChannelDownsampling,...
        'EbNo', prmQAMTxRx.EbNo, ...
        'BitsPerSymbol', prmQAMTxRx.M, ...
        'FrequencyOffset', prmQAMTxRx.FrequencyOffset, ...
        'SymbolRate', prmQAMTxRx.SymbolRate);
%  
    QAMRx = QAMReceiver('ModulationOrder', prmQAMTxRx.M, ...
        'DownsamplingFactor', prmQAMTxRx.FilterDownsampling, ...
        'PhaseRecoveryDampingFactor', prmQAMTxRx.PhaseRecoveryDampingFactor, ...
        'PhaseRecoveryLoopBandwidth', prmQAMTxRx.PhaseRecoveryLoopBandwidth, ...
        'TimingRecoveryDampingFactor', prmQAMTxRx.TimingRecoveryDampingFactor, ...
        'TimingRecoveryLoopBandwidth', prmQAMTxRx.TimingRecoveryLoopBandwidth, ...
        'TimingErrorDetectorGain', prmQAMTxRx.TimingErrorDetectorGain, ...
        'PostFilterOversampling', prmQAMTxRx.PostFilterOversampling, ...
        'SymbolRate', prmQAMTxRx.SymbolRate, ...
        'ReceiverFilterCoefficients', prmQAMTxRx.ReceiverFilterCoefficients);    

% t(1) = 0;
% ff = [-prmQAMTxRx.FrameSize*prmQAMTxRx.Upsampl1q2w3e1q2w3eing/2:prmQAMTxRx.FrameSize*prmQAMTxRx.Upsampling/2-1]*prmQAMTxRx.Fs/prmQAMTxRx.FrameSize/prmQAMTxRx.Upsampling;

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
    plot(mod(temp,pi/2))
%     hold on
%     plot(mod(-2*pi*prmQAMTxRx.FrequencyOffset*t - prmQAMTxRx.PhaseOffset,pi/2),'r')
%     hold off
    subplot(2,3,5)
    plot(20*log10(abs(fftshift(fft(RCRxSignal)))))
    axis([0,16386,-10,50])
    subplot(2,3,6)
    plot(timingRecBuffer)
    axis([0,length(timingRecBuffer),-0.5,1.5])
    drawnow
     
end

