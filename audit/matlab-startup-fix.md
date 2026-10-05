# Reliable MATLAB command-line startup

## What was happening

MATLAB sometimes stopped before any Neyer code ran and displayed **Error Starting MATLAB**.
The hidden error message was:

> Unable to create the preferences folder in MathWorks\MATLAB\R2022b.
> Preferences folder location must be a valid full path.

The path shown in the error was only a relative ending. It was not a complete
Windows path such as `C:\Users\games\AppData\Roaming\...`.

## Root cause

Automated commands run inside a controlled workspace. MATLAB tried to use its
normal Windows preferences location before the Neyer code started, but that
location was not usable by the controlled process. This was a MATLAB startup
environment problem, not a Neyer calculation or Live Script problem.

## Implemented solution

`tools/invoke_matlab.ps1` sets MATLAB's officially supported
`MATLAB_PREFDIR` value to a full, writable folder inside this project before
starting MATLAB. The folder is ignored by Git and does not enter the release.

All command-line MATLAB work for this project should use this launcher. The
V1.15 release command is `tools/verify_v115_release.ps1`.

## Verification

`tools/test_matlab_launcher.ps1` deliberately supplied the original broken
relative value before each launch. The protected launcher then started MATLAB
successfully two times in succession, and MATLAB confirmed that it was using
the expected full project-local preferences path.

MathWorks documents `MATLAB_PREFDIR` as the supported way to override the
preferences location when the default folder is unsuitable:
https://www.mathworks.com/matlabcentral/answers/93696-how-do-i-change-the-matlab-preferences-directory-location
