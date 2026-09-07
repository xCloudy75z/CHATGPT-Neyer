function paths = save_results_files(base, csv_text, html_text)
%SAVE_RESULTS_FILES  Write CSV + HTML report text to <base>.csv / <base>.html.
%   paths = SAVE_RESULTS_FILES(base, csv_text, html_text) writes the two files
%   next to each other, sharing the base name the user chose. Returns a struct
%   with .csv and .html full paths. Existing files are never replaced.
%   Base-MATLAB file IO. [compiled-app]
    paths = result_output_paths(base);
    existing = {};
    if isfile(paths.csv), existing{end+1} = paths.csv; end %#ok<AGROW>
    if isfile(paths.html), existing{end+1} = paths.html; end %#ok<AGROW>
    if ~isempty(existing)
        error('save_results_files:alreadyExists', ...
            ['Nothing was saved because this file already exists:\n%s\n\n' ...
             'Choose a different name so no earlier result is replaced.'], ...
            strjoin(existing, newline));
    end
    write_text(paths.csv,  csv_text);
    write_text(paths.html, html_text);
end

function write_text(p, txt)
    fid = fopen(p, 'w');
    if fid < 0, error('save_results_files:cannotWrite', 'Cannot write %s', p); end
    fwrite(fid, txt);
    fclose(fid);
end
