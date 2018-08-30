classdef Channel < matlab.System 
%#codegen
    
%   Copyright 2012-2013 The MathWorks, Inc.
   
    
    properties (Nontunable)
        PhaseOffset = 47;
        SignalPower = 0.25;
        UpsamplingFactor = 4;
        EbNo = 7;
        BitsPerSymbol = 2;
        FrequencyOffset = 5000;
        SampleRate = 200000;
    end
    
    properties (Access=private)
        pPhaseFreqOffset
        pVariableTimeDelay
        pAWGNChannel
    end
    
    properties (Access=private)
        pDelayStepSize = 0.001;
        pDelayMaximum = 8;
        pDelayMinimum = 0;
        pDelay = 0;
        DelayArray = [];
    end
    
    methods
        function obj = Channel(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access=protected)
        function setupImpl(obj, ~)
            obj.pPhaseFreqOffset = comm.PhaseFrequencyOffset('PhaseOffset', obj.PhaseOffset,'FrequencyOffset', obj.FrequencyOffset,'SampleRate',obj.SampleRate);
            obj.pVariableTimeDelay = dsp.VariableFractionalDelay('MaximumDelay',  obj.pDelayMaximum);
            obj.pAWGNChannel = comm.AWGNChannel('EbNo', obj.EbNo,'BitsPerSymbol', obj.BitsPerSymbol,'SignalPower', obj.SignalPower,'SamplesPerSymbol', obj.UpsamplingFactor);
         end
        
        
        function corruptSignal = stepImpl(obj, TxSignal)
 
            for i=1:length(TxSignal)
                obj.pDelay = obj.pDelay + obj.pDelayStepSize;  
                if obj.pDelay > obj.pDelayMaximum
                    obj.pDelayStepSize = -obj.pDelayStepSize;
                    obj.pDelay = obj.pDelayMaximum;
                end
                if obj.pDelay < obj.pDelayMinimum
                    obj.pDelayStepSize = -obj.pDelayStepSize;
                    obj.pDelay = obj.pDelayMinimum;
                end
                obj.DelayArray(i,1) = obj.pDelay;
            end
            % Signal undergoes phase/frequency offset
            rotatedSignal = step(obj.pPhaseFreqOffset,TxSignal);
            
            % Delayed signal
            delayedSignal = step(obj.pVariableTimeDelay, rotatedSignal, obj.DelayArray);
            
            % Signal passing through AWGN channel
            corruptSignal = step(obj.pAWGNChannel, delayedSignal);
        end
        
        function resetImpl(obj)
            reset(obj.pPhaseFreqOffset);
            reset(obj.pVariableTimeDelay);            
            reset(obj.pAWGNChannel);
        end
        
        function releaseImpl(obj)
            release(obj.pPhaseFreqOffset);
            release(obj.pVariableTimeDelay);            
            release(obj.pAWGNChannel);            
        end
        
        function N = getNumInputsImpl(~)
            N = 1; 
        end
    end
end

