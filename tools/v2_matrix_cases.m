function cases=v2_matrix_cases(mode)
%V2_MATRIX_CASES Fixed, independently seeded release studies.
lists={[1 1.1 2.5 4.1 5.5 10]', ...
    [0 0.15 0.5 1.1 2.07 3.67 5 10]', ...
    [1 1.03 1.47 2.18 3.02 4.95 7.4 10]'};
if strcmp(mode,'regular')
    [m,v,s,g,n]=ndgrid([1.5 5 8.5],[0.15 0.25 0.5 1 1.5], ...
        [0.05 0.1 0.15 0.5],[0.25 1 2],[20 62]);
elseif strcmp(mode,'list')
    [m,v,s,g,n]=ndgrid([1.5 5 8.5],[0.15 0.25 0.5 1 1.5],1:3,1,[20 62]);
else
    error('v2Matrix:mode','Choose regular or list.');
end
cases=struct('id',{},'scenario',{},'repetition',{},'middle',{}, ...
    'variation',{},'step',{},'starting',{},'budget',{},'seed',{},'gaps',{});
for i=1:numel(m)
    for r=1:5
        if strcmp(mode,'regular'), step=s(i); gaps=(0:step:10)';
        else, gaps=lists{s(i)}; step=min(diff(gaps)); end
        cases(end+1)=struct('id',numel(cases)+1,'scenario',i,'repetition',r, ...
            'middle',m(i),'variation',v(i),'step',step,'starting',g(i), ...
            'budget',n(i),'seed',202609140+1000*i+r,'gaps',gaps); %#ok<AGROW>
    end
end
end
