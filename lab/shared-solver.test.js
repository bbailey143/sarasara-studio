'use strict';

global.window={};
global.document={createElement(){return{width:0,height:0,getContext(){return{createImageData(w,h){return{data:new Uint8ClampedArray(w*h*4)}},putImageData(){}}}}}};
require('./shared-solver.js');

const {SharedSolver,PROFILES}=window.SarasaraLab;
const assert=(condition,message)=>{if(!condition)throw new Error(message)};

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

const prewet=new SharedSolver(48,24,PROFILES.watercolor);
prewet.clear(.8);
assert(prewet.metrics().wet_area_fraction===1,'paper dampness must prepare the full substrate');

const lowWater=new SharedSolver(48,24,PROFILES.watercolor),highWater=new SharedSolver(48,24,PROFILES.watercolor);
lowWater.depositSegment(50,30,70,30,120,60,.5,.6,.1,.5);
highWater.depositSegment(50,30,70,30,120,60,.5,.6,1,.5);
for(let i=0;i<90;i++){lowWater.step(1/60);highWater.step(1/60)}
assert(highWater.metrics().wet_area_fraction>lowWater.metrics().wet_area_fraction,'more brush water must create a larger wet region');

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

console.log('shared solver checks passed');
