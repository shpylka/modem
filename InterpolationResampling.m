classdef InterpolationResampling < matlab.System
%#codegen
%    Refer figure 8.4.16, section 8.4.1 and figure 8.4.19 of "Digital 
%    Communications - A Discrete-Time Approach" by Michael Rice for 
%    interpolation filter, zero-crossing timing error detector, and  
%    modulo-1 counter for interpolation control respectively

%   Copyright 2012-2014 The MathWorks, Inc.

    properties (Nontunable)
        mu = 0;
        delta = 0;
        ChannelDownsampling = 1;
    end
    
    properties (Access=private)
        pMU
        DownSampleCount
        pDelayBuffer1
        pDelayBuffer2
        pDelayBuffer3
    end
    
    
    methods
        function obj = InterpolationResampling(varargin)
            setProperties(obj,nargin,varargin{:});
            obj.pMU = obj.mu;
            obj.DownSampleCount = 0;
        end
    end
    
    methods (Access=protected)
        function setupImpl(obj, ~)
            [obj.pDelayBuffer1, obj.pDelayBuffer2, obj.pDelayBuffer3] = ...
                deal(complex(0,0));
            obj.DownSampleCount = 0;
        end
        
        function dataOut = stepImpl(obj, data)
            dataOut = [];
            i=0;
            while (i<length(data))
                i=i+1;
                obj.DownSampleCount = obj.DownSampleCount +1; 
                if (mod(obj.DownSampleCount-1,obj.ChannelDownsampling) == 0)
                    interp_sempl =  obj.pDelayBuffer2 + ...
                                obj.pMU*  (-data(i)/6+obj.pDelayBuffer1/1 - obj.pDelayBuffer2/2 - obj.pDelayBuffer3/3)+...
                                obj.pMU^2*(           obj.pDelayBuffer1/2 - obj.pDelayBuffer2/1 + obj.pDelayBuffer3/2)+...
                                obj.pMU^3*( data(i)/6-obj.pDelayBuffer1/2 + obj.pDelayBuffer2/2 - obj.pDelayBuffer3/6);
                    dataOut = [dataOut; interp_sempl];
                end
                obj.pMU = obj.pMU + obj.delta;
                if (obj.pMU < 0)
                    obj.pMU = 1 + obj.pMU;
                    obj.DownSampleCount = obj.DownSampleCount +1;
                    
                    if (mod(obj.DownSampleCount-1,obj.ChannelDownsampling) == 0)
                        interp_sempl =  obj.pDelayBuffer2 + ...
                                    obj.pMU*  (-data(i)/6+obj.pDelayBuffer1/1 - obj.pDelayBuffer2/2 - obj.pDelayBuffer3/3)+...
                                    obj.pMU^2*(           obj.pDelayBuffer1/2 - obj.pDelayBuffer2/1 + obj.pDelayBuffer3/2)+...
                                    obj.pMU^3*( data(i)/6-obj.pDelayBuffer1/2 + obj.pDelayBuffer2/2 - obj.pDelayBuffer3/6);
                        dataOut = [dataOut; interp_sempl];
                    end
                    obj.pMU = obj.pMU + obj.delta;
                end
                if (obj.pMU > 1)
                    obj.pMU = obj.pMU-1;
                    obj.pDelayBuffer3 = obj.pDelayBuffer2;
                    obj.pDelayBuffer2 = obj.pDelayBuffer1;
                    obj.pDelayBuffer1 = data(i);
                    i=i+1;
                end
                 % Update delay buffers
                obj.pDelayBuffer3 = obj.pDelayBuffer2;
                obj.pDelayBuffer2 = obj.pDelayBuffer1;
                obj.pDelayBuffer1 = data(i);
            end
        end
        
        function resetImpl(obj)
             [obj.pDelayBuffer1, ...
                obj.pDelayBuffer2, ...
                obj.pDelayBuffer3] = deal(complex(0,0));

            obj.pMU = obj.mu;
        end
        
      
        function N = getNumOutputsImpl(~)
            N = 1;
        end
                

    end
    

end

