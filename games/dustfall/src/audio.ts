type Point = { x: number; y: number; z: number };
type Voice = { input: GainNode; nodes: AudioNode[]; pending: number };

const quiet = 0.0001;
const clamp = (value: number) => Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0;

/** All synthesis begins only after init() is called from a user interaction. */
export class AudioSystem {
  private context?: AudioContext;
  private master?: GainNode;
  private sfx?: GainNode;
  private music?: GainNode;
  private white?: AudioBuffer;
  private brown?: AudioBuffer;
  private windFilter?: BiquadFilterNode;
  private windGain?: GainNode;
  private droneGain?: GainNode;
  private droneFilter?: BiquadFilterNode;
  private volumes = { master: 0.8, sfx: 0.8, music: 0.35 };
  private ambientStarted = false;
  private voices = 0;
  private nextEnvironment = 0;
  private nextModulation = 0;
  private environmentPhase = 0;
  private readonly environmentPosition: Point = { x: 0, y: 0, z: 0 };

  init(): void {
    // Checking activation also protects callers that accidentally initialize during loading.
    if (typeof window === 'undefined') return;
    if (navigator.userActivation && !navigator.userActivation.hasBeenActive && !navigator.userActivation.isActive) return;
    if (!this.context) {
      const Constructor = window.AudioContext;
      if (!Constructor) return;
      try {
        const context = new Constructor();
        this.context = context;
        this.master = context.createGain();
        this.sfx = context.createGain();
        this.music = context.createGain();
        const limiter = context.createDynamicsCompressor();
        limiter.threshold.value = -12;
        limiter.knee.value = 12;
        limiter.ratio.value = 5;
        limiter.attack.value = 0.003;
        limiter.release.value = 0.18;
        this.sfx.connect(limiter);
        this.music.connect(limiter);
        limiter.connect(this.master).connect(context.destination);
        this.master.gain.value = this.volumes.master;
        this.sfx.gain.value = this.volumes.sfx;
        this.music.gain.value = this.volumes.music;
        this.white = this.makeNoise(false);
        this.brown = this.makeNoise(true);
      } catch {
        this.context = undefined;
        return;
      }
    }
    const context = this.context;
    if (context.state === 'running') this.startAmbience();
    else if (context.state !== 'closed') {
      // Safari and tab-resume restrictions must never produce an unhandled rejection.
      void context.resume().then(() => {
        if (context.state === 'running') this.startAmbience();
      }).catch(() => {});
    }
  }

  setVolumes(master: number, sfx: number, music: number): void {
    this.volumes.master = clamp(master);
    this.volumes.sfx = clamp(sfx);
    this.volumes.music = clamp(music);
    const now = this.context?.currentTime ?? 0;
    this.master?.gain.setTargetAtTime(this.volumes.master, now, 0.025);
    this.sfx?.gain.setTargetAtTime(this.volumes.sfx, now, 0.025);
    this.music?.gain.setTargetAtTime(this.volumes.music, now, 0.025);
  }

  play(name: string, position?: Point): void {
    if (!this.context || this.context.state !== 'running' || !this.sfx || this.voices >= 64) return;
    const now = this.context.currentTime;
    const variation = 0.96 + Math.random() * 0.08;
    let voice: Voice;
    switch (name) {
      case 'shoot-shotgun':
        voice = this.voice(position, 1.1, 16, 250);
        this.noise(voice, now, .085, .65, 'highpass', 900);
        this.tone(voice, now, .32, .75, 155 * variation, 30, 'triangle');
        this.noise(voice, now + .015, .4, .4, 'lowpass', 1600);
        this.noise(voice, now + .11, .55, .13, 'bandpass', 480, .7);
        this.metal(voice, now + .34, .12, 1250);
        this.noise(voice, now + .43, .09, .16, 'highpass', 1800);
        this.metal(voice, now + .52, .1, 2100);
        break;
      case 'shoot-carbine':
      case 'shoot-smg':
      case 'shoot-scout': {
        const scout = name === 'shoot-scout';
        const smg = name === 'shoot-smg';
        voice = this.voice(position, scout ? 1.05 : smg ? 0.69 : 0.9, 12, 250);
        // Muzzle crack, pressure body, burning gas and an open-valley reflection.
        this.noise(voice, now, smg ? 0.045 : 0.065, 0.55, 'highpass', smg ? 1900 : 1200);
        this.tone(voice, now, scout ? 0.25 : 0.14, scout ? 0.66 : 0.48, (scout ? 175 : smg ? 245 : 205) * variation, 43, 'triangle');
        this.noise(voice, now + 0.006, scout ? 0.45 : smg ? 0.13 : 0.24, 0.35, 'lowpass', scout ? 1750 : 2400);
        this.noise(voice, now + 0.075, scout ? 0.6 : 0.27, scout ? 0.14 : 0.075, 'bandpass', 540, 0.65);
        this.noise(voice, now + 0.145, scout ? 0.32 : 0.13, 0.035, 'lowpass', 1200);
        this.metal(voice, now + (smg ? 0.12 : 0.19), 0.045, 3100 * variation);
        this.metal(voice, now + 0.31, 0.018, 4400 * variation);
        break;
      }
      case 'reload':
        voice = this.voice(position, 0.65, 3, 25);
        this.metal(voice, now, 0.12, 1700);
        this.noise(voice, now + 0.1, 0.2, 0.11, 'bandpass', 1150, 0.6);
        this.tone(voice, now + 0.2, 0.09, 0.13, 230, 100, 'triangle');
        this.noise(voice, now + 0.64, 0.08, 0.19, 'highpass', 1400);
        this.metal(voice, now + 0.7, 0.13, 2350);
        this.noise(voice, now + 0.96, 0.11, 0.15, 'bandpass', 750, 1.2);
        this.metal(voice, now + 1.06, 0.1, 1300);
        break;
      case 'empty':
        voice = this.voice(position, 0.65, 2, 15);
        this.metal(voice, now, 0.09, 2100);
        this.tone(voice, now, 0.035, 0.14, 130, 70, 'triangle');
        break;
      case 'step':
      case 'sprint': {
        const sprint = name === 'sprint';
        voice = this.voice(position, sprint ? 0.85 : 0.55, 2, 22);
        this.tone(voice, now, 0.09, 0.22, (sprint ? 110 : 90) * variation, 38, 'sine');
        this.noise(voice, now, 0.08, 0.18, 'lowpass', 520 * variation);
        this.noise(voice, now + 0.025, sprint ? 0.19 : 0.13, 0.09, 'bandpass', 1750 * variation, 0.5);
        if (sprint) this.metal(voice, now + 0.05, 0.012, 2200);
        break;
      }
      case 'hit':
        voice = this.voice(position, 0.7, 5, 90);
        this.noise(voice, now, 0.07, 0.23, 'highpass', 1500);
        this.metal(voice, now, 0.16, 1250 * variation);
        this.tone(voice, now, 0.09, 0.16, 195, 70, 'triangle');
        break;
      case 'kill':
        voice = this.voice(position, 0.85, 7, 110);
        this.noise(voice, now, 0.28, 0.34, 'lowpass', 1200);
        this.tone(voice, now, 0.48, 0.2, 450, 35, 'sawtooth');
        this.metal(voice, now + 0.055, 0.2, 970);
        this.metal(voice, now + 0.22, 0.1, 1600);
        this.noise(voice, now + 0.28, 0.38, 0.08, 'bandpass', 3200, 0.7);
        break;
      case 'damage':
        voice = this.voice(undefined, 0.85);
        this.tone(voice, now, 0.23, 0.48, 95, 31, 'sine');
        this.noise(voice, now, 0.17, 0.3, 'lowpass', 650);
        this.noise(voice, now + 0.015, 0.08, 0.12, 'bandpass', 1500, 0.5);
        this.tone(voice, now + 0.03, 0.42, 0.02, 2100, 1750, 'sine', 0.02);
        break;
      case 'heal':
        voice = this.voice(position, 0.6, 2, 18);
        this.noise(voice, now, 0.27, 0.15, 'highpass', 2200);
        this.noise(voice, now + 0.28, 0.43, 0.1, 'bandpass', 900, 0.6);
        this.tone(voice, now + 0.42, 0.24, 0.065, 440, 440, 'sine', 0.025);
        this.tone(voice, now + 0.59, 0.35, 0.05, 660, 660, 'sine', 0.025);
        break;
      case 'loot':
        voice = this.voice(position, 0.6, 3, 30);
        this.metal(voice, now, 0.12, 1100);
        this.noise(voice, now + 0.045, 0.27, 0.1, 'bandpass', 650, 1.3);
        this.tone(voice, now + 0.18, 0.16, 0.085, 740, 740, 'sine');
        this.tone(voice, now + 0.28, 0.26, 0.065, 1110, 1110, 'sine');
        break;
      case 'ui':
        voice = this.voice(undefined, 0.45);
        this.noise(voice, now, 0.018, 0.07, 'bandpass', 2600, 0.8);
        this.tone(voice, now, 0.055, 0.13, 620, 490, 'sine');
        break;
      case 'alert':
        voice = this.voice(position, 0.65, 8, 120);
        for (let i = 0; i < 3; i++) {
          this.tone(voice, now + i * 0.19, 0.12, 0.1, 730, 940, 'triangle', 0.008);
          this.tone(voice, now + i * 0.19, 0.12, 0.045, 365, 470, 'sine');
        }
        break;
      case 'robot':
        voice = this.voice(position, 0.55, 5, 75);
        this.tone(voice, now, 0.19, 0.075, 240 * variation, 650 * variation, 'sawtooth', 0.035);
        this.tone(voice, now + 0.11, 0.16, 0.075, 1200 * variation, 560, 'sine');
        this.noise(voice, now, 0.3, 0.07, 'bandpass', 820, 3);
        this.metal(voice, now + 0.24, 0.03, 2400);
        break;
      case 'beacon':
        voice = this.voice(position, 0.65, 10, 180);
        for (let i = 0; i < 3; i++) {
          this.tone(voice, now + i * 0.34, 0.26, 0.11, 880, 880, 'sine', 0.015);
          this.tone(voice, now + i * 0.34 + 0.07, 0.26, 0.045, 1320, 1320, 'sine', 0.02);
        }
        break;
      case 'success':
        voice = this.voice(undefined, 0.65);
        for (const [i, frequency] of [220, 330, 440, 550, 660].entries()) {
          this.tone(voice, now + i * 0.13, 1.7, 0.07, frequency, frequency, 'sine', 0.055);
          this.tone(voice, now + i * 0.13, 1.1, 0.019, frequency * 2.003, frequency * 2, 'sine', 0.03);
        }
        this.noise(voice, now, 0.6, 0.025, 'bandpass', 1700, 0.4);
        break;
      case 'grenade':
        voice = this.voice(position, 1.15, 18, 280);
        this.noise(voice, now, 0.12, 0.68, 'highpass', 700);
        this.tone(voice, now, 0.85, 0.8, 135, 24, 'sine');
        this.noise(voice, now + 0.018, 1.4, 0.56, 'lowpass', 850);
        this.noise(voice, now + 0.18, 1.7, 0.22, 'bandpass', 260, 0.65);
        for (let i = 0; i < 5; i++) this.metal(voice, now + 0.2 + i * 0.13, 0.07 / (i + 1), 1700 + Math.random() * 1800);
        break;
    }
  }

  update(position: Point, forward: Point, threat: number): void {
    const context = this.context;
    if (!context || context.state !== 'running') return;
    const listener = context.listener;
    if (listener.positionX) {
      listener.positionX.value = position.x;
      listener.positionY.value = position.y;
      listener.positionZ.value = position.z;
      listener.forwardX.value = forward.x;
      listener.forwardY.value = forward.y;
      listener.forwardZ.value = forward.z;
      listener.upX.value = 0;
      listener.upY.value = 1;
      listener.upZ.value = 0;
    } else {
      listener.setPosition(position.x, position.y, position.z);
      listener.setOrientation(forward.x, forward.y, forward.z, 0, 1, 0);
    }
    const now = context.currentTime;
    const tension = clamp(threat);
    // Only parameter automation at a low control rate; no nodes or buffers per frame.
    if (now >= this.nextModulation) {
      this.nextModulation = now + 0.25;
      const gust = 0.5 + 0.3 * Math.sin(now * 0.19) + 0.2 * Math.sin(now * 0.071 + 1.7);
      this.windFilter?.frequency.setTargetAtTime(370 + gust * 680, now, 0.7);
      this.windGain?.gain.setTargetAtTime(0.075 + gust * 0.085, now, 0.8);
      this.droneGain?.gain.setTargetAtTime(0.025 + tension * 0.12, now, 1.6);
      this.droneFilter?.frequency.setTargetAtTime(160 + tension * 520, now, 1.3);
    }
    if (now >= this.nextEnvironment) {
      this.nextEnvironment = now + 7 + Math.random() * 11;
      this.environmentPhase++;
      const angle = Math.random() * Math.PI * 2;
      const distance = 25 + Math.random() * 45;
      const source = this.environmentPosition;
      source.x = position.x + Math.sin(angle) * distance;
      source.z = position.z + Math.cos(angle) * distance;
      source.y = position.y + 5 + Math.random() * 8;
      if (this.voices >= 48) return;
      const voice = this.voice(source, 0.38, 12, 130);
      if (this.environmentPhase % 3 === 0) {
        // A stressed girder: detuned modes and a long friction scrape.
        this.tone(voice, now, 2.5, 0.1, 150, 105, 'triangle', 0.5);
        this.tone(voice, now + 0.3, 1.9, 0.05, 309, 218, 'sine', 0.4);
        this.noise(voice, now + 0.1, 2.1, 0.08, 'bandpass', 650, 6, 0.35);
      } else {
        // Sparse wildlife, not a melodic ambient soundtrack.
        for (let i = 0; i < 3; i++) {
          const pitch = 1900 + Math.random() * 750;
          this.tone(voice, now + i * 0.19, 0.12, 0.09, pitch, pitch * (i % 2 ? 0.72 : 1.25), 'sine', 0.018);
        }
      }
    }
  }

  private makeNoise(brown: boolean): AudioBuffer {
    const context = this.context!;
    const buffer = context.createBuffer(1, context.sampleRate * 4, context.sampleRate);
    const data = buffer.getChannelData(0);
    let previous = 0;
    for (let i = 0; i < data.length; i++) {
      const sample = Math.random() * 2 - 1;
      previous = (previous + 0.02 * sample) / 1.02;
      data[i] = brown ? previous * 3.5 : sample;
    }
    // Crossfade the loop boundary without muting a discernible section of the wind.
    const seam = 512;
    for (let i = 0; i < seam; i++) {
      const blend = i / seam;
      data[data.length - seam + i] = data[data.length - seam + i] * (1 - blend) + data[i] * blend;
    }
    return buffer;
  }

  private panner(position: Point, reference: number, maximum: number): PannerNode {
    const panner = this.context!.createPanner();
    panner.panningModel = 'HRTF';
    panner.distanceModel = 'inverse';
    panner.refDistance = reference;
    panner.maxDistance = maximum;
    panner.rolloffFactor = 1.3;
    panner.positionX.value = position.x;
    panner.positionY.value = position.y;
    panner.positionZ.value = position.z;
    return panner;
  }

  private voice(position?: Point, volume = 1, reference = 4, maximum = 100): Voice {
    const input = this.context!.createGain();
    input.gain.value = volume;
    const voice: Voice = { input, nodes: [input], pending: 0 };
    if (position) {
      const panner = this.panner(position, reference, maximum);
      input.connect(panner).connect(this.sfx!);
      voice.nodes.push(panner);
    } else input.connect(this.sfx!);
    this.voices++;
    return voice;
  }

  private envelope(voice: Voice, start: number, duration: number, peak: number, attack: number): GainNode {
    const envelope = this.context!.createGain();
    envelope.gain.setValueAtTime(quiet, start);
    envelope.gain.linearRampToValueAtTime(peak, start + Math.min(attack, duration * 0.4));
    envelope.gain.exponentialRampToValueAtTime(quiet, start + duration);
    envelope.connect(voice.input);
    voice.nodes.push(envelope);
    return envelope;
  }

  private source(voice: Voice, source: AudioScheduledSourceNode, start: number, duration: number): void {
    voice.pending++;
    voice.nodes.push(source);
    source.onended = () => {
      source.disconnect();
      source.onended = null;
      if (--voice.pending === 0) {
        for (const node of voice.nodes) node.disconnect();
        voice.nodes.length = 0;
        this.voices--;
      }
    };
    source.start(start);
    source.stop(start + duration + 0.025);
  }

  private tone(voice: Voice, start: number, duration: number, peak: number, frequency: number, end: number, type: OscillatorType, attack = 0.003): void {
    const oscillator = this.context!.createOscillator();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, start);
    oscillator.frequency.exponentialRampToValueAtTime(Math.max(20, end), start + duration);
    oscillator.connect(this.envelope(voice, start, duration, peak, attack));
    this.source(voice, oscillator, start, duration);
  }

  private noise(voice: Voice, start: number, duration: number, peak: number, type: BiquadFilterType, frequency: number, q = 0.7, attack = 0.002): void {
    const context = this.context!;
    const source = context.createBufferSource();
    source.buffer = this.white!;
    source.loop = true;
    source.playbackRate.value = 0.91 + Math.random() * 0.18;
    const filter = context.createBiquadFilter();
    filter.type = type;
    filter.frequency.value = frequency;
    filter.Q.value = q;
    source.connect(filter).connect(this.envelope(voice, start, duration, peak, attack));
    voice.nodes.push(filter);
    this.source(voice, source, start, duration);
  }

  private metal(voice: Voice, start: number, peak: number, frequency: number): void {
    this.tone(voice, start, 0.11, peak, frequency, frequency * 0.94, 'sine');
    this.tone(voice, start, 0.065, peak * 0.45, frequency * 1.483, frequency * 1.47, 'sine');
    this.noise(voice, start, 0.014, peak * 0.5, 'highpass', 2800);
  }

  private startAmbience(): void {
    if (this.ambientStarted) return;
    this.ambientStarted = true;
    const context = this.context!;
    const now = context.currentTime;
    this.nextEnvironment = now + 5;
    this.windFilter = context.createBiquadFilter();
    this.windFilter.type = 'lowpass';
    this.windFilter.frequency.value = 650;
    this.windFilter.Q.value = 0.55;
    const windHighpass = context.createBiquadFilter();
    windHighpass.type = 'highpass';
    windHighpass.frequency.value = 75;
    this.windGain = context.createGain();
    this.windGain.gain.setValueAtTime(0, now);
    this.windGain.gain.linearRampToValueAtTime(0.12, now + 3);
    const wind = context.createBufferSource();
    wind.buffer = this.brown!;
    wind.loop = true;
    wind.connect(windHighpass).connect(this.windFilter).connect(this.windGain).connect(this.sfx!);
    wind.start();

    const industrial = context.createGain();
    industrial.gain.setValueAtTime(0, now);
    industrial.gain.linearRampToValueAtTime(0.045, now + 4);
    const industrialFilter = context.createBiquadFilter();
    industrialFilter.type = 'lowpass';
    industrialFilter.frequency.value = 380;
    const industrialPanner = this.panner({ x: -45, y: 12, z: -45 }, 35, 270);
    industrial.connect(industrialFilter).connect(industrialPanner).connect(this.sfx!);
    for (const frequency of [49, 98.4, 147]) {
      const oscillator = context.createOscillator();
      oscillator.type = 'triangle';
      oscillator.frequency.value = frequency;
      oscillator.connect(industrial);
      oscillator.start();
    }
    const flutter = context.createOscillator();
    const flutterDepth = context.createGain();
    flutter.frequency.value = 0.37;
    flutterDepth.gain.value = 0.008;
    flutter.connect(flutterDepth).connect(industrial.gain);
    flutter.start();

    // Music is deliberately a quiet, non-rhythmic tension bed, independently muted.
    this.droneGain = context.createGain();
    this.droneGain.gain.setValueAtTime(0, now);
    this.droneGain.gain.linearRampToValueAtTime(0.025, now + 5);
    this.droneFilter = context.createBiquadFilter();
    this.droneFilter.type = 'lowpass';
    this.droneFilter.frequency.value = 180;
    this.droneFilter.Q.value = 0.5;
    this.droneFilter.connect(this.droneGain).connect(this.music!);
    for (const [index, frequency] of [55, 82.41, 110.3].entries()) {
      const oscillator = context.createOscillator();
      oscillator.type = index === 1 ? 'triangle' : 'sine';
      oscillator.frequency.value = frequency;
      const level = context.createGain();
      level.gain.value = index === 0 ? 0.65 : 0.2;
      oscillator.connect(level).connect(this.droneFilter);
      oscillator.start();
      const drift = context.createOscillator();
      const depth = context.createGain();
      drift.frequency.value = 0.037 + index * 0.019;
      depth.gain.value = 3;
      drift.connect(depth).connect(oscillator.detune);
      drift.start();
    }
  }
}
