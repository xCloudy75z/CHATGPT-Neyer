function f=v2_check_transcript(result,record,gaps)
%V2_CHECK_TRANSCRIPT Independent checks of actual physical-run transcripts.
x=record.requested_levels(:); y=logical(record.successes(:)); tol=1e-9;
f=struct('nonfinite',double(any(~isfinite(x))), ...
    'bounds',double(any(x<min(gaps)-tol | x>max(gaps)+tol)), ...
    'membership',double(any(~any(abs(x-gaps(:)')<tol,2))), ...
    'duplicate',0,'stage',double(any(~ismember(record.stage,[1 2 3])) || ...
    any(diff(record.stage)<0)),'budget',double(record.N>record.requested_N), ...
    'measurements',double(any(cellfun(@numel,record.measurements)~=1)), ...
    'fit',0,'direction',0,'pause_reason',0,'boundary',0);
for k=find(abs(diff(x))<tol)'+1
    minConfirm=abs(x(k)-min(gaps))<tol && ~any(y(1:k-1));
    maxConfirm=abs(x(k)-max(gaps))<tol && all(y(1:k-1));
    f.duplicate=f.duplicate+double(~(minConfirm||maxConfirm));
end
if result.has_overlap
    f.fit=double(~all(isfinite([result.mu result.sigma])) || result.sigma<=0);
    lo=shape_model(result.mu-result.sigma,result.mu,result.sigma);
    hi=shape_model(result.mu+result.sigma,result.mu,result.sigma);
    f.direction=double(~(lo.p>hi.p));
end
if strcmp(record.status,'paused')
    f.pause_reason=double(isempty(record.stop_reason));
end
if strcmp(record.stop_reason,'no_interaction_at_min_gap')
    f.boundary=double(numel(x)<2 || ~all(abs(x(end-1:end)-min(gaps))<tol) || any(y));
elseif strcmp(record.stop_reason,'interaction_at_max_gap')
    f.boundary=double(numel(x)<2 || ~all(abs(x(end-1:end)-max(gaps))<tol) || ~all(y));
end
end
