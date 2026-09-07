function paths = result_output_paths(base)
%RESULT_OUTPUT_PATHS  Return the CSV and HTML paths for a chosen base name.
%   A user may choose a name with or without an extension. The tool always
%   creates one CSV data file and one self-contained HTML report beside it.
    [folder, name, ~] = fileparts(base);
    if isempty(name)
        name = 'gap-study-results';
    end
    paths = struct('csv', fullfile(folder, [name '.csv']), ...
                   'html', fullfile(folder, [name '.html']));
end
