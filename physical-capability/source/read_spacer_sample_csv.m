function [labelled_sizes_mm,readings_by_size] = read_spacer_sample_csv(csv_path)
%READ_SPACER_SAMPLE_CSV Read the released three-reading spacer sample.
% The CSV is the single recorded source for the batch-capability summary.

if ~(ischar(csv_path) || (isstring(csv_path) && isscalar(csv_path))) || ...
        ~isfile(csv_path)
    error('read_spacer_sample_csv:missingFile', ...
        'The spacer sample CSV could not be found.');
end

data = readmatrix(csv_path,'NumHeaderLines',1);
if size(data,2) ~= 6 || isempty(data) || ...
        any(~isfinite(data(:,1:5)),'all')
    error('read_spacer_sample_csv:badData', ...
        'Every spacer row must contain a size, sample number, and three readings.');
end

labelled_sizes_mm = unique(data(:,1),'stable')';
readings_by_size = cell(1,numel(labelled_sizes_mm));
for size_number = 1:numel(labelled_sizes_mm)
    rows = data(data(:,1) == labelled_sizes_mm(size_number),:);
    expected_numbers = (1:size(rows,1))';
    if ~isequal(rows(:,2),expected_numbers) || ...
            any(abs(mean(rows(:,3:5),2) - rows(:,6)) > 5e-7)
        error('read_spacer_sample_csv:badData', ...
            'Spacer sample numbers or recorded averages are inconsistent.');
    end
    readings_by_size{size_number} = rows(:,3:5);
end
end
