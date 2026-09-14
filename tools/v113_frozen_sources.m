function folder=v113_frozen_sources(folder)
%V113_FROZEN_SOURCES Test the sealed V1.13 implementation, not evolving V2.
root=fileparts(fileparts(mfilename('fullpath')));
artifact=fullfile(root,'delivery','Neyer_Gap_Test_v1_13.mlx');
fp=v113_release_fingerprint(artifact);
assert(strcmp(fp.sha256,'2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E'));
converted=fullfile(folder,'converted.m');
matlab.internal.liveeditor.openAndConvert(artifact,converted);
text=fileread(converted); delete(converted);
inventory=readtable(fullfile(root,'audit','v113-complete','component-map.csv'),'TextType','string');
names=erase(inventory.source_file,'.m');
starts=zeros(numel(names),1);
for k=1:numel(names)
    pattern=['(?m)^function[ \t]+(?:(?:\[[^\]]+\]|[A-Za-z]\w*)[ \t]*=[ \t]*)?' char(names(k)) '\s*\('];
    hits=regexp(text,pattern,'start');
    assert(numel(hits)==1,'Frozen component missing or duplicated: %s',names(k));
    starts(k)=hits;
end
[starts,order]=sort(starts); names=names(order);
for k=1:numel(names)
    if k<numel(names), finish=starts(k+1)-1; else, finish=numel(text); end
    fid=fopen(fullfile(folder,char(names(k)+'.m')),'w','n','UTF-8');
    assert(fid>=0); fprintf(fid,'%s',text(starts(k):finish)); fclose(fid);
end
end
