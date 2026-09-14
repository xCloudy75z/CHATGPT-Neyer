project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root,'physical-capability','source'));
output_folder = fullfile(project_root,'audit','v112');
if ~isfolder(output_folder), mkdir(output_folder); end
raw_path = fullfile(output_folder,'spacer-sample-readings.csv');
[nominal_sizes,readings] = read_spacer_sample_csv(raw_path);
summary = summarize_spacer_batches(nominal_sizes,readings);

summary_path = fullfile(output_folder,'spacer-sample-summary.md');
file_id = fopen(summary_path,'w');
assert(file_id >= 0,'Could not create spacer summary evidence.');
cleanup = onCleanup(@()fclose(file_id));
fprintf(file_id,'# Sampled spacer capability\n\n');
fprintf(file_id,'Ten spacers from each labelled size were measured three times. These are batch samples, not individually tracked stock.\n\n');
fprintf(file_id,'| Label | Typical thickness | Lowest sampled spacer average | Highest sampled spacer average | Full reading range |\n');
fprintf(file_id,'|---:|---:|---:|---:|---:|\n');
for size_number = 1:numel(summary)
    item = summary(size_number);
    fprintf(file_id,'| %.2f mm | %.3f mm | %.3f mm | %.3f mm | %.2f–%.2f mm |\n', ...
        item.nominal_size_mm,item.typical_thickness_mm, ...
        item.lowest_spacer_average_mm,item.highest_spacer_average_mm, ...
        item.lowest_reading_mm,item.highest_reading_mm);
end
expected_combination = sum([summary.typical_thickness_mm]);
fprintf(file_id,'\nThe unrounded sum of one typical spacer of every size is %.6f mm, which displays directly as %.2f mm. The earlier complete-build measurement was 3.67 mm.\n', ...
    expected_combination,expected_combination);
fprintf(file_id,'\nThe app must still use one final measurement of the complete setup. The sample does not prove the thickness of every spacer in the larger stock.\n');
fprintf(file_id,'\nFoil recipes remain disabled until foil-stack measurements and the practical maximum layer count are supplied.\n');
clear cleanup;
exit(0);
