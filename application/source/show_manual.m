function show_manual()
%SHOW_MANUAL Show the embedded gap-study operator guide.
    f=uifigure('Name','Neyer Gap Test - Help','Position',[340 180 720 620]);
    gl=uigridlayout(f,[1 1]); gl.Padding=[10 10 10 10];
    ta=uitextarea(gl,'Value',manual_lines(),'Editable','off');
    ta.FontName='Consolas';
end

function lines=manual_lines()
    lines={
      'NEYER GAP TEST - OPERATOR GUIDE'
      ''
      'PURPOSE'
      'This tool estimates how interaction changes as the physical gap changes.'
      'Smaller gaps make interaction more likely. Larger gaps make it less likely.'
      'The main results are the middle gap (about 50% interaction) and the'
      'transition width (how sharply the outcome changes with gap).'
      ''
      'BEFORE STARTING'
      '- Enter low and high guesses for the middle gap.'
      '- Enter a rough transition-width guess.'
      '- Enter the number of destructive tests available.'
      '- Enter the permitted minimum gap and the usable gap step for this study.'
      '- Foil thickness is construction information; it does not set the safety floor.'
      '- Use 0 to 10 mm as the study boundaries unless the approved setup changes.'
      ''
      'FOR EVERY TEST'
      '1. Build a new spacer setup at the requested reachable gap.'
      '2. Measure that unchanged setup 4 or 5 times.'
      '3. Enter all readings; their mean is used by the statistical calculation.'
      '4. Perform one test and select Interaction or No interaction.'
      '5. The spacer setup is not reused after the destructive test.'
      ''
      'IMPORTANT DISTINCTION'
      'The requested build gap is always shown with two decimal places.'
      'The measured mean is the actual gap used in the statistical model.'
      'If the same reachable gap is requested again, build and measure a new setup.'
      'The Stage-2 planning width cannot fall below two usable gap steps.'
      'If the readings span more than one usable step, the app warns you to check them.'
      ''
      'BOUNDARY PROTECTION'
      'An unexpected outcome at 0 or 10 mm is repeated once for confirmation.'
      'If it happens twice, the study pauses and saves the data for review.'
      'A boundary pause does not mean that the specimen test failed.'
      ''
      'READING THE RESULTS'
      '- Middle gap: the estimated gap with about 50% interaction chance.'
      '- Transition width: how gradual or sharp the change is.'
      '- High-interaction gap: a smaller-gap reliability point.'
      '- Negligible-interaction gap: a larger-gap reliability point.'
      '- Values outside 0 to 10 mm are outside the tested range, not build settings.'
      ''
      'CONFIDENCE AND PROBABILITY'
      'Probability describes the expected outcome at a gap.'
      'Confidence describes how certain the estimate is from the available data.'
      'These are different quantities and should be reported separately.'
      ''
      'SELF-CHECK'
      'Run the published demo. It must report middle 5.3922 and width 1.0412 - MATCH.'
      ''
      'Method: Neyer (1994) D-optimal sensitivity test.'
    };
end
