classdef TestGapBoundaryPause < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addGapCandidate(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'application','source')));
        end
    end

    methods (Test)
        function twoNoInteractionsAtZeroPauseForReview(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            record=run_loop(params,20,@(~,~)false,neyer_settings());

            testCase.verifyEqual(record.status,'paused');
            testCase.verifyEqual(record.stop_reason,'no_interaction_at_min_gap');
            testCase.verifyEqual(sum(record.levels==0),2);
            testCase.verifyLessThan(numel(record.levels),20);
        end

        function twoInteractionsAtTenPauseForReview(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            record=run_loop(params,20,@(~,~)true,neyer_settings());

            testCase.verifyEqual(record.status,'paused');
            testCase.verifyEqual(record.stop_reason,'interaction_at_max_gap');
            testCase.verifyEqual(sum(record.levels==10),2);
            testCase.verifyLessThan(numel(record.levels),20);
        end

        function expectedBoundaryAnswerContinuesStudy(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            outcome=@(gap,~) gap<=0;
            record=run_loop(params,8,outcome,neyer_settings());

            testCase.verifyEqual(record.status,'complete');
            testCase.verifyEmpty(record.stop_reason);
            testCase.verifyEqual(numel(record.levels),8);
            testCase.verifyTrue(any(record.successes));
            testCase.verifyTrue(any(~record.successes));
        end

        function pausedRunReportDoesNotTellOperatorToKeepTesting(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            text=evalc('[result,record]=run_test(params,20,@(~,~)false,neyer_settings());');

            testCase.verifyEqual(record.status,'paused');
            testCase.verifyEqual(result.status,'paused');
            testCase.verifySubstring(text,'REVIEW REQUIRED');
            testCase.verifyFalse(contains(text,'Run more items'));
        end

        function boundaryMessagesUseGapLanguage(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            text=evalc('run_loop(params,8,@(gap,~)gap<=0,neyer_settings());');

            testCase.verifyFalse(contains(text,'height'));
            testCase.verifyFalse(contains(text,'parts may break'));
        end
    end
end
