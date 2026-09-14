function output = General_Measurement_Recorder(action, varargin)
%GENERAL_MEASUREMENT_RECORDER Record one measurement for each general item.
%   Run GENERAL_MEASUREMENT_RECORDER with no inputs for the guided recorder.
%   Each saved row contains the one measurement entered for that item.

    if nargin == 0
        output = run_recorder_ui();
        return;
    end
    action = validatestring(lower(char(string(action))), ...
        {'newrecord','tocsv','save'});
    switch action
        case 'newrecord'
            output = make_record(varargin{:});
        case 'tocsv'
            output = records_to_csv(varargin{:});
        case 'save'
            output = save_records(varargin{:});
    end
end

function record = make_record(sample_id, nominal_size, measured_size, unit, note, recorded_at)
    if ~(ischar(sample_id) || (isstring(sample_id) && isscalar(sample_id))) || ...
            isempty(strtrim(char(sample_id)))
        error('General_Measurement_Recorder:badSampleId', ...
            'Enter a sample ID.');
    end
    if ~(isnumeric(nominal_size) && isreal(nominal_size) && ...
            isscalar(nominal_size) && isfinite(nominal_size) && nominal_size >= 0)
        error('General_Measurement_Recorder:badNominalSize', ...
            'Nominal size must be one finite, nonnegative number.');
    end
    if isnumeric(measured_size) && numel(measured_size) ~= 1
        error('General_Measurement_Recorder:oneMeasurementRequired', ...
            'Enter exactly one measured size for this sample.');
    end
    if ~(isnumeric(measured_size) && isreal(measured_size) && ...
            isscalar(measured_size) && isfinite(measured_size) && measured_size >= 0)
        error('General_Measurement_Recorder:badMeasuredSize', ...
            'Measured size must be one finite, nonnegative number.');
    end
    if ~(ischar(unit) || (isstring(unit) && isscalar(unit))) || ...
            isempty(strtrim(char(unit)))
        error('General_Measurement_Recorder:badUnit', ...
            'Enter a unit such as mm.');
    end
    if nargin < 5 || isempty(note), note = ''; end
    if ~(ischar(note) || (isstring(note) && isscalar(note)))
        error('General_Measurement_Recorder:badNote', ...
            'The note must be text.');
    end
    if nargin < 6 || isempty(recorded_at), recorded_at = datetime('now'); end
    if ~(isdatetime(recorded_at) && isscalar(recorded_at) && ~isnat(recorded_at))
        error('General_Measurement_Recorder:badTimestamp', ...
            'The date and time could not be recorded.');
    end
    record = struct( ...
        'sample_id',strtrim(char(sample_id)), ...
        'nominal_size',double(nominal_size), ...
        'measured_size',double(measured_size), ...
        'unit',strtrim(char(unit)), ...
        'recorded_at',recorded_at, ...
        'note',char(note), ...
        'measurement_count',1);
end

function csv_text = records_to_csv(records)
    if isempty(records)
        error('General_Measurement_Recorder:noRecords', ...
            'Add at least one measurement before saving.');
    end
    header = ['sample ID,nominal size,measured size,unit,date and time,note,' ...
        'measurement count'];
    rows = cell(numel(records),1);
    for record_index = 1:numel(records)
        record = records(record_index);
        shown_time = record.recorded_at;
        shown_time.Format = 'yyyy-MM-dd HH:mm:ss';
        rows{record_index} = strjoin({ ...
            csv_text_field(record.sample_id), ...
            shortest_number(record.nominal_size), ...
            shortest_number(record.measured_size), ...
            csv_text_field(record.unit), ...
            csv_text_field(char(shown_time)), ...
            csv_text_field(record.note), ...
            '1'}, ',');
    end
    csv_text = strjoin([{header};rows], sprintf('\n'));
end

function output_path = save_records(output_path, csv_text)
    output_path = char(string(output_path));
    if isempty(strtrim(output_path))
        error('General_Measurement_Recorder:badOutputPath', ...
            'Choose a CSV output file.');
    end
    [folder,~,extension] = fileparts(output_path);
    if ~strcmpi(extension,'.csv')
        error('General_Measurement_Recorder:badOutputPath', ...
            'The output file must end in .csv.');
    end
    if ~isempty(folder) && ~isfolder(folder)
        error('General_Measurement_Recorder:missingFolder', ...
            'The selected output folder does not exist.');
    end
    if isfile(output_path)
        error('General_Measurement_Recorder:alreadyExists', ...
            'Nothing was saved because that file already exists. Choose another name.');
    end
    file_id = fopen(output_path,'w');
    if file_id < 0
        error('General_Measurement_Recorder:cannotWrite', ...
            'The selected file could not be created.');
    end
    cleanup = onCleanup(@()fclose(file_id));
    fwrite(file_id,csv_text);
end

function records = run_recorder_ui()
    records = struct([]);
    while true
        answers = inputdlg({ ...
            'Sample ID:', ...
            'Nominal size:', ...
            'One measured size:', ...
            'Unit:', ...
            'Optional note:'}, ...
            'General measurement recorder', [1 52], {'','','','mm',''});
        if isempty(answers), return; end
        try
            new_record = make_record(answers{1},str2double(answers{2}), ...
                str2double(answers{3}),answers{4},answers{5},datetime('now'));
        catch input_error
            errordlg(input_error.message,'Please check the entry','modal');
            continue;
        end
        records(end+1) = new_record;
        choice = questdlg(sprintf('%d measurement(s) recorded.',numel(records)), ...
            'Continue', 'Add another','Save CSV','Cancel','Add another');
        if strcmp(choice,'Add another'), continue; end
        if ~strcmp(choice,'Save CSV'), records = struct([]); return; end
        [name,folder] = uiputfile('*.csv','Save measurement record', ...
            'measurements.csv');
        if isequal(name,0), continue; end
        try
            save_records(fullfile(folder,name),records_to_csv(records));
            msgbox(sprintf('Saved to:\n%s',fullfile(folder,name)), ...
                'Measurement record saved','modal');
            return;
        catch save_error
            errordlg(save_error.message,'Nothing was saved','modal');
        end
    end
end

function text = shortest_number(value)
    for significant_digits = 1:17
        candidate = sprintf(['%.' num2str(significant_digits) 'g'],value);
        if isequal(str2double(candidate),value), text=candidate; return; end
    end
    text=sprintf('%.17g',value);
end

function text = csv_text_field(value)
    text = char(string(value));
    if any(contains(text, {'"',',',sprintf('\n'),sprintf('\r')}))
        text = ['"' strrep(text,'"','""') '"'];
    end
end
