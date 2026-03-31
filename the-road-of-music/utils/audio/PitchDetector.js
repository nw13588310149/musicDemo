export class PitchDetector {
  constructor() {
    this.audioContext = null;
    this.analyser = null;
    this.bufferLength = 2048;
    this.sampleRate = 44100;
  }

  // 初始化音频上下文
  async initialize() {
    try {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      this.analyser = this.audioContext.createAnalyser();
      this.analyser.fftSize = this.bufferLength;
      
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const source = this.audioContext.createMediaStreamSource(stream);
      source.connect(this.analyser);
      
      return stream;
    } catch (error) {
      console.error('音频初始化错误:', error);
      throw error;
    }
  }

  // 使用自相关算法检测音高
  detectPitch() {
    const buffer = new Float32Array(this.bufferLength);
    this.analyser.getFloatTimeDomainData(buffer);
    
    // 自相关算法
    const correlation = new Float32Array(this.bufferLength);
    for (let i = 0; i < this.bufferLength; i++) {
      for (let j = 0; j < this.bufferLength - i; j++) {
        correlation[i] += buffer[j] * buffer[j + i];
      }
    }

    // 寻找第一个显著峰值
    let maxCorrelation = -1;
    let foundPeriod = 0;
    
    for (let i = 1; i < correlation.length; i++) {
      if (correlation[i] > maxCorrelation) {
        maxCorrelation = correlation[i];
        foundPeriod = i;
      }
    }

    // 计算频率
    const frequency = this.sampleRate / foundPeriod;
    
    // 检查频率是否在人声范围内 (80Hz - 1100Hz)
    if (frequency < 80 || frequency > 1100) {
      return null;
    }

    return frequency;
  }

  // 获取最接近的音符
  getNearestNote(frequency) {
    if (!frequency) return null;

    // MIDI音符频率对照表
    const A4 = 440;
    const A4_MIDI = 69;
    
    // 计算MIDI音符号
    const midiNote = Math.round(12 * Math.log2(frequency / A4) + A4_MIDI);
    
    // 计算标准频率
    const standardFreq = A4 * Math.pow(2, (midiNote - A4_MIDI) / 12);
    
    // 计算音分差
    const cents = Math.round(1200 * Math.log2(frequency / standardFreq));

    return {
      midiNote,
      frequency: standardFreq,
      cents,
      noteName: this.getMidiNoteName(midiNote)
    };
  }

  // 获取MIDI音符名称
  getMidiNoteName(midiNote) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const octave = Math.floor(midiNote / 12) - 1;
    const noteIndex = midiNote % 12;
    return noteNames[noteIndex] + octave;
  }

  // 停止音频处理
  stop() {
    if (this.audioContext) {
      this.audioContext.close();
      this.audioContext = null;
      this.analyser = null;
    }
  }
} 