
%   Copyright 2012-2013 The MathWorks, Inc.

classdef QAMReceiver < matlab.System
    %#codegen
    properties (Nontunable)
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
        SymbolRate = 200000;
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
        
        
        function [y,frequencyOffsetCompensation,timingRecBuffer,ProcessCanstellation,temp] = stepImpl(obj, y)
            
            AGCSignal = y;%obj.DesiredAmplitude*step(obj.pAGC, y);
            % Pass the signal through Square-Root Raised Cosine Received
            % Filter
            
            
            % Coarsely compensate for the Frequency Offset
            %coarseCompSignal = step(obj.pCoarseFreqCompensator, RCRxSignal);
            
            % Buffers to store values required for plotting
            %coarseCompBuffer = coder.nullcopy(complex(zeros(size(coarseCompSignal))));
% % %             ProcessCanstellation = coder.nullcopy(zeros(length(y),1));
% % %             frequencyOffsetCompensation = coder.nullcopy(zeros(size(y)));
% % %             timingRecBuffer = coder.nullcopy(zeros(size(y)));
% % %             RCRxSignal = coder.nullcopy(zeros(size(y)));
% % %             temp = coder.nullcopy(zeros(size(y)));
            % Scalar processing for fine frequency compensation and timing
            % recovery 
            ProcessCanstellation = [];
            for i=1:length(AGCSignal)
                
                temp(i) = obj.pFineFreqEstimator.OUTPhase;
                frequencyOffsetCompensation(i) = AGCSignal(i)*exp(1i*obj.pFineFreqEstimator.OUTPhase);
                RCRxSignal(i) = step(obj.pRxFilter,frequencyOffsetCompensation(i));
                %step(obj.pFineFreqEstimator,frequencyOffsetCompensation(i));
                
                % Timing recovery of the received data
                [dataOut, isDataValid, timingRecBuffer(i)] = step(obj.pTimingRec,RCRxSignal(i));
                if (isDataValid)
                %if (mod(i-1,obj.PostFilterOversampling)==0)
                    step(obj.pFineFreqEstimator,dataOut);
                    ProcessCanstellation = [ProcessCanstellation;dataOut];
                else
                    step(obj.pFineFreqEstimator,0);
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
            N = 5;
        end
    end
end

