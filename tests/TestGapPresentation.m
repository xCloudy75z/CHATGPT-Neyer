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
            testCase.verifySubstring(text,'OVERALL VARIATION');
            testCase.verifySubstring(lower(text),'entire tested process varies');
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

        function physicalCsvPreservesRequestsAndEveryReading(testCase)
            result=finished_result();
            result.levels=[3.668;7.004];
            result.raw_requested_levels=[3.645;7.0049];
            result.requested_levels=[3.65;7.00];
            result.measurements={ [3.661 3.670 3.681 3.660], ...
                                  [7.011 7.002 6.999 7.001 7.007] };
            result.usable_resolution=0.05;
            result.foil_thickness=0.015;
            result.measurement_ranges=[0.021;0.012];
            result.measurement_warnings=logical([false;false]);

            text=results_to_csv_text(result);

            testCase.verifySubstring(text, ...
                ['test,internal target (mm),build request (mm),measured mean (mm),reading 1,' ...
                 'reading 2,reading 3,reading 4,reading 5,reading range,' ...
                 'measurement warning,outcome']);
            testCase.verifySubstring(text, ...
                '1,3.645,3.65,3.668,3.661,3.67,3.681,3.66,,0.021,no,interaction');
            testCase.verifySubstring(text, ...
                '2,7.0049,7.00,7.004,7.011,7.002,6.999,7.001,7.007,0.012,no,no interaction');
            testCase.verifySubstring(text,'Usable resolution,0.0500,mm');
            testCase.verifySubstring(text,'Foil thickness,0.0150,mm');
        end

        function physicalCsvUsesCleanRoundTripPrecision(testCase)
            result=finished_result();
            result.raw_requested_levels=[pi;7];
            result.requested_levels=[3.14;7];
            result.levels=[pi;7];
            result.measurements={ [pi 3.14 3.15 3.16], [7 7 7 7] };

            text=results_to_csv_text(result);

            testCase.verifySubstring(text,'3.141592653589793');
            testCase.verifyFalse(contains(text,'3.14159265358979,'));
            testCase.verifyFalse(contains(text,'3.1415926535897931'));
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
