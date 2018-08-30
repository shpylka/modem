classdef QAMTransmitter < matlab.System  
%#codegen
% Generates the QPSK signal to be transmitted
    
%   Copyright 2012-2016 The MathWorks, Inc.
    
    properties (Nontunable)
        UpsamplingFactor = 4;
        ModulationOrder = 2;
        FrameSize = 1024;        
        TransmitterFilterCoefficients = 1;
    end
    
    properties (Access=private)
        pQAMModulator 
        pTransmitterFilter
    end
    properties (Access = public)
        transmittedData
    end
    
    
    methods
        function obj = QAMTransmitter(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access=protected)
        function setupImpl(obj)
            obj.pQAMModulator  = comm.RectangularQAMModulator('ModulationOrder', 2^obj.ModulationOrder,...
                'BitInput',true);
            obj.pTransmitterFilter = dsp.FIRInterpolator(obj.UpsamplingFactor, ...
                obj.TransmitterFilterCoefficients);
        end
        
        function transmittedSignal = stepImpl(obj)
            obj.transmittedData = randi(2,obj.ModulationOrder*obj.FrameSize,1)-1;
            modulatedData = step(obj.pQAMModulator,obj.transmittedData);       % Modulates the bits into QPSK symbols           
            transmittedSignal = step(obj.pTransmitterFilter,modulatedData); % Square root Raised Cosine Transmit Filter
        end
        
        function resetImpl(obj)
            reset(obj.pQAMModulator );
            reset(obj.pTransmitterFilter);
        end
        
        function releaseImpl(obj)
            release(obj.pQAMModulator );
            release(obj.pTransmitterFilter);
        end
        
        function N = getNumInputsImpl(~)
            N = 0;
        end
    end
end

