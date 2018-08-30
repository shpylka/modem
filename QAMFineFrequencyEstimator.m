classdef QAMFineFrequencyEstimator< matlab.System
%#codegen

%   Copyright 2012-2014 The MathWorks, Inc.

    properties (Nontunable)
        ProportionalGain = 0.008;
        IntegratorGain = 3e-5;
        DigitalSynthesizerGain = -1;
    end
    
    properties
       OUTPhase = 0; 
    end
    
    properties (Access=private)

        pLoopFilter
        pIntegrator
    end
    
    methods
        function obj = QAMFineFrequencyEstimator(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access  = private)
        function d = Demaper(obj,y)
                if (y > 6)                 d = 7; end;
                if ((y > 4) && (y <= 6))   d = 5; end
                if ((y > 2) && (y <= 4))   d = 3; end
                if ((y > 0) && (y <= 2))   d = 1; end
                if ((y > -2) && (y <= 0))  d = -1;end
                if ((y > -4) && (y <= -2)) d = -3;end
                if ((y > -6) && (y <= -4)) d = -5;end
                if (y <= -6)               d = -7;end

        end
    end
    methods (Access=protected)
        function setupImpl(obj, ~)
            obj.pLoopFilter = dsp.IIRFilter( ...
                'Structure', 'Direct form II transposed', ...
                'Numerator', [1 0], 'Denominator', [1 -1]);
            obj.pIntegrator = dsp.IIRFilter(...
                'Structure', 'Direct form II transposed', ...
                'Numerator', [0 1], 'Denominator', [1 -1]);
            obj.OUTPhase = 0;
        end
        
        function stepImpl(obj, u)
            
            % Find phase error
            phErr =   imag(u)*obj.Demaper(real(u)) - real(u)*obj.Demaper(imag(u));
            %phErr =   imag(u)*sign(real(u)) - real(u)*sign(imag(u));
            % Loop Filter
            loopFiltOut = step(obj.pLoopFilter,phErr*obj.IntegratorGain); 
            
            % Direct Digital Synthesizer
            DDSOut = step(obj.pIntegrator,phErr*obj.ProportionalGain + loopFiltOut);
            obj.OUTPhase =  obj.DigitalSynthesizerGain * DDSOut;
           

        end
        
        function resetImpl(obj)
            reset(obj.pLoopFilter);
            reset(obj.pIntegrator);
            obj.OUTPhase = 0;
        end
        
        function releaseImpl(obj)
            release(obj.pLoopFilter);
            release(obj.pIntegrator);            
        end
        
    end
end