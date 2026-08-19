(function(global){
  'use strict';

  const MATERIAL_REQUIRED=['COMP-001','COMP-003','STATE-001','STATE-003','TRAN-001','DEPO-001','DEPO-004','TRIB-002','EVOL-001','EVOL-003','REAC-001','REAC-002','REAC-003','REAC-004'];
  const SUBSTRATE_REQUIRED=['TRAN-002','SUBI-001','SUBI-003'];
  const MODELS=['MODEL-TRAN-001','MODEL-TRAN-002','MODEL-TRAN-003','MODEL-DEPO-001','MODEL-EVOL-001','MODEL-PART-001','MODEL-REAC-001','MODEL-TRIB-001'];

  const SUBSTRATES={
    plain:{id:'substrate.paper.plain-white.archive-seed.v0.2',name:'Plain White',version:'0.2.0',state:{'TRAN-002':0,'SUBI-001':0,'SUBI-003':0},archive:{tooth:0,absorbency:0,sizing:1,capacity:0,dryBrushBreakup:0,seed:0,noiseScale:1,paperColor:'#ffffff'},provenance:[{status:'archive-seed',note:'Values preserved from the legacy Paper.plain preset; v0.2 corrects the shared grain-scale direction; not measured production constants.'}]},
    hotPress:{id:'substrate.paper.hot-press.archive-seed.v0.2',name:'Hot Press',version:'0.2.0',state:{'TRAN-002':.026,'SUBI-001':.15,'SUBI-003':.4},archive:{tooth:.15,absorbency:.3,sizing:.8,capacity:.4,dryBrushBreakup:.15,seed:101,noiseScale:2,paperColor:'#fcfaf7'},provenance:[{status:'archive-seed',note:'Legacy preset values preserved; v0.2 corrects grain-scale direction; permeability remains a normalized diagnostic mapping.'}]},
    coldPress:{id:'substrate.paper.cold-press.archive-seed.v0.2',name:'Cold Press',version:'0.2.0',state:{'TRAN-002':.055,'SUBI-001':.5,'SUBI-003':.5},archive:{tooth:.5,absorbency:.5,sizing:.6,capacity:.5,dryBrushBreakup:.5,seed:42,noiseScale:1,paperColor:'#faf8f5'},provenance:[{status:'archive-seed',note:'Legacy preset values preserved; v0.2 corrects grain-scale direction; permeability remains normalized to the reviewed uptake rate.'}]},
    rough:{id:'substrate.paper.rough.archive-seed.v0.2',name:'Rough',version:'0.2.0',state:{'TRAN-002':.073,'SUBI-001':.85,'SUBI-003':.7},archive:{tooth:.85,absorbency:.6,sizing:.5,capacity:.7,dryBrushBreakup:.8,seed:7,noiseScale:.6,paperColor:'#f5f0e8'},provenance:[{status:'archive-seed',note:'Legacy preset values preserved; v0.2 fixes the inverted scale so Rough has fine tooth; artist revalidation required.'}]}
  };

  const PROFILES={
    watercolor:{
      id:'material.watercolor.diagnostic.v0.6.1',version:'0.6.1',
      state:{'COMP-001':.88,'COMP-003':.12,'STATE-001':'suspension','STATE-003':0,'TRAN-001':.48,'DEPO-001':.74,'DEPO-004':.42,'TRIB-002':.18,'EVOL-001':.0032,'EVOL-003':.016,'REAC-001':.22,'REAC-002':.58,'REAC-003':.18,'REAC-004':.025},
      display:{pigment_visibility_gain:2.6,note:'Diagnostic preview gain only; does not alter physical pigment mass.'},
      models:MODELS,interactions:['IM-009'],provenance:[{status:'stand-in',note:'Artist-calibrated diagnostic values; not measured production constants.'}]
    },
    charcoal:{
      id:'material.charcoal.diagnostic.v0.4',version:'0.4.0',
      state:{'COMP-001':0,'COMP-003':1,'STATE-001':'powder','STATE-003':0,'TRAN-001':0,'DEPO-001':.68,'DEPO-004':.48,'TRIB-002':.58,'EVOL-001':0,'EVOL-003':0,'REAC-001':0,'REAC-002':0,'REAC-003':0,'REAC-004':1},
      models:['MODEL-DEPO-001','MODEL-PART-001','MODEL-TRIB-001'],interactions:['IM-009'],provenance:[{status:'stand-in',note:'Artist-recognizable diagnostic profile; friction, packing, and loose-particle settling require artist calibration.'}]
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
    constructor(width,height,profile,substrate=SUBSTRATES.coldPress){this.w=width;this.h=height;this.n=width*height;this.surface=document.createElement('canvas');this.surface.width=width;this.surface.height=height;this.sctx=this.surface.getContext('2d');this.image=this.sctx.createImageData(width,height);this.substrate=validateSubstrate(substrate);this.s=substrate.state;this.setProfile(profile)}
    setProfile(profile){this.profile=validateProfile(profile);this.p=profile.state;this.displayGain=profile.display?.pigment_visibility_gain||1;this.water=new Float32Array(this.n);this.mobile=new Float32Array(this.n);this.deposited=new Float32Array(this.n);this.loose=new Float32Array(this.n);this.looseVx=new Float32Array(this.n);this.looseVy=new Float32Array(this.n);this.nextLoose=new Float32Array(this.n);this.nextLooseMx=new Float32Array(this.n);this.nextLooseMy=new Float32Array(this.n);this.absorbed=new Float32Array(this.n);this.nextWater=new Float32Array(this.n);this.nextMobile=new Float32Array(this.n);this.initialPigment=0;this.lostPigment=0;this.relocatedPigment=0;this.dryBoost=1;this.elapsed=0}
    setSubstrate(substrate){this.substrate=validateSubstrate(substrate);this.s=substrate.state}
    setDisplayGain(value){this.displayGain=Math.max(1,Math.min(12,Number(value)||1))}
    clear(substrateDampness=0){const saturation=this.p['COMP-001']>.02?Math.max(0,Math.min(1,substrateDampness))*this.s['SUBI-003']:0;this.water.fill(0);this.mobile.fill(0);this.deposited.fill(0);this.loose.fill(0);this.looseVx.fill(0);this.looseVy.fill(0);this.absorbed.fill(saturation);this.initialPigment=0;this.lostPigment=0;this.relocatedPigment=0;this.dryBoost=1;this.elapsed=0}
    noise(x,y,seed){const v=Math.sin(x*127.1+y*311.7+seed*74.7)*43758.5453123;return v-Math.floor(v)}
    smoothNoise(x,y,seed){const x0=Math.floor(x),y0=Math.floor(y),fx=x-x0,fy=y-y0,u=fx*fx*(3-2*fx),v=fy*fy*(3-2*fy),a=this.noise(x0,y0,seed),b=this.noise(x0+1,y0,seed),c=this.noise(x0,y0+1,seed),d=this.noise(x0+1,y0+1,seed);return(a+(b-a)*u)*(1-v)+(c+(d-c)*u)*v}
    tooth(x,y){const a=this.substrate.archive,rough=this.s['SUBI-001'];if(rough<=0)return .5;let total=0,amplitude=.55,norm=0,frequency=Math.max(.025,.11/Math.max(.1,a.noiseScale));for(let octave=0;octave<4;octave++){total+=this.smoothNoise(x*frequency,y*frequency,a.seed+octave*7919)*amplitude;norm+=amplitude;amplitude*=.5;frequency*=2}const natural=total/norm,spread=.28+rough*.72;return Math.max(0,Math.min(1,.5+(natural-.5)*spread*1.65))}
    addDisk(cx,cy,radius,water,pigment,pressure,speed,brushMoisture){
      const dry=this.p['COMP-001']<.02,rough=this.s['SUBI-001'];
      let addedPigment=0;
      const x0=Math.max(0,Math.floor(cx-radius)),x1=Math.min(this.w-1,Math.ceil(cx+radius)),y0=Math.max(0,Math.floor(cy-radius)),y1=Math.min(this.h-1,Math.ceil(cy+radius));
      for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
        const dx=(x-cx)/radius,dy=(y-cy)/radius,q=dx*dx+dy*dy;if(q>1)continue;
        const k=(1-q)*this.p['DEPO-001'],i=y*this.w+x;
        if(dry){const tooth=this.tooth(x,y),contact=tooth*.72+pressure*.48;if(contact<.34||(speed>1.05&&contact<.58&&((x+y)%3===0)))continue;const amount=pigment*k*(.35+rough*tooth);this.deposited[i]+=amount;addedPigment+=amount}
        else{
          const tooth=this.tooth(x,y),capacity=Math.max(.001,this.s['SUBI-003']),surfaceMobility=Math.max(0,Math.min(1,(this.water[i]+water*k)/.12)),paperMobility=.6*Math.max(0,Math.min(1,this.absorbed[i]/capacity)),contactWetness=1-(1-surfaceMobility)*(1-paperMobility),dryShare=Math.pow(1-contactWetness,1.35);
          const toothContact=Math.max(0,Math.min(1,(tooth+pressure*.45-.5)/.45)),speedContact=Math.max(.35,Math.min(1,1.08-Math.max(0,speed-.4)*.12+pressure*.08)),contact=(1-dryShare)+dryShare*toothContact*speedContact;
          const amount=pigment*k*contact,mobileAmount=amount*contactWetness;
          this.water[i]=Math.min(2.5,this.water[i]+water*k);this.mobile[i]+=mobileAmount;this.deposited[i]+=amount-mobileAmount;addedPigment+=amount;
        }
      }
      this.initialPigment+=addedPigment;
    }
    depositSegment(ax,ay,bx,by,canvasW,canvasH,pressure,pigmentLoad,brushWater,speed){
      const sx=this.w/canvasW,sy=this.h/canvasH,x0=ax*sx,y0=ay*sy,x1=bx*sx,y1=by*sy,d=Math.hypot(x1-x0,y1-y0),steps=Math.max(1,Math.ceil(d/.65));
      const carrier=this.p['COMP-001'],pigmentFraction=this.p['COMP-003'],radius=(1.2+pressure*2.6+brushWater*1.8),water=Math.pow(brushWater,1.85)*.36*carrier;
      const availablePigment=carrier>.02?(.05+pressure*.16)*pigmentFraction:(.012+pressure*.04)*(pigmentFraction||1),pigment=availablePigment*pigmentLoad;
      for(let s=0;s<=steps;s++){const t=s/steps;this.addDisk(x0+(x1-x0)*t,y0+(y1-y0)*t,radius,water,pigment,pressure,speed,brushWater)}
    }
    smudgeSegment(ax,ay,bx,by,canvasW,canvasH,pressure,speed){
      const sx=this.w/canvasW,sy=this.h/canvasH,x0=ax*sx,y0=ay*sy,x1=bx*sx,y1=by*sy,dx=x1-x0,dy=y1-y0,d=Math.hypot(dx,dy);if(d<.001)return 0;
      const ux=dx/d,uy=dy/d,radius=1.4+pressure*2.8,steps=Math.max(1,Math.ceil(d/.55)),contact=new Float32Array(this.n);
      for(let s=0;s<=steps;s++){
        const t=s/steps,cx=x0+dx*t,cy=y0+dy*t,xMin=Math.max(0,Math.floor(cx-radius)),xMax=Math.min(this.w-1,Math.ceil(cx+radius)),yMin=Math.max(0,Math.floor(cy-radius)),yMax=Math.min(this.h-1,Math.ceil(cy+radius));
        for(let y=yMin;y<=yMax;y++)for(let x=xMin;x<=xMax;x++){const q=((x-cx)*(x-cx)+(y-cy)*(y-cy))/(radius*radius);if(q>1)continue;const i=y*this.w+x;contact[i]=Math.max(contact[i],1-q)}
      }
      const source=this.deposited.slice(),next=this.deposited.slice(),friction=this.p['TRIB-002'],packing=Math.max(0,Math.min(1,this.p['DEPO-004'])),roughness=this.s['SUBI-001'],sliding=Math.max(.1,Math.min(2,speed)),coupling=Math.min(.72,(.08+friction*.34)*(0.3+pressure*.7)*(.45+sliding*.38)*(1-packing*.55)),travel=1+Math.min(3,sliding*1.15+pressure*.85),launchSpeed=2.4+sliding*3.2+pressure*1.4;
      let relocated=0;
      for(let i=0;i<this.n;i++){
        if(contact[i]<=0||source[i]<=0)continue;
        const x=i%this.w,y=Math.floor(i/this.w),toothHold=.65+.35*this.tooth(x,y)*roughness,amount=Math.min(source[i],source[i]*contact[i]*coupling/toothHold);if(amount<=0)continue;
        const tx=Math.max(0,Math.min(this.w-1,Math.round(x+ux*travel))),ty=Math.max(0,Math.min(this.h-1,Math.round(y+uy*travel))),px=-uy,py=ux,lx=Math.max(0,Math.min(this.w-1,Math.round(tx+px))),ly=Math.max(0,Math.min(this.h-1,Math.round(ty+py))),rx=Math.max(0,Math.min(this.w-1,Math.round(tx-px))),ry=Math.max(0,Math.min(this.h-1,Math.round(ty-py)));
        next[i]-=amount;
        const launch=(targetIndex,mass,sideBias)=>{const old=this.loose[targetIndex],combined=old+mass;if(combined<=0)return;this.looseVx[targetIndex]=(this.looseVx[targetIndex]*old+(ux*launchSpeed+px*sideBias)*mass)/combined;this.looseVy[targetIndex]=(this.looseVy[targetIndex]*old+(uy*launchSpeed+py*sideBias)*mass)/combined;this.loose[targetIndex]=combined};
        launch(ty*this.w+tx,amount*.72,0);launch(ly*this.w+lx,amount*.14,.35);launch(ry*this.w+rx,amount*.14,-.35);relocated+=amount;
      }
      this.deposited.set(next);this.relocatedPigment+=relocated;return relocated;
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
    step(dt){
      this.elapsed+=dt;this.stepSurfaceParticles(dt);const wet=this.p['COMP-001']>.02;if(!wet)return;
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
    metrics(){let water=0,mobile=0,deposited=0,loose=0,absorbed=0,wetCells=0,pigmentCells=0;for(let i=0;i<this.n;i++){water+=this.water[i];mobile+=this.mobile[i];deposited+=this.deposited[i];loose+=this.loose[i];absorbed+=this.absorbed[i];if(this.water[i]>.008||this.absorbed[i]>.008)wetCells++;if(this.mobile[i]+this.deposited[i]+this.loose[i]>.0001)pigmentCells++}const pigment=mobile+deposited+loose,error=this.initialPigment?Math.abs(this.initialPigment-pigment-this.lostPigment)/this.initialPigment:0;return{water,wet_area_fraction:wetCells/this.n,pigment_area_fraction:pigmentCells/this.n,mobile_pigment:mobile,deposited_pigment:deposited,loose_pigment:loose,absorbed_water:absorbed,relocated_pigment:this.relocatedPigment,pigment_conservation_error:error}}
    render(target,canvas){
      const data=this.image.data,dry=this.p['COMP-001']<.02;
      for(let i=0;i<this.n;i++){
        const j=i*4,water=this.water[i],mobile=this.mobile[i],deposit=this.deposited[i],loose=this.loose[i],pigment=mobile+deposit+loose,paperNoise=this.tooth(i%this.w,Math.floor(i/this.w));
        const color=this.substrate.archive.paperColor,base=parseInt(color.slice(1),16),roughness=this.s['SUBI-001'],shade=(paperNoise-.5)*(5+roughness*22);let pr=(base>>16&255)+shade,pg=(base>>8&255)+shade,pb=(base&255)+shade;
        if(dry){const a=1-Math.exp(-pigment*2.5);data[j]=pr*(1-a)+32*a;data[j+1]=pg*(1-a)+28*a;data[j+2]=pb*(1-a)+24*a}
        else{const a=Math.min(.74,1-Math.exp(-pigment*.78*this.displayGain)),wetGlow=Math.min(.045,water*.018);data[j]=pr*(1-a)+44*a;data[j+1]=pg*(1-a)+105*a;data[j+2]=pb*(1-a)+158*a;data[j]=data[j]*(1-wetGlow)+220*wetGlow;data[j+1]=data[j+1]*(1-wetGlow)+236*wetGlow;data[j+2]=data[j+2]*(1-wetGlow)+245*wetGlow}
        data[j+3]=255;
      }
      this.sctx.putImageData(this.image,0,0);target.save();target.imageSmoothingEnabled=true;target.clearRect(0,0,canvas.width,canvas.height);target.drawImage(this.surface,0,0,canvas.width,canvas.height);target.restore();
    }
  }

  global.SarasaraLab={SharedSolver,PROFILES,SUBSTRATES,validateProfile,validateSubstrate};
})(window);
