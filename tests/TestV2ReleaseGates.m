classdef TestV2ReleaseGates < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(tc)
            root=fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'application','source')));
        end
    end
    methods (Test)
        function exactRegularCoverage(tc)
            % Missing a dimension or repetition must shrink this independent count.
            c=v2_matrix_cases('regular');
            tc.verifyNumElements(c,1800);
            tc.verifyEqual(unique([c.step]),[0.05 0.10 0.15 0.50]);
            tc.verifyEqual(unique([c.middle]),[1.5 5 8.5]);
            tc.verifyEqual(unique([c.variation]),[0.15 0.25 0.5 1 1.5]);
            tc.verifyEqual(unique([c.starting]),[0.25 1 2]);
            tc.verifyEqual(unique([c.budget]),[20 62]);
            tc.verifyEqual(numel(unique([c.seed])),1800);
        end
        function irregularRunsUseExplicitListsAndUniqueSeeds(tc)
            c=v2_matrix_cases('list');
            tc.verifyNumElements(c,450);
            tc.verifyEqual(c(1).gaps,[1 1.1 2.5 4.1 5.5 10]');
            tc.verifyEqual(numel(unique([c.seed])),450);
        end
        function checkerRejectsInventedGapAndPrematureBoundary(tc)
            % A corrupt transcript must never be certified by the audit.
            c=v2_matrix_cases('list');
            r=struct('requested_levels',[5.5;1.05], 'successes',logical([0;0]), ...
                'stage',[1;1],'N',2,'requested_N',20,'measurements',{{5.5,1.05}}, ...
                'status','paused','stop_reason','no_interaction_at_min_gap');
            result=struct('has_overlap',false);
            f=v2_check_transcript(result,r,c(1).gaps);
            tc.verifyEqual(f.membership,1);
            tc.verifyEqual(f.boundary,1);
            r.requested_levels=[1;1]; r.measurements={1,1};
            f=v2_check_transcript(result,r,c(1).gaps);
            tc.verifyEqual(sum(struct2array(f)),0);
        end
        function captureLeavesUnrelatedFigureAlive(tc)
            % Audit cleanup must not delete another user's MATLAB figure.
            root=fileparts(fileparts(mfilename('fullpath')));
            unrelated=figure('Visible','off','Name','Unrelated release-gate sentinel');
            cleanup=onCleanup(@() delete_if_valid(unrelated)); %#ok<NASGU>
            isolated_capture(fullfile(root,'tools','capture_v2_inputs.m'));
            tc.verifyTrue(isgraphics(unrelated));
        end
        function oneStudyWritesAndResumesItsCheckpoint(tc)
            folder=tc.createTemporaryFolder();
            run_v2_matrix('regular',1,1800,folder);
            before=load(fullfile(folder,'regular-1-of-1800.mat'));
            run_v2_matrix('regular',1,1800,folder);
            after=load(fullfile(folder,'regular-1-of-1800.mat'));
            tc.verifyNumElements(after.rows,1);
            tc.verifyEqual(after.rows.invariant_failures,0);
            tc.verifyEqual(after.rows.replay_mismatches,0);
            tc.verifyEqual(after,before);
        end
        function incompleteMatrixCannotBeCertified(tc)
            folder=tc.createTemporaryFolder();
            tc.verifyError(@() v2_collect_results('regular',folder), ...
                'v2Matrix:incomplete');
            rows=table((1:1800)',zeros(1800,1),zeros(1800,1), ...
                'VariableNames',{'id','invariant_failures','replay_mismatches'});
            writetable(rows,fullfile(folder,'regular-1-of-1.csv'));
            summary=v2_collect_results('regular',folder);
            tc.verifyEqual(summary.studies,1800);
            rows.id(1800)=1799;
            writetable(rows,fullfile(folder,'regular-1-of-1.csv'));
            tc.verifyError(@() v2_collect_results('regular',folder), ...
                'v2Matrix:incomplete');
        end
        function emptyStopReasonsDoNotBreakShardCollection(tc)
            folder=tc.createTemporaryFolder();
            for shard=1:2
                first=1+(shard-1)*900;
                rows=table((first:first+899)',zeros(900,1),zeros(900,1), ...
                    'VariableNames',{'id','invariant_failures','replay_mismatches'});
                if shard==1, rows.reason=repmat("",900,1);
                else, rows.reason=repmat("no_interaction_at_min_gap",900,1); end
                writetable(rows,fullfile(folder,sprintf('regular-%d-of-2.csv',shard)));
            end
            summary=v2_collect_results('regular',folder);
            tc.verifyEqual(summary.studies,1800);
        end
    end
end
function delete_if_valid(h)
if isgraphics(h), delete(h); end
end
function isolated_capture(script)
run(script);
end
