function message = format_requested_gap(level, unit)
%FORMAT_REQUESTED_GAP Build the operator instruction with two decimals.
%   Internal calculations and measured readings retain their full precision;
%   only the physical build instruction is deliberately simplified.
    if nargin < 2 || isempty(unit), unit = 'mm'; end
    message = sprintf('Build a gap of %.2f %s.',level,unit);
end
