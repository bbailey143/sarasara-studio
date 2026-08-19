'use strict';

global.window={};
global.document={createElement(){return{width:0,height:0,getContext(){return{createImageData(w,h){return{data:new Uint8ClampedArray(w*h*4)}},putImageData(){}}}}}};
require('./shared-solver.js');

const {SharedSolver,PROFILES,SUBSTRATES}=window.SarasaraLab;
const assert=(condition,message)=>{if(!condition)throw new Error(message)};

assert(PROFILES.watercolor.state['SUBI-001']===undefined&&PROFILES.charcoal.state['SUBI-001']===undefined,'material profiles must not own intrinsic paper roughness');
assert(SUBSTRATES.rough.texture.tooth===.85&&SUBSTRATES.coldPress.texture.capacity===.5,'archived paper seed values must remain traceable');
assert(SUBSTRATES.rough.version==='0.2.0','corrected paper scale must remain versioned for artist review history');

const plainTexture=new SharedSolver(48,24,PROFILES.charcoal,SUBSTRATES.plain),roughTexture=new SharedSolver(48,24,PROFILES.charcoal,SUBSTRATES.rough);
const pastelTexture=new SharedSolver(48,24,PROFILES.charcoal,SUBSTRATES.pastelWhite),creamTexture=new SharedSolver(48,24,PROFILES.charcoal,SUBSTRATES.pastelCream);let plainMin=1,plainMax=0,roughMin=1,roughMax=0,pastelMin=1,pastelMax=0;for(let y=0;y<24;y++)for(let x=0;x<48;x++){const p=plainTexture.tooth(x,y),r=roughTexture.tooth(x,y),f=pastelTexture.tooth(x,y);plainMin=Math.min(plainMin,p);plainMax=Math.max(plainMax,p);roughMin=Math.min(roughMin,r);roughMax=Math.max(roughMax,r);pastelMin=Math.min(pastelMin,f);pastelMax=Math.max(pastelMax,f);assert(Math.abs(f-creamTexture.tooth(x,y))<.000001,'pastel paper color variants must share identical physical tooth')}
assert(plainMax-plainMin<.0001,'plain paper must have a flat contact surface');
assert(roughMax-roughMin>.35,'rough paper must expose meaningful peaks and valleys');
assert(pastelMax-pastelMin<(roughMax-roughMin)*.45,'sample-guided pastel paper must have much shallower relief than rough watercolor paper');
const toothCrossings=substrate=>{const solver=new SharedSolver(300,130,PROFILES.charcoal,substrate);let crossings=0,last=solver.tooth(0,65)-.5;for(let x=1;x<300;x++){const value=solver.tooth(x,65)-.5;if(value*last<0)crossings++;if(value!==0)last=value}return crossings};
const hotCrossings=toothCrossings(SUBSTRATES.hotPress),roughCrossings=toothCrossings(SUBSTRATES.rough);
assert(roughCrossings>=25,'rough paper must use fine tooth rather than a few zoomed-in terrain ridges');
assert(roughCrossings>hotCrossings*2,'the archived inverse grain scale must make Rough finer-grained than Hot Press');
assert(toothCrossings(SUBSTRATES.pastelWhite)>roughCrossings,'sample-guided pastel paper must use smaller, more frequent grain than rough watercolor paper');

const roughLight=new SharedSolver(48,24,PROFILES.charcoal,SUBSTRATES.rough),roughFirm=new SharedSolver(48,24,PROFILES.charcoal,SUBSTRATES.rough);
for(let y=5;y<60;y+=5){roughLight.depositSegment(5,y,115,y,120,60,.2,.8,0,1.25);roughFirm.depositSegment(5,y,115,y,120,60,.85,.8,0,1.25)}
assert(roughFirm.metrics().deposited_pigment>roughLight.metrics().deposited_pigment,'firmer contact must reach and load more of a rough paper surface');
const toothBandAverage=(solver,min,max)=>{let mass=0,cells=0;for(let i=0;i<solver.n;i++){const tooth=solver.tooth(i%solver.w,Math.floor(i/solver.w));if(tooth>=min&&tooth<max){mass+=solver.deposited[i];cells++}}return cells?mass/cells:0};
const lightPeak=toothBandAverage(roughLight,.62,1.01),lightValley=toothBandAverage(roughLight,0,.38),firmValley=toothBandAverage(roughFirm,0,.38);
assert(lightPeak>lightValley,'light charcoal contact must favor raised rough-paper tooth over valleys');
assert(firmValley>lightValley,'greater pressure must progressively increase charcoal captured in rough-paper valleys (light '+lightValley+', firm '+firmValley+')');

const pastelLight=new SharedSolver(48,24,PROFILES.charcoal,SUBSTRATES.pastelWhite),pastelFirm=new SharedSolver(48,24,PROFILES.charcoal,SUBSTRATES.pastelWhite);for(let y=0;y<24;y+=2){pastelLight.depositSegment(0,y,48,y,48,24,.2,.8,0,.8);pastelFirm.depositSegment(0,y,48,y,48,24,.85,.8,0,.8)}
const pastelLightPeak=toothBandAverage(pastelLight,.515,1.01),pastelLightValley=toothBandAverage(pastelLight,0,.485),pastelFirmValley=toothBandAverage(pastelFirm,0,.485);
assert(pastelLightPeak>pastelLightValley,'light charcoal must still favor the small raised fibers of pastel paper');
assert(pastelFirmValley>pastelLightValley,'firm charcoal must reach more shallow valleys on pastel paper');

const hotUptake=new SharedSolver(48,24,PROFILES.watercolor,SUBSTRATES.hotPress),roughUptake=new SharedSolver(48,24,PROFILES.watercolor,SUBSTRATES.rough);
hotUptake.depositSegment(30,30,90,30,120,60,.55,.7,.7,.8);roughUptake.depositSegment(30,30,90,30,120,60,.55,.7,.7,.8);for(let i=0;i<120;i++){hotUptake.step(1/60);roughUptake.step(1/60)}
assert(roughUptake.metrics().absorbed_water>hotUptake.metrics().absorbed_water,'rough archived paper must take up more carrier than hot press under a matched wet gesture');

const wet=new SharedSolver(48,24,PROFILES.watercolor);
wet.clear(.3);
wet.depositSegment(20,40,80,40,120,60,.6,.7,.85,.5);
const wetBefore=wet.metrics();
wet.setDisplayGain(8);
const wetAfterDisplayChange=wet.metrics();
assert(JSON.stringify(wetBefore)===JSON.stringify(wetAfterDisplayChange),'diagnostic visibility must not alter physical state');
for(let i=0;i<180;i++)wet.step(1/60);
const wetAfter=wet.metrics();
assert(wetBefore.water>0,'watercolor must deposit carrier');
assert(wetAfter.water<wetBefore.water,'watercolor carrier must evaporate or absorb');
assert(wetAfter.deposited_pigment>0,'mobile watercolor pigment must settle');
assert(wetAfter.pigment_area_fraction>wetBefore.pigment_area_fraction,'water flux must expand the visible pigment region');
assert(wetAfter.pigment_conservation_error<.01,'pigment transport must remain conservative');

const cleanWater=new SharedSolver(48,24,PROFILES.watercolor);
cleanWater.depositSegment(20,40,80,40,120,60,.6,0,1,.5);
const cleanWaterState=cleanWater.metrics();
assert(cleanWaterState.water>0,'clean-water gesture must deposit carrier');
assert(cleanWaterState.mobile_pigment===0&&cleanWaterState.deposited_pigment===0,'clean-water gesture must not invent pigment');

const dryBrush=new SharedSolver(48,24,PROFILES.watercolor),dampBrush=new SharedSolver(48,24,PROFILES.watercolor),wetBrush=new SharedSolver(48,24,PROFILES.watercolor);
dryBrush.depositSegment(20,30,100,30,120,60,.55,1,0,1);
dampBrush.depositSegment(20,30,100,30,120,60,.55,1,.35,1);
wetBrush.depositSegment(20,30,100,30,120,60,.55,1,1,1);
const dryBrushState=dryBrush.metrics(),dampBrushState=dampBrush.metrics(),wetBrushState=wetBrush.metrics();
assert(dryBrushState.water===0,'zero brush water on dry paper must not add hidden carrier');
assert(dryBrushState.mobile_pigment===0&&dryBrushState.deposited_pigment>0,'dry watercolor contact must deposit pigment directly onto paper tooth');
assert(dryBrushState.pigment_area_fraction<wetBrushState.pigment_area_fraction,'dry watercolor must skip more paper than a wet wash');
assert(dampBrushState.mobile_pigment>dryBrushState.mobile_pigment&&wetBrushState.mobile_pigment>dampBrushState.mobile_pigment,'pigment mobility must increase continuously with brush moisture');

const lightDryBrush=new SharedSolver(48,24,PROFILES.watercolor),heavyDryBrush=new SharedSolver(48,24,PROFILES.watercolor);
lightDryBrush.depositSegment(20,30,100,30,120,60,.2,1,0,1);
heavyDryBrush.depositSegment(20,30,100,30,120,60,.9,1,0,1);
assert(heavyDryBrush.metrics().deposited_pigment>lightDryBrush.metrics().deposited_pigment,'pressure must increase dry-brush contact and deposition');

const prewet=new SharedSolver(48,24,PROFILES.watercolor);
prewet.clear(.8);
assert(prewet.metrics().wet_area_fraction===1,'paper dampness must prepare the full substrate');
assert(prewet.metrics().water===0&&prewet.metrics().absorbed_water>0,'paper dampness must initialize paper-held moisture rather than a surface puddle');

const lowWater=new SharedSolver(48,24,PROFILES.watercolor),highWater=new SharedSolver(48,24,PROFILES.watercolor);
lowWater.depositSegment(50,30,70,30,120,60,.5,.6,.1,.5);
highWater.depositSegment(50,30,70,30,120,60,.5,.6,1,.5);
for(let i=0;i<90;i++){lowWater.step(1/60);highWater.step(1/60)}
assert(highWater.metrics().wet_area_fraction>lowWater.metrics().wet_area_fraction,'more brush water must create a larger wet region');

const dampStroke=new SharedSolver(48,24,PROFILES.watercolor),washStroke=new SharedSolver(48,24,PROFILES.watercolor);
dampStroke.depositSegment(35,30,85,30,120,60,.55,1,.35,1);
washStroke.depositSegment(35,30,85,30,120,60,.55,1,1,1);
const dampSurfaceBefore=dampStroke.metrics().water,dampPaperBefore=dampStroke.metrics().absorbed_water;
for(let i=0;i<120;i++){dampStroke.step(1/60);washStroke.step(1/60)}
const dampResult=dampStroke.metrics(),washResult=washStroke.metrics();
assert(dampResult.water<dampSurfaceBefore&&dampResult.absorbed_water>dampPaperBefore,'paper must take up surface carrier during a damp stroke');
assert(dampResult.pigment_area_fraction<washResult.pigment_area_fraction,'a damp stroke must remain more concentrated than a fully wet wash');
assert(dampResult.deposited_pigment>0,'paper contact must retain some damp-stroke pigment');

const quarterLoad=new SharedSolver(48,24,PROFILES.watercolor),fullLoad=new SharedSolver(48,24,PROFILES.watercolor);
quarterLoad.depositSegment(20,30,100,30,120,60,.55,.25,1,1);
fullLoad.depositSegment(20,30,100,30,120,60,.55,1,1,1);
const quarterState=quarterLoad.metrics(),fullState=fullLoad.metrics();
assert(Math.abs(fullState.water-quarterState.water)<.0001,'pigment-load calibration must not change carrier delivery');
assert(fullState.mobile_pigment>quarterState.mobile_pigment*3.9,'full pigment load must deliver about four times quarter load');

const rewet=new SharedSolver(48,24,PROFILES.watercolor);
rewet.depositSegment(35,30,85,30,120,60,.5,.8,.25,.5);
rewet.dry();for(let i=0;i<240;i++)rewet.step(1/60);
const settled=rewet.metrics(),pigmentBeforeWater=rewet.initialPigment;
rewet.depositSegment(35,30,85,30,120,60,.5,0,1,.5);
for(let i=0;i<30;i++)rewet.step(1/60);
const reactivated=rewet.metrics();
assert(reactivated.mobile_pigment>settled.mobile_pigment,'clean water must remobilize settled watercolor pigment');
assert(rewet.initialPigment===pigmentBeforeWater,'clean water must not add pigment mass');
assert(reactivated.pigment_conservation_error<.01,'clean-water reactivation must conserve pigment');

const dry=new SharedSolver(48,24,PROFILES.charcoal);
dry.depositSegment(20,40,80,40,120,60,.7,.5,0,1.3);
const dryState=dry.metrics();
assert(dryState.water===0,'charcoal profile must not deposit carrier');
assert(dryState.deposited_pigment>0,'charcoal profile must deposit dry particles');
assert(dryState.pigment_conservation_error<.01,'charcoal deposition must remain conservative');

const surfaceInRect=(solver,x0,y0,x1,y1)=>{let total=0;for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++){const i=y*solver.w+x;total+=solver.deposited[i]+solver.loose[i]}return total};
const looseCentroidX=solver=>{let mass=0,moment=0;for(let i=0;i<solver.n;i++){mass+=solver.loose[i];moment+=(i%solver.w)*solver.loose[i]}return mass?moment/mass:0};
const smudged=new SharedSolver(120,60,PROFILES.charcoal,SUBSTRATES.pastelWhite);
smudged.depositSegment(40,15,40,45,120,60,.75,.9,0,.8);
const sourceBefore=surfaceInRect(smudged,35,10,43,50),destinationBefore=surfaceInRect(smudged,43,10,53,50),initialBeforeSmudge=smudged.initialPigment,totalBeforeSmudge=smudged.metrics().deposited_pigment;
const moved=smudged.smudgeSegment(35,30,68,30,120,60,.65,1);
const sourceAfter=surfaceInRect(smudged,35,10,43,50),destinationAfter=surfaceInRect(smudged,43,10,53,50),smudgedState=smudged.metrics(),looseImmediately=smudgedState.loose_pigment,settledImmediately=smudgedState.deposited_pigment,centroidImmediately=looseCentroidX(smudged);
assert(moved>0&&smudgedState.relocated_pigment>0,'smudge contact must relocate existing deposited pigment');
assert(sourceAfter<sourceBefore,'smudge contact must reduce surface pigment in the source region');
assert(destinationAfter>destinationBefore,'smudge contact must increase surface pigment in the destination region');
assert(looseImmediately>0,'smudge contact must create a transient loose-particle ridge');
assert(smudged.initialPigment===initialBeforeSmudge,'smudging must not add pigment to the material ledger');
assert(Math.abs(smudgedState.deposited_pigment+smudgedState.loose_pigment-totalBeforeSmudge)<.0001,'smudging must conserve settled plus loose surface pigment');
assert(smudgedState.pigment_conservation_error<.01,'smudge transport must remain conservative');
for(let i=0;i<30;i++)smudged.step(1/60);
const movingState=smudged.metrics(),centroidAfterCoast=looseCentroidX(smudged);
assert(centroidAfterCoast>centroidImmediately,'loose particles must continue briefly in the contact direction after contact stops');
for(let i=0;i<240;i++)smudged.step(1/60);
const settledState=smudged.metrics();
assert(settledState.loose_pigment<looseImmediately*.2,'loose particles must lose energy and settle rather than slide forever');
assert(settledState.deposited_pigment>settledImmediately,'settling must return loose particles to the deposited state');
assert(settledState.pigment_conservation_error<.01,'post-contact motion and settling must conserve pigment');

const smudgeMovedAtPressure=pressure=>{const solver=new SharedSolver(120,60,PROFILES.charcoal,SUBSTRATES.pastelWhite);solver.depositSegment(40,15,40,45,120,60,.75,.9,0,.8);return solver.smudgeSegment(35,30,68,30,120,60,pressure,.8)};
assert(smudgeMovedAtPressure(.75)>smudgeMovedAtPressure(.25),'firmer smudge contact must relocate more existing pigment than light contact');

const blankSmudge=new SharedSolver(120,60,PROFILES.charcoal,SUBSTRATES.pastelWhite);
blankSmudge.smudgeSegment(20,30,90,30,120,60,.8,1.2);
const blankSmudgeState=blankSmudge.metrics();
assert(blankSmudgeState.deposited_pigment===0&&blankSmudgeState.loose_pigment===0&&blankSmudgeState.relocated_pigment===0,'smudging blank paper must not create pigment');

console.log('shared solver checks passed');
