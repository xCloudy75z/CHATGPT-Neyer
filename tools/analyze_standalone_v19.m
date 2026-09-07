root = fileparts(fileparts(mfilename('fullpath')));
source = fullfile(root,'delivery','Neyer_Gap_Test_v1_9.m');
issues = checkcode(source,'-id');

fprintf('Code Analyzer messages: %d\n',numel(issues));
for k = 1:numel(issues)
    fprintf('%s line %d: %s\n',issues(k).id,issues(k).line,issues(k).message);
end

tree = mtree(source,'-file');
if isempty(tree)
    error('analyze_standalone_v19:parseFailure','MATLAB could not parse the standalone source.');
end
fprintf('MATLAB parser accepted the standalone source.\n');
exit(0);
