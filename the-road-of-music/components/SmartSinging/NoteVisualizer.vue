<template>
  <view class="note-visualizer">
    <canvas 
      type="2d"
      id="visualizerCanvas"
      class="visualizer-canvas"
      :style="{ width: canvasWidth + 'px', height: canvasHeight + 'px' }"
    ></canvas>
  </view>
</template>

<script setup>
import { ref, onMounted, watch, getCurrentInstance, nextTick } from 'vue';

const props = defineProps({
  currentNote: {
    type: Object,
    default: null
  },
  referenceNote: {
    type: Object,
    default: null
  },
  minFrequency: {
    type: Number,
    default: 220  // A3
  },
  maxFrequency: {
    type: Number,
    default: 880  // A5
  }
});

const canvasWidth = ref(300);
const canvasHeight = ref(150);
let ctx = null;

// 初始化Canvas
onMounted(() => {
  const instance = getCurrentInstance();
  nextTick(() => {
    initCanvas();
  });
});

// 初始化Canvas
const initCanvas = () => {
  const query = uni.createSelectorQuery();
  query.select('#visualizerCanvas')
    .fields({ node: true, size: true })
    .exec((res) => {
      if (res[0]) {
        const canvas = res[0].node;
        ctx = canvas.getContext('2d');
        
        const dpr = uni.getSystemInfoSync().pixelRatio;
        canvas.width = res[0].width * dpr;
        canvas.height = res[0].height * dpr;
        ctx.scale(dpr, dpr);
        
        canvasWidth.value = res[0].width;
        canvasHeight.value = res[0].height;
        
        drawVisualization();
      }
    });
};

// 监听音符变化
watch(() => [props.currentNote, props.referenceNote], () => {
  if (ctx) {
    drawVisualization();
  }
}, { deep: true });

// 绘制可视化
const drawVisualization = () => {
  if (!ctx) return;
  
  // 清空画布
  ctx.clearRect(0, 0, canvasWidth.value, canvasHeight.value);
  
  // 绘制背景网格
  drawGrid();
  
  // 绘制参考线
  drawReferenceLines();
  
  // 绘制当前音符
  if (props.currentNote) {
    drawNote(props.currentNote.frequency, '#00c9a4');
  }
  
  // 绘制标准音符
  if (props.referenceNote) {
    drawNote(props.referenceNote.frequency, '#666666', true);
  }
};

// 绘制网格
const drawGrid = () => {
  ctx.strokeStyle = '#f0f0f0';
  ctx.lineWidth = 1;
  
  // 横线（频率刻度）
  const freqStep = (props.maxFrequency - props.minFrequency) / 8;
  for (let freq = props.minFrequency; freq <= props.maxFrequency; freq += freqStep) {
    const y = frequencyToY(freq);
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(canvasWidth.value, y);
    ctx.stroke();
  }
};

// 绘制参考线
const drawReferenceLines = () => {
  // 标准音高线
  const standardNotes = ['A3', 'C4', 'E4', 'A4', 'C5', 'E5', 'A5'];
  standardNotes.forEach(note => {
    const freq = noteToFrequency(note);
    const y = frequencyToY(freq);
    
    ctx.strokeStyle = '#e0e0e0';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(canvasWidth.value, y);
    ctx.stroke();
    
    // 绘制音符名称
    ctx.fillStyle = '#999';
    ctx.font = '12px sans-serif';
    ctx.fillText(note, 5, y - 5);
  });
};

// 绘制音符
const drawNote = (frequency, color, isReference = false) => {
  const y = frequencyToY(frequency);
  
  // 绘制音高线
  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(0, y);
  ctx.lineTo(canvasWidth.value, y);
  ctx.stroke();
  
  // 绘制音高点
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(canvasWidth.value / 2, y, isReference ? 4 : 6, 0, Math.PI * 2);
  ctx.fill();
};

// 频率转换为Y坐标
const frequencyToY = (frequency) => {
  const logFreq = Math.log2(frequency / props.minFrequency);
  const logRange = Math.log2(props.maxFrequency / props.minFrequency);
  return canvasHeight.value - (logFreq / logRange) * canvasHeight.value;
};

// 音符名称转换为频率
const noteToFrequency = (noteName) => {
  const noteMap = {
    'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
    'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11
  };
  
  const note = noteName.slice(0, -1);
  const octave = parseInt(noteName.slice(-1));
  const semitones = noteMap[note] + (octave - 4) * 12;
  
  return 440 * Math.pow(2, semitones / 12);
};
</script>

<style lang="scss" scoped>
.note-visualizer {
  width: 100%;
  height: 100%;
  background: #ffffff;
  border-radius: 8px;
  overflow: hidden;
  
  .visualizer-canvas {
    width: 100%;
    height: 100%;
  }
}
</style> 