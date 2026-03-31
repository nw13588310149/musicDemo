<template>
  <div class="virtual-piano2">
    <div class="showText">{{ note }}</div>
    <div class="btn">
      <div class="del" @click="decreaseFrequency"></div>
      <div class="text">{{ frequency }}hz</div>
      <div class="add" @click="increaseFrequency"></div>
    </div>
    <div class="ul">
      <div
        class="li"
        v-for="item in lines"
        :key="item.index"
        :data-line="item.index - 51"
        :class="{ highlight: item.highlight }"
        :style="getHeightStyle(item.index)"
      >
        <div v-if="(item.index - 1) % 10 === 0" class="num" :style="getNumStyle(item.index)">
          {{ item.index - 51 }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue';

// 定义音律数组为静态属性
class Tune {
  static equal = [
    Math.pow(2,  0/12), Math.pow(2,  1/12), Math.pow(2,  2/12), Math.pow(2,  3/12),
    Math.pow(2,  4/12), Math.pow(2,  5/12), Math.pow(2,  6/12), Math.pow(2,  7/12),
    Math.pow(2,  8/12), Math.pow(2,  9/12), Math.pow(2, 10/12), Math.pow(2, 11/12),
    Math.pow(2, 12/12)
  ];

  constructor(options = {}) {
    this.temperament = options.temperament || 'equal';
    this.fundamental = options.fundamental || 440;
    this.ratios = Tune[this.temperament];
    this.targetFrequencies = [];
    this.midPoints = [];
    this.temperature = options.temperature || 70;
    this.speedOfSound = options.speedOfSound || 343;
    this.wavelength = options.wavelength || 0;
    this.frequency = options.frequency || 440;

    this.setFundamental(this.fundamental);
    this.setTemperament(this.temperament);
  }

  setTemperament(e) {
    this.temperament = e;
    const newRatios = [];
    Tune[e].forEach(r => {
      if (e === 'just' || e === 'meantone' || e === 'pythagorean') {
        newRatios.push(r[0] / r[1]);
      } else if (e === 'equal' || e === 'werckmeisterI' || e === 'werckmeisterII' || e === 'werckmeisterIII') {
        newRatios.push(r);
      }
    });
    this.setRatios(newRatios);
  }

  getTemperament() {
    return this.temperament;
  }

  setFundamental(e) {
    this.fundamental = e;
    this.setTemperament(this.temperament);
  }

  getFundamental() {
    return this.fundamental;
  }

  setRatios(e) {
    try {
      this.ratios = e;
      const funda = this.fundamental;
      const newTargetFreqs = e.map(r => r * funda);
      this.targetFrequencies = newTargetFreqs;

      const diff = ary => {
        const newA = [];
        for (let i = 1; i < ary.length; i++) {
          const x = ary[i] - ary[i - 1];
          newA.push(x / 2);
        }
        return newA;
      };

      const newMidPoints = [];
      diff(newTargetFreqs).forEach((v, i) => {
        newMidPoints.push(newTargetFreqs[i] + v);
      });
      this.midPoints = newMidPoints;
    } catch (err) {
      console.error(err);
    }
  }

  tune(e) {
    this.frequency = e;
    let frequency = e;
    let cents;

    const highMidPoint = this.midPoints[this.midPoints.length - 1] / 2;
    for (let step = 0; step < 100; step++) {
      if (frequency < highMidPoint) {
        frequency *= 2;
      } else if (frequency > highMidPoint * 2) {
        frequency /= 2;
      } else {
        break;
      }
    }

    this.midPoints.some((v, i) => {
      if (frequency < v) {
        cents = 1200 * Math.log2(frequency / this.targetFrequencies[i]);
        return true;
      }
      return false;
    });
    return cents;
  }

  static noteFromPitch(frequency) {
    const noteNum = 12 * (Math.log(frequency / 440) / Math.log(2));
    return Math.round(noteNum) + 69;
  }

  static getNoteFromMIDI(midi, accidental = 'sharp', notation = 'american') {
    const notes = {
      flat: {
        american: ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'],
        european: ['DO', 'REb', 'RE', 'MIb', 'MI', 'FA', 'SOLb', 'SOL', 'LAb', 'LA', 'SIb', 'SI'],
      },
      sharp: {
        american: ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'],
        european: ['DO', 'DO♯', 'RE', 'RE♯', 'MI', 'FA', 'FA♯', 'SOL', 'SOL♯', 'LA', 'LA♯', 'SI'],
      },
    };

    const noteIndex = midi % 12;
    return notes[accidental][notation][noteIndex];
  }
}

let stream;
let shouldStopMonitoring = false;
let audioContext, analyser, microphone;

const note = ref('');
const frequency = ref(440); // 默认频率

// 调音器类的实例
const tuner = new Tune({ temperament: 'equal', fundamental: 440 });

// 定义用于存储线条的数组
const lines = ref([]);

const initLines = () => {
  for (let i = -50; i <= 50; i++) {
    lines.value.push({
      index: i + 51,
      highlight: false,
      color: getLineColor(i),
    });
  }
};

const getLineColor = (index) => {
  const breakpoints = [
    { value: 5, color: '#04D300' },
    { value: 30, color: '#FFA914' },
    { value: 50, color: '#F24822' },
  ];
  const breakpoint = breakpoints.find((point) => Math.abs(index) <= point.value);
  return breakpoint?.color || '#000';
};

const autoCorrelate = (buf, sampleRate) => {
  const SIZE = buf.length;
  let rms = 0;

  for (let i = 0; i < SIZE; i++) {
    const val = buf[i];
    rms += val * val;
  }
  rms = Math.sqrt(rms / SIZE);

  if (rms < 0.01) {
    return -1;
  }

  let r1 = 0, r2 = SIZE - 1, thres = 0.2;
  for (let i = 0; i < SIZE / 2; i++) {
    if (Math.abs(buf[i]) < thres) {
      r1 = i;
      break;
    }
  }
  for (let i = 1; i < SIZE / 2; i++) {
    if (Math.abs(buf[SIZE - i]) < thres) {
      r2 = SIZE - i;
      break;
    }
  }

  buf = buf.slice(r1, r2);
  const newSIZE = buf.length;

  const c = new Array(newSIZE).fill(0);
  for (let i = 0; i < newSIZE; i++) {
    for (let j = 0; j < newSIZE - i; j++) {
      c[i] += buf[j] * buf[j + i];
    }
  }

  let d = 0;
  while (c[d] > c[d + 1]) {
    d++;
  }
  let maxval = -1, maxpos = -1;
  for (let i = d; i < newSIZE; i++) {
    if (c[i] > maxval) {
      maxval = c[i];
      maxpos = i;
    }
  }
  let T0 = maxpos;

  const x1 = c[T0 - 1], x2 = c[T0], x3 = c[T0 + 1];
  const a = (x1 + x3 - 2 * x2) / 2;
  const b = (x3 - x1) / 2;
  if (a) {
    T0 = T0 - b / (2 * a);
  }

  return sampleRate / T0;
};

const unlockAudioContext = () => {
  if (audioContext.state === 'suspended') {
    audioContext.resume();
  }
};

const monitorFrequency = () => {
  if (shouldStopMonitoring) {
    return;
  }
  const bufferLength = analyser.fftSize;
  const dataArray = new Float32Array(bufferLength);
  analyser.getFloatTimeDomainData(dataArray);

  const detectedFrequency = autoCorrelate(dataArray, audioContext.sampleRate);
  if (detectedFrequency !== -1) {
    const closestNote = findClosestNoteWithTune(detectedFrequency);
    note.value = closestNote.note;
    drawDetune(closestNote.cents);
  }

  requestAnimationFrame(monitorFrequency);
};

const drawDetune = (detune) => {
  const isPositive = detune > 0;
  clearDetune();
  const filteredLines = lines.value.filter((line) => {
    const lineIndex = line.index - 51;
    const upperRange = isPositive ? lineIndex <= detune : lineIndex >= detune;
    const lowerRange = isPositive ? lineIndex >= 0 : lineIndex <= 0;
    return upperRange && lowerRange;
  });
  filteredLines.forEach((line) => {
    line.highlight = true;
  });
};

const clearDetune = () => {
  lines.value.forEach((line) => {
    line.highlight = false;
  });
};

const findClosestNoteWithTune = (frequency) => {
  const cents = tuner.tune(frequency);
  const noteNumber = Tune.noteFromPitch(frequency);
  const noteName = Tune.getNoteFromMIDI(noteNumber, 'sharp', 'american');
  return { note: noteName, cents: cents };
};

const getHeightStyle = (num) => {
  if (num === 51) {
    return { height: '90px' };
  } else if ((num - 1) % 10 === 0) {
    return { height: '70px' };
  } else {
    return { height: '50px' };
  }
};

const getNumStyle = (item) => {
  return { left: item === 51 ? '-4px' : item > 51 ? '-8px' : '-15px' };
};

const increaseFrequency = () => {
  frequency.value += 10; // 增加频率
};

const decreaseFrequency = () => {
  if (frequency.value > 0) {
    frequency.value -= 10; // 减少频率
  }
};

onMounted(() => {
  audioContext = new (window.AudioContext || window.webkitAudioContext)();
  analyser = audioContext.createAnalyser();
  analyser.fftSize = 4096;

  document.addEventListener('click', unlockAudioContext);
  document.addEventListener('touchstart', unlockAudioContext);

  navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true } })
    .then(function(str) {
      stream = str;
      microphone = audioContext.createMediaStreamSource(str);
      microphone.connect(analyser);
      monitorFrequency();
    })
    .catch(function(err) {
      console.error('Error accessing audio input:', err);
    });

  initLines();
});

onBeforeUnmount(() => {
  shouldStopMonitoring = true;
  if (stream) {
    stream.getTracks().forEach((track) => track.stop());
  }
  document.removeEventListener('click', unlockAudioContext);
  document.removeEventListener('touchstart', unlockAudioContext);
});
</script>


<style scoped lang="scss">
	.virtual-piano2 {
	  /* 样式定义 */
	}
	
	.highlight {
	  background-color: #00c9a4 !important;
	}
.virtual-piano2 {
	padding: 20px;
	.showText{
		width: 190px;
		height: 70px;
		text-align: center;
		line-height: 70px;
		background: #232323;
		margin: 0 auto;
		margin-top: 100px;
		border-radius: 16px;
		color: #fff;
		font-size: 50px;
	}
	.btn{
		display: flex;
		justify-content: center;
		margin-top: 60px;
		margin-bottom: 120px;
		.text{
		    margin: 0 20px;
		    font-size: 30px;
		    padding: 0px 20px;
		    background: #232323;
		    border-radius: 40px;
		    color: #fff;
			display: flex;
			justify-content: center;
			align-items: center;
		}
		.add , .del{
			    font-size: 50px;
			    background: #ddd;
			    width: 60px;
			    text-align: center;
			    height: 60px;
			    border-radius: 50%;
				    display: flex;
				    justify-content: center;
				    align-items: center;
				span{
					width: 25px;
					height: 25px;
					text-align: center;
					line-height: 25px;
				}	
		}
		.add{
			                background-image: url(/static/assets/add.png);
			                background-repeat: no-repeat;
			                background-size: 60px;
		}
		.del{
			                background-image: url(/static/assets/del.png);
			                background-repeat: no-repeat;
			                background-size: 60px;
		}
	}
  .ul{
	  display: flex;
	  justify-content: center;
	  align-items: end;
	  .li{
			width: 4px;
		    height: 50px;
		    background-color: #3f403f;
		    border-radius: 2px;
		    margin-right: 4px;
			position: relative;
			.num{
				position: absolute;
				top: -30px;
			
			}
	  }
  }
}
</style>
