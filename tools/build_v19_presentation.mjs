import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const workspaceDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const { SKILL_DIR, RUNTIME_PYTHON } = process.env;
if (!path.isAbsolute(SKILL_DIR ?? "") || !path.isAbsolute(RUNTIME_PYTHON ?? "")) {
  throw new Error("SKILL_DIR and RUNTIME_PYTHON must be absolute paths.");
}
const TMP_DIR = path.join(workspaceDir, ".pptx-build-v19");
const FINAL_PPTX = path.join(workspaceDir, "delivery", "Neyer_Gap_Test_v1_9_Presentation_r4.pptx");
await fs.mkdir(TMP_DIR, { recursive: true });
await fs.mkdir(path.dirname(FINAL_PPTX), { recursive: true });

const { applyPresentationChartFont, finalizePresentation } = await import(
  pathToFileURL(path.join(SKILL_DIR, "container_tools/artifact_tool_utils.mjs")).href,
);

const C = { ink:"#142738", navy:"#173B57", blue:"#26739B", teal:"#23837B", amber:"#D98A2B", pale:"#E8EDF0", paper:"#FBFCFD", muted:"#526775", white:"#FFFFFF", line:"#C7D1D7" };
const family = "Aptos";
const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });

function box(slide, left, top, width, height, fill, line="none") {
  return slide.shapes.add({ geometry:"rect", position:{left,top,width,height}, fill, line:{fill:line,width:line==="none"?0:1} });
}
function textBox(slide, text, left, top, width, height, opts={}) {
  const s=slide.shapes.add({geometry:"textbox",position:{left,top,width,height},fill:"none",line:{fill:"none",width:0}});
  s.text=text;
  s.text.style={typeface:family,fontSize:opts.size??24,color:opts.color??C.ink,bold:opts.bold??false,alignment:opts.align??"left",autoFit:"shrinkText"};
  return s;
}
function title(slide, value, number) {
  textBox(slide,value,64,38,1080,60,{size:34,bold:true,color:C.ink});
  box(slide,64,108,1152,3,C.blue);
  textBox(slide,String(number).padStart(2,"0"),1170,40,46,32,{size:18,bold:true,color:C.muted,align:"right"});
}
function footer(slide, note="Neyer Gap Test v1.9") { textBox(slide,note,64,680,700,20,{size:11,color:C.muted}); }
async function addImage(slide,name,alt,pos) {
  const bytes=await fs.readFile(path.join(workspaceDir,"assets","screenshots",name));
  slide.images.add({blob:new Uint8Array(bytes),contentType:"image/png",alt,fit:"contain",position:pos});
}
function styleTable(table, rows, cols, header=true, fontSize=17) {
  table.borders.assign({style:"solid",fill:C.line,width:1});
  table.cells.block({row:0,column:0,rowCount:rows,columnCount:cols}).assign({margins:{left:9,right:9,top:6,bottom:6},textStyle:{typeface:family,fontSize,color:C.ink}});
  if(header) table.cells.block({row:0,column:0,rowCount:1,columnCount:cols}).assign({fill:C.navy,textStyle:{typeface:family,fontSize,bold:true,color:C.white}});
  for(let r=1;r<rows;r++) if(r%2===0) table.cells.block({row:r,column:0,rowCount:1,columnCount:cols}).fill="#F0F4F6";
}

// 1 Cover
{
 const s=presentation.slides.add(); s.background.fill=C.navy;
 textBox(s,"Neyer Gap Test",76,120,900,88,{size:58,bold:true,color:C.white});
 textBox(s,"MATLAB implementation audit and V1.9 delivery",80,216,870,52,{size:28,color:"#D8EAF2"});
 box(s,80,330,470,9,C.amber); box(s,550,330,180,9,"#E6C36B"); box(s,730,330,470,9,C.teal);
 textBox(s,"Decreasing-interaction gap model",80,385,690,40,{size:22,bold:true,color:C.white});
 textBox(s,"Standalone MATLAB R2022b Live Script\nAudit • physical workflow • simulation evidence • operation",80,442,780,90,{size:20,color:"#D8EAF2"});
 textBox(s,"September 2026",80,640,300,28,{size:15,color:"#BBD1DC"});
}

// 2 Concept
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"What the method estimates",2);
 await addImage(s,"04-results.png","MATLAB results window",{left:62,top:142,width:650,height:470});
 textBox(s,"Middle gap",770,162,390,36,{size:26,bold:true,color:C.blue});
 textBox(s,"The gap with about 50% interaction chance.",770,205,390,58,{size:21});
 textBox(s,"Transition width",770,302,390,36,{size:26,bold:true,color:C.amber});
 textBox(s,"How quickly the material response changes around the middle.",770,345,390,76,{size:21});
 textBox(s,"Smaller gap",770,484,170,30,{size:18,bold:true,color:C.amber});
 textBox(s,"interaction likely",770,516,190,28,{size:17,color:C.muted});
 textBox(s,"Larger gap",1010,484,170,30,{size:18,bold:true,color:C.teal,align:"right"});
 textBox(s,"interaction unlikely",980,516,200,28,{size:17,color:C.muted,align:"right"});
 box(s,780,568,390,7,C.line); box(s,780,568,170,7,C.amber); box(s,1010,568,160,7,C.teal); footer(s);
}

// 3 Audit table
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"V1.8 audit findings",3);
 const values=[
  ["Area","What V1.8 did","Audit result"],
  ["Stage 1","Simplified outward doubling","Reference table matched, general paper rule did not"],
  ["Stage 2 transition","Used 1.5 × guessed sigma","Historical reconstruction, not Neyer's rule"],
  ["0.8 shrink","Setting existed but stayed inactive","Repeated Stage-2 behavior did not match"],
  ["MLE","Probit likelihood with positive sigma","Core method matched; numerical depth remains a limitation"],
  ["D-optimal point","Maximised information determinant","Core rule matched; grid and fence are engineering choices"],
  ["Rounding","Two decimal places","Reproduced Table 1 but did not describe the physical tool"],
  ["Stopping","Fixed budget, no estimate without overlap","Sound; repeated boundary clamping needed a safe pause"]];
 const t=s.tables.add({rows:values.length,columns:3,left:64,top:142,width:1152,height:480,columnTracks:[{mode:"fr",value:1.1},{mode:"fr",value:2.2},{mode:"fr",value:2.8}],values});
 styleTable(t,values.length,3,true,16); footer(s,"Original V1.8 remains unchanged and hash-matched");
}

// 4 Stage 2
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"The Stage 2 correction",4);
 textBox(s,"1.5 × sigma",78,154,330,60,{size:42,bold:true,color:C.amber});
 textBox(s,"This threshold was chosen while reconstructing Table 1. The paper uses one guessed sigma.",78,220,430,110,{size:21});
 textBox(s,"0.8",78,385,220,58,{size:48,bold:true,color:C.teal});
 textBox(s,"After each Part-2 test, multiply the working sigma by 0.8.",78,448,430,80,{size:21});
 const values=[["State","Next action","Exit condition"],["Part 1","Bisect the response bracket","Bracket width reaches 1.0 guessed sigma"],["Part 2","One-way D-optimal selection","Yes and No results strictly overlap"],["After each Part-2 test","Working sigma × 0.8","Never return to bisection"]];
 const t=s.tables.add({rows:4,columns:3,left:565,top:164,width:640,height:330,columnTracks:[{mode:"fr",value:1.1},{mode:"fr",value:1.7},{mode:"fr",value:2.2}],values}); styleTable(t,4,3,true,16);
 textBox(s,"Table 1 hid the problem because its first D-optimal test created overlap immediately.",565,530,620,72,{size:20,bold:true,color:C.navy}); footer(s);
}

// 5 Physical workflow
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"Physical gap workflow",5);
 const values=[["Gap value","Plain meaning","Use in V1.9"],["Requested","Mathematical best next point","Kept in the audit record"],["Reachable","Nearest different buildable and useful setting","Shown to the operator"],["Measured mean","Average of 4 or 5 readings on this new build","Used as the statistical gap"]];
 const t=s.tables.add({rows:4,columns:3,left:64,top:140,width:1152,height:270,columnTracks:[{mode:"fr",value:1.1},{mode:"fr",value:2.2},{mode:"fr",value:2.4}],values}); styleTable(t,4,3,true,18);
 textBox(s,"Each destructive test uses a new spacer build",64,458,680,40,{size:28,bold:true,color:C.navy});
 textBox(s,"Build the requested reachable setting. Measure the unchanged setup four or five times before testing. Enter all readings, then record Interaction or No interaction. Do not reuse the melted spacer.",64,512,1110,100,{size:22}); footer(s);
}

// 6 Increment chart
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"Equipment resolution changes Stage 2 performance",6);
 const chart=s.charts.add("line",{position:{left:72,top:145,width:820,height:455},categories:["0.01","0.05","0.10","0.25"],series:[
  {name:"True width 0.10 mm",values:[0.835,0.655,0.460,0.035],line:{fill:C.amber,width:4},marker:{symbol:"circle",size:8}},
  {name:"True width 0.20 mm",values:[0.925,0.865,0.790,0.355],line:{fill:"#B9A047",width:3},marker:{symbol:"circle",size:7}},
  {name:"True width 0.50 mm",values:[1.000,0.985,0.980,0.840],line:{fill:C.blue,width:3},marker:{symbol:"circle",size:7}},
  {name:"True width 1.00 mm",values:[0.995,0.990,0.990,0.925],line:{fill:C.teal,width:4},marker:{symbol:"circle",size:8}}],hasLegend:true,legend:{position:"bottom",overlay:false},xAxis:{title:"Physical increment (mm)",textStyle:{typeface:family,fontSize:14,color:C.muted}},yAxis:{title:"Overlap within 20 tests",min:0,max:1,majorUnit:.2,numberFormatCode:"0%",majorGridlines:{fill:C.line,width:1},textStyle:{typeface:family,fontSize:14,color:C.muted}},chartFill:C.paper,plotAreaFill:C.white});
 applyPresentationChartFont(chart,{fontFamily:family});
 textBox(s,"0.10 mm is workable when the true transition is broad. It becomes restrictive when the transition itself is near 0.10 mm.",930,188,285,210,{size:22,bold:true,color:C.navy});
 textBox(s,"32 settings × 200 paired repetitions",930,475,270,60,{size:17,color:C.muted}); footer(s,"Source: increment-study-results.csv");
}

// 7 final study chart
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"Final physical simulation: 129,600 runs",7);
 const chart=s.charts.add("bar",{position:{left:72,top:160,width:760,height:420},categories:["No floor","1 × increment","2 × increment"],series:[
  {name:"20-test budget",values:[0.9323,0.9233,0.9336],valuesFormatCode:"0.00%",fill:C.blue},
  {name:"50-test budget",values:[0.9728,0.9792,0.9964],valuesFormatCode:"0.00%",fill:C.teal}],barOptions:{direction:"column",grouping:"clustered",gapWidth:65},hasLegend:true,legend:{position:"bottom",overlay:false},yAxis:{min:.88,max:1,majorUnit:.02,numberFormatCode:"0%",majorGridlines:{fill:C.line,width:1},textStyle:{typeface:family,fontSize:14,color:C.muted}},xAxis:{textStyle:{typeface:family,fontSize:14,color:C.muted}},dataLabels:{showValue:true,position:"outEnd",textStyle:{typeface:family,fontSize:14,bold:true,color:C.ink}},chartFill:C.paper,plotAreaFill:C.white});
 applyPresentationChartFont(chart,{fontFamily:family});
 textBox(s,"2 × increment",890,170,290,46,{size:33,bold:true,color:C.teal});
 textBox(s,"Chosen as the Stage-2 working-sigma floor.",890,224,280,68,{size:21});
 textBox(s,"At 50 tests: 99.64% actual overlap, 0.00% false overlap.",890,340,280,100,{size:23,bold:true,color:C.navy});
 textBox(s,"Middle and width RMSE stayed unchanged at the displayed precision.",890,476,280,92,{size:18,color:C.muted}); footer(s,"432 settings × 300 repetitions");
}

// 8 boundaries
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"Boundaries and safe stopping",8);
 await addImage(s,"03-test-gap.png","Reachable test gap entry window",{left:690,top:155,width:500,height:380});
 textBox(s,"Default study range",70,155,500,38,{size:25,bold:true,color:C.blue});
 textBox(s,"0 mm to 10 mm",70,200,460,52,{size:38,bold:true,color:C.navy});
 textBox(s,"Unexpected result at a boundary",70,305,510,34,{size:24,bold:true,color:C.amber});
 textBox(s,"Repeat that same boundary once for confirmation.",70,348,520,62,{size:21});
 textBox(s,"Same contradiction twice",70,452,510,34,{size:24,bold:true,color:C.teal});
 textBox(s,"Pause for review and preserve the data. The software does not label the whole experiment a failure.",70,495,530,100,{size:21}); footer(s);
}

// 9 UI
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"Operator screens",9);
 await addImage(s,"01-main-menu.png","Main menu",{left:64,top:155,width:345,height:390});
 await addImage(s,"02-settings.png","Study settings",{left:455,top:155,width:345,height:390});
 await addImage(s,"05-help.png","Built-in help",{left:846,top:155,width:345,height:390});
 textBox(s,"Main menu",64,570,345,30,{size:19,bold:true,align:"center"});
 textBox(s,"Physical settings",455,570,345,30,{size:19,bold:true,align:"center"});
 textBox(s,"Operating help",846,570,345,30,{size:19,bold:true,align:"center"}); footer(s);
}

// 10 Operation
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"Running V1.9",10);
 const steps=[
  ["1","Open and run the Live Script","Neyer_Gap_Test_v1_9.mlx in MATLAB R2022b"],
  ["2","Verify the build","Run a Demo should return 5.3922 mm and 1.0412 mm"],
  ["3","Enter the study setup","Use 0–10 mm, test budget, guessed width, and confirmed increment"],
  ["4","Build and measure each new spacer","Enter four or five readings before the destructive test"],
  ["5","Record the outcome and continue","Choose Interaction or No interaction, then save the final results"]];
 const t=s.tables.add({rows:5,columns:3,left:70,top:145,width:1135,height:440,columnTracks:[{mode:"fixed",value:70},{mode:"fr",value:1.6},{mode:"fr",value:2.6}],values:steps}); styleTable(t,5,3,false,19);
 for(let r=0;r<5;r++){t.getCell(r,0).fill=r%2===0?C.blue:C.teal;t.getCell(r,0).text.style={typeface:family,fontSize:25,bold:true,color:C.white,alignment:"center"};}
 footer(s,"No executable, helper folder, addpath, internet connection, or add-on package required");
}

// 11 Saving
{
 const s=presentation.slides.add(); s.background.fill=C.paper; title(s,"Saving result data",11);
 textBox(s,"The operator chooses the folder and base name",70,146,1110,42,{size:28,bold:true,color:C.navy});
 const values=[["Output","Complete path shown before saving","Contents"],["CSV data","<selected folder>\\<chosen name>.csv","Every requested, reachable, measured, and outcome value"],["HTML result report","<selected folder>\\<chosen name>.html","Self-contained summary, estimates, and chart"]];
 const t=s.tables.add({rows:3,columns:3,left:70,top:220,width:1135,height:230,columnTracks:[{mode:"fr",value:1.1},{mode:"fr",value:2.5},{mode:"fr",value:2.5}],values}); styleTable(t,3,3,true,18);
 textBox(s,"No silent overwrite",70,500,330,38,{size:27,bold:true,color:C.amber});
 textBox(s,"If either intended file already exists, the app writes neither file and asks for a different name.",70,550,1080,68,{size:23});
 footer(s,"The selected folder remains visible in both complete paths before the user confirms");
}

// 12 Verification
{
 const s=presentation.slides.add(); s.background.fill=C.navy;
 textBox(s,"Final verification",66,48,900,56,{size:36,bold:true,color:C.white}); box(s,66,118,1148,3,C.blue);
 textBox(s,"77 / 77",72,164,330,62,{size:52,bold:true,color:C.white}); textBox(s,"MATLAB regression tests passed",72,232,430,38,{size:22,color:"#D8EAF2"});
 textBox(s,"1 file",72,330,330,62,{size:52,bold:true,color:C.white}); textBox(s,"Live Script ran alone in an empty folder",72,398,470,60,{size:22,color:"#D8EAF2"});
 textBox(s,"5.3922 / 1.0412",645,164,500,62,{size:45,bold:true,color:C.white}); textBox(s,"Embedded demo result",645,232,430,38,{size:22,color:"#D8EAF2"});
 textBox(s,"V1.8 preserved",645,330,430,62,{size:40,bold:true,color:C.white}); textBox(s,"Original and audit copy hashes remain identical",645,398,500,60,{size:22,color:"#D8EAF2"});
 box(s,72,520,1130,7,C.amber);
 textBox(s,"Final package folder",72,555,300,30,{size:18,bold:true,color:"#D8EAF2"}); textBox(s,"OneDrive\\CHATGPT-Neyer\\",72,594,1050,38,{size:25,bold:true,color:C.white});
 textBox(s,"Operator decision still required: confirm whether the real increment is 0.05 mm or 0.10 mm.",72,650,1110,28,{size:16,color:"#F2D49D"});
}

const stagingDir=path.join(workspaceDir,".codex-finalizer-v19");
await fs.mkdir(stagingDir,{recursive:true});
const candidatePath=path.join(stagingDir,"candidate-v19.pptx");
await (await PresentationFile.exportPptx(presentation)).save(candidatePath);

const result=await finalizePresentation({
  explicitTotalSlideCount:12,
  requiredNativeTableOwnerSlides:[3,4,5,10,11],
  requiredNativeChartOwnerSlides:[6,7],
  materializeLiteralChartWorkbooks:true,
  nativeChartTargetApplication:"powerpoint",
  workspaceDir,
  candidatePath,
  finalPath:FINAL_PPTX,
  pythonExecutable:RUNTIME_PYTHON,
  integrityValidatorPath:path.join(SKILL_DIR,"container_tools/inspect_presentation_package_integrity.py"),
  layoutValidatorPath:path.join(SKILL_DIR,"container_tools/inspect_presentation_layout_geometry.py"),
  layoutArgs:["--expected-slide-size-emu","12192000,6858000","--validate-heading-fit","--require-native-table-slide","3","--require-native-table-slide","4","--require-native-table-slide","5","--require-native-table-slide","10","--require-native-table-slide","11"],
  fontPolicy:{basis:"design",families:[family]},
  verifyArtifactToolImport:true,
  receiptPath:path.join(stagingDir,"Neyer_Gap_Test_v1_9_Presentation_r4.validation.json")
});

for(let i=0;i<presentation.slides.items.length;i++){
  const slide=presentation.slides.items[i];
  const preview=await presentation.export({slide,format:"png",scale:1});
  await fs.writeFile(path.join(TMP_DIR,`slide-${String(i+1).padStart(2,"0")}.png`),new Uint8Array(await preview.arrayBuffer()));
  const layout=await slide.export({format:"layout"});
  await fs.writeFile(path.join(TMP_DIR,`slide-${String(i+1).padStart(2,"0")}.layout.json`),await layout.text());
}
const montage=await presentation.export({format:"webp",montage:true,scale:1});
await fs.writeFile(path.join(TMP_DIR,"montage.webp"),new Uint8Array(await montage.arrayBuffer()));
console.log(JSON.stringify({finalPath:FINAL_PPTX,slides:presentation.slides.items.length,validation:result},null,2));
