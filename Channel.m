classdef Channel < matlab.System 
%#codegen
    
%   Copyright 2012-2013 The MathWorks, Inc.
   
    
    properties (Nontunable)
        PhaseOffset = 47;
        SignalPower = 0.25;
        UpsamplingFactor = 4;
        ChannelDownsampling = 2;
        EbNo = 7;
        BitsPerSymbol = 2;
        FrequencyOffset = 5000;
        SymbolRate = 200000;
    end
    
    properties (Access=private)
        pPhaseFreqOffset
%        pVariableTimeDelay
        pAWGNChannel
        pResampler
    end
    
    properties (Access=private)
        pDelayStepSize = 0.000001;
%        pDelayMaximum = 8;
%        pDelayMinimum = 0;
        pDelay = 0.5;
    end
    
    methods
        function obj = Channel(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access=protected)
        function setupImpl(obj, ~)
            obj.pPhaseFreqOffset = comm.PhaseFrequencyOffset('PhaseOffset', obj.PhaseOffset,'FrequencyOffset', obj.FrequencyOffset,'SampleRate',obj.SymbolRate*obj.UpsamplingFactor);
%            obj.pVariableTimeDelay = dsp.VariableFractionalDelay('InterpolationMethod','Farrow','FilterLength',8,'MaximumDelay',  obj.pDelayMaximum);
            obj.pAWGNChannel = comm.AWGNChannel('EbNo', obj.EbNo,'BitsPerSymbol', obj.BitsPerSymbol,'SignalPower', obj.SignalPower,'SamplesPerSymbol', obj.UpsamplingFactor/obj.ChannelDownsampling);
            obj.pResampler = InterpolationResampling('mu',obj.pDelay,'delta', obj.pDelayStepSize,'ChannelDownsampling',obj.ChannelDownsampling);
        end
        
        
        function corruptSignal = stepImpl(obj, TxSignal)
 
            % Signal undergoes phase/frequency offset
            rotatedSignal = step(obj.pPhaseFreqOffset,TxSignal);
            
            % Resampling signal
            delayedSignal= step(obj.pResampler,rotatedSignal)*sqrt(obj.ChannelDownsampling);


            % Signal passing through AWGN channel
            corruptSignal = step(obj.pAWGNChannel, delayedSignal);
            
        end
        
        function resetImpl(obj)
            reset(obj.pPhaseFreqOffset);
%            reset(obj.pVariableTimeDelay);            
            reset(obj.pAWGNChannel);
            reset(obj.pResampler);
        end
        
        function releaseImpl(obj)
            release(obj.pPhaseFreqOffset);
%            release(obj.pVariableTimeDelay);            
            release(obj.pAWGNChannel);            
            release(obj.pResampler);
        end
        
        function N = getNumInputsImpl(~)
            N = 1; 
        end
        
        function num = getNumOutputsImpl(~)
           num=1; 
        end
    end
end

