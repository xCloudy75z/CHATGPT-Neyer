function summary = merge_planner_validation(config_path, shard_files, summary_path)
%MERGE_PLANNER_VALIDATION Validate every shard before summarising evidence.
    if isstring(shard_files), shard_files = cellstr(shard_files); end
    if ~iscell(shard_files) || isempty(shard_files)
        error('merge_planner_validation:noShards', ...
            'Provide the completed shard files.');
    end
    if isfile(summary_path)
        error('merge_planner_validation:summaryExists', ...
            'The summary already exists; it will not be overwritten.');
    end
    expected_hash = string(planner_validation_hash(config_path));
    config = jsondecode(fileread(config_path));
    all_rows = table();
    for file_index = 1:numel(shard_files)
        if ~isfile(shard_files{file_index})
            error('merge_planner_validation:missingShardFile', ...
                'A listed shard file is missing.');
        end
        one = readtable(shard_files{file_index}, 'TextType', 'string');
        if isempty(one) || ~ismember('config_hash', one.Properties.VariableNames) || ...
                any(one.config_hash ~= expected_hash)
            error('merge_planner_validation:configurationMismatch', ...
                'A shard was created from a different configuration.');
        end
        all_rows = [all_rows; one]; %#ok<AGROW>
    end
    shard_count_values = unique(all_rows.shard_count);
    if numel(shard_count_values) ~= 1
        error('merge_planner_validation:shardCountMismatch', ...
            'Shard files disagree about the total shard count.');
    end
    expected_shards = shard_count_values(1);
    if numel(unique(all_rows.shard_index)) ~= expected_shards || ...
            any(sort(unique(all_rows.shard_index))' ~= 1:expected_shards)
        error('merge_planner_validation:missingShard', ...
            'One or more expected shard files are missing.');
    end
    if numel(unique(all_rows.row_key)) ~= height(all_rows)
        error('merge_planner_validation:duplicateRows', ...
            'Duplicate scenario/seed rows were found.');
    end
    scenarios = expand_planner_validation_scenarios(config);
    expected_rows = sum([scenarios.repetitions]);
    if height(all_rows) ~= expected_rows
        error('merge_planner_validation:missingRows', ...
            'The merged row count does not match the configuration.');
    end

    scenario_ids = string({scenarios.id});
    summary_rows = struct([]);
    for scenario_index = 1:numel(scenario_ids)
        selected = all_rows(all_rows.scenario_id == scenario_ids(scenario_index), :);
        if height(selected) ~= scenarios(scenario_index).repetitions
            error('merge_planner_validation:missingRows', ...
                'A scenario is missing one or more repetitions.');
        end
        requested_rate = max(0.95, scenarios(scenario_index).confidence);
        withheld = all(startsWith(selected.run_status, "withheld"));
        usable_rate = safe_mean(selected.usable_fit);
        middle_rate = safe_mean(selected.middle_covered);
        boundary_rate = safe_mean(selected.boundary_conservative);
        usable_rows = selected.usable_fit == 1;
        reachable_rate = mean(selected.reachable_safe == 1);
        if any(usable_rows & selected.reachable_safe == 1)
            operating_rate = mean(selected.operating_gap_conservative( ...
                usable_rows & selected.reachable_safe == 1) == 1);
        else
            operating_rate = 0;
        end
        checkpoint_rate = safe_mean(selected.checkpoint_correct);
        accepted = ~withheld && usable_rate >= requested_rate && ...
            middle_rate >= scenarios(scenario_index).confidence && ...
            operating_rate >= scenarios(scenario_index).confidence && ...
            reachable_rate >= requested_rate && checkpoint_rate == 1;
        if withheld
            conclusion = "withheld";
        elseif accepted
            conclusion = "accepted";
        else
            conclusion = "not accepted";
        end
        one_summary = struct( ...
            'scenario_id', scenario_ids(scenario_index), ...
            'repetitions', height(selected), ...
            'outcome', selected.outcome(1), ...
            'reliability', selected.reliability(1), ...
            'confidence', selected.confidence(1), ...
            'accuracy_mm', selected.accuracy_mm(1), ...
            'planned_main', selected.planned_main(1), ...
            'planned_total', selected.planned_total(1), ...
            'required_rate', requested_rate, ...
            'usable_fit_rate', usable_rate, ...
            'middle_coverage_rate', middle_rate, ...
            'boundary_coverage_rate', boundary_rate, ...
            'operating_gap_coverage_rate', operating_rate, ...
            'reachable_safe_rate', reachable_rate, ...
            'checkpoint_correct_rate', checkpoint_rate, ...
            'conclusion', conclusion);
        if scenario_index == 1
            summary_rows = one_summary;
        else
            summary_rows(scenario_index) = one_summary; %#ok<AGROW>
        end
    end
    summary = struct2table(summary_rows);
    writetable(summary, summary_path);
end

function value = safe_mean(values)
    valid = isfinite(values);
    if ~any(valid), value = 0; else, value = mean(values(valid)); end
end
