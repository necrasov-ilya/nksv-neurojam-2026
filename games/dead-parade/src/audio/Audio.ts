import type { Effect, Snapshot } from '../core/model';

export class AudioSys {
  private context: AudioContext | null = null;
  private master: GainNode | null = null;
  private music: GainNode | null = null;
  private sfx: GainNode | null = null;
  private noise: AudioBuffer | null = null;
  private timer = 0;
  private beat = 0;
  private ambience = 0;
  private voices = 0;
  private volumes = {master:0.65,music:0.4,sfx:0.7};

  async unlock(): Promise<void> {
    if (!this.context) {
      this.context = new AudioContext();
      this.master = this.context.createGain();
      this.music = this.context.createGain();
      this.sfx = this.context.createGain();
      this.music.connect(this.master); this.sfx.connect(this.master); this.master.connect(this.context.destination);
      this.noise = this.context.createBuffer(1, this.context.sampleRate, this.context.sampleRate);
      const samples = this.noise.getChannelData(0);
      for(let i=0;i<samples.length;i++) samples[i]=Math.random()*2-1;
      this.configure(this.volumes);
    }
    await this.context.resume();
  }

  configure(values:{master:number;music:number;sfx:number}):void {
    this.volumes = {master:values.master,music:values.music,sfx:values.sfx};
    if (!this.context) return;
    for(const [node,value] of [[this.master,values.master],[this.music,values.music],[this.sfx,values.sfx]] as const) {
      node?.gain.setTargetAtTime(Math.max(0,Math.min(1,value)),this.context.currentTime,.03);
    }
  }

  private play(frequency:number,duration:number,volume:number,type:OscillatorType,noise=false,musical=false,pan=0,endFrequency=frequency):void {
    const ctx=this.context, bus=musical?this.music:this.sfx;
    if(!ctx||!bus||ctx.state!=='running'||this.voices>=36) return;
    const gain=ctx.createGain(), stereo=ctx.createStereoPanner();
    const source=noise?ctx.createBufferSource():ctx.createOscillator();
    if(source instanceof OscillatorNode) {source.type=type;source.frequency.setValueAtTime(Math.max(20,frequency),ctx.currentTime);source.frequency.exponentialRampToValueAtTime(Math.max(20,endFrequency),ctx.currentTime+duration);}
    else source.buffer=this.noise;
    const filter=ctx.createBiquadFilter(); filter.type='lowpass';filter.frequency.value=noise?frequency:6000;
    gain.gain.setValueAtTime(.001,ctx.currentTime);gain.gain.linearRampToValueAtTime(volume,ctx.currentTime+.008);gain.gain.exponentialRampToValueAtTime(.001,ctx.currentTime+duration);
    stereo.pan.value=Math.max(-1,Math.min(1,pan));source.connect(filter);filter.connect(gain);gain.connect(stereo);stereo.connect(bus);
    this.voices++;source.onended=()=>{source.disconnect();filter.disconnect();gain.disconnect();stereo.disconnect();this.voices--;};
    source.start();source.stop(ctx.currentTime+duration+.02);
  }

  effect(effect:Effect,s:Snapshot):void {
    const dx=effect.x-s.leader.x,dz=effect.z-s.leader.z,d=Math.hypot(dx,dz);
    const volume=.22/(1+d*.065), pan=dx/30;
    if(d>90)return;
    switch(effect.kind){
      case 'shot':this.play(2400,.08,volume,'sawtooth',true,false,pan);this.play(130,.07,volume*.7,'square',false,false,pan,40);break;
      case 'explosion':this.play(450,.65,volume*2,'sawtooth',true,false,pan);this.play(85,.5,volume,'sine',false,false,pan,22);break;
      case 'surge':this.play(100,.9,.4,'sawtooth',false,false,0,48);this.play(700,.4,.15,'triangle',true);break;
      case 'infection':this.play(170,.24,volume*.5,'sine',false,false,pan,460);break;
      case 'bite':case 'hit':this.play(750,.11,volume*.8,'square',true,false,pan);break;
      case 'acid':this.play(900,.3,volume*.6,'triangle',true,false,pan);break;
      case 'debris':this.play(1500,.22,volume*.7,'square',true,false,pan);break;
    }
  }

  update(dt:number,s:Snapshot,playing:boolean):void {
    if(!this.context||this.context.state!=='running')return;
    this.timer-=dt;this.ambience-=dt;
    const count=s.hordeCounts.reduce((a,b)=>a+b,0);
    if(this.timer<=0){
      const intensity=playing?(s.district===4?4:count>90?3:s.surgeTime>0?2:1):0;
      this.timer+=60/(96+intensity*12)/2;
      const notes=[55,55,65.41,55,73.42,65.41,51.91,61.74];
      const note=notes[Math.floor(this.beat/4)%notes.length];
      if(this.beat%2===0)this.play(note,.25,.12,'triangle',false,true);
      if(this.beat%4===0)this.play(90,.13,.17,'sine',false,true,0,25);
      if(this.beat%4===2)this.play(1800,.095,.065,'square',true,true);
      if(intensity>1||this.beat%2===0)this.play(6500,.035,.025,'triangle',true,true);
      if(this.beat%8===1)this.play(note*8,.5,.035,'sine',false,true,0,note*8.12);
      if(intensity>=3&&this.beat%4===3)this.play(note*3,.12,.045,'sawtooth',false,true);
      this.beat++;
    }
    if(this.ambience<=0){
      this.ambience=playing?1.4:3;
      this.play(60+Math.random()*30,.7,Math.min(.11,.018+count*.0003),'sawtooth',false,false,Math.random()-.5,45);
      if(this.beat%3===0)this.play(380,.9,.02,'sine',false,false,.6,620);
      if(playing&&s.actors.some(a=>a.state==='PANIC'||a.state==='FLEE'))this.play(500,.25,.027,'triangle',false,false,Math.random()-.5,850);
    }
  }

  reset():void {this.timer=0;this.beat=0;this.ambience=0;}
  async dispose():Promise<void>{if(this.context)await this.context.close();this.context=null;this.master=null;this.music=null;this.sfx=null;}
}
