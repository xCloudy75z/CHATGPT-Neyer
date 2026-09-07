classdef TestGapPresentation < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addGapCandidate(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'application','source')));
        end
    end

    methods (Test)
        function plainTextUsesGapMeaning(testCase)
            text=format_result_text(finished_result());

            testCase.verifySubstring(text,'MIDDLE GAP');
            testCase.verifySubstring(text,'TRANSITION WIDTH');
            testCase.verifySubstring(text,'HIGH-INTERACTION GAP');
            testCase.verifySubstring(text,'NEGLIGIBLE-INTERACTION GAP');
            testCase.verifyFalse(contains(lower(text),'height'));
            testCase.verifyFalse(contains(lower(text),'fire'));
        end

        function csvStoresGapAndInteractionOutcomes(testCase)
            text=results_to_csv_text(finished_result());

            testCase.verifySubstring(text,'test,gap (mm),outcome');
            testCase.verifySubstring(text,'1,3.00,interaction');
            testCase.verifySubstring(text,'2,7.00,no interaction');
            testCase.verifySubstring(text,'Middle gap');
            testCase.verifySubstring(text,'High-interaction gap');
            testCase.verifySubstring(text,'Negligible-interaction gap');
            testCase.verifyFalse(contains(lower(text),'height'));
            testCase.verifyFalse(contains(lower(text),'break'));
            testCase.verifyFalse(contains(lower(text),'survive'));
        end

        function htmlExplainsDecreasingGapDirection(testCase)
            text=results_to_html(finished_result(),'');

            testCase.verifySubstring(text,'Neyer gap-study results');
            testCase.verifySubstring(text,'Smaller gaps make interaction more likely');
            testCase.verifySubstring(text,'Larger gaps make interaction less likely');
            testCase.verifySubstring(text,'Middle gap');
            testCase.verifyFalse(contains(lower(text),'height'));
            testCase.verifyFalse(contains(lower(text),'break'));
            testCase.verifyFalse(contains(lower(text),'survive'));
        end

        function existingCsvPreventsBothResultFilesFromBeingChanged(testCase)
            folder=tempname;
            mkdir(folder);
            cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
            base=fullfile(folder,'gap-results');
            csvPath=[base '.csv'];
            write_fixture(csvPath,'existing CSV');

            testCase.verifyError( ...
                @()save_results_files(base,'replacement CSV','new HTML'), ...
                'save_results_files:alreadyExists');
            testCase.verifyEqual(fileread(csvPath),'existing CSV');
            testCase.verifyFalse(isfile([base '.html']));
        end

        function existingHtmlPreventsBothResultFilesFromBeingChanged(testCase)
            folder=tempname;
            mkdir(folder);
            cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
            base=fullfile(folder,'gap-results');
            htmlPath=[base '.html'];
            write_fixture(htmlPath,'existing HTML');

            testCase.verifyError( ...
                @()save_results_files(base,'new CSV','replacement HTML'), ...
                'save_results_files:alreadyExists');
            testCase.verifyFalse(isfile([base '.csv']));
            testCase.verifyEqual(fileread(htmlPath),'existing HTML');
        end

        function operatorScreensDoNotUseOldDropTestLanguage(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            files={fullfile(root,'application','source','neyer_app.m'), ...
                   fullfile(root,'application','source','run_test_ui.m'), ...
                   fullfile(root,'application','source','report.m'), ...
                   fullfile(root,'application','source','show_result.m'), ...
                   fullfile(root,'application','source','show_manual.m'), ...
                   fullfile(root,'application','source','plan_prep_message.m')};
            visibleOldPhrases={ ...
                'average height','breaking height','drop height','first drop', ...
                'doing the drops','break or survive','break/survive', ...
                'reliability at a height','height to set','rig minimum height', ...
                'safe:','fails:','number of parts','the average is', ...
                'average and spread','run more items'};
            for f=1:numel(files)
                source=lower(fileread(files{f}));
                for p=1:numel(visibleOldPhrases)
                    testCase.verifyFalse(contains(source,visibleOldPhrases{p}), ...
                        sprintf('%s still contains "%s".',files{f},visibleOldPhrases{p}));
                end
            end
        end

        function mainMenuNamesTheNeyerGapTest(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            source=fileread(fullfile(root,'application','source','neyer_app.m'));
            testCase.verifySubstring(source,'''Neyer Gap Test''');
        end

        function resultHeadlineHasEnoughVerticalSpace(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            source=fileread(fullfile(root,'application','source','show_result.m'));
            testCase.verifySubstring(source,'gA.RowHeight   = {54,');
        end

        function chartEdgeCalloutsPointInward(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            source=fileread(fullfile(root,'application','source','draw_distribution.m'));
            testCase.verifySubstring(source,'''HorizontalAlignment'',''left'', ''VerticalAlignment'',''bottom''');
            testCase.verifySubstring(source,'''HorizontalAlignment'',''right'', ''VerticalAlignment'',''bottom''');
            testCase.verifySubstring(source,'''%.4g%% interaction\n%.2f %s''');
            testCase.verifySubstring(source,'''negligible interaction\n%.2f %s''');
        end

        function pausedPlainTextRequestsReviewNotMoreTests(testCase)
            result=struct('has_overlap',false,'mu',NaN,'status','paused', ...
                          'stop_reason','no_interaction_at_min_gap');
            text=format_result_text(result);

            testCase.verifySubstring(text,'PAUSED - REVIEW REQUIRED');
            testCase.verifyFalse(contains(text,'Run more'));
        end

        function chartShowsCorrectGapDirection(testCase)
            fig=figure('Visible','off');
            cleaner=onCleanup(@()close(fig)); %#ok<NASGU>
            ax=axes('Parent',fig);
            draw_distribution(ax,finished_result());

            labels=get(findall(ax,'Type','text'),'String');
            if ischar(labels), labels={labels}; end
            flat={};
            for k=1:numel(labels)
                if iscell(labels{k}), flat=[flat labels{k}(:)']; %#ok<AGROW>
                else, flat{end+1}=labels{k}; %#ok<AGROW>
                end
            end
            words=lower(strjoin(flat,' | '));
            testCase.verifyEqual(ax.XLabel.String,'gap (mm)');
            testCase.verifySubstring(words,'middle gap');
            testCase.verifySubstring(words,'high interaction');
            testCase.verifySubstring(words,'negligible interaction');
            testCase.verifyFalse(contains(words,'fire'));
            testCase.verifyFalse(contains(words,'break'));
            testCase.verifyFalse(contains(words,'height'));
        end

        function matlabResultFigureKeepsBellCurveAndAddsProbabilityCurve(testCase)
            oldVisible=get(groot,'defaultFigureVisible');
            set(groot,'defaultFigureVisible','off');
            restore=onCleanup(@()set(groot,'defaultFigureVisible',oldVisible)); %#ok<NASGU>
            h=plot_result(finished_result(),neyer_settings());
            cleaner=onCleanup(@()close(h)); %#ok<NASGU>

            axesFound=findall(h,'Type','axes');
            testCase.assertEqual(numel(axesFound),2);
            for k=1:numel(axesFound)
                testCase.verifyEqual(axesFound(k).XLim,[0 10],'AbsTol',1e-12);
            end
            ylabels=arrayfun(@(a)lower(strjoin(cellstr(a.YLabel.String),' ')), ...
                axesFound,'UniformOutput',false);
            probabilityAxes=axesFound(contains(ylabels,'chance of interaction'));
            testCase.assertNumElements(probabilityAxes,1);
            testCase.verifyEqual(probabilityAxes.XLim,[0 10],'AbsTol',1e-12);
            curves=findall(probabilityAxes,'Type','line');
            lengths=arrayfun(@(line)numel(line.XData),curves);
            [~,longest]=max(lengths);
            testCase.verifyGreaterThan(curves(longest).YData(1),curves(longest).YData(end));
        end
    end
end

function write_fixture(path,text)
    file=fopen(path,'w');
    assert(file>=0,'Could not create test fixture.');
    cleanup=onCleanup(@()fclose(file)); %#ok<NASGU>
    fwrite(file,text);
end

function result=finished_result()
    result=struct( ...
        'has_overlap',true,'status','complete','n',2,'unit','mm', ...
        'levels',[3;7],'successes',logical([1;0]), ...
        'mu',5,'mu_lo',4.5,'mu_hi',5.5, ...
        'sigma',1,'sigma_lo',0.7,'sigma_hi',1.4, ...
        'confidence_level',0.95,'tail_fraction',0.999, ...
        'high_interaction_gap',1.9,'negligible_interaction_gap',8.1);
end
