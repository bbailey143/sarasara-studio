'use strict';

global.window={};
global.document={createElement(){return{width:0,height:0,getContext(){return{createImageData(w,h){return{data:new Uint8ClampedArray(w*h*4)}},putImageData(){}}}}}};
require('./shared-solver.js');

const {SharedSolver,PROFILES,SUBSTRATES,BRUSHES,DEFAULT_CALIBRATION,validateCalibration,interpolatePressure}=window.SarasaraLab;
const assert=(condition,message)=>{if(!condition)throw new Error(message)};

assert(PROFILES.charcoal.id==='material.charcoal.diagnostic.v0.6','the loose-grain target must remain versioned for artist review history');
assert(PROFILES.watercolor.state['SUBI-001']===undefined&&PROFILES.charcoal.state['SUBI-001']===undefined,'material profiles must not own intrinsic paper roughness');
assert(SUBSTRATES.rough.texture.tooth===.85&&SUBSTRATES.coldPress.texture.capacity===.5,'archived paper seed values must remain traceable');
assert(SUBSTRATES.rough.version==='0.2.0','corrected paper scale must remain versioned for artist review history');

const defaultCalibrationSolver=new SharedSolver(24,12,PROFILES.charcoal,SUBSTRATES.pastelWhite);
for(const pressure of [0,.1,.33,.5,.67,.9,1])assert(Math.abs(defaultCalibrationSolver.transformPressure(pressure)-pressure)<.000001,'the default linear calibration must preserve input pressure at '+pressure);
const curvedCalibration=validateCalibration({curve:[{x:0,y:0},{x:.33,y:.16},{x:.67,y:.84},{x:1,y:1}],paperTexture:1,particleBreakup:1,smear:1,speed:1});
let previous=-1;for(let index=0;index<=100;index++){const value=interpolatePressure(curvedCalibration.curve,index/100);assert(value>=previous-.000001,'pressure curve interpolation must remain monotonic');previous=value}
assert(interpolatePressure(curvedCalibration.curve,0)===0&&interpolatePressure(curvedCalibration.curve,1)===1,'pressure curve endpoints must remain exactly zero and one');
assert(JSON.parse(JSON.stringify(curvedCalibration)).curve.length===4,'artist calibration must be JSON serializable');
assert(!/watercolor|charcoal/i.test(validateCalibration.toString()+interpolatePressure.toString()+SharedSolver.prototype.setCalibration.toString()+SharedSolver.prototype.transformPressure.toString()),'shared pressure calibration must not branch on a named medium');

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

const calibratedDraw=(name,value)=>{const solver=new SharedSolver(72,36,PROFILES.charcoal,SUBSTRATES.pastelWhite),config=solver.getCalibration();config[name]=value;solver.setCalibration(config);for(let y=4;y<34;y+=4)solver.depositSegment(4,y,68,y,72,36,.62,.8,0,1.4);return solver};
const lowTextureCalibration=calibratedDraw('paperTexture',0),highTextureCalibration=calibratedDraw('paperTexture',2);
assert(highTextureCalibration.metrics().deposited_pigment>lowTextureCalibration.metrics().deposited_pigment,'greater paper-texture influence must let pressure reach more paper tooth');
const lowBreakupCalibration=calibratedDraw('particleBreakup',0),highBreakupCalibration=calibratedDraw('particleBreakup',2),particleMass=solver=>solver.metrics().coarse_fragment_created+solver.metrics().fine_dust_created;
assert(particleMass(highBreakupCalibration)>particleMass(lowBreakupCalibration),'greater particle-breakup influence must create more conserved fragments and dust');
const lowSpeedCalibration=calibratedDraw('speed',0),highSpeedCalibration=calibratedDraw('speed',2);
assert(particleMass(highSpeedCalibration)>particleMass(lowSpeedCalibration),'greater speed influence must strengthen gesture-speed breakup');

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

const grainScene=passes=>{const solver=new SharedSolver(120,60,PROFILES.charcoal,SUBSTRATES.pastelWhite);for(let i=0;i<passes;i++)solver.depositSegment(20,30,100,30,120,60,.55,.7,0,.8);return solver};
const singleGrain=grainScene(1),layeredGrain=grainScene(3),singleGrainState=singleGrain.metrics(),layeredGrainState=layeredGrain.metrics();let contacted=0,marked=0;for(let y=26;y<=34;y++)for(let x=20;x<=100;x++){contacted++;const i=y*singleGrain.w+x;if(singleGrain.deposited[i]+singleGrain.coarse[i]+singleGrain.fineDust[i]>.000001)marked++}
assert(JSON.stringify(Array.from(singleGrain.deposited))===JSON.stringify(Array.from(grainScene(1).deposited)),'identical granular contact must reproduce the same broken mark');
assert(!/watercolor|charcoal/i.test(SharedSolver.prototype.addDisk.toString()),'granular dry contact must not branch on a named medium');
assert(marked>contacted*.2&&marked<contacted*.82,'one loose-charcoal layer must remain materially grainy with both captured particles and visible paper gaps');
assert(layeredGrainState.deposited_pigment>singleGrainState.deposited_pigment*2.9,'repeated charcoal layers must accumulate real deposited mass rather than use a display-only darkening effect');
assert(Math.abs(layeredGrainState.pigment_area_fraction-singleGrainState.pigment_area_fraction)<.01,'matched repeated layers should deepen the same granular structure rather than inflate into a flat wider ribbon');
assert(singleGrainState.pigment_conservation_error<.01&&layeredGrainState.pigment_conservation_error<.01,'granular transfer and repeated layers must conserve pigment');
const renderTarget={save(){},clearRect(){},drawImage(){},restore(){}};singleGrain.render(renderTarget,{width:120,height:60});layeredGrain.render(renderTarget,{width:120,height:60});const strokeLuminance=solver=>{let total=0,cells=0;for(let y=26;y<=34;y++)for(let x=20;x<=100;x++){const j=(y*solver.w+x)*4;total+=(solver.image.data[j]+solver.image.data[j+1]+solver.image.data[j+2])/3;cells++}return total/cells};
assert(strokeLuminance(layeredGrain)<strokeLuminance(singleGrain)-5,'multiple charcoal layers must become visibly darker while retaining the same granular footprint');

const surfaceInRect=(solver,x0,y0,x1,y1)=>{let total=0;for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++){const i=y*solver.w+x;total+=solver.deposited[i]+solver.loose[i]+solver.coarse[i]+solver.fineDust[i]}return total};
const depositedInRect=(solver,x0,y0,x1,y1)=>{let total=0;for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++)total+=solver.deposited[y*solver.w+x];return total};
const looseCentroidX=solver=>{let mass=0,moment=0;for(let i=0;i<solver.n;i++){mass+=solver.loose[i];moment+=(i%solver.w)*solver.loose[i]}return mass?moment/mass:0};
const populationCentroidX=(solver,population)=>{let mass=0,moment=0;for(let i=0;i<solver.n;i++){mass+=population[i];moment+=(i%solver.w)*population[i]}return mass?moment/mass:0};
const pigmentLedger=state=>state.mobile_pigment+state.deposited_pigment+state.loose_pigment+state.coarse_fragment_pigment+state.fine_dust_pigment+state.lost_off_canvas_pigment;

const fractureScene=(load,pressure,speed)=>{const solver=new SharedSolver(120,60,PROFILES.charcoal,SUBSTRATES.pastelWhite);solver.depositSegment(25,30,65,30,120,60,pressure,load,0,speed);return solver};
const createdParticles=solver=>{const state=solver.metrics();return state.coarse_fragment_created+state.fine_dust_created};
const lowFracture=fractureScene(.25,.2,.25),highFracture=fractureScene(1,.9,1.8),lowFractureState=lowFracture.metrics(),highFractureState=highFracture.metrics();
assert(highFractureState.coarse_fragment_created>lowFractureState.coarse_fragment_created,'greater loading, pressure, and speed must create more coarse fragments');
assert(highFractureState.fine_dust_created>lowFractureState.fine_dust_created,'greater loading, pressure, and speed must create more fine dust');
assert(createdParticles(fractureScene(1,.65,1))>createdParticles(fractureScene(.25,.65,1))*3.9,'greater loading alone must proportionally increase physically sourced breakup');
assert(createdParticles(fractureScene(.8,.9,1))>createdParticles(fractureScene(.8,.2,1)),'greater pressure alone must increase breakup');
assert(createdParticles(fractureScene(.8,.65,1.8))>createdParticles(fractureScene(.8,.65,.25)),'greater tangential speed alone must increase breakup');
assert(highFractureState.source_offered_pigment>highFractureState.source_remaining_pigment,'a dry draw must transfer only part of the pigment offered by the applicator');
assert(Math.abs(highFractureState.source_offered_pigment-highFractureState.source_remaining_pigment-highFracture.initialPigment)<.0001,'offered dry pigment must equal remaining source plus transferred pigment');
assert(Math.abs(pigmentLedger(highFractureState)-highFracture.initialPigment)<.0001&&highFractureState.pigment_conservation_error<.01,'settled, loose, coarse, fine, and lost pigment must close the transferred-mass ledger');

const travelScene=fractureScene(1,.9,1.8),coarseStart=travelScene.metrics().coarse_fragment_pigment,fineStart=travelScene.metrics().fine_dust_pigment;for(let i=0;i<45;i++)travelScene.step(1/60);const coarseX=populationCentroidX(travelScene,travelScene.coarse),fineX=populationCentroidX(travelScene,travelScene.fineDust),travelState=travelScene.metrics();
assert(fineX>coarseX,'fine dust must travel farther along the gesture than coarse fragments');
assert(travelState.coarse_fragment_pigment/coarseStart<travelState.fine_dust_pigment/fineStart,'coarse fragments must settle faster than fine dust');
for(let i=0;i<240;i++)travelScene.step(1/60);const postSettleState=travelScene.metrics();
assert(postSettleState.coarse_fragment_pigment<travelState.coarse_fragment_pigment&&postSettleState.fine_dust_pigment<travelState.fine_dust_pigment,'both detached populations must settle after contact');
assert(postSettleState.pigment_conservation_error<.01,'detached-particle travel and settling must conserve pigment including off-canvas loss');

const deterministicA=fractureScene(.8,.72,1.35),deterministicB=fractureScene(.8,.72,1.35);for(let i=0;i<75;i++){deterministicA.step(1/60);deterministicB.step(1/60)}
assert(JSON.stringify(deterministicA.metrics())===JSON.stringify(deterministicB.metrics())&&JSON.stringify(Array.from(deterministicA.fineDust))===JSON.stringify(Array.from(deterministicB.fineDust)),'identical fracture commands must reproduce identical particle state');

const fineTravelAtFriction=friction=>{const profile=JSON.parse(JSON.stringify(PROFILES.charcoal));profile.state['TRIB-002']=friction;const solver=new SharedSolver(120,60,profile,SUBSTRATES.pastelWhite);solver.depositSegment(25,30,65,30,120,60,.85,1,0,1.6);const start=populationCentroidX(solver,solver.fineDust);for(let i=0;i<60;i++)solver.step(1/60);return populationCentroidX(solver,solver.fineDust)-start};
assert(fineTravelAtFriction(.85)<fineTravelAtFriction(.15),'greater shared surface friction must visibly shorten fine-dust travel');

const nonBrittleDryProfile=JSON.parse(JSON.stringify(PROFILES.charcoal));delete nonBrittleDryProfile.state['TRIB-003'];delete nonBrittleDryProfile.state['PART-001'];const nonBrittleDry=new SharedSolver(120,60,nonBrittleDryProfile,SUBSTRATES.pastelWhite);nonBrittleDry.depositSegment(25,30,65,30,120,60,.9,1,0,1.8);const nonBrittleState=nonBrittleDry.metrics();
assert(nonBrittleState.coarse_fragment_created===0&&nonBrittleState.fine_dust_created===0,'a profile without a brittle particulate source must not create fragments or dust');
assert(!/watercolor|charcoal/i.test(SharedSolver.prototype.fractureSplit.toString()+SharedSolver.prototype.stepDetachedPopulation.toString()),'fracture and dusting must not branch on a named medium');
const smudged=new SharedSolver(120,60,PROFILES.charcoal,SUBSTRATES.pastelWhite);
smudged.depositSegment(40,15,40,45,120,60,.75,.9,0,.8);
const sourceBefore=surfaceInRect(smudged,35,10,43,50),destinationBefore=surfaceInRect(smudged,43,10,53,50),initialBeforeSmudge=smudged.initialPigment,totalBeforeSmudge=pigmentLedger(smudged.metrics());
const moved=smudged.smudgeSegment(35,30,68,30,120,60,.65,1);
const sourceAfter=surfaceInRect(smudged,35,10,43,50),destinationAfter=surfaceInRect(smudged,43,10,53,50),smudgedState=smudged.metrics(),looseImmediately=smudgedState.loose_pigment,settledImmediately=smudgedState.deposited_pigment,centroidImmediately=looseCentroidX(smudged);
assert(moved>0&&smudgedState.relocated_pigment>0,'smudge contact must relocate existing deposited pigment');
assert(sourceAfter<sourceBefore,'smudge contact must reduce surface pigment in the source region');
assert(destinationAfter>destinationBefore,'smudge contact must increase surface pigment in the destination region');
assert(looseImmediately>0,'smudge contact must create a transient loose-particle ridge');
assert(smudged.initialPigment===initialBeforeSmudge,'smudging must not add pigment to the material ledger');
assert(Math.abs(pigmentLedger(smudgedState)-totalBeforeSmudge)<.0001,'smudging must conserve settled, loose, coarse, fine, and lost pigment');
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
const smudgeAtInfluence=value=>{const solver=new SharedSolver(120,60,PROFILES.charcoal,SUBSTRATES.pastelWhite),config=solver.getCalibration();solver.depositSegment(40,15,40,45,120,60,.75,.9,0,.8);config.smear=value;solver.setCalibration(config);return{moved:solver.smudgeSegment(35,30,68,30,120,60,.72,1.2),state:solver.metrics()}};
const lowSmearInfluence=smudgeAtInfluence(0),highSmearInfluence=smudgeAtInfluence(2);
assert(highSmearInfluence.moved>lowSmearInfluence.moved,'greater smear influence must relocate more existing material');
assert(highSmearInfluence.state.pigment_conservation_error<.01,'artist-controlled smear influence must preserve pigment conservation');

const pressureSmearScene=pressure=>{const solver=new SharedSolver(120,60,PROFILES.charcoal,SUBSTRATES.pastelWhite);solver.depositSegment(40,15,40,45,120,60,.75,.9,0,.8);const before=depositedInRect(solver,44,25,65,36);solver.smudgeSegment(35,30,68,30,120,60,pressure,1.6);return{solver,before,after:depositedInRect(solver,44,25,65,36)}};
const moderateSmear=pressureSmearScene(.55),strongSmear=pressureSmearScene(.85);
assert(strongSmear.after-strongSmear.before>moderateSmear.after-moderateSmear.before,'strong pressure must anchor more relocated pigment into a deposited smear than the accepted moderate smudge');
assert(strongSmear.after>strongSmear.before,'strong smudging must leave pressed pigment in the contacted paper trail instead of moving every particle as loose dust');
assert(moderateSmear.solver.metrics().pressure_anchored_pigment===0,'the carried-forward high-load correction must preserve the accepted pressure-0.55 smudge path');
assert(strongSmear.solver.metrics().pressure_anchored_pigment>moderateSmear.solver.metrics().pressure_anchored_pigment,'the pressure-anchoring ledger must distinguish strong contact from the accepted moderate reference');
assert(strongSmear.solver.metrics().loose_pigment>0,'strong pressure anchoring must coexist with loose dusty movement rather than turn the whole smudge into putty');
assert(strongSmear.solver.metrics().pigment_conservation_error<.01,'strong pressure anchoring must conserve the full pigment ledger');
assert(!/watercolor|charcoal/i.test(SharedSolver.prototype.smudgeSegment.toString()),'smudge pressure anchoring must not branch on a named medium');

const blankSmudge=new SharedSolver(120,60,PROFILES.charcoal,SUBSTRATES.pastelWhite);
blankSmudge.smudgeSegment(20,30,90,30,120,60,.8,1.2);
const blankSmudgeState=blankSmudge.metrics();
assert(blankSmudgeState.deposited_pigment===0&&blankSmudgeState.loose_pigment===0&&blankSmudgeState.coarse_fragment_pigment===0&&blankSmudgeState.fine_dust_pigment===0&&blankSmudgeState.relocated_pigment===0,'smudging blank paper must not create pigment or detached particles');

/* ---- ADR-0002: shared deposited layer + oil as the third recipe ---- */

assert(PROFILES.oil && PROFILES.oil.id === 'material.oil.diagnostic.v0.1', 'the oil recipe must remain versioned for artist review history');
assert(PROFILES.oil.state['SUBI-001'] === undefined && PROFILES.oil.state['SUBI-003'] === undefined, 'the oil recipe must not own intrinsic paper properties');
assert(PROFILES.oil.state['TRAN-001'] === 0, 'oil pigment must never diffuse on its own');

// every property oil uses must already exist in the canonical vocabulary
const CANONICAL = new Set(['COMP-001','COMP-002','COMP-003','COMP-004','STATE-001','STATE-002','STATE-003','STATE-004','RHEO-001','RHEO-002','RHEO-003','RHEO-004','TRIB-001','TRIB-002','TRIB-003','TRIB-004','PART-001','PART-002','PART-003','PART-004','INTF-001','INTF-002','INTF-003','INTF-004','TRAN-001','TRAN-002','TRAN-003','TRAN-004','DEPO-001','DEPO-002','DEPO-003','DEPO-004','DEPO-005','SUBI-001','SUBI-002','SUBI-003','SUBI-004','EVOL-001','EVOL-002','EVOL-003','EVOL-004','REAC-001','REAC-002','REAC-003','REAC-004','OPT-001','OPT-002','OPT-003','OPT-004']);
for (const id of Object.keys(PROFILES.oil.state)) assert(CANONICAL.has(id), 'oil introduced a property outside the canonical vocabulary: ' + id);

// the regime is chosen by physical properties, never by a material name
const oilSolver = new SharedSolver(40, 40, PROFILES.oil, SUBSTRATES.coldPress);
const wcSolver = new SharedSolver(40, 40, PROFILES.watercolor, SUBSTRATES.coldPress);
const chSolver = new SharedSolver(40, 40, PROFILES.charcoal, SUBSTRATES.pastelWhite);
assert(oilSolver.regime() === 'body', 'a material with a yield stress must select the body regime');
assert(wcSolver.regime() === 'flowing', 'watercolor must still select the flowing regime');
assert(chSolver.regime() === 'granular', 'charcoal must still select the granular regime');
assert(!/watercolor|charcoal|oil(?![A-Za-z])/i.test(
  SharedSolver.prototype.regime.toString() +
  SharedSolver.prototype.flowLayer.toString() +
  SharedSolver.prototype.smearBody.toString() +
  SharedSolver.prototype.reliefHeight.toString()
), 'the shared layer must not branch on a named medium');

// REGRESSION: the new pass must be a bit-for-bit no-op for the existing media
for (const [name, solver] of [['watercolor', wcSolver], ['charcoal', chSolver]]) {
  solver.clear(0);
  solver.depositSegment(6, 20, 34, 20, 40, 40, .6, 1, name === 'watercolor' ? .4 : 0, .8);
  const before = solver.deposited.slice();
  const moved = solver.flowLayer(1 / 60);
  assert(moved === 0, name + ' must not participate in yield-gated layer motion');
  for (let i = 0; i < before.length; i++) assert(before[i] === solver.deposited[i], name + ' deposited material must be bit-for-bit unchanged by the shared layer pass');
}

// relief height is derived from mass, packing and density — not stored
oilSolver.clear(0);
const packing = PROFILES.oil.state['DEPO-004'], density = PROFILES.oil.state['PART-002'];
oilSolver.deposited[820] = .5;
assert(Math.abs(oilSolver.reliefHeight(820) - .5 / (packing * density)) < 1e-9, 'relief height must equal deposited mass over packing times density');
oilSolver.deposited[820] = 1;
assert(oilSolver.reliefHeight(820) > .5 / (packing * density), 'more deposited mass must stand taller');

// below yield nothing slumps; above yield it does, and mass is conserved
const belowYield = new SharedSolver(20, 20, PROFILES.oil, SUBSTRATES.coldPress);
belowYield.clear(0);
belowYield.deposited[210] = PROFILES.oil.state['RHEO-002'] * packing * density * .5;
const belowTotal = belowYield.deposited.reduce((a, b) => a + b, 0);
assert(belowYield.flowLayer(1 / 60) === 0, 'a mound below the yield stress must hold its shape');
assert(Math.abs(belowYield.deposited.reduce((a, b) => a + b, 0) - belowTotal) < 1e-9, 'a held mound must not lose mass');

const aboveYield = new SharedSolver(20, 20, PROFILES.oil, SUBSTRATES.coldPress);
aboveYield.clear(0);
aboveYield.deposited[210] = PROFILES.oil.state['RHEO-002'] * packing * density * 40;
const aboveTotal = aboveYield.deposited.reduce((a, b) => a + b, 0);
const peakBefore = aboveYield.deposited[210];
let slumped = 0;
for (let f = 0; f < 30; f++) slumped += aboveYield.flowLayer(1 / 60);
assert(slumped > 0, 'a mound above the yield stress must slump');
assert(aboveYield.deposited[210] < peakBefore, 'the slumping peak must lose height');
assert(aboveYield.deposited[211] > 0, 'slumped material must arrive at a neighbour');
const aboveAfter = aboveYield.deposited.reduce((a, b) => a + b, 0);
assert(Math.abs(aboveAfter - aboveTotal) / aboveTotal < .00001, 'slumping must conserve deposited mass');
for (let i = 0; i < aboveYield.deposited.length; i++) assert(aboveYield.deposited[i] >= 0, 'slumping must never drive a cell negative');

// a stiffer body holds its shape better than a softer one, with no name involved
const softProfile = JSON.parse(JSON.stringify(PROFILES.oil));
softProfile.id = 'material.oil.diagnostic.v0.1-soft';
softProfile.state['RHEO-002'] = PROFILES.oil.state['RHEO-002'] * .25;
const softMound = new SharedSolver(20, 20, softProfile, SUBSTRATES.coldPress);
softMound.clear(0);
softMound.deposited[210] = aboveYield.deposited === null ? 0 : PROFILES.oil.state['RHEO-002'] * packing * density * 40;
let softSlump = 0;
for (let f = 0; f < 30; f++) softSlump += softMound.flowLayer(1 / 60);
assert(softSlump > slumped, 'a lower yield stress must slump more from the same mound');

// drawing oil: mass conserves, pigment never diffuses, and the layer stands up
const oilStroke = new SharedSolver(60, 60, PROFILES.oil, SUBSTRATES.coldPress);
oilStroke.clear(0);
oilStroke.depositSegment(10, 30, 50, 30, 60, 60, .75, 1, .6, .8); // brush water deliberately non-zero: a body must ignore it
for (let f = 0; f < 20; f++) oilStroke.step(1 / 60);
const oilState = oilStroke.metrics();
assert(oilState.deposited_pigment > 0, 'an oil stroke must leave material on the sheet');
assert(oilState.pigment_conservation_error < 1, 'an oil stroke must conserve pigment within 1%');
assert(oilStroke.water.reduce((a, b) => a + b, 0) === 0, 'an oil body must never wet the sheet');
assert(oilStroke.absorbed.reduce((a, b) => a + b, 0) === 0, 'an oil body must never soak into the sheet');
assert(oilStroke.mobile.reduce((a, b) => a + b, 0) === 0, 'oil pigment must never enter the suspended state');
// carrier water offered straight at the contact must still be refused by a body
const bodyIgnoresWater = new SharedSolver(20, 20, PROFILES.oil, SUBSTRATES.coldPress);
bodyIgnoresWater.clear(0);
bodyIgnoresWater.addDisk(10, 10, 3, .9, .5, .7, .8, .9, 0, 0);
assert(bodyIgnoresWater.water.reduce((a, b) => a + b, 0) === 0, 'a body must ignore carrier water even when it is offered directly at the contact');
assert(bodyIgnoresWater.absorbed.reduce((a, b) => a + b, 0) === 0, 'a body must not soak the sheet even when offered carrier water');
assert(bodyIgnoresWater.deposited.reduce((a, b) => a + b, 0) > 0, 'the body contact must still deposit material');

let standing = 0;
for (let i = 0; i < oilStroke.n; i++) if (oilStroke.reliefHeight(i) > 0) standing++;
assert(standing > 0, 'an oil stroke must produce standing relief');

// the brush takes material off the sheet and gives it back, conserving both ways
const pushTest = new SharedSolver(30, 30, PROFILES.oil, SUBSTRATES.coldPress);
pushTest.clear(0);
pushTest.deposited[465] = 1;
const pushTotalBefore = pushTest.deposited.reduce((a, b) => a + b, 0);
const lifted = pushTest.smearBody(465, .9, 1);
assert(lifted > 0, 'pressure above the yield stress must lift material onto the tool');
assert(pushTest.deposited[465] < 1, 'lifting must take material off the sheet');
assert(Math.abs(pushTest.deposited.reduce((a, b) => a + b, 0) + pushTest.carriedPigment - pushTotalBefore) < 1e-6, 'material must be either on the sheet or on the tool, never lost');

const gentleTest = new SharedSolver(30, 30, PROFILES.oil, SUBSTRATES.coldPress);
gentleTest.clear(0);
gentleTest.deposited[465] = 1;
assert(gentleTest.smearBody(465, PROFILES.oil.state['RHEO-002'] * .5, 1) === 0, 'pressure below the yield stress must lift nothing');

// determinism
const runOil = () => { const s = new SharedSolver(30, 30, PROFILES.oil, SUBSTRATES.coldPress); s.clear(0); s.depositSegment(5, 15, 25, 15, 30, 30, .7, 1, 0, .9); for (let f = 0; f < 10; f++) s.step(1 / 60); return s.metrics().deposited_pigment };
assert(Math.abs(runOil() - runOil()) < 1e-9, 'identical oil commands must produce identical results');

/* ---- the brush must not scrape the sheet clean (artist review 2026-08-20) ---- */
// Tolerances here are 1e-6, not 1e-9: the canvas stores mass in Float32Array,
// so a lift-and-lay round trip carries about 2e-8 of storage rounding on unit mass.

// A retained film comes from DEPO-003, a property oil already declared and
// nothing consumed. Below that thickness the material adheres to the sheet.
const oilFloor = PROFILES.oil.state['DEPO-003'] * PROFILES.oil.state['DEPO-004'] * PROFILES.oil.state['PART-002'];
const floorSolver = new SharedSolver(190, 140, PROFILES.oil, SUBSTRATES.coldPress);
assert(Math.abs(floorSolver.retainedFilmMass() - oilFloor) < 1e-9, 'the retained film must come from DEPO-003, packing and particle density');

// one firm pass must leave a continuous film, not bare paper
floorSolver.clear(0);
floorSolver.depositSegment(0.2 * 760, 0.5 * 560, 0.8 * 760, 0.5 * 560, 760, 560, .55, 1, .3, .8);
let bareOnLine = 0;
for (let x = 48; x < 143; x++) if (floorSolver.deposited[70 * 190 + x] <= 1e-6) bareOnLine++;
assert(bareOnLine === 0, 'a single pass must not leave bare paper along the centre of its own stroke');

// no cell anywhere may be pushed below the retained film
const scrape = new SharedSolver(190, 140, PROFILES.oil, SUBSTRATES.coldPress);
scrape.clear(0);
for (let pass = 0; pass < 8; pass++) scrape.depositSegment(0.2 * 760, 0.5 * 560, 0.8 * 760, 0.5 * 560, 760, 560, .9, 1, .3, 1.4);
let scrapedThrough = 0;
for (let x = 60; x < 130; x++) { const v = scrape.deposited[70 * 190 + x]; if (v > 0 && v < oilFloor * 0.98) scrapedThrough++; }
assert(scrapedThrough === 0, 'repeated hard passes must never push a covered cell below the retained film');

// pushing a lone mound still works, and still stops below the yield stress
const mound = new SharedSolver(20, 20, PROFILES.oil, SUBSTRATES.coldPress);
mound.clear(0);
mound.deposited[210] = 1;
const moundBefore = mound.deposited.reduce((a, b) => a + b, 0);
assert(mound.smearBody(210, .9, 1) > 0, 'pressure above the yield stress must still lift from a thick body');
assert(Math.abs(mound.deposited.reduce((a, b) => a + b, 0) + mound.carriedPigment - moundBefore) < 1e-6, 'lifting must still conserve mass across sheet and tool');
assert(mound.deposited[210] >= mound.retainedFilmMass() - 1e-9, 'lifting must leave the retained film behind');

// a film already at the floor cannot be pushed at all
const thin = new SharedSolver(20, 20, PROFILES.oil, SUBSTRATES.coldPress);
thin.clear(0);
thin.deposited[210] = thin.retainedFilmMass();
assert(thin.smearBody(210, 1, 1) === 0, 'a film at the retained thickness must not lift under any pressure');

// sweep scales displacement: half a crossing displaces less than a whole one
const sweepA = new SharedSolver(20, 20, PROFILES.oil, SUBSTRATES.coldPress);
sweepA.clear(0); sweepA.deposited[210] = 1;
const sweepB = new SharedSolver(20, 20, PROFILES.oil, SUBSTRATES.coldPress);
sweepB.clear(0); sweepB.deposited[210] = 1;
const wholeCrossing = sweepA.smearBody(210, .9, 1);
const halfCrossing = sweepB.smearBody(210, .9, .5);
assert(halfCrossing > 0 && halfCrossing < wholeCrossing, 'a partial crossing must lift less than a whole one');
assert(Math.abs(halfCrossing * 2 - wholeCrossing) < 1e-9, 'lifting must be proportional to the crossing travelled');

// the media without a yield stress are untouched by any of this
for (const [name, profile, paper] of [['watercolor', PROFILES.watercolor, SUBSTRATES.coldPress], ['charcoal', PROFILES.charcoal, SUBSTRATES.pastelWhite]]) {
  const solver = new SharedSolver(60, 60, profile, paper);
  solver.clear(0);
  solver.depositSegment(10, 30, 50, 30, 60, 60, .6, 1, name === 'watercolor' ? .4 : 0, .8);
  const snapshot = solver.deposited.slice();
  assert(solver.smearBody(100, 1, 1) === 0, name + ' must never lift material as a body');
  assert(solver.retainedFilmMass() === 0, name + ' declares no detachment threshold and must retain no film');
  for (let i = 0; i < snapshot.length; i++) assert(snapshot[i] === solver.deposited[i], name + ' must be bit-for-bit unchanged by body displacement');
}

// OIL-002: an empty brush dragged out of thick paint must carry colour onto
// bare canvas and taper, rather than stopping dead at the paint's edge.
const drag = new SharedSolver(190, 140, PROFILES.oil, SUBSTRATES.coldPress);
drag.clear(0);
for (let pass = 0; pass < 6; pass++) drag.depositSegment(.25 * 760, .5 * 560, .40 * 760, .5 * 560, 760, 560, .8, 1, .3, .6);
const edgeOf = () => { let last = -1; for (let x = 0; x < 190; x++) if (drag.deposited[70 * 190 + x] > 1e-6) last = x; return last; };
const edgeBefore = edgeOf();
drag.depositSegment(.32 * 760, .5 * 560, .75 * 760, .5 * 560, 760, 560, .8, 0, .3, .8);
const edgeAfter = edgeOf();
assert(edgeAfter - edgeBefore >= 12, 'an empty brush must drag colour well past the edge of the paint it started in');
assert(drag.deposited[70 * 190 + edgeAfter] < drag.deposited[70 * 190 + edgeBefore], 'dragged-out colour must taper, not end in a hard wall');
assert(drag.metrics().pigment_conservation_error < 1, 'dragging colour out must conserve pigment');

/* ---- the tool: a drawn shape must become a brush (first pass) ---------- */

const CELLS_PER_MM = 190 / 80; // the sheet is 80 mm across

// Putting the brush down leaves a mark, even if the hand never moves.
const tapOnly = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
tapOnly.setBrush('filbert');
tapOnly.clear(0);
tapOnly.liftBrush();
tapOnly.depositSegment(190, 140, 190, 140, 380, 280, .6, 1, .3, .8, 0);
const tapped = tapOnly.metrics().deposited_pigment;
assert(tapped > 0, 'a brush pressed to the sheet and lifted must leave a mark (' + tapped.toFixed(3) + ')');

// but a landing is one dab, not a licence to lay paint forever in one place
const heldDown = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
heldDown.setBrush('filbert');
heldDown.clear(0);
heldDown.liftBrush();
for (let i = 0; i < 8; i++) heldDown.depositSegment(190, 140, 190, 140, 380, 280, .6, 1, .3, .8, 0);
assert(heldDown.metrics().deposited_pigment < tapped * 2,
  'holding still must not keep pumping paint out of the brush (' + heldDown.metrics().deposited_pigment.toFixed(3) + ' from ' + tapped.toFixed(3) + ')');

// An empty brush stops giving paint. It does not stop being a brush: it still
// shoves what is already on the sheet and picks some of it up.
const spent = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
spent.setBrush('filbert');
spent.clear(0);
spent.setAutoReload(false);
for (let y = 100; y < 180; y += 6) { spent.liftBrush(); spent.depositSegment(60, y, 320, y, 380, 280, .7, 1, .3, .8, 0); }
let guard = 0;
while (spent.brushCharge() > 0 && guard++ < 400) { spent.liftBrush(); spent.depositSegment(60, 240, 320, 240, 380, 280, .7, 1, .3, .8, 0); }
assert(spent.brushCharge() === 0, 'the brush must actually run dry for this check to mean anything');
const movedBefore = spent.relocatedPigment;
spent.liftBrush();
spent.depositSegment(60, 140, 320, 140, 380, 280, .8, 1, .3, .8, 0);
assert(spent.relocatedPigment > movedBefore,
  'an empty brush must still push the paint that is already on the sheet');
assert(spent.metrics().pigment_conservation_error < 1, 'pushing paint with an empty brush must conserve it');

// A hair that barely touches must shove proportionally less than the belly.
//
// Without this the outermost hair moved paint exactly as hard as the middle of
// the head, which turns the soft edge of a mark into a hard one. The artist
// found it from the far end: "it's not great at feathering edges... The
// relationship between the brush and the paint already on the canvas just
// doesn't quite jive."
//
// The brush is run empty first, so nothing is laid and everything that moves
// moved because the hair shoved it.
const dryHead = { ...BRUSHES.filbert, id: 'brush.test.dry-head.v0', capacity: 1 };
const onWetPaint = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
onWetPaint.setBrush(dryHead);
onWetPaint.clear(0);
onWetPaint.setAutoReload(false);
onWetPaint.charge = 0;
for (let y = 100; y < 190; y++) for (let x = 100; x < 300; x++) onWetPaint.deposited[y * 380 + x] = 2;
const beforeContact = new Float32Array(onWetPaint.deposited);
onWetPaint.liftBrush();
onWetPaint.depositSegment(130, 145, 270, 145, 380, 280, .7, 1, .3, .8, 0);
const shovedAt = (dy) => {
  let total = 0;
  for (let x = 150; x < 250; x++) total += Math.abs(onWetPaint.deposited[(145 + dy) * 380 + x] - beforeContact[(145 + dy) * 380 + x]);
  return total;
};
assert(shovedAt(0) > 0, 'an empty head dragged over settled paint must move some of it');
assert(shovedAt(0) > shovedAt(8) * 3,
  'the belly must shove settled paint far harder than the rim of the same head (' +
  shovedAt(0).toFixed(4) + ' down the middle, ' + shovedAt(8).toFixed(4) + ' near the edge)');
assert(shovedAt(0) > shovedAt(4) && shovedAt(4) > shovedAt(8),
  'the falloff from belly to rim must be gradual rather than a step');

// The disc is the default and stays the default. Every material review so far
// was made with it, and none of them may move because drawn brushes now exist.
const defaultTool = new SharedSolver(60, 60, PROFILES.oil, SUBSTRATES.coldPress);
assert(defaultTool.getBrush().kind === 'disc', 'a solver must reach for the disc unless told otherwise');

// A golden mark, so any future change to the disc footprint is caught here.
// Re-baselined 2026-08-21 by a tenth of a percent when contact spacing moved
// from nominal to actual. That change stopped a stroke getting heavier the
// faster the pen reported it, which was worth more than an exact reference.
// Re-baselined again the same day, by half of one tenth of a percent, when
// putting the brush down became a mark in its own right. Paint is laid by
// distance travelled, and taken literally that left a brush pressed to the
// sheet and lifted without moving with nothing to show for it.
const goldenDisc = new SharedSolver(190, 140, PROFILES.oil, SUBSTRATES.coldPress); // the disc's own reference grid
goldenDisc.clear(0);
goldenDisc.depositSegment(114, 280, 646, 252, 760, 560, .68, 1, .42, .9);
assert(Math.abs(goldenDisc.metrics().deposited_pigment - 128.4923) < .01,
  'the disc footprint must keep laying the paint it lays (got ' + goldenDisc.metrics().deposited_pigment.toFixed(4) + ')');

/* ---- work that is skipped must be work there was none of ------------------

   The frame loop no longer runs the water solve on a sheet with no water, or
   the crumb and dust passes when there are no crumbs and no dust. That is a
   large saving and a real risk: get the bookkeeping wrong and a wash quietly
   stops moving halfway through. Both checks below are absolute - they say the
   sheet keeps changing - rather than comparing two sheets against each other,
   which is what let the first version of this slip through. */

// a wash keeps working long after the brush has left it
const keepsMoving = new SharedSolver(120, 90, PROFILES.watercolor, SUBSTRATES.rough);
keepsMoving.clear(0);
keepsMoving.depositSegment(30, 45, 90, 45, 120, 90, .6, 1, 1, .5);
keepsMoving.step(1 / 60);
const soakedAfterOneFrame = keepsMoving.metrics().absorbed_water;
for (let i = 0; i < 60; i++) keepsMoving.step(1 / 60);
const soakedAfterASecond = keepsMoving.metrics().absorbed_water;
assert(soakedAfterASecond > soakedAfterOneFrame * 1.5,
  'a wash must keep soaking into the paper after the brush has gone (' +
  soakedAfterOneFrame.toFixed(3) + ' -> ' + soakedAfterASecond.toFixed(3) + ')');

// and a sheet that really is dry must be left alone rather than churned
const bone = new SharedSolver(60, 60, PROFILES.oil, SUBSTRATES.coldPress);
bone.clear(0);
assert(bone.wetLive === false, 'oil cannot wet the sheet, so its water solve must never run');
const damp = new SharedSolver(60, 60, PROFILES.watercolor, SUBSTRATES.rough);
damp.clear(1);
assert(damp.wetLive === true, 'a sheet damped on purpose must be simulated as damp');

/* ---- the paper is mixed once, so it must be re-mixed when it changes ------ */

const paintedPaper = (substrate, sheet) => {
  const solver = new SharedSolver(64, 48, PROFILES.oil, SUBSTRATES[substrate]);
  solver.clear(0);
  if (sheet) solver.newSheet(sheet);
  solver.render({ save() {}, restore() {}, clearRect() {}, drawImage() {} }, { width: 64, height: 48 });
  return Uint8ClampedArray.from(solver.image.data);
};
const differingChannels = (a, b) => { let n = 0; for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) n++; return n; };

const onHotPress = paintedPaper("hotPress", 0), onCanvas = paintedPaper("roughCanvas", 0);
assert(differingChannels(onHotPress, onCanvas) > onHotPress.length * .5,
  'changing the paper must change what is on screen (' + differingChannels(onHotPress, onCanvas) + ' channels)');

const firstSheet = paintedPaper("roughCanvas", 0), anotherSheet = paintedPaper("roughCanvas", 9);
assert(differingChannels(firstSheet, anotherSheet) > firstSheet.length * .1,
  'taking a new sheet must change what is on screen (' + differingChannels(firstSheet, anotherSheet) + ' channels)');

// Geometry only. A brush may never carry a look.
for (const key of Object.keys(BRUSHES)) {
  const brush = BRUSHES[key];
  const text = JSON.stringify({ o: brush.outline, b: brush.belly, s: brush.softness, w: brush.widthMm });
  assert(!/color|colour|pigment|grain|texture|bloom|ridge|image/i.test(text),
    key + ' must carry geometry only — never a baked mark');
  assert(brush.id && brush.version, key + ' must be versioned, so a review can name the tool that made it');
}

// how wide a mark is, measured across the stroke, in whole cells
const markWidth = (brush, angle, dirX, dirY, pressure) => {
  const solver = new SharedSolver(190, 140, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush(brush);
  solver.clear(0);
  solver.depositSegment(380 - dirX * 150, 280 - dirY * 150, 380 + dirX * 150, 280 + dirY * 150,
    760, 560, pressure, 1, .3, .8, angle);
  let cells = 0;
  if (dirY !== 0) { for (let x = 0; x < 190; x++) if (solver.deposited[70 * 190 + x] > 1e-6) cells++; }
  else { for (let y = 0; y < 140; y++) if (solver.deposited[y * 190 + 95] > 1e-6) cells++; }
  return { cells, mm: cells / CELLS_PER_MM, error: solver.metrics().pigment_conservation_error };
};

// A flat brush must care which way it is dragged. This is the whole proof.
const broadStroke = markWidth('flat', 0, 0, 1, .7);
const edgeStroke = markWidth('flat', 0, 1, 0, .7);
assert(broadStroke.cells >= edgeStroke.cells * 3,
  'a flat brush dragged across its face must make a far broader mark than the same brush dragged along it');
assert(edgeStroke.mm < 4, 'the edge of a 12 mm flat must draw a thin line, not a band');

// The disc cannot tell the difference, and must not pretend to.
const discAcross = markWidth('disc', 0, 0, 1, .7);
const discAlong = markWidth('disc', 0, 1, 0, .7);
assert(Math.abs(discAcross.cells - discAlong.cells) <= 1, 'a round footprint must mark the same in every direction');

// The wrist matters: turning the brush without changing the drag changes the mark.
const turned = [0, 45, 90].map((deg) => markWidth('flat', deg * Math.PI / 180, 0, 1, .7).cells);
assert(turned[0] > turned[1] && turned[1] > turned[2],
  'turning the brush must narrow the mark steadily, not jump');

// Sized in millimetres, so the mark keeps its real size whatever the grid does.
const pressedFull = markWidth('filbert', 0, 0, 1, 1);
assert(Math.abs(pressedFull.mm - BRUSHES.filbert.widthMm) < 1.5,
  'a 12 mm filbert pressed fully down must make a mark about 12 mm across (got ' + pressedFull.mm.toFixed(1) + ')');

// The belly: light contact is the tip only, heavy contact is the whole head.
const tipOnly = markWidth('filbert', 0, 0, 1, .15);
assert(tipOnly.cells < pressedFull.cells * .55, 'light pressure must touch with the tip, not the whole head');
const bellySteps = [.15, .4, .7, 1].map((p) => markWidth('filbert', 0, 0, 1, p).cells);
for (let i = 1; i < bellySteps.length; i++)
  assert(bellySteps[i] >= bellySteps[i - 1], 'pressing harder must never make the mark narrower');

// The head is hair, not a cookie cutter: it must lay more in the middle of its
// footprint than at the rim, or every mark is a stamp with a hard edge.
const feather = new SharedSolver(190, 140, PROFILES.oil, SUBSTRATES.coldPress);
feather.setBrush('filbert');
feather.clear(0);
feather.depositSegment(380, 280, 380.6, 280, 760, 560, .9, 1, .3, .4, 0); // one dab, not a drag: a swept stroke piles up and hides the profile
let firstMarked = -1, lastMarked = -1;
for (let x = 0; x < 190; x++) if (feather.deposited[70 * 190 + x] > 1e-6) { if (firstMarked < 0) firstMarked = x; lastMarked = x; }
const middleCell = Math.round((firstMarked + lastMarked) / 2);
const middle = feather.deposited[70 * 190 + middleCell];
const rim = Math.max(feather.deposited[70 * 190 + firstMarked], feather.deposited[70 * 190 + lastMarked]);
assert(middle > rim * 4, 'the footprint must feather towards its edge, not cut off square (middle ' + middle.toFixed(3) + ' vs rim ' + rim.toFixed(3) + ')');

// Whatever the shape, the ledger still balances.
for (const brush of ['filbert', 'flat']) {
  const solver = new SharedSolver(190, 140, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush(brush);
  solver.clear(0);
  solver.depositSegment(120, 200, 620, 340, 760, 560, .8, 1, .3, .9, .4);
  for (let f = 0; f < 20; f++) solver.step(1 / 60);
  assert(solver.metrics().pigment_conservation_error < 1, brush + ' must conserve pigment like any other contact');
}

// Same shape, same commands, same result.
const repeat = () => {
  const solver = new SharedSolver(120, 90, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush('filbert'); solver.clear(0);
  solver.depositSegment(60, 150, 420, 210, 480, 360, .75, 1, .3, .9, .3);
  return solver.metrics().deposited_pigment;
};
assert(Math.abs(repeat() - repeat()) < 1e-9, 'a drawn brush must be as repeatable as a disc');

// And a drawn brush must not decide anything from the material's name.
assert(!/watercolor|charcoal|oil(?![A-Za-z])/i.test(
  SharedSolver.prototype.setBrush.toString() + SharedSolver.prototype.getBrush.toString()
), 'the tool must not branch on a named medium');

/* ---- canvas is woven, and a weave is not noise ------------------------- */

// Counting peaks alone cannot tell cloth from paper - both have plenty. What
// separates them is that a weave's threads are EVENLY SPACED. So measure the
// spacing between peaks and how much it varies.
const WEAVE_GRID = 500; // 80 mm across 500 cells = 62.5 cells/cm, fine enough to draw 12-20 threads/cm
const threadSpacing = (substrate, down) => {
  const solver = new SharedSolver(WEAVE_GRID, WEAVE_GRID, PROFILES.oil, SUBSTRATES[substrate]);
  const line = [];
  for (let i = 0; i < WEAVE_GRID; i++) line.push(down ? solver.tooth(WEAVE_GRID / 2, i) : solver.tooth(i, WEAVE_GRID / 2));
  const peaks = [];
  for (let i = 1; i < WEAVE_GRID - 1; i++) if (line[i] > line[i - 1] && line[i] >= line[i + 1]) peaks.push(i);
  const gaps = [];
  for (let i = 1; i < peaks.length; i++) gaps.push(peaks[i] - peaks[i - 1]);
  const mean = gaps.reduce((a, b) => a + b, 0) / Math.max(1, gaps.length);
  const spread = Math.sqrt(gaps.reduce((a, g) => a + (g - mean) * (g - mean), 0) / Math.max(1, gaps.length));
  const cellsPerCm = (WEAVE_GRID / 80) * 10;
  return { count: peaks.length, mean, perCm: cellsPerCm / Math.max(.001, mean), wobble: spread / Math.max(.001, mean) };
};

for (const cloth of ['roughCanvas', 'linenCanvas']) {
  const across = threadSpacing(cloth, false), down = threadSpacing(cloth, true);
  assert(across.wobble < .3 && down.wobble < .3,
    cloth + ' must have evenly spaced threads, which is what makes it cloth rather than noise');
  assert(Math.abs(across.mean - down.mean) < 1.5,
    cloth + ' is a plain weave: warp and weft must be spaced alike');
  assert(Math.abs(across.perCm - SUBSTRATES[cloth].texture.threadsPerCm) < 3,
    cloth + ' must weave at the thread count its profile states (states ' + SUBSTRATES[cloth].texture.threadsPerCm + '/cm, measured ' + across.perCm.toFixed(1) + ')');
  assert(SUBSTRATES[cloth].state['TRAN-002'] < SUBSTRATES.hotPress.state['TRAN-002'] * .5,
    cloth + ' is primed cloth and must drink far less than the least thirsty paper');
  assert(SUBSTRATES[cloth].texture.pattern === 'woven', cloth + ' must use the woven surface');
  assert(SUBSTRATES[cloth].version && /reference-derived/.test(JSON.stringify(SUBSTRATES[cloth].provenance)),
    cloth + ' must be versioned and say where it came from');
}

// THE INTERLACING. Even thread spacing is not enough - a twill and a plain grid
// of bumps both have that. What makes plain weave is that which thread lies on
// top SWAPS at every crossing. Walk along one line of warp crests: every other
// one is the thread that dipped under, so the raised ones must sit measurably
// higher than the dipped ones. Counting wobbles is not enough; slub variation
// alone can fake that. Measure the depth of the dip.
for (const cloth of ['roughCanvas', 'linenCanvas']) {
  const solver = new SharedSolver(WEAVE_GRID, WEAVE_GRID, PROFILES.oil, SUBSTRATES[cloth]);
  const period = (WEAVE_GRID / 80) * 10 / SUBSTRATES[cloth].texture.threadsPerCm;
  const overs = [], unders = [];
  for (let i = 0; i < 14; i++) {
    const height = solver.tooth((i + .5) * period, 4 * period);
    (i % 2 === 0 ? overs : unders).push(height);
  }
  const mean = (a) => a.reduce((x, y) => x + y, 0) / a.length;
  const raised = Math.max(mean(overs), mean(unders));
  const dipped = Math.min(mean(overs), mean(unders));
  assert(raised - dipped > .12,
    cloth + ' must interlace: alternate crossings have to sit clearly lower, because that thread passed underneath (gap ' + (raised - dipped).toFixed(3) + ')');
}
// paper is not cloth: its grain must be irregular
for (const paper of ['coldPress', 'rough']) {
  assert(threadSpacing(paper, false).wobble > .3,
    paper + ' is paper and must not fall into an even weave');
}

// linen is the finer cloth
assert(threadSpacing('linenCanvas', false).perCm > threadSpacing('roughCanvas', false).perCm,
  'linen must be woven finer than the rough canvas');

// Cloth sits LOWER on average than paper, and should: a weave is mostly valley
// with threads raised above it, which is what gives oil on canvas its broken
// bite. What matters is that it stays in a sane band and never drifts to one
// extreme, where everything would either catch or miss.
for (const cloth of ['roughCanvas', 'linenCanvas']) {
  const solver = new SharedSolver(WEAVE_GRID, WEAVE_GRID, PROFILES.oil, SUBSTRATES[cloth]);
  let sum = 0;
  for (let y = 0; y < WEAVE_GRID; y++) for (let x = 0; x < WEAVE_GRID; x++) sum += solver.tooth(x, y);
  const mean = sum / (WEAVE_GRID * WEAVE_GRID);
  assert(mean > .3 && mean < .6, cloth + ' must stay in a usable height band, lower than paper but not collapsed (got ' + mean.toFixed(3) + ')');
}

// the same cloth twice is the same cloth
assert(threadSpacing('linenCanvas', false).count === threadSpacing('linenCanvas', false).count, 'a weave must be repeatable');

// and a drawn brush can paint oil on it
const onCloth = new SharedSolver(190, 140, PROFILES.oil, SUBSTRATES.roughCanvas);
onCloth.setBrush('filbert');
onCloth.clear(0);
onCloth.depositSegment(140, 220, 620, 330, 760, 560, .8, 1, .3, .9, 0);
for (let f = 0; f < 20; f++) onCloth.step(1 / 60);
assert(onCloth.metrics().deposited_pigment > 0, 'a drawn brush must lay paint on canvas');
assert(onCloth.metrics().pigment_conservation_error < 1, 'painting on canvas must conserve pigment');

/* ---- no two sheets are the same sheet ---------------------------------- */

const sheetOf = (substrate, id) => {
  const solver = new SharedSolver(140, 140, PROFILES.oil, SUBSTRATES[substrate]);
  solver.newSheet(id);
  const line = [];
  for (let x = 0; x < 140; x++) line.push(solver.tooth(x, 70));
  let peaks = 0, sum = 0;
  for (let i = 1; i < 139; i++) if (line[i] > line[i - 1] && line[i] >= line[i + 1]) peaks++;
  for (let i = 0; i < solver.paperHeight.length; i++) sum += solver.paperHeight[i];
  return { peaks, mean: sum / solver.paperHeight.length, height: solver.paperHeight.slice() };
};

// Sheet 0 is the reference sheet and must never move - every mark already
// reviewed was made on it. Comparing the engine against itself cannot prove
// that, so these are fingerprints taken on 2026-08-20. If one of them shifts,
// a paper has changed underneath work that was already approved.
// pastelWhite and coldPress carry approved marks and are pinned to their
// original 2026-08-20 values. roughCanvas was re-baselined the same day when
// thread spacing moved from grid cells to threads-per-centimetre: the cloth
// genuinely changed, and no canvas has ever been reviewed, so nothing was lost.
const REFERENCE_SHEETS = { pastelWhite: 8292.6483, coldPress: 8482.1659, roughCanvas: 6665.2201 };
for (const [paper, expected] of Object.entries(REFERENCE_SHEETS)) {
  const solver = new SharedSolver(64, 64, PROFILES.oil, SUBSTRATES[paper]);
  let fingerprint = 0;
  for (let i = 0; i < solver.paperHeight.length; i++) fingerprint += solver.paperHeight[i] * (1 + (i % 7));
  assert(Math.abs(fingerprint - expected) < .01,
    paper + ' reference sheet has changed - approved marks were made on the old one (got ' + fingerprint.toFixed(4) + ', expected ' + expected + ')');
}

// and asking for sheet 0 explicitly must land on that same reference sheet
// reviewed was made on it.
for (const paper of ['coldPress', 'pastelWhite', 'roughCanvas']) {
  const fresh = new SharedSolver(140, 140, PROFILES.oil, SUBSTRATES[paper]);
  const asked = sheetOf(paper, 0);
  for (let i = 0; i < fresh.paperHeight.length; i++)
    assert(fresh.paperHeight[i] === asked.height[i], paper + ' sheet 0 must be exactly the sheet it has always been');
}

// A different sheet is genuinely a different sheet.
for (const paper of ['coldPress', 'roughCanvas', 'linenCanvas']) {
  const first = sheetOf(paper, 0), second = sheetOf(paper, 17);
  let differing = 0;
  for (let i = 0; i < first.height.length; i++) if (first.height[i] !== second.height[i]) differing++;
  assert(differing > first.height.length * .8, paper + ' must actually change from one sheet to the next');
}

// But it is still the same paper. Cloth must keep weaving at its own count.
for (const cloth of ['roughCanvas', 'linenCanvas']) {
  const counts = [0, 3, 11, 50, 137].map((id) => sheetOf(cloth, id).peaks);
  const low = Math.min(...counts), high = Math.max(...counts);
  assert(high - low <= 2, cloth + ' must weave the same count sheet to sheet - a new sheet is not a new cloth (got ' + counts.join(', ') + ')');
}

// And rough must stay rougher than smooth, whichever sheets you pick.
for (const id of [1, 9, 64]) {
  assert(sheetOf('rough', id).peaks > 0 && sheetOf('hotPress', id).peaks > 0, 'every sheet must have a surface');
  const roughSheet = new SharedSolver(140, 140, PROFILES.charcoal, SUBSTRATES.rough); roughSheet.newSheet(id);
  const smoothSheet = new SharedSolver(140, 140, PROFILES.charcoal, SUBSTRATES.hotPress); smoothSheet.newSheet(id);
  let rMin = 1, rMax = 0, sMin = 1, sMax = 0;
  for (let i = 0; i < roughSheet.paperHeight.length; i++) {
    const r = roughSheet.paperHeight[i], sm = smoothSheet.paperHeight[i];
    if (r < rMin) rMin = r; if (r > rMax) rMax = r;
    if (sm < sMin) sMin = sm; if (sm > sMax) sMax = sm;
  }
  assert(rMax - rMin > sMax - sMin, 'rough paper must stay rougher than hot press on sheet ' + id);
}

// The same sheet number is always the same sheet, or nothing is reproducible.
const twiceA = sheetOf('linenCanvas', 42), twiceB = sheetOf('linenCanvas', 42);
for (let i = 0; i < twiceA.height.length; i++)
  assert(twiceA.height[i] === twiceB.height[i], 'asking for the same sheet twice must give the same sheet');

/* ---- a brush being drawn is a brush ------------------------------------ */

// The editor hands the engine a whole definition on every edit. If that does
// not change the mark, nothing about drawing a brush is real.
const EDIT_GRID = 380, EDIT_H = 280, EDIT_CPM = EDIT_GRID / 80;
const markOfDefinition = (definition, alongFace) => {
  const solver = new SharedSolver(EDIT_GRID, EDIT_H, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush(definition);
  solver.clear(0);
  const cx = EDIT_GRID * 2, cy = EDIT_H * 2, reach = EDIT_GRID;
  if (alongFace) solver.depositSegment(cx - reach, cy, cx + reach, cy, EDIT_GRID * 4, EDIT_H * 4, .9, 1, .3, .8, 0);
  else solver.depositSegment(cx, cy - reach, cx, cy + reach, EDIT_GRID * 4, EDIT_H * 4, .9, 1, .3, .8, 0);
  let cells = 0;
  if (alongFace) { for (let y = 0; y < EDIT_H; y++) if (solver.deposited[y * EDIT_GRID + Math.round(EDIT_GRID / 2)] > 1e-6) cells++; }
  else { for (let x = 0; x < EDIT_GRID; x++) if (solver.deposited[Math.round(EDIT_H / 2) * EDIT_GRID + x] > 1e-6) cells++; }
  return { mm: cells / EDIT_CPM, error: solver.metrics().pigment_conservation_error };
};

const asDrawn = (changes) => {
  const base = JSON.parse(JSON.stringify(BRUSHES.filbert));
  delete base._field;
  return { ...base, kind: 'shape', ...changes };
};

const stock = markOfDefinition(asDrawn({}), false);
const stockAlong = markOfDefinition(asDrawn({}), true);

// pinch the hairs toward the spine: the face narrows, the other way does not
const pinched = asDrawn({ outline: BRUSHES.filbert.outline.map((p) => [p[0] * .45, p[1]]) });
assert(markOfDefinition(pinched, false).mm < stock.mm * .6,
  'pulling the hairs inward must narrow the face of the mark');
assert(Math.abs(markOfDefinition(pinched, true).mm - stockAlong.mm) < .5,
  'narrowing the face must not change the mark along the face');

// pull it long and thin and the two axes swap over
const rigger = asDrawn({ outline: BRUSHES.filbert.outline.map((p) => [p[0] * .3, p[1] * 2.1]) });
const riggerAcross = markOfDefinition(rigger, false).mm, riggerAlong = markOfDefinition(rigger, true).mm;
assert(riggerAlong > riggerAcross * 2,
  'a long thin head must mark broadly along its length and thinly across it');

// the belly alone decides how pressure opens the head
const lateBelly = asDrawn({ belly: [{ p: 0, contact: .12 }, { p: .6, contact: .2 }, { p: .85, contact: .6 }, { p: 1, contact: 1 }] });
const lateSolver = (pressure) => {
  const solver = new SharedSolver(EDIT_GRID, EDIT_H, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush(lateBelly);
  solver.clear(0);
  solver.depositSegment(EDIT_GRID * 1.2, EDIT_H * 2, EDIT_GRID * 2.8, EDIT_H * 2, EDIT_GRID * 4, EDIT_H * 4, pressure, 1, .3, .8, 0);
  let cells = 0;
  for (let y = 0; y < EDIT_H; y++) if (solver.deposited[y * EDIT_GRID + Math.round(EDIT_GRID / 2)] > 1e-6) cells++;
  return cells / EDIT_CPM;
};
assert(lateSolver(.9) > lateSolver(.3) * 2.5,
  'a belly that opens late must stay thin under light pressure and open under heavy');

// whatever is drawn, the ledger still balances and no look is baked in
assert(stock.error < 1, 'a drawn brush must conserve pigment like any other');
assert(!/color|colour|pigment|grain|texture|image/i.test(JSON.stringify(asDrawn({}).outline)),
  'a drawn brush must carry geometry only');

/* ---- hair bends: the head trails the hand ------------------------------ */

// A lagging head does not run PAST a corner - it never gets there. The hand
// turns first and the head cuts across, which is why a soft brush rounds a
// sharp corner off and a stiff one takes it crisply.
const cornerReach = (stiffness, speed) => {
  const definition = { ...JSON.parse(JSON.stringify(BRUSHES.filbert)), kind: 'shape', stiffness };
  delete definition._field;
  const solver = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush(definition);
  solver.clear(0);
  solver.liftBrush();
  const V = 4;
  solver.depositSegment(380 * V * .25, 280 * V * .35, 380 * V * .62, 280 * V * .35, 380 * V, 280 * V, .8, 1, .3, speed, 0);
  solver.depositSegment(380 * V * .62, 280 * V * .35, 380 * V * .62, 280 * V * .8, 380 * V, 280 * V, .8, 1, .3, speed, 0);
  const cornerX = Math.round(380 * .62), cornerY = Math.round(280 * .35);
  let reach = 0;
  for (let x = cornerX; x < 380; x++) if (solver.deposited[cornerY * 380 + x] > 1e-6) reach = x - cornerX;
  return reach / (380 / 80);
};

const stiffCorner = cornerReach(.95, 1.4);
const softCorner = cornerReach(.30, 1.4);
assert(softCorner < stiffCorner * .8,
  'a soft head must cut the corner, reaching less far than a stiff one (soft ' + softCorner.toFixed(2) + ' mm, stiff ' + stiffCorner.toFixed(2) + ' mm)');

// hurrying bends the head further
assert(cornerReach(.30, 1.4) < cornerReach(.30, .4),
  'the same soft head must bend further when the gesture is quicker');

// and it is a steady relationship, not a switch
const ladder = [.95, .78, .55, .30].map((st) => cornerReach(st, 1.4));
for (let i = 1; i < ladder.length; i++)
  assert(ladder[i] <= ladder[i - 1] + .01, 'softer hair must never cut the corner less than stiffer hair');

/* ---- and the bend has to be big enough to see ---------------------------

   Every assertion above compares one brush against another. All of them passed
   while the effect was far too small to notice - a filbert sat 1.5 mm behind
   the hand on an 80 mm sheet, and the whole spread between the softest and the
   stiffest head rounding a corner was 0.4 mm. The artist saw that immediately:
   "The bending and lagging is very understated which is why I haven't green
   marked it." Ordering was tested; size was not. */

const trailingMm = (stiffness, widthMm, speed) => {
  const solver = new SharedSolver(570, 420, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush({ ...BRUSHES.filbert, id: 'brush.test.trail.v0', stiffness, widthMm });
  solver.clear(0);
  solver.liftBrush();
  solver.headFollow(50, 100, 0, speed);
  for (let i = 0; i < 400; i++) solver.headFollow(50 + (i + 1) * 2, 100, 2, speed);
  return (850 - solver.headX) / (570 / 80);   // 570 cells across a sheet 80 mm wide
};

const filbertTrail = trailingMm(.55, 12, .8);
assert(filbertTrail > 3 && filbertTrail < 6,
  'a 12 mm filbert must sit 3 to 6 mm behind the hand - far enough to read as hair (' + filbertTrail.toFixed(2) + ' mm)');

// The gap between a soft head and a stiff one has to be visible on the sheet,
// not merely present in the numbers.
const cornerSpread = cornerReach(.95, 1.4) - cornerReach(.30, 1.4);
assert(cornerSpread > 1,
  'soft and stiff heads must round a corner at least a millimetre apart (' + cornerSpread.toFixed(2) + ' mm)');

// A brush bends because its hair is a cantilever, so a wider head - carrying
// longer hair - must lag more than a narrow one of the same stiffness.
assert(trailingMm(.55, 24, .8) > filbertTrail * 1.5,
  'a wider head must trail further than a narrow one of the same hair');

// and hurrying it must matter by a visible amount, not a rounding error
assert(trailingMm(.55, 12, 1.6) - trailingMm(.55, 12, .3) > 1.5,
  'the same head must trail at least 1.5 mm further when hurried');

// the disc has no hair and must not pretend to
const rigidSolver = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
rigidSolver.clear(0);
rigidSolver.liftBrush();
assert(rigidSolver.getBrush().stiffness === undefined, 'the disc must declare no stiffness rather than a fake one');
const before = rigidSolver.headFollow(100, 100, 0, 1);
const after = rigidSolver.headFollow(180, 100, 40, 1);
assert(after.x === 180 && after.y === 100 && before.x === 100,
  'a tool with no stiffness must sit exactly where the hand puts it');

// The bend must follow the DISTANCE the hand travelled, not the number of
// times the stroke happened to be sampled. Chasing a fixed point in one long
// step and in ten short ones has to land the head in the same place, or the
// same gesture drags differently depending on how fast the pen reports.
const chase=(steps,total)=>{
  const solver=new SharedSolver(380,280,PROFILES.oil,SUBSTRATES.coldPress);
  solver.setBrush('filbert');
  solver.clear(0);
  solver.liftBrush();
  solver.headFollow(0,0,0,1);
  for(let i=0;i<steps;i++) solver.headFollow(total,0,total/steps,1);
  return solver.headX;
};
// eight cells is about one trailing length, so the head is still catching up
// there; over a long straight it would arrive fully, which is the point.
const oneLongStep=chase(1,8), manyShortSteps=chase(24,8);
assert(Math.abs(oneLongStep-manyShortSteps)<.5,
  'the bend must depend on how far the hand moved, not how finely it was sampled ('+oneLongStep.toFixed(2)+' against '+manyShortSteps.toFixed(2)+')');
assert(oneLongStep<8*.85,'the head must genuinely trail behind the point it is chasing (reached '+oneLongStep.toFixed(2)+' of 8)');

// lifting clears the head, so the next stroke starts where you put it
const afterLift = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
afterLift.setBrush('filbert');
afterLift.clear(0);
afterLift.headFollow(10, 10, 0, 1);
afterLift.headFollow(300, 10, 200, 1);
afterLift.liftBrush();
const restart = afterLift.headFollow(50, 200, 0, 1);
assert(restart.x === 50 && restart.y === 200, 'lifting the brush must let the next stroke start where it is put');

/* ---- the brush holds paint, and runs out -------------------------------- */

const strokeOn = (solver, row) => {
  const before = solver.metrics().deposited_pigment;
  solver.liftBrush();
  solver.depositSegment(solver.w * .12, solver.h * row, solver.w * .88, solver.h * row, solver.w, solver.h, .75, 1, .3, .8, 0);
  return solver.metrics().deposited_pigment - before;
};

// A deliberately small head, so running dry is five strokes rather than thirty.
// What is under test here is the mechanism; the capacities the brushes actually
// ship with are pinned separately, by reach, below.
const smallHead = { ...BRUSHES.filbert, id: 'brush.test.small-head.v0', name: 'Small head', capacity: 900 };
const loaded = new SharedSolver(380, 420, PROFILES.oil, SUBSTRATES.coldPress);
loaded.setBrush(smallHead);
loaded.clear(0);
assert(loaded.hasReservoir(), 'a drawn brush must hold a finite amount of paint');
assert(loaded.brushCharge() === 1, 'a brush must come to the sheet loaded, not dry');

const laid = [.15, .3, .45, .6, .75].map((row) => strokeOn(loaded, row));
const laidAt = laid.map((v) => v.toFixed(0)).join(', ');
assert(laid[0] > 300, 'the first stroke must lay a full load of paint (' + laidAt + ')');
assert(laid[2] < laid[0] * .5, 'a brush running low must lay less (' + laidAt + ')');
assert(laid[4] === 0, 'an empty brush must lay nothing at all (' + laidAt + ')');
assert(loaded.brushCharge() === 0, 'an empty brush must read empty, not merely faint');
assert(loaded.metrics().pigment_conservation_error < 1, 'running a brush dry must still conserve pigment');

// dipping brings it back, and brings paint into the world rather than conjuring it
const beforeDip = loaded.metrics().deposited_pigment + loaded.charge;
const taken = loaded.dipBrush(1);
assert(taken > 0 && loaded.brushCharge() === 1, 'dipping must refill the brush');
assert(Math.abs(loaded.metrics().pigment_conservation_error) < 1, 'dipping must keep the ledger honest');
assert(strokeOn(loaded, .9) > 300, 'a freshly dipped brush must paint at full strength again');
assert(beforeDip < loaded.metrics().deposited_pigment + loaded.charge, 'dipping must add paint, not move it');

/* ---- how far one dip goes -------------------------------------------------

   The artist's finding on 2026-08-21, painting oil with the filbert: "Paint runs
   out very quickly - too quickly, actually." It was true and it was measurable -
   a single 8 cm stroke spent 42% of a full load, so two and a half strokes and
   the brush was dead.

   Reach is capacity divided by release. Both are per-brush numbers meant to be
   edited, so the thing worth holding still is the reach they produce, stated in
   millimetres of stroke rather than in units of pigment. */

const reachMm = (material, substrate, brush) => {
  const t = new SharedSolver(380, 280, PROFILES[material], SUBSTRATES[substrate]);
  t.setBrush(brush);
  t.clear(0);
  let cells = 0;
  // 380 cells across a sheet 80 mm wide.
  for (let i = 0; i < 600 && t.brushCharge() > 0; i++) {
    t.liftBrush();
    t.depositSegment(10, 20 + (i * 13) % 240, 370, 20 + (i * 13) % 240, 380, 280, .6, 1, .3, .8, 0);
    cells += 360;
  }
  return cells / (380 / 80);
};

const oilReach = reachMm('oil', 'roughCanvas', 'filbert');
assert(oilReach > 500 && oilReach < 2000,
  'a dipped filbert must draw between 50 and 200 cm of oil before it runs dry (' + (oilReach / 10).toFixed(0) + ' cm)');
const washReach = reachMm('watercolor', 'hotPress', 'filbert');
assert(washReach > oilReach * 1.5,
  'a thin wash must go much further on one dip than stiff paint (' + (washReach / 10).toFixed(0) + ' vs ' + (oilReach / 10).toFixed(0) + ' cm)');

// A stiffer, coarser head meters its paint out and drags the same load further.
assert(reachMm('oil', 'roughCanvas', 'flat') > oilReach,
  'the stiffer flat must reach further on one dip than the softer filbert');

/* ---- auto-reload ----------------------------------------------------------

   Going back to the palette without having to say so. It is a convenience and
   not physics, so the engine ships with it off - otherwise every measurement of
   running out silently measures nothing. */

const reload = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
reload.setBrush('filbert');
reload.clear(0);
reload.depositSegment(40, 60, 340, 60, 380, 280, .75, 1, .3, .8, 0);
const spentCharge = reload.brushCharge();
assert(spentCharge > 0 && spentCharge < 1, 'a stroke must spend paint without emptying the brush (' + spentCharge.toFixed(3) + ')');
reload.liftBrush();
assert(reload.brushCharge() === spentCharge, 'lifting must not refill the brush while auto-reload is off');
reload.setAutoReload(true);
reload.liftBrush();
assert(reload.brushCharge() === 1, 'auto-reload must fill the brush when the hand lifts');

reload.setAutoReload(false);
for (let i = 0; i < 20 && reload.brushCharge() > .3; i++) {
  reload.liftBrush();
  reload.depositSegment(40, 140, 340, 140, 380, 280, .75, 1, .3, .8, 0);
}
assert(reload.brushCharge() <= .3, 'the brush must actually run low when auto-reload is off');
reload.setAutoReload(true, .4);
reload.liftBrush();
assert(Math.abs(reload.charge / reload.brushCapacity() - .4) < 1e-6,
  'auto-reload must honour how much paint it puts on (' + (reload.charge / reload.brushCapacity()).toFixed(4) + ')');
assert(reload.metrics().pigment_conservation_error < 1, 'auto-reload must not conjure paint');

// Dipping brings paint into the world from the palette, so the ledger has to
// grow by exactly what was taken up. The conservation error alone cannot catch
// this: with nothing yet on the sheet it divides by zero and reads clean.
const ledgerOnDip=new SharedSolver(120,90,PROFILES.oil,SUBSTRATES.coldPress);
ledgerOnDip.setBrush('filbert');
ledgerOnDip.clear(0);
assert(Math.abs(ledgerOnDip.initialPigment-ledgerOnDip.charge)<1e-6,
  'a dipped brush must put its paint on the books ('+ledgerOnDip.initialPigment.toFixed(2)+' on the books, '+ledgerOnDip.charge.toFixed(2)+' on the hair)');
const booksBefore=ledgerOnDip.initialPigment;
ledgerOnDip.charge=0;
const tookUp=ledgerOnDip.dipBrush(1);
assert(Math.abs((ledgerOnDip.initialPigment-booksBefore)-tookUp)<1e-6,
  'a second dip must add exactly what it took up to the books');

// a half dip is half a brush
const half = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
half.setBrush('filbert');
half.clear(0);
half.charge = 0;
half.dipBrush(.5);
assert(Math.abs(half.charge / half.brushCapacity() - .5) < 1e-9, 'a half dip must put exactly half a load on the hair');
// The gauge reads paint the brush can still use, not raw fill. A trace stays
// stuck in the hair and never transfers, so half a load reads a shade under
// half - and, far more usefully, a spent brush reads a true zero.
assert(Math.abs(half.brushCharge() - .5) < .02, 'a half dip must read about half full (' + half.brushCharge().toFixed(4) + ')');
half.charge = half.brushCapacity() * .004;
assert(half.brushCharge() === 0, 'a brush down to the trace in its hair must read empty');

// the disc is bottomless, exactly as every earlier review found it
const bottomless = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
bottomless.clear(0);
assert(!bottomless.hasReservoir(), 'the disc must declare no capacity rather than a fake one');
assert(bottomless.brushCapacity() === Infinity, 'the disc must never run out');
const discLaid = [.25, .36, .47, .58].map((row) => strokeOn(bottomless, row));
assert(discLaid[3] > discLaid[0] * .8, 'the disc must lay the same paint on its fourth stroke as its first');

/* ---- and paint is laid per millimetre, not per contact ------------------ */

// The same gesture used to lay 454 units on a 190-cell grid and 9674 on a
// 570-cell one, purely because a finer grid stamps more contacts along the same
// path. Marks got heavier every time the resolution went up.
const paintFor = (grid, brush) => {
  const height = Math.round(grid * .737);
  const solver = new SharedSolver(grid, height, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush(brush);
  solver.clear(0);
  solver.dipBrush(1);
  solver.charge = Infinity; // measure the gesture, not the reservoir
  solver.depositSegment(grid * 4 * .15, height * 4 * .5, grid * 4 * .85, height * 4 * .5, grid * 4, height * 4, .75, 1, .3, .8, 0);
  return solver.metrics().deposited_pigment;
};
for (const brush of ['disc', 'filbert', 'flat']) {
  const coarse = paintFor(190, brush), fine = paintFor(570, brush);
  assert(fine < coarse * 1.35 && fine > coarse * .7,
    brush + ' must lay about the same paint however fine the grid is (' + coarse.toFixed(0) + ' against ' + fine.toFixed(0) + ')');
}

/* ---- a gesture is a gesture, however fast the pen talks ----------------- */

// Every measurement in this file used to draw one long segment. A real pen
// reports hundreds of points per stroke, and each segment used to lay a contact
// at BOTH ends - so the same gesture laid 522 units drawn as one segment and
// 1092 chopped into four hundred. How hard you appeared to press depended on
// how fast your hardware talked.
const drawnAsPieces = (pieces, brush) => {
  const solver = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush(brush);
  solver.clear(0);
  solver.liftBrush();
  const x0 = 380 * 4 * .15, x1 = 380 * 4 * .85, y = 280 * 4 * .5;
  for (let i = 0; i < pieces; i++)
    solver.depositSegment(x0 + (x1 - x0) * i / pieces, y, x0 + (x1 - x0) * (i + 1) / pieces, y, 380 * 4, 280 * 4, .75, 1, .3, .8, 0);
  return solver.metrics().deposited_pigment;
};

for (const brush of ['disc', 'filbert', 'flat']) {
  const counts = [1, 20, 150, 400, 1000].map((pieces) => drawnAsPieces(pieces, brush));
  const low = Math.min(...counts), high = Math.max(...counts);
  assert(high < low * 1.05,
    brush + ' must lay the same paint however finely the pen reports the stroke (' + counts.map((v) => v.toFixed(0)).join(', ') + ')');
}

// and the reservoir must empty at the same rate for the same gesture
const emptyAfter = (pieces) => {
  const solver = new SharedSolver(380, 280, PROFILES.oil, SUBSTRATES.coldPress);
  solver.setBrush('filbert');
  solver.clear(0);
  solver.liftBrush();
  const x0 = 380 * 4 * .15, x1 = 380 * 4 * .85, y = 280 * 4 * .5;
  for (let i = 0; i < pieces; i++)
    solver.depositSegment(x0 + (x1 - x0) * i / pieces, y, x0 + (x1 - x0) * (i + 1) / pieces, y, 380 * 4, 280 * 4, .75, 1, .3, .8, 0);
  return solver.brushCharge();
};
assert(Math.abs(emptyAfter(1) - emptyAfter(400)) < .03,
  'a brush must run down at the same rate however finely the pen reports (' + emptyAfter(1).toFixed(3) + ' against ' + emptyAfter(400).toFixed(3) + ')');

console.log('shared solver checks passed');
