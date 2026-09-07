function paths = save_results_files(base, csv_text, html_text)
%SAVE_RESULTS_FILES  Write CSV + HTML report text to <base>.csv / <base>.html.
%   paths = SAVE_RESULTS_FILES(base, csv_text, html_text) writes the two files
%   next to each other, sharing the base name the user chose. Returns a struct
%   with .csv and .html full paths. Base-MATLAB file IO. [compiled-app]
    [d, name, ~] = fileparts(base);
    if isempty(name), name = 'drop-test-results'; end
    paths = struct('csv', fullfile(d, [name '.csv']), ...
                   'html', fullfile(d, [name '.html']));
    write_text(paths.csv,  csv_text);
    write_text(paths.html, html_text);
end

function write_text(p, txt)
    fid = fopen(p, 'w');
    if fid < 0, error('save_results_files:cannotWrite', 'Cannot write %s', p); end
    fwrite(fid, txt);
    fclose(fid);
end
