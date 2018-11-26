classdef TimingRecovery < matlab.System
%#codegen
%    Refer figure 8.4.16, section 8.4.1 and figure 8.4.19 of "Digital 
%    Communications - A Discrete-Time Approach" by Michael Rice for 
%    interpolation filter, zero-crossing timing error detector, and  
%    modulo-1 counter for interpolation control respectively

%   Copyright 2012-2014 The MathWorks, Inc.

    properties (Nontunable)
        ProportionalGain = -0.003;
        IntegratorGain = -1e-5;
        PostFilterOversampling = 2;
    end
    
    properties (Access=private)
        pLoopFilter
        pMU
        pStrobe
        pDelayBuffer1
        pDelayBuffer2
        pDelayBuffer3
%         pTEDDelay1
%         pTEDDelay2
%         pTEDDelay3
%         pTEDDelay4
%         pTEDDelay5
%         pTEDDelay6 
%         pTEDDelay7
%         pTEDDelay8
        pTEDDelay
%         pDelayStrobe
        pNCODelay
        pRegTemp
    end
    
    properties (Constant, Access=private)
        pAlpha = 0.5;
    end
    
    methods
        function obj = TimingRecovery(varargin)
            setProperties(obj,nargin,varargin{:});
            obj.pTEDDelay = zeros(obj.PostFilterOversampling,1);
        end
    end
    
    methods (Access=protected)
        function setupImpl(obj, ~)
            [obj.pDelayBuffer1, obj.pDelayBuffer2, obj.pDelayBuffer3] = ...
                deal(complex(0,0));
%             [obj.pTEDDelay1, obj.pTEDDelay2,obj.pTEDDelay3,obj.pTEDDelay4] = deal(complex(0,0));
%             obj.pDelayStrobe = 0;
            obj.pTEDDelay = complex(zeros(obj.PostFilterOversampling,1));
            [obj.pNCODelay, obj.pRegTemp] = deal(0);
            obj.pMU = 0;
            obj.pStrobe = 0;
            obj.pLoopFilter = dsp.IIRFilter( ...
                'Structure', 'Direct form II transposed', ...
                'Numerator', [1 0], 'Denominator', [1 -1]);

        end
        
        function [dataOut, isDataValid, normTimingErr] = stepImpl(obj, y)
            normTimingErr = obj.pMU;
            
            % Interpolation Filter
            interpFiltOut = interpfilter(obj,y);
            
            % Timing Error Detector
            e = TED(obj,interpFiltOut);
            
            % Loop filter
            loopFiltOut = step(obj.pLoopFilter,e*obj.IntegratorGain);
            
            % Updates timing difference for Interpolation Filter
            [underflow,mu] = NCO_control(obj,e,loopFiltOut);...
            
            % Check if the data is valid
            if obj.pStrobe>0
                  dataOut =  interpFiltOut;
                  isDataValid = 1;
                  obj.pMU = mu;
            else
                  dataOut =  0;
                  isDataValid = 0;                
            end
            obj.pStrobe = underflow;
        end
        
        function resetImpl(obj)
            reset(obj.pLoopFilter);

            [   obj.pMU, ...
                obj.pStrobe, ...
                obj.pNCODelay, ...
                obj.pRegTemp]   = deal(0);
            [obj.pDelayBuffer1, ...
                obj.pDelayBuffer2, ...
                obj.pDelayBuffer3] = deal(complex(0,0));%, ...
% %                 obj.pTEDDelay1, ...
% %                 obj.pTEDDelay2,...
% %                 obj.pTEDDelay3,...
% %                 obj.pTEDDelay4, ...
% %                 obj.pTEDDelay5,...
% %                 obj.pTEDDelay6,... 
% %                 obj.pTEDDelay7, ...
% %                 obj.pTEDDelay8] = deal(complex(0,0));


        end
        
        function releaseImpl(obj)
            release(obj.pLoopFilter);
        end        
        
        function N = getNumOutputsImpl(~)
            N = 3;
        end
    end
    
    methods (Access=private)
        
        function Out = interpfilter(obj,in)
            % Parabolic piecewise polynomial interpolator, farrow interpolator with
            % alpha = 1/2, see figure 8.4.16 of "Digital Communications - A
            % Discrete-Time Approach" by Michael Rice.
            K = -obj.pAlpha;
            
%             Out = obj.pDelayBuffer2 + ...
%                 obj.pMU*  (K*(in+obj.pDelayBuffer3)+(1-K)*obj.pDelayBuffer1 - (1+K)*obj.pDelayBuffer2)+...
%                 obj.pMU^2*(K*(obj.pDelayBuffer1+obj.pDelayBuffer2-in-obj.pDelayBuffer3));
            Out =  obj.pDelayBuffer2 + ...
                            obj.pMU*  (-in/6+obj.pDelayBuffer1/1 - obj.pDelayBuffer2/2 - obj.pDelayBuffer3/3)+...
                            obj.pMU^2*(      obj.pDelayBuffer1/2 - obj.pDelayBuffer2/1 + obj.pDelayBuffer3/2)+...
                            obj.pMU^3*( in/6-obj.pDelayBuffer1/2 + obj.pDelayBuffer2/2 - obj.pDelayBuffer3/6);
            
            % Update delay buffers
            obj.pDelayBuffer3 = obj.pDelayBuffer2;
            obj.pDelayBuffer2 = obj.pDelayBuffer1;
            obj.pDelayBuffer1 = in;
        end
        
        function e = TED(obj,in)
            % Zero-Crossing timing error detector. See "Zero-Crossing Timing Error
            % Detector" section in Chapter 8.4.1 of "Digital Communications - A
            % Discrete-Time Approach" by Michael Rice. For bit stuffing/stripping
            % details, see page 490-494 of the same book.
            
            if obj.pStrobe %&& obj.pDelayStrobe~=obj.pStrobe
                %e = real(obj.pTEDDelay1) * (sign(real(obj.pTEDDelay2)) -  sign(real(in))) + imag(obj.pTEDDelay1) * (sign(imag(obj.pTEDDelay2)) - sign(imag(in)));
                e = real(obj.pTEDDelay(end/2)) * ((real(obj.pTEDDelay(end))) -  (real(in))) + imag(obj.pTEDDelay(end/2)) * ((imag(obj.pTEDDelay(end))) - (imag(in)));

            else
                e = 0;
            end
            
%             if obj.pDelayStrobe~=obj.pStrobe
                % Shift contents in delay register
% %                 obj.pTEDDelay8 = obj.pTEDDelay7;
% %                 obj.pTEDDelay7 = obj.pTEDDelay6;
% %                 obj.pTEDDelay6 = obj.pTEDDelay5;
% %                 obj.pTEDDelay5 = obj.pTEDDelay4;                
% %                 obj.pTEDDelay4 = obj.pTEDDelay3;
% %                 obj.pTEDDelay3 = obj.pTEDDelay2;
% %                 obj.pTEDDelay2 = obj.pTEDDelay1;
% %                 obj.pTEDDelay1 = in;
                obj.pTEDDelay = [in;obj.pTEDDelay(1:end-1)];
%             elseif obj.pStrobe
%                 % Two consecutive high strobes
%                 obj.pTEDDelay2 = 0; % Stuff missing sample
%                 obj.pTEDDelay1 = in;
%             end
            % If both current and previous enable signals are 0, skip current sample
            % and keep the delayed signals unchanged. (Bit stripping)
%             obj.pDelayStrobe = obj.pStrobe;
        end
        
        function [ Underflow,mu ] = NCO_control( obj,e,loopFiltOut )
            % Implementation of modulo-1 counter for interpolation control listed in
            % Figure 8.4.19 of "Digital Communications - A Discrete-Time Approach"
            % by Michael Rice. See design details in Chapter 8.4.3 of the same book.
            
            % Underflow - Indicator of counter underflow. This is the strobe signal
            %             for downstream processing
            % mu - Difference between actual sampling instant and the optimal instant,
            %      between zero and one
            % obj.pRegTemp - The estimated timing error normalized by half QPSK symbols
            
            Delta = e*obj.ProportionalGain + loopFiltOut; %If loop is in lock, Delta would be small
            counter = mod(obj.pNCODelay,1)-Delta-1/obj.PostFilterOversampling; %decrementing counter
            if counter < 0
                Underflow = 1;
                obj.pRegTemp = mod(obj.pNCODelay,1)/(Delta+1/obj.PostFilterOversampling);
            else
                Underflow = 0;
            end
            
            mu = obj.pRegTemp;
            % Update delay buffer
            obj.pNCODelay = mod(obj.pNCODelay,1)-Delta-1/obj.PostFilterOversampling;
            
        end  
    end
end

