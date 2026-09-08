classdef TestDirectRunSafety < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot,'application','source')));
        end
    end

    methods (Test)
        function sixtyTwoSeparatedResultsNeverRequestImmediateDuplicate(testCase)
            parsed=parse_run_inputs( ...
                {'1','10','1','62','1','10','mm','0.10','0.015'});
            parameters=struct('mu_min',parsed.params.avg_low, ...
                'mu_max',parsed.params.avg_high, ...
                'sigma_guess',parsed.params.spread_guess);
            response=@(gap,~)struct('outcome',gap<=1.1, ...
                'measurements',repmat(gap,1,4));

            record=run_loop(parameters,parsed.num_parts,response,parsed.cfg);

            testCase.verifyEqual(record.requested_N,62);
            testCase.verifyGreaterThan(record.N,5);
            testCase.verifyFalse(any(abs(diff(record.requested_levels))<1e-12), ...
                'Direct mode requested the same physical gap twice in a row.');
            testCase.verifyFalse(has_overlap(record.levels,record.successes));
        end
    end
end
