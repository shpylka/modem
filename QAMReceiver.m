
%   Copyright 2012-2013 The MathWorks, Inc.

classdef QAMReceiver < matlab.System
    %#codegen
    properties (Nontunable)
        DesiredAmplitude = 0.5;
        ModulationOrder = 4;
        DownsamplingFactor = 2;
        PhaseRecoveryLoopBandwidth = 0.01;
        PhaseRecoveryDampingFactor = 1;
        TimingRecoveryLoopBandwidth = 0.01;
        TimingRecoveryDampingFactor = 1;
        PostFilterOversampling = 2;
        PhaseErrorDetectorGain = 2;
        PhaseRecoveryGain = 1;
        TimingErrorDetectorGain = 5.4;
        TimingRecoveryGain = -1;
        SampleRate = 200000;
        ReceiverFilterCoefficients = 1;
    end
    
    properties (Access=private)
        pAGC
        pRxFilter
%        pCoarseFreqCompensator
        pFineFreqEstimator
        pTimingRec

     end
    
    properties (Access = private, Nontunable)
        pUpdatePeriod % Defines the size of vector that will be processed in AGC system object
    end
    
    methods
        function obj = QAMReceiver(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access=protected)
        function setupImpl(obj, ~)
            obj.pUpdatePeriod = 4;
            obj.pAGC = comm.AGC('UpdatePeriod',obj.pUpdatePeriod);
            obj.pRxFilter = dsp.FIRDecimator(obj.DownsamplingFactor,obj.ReceiverFilterCoefficients);
% %             obj.pCoarseFreqCompensator = QPSKCoarseFrequencyCompensator(...
% %                 'ModulationOrder', obj.ModulationOrder, ...
% %                 'CoarseCompFrequencyResolution', obj.CoarseCompFrequencyResolution, ...
% %                 'SampleRate', obj.SampleRate, ...
% %                 'DownsamplingFactor', obj.DownsamplingFactor);
            
            % Refer C.57 to C.61 in Michael Rice's "Digital Communications 
            % - A Discrete-Time Approach" for K1 and K2
            theta = obj.PhaseRecoveryLoopBandwidth/...
                (obj.PhaseRecoveryDampingFactor + ...
                0.25/obj.PhaseRecoveryDampingFactor)/obj.PostFilterOversampling;
            d = 1 + 2*obj.PhaseRecoveryDampingFactor*theta + theta*theta;
            K1 = (4*obj.PhaseRecoveryDampingFactor*theta/d)/...
                (obj.PhaseErrorDetectorGain*obj.PhaseRecoveryGain);
            K2 = (4*theta*theta/d)/...
                (obj.PhaseErrorDetectorGain*obj.PhaseRecoveryGain);
            obj.pFineFreqEstimator = QAMFineFrequencyEstimator(...
                'ProportionalGain', K1,...
                'IntegratorGain', K2,...
                'DigitalSynthesizerGain', -1*obj.PhaseRecoveryGain);

           
            % Refer C.57 to C.61 in Michael Rice's "Digital Communications 
            % - A Discrete-Time Approach" for K1 and K2

            theta = obj.TimingRecoveryLoopBandwidth/...
                (obj.TimingRecoveryDampingFactor + ...
                0.25/obj.TimingRecoveryDampingFactor)/obj.PostFilterOversampling;
            d = 1 + 2*obj.TimingRecoveryDampingFactor*theta + theta*theta;

            K1 = (4*obj.TimingRecoveryDampingFactor*theta/d)/...
                (obj.TimingErrorDetectorGain*obj.TimingRecoveryGain);
            K2 = (4*theta*theta/d)/...
                (obj.TimingErrorDetectorGain*obj.TimingRecoveryGain);

            obj.pTimingRec = TimingRecovery('ProportionalGain', K1,...
                                            'IntegratorGain', K2,...
                                            'PostFilterOversampling', obj.PostFilterOversampling);

        end
        
        
        function [RCRxSignal,frequencyOffsetCompensation,timingRecBuffer,ProcessCanstellation] = stepImpl(obj, y)
            
            AGCSignal = y;%obj.DesiredAmplitude*step(obj.pAGC, y);
            % Pass the signal through Square-Root Raised Cosine Received
            % Filter
            RCRxSignal = step(obj.pRxFilter,AGCSignal);
            
            % Coarsely compensate for the Frequency Offset
            %coarseCompSignal = step(obj.pCoarseFreqCompensator, RCRxSignal);
            
            % Buffers to store values required for plotting
            %coarseCompBuffer = coder.nullcopy(complex(zeros(size(coarseCompSignal))));
            ProcessCanstellation = coder.nullcopy(zeros(size(RCRxSignal)));
            frequencyOffsetCompensation = coder.nullcopy(zeros(size(RCRxSignal)));
            timingRecBuffer = coder.nullcopy(zeros(size(AGCSignal)));
            % Scalar processing for fine frequency compensation and timing
            % recovery 
            for i=1:length(RCRxSignal)
                

                frequencyOffsetCompensation(i) = RCRxSignal(i)*exp(1i*obj.pFineFreqEstimator.OUTPhase);
                step(obj.pFineFreqEstimator,frequencyOffsetCompensation(i));
                
                % Timing recovery of the received data
                [dataOut, isDataValid, timingRecBuffer(i)] = step(obj.pTimingRec, frequencyOffsetCompensation(i));
                if (isDataValid)
                    ProcessCanstellation = [ProcessCanstellation(2:end);dataOut];
                end
            end
            
        end
        
        function resetImpl(obj)
            reset(obj.pAGC);
            reset(obj.pRxFilter);
            %reset(obj.pCoarseFreqCompensator);
            reset(obj.pFineFreqEstimator);
            reset(obj.pTimingRec);
        end
        
        function releaseImpl(obj)
            release(obj.pAGC);
            release(obj.pRxFilter);
            %release(obj.pCoarseFreqCompensator);
            release(obj.pFineFreqEstimator);
            release(obj.pTimingRec);
          
        end
        
        function N = getNumOutputsImpl(~)
            N = 4;
        end
    end
end

