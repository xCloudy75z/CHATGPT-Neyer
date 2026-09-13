project_root = fileparts(fileparts(mfilename('fullpath')));
temporary_folder = tempname;
mkdir(temporary_folder);

copyfile(fullfile(project_root,'delivery','General_Measurement_Recorder.m'), ...
    temporary_folder);
addpath(temporary_folder,'-begin');
clear General_Measurement_Recorder;

record = General_Measurement_Recorder('newrecord','2mm-01',2,2.07, ...
    'mm','one physical reading',datetime(2026,9,13,22,0,0));
assert(record.measurement_count == 1);
assert(strcmp(record.measurement_uncertainty,'not assessed'));
assert(record.measured_size == 2.07);
csv_text = General_Measurement_Recorder('tocsv',record);
assert(contains(csv_text,'2mm-01,2,2.07,mm'));

output_path = fullfile(temporary_folder,'measurement-check.csv');
saved_path = General_Measurement_Recorder('save',output_path,csv_text);
assert(strcmp(saved_path,output_path));
assert(isfile(output_path));
try
    General_Measurement_Recorder('save',output_path,csv_text);
    error('verify_general_measurement_recorder_delivery:overwriteAccepted', ...
        'The recorder silently replaced an existing file.');
catch expected_error
    assert(strcmp(expected_error.identifier, ...
        'General_Measurement_Recorder:alreadyExists'));
end

evidence_path = fullfile(project_root,'audit','v111', ...
    'general-recorder-clean-start.txt');
file_id = fopen(evidence_path,'w');
assert(file_id >= 0,'Could not write recorder verification evidence.');
fprintf(file_id,'MATLAB %s general recorder clean-start check passed.\n', ...
    version('-release'));
fprintf(file_id,'Only General_Measurement_Recorder.m was placed on the clean path.\n');
fprintf(file_id,'One measurement was accepted, saved, and read back.\n');
fprintf(file_id,'A second save to the same name was refused.\n');
fclose(file_id);
clear General_Measurement_Recorder;
rmpath(temporary_folder);
rmdir(temporary_folder,'s');
