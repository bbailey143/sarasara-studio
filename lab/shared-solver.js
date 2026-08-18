(function(global){
  'use strict';

  const REQUIRED=['COMP-001','COMP-003','STATE-001','TRAN-001','TRAN-002','DEPO-001','SUBI-001','SUBI-003','EVOL-001','EVOL-003','REAC-001','REAC-002','REAC-003','REAC-004'];
  const MODELS=['MODEL-TRAN-001','MODEL-TRAN-002','MODEL-TRAN-003','MODEL-DEPO-001','MODEL-EVOL-001','MODEL-PART-001','MODEL-REAC-001'];

  const PROFILES={
    watercolor:{
      id:'material.watercolor.diagnostic.v0.4',version:'0.4.0',
      state:{'COMP-001':.88,'COMP-003':.12,'STATE-001':'suspension','TRAN-001':.48,'TRAN-002':.055,'DEPO-001':.74,'SUBI-001':.28,'SUBI-003':.64,'EVOL-001':.0032,'EVOL-003':.016,'REAC-001':.22,'REAC-002':.58,'REAC-003':.18,'REAC-004':.025},
      display:{pigment_visibility_gain:2.6,note:'Diagnostic preview gain only; does not alter physical pigment mass.'},
      models:MODELS,provenance:[{status:'stand-in',note:'Artist-calibrated diagnostic values; not measured production constants.'}]
    },
    charcoal:{
      id:'material.charcoal.diagnostic.v0.2',version:'0.2.0',
      state:{'COMP-001':0,'COMP-003':1,'STATE-001':'powder','TRAN-001':0,'TRAN-002':0,'DEPO-001':.68,'SUBI-001':.82,'SUBI-003':.45,'EVOL-001':0,'EVOL-003':0,'REAC-001':0,'REAC-002':0,'REAC-003':0,'REAC-004':1},
      models:['MODEL-DEPO-001'],provenance:[{status:'stand-in',note:'Artist-recognizable diagnostic profile; further calibration required.'}]
    }
  };

  function validateProfile(profile){
    const missing=REQUIRED.filter(id=>profile.state[id]===undefined);
    if(missing.length)throw new Error('Missing canonical properties: '+missing.join(', '));
    for(const id of REQUIRED){const value=profile.state[id];if(typeof value==='number'&&(!Number.isFinite(value)||value<0))throw new Error('Invalid canonical value for '+id)}
    return profile;
  }

  class SharedSolver{
    constructor(width,height,profile){this.w=width;this.h=height;this.n=width*height;this.surface=document.createElement('canvas');this.surface.width=width;this.surface.height=height;this.sctx=this.surface.getContext('2d');this.image=this.sctx.createImageData(width,height);this.setProfile(profile)}
    setProfile(profile){this.profile=validateProfile(profile);this.p=profile.state;this.displayGain=profile.display?.pigment_visibility_gain||1;this.water=new Float32Array(this.n);this.mobile=new Float32Array(this.n);this.deposited=new Float32Array(this.n);this.absorbed=new Float32Array(this.n);this.nextWater=new Float32Array(this.n);this.nextMobile=new Float32Array(this.n);this.initialPigment=0;this.lostPigment=0;this.dryBoost=1;this.elapsed=0}
    setDisplayGain(value){this.displayGain=Math.max(1,Math.min(12,Number(value)||1))}
    clear(substrateDampness=0){const initialWater=this.p['COMP-001']>.02?Math.max(0,Math.min(1,substrateDampness))*.12:0;this.water.fill(initialWater);this.mobile.fill(0);this.deposited.fill(0);this.absorbed.fill(0);this.initialPigment=0;this.lostPigment=0;this.dryBoost=1;this.elapsed=0}
    tooth(x,y){return Math.max(0,Math.min(1,(Math.sin(x*.73+y*1.31)+Math.sin(x*.19-y*.41)+2)/4))}
    addDisk(cx,cy,radius,water,pigment,pressure,speed){
      const dry=this.p['COMP-001']<.02,rough=this.p['SUBI-001'];
      let addedPigment=0;
      const x0=Math.max(0,Math.floor(cx-radius)),x1=Math.min(this.w-1,Math.ceil(cx+radius)),y0=Math.max(0,Math.floor(cy-radius)),y1=Math.min(this.h-1,Math.ceil(cy+radius));
      for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
        const dx=(x-cx)/radius,dy=(y-cy)/radius,q=dx*dx+dy*dy;if(q>1)continue;
        const k=(1-q)*this.p['DEPO-001'],i=y*this.w+x;
        if(dry){const tooth=this.tooth(x,y),contact=tooth*.72+pressure*.48;if(contact<.34||(speed>1.05&&contact<.58&&((x+y)%3===0)))continue;const amount=pigment*k*(.35+rough*tooth);this.deposited[i]+=amount;addedPigment+=amount}
        else{const amount=pigment*k;this.water[i]=Math.min(2.5,this.water[i]+water*k);this.mobile[i]+=amount;addedPigment+=amount}
      }
      this.initialPigment+=addedPigment;
    }
    depositSegment(ax,ay,bx,by,canvasW,canvasH,pressure,pigmentLoad,brushWater,speed){
      const sx=this.w/canvasW,sy=this.h/canvasH,x0=ax*sx,y0=ay*sy,x1=bx*sx,y1=by*sy,d=Math.hypot(x1-x0,y1-y0),steps=Math.max(1,Math.ceil(d/.65));
      const carrier=this.p['COMP-001'],pigmentFraction=this.p['COMP-003'],radius=(1.2+pressure*2.6+brushWater*1.8),water=(.02+brushWater*.34)*carrier;
      const availablePigment=carrier>.02?(.05+pressure*.16)*pigmentFraction:(.012+pressure*.04)*(pigmentFraction||1),pigment=availablePigment*pigmentLoad;
      for(let s=0;s<=steps;s++){const t=s/steps;this.addDisk(x0+(x1-x0)*t,y0+(y1-y0)*t,radius,water,pigment,pressure,speed)}
    }
    step(dt){
      this.elapsed+=dt;const wet=this.p['COMP-001']>.02;if(!wet)return;
      const D=this.p['TRAN-001'],uptake=this.p['TRAN-002']*this.p['SUBI-003'],evap=this.p['EVOL-001']*this.dryBoost*dt*2,settle=this.p['EVOL-003'],rewetRate=this.p['REAC-001'],releaseFraction=this.p['REAC-002'],redispersion=this.p['REAC-003'],reactivationThreshold=this.p['REAC-004'];
      const w=this.w,h=this.h,W=this.water,M=this.mobile,NW=this.nextWater,NM=this.nextMobile,DP=this.deposited,AB=this.absorbed;
      NW.set(W);NM.set(M);
      const exchange=(i,j)=>{const fw=D*(W[j]-W[i])*.24;NW[i]+=fw;NW[j]-=fw;let fm=0;if(fw>0&&W[j]>.0001)fm=fw*(M[j]/W[j])*.98;else if(fw<0&&W[i]>.0001)fm=fw*(M[i]/W[i])*.98;const dispersion=D*(M[j]-M[i])*.006;fm+=dispersion;NM[i]+=fm;NM[j]-=fm};
      for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x;if(x<w-1)exchange(i,i+1);if(y<h-1)exchange(i,i+w)}
      for(let y=1;y<h-1;y++)for(let x=1;x<w-1;x++){
        const i=y*w+x,avgW=(W[i-1]+W[i+1]+W[i-w]+W[i+w])*.25,outward=Math.max(0,W[i]-avgW),edgeSettle=Math.min(Math.max(0,NM[i]),Math.max(0,NM[i])*(settle*dt*2+outward*.02));NM[i]-=edgeSettle;DP[i]+=edgeSettle;
      }
      for(let i=0;i<this.n;i++){
        let water=Math.max(0,NW[i]);const absorbed=Math.min(water,water*uptake*.018);water=Math.max(0,water-absorbed-evap);AB[i]=Math.min(1,AB[i]+absorbed);let mobile=Math.max(0,NM[i]);
        if(water>reactivationThreshold&&DP[i]>0){const wetExcess=water-reactivationThreshold,release=Math.min(DP[i],DP[i]*wetExcess*rewetRate*releaseFraction*redispersion*6);DP[i]-=release;mobile+=release}
        if(water<.025&&mobile>0){const fall=Math.min(mobile,mobile*(.08+(1-water/.025)*.22));mobile-=fall;DP[i]+=fall}
        W[i]=water;M[i]=mobile;
      }
      if(this.dryBoost>1)this.dryBoost=Math.max(1,this.dryBoost-dt*4);
    }
    dry(){this.dryBoost=35}
    metrics(){let water=0,mobile=0,deposited=0,absorbed=0,wetCells=0,pigmentCells=0;for(let i=0;i<this.n;i++){water+=this.water[i];mobile+=this.mobile[i];deposited+=this.deposited[i];absorbed+=this.absorbed[i];if(this.water[i]>.008)wetCells++;if(this.mobile[i]+this.deposited[i]>.0001)pigmentCells++}const pigment=mobile+deposited,error=this.initialPigment?Math.abs(this.initialPigment-pigment-this.lostPigment)/this.initialPigment:0;return{water,wet_area_fraction:wetCells/this.n,pigment_area_fraction:pigmentCells/this.n,mobile_pigment:mobile,deposited_pigment:deposited,absorbed_water:absorbed,pigment_conservation_error:error}}
    render(target,canvas){
      const data=this.image.data,dry=this.p['COMP-001']<.02;
      for(let i=0;i<this.n;i++){
        const j=i*4,water=this.water[i],mobile=this.mobile[i],deposit=this.deposited[i],pigment=mobile+deposit,paperNoise=this.tooth(i%this.w,Math.floor(i/this.w));
        let pr=249-(paperNoise-.5)*4,pg=245-(paperNoise-.5)*3,pb=235-(paperNoise-.5)*2;
        if(dry){const a=1-Math.exp(-pigment*2.5);data[j]=pr*(1-a)+32*a;data[j+1]=pg*(1-a)+28*a;data[j+2]=pb*(1-a)+24*a}
        else{const a=Math.min(.74,1-Math.exp(-pigment*.78*this.displayGain)),wetGlow=Math.min(.045,water*.018);data[j]=pr*(1-a)+44*a;data[j+1]=pg*(1-a)+105*a;data[j+2]=pb*(1-a)+158*a;data[j]=data[j]*(1-wetGlow)+220*wetGlow;data[j+1]=data[j+1]*(1-wetGlow)+236*wetGlow;data[j+2]=data[j+2]*(1-wetGlow)+245*wetGlow}
        data[j+3]=255;
      }
      this.sctx.putImageData(this.image,0,0);target.save();target.imageSmoothingEnabled=true;target.clearRect(0,0,canvas.width,canvas.height);target.drawImage(this.surface,0,0,canvas.width,canvas.height);target.restore();
    }
  }

  global.SarasaraLab={SharedSolver,PROFILES,validateProfile};
})(window);
