function folder=v2_audit_folder(root,versionName)
%V2_AUDIT_FOLDER Keep each candidate's evidence in an explicit child folder.
if nargin<2, versionName=getenv('NEYER_V2_AUDIT_VERSION'); end
versionName=char(string(versionName));
if isempty(versionName)
    folder=fullfile(root,'audit','v2');
elseif ~isempty(regexp(versionName,'^candidate-[0-9]{2}$','once'))
    folder=fullfile(root,'audit','v2',versionName);
else
    error('v2Audit:badVersion','Use a version such as candidate-02.');
end
end
