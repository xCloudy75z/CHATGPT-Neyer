function xb = find_root(R, x0, dir, thr, cap, floorval)
%FIND_ROOT  Bracket-then-bisect one-sided root of R(x)=thr, on side `dir` of x0.
%   R(x0)~0 and R rises away from x0. Returns NaN if not bracketed within `cap`
%   of x0. `floorval` eases a downward search toward a hard limit (e.g. sigma>0).
%   Shared by lr_confidence and the reliability-at-confidence units.  [addendum LR]
    xb  = NaN;
    lo  = x0;                       % R(lo) < thr
    step = 0.05 * max(abs(x0), 1);
    hi  = NaN; found = false;
    for it = 1:100
        cand = x0 + dir*step;
        if dir < 0 && cand <= floorval
            cand = 0.5*(lo + floorval);
        end
        if abs(cand - x0) > cap, return; end       % not bracketed -> NaN
        if R(cand) >= thr
            hi = cand; found = true; break;
        else
            lo = cand; step = 2*step;
        end
    end
    if ~found, return; end
    for it = 1:100                                  % bisection
        mid = 0.5*(lo + hi);
        if R(mid) >= thr, hi = mid; else lo = mid; end
        if abs(hi - lo) <= 1e-6 * max(abs(x0),1), break; end
    end
    xb = 0.5*(lo + hi);
end
