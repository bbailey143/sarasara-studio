(function(global){
  'use strict';

  const MATERIAL_REQUIRED=['COMP-001','COMP-003','STATE-001','STATE-003','TRAN-001','DEPO-001','DEPO-004','TRIB-002','EVOL-001','EVOL-003','REAC-001','REAC-002','REAC-003','REAC-004'];
  const SUBSTRATE_REQUIRED=['TRAN-002','SUBI-001','SUBI-003'];
  const MODELS=['MODEL-TRAN-001','MODEL-TRAN-002','MODEL-TRAN-003','MODEL-DEPO-001','MODEL-EVOL-001','MODEL-PART-001','MODEL-REAC-001','MODEL-TRIB-001'];
  const DEFAULT_CALIBRATION=Object.freeze({
    curve:Object.freeze([{x:0,y:0},{x:.33,y:.33},{x:.67,y:.67},{x:1,y:1}]),
    paperTexture:1,particleBreakup:1,smear:1,speed:1
  });

  function clamp01(value){return Math.max(0,Math.min(1,Number(value)||0))}
  function calibrationCopy(source=DEFAULT_CALIBRATION){return{curve:source.curve.map(point=>({x:point.x,y:point.y})),paperTexture:source.paperTexture,particleBreakup:source.particleBreakup,smear:source.smear,speed:source.speed}}
  function validateCalibration(value={}){
    const source=value&&typeof value==='object'?value:{};
    const proposed=Array.isArray(source.curve)&&source.curve.length===4?source.curve:DEFAULT_CALIBRATION.curve;
    const curve=proposed.map((point,index)=>({x:clamp01(point?.x),y:clamp01(point?.y)}));
    curve[0]={x:0,y:0};curve[3]={x:1,y:1};
    curve[1].x=Math.max(.05,Math.min(.9,curve[1].x));
    curve[2].x=Math.max(curve[1].x+.05,Math.min(.95,curve[2].x));
    curve[1].y=Math.min(curve[1].y,curve[2].y);curve[2].y=Math.max(curve[1].y,curve[2].y);
    const multiplier=name=>Math.max(0,Math.min(2,Number.isFinite(Number(source[name]))?Number(source[name]):DEFAULT_CALIBRATION[name]));
    return{curve,paperTexture:multiplier('paperTexture'),particleBreakup:multiplier('particleBreakup'),smear:multiplier('smear'),speed:multiplier('speed')};
  }
  function interpolatePressure(curve,input){
    const pressure=clamp01(input);let segment=curve.length-2;
    for(let index=0;index<curve.length-1;index++)if(pressure<=curve[index+1].x){segment=index;break}
    const spans=[],slopes=[];for(let index=0;index<curve.length-1;index++){spans[index]=Math.max(.0001,curve[index+1].x-curve[index].x);slopes[index]=(curve[index+1].y-curve[index].y)/spans[index]}
    const tangents=new Array(curve.length);tangents[0]=slopes[0];tangents[curve.length-1]=slopes[slopes.length-1];for(let index=1;index<curve.length-1;index++)tangents[index]=slopes[index-1]*slopes[index]<=0?0:(slopes[index-1]+slopes[index])/2;
    for(let index=0;index<slopes.length;index++){if(slopes[index]===0){tangents[index]=0;tangents[index+1]=0;continue}const a=tangents[index]/slopes[index],b=tangents[index+1]/slopes[index],magnitude=a*a+b*b;if(magnitude>9){const scale=3/Math.sqrt(magnitude);tangents[index]=scale*a*slopes[index];tangents[index+1]=scale*b*slopes[index]}}
    const left=curve[segment],right=curve[segment+1],span=spans[segment],t=Math.max(0,Math.min(1,(pressure-left.x)/span)),t2=t*t,t3=t2*t;
    return(2*t3-3*t2+1)*left.y+(t3-2*t2+t)*span*tangents[segment]+(-2*t3+3*t2)*right.y+(t3-t2)*span*tangents[segment+1];
  }

  const SUBSTRATES={
    plain:{id:'substrate.paper.plain-white.archive-seed.v0.2',name:'Plain White',version:'0.2.0',state:{'TRAN-002':0,'SUBI-001':0,'SUBI-003':0},texture:{tooth:0,absorbency:0,sizing:1,capacity:0,dryBrushBreakup:0,seed:0,noiseScale:1,paperColor:'#ffffff'},provenance:[{status:'archive-seed',note:'Values preserved from the legacy Paper.plain preset; v0.2 corrects the shared grain-scale direction; not measured production constants.'}]},
    hotPress:{id:'substrate.paper.hot-press.archive-seed.v0.2',name:'Hot Press',version:'0.2.0',state:{'TRAN-002':.026,'SUBI-001':.15,'SUBI-003':.4},texture:{tooth:.15,absorbency:.3,sizing:.8,capacity:.4,dryBrushBreakup:.15,seed:101,noiseScale:2,paperColor:'#fcfaf7'},provenance:[{status:'archive-seed',note:'Legacy preset values preserved; v0.2 corrects grain-scale direction; permeability remains a normalized diagnostic mapping.'}]},
    coldPress:{id:'substrate.paper.cold-press.archive-seed.v0.2',name:'Cold Press',version:'0.2.0',state:{'TRAN-002':.055,'SUBI-001':.5,'SUBI-003':.5},texture:{tooth:.5,absorbency:.5,sizing:.6,capacity:.5,dryBrushBreakup:.5,seed:42,noiseScale:1,paperColor:'#faf8f5'},provenance:[{status:'archive-seed',note:'Legacy preset values preserved; v0.2 corrects grain-scale direction; permeability remains normalized to the reviewed uptake rate.'}]},
    rough:{id:'substrate.paper.rough.archive-seed.v0.2',name:'Rough Watercolor Paper',version:'0.2.0',state:{'TRAN-002':.073,'SUBI-001':.85,'SUBI-003':.7},texture:{tooth:.85,absorbency:.6,sizing:.5,capacity:.7,dryBrushBreakup:.8,seed:7,noiseScale:.6,paperColor:'#f5f0e8'},provenance:[{status:'archive-seed',note:'Values preserved from the legacy watercolor Paper.rough preset; not approved as a charcoal drawing sheet.'}]},
    pastelWhite:{id:'substrate.paper.pastel-white.reference-derived.experimental.v0.2',name:'Pastel Paper — White',version:'0.2.0',state:{'TRAN-002':.014,'SUBI-001':.18,'SUBI-003':.28},texture:{pattern:'fibrous',tooth:.18,absorbency:.18,sizing:.82,capacity:.28,dryBrushBreakup:.32,seed:811,noiseScale:.2,paperColor:'#eeeeed',visualFiberContrast:5.5},provenance:[{status:'reference-derived',note:'Sample-guided from the artist-supplied 5100 px Pastel White image: sampled mean RGB 238.1/238.0/237.0 and luminance spread 8.81. Color and visible fiber scale are evidence; physical height remains an artist-tested stand-in.'}]},
    pastelCream:{id:'substrate.paper.pastel-light-cream.reference-derived.experimental.v0.2',name:'Pastel Paper — Light Cream',version:'0.2.0',state:{'TRAN-002':.014,'SUBI-001':.18,'SUBI-003':.28},texture:{pattern:'fibrous',tooth:.18,absorbency:.18,sizing:.82,capacity:.28,dryBrushBreakup:.32,seed:811,noiseScale:.2,paperColor:'#eeebdf',visualFiberContrast:6.2},provenance:[{status:'reference-derived',note:'Sample-guided from the artist-supplied 5100 px Pastel Light Cream image: sampled mean RGB 238.1/235.0/223.0 and luminance spread 10.30. Color and visible fiber scale are evidence; physical height remains an artist-tested stand-in.'}]}
  };

  const PROFILES={
    watercolor:{
      id:'material.watercolor.diagnostic.v0.6.1',version:'0.6.1',
      state:{'COMP-001':.88,'COMP-003':.12,'STATE-001':'suspension','STATE-003':0,'TRAN-001':.48,'DEPO-001':.74,'DEPO-004':.42,'TRIB-002':.18,'EVOL-001':.0032,'EVOL-003':.016,'REAC-001':.22,'REAC-002':.58,'REAC-003':.18,'REAC-004':.025},
      display:{pigment_visibility_gain:2.6,note:'Diagnostic preview gain only; does not alter physical pigment mass.'},
      models:MODELS,interactions:['IM-009'],provenance:[{status:'stand-in',note:'Artist-calibrated diagnostic values; not measured production constants.'}]
    },
    charcoal:{
      id:'material.charcoal.diagnostic.v0.6',version:'0.6.0',
      state:{'COMP-001':0,'COMP-003':1,'STATE-001':'powder','STATE-003':0,'TRAN-001':0,'DEPO-001':.68,'DEPO-004':.48,'TRIB-002':.58,'TRIB-003':.34,'TRIB-004':.42,'PART-001':{coarse_fraction:.38,fine_fraction:.62},'PART-002':.72,'PART-003':.46,'EVOL-001':0,'EVOL-003':0,'REAC-001':0,'REAC-002':0,'REAC-003':0,'REAC-004':1},
      models:['MODEL-DEPO-001','MODEL-PART-001','MODEL-TRIB-001'],interactions:['IM-008','IM-009'],provenance:[{status:'stand-in',note:'Artist-recognizable loose, grainy charcoal target. Fracture toughness, abrasion resistance, coarse/fine shares, density, shape, settling, granular capture, optical density, and pressure anchoring are normalized unmeasured stand-ins. v0.6 preserves v0.5.2 high-load anchoring while making dry transfer spatially incomplete and separating the visible density of settled, loose, coarse, and fine populations.'}]
    },
    oil:{
      id:'material.oil.diagnostic.v0.1',version:'0.1.0',
      state:{'COMP-001':.28,'COMP-002':.32,'COMP-003':.4,'COMP-004':0,'STATE-001':'paste','STATE-003':0,'RHEO-001':.82,'RHEO-002':.34,'RHEO-003':.68,'TRAN-001':0,'DEPO-001':.62,'DEPO-003':.28,'DEPO-004':.78,'PART-002':.62,'TRIB-002':.3,'EVOL-001':0,'EVOL-003':0,'REAC-001':0,'REAC-002':0,'REAC-003':0,'REAC-004':1},
      display:{pigment_visibility_gain:1,note:'Diagnostic preview only; relief shading does not alter physical mass.'},
      models:['MODEL-DEPO-001','MODEL-RHEO-003','MODEL-TRIB-001'],interactions:['IM-009'],provenance:[{status:'stand-in',note:'ADR-0002 third-material vocabulary test. Every value is an unmeasured normalized stand-in assembled from existing canonical properties; no new property family was introduced. Yield stress, viscosity, packing, density, and transfer efficiency require artist review before any claim of oil realism.'}]
    }
  };

  function validateProfile(profile){
    const missing=MATERIAL_REQUIRED.filter(id=>profile.state[id]===undefined);
    if(missing.length)throw new Error('Missing canonical properties: '+missing.join(', '));
    for(const id of MATERIAL_REQUIRED){const value=profile.state[id];if(typeof value==='number'&&(!Number.isFinite(value)||value<0))throw new Error('Invalid canonical value for '+id)}
    return profile;
  }
  function validateSubstrate(substrate){const missing=SUBSTRATE_REQUIRED.filter(id=>substrate.state[id]===undefined);if(missing.length)throw new Error('Missing substrate properties: '+missing.join(', '));for(const id of SUBSTRATE_REQUIRED){const value=substrate.state[id];if(typeof value!=='number'||!Number.isFinite(value)||value<0)throw new Error('Invalid substrate value for '+id)}return substrate}

  class SharedSolver{
    constructor(width,height,profile,substrate=SUBSTRATES.coldPress){this.w=width;this.h=height;this.n=width*height;this.surface=document.createElement('canvas');this.surface.width=width;this.surface.height=height;this.sctx=this.surface.getContext('2d');this.image=this.sctx.createImageData(width,height);this.calibration=calibrationCopy();this.substrate=validateSubstrate(substrate);this.s=substrate.state;this.buildPaperSurface();this.setProfile(profile)}
    setCalibration(value){this.calibration=validateCalibration(value);return this.getCalibration()}
    getCalibration(){return calibrationCopy(this.calibration)}
    transformPressure(value){return interpolatePressure(this.calibration.curve,value)}
    calibratedSpeed(value){return Math.max(.1,Math.min(2,.1+(Math.max(.1,Math.min(2,Number(value)||.1))-.1)*this.calibration.speed))}
    setProfile(profile){this.profile=validateProfile(profile);this.p=profile.state;this.displayGain=profile.display?.pigment_visibility_gain||1;this.water=new Float32Array(this.n);this.mobile=new Float32Array(this.n);this.deposited=new Float32Array(this.n);this.loose=new Float32Array(this.n);this.looseVx=new Float32Array(this.n);this.looseVy=new Float32Array(this.n);this.nextLoose=new Float32Array(this.n);this.nextLooseMx=new Float32Array(this.n);this.nextLooseMy=new Float32Array(this.n);this.coarse=new Float32Array(this.n);this.coarseVx=new Float32Array(this.n);this.coarseVy=new Float32Array(this.n);this.nextCoarse=new Float32Array(this.n);this.nextCoarseMx=new Float32Array(this.n);this.nextCoarseMy=new Float32Array(this.n);this.fineDust=new Float32Array(this.n);this.fineDustVx=new Float32Array(this.n);this.fineDustVy=new Float32Array(this.n);this.nextFineDust=new Float32Array(this.n);this.nextFineDustMx=new Float32Array(this.n);this.nextFineDustMy=new Float32Array(this.n);this.absorbed=new Float32Array(this.n);this.nextWater=new Float32Array(this.n);this.nextMobile=new Float32Array(this.n);this.nextDeposited=new Float32Array(this.n);this.initialPigment=0;this.lostPigment=0;this.relocatedPigment=0;this.pressureAnchoredPigment=0;this.sourceOfferedPigment=0;this.sourceRemainingPigment=0;this.coarseCreatedPigment=0;this.fineCreatedPigment=0;this.carriedPigment=0;this.dryBoost=1;this.elapsed=0}
    setSubstrate(substrate){this.substrate=validateSubstrate(substrate);this.s=substrate.state;this.buildPaperSurface()}
    setSmoothing(enabled){this.smoothing=enabled!==false}
    setDisplayGain(value){this.displayGain=Math.max(1,Math.min(12,Number(value)||1))}
    clear(substrateDampness=0){const saturation=this.regime()==='flowing'?Math.max(0,Math.min(1,substrateDampness))*this.s['SUBI-003']:0;this.water.fill(0);this.mobile.fill(0);this.deposited.fill(0);this.loose.fill(0);this.looseVx.fill(0);this.looseVy.fill(0);this.coarse.fill(0);this.coarseVx.fill(0);this.coarseVy.fill(0);this.fineDust.fill(0);this.fineDustVx.fill(0);this.fineDustVy.fill(0);this.absorbed.fill(saturation);this.initialPigment=0;this.lostPigment=0;this.relocatedPigment=0;this.pressureAnchoredPigment=0;this.sourceOfferedPigment=0;this.sourceRemainingPigment=0;this.coarseCreatedPigment=0;this.fineCreatedPigment=0;this.carriedPigment=0;this.dryBoost=1;this.elapsed=0}
    regime(){const yieldStress=Number(this.p['RHEO-002']);if(Number.isFinite(yieldStress)&&yieldStress>0)return'body';return this.p['COMP-001']<.02?'granular':'flowing'}
    hasYieldingBody(){return this.regime()==='body'}
    reliefHeight(index){const packing=Math.max(.05,Math.min(1,Number(this.p['DEPO-004'])||.05)),density=Math.max(.05,Math.min(1,Number(this.p['PART-002'])||.05));return this.deposited[index]/(packing*density)}
    bodyStress(pressure){const thinning=Math.max(0,Math.min(1,Number(this.p['RHEO-003'])||0));return Math.max(0,Math.min(1,pressure))*(1-thinning*.3)}
    flowLayer(dt){
      if(!this.hasYieldingBody())return 0;
      const yieldStress=Math.max(0,Number(this.p['RHEO-002'])||0),viscosity=Math.max(.05,Number(this.p['RHEO-001'])||.05);
      const w=this.w,h=this.h,DP=this.deposited,ND=this.nextDeposited;ND.set(DP);let moved=0;
      const slump=(i,j)=>{const drop=this.reliefHeight(i)-this.reliefHeight(j);if(drop<=0)return;const excess=drop-yieldStress;if(excess<=0)return;const flux=Math.min(DP[i]*.2,excess*dt*.5/viscosity);if(flux<=0)return;ND[i]-=flux;ND[j]+=flux;moved+=flux};
      for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x;if(x<w-1){slump(i,i+1);slump(i+1,i)}if(y<h-1){slump(i,i+w);slump(i+w,i)}}
      DP.set(ND);return moved;
    }
    /** Mass per cell that adheres to the sheet and cannot be pushed off it.
        DEPO-003 is a detachment threshold expressed as a retained relief height. */
    retainedFilmMass(){
      const threshold=Math.max(0,Number(this.p['DEPO-003'])||0);
      if(threshold<=0)return 0;
      const packing=Math.max(.05,Math.min(1,Number(this.p['DEPO-004'])||.05)),density=Math.max(.05,Math.min(1,Number(this.p['PART-002'])||.05));
      return threshold*packing*density;
    }
    /** `sweep` is the share of one footprint crossing this contact represents,
        so the total displaced over a crossing does not depend on sampling rate. */
    /** How readily the tool takes material off the sheet and gives it back.
        Picking up is gated by yield stress; laying down favours emptier ground,
        which is what lets a loaded brush drag colour out onto bare canvas. */
    smearBody(index,pressure,sweep=1){
      if(!this.hasYieldingBody())return 0;
      const yieldStress=Math.max(0,Number(this.p['RHEO-002'])||0),stress=this.bodyStress(pressure);
      const floor=this.retainedFilmMass(),reach=Math.max(0,Math.min(1,sweep));
      let lifted=0;
      if(stress>yieldStress){
        const share=Math.max(0,Math.min(.6,(stress-yieldStress)/Math.max(.05,1-yieldStress)));
        const available=Math.max(0,this.deposited[index]-floor);
        lifted=available*share*reach;
        if(lifted>0){this.deposited[index]-=lifted;this.carriedPigment+=lifted}
      }
      if(this.carriedPigment>0){
        const full=Math.max(1e-9,floor*4),room=Math.max(0,Math.min(1,1-this.deposited[index]/full));
        const laid=this.carriedPigment*Math.min(1,(.02+.12*room)*reach);
        if(laid>0){this.carriedPigment-=laid;this.deposited[index]+=laid;this.relocatedPigment+=laid}
      }
      return lifted;
    }
    hasBrittleParticleSource(){const phase=this.p['STATE-001'],distribution=this.p['PART-001'];return(phase==='powder'||phase==='brittle_solid')&&this.p['COMP-003']>0&&Number.isFinite(this.p['TRIB-003'])&&distribution&&typeof distribution==='object'}
    fractureSplit(pressure,speed,tooth){if(!this.hasBrittleParticleSource())return{coarse:0,fine:0};const clamp=value=>Math.max(0,Math.min(1,value)),packing=clamp(this.p['DEPO-004']),toughness=clamp(this.p['TRIB-003']),abrasion=clamp(this.p['TRIB-004']),normal=clamp(pressure*this.calibration.particleBreakup),sliding=clamp((this.calibratedSpeed(speed)-.1)/1.9),roughness=clamp(this.s['SUBI-001']),distribution=this.p['PART-001'],coarseShare=clamp(Number(distribution.coarse_fraction)||0),fineShare=clamp(Number(distribution.fine_fraction)||0),shareTotal=coarseShare+fineShare||1;const detached=clamp((1-toughness*.65)*(1-abrasion*.4)*(1-packing*.38)*(.08+normal*.52)*(.15+sliding*.5)*(.35+roughness*tooth*.65));return{coarse:detached*coarseShare/shareTotal,fine:detached*fineShare/shareTotal}}
    addParticlePopulation(mass,index,vx,vy,population,vxField,vyField){if(mass<=0)return;const old=population[index],combined=old+mass;vxField[index]=(vxField[index]*old+vx*mass)/combined;vyField[index]=(vyField[index]*old+vy*mass)/combined;population[index]=combined}
    noise(x,y,seed){const v=Math.sin(x*127.1+y*311.7+seed*74.7)*43758.5453123;return v-Math.floor(v)}
    smoothNoise(x,y,seed){const x0=Math.floor(x),y0=Math.floor(y),fx=x-x0,fy=y-y0,u=fx*fx*(3-2*fx),v=fy*fy*(3-2*fy),a=this.noise(x0,y0,seed),b=this.noise(x0+1,y0,seed),c=this.noise(x0,y0+1,seed),d=this.noise(x0+1,y0+1,seed);return(a+(b-a)*u)*(1-v)+(c+(d-c)*u)*v}
    samplePaperSurface(x,y){const a=this.substrate.texture,rough=this.s['SUBI-001'];if(rough<=0)return{height:.5,visual:0};if(a.pattern==='fibrous'){const layer=(angle,along,cross,seed)=>{const c=Math.cos(angle),s=Math.sin(angle),u=x*c+y*s,v=-x*s+y*c,field=this.smoothNoise(u*along,v*cross,seed),ridge=Math.pow(Math.max(0,1-Math.abs(field-.5)*2),7);return ridge};const f1=layer(.18,.055,.72,a.seed+17),f2=layer(1.19,.07,.62,a.seed+71),f3=layer(2.34,.05,.82,a.seed+131),fibers=Math.max(f1,f2*.88,f3*.72),grain=this.smoothNoise(x*.78,y*.78,a.seed+307),natural=.5+(grain-.5)*.18+(fibers-.28)*.16,spread=.22+rough*.58;return{height:Math.max(0,Math.min(1,.5+(natural-.5)*spread*1.45)),visual:fibers-.28}}let total=0,amplitude=.55,norm=0,frequency=Math.max(.025,.11/Math.max(.1,a.noiseScale));for(let octave=0;octave<4;octave++){total+=this.smoothNoise(x*frequency,y*frequency,a.seed+octave*7919)*amplitude;norm+=amplitude;amplitude*=.5;frequency*=2}const natural=total/norm,spread=.28+rough*.72;return{height:Math.max(0,Math.min(1,.5+(natural-.5)*spread*1.65)),visual:0}}
    buildPaperSurface(){this.paperHeight=new Float32Array(this.n);this.paperVisual=new Float32Array(this.n);for(let y=0;y<this.h;y++)for(let x=0;x<this.w;x++){const i=y*this.w+x,sample=this.samplePaperSurface(x,y);this.paperHeight[i]=sample.height;this.paperVisual[i]=sample.visual}}
    tooth(x,y){const ix=Math.max(0,Math.min(this.w-1,Math.round(x))),iy=Math.max(0,Math.min(this.h-1,Math.round(y)));return this.paperHeight[iy*this.w+ix]}
    addDisk(cx,cy,radius,water,pigment,pressure,speed,brushMoisture,strokeX=0,strokeY=0,sweep=1){
      const regime=this.regime(),body=regime==='body',dry=regime==='granular',rough=this.s['SUBI-001'];
      let addedPigment=0;
      const x0=Math.max(0,Math.floor(cx-radius)),x1=Math.min(this.w-1,Math.ceil(cx+radius)),y0=Math.max(0,Math.floor(cy-radius)),y1=Math.min(this.h-1,Math.ceil(cy+radius));
      for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
        const dx=(x-cx)/radius,dy=(y-cy)/radius,q=dx*dx+dy*dy;if(q>1)continue;
        const k=(1-q)*this.p['DEPO-001'],i=y*this.w+x;
        if(body){
          const relief=this.reliefHeight(i),amount=pigment*k/(1+relief*.55);
          this.deposited[i]+=amount;addedPigment+=amount;
          this.smearBody(i,pressure,sweep);
        }
        else if(dry){const tooth=this.tooth(x,y),texturePressure=Math.max(0,Math.min(1,pressure*this.calibration.paperTexture)),gestureSpeed=this.calibratedSpeed(speed),contact=tooth*.72+texturePressure*.48,potential=pigment*k,particleDensity=Math.max(0,Math.min(1,Number(this.p['PART-002'])||0)),shape=Math.max(0,Math.min(1,Number(this.p['PART-003'])||0)),grain=this.noise(x*1.91,y*2.37,this.substrate.texture.seed+1231),coverage=Math.max(.12,Math.min(.92,.02+texturePressure*.34+particleDensity*.18+tooth*.5-shape*.08));this.sourceOfferedPigment+=potential;if(contact<.34||grain>coverage||(gestureSpeed>1.05&&contact<.58&&((x+y)%3===0))){this.sourceRemainingPigment+=potential;continue}const captureVariation=.58+grain*.78,amount=Math.min(potential,potential*(.16+tooth*.32+particleDensity*.14)*captureVariation),split=this.fractureSplit(pressure,speed,tooth),coarseMass=amount*split.coarse,fineMass=amount*split.fine,settledMass=Math.max(0,amount-coarseMass-fineMass),side=this.noise(x,y,this.substrate.texture.seed+997)*2-1,normalX=-strokeY,normalY=strokeX,coarseSpeed=.7+pressure*.85+gestureSpeed*.45,fineSpeed=2+pressure*1.3+gestureSpeed*2.1;this.sourceRemainingPigment+=potential-amount;this.deposited[i]+=settledMass;this.addParticlePopulation(coarseMass,i,strokeX*coarseSpeed+normalX*side*.35,strokeY*coarseSpeed+normalY*side*.35,this.coarse,this.coarseVx,this.coarseVy);this.addParticlePopulation(fineMass,i,strokeX*fineSpeed+normalX*side,strokeY*fineSpeed+normalY*side,this.fineDust,this.fineDustVx,this.fineDustVy);this.coarseCreatedPigment+=coarseMass;this.fineCreatedPigment+=fineMass;addedPigment+=amount}
        else{
          const tooth=this.tooth(x,y),capacity=Math.max(.001,this.s['SUBI-003']),surfaceMobility=Math.max(0,Math.min(1,(this.water[i]+water*k)/.12)),paperMobility=.6*Math.max(0,Math.min(1,this.absorbed[i]/capacity)),contactWetness=1-(1-surfaceMobility)*(1-paperMobility),dryShare=Math.pow(1-contactWetness,1.35);
          const texturePressure=Math.max(0,Math.min(1,pressure*this.calibration.paperTexture)),gestureSpeed=this.calibratedSpeed(speed),toothContact=Math.max(0,Math.min(1,(tooth+texturePressure*.45-.5)/.45)),speedContact=Math.max(.35,Math.min(1,1.08-Math.max(0,gestureSpeed-.4)*.12+pressure*.08)),contact=(1-dryShare)+dryShare*toothContact*speedContact;
          const amount=pigment*k*contact,mobileAmount=amount*contactWetness;
          this.water[i]=Math.min(2.5,this.water[i]+water*k);this.mobile[i]+=mobileAmount;this.deposited[i]+=amount-mobileAmount;addedPigment+=amount;
        }
      }
      this.initialPigment+=addedPigment;
    }
    depositSegment(ax,ay,bx,by,canvasW,canvasH,pressure,pigmentLoad,brushWater,speed){
      pressure=this.transformPressure(pressure);
      const sx=this.w/canvasW,sy=this.h/canvasH,x0=ax*sx,y0=ay*sy,x1=bx*sx,y1=by*sy,d=Math.hypot(x1-x0,y1-y0),steps=Math.max(1,Math.ceil(d/.65));
      const carrier=this.p['COMP-001'],pigmentFraction=this.p['COMP-003'],radius=(1.2+pressure*2.6+brushWater*1.8),regime=this.regime(),water=regime==='body'?0:Math.pow(brushWater,1.85)*.36*carrier;
      const availablePigment=regime==='body'?(.03+pressure*.14)*(pigmentFraction||1):carrier>.02?(.05+pressure*.16)*pigmentFraction:(.012+pressure*.04)*(pigmentFraction||1),pigment=availablePigment*pigmentLoad;
      const ux=d>.001?(x1-x0)/d:0,uy=d>.001?(y1-y0)/d:0;const sweep=radius>0?Math.min(1,(d/Math.max(1,steps))/(2*radius)):1;
      for(let s=0;s<=steps;s++){const t=s/steps;this.addDisk(x0+(x1-x0)*t,y0+(y1-y0)*t,radius,water,pigment,pressure,speed,brushWater,ux,uy,sweep)}
    }
    smudgeSegment(ax,ay,bx,by,canvasW,canvasH,pressure,speed){
      pressure=this.transformPressure(pressure);
      const sx=this.w/canvasW,sy=this.h/canvasH,x0=ax*sx,y0=ay*sy,x1=bx*sx,y1=by*sy,dx=x1-x0,dy=y1-y0,d=Math.hypot(dx,dy);if(d<.001)return 0;
      const ux=dx/d,uy=dy/d,radius=1.4+pressure*2.8,steps=Math.max(1,Math.ceil(d/.55)),contact=new Float32Array(this.n);
      for(let s=0;s<=steps;s++){
        const t=s/steps,cx=x0+dx*t,cy=y0+dy*t,xMin=Math.max(0,Math.floor(cx-radius)),xMax=Math.min(this.w-1,Math.ceil(cx+radius)),yMin=Math.max(0,Math.floor(cy-radius)),yMax=Math.min(this.h-1,Math.ceil(cy+radius));
        for(let y=yMin;y<=yMax;y++)for(let x=xMin;x<=xMax;x++){const q=((x-cx)*(x-cx)+(y-cy)*(y-cy))/(radius*radius);if(q>1)continue;const i=y*this.w+x;contact[i]=Math.max(contact[i],1-q)}
      }
      const source=this.deposited.slice(),sourceLoose=this.loose.slice(),next=this.deposited.slice(),nextLoose=this.loose.slice(),nextLooseVx=this.looseVx.slice(),nextLooseVy=this.looseVy.slice(),friction=this.p['TRIB-002'],packing=Math.max(0,Math.min(1,this.p['DEPO-004'])),roughness=this.s['SUBI-001'],sliding=this.calibratedSpeed(speed),smearPressure=Math.max(0,Math.min(1,pressure*this.calibration.smear)),coupling=Math.min(.72,(.08+friction*.34)*(0.3+smearPressure*.7)*(.45+sliding*.38)*(1-packing*.55)),travel=1+Math.min(3,sliding*1.15+smearPressure*.85),launchSpeed=2.4+sliding*3.2+smearPressure*1.4,normalCompression=Math.max(0,Math.min(1,(smearPressure-.55)/.45));
      let relocated=0;
      for(let i=0;i<this.n;i++){
        const available=source[i]+sourceLoose[i];if(contact[i]<=0||available<=0)continue;
        const x=i%this.w,y=Math.floor(i/this.w),tooth=this.tooth(x,y),toothHold=.65+.35*tooth*roughness,amount=Math.min(available,available*contact[i]*coupling/toothHold);if(amount<=0)continue;
        const tx=Math.max(0,Math.min(this.w-1,Math.round(x+ux*travel))),ty=Math.max(0,Math.min(this.h-1,Math.round(y+uy*travel))),px=-uy,py=ux,lx=Math.max(0,Math.min(this.w-1,Math.round(tx+px))),ly=Math.max(0,Math.min(this.h-1,Math.round(ty+py))),rx=Math.max(0,Math.min(this.w-1,Math.round(tx-px))),ry=Math.max(0,Math.min(this.h-1,Math.round(ty-py)));
        const looseWithdrawal=amount*sourceLoose[i]/available,depositedWithdrawal=amount-looseWithdrawal;next[i]-=depositedWithdrawal;nextLoose[i]-=looseWithdrawal;if(nextLoose[i]<1e-10){nextLoose[i]=0;nextLooseVx[i]=0;nextLooseVy[i]=0}
        const anchoring=normalCompression*Math.min(.55,(.14+friction*.22+roughness*tooth*.32)*(1-packing*.25)),embeddedMass=amount*anchoring,mobileMass=Math.max(0,amount-embeddedMass),split=this.fractureSplit(pressure,speed,tooth),coarseMass=mobileMass*split.coarse,fineMass=mobileMass*split.fine,transported=Math.max(0,mobileMass-coarseMass-fineMass),side=this.noise(x,y,this.substrate.texture.seed+1597)*2-1,target=ty*this.w+tx,left=ly*this.w+lx,right=ry*this.w+rx;
        const launch=(targetIndex,mass,sideBias)=>{if(mass<=0)return;const old=nextLoose[targetIndex],combined=old+mass;nextLooseVx[targetIndex]=(nextLooseVx[targetIndex]*old+(ux*launchSpeed+px*sideBias)*mass)/combined;nextLooseVy[targetIndex]=(nextLooseVy[targetIndex]*old+(uy*launchSpeed+py*sideBias)*mass)/combined;nextLoose[targetIndex]=combined};
        next[target]+=embeddedMass*.7;next[left]+=embeddedMass*.15;next[right]+=embeddedMass*.15;launch(target,transported*.72,0);launch(left,transported*.14,.35);launch(right,transported*.14,-.35);this.addParticlePopulation(coarseMass,target,ux*(launchSpeed*.55)+px*side*.3,uy*(launchSpeed*.55)+py*side*.3,this.coarse,this.coarseVx,this.coarseVy);this.addParticlePopulation(fineMass,target,ux*(launchSpeed*1.15)+px*side*.85,uy*(launchSpeed*1.15)+py*side*.85,this.fineDust,this.fineDustVx,this.fineDustVy);this.coarseCreatedPigment+=coarseMass;this.fineCreatedPigment+=fineMass;this.pressureAnchoredPigment+=embeddedMass;relocated+=amount;
      }
      this.deposited.set(next);this.loose.set(nextLoose);this.looseVx.set(nextLooseVx);this.looseVy.set(nextLooseVy);this.relocatedPigment+=relocated;return relocated;
    }
    stepSurfaceParticles(dt){
      const L=this.loose,VX=this.looseVx,VY=this.looseVy,NL=this.nextLoose,MX=this.nextLooseMx,MY=this.nextLooseMy,DP=this.deposited,w=this.w,h=this.h,friction=this.p['TRIB-002'],packing=Math.max(0,Math.min(1,this.p['DEPO-004'])),roughness=this.s['SUBI-001'];
      NL.fill(0);MX.fill(0);MY.fill(0);const drag=Math.exp(-(1.15+friction*2.2+roughness*.8)*dt);
      const add=(x,y,mass,vx,vy)=>{if(mass<=0)return;const i=y*w+x;NL[i]+=mass;MX[i]+=mass*vx;MY[i]+=mass*vy};
      for(let i=0;i<this.n;i++){
        const mass=L[i];if(mass<=0)continue;const speed=Math.hypot(VX[i],VY[i]),settleRate=.26+packing*.38+roughness*.2+Math.max(0,1-speed)*.42,settled=mass*Math.min(.12,settleRate*dt),moving=mass-settled;DP[i]+=settled;if(moving<=0)continue;
        const vx=VX[i]*drag,vy=VY[i]*drag,x=i%w,y=Math.floor(i/w),nx=Math.max(0,Math.min(w-1,x+vx*dt)),ny=Math.max(0,Math.min(h-1,y+vy*dt)),x0=Math.floor(nx),y0=Math.floor(ny),x1=Math.min(w-1,x0+1),y1=Math.min(h-1,y0+1),fx=nx-x0,fy=ny-y0;
        add(x0,y0,moving*(1-fx)*(1-fy),vx,vy);add(x1,y0,moving*fx*(1-fy),vx,vy);add(x0,y1,moving*(1-fx)*fy,vx,vy);add(x1,y1,moving*fx*fy,vx,vy);
      }
      for(let i=0;i<this.n;i++){L[i]=NL[i];if(NL[i]>0){VX[i]=MX[i]/NL[i];VY[i]=MY[i]/NL[i]}else{VX[i]=0;VY[i]=0}}
    }
    stepDetachedPopulation(dt,population,vxField,vyField,nextPopulation,nextMx,nextMy,kind){
      const w=this.w,h=this.h,roughness=this.s['SUBI-001'],packing=Math.max(0,Math.min(1,this.p['DEPO-004'])),friction=this.p['TRIB-002'],coarse=kind==='coarse',drag=Math.exp(-(coarse?2.6+friction*2.1+roughness*1.3:1.35+friction*1.5+roughness*.75)*dt),settleRate=coarse?1.7+packing*.8+roughness*.8:.28+packing*.28+roughness*.18,settleCap=coarse?.3:.075;nextPopulation.fill(0);nextMx.fill(0);nextMy.fill(0);
      const add=(x,y,mass,vx,vy)=>{if(mass<=0)return;const i=y*w+x;nextPopulation[i]+=mass;nextMx[i]+=mass*vx;nextMy[i]+=mass*vy};
      for(let i=0;i<this.n;i++){
        const mass=population[i];if(mass<=0)continue;const speed=Math.hypot(vxField[i],vyField[i]),settled=mass*Math.min(settleCap,(settleRate+Math.max(0,.8-speed)*(coarse?.8:.08))*dt),moving=mass-settled;this.deposited[i]+=settled;if(moving<=0)continue;
        const vx=vxField[i]*drag,vy=vyField[i]*drag,x=i%w,y=Math.floor(i/w),nx=x+vx*dt,ny=y+vy*dt;if(nx<0||nx>w-1||ny<0||ny>h-1){this.lostPigment+=moving;continue}const x0=Math.floor(nx),y0=Math.floor(ny),x1=Math.min(w-1,x0+1),y1=Math.min(h-1,y0+1),fx=nx-x0,fy=ny-y0;add(x0,y0,moving*(1-fx)*(1-fy),vx,vy);add(x1,y0,moving*fx*(1-fy),vx,vy);add(x0,y1,moving*(1-fx)*fy,vx,vy);add(x1,y1,moving*fx*fy,vx,vy);
      }
      for(let i=0;i<this.n;i++){population[i]=nextPopulation[i];if(nextPopulation[i]>0){vxField[i]=nextMx[i]/nextPopulation[i];vyField[i]=nextMy[i]/nextPopulation[i]}else{vxField[i]=0;vyField[i]=0}}
    }
    step(dt){
      this.elapsed+=dt;this.flowLayer(dt);this.stepSurfaceParticles(dt);this.stepDetachedPopulation(dt,this.coarse,this.coarseVx,this.coarseVy,this.nextCoarse,this.nextCoarseMx,this.nextCoarseMy,'coarse');this.stepDetachedPopulation(dt,this.fineDust,this.fineDustVx,this.fineDustVy,this.nextFineDust,this.nextFineDustMx,this.nextFineDustMy,'fine');const wet=this.p['COMP-001']>.02;if(!wet)return;
      const D=this.p['TRAN-001'],uptake=this.s['TRAN-002']*this.s['SUBI-003'],evap=this.p['EVOL-001']*this.dryBoost*dt*2,settle=this.p['EVOL-003'],rewetRate=this.p['REAC-001'],releaseFraction=this.p['REAC-002'],redispersion=this.p['REAC-003'],reactivationThreshold=this.p['REAC-004'];
      const w=this.w,h=this.h,W=this.water,M=this.mobile,NW=this.nextWater,NM=this.nextMobile,DP=this.deposited,AB=this.absorbed;
      NW.set(W);NM.set(M);
      const exchange=(i,j)=>{const maxWater=Math.max(W[i],W[j]),surfaceMobility=Math.max(0,Math.min(1,(maxWater-.015)/.18));if(surfaceMobility<=0)return;const xi=i%w,yi=Math.floor(i/w),xj=j%w,yj=Math.floor(j/w),valleyConnection=(1-this.tooth(xi,yi))*(1-this.tooth(xj,yj)),paperConductance=.18+.82*valleyConnection*valleyConnection,conductance=paperConductance+(1-paperConductance)*surfaceMobility,fw=D*(W[j]-W[i])*.24*surfaceMobility*conductance;NW[i]+=fw;NW[j]-=fw;let fm=0;if(fw>0&&W[j]>.0001)fm=fw*(M[j]/W[j])*.98;else if(fw<0&&W[i]>.0001)fm=fw*(M[i]/W[i])*.98;const dispersion=D*(M[j]-M[i])*.006*surfaceMobility;fm+=dispersion;NM[i]+=fm;NM[j]-=fm};
      for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x;if(x<w-1)exchange(i,i+1);if(y<h-1)exchange(i,i+w)}
      for(let y=1;y<h-1;y++)for(let x=1;x<w-1;x++){
        const i=y*w+x,avgW=(W[i-1]+W[i+1]+W[i-w]+W[i+w])*.25,outward=Math.max(0,W[i]-avgW),edgeSettle=Math.min(Math.max(0,NM[i]),Math.max(0,NM[i])*(settle*dt*2+outward*.02));NM[i]-=edgeSettle;DP[i]+=edgeSettle;
      }
      for(let i=0;i<this.n;i++){
        let water=Math.max(0,NW[i]);const capacity=this.s['SUBI-003'],room=Math.max(0,capacity-AB[i]),absorbed=Math.min(water,water*uptake*.5,room);water=Math.max(0,water-absorbed-evap);AB[i]=Math.max(0,Math.min(capacity,AB[i]+absorbed-evap*.22));let mobile=Math.max(0,NM[i]);
        if(water>reactivationThreshold&&DP[i]>0){const wetExcess=water-reactivationThreshold,release=Math.min(DP[i],DP[i]*wetExcess*rewetRate*releaseFraction*redispersion*6);DP[i]-=release;mobile+=release}
        if(water<.025&&mobile>0){const fall=Math.min(mobile,mobile*(.08+(1-water/.025)*.22));mobile-=fall;DP[i]+=fall}
        W[i]=water;M[i]=mobile;
      }
      if(this.dryBoost>1)this.dryBoost=Math.max(1,this.dryBoost-dt*4);
    }
    dry(){this.dryBoost=35}
    metrics(){let water=0,mobile=0,deposited=0,loose=0,coarse=0,fine=0,absorbed=0,wetCells=0,pigmentCells=0;for(let i=0;i<this.n;i++){water+=this.water[i];mobile+=this.mobile[i];deposited+=this.deposited[i];loose+=this.loose[i];coarse+=this.coarse[i];fine+=this.fineDust[i];absorbed+=this.absorbed[i];if(this.water[i]>.008||this.absorbed[i]>.008)wetCells++;if(this.mobile[i]+this.deposited[i]+this.loose[i]+this.coarse[i]+this.fineDust[i]>.0001)pigmentCells++}const pigment=mobile+deposited+loose+coarse+fine+this.carriedPigment,error=this.initialPigment?Math.abs(this.initialPigment-pigment-this.lostPigment)/this.initialPigment:0;return{water,wet_area_fraction:wetCells/this.n,pigment_area_fraction:pigmentCells/this.n,mobile_pigment:mobile,deposited_pigment:deposited,settled_pigment:deposited,loose_pigment:loose,coarse_fragment_pigment:coarse,fine_dust_pigment:fine,coarse_fragment_created:this.coarseCreatedPigment,fine_dust_created:this.fineCreatedPigment,source_offered_pigment:this.sourceOfferedPigment,source_remaining_pigment:this.sourceRemainingPigment,lost_off_canvas_pigment:this.lostPigment,absorbed_water:absorbed,carried_pigment:this.carriedPigment,relocated_pigment:this.relocatedPigment,pressure_anchored_pigment:this.pressureAnchoredPigment,pigment_conservation_error:error}}
    render(target,canvas){
      const data=this.image.data,renderRegime=this.regime(),body=renderRegime==='body',dry=renderRegime==='granular';
      for(let i=0;i<this.n;i++){
        const j=i*4,water=this.water[i],mobile=this.mobile[i],deposit=this.deposited[i],loose=this.loose[i],coarse=this.coarse[i],fine=this.fineDust[i],pigment=mobile+deposit+loose+coarse+fine,paperNoise=this.tooth(i%this.w,Math.floor(i/this.w));
        const color=this.substrate.texture.paperColor,base=parseInt(color.slice(1),16),roughness=this.s['SUBI-001'],fiberShade=this.paperVisual[i]*(this.substrate.texture.visualFiberContrast||0),shade=(paperNoise-.5)*(5+roughness*22)-fiberShade;let pr=(base>>16&255)+shade,pg=(base>>8&255)+shade,pb=(base&255)+shade;
        if(body){
          const relief=this.reliefHeight(i),rx=i%this.w,ry=Math.floor(i/this.w);
          const left=rx>0?this.reliefHeight(i-1):relief,up=ry>0?this.reliefHeight(i-this.w):relief;
          const lit=Math.max(-.6,Math.min(.6,((relief-left)+(relief-up))*1.2)),a=1-Math.exp(-deposit*5.4);
          data[j]=pr*(1-a)+Math.max(0,Math.min(255,118+lit*96))*a;
          data[j+1]=pg*(1-a)+Math.max(0,Math.min(255,76+lit*82))*a;
          data[j+2]=pb*(1-a)+Math.max(0,Math.min(255,52+lit*70))*a;
        }
        else if(dry){const packing=Math.max(0,Math.min(1,this.p['DEPO-004'])),density=Math.max(0,Math.min(1,Number(this.p['PART-002'])||0)),opticalPigment=deposit*(.72+packing*.7)+loose*.58+coarse*(.78+density*.45)+fine*.42,a=1-Math.exp(-opticalPigment*4.2);data[j]=pr*(1-a)+32*a;data[j+1]=pg*(1-a)+28*a;data[j+2]=pb*(1-a)+24*a}
        else{const a=Math.min(.74,1-Math.exp(-pigment*.78*this.displayGain)),wetGlow=Math.min(.045,water*.018);data[j]=pr*(1-a)+44*a;data[j+1]=pg*(1-a)+105*a;data[j+2]=pb*(1-a)+158*a;data[j]=data[j]*(1-wetGlow)+220*wetGlow;data[j+1]=data[j+1]*(1-wetGlow)+236*wetGlow;data[j+2]=data[j+2]*(1-wetGlow)+245*wetGlow}
        data[j+3]=255;
      }
      this.sctx.putImageData(this.image,0,0);target.save();target.imageSmoothingEnabled=this.smoothing!==false;target.clearRect(0,0,canvas.width,canvas.height);target.drawImage(this.surface,0,0,canvas.width,canvas.height);target.restore();
    }
  }

  global.SarasaraLab={SharedSolver,PROFILES,SUBSTRATES,DEFAULT_CALIBRATION:calibrationCopy(),validateCalibration,interpolatePressure,validateProfile,validateSubstrate};
})(window);
