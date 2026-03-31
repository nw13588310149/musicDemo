<template>
  <div class="score-container">
    <div class="score-content" ref="scoreContent"></div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import * as ABCJS from 'abcjs';
import { Midi } from '@tonejs/midi';

// 组件属性
const props = defineProps({
  midiData: {
    type: [ArrayBuffer, Blob, String],
    required: true
  }
});

// 引用
const scoreContent = ref(null);

// 基本的 ABC 记谱示例
const testAbc = `X:1
T:Test Score
M:4/4
L:1/4
K:C
%%staves {(RH)}
%%staffsep 100
%%sysstaffsep 100
%%stretchlast 0.7
%%musicspace 0.7
%%titlefont Times-Roman 20
%%gchordfont Times-Roman 12
%%composerfont Times-Roman 12
%%partsfont Times-Roman 12
%%textfont Times-Roman 12
%%annotationfont Times-Roman 12
%%measurefont Times-Roman 12
%%barnumberfont Times-Roman 12
V:RH clef=treble name="Piano"
[V:RH] C D E F | G A B c |]`;

// 渲染设置
const renderOptions = {
  responsive: 'resize',
  add_classes: true,
  staffwidth: 800,
  scale: 1.3,
  wrap: {
    minSpacing: 1.2,
    maxSpacing: 2.2,
    preferredMeasuresPerLine: 4
  },
  format: {
    aligncomposer: 1,
    alignbars: 1,
    stretchlast: 0.8,
    staffwidth: 800,
    staffsep: 60,
    sysstaffsep: 60,
    maxshrink: 0.6,
    notespacingfactor: 1.2,
    linethickness: 1.2,
    indent: 10
  },
  paddingright: 30,
  paddingleft: 30,
  paddingbottom: 30,
  paddingtop: 30
};

// MIDI 到 ABC 的转换函数
const convertMidiToAbc = async (midiData) => {
  try {
    const midi = await new Midi(midiData);
    console.log('MIDI 文件信息:', midi);

    let abcString = `X:1\n`;
    abcString += `T:Converted from MIDI\n`;
    abcString += `M:4/4\n`;
    abcString += `L:1/8\n`;
    abcString += `K:C\n`;

    // 处理每个音轨
    midi.tracks.forEach((track, trackIndex) => {
      if (track.notes.length === 0) return;

      abcString += `V:${trackIndex + 1} clef=treble name="${track.name || 'Track ' + (trackIndex + 1)}"\n`;
      abcString += `[V:${trackIndex + 1}] `;

      // 计算每小节的tick数
      const ticksPerMeasure = midi.header.ppq * 4;
      const ticksPerQuarter = midi.header.ppq;
      
      // 按时间排序音符并限制处理的音符数量
      const maxNotes = 1000;
      const sortedNotes = [...track.notes]
        .sort((a, b) => a.ticks - b.ticks)
        .slice(0, maxNotes);

      // 预处理：将音符按小节分组
      const measureMap = new Map();
      sortedNotes.forEach(note => {
        const measureIndex = Math.floor(note.ticks / ticksPerMeasure);
        if (!measureMap.has(measureIndex)) {
          measureMap.set(measureIndex, []);
        }
        measureMap.get(measureIndex).push(note);
      });

      // 按小节顺序生成ABC记谱
      const measures = [];
      let currentTime = 0;
      
      for (let i = 0; i <= Math.max(...measureMap.keys()); i++) {
        const measureNotes = measureMap.get(i) || [];
        if (measureNotes.length > 0) {
          // 对小节内的音符按时间排序
          measureNotes.sort((a, b) => a.ticks - b.ticks);
          
          // 处理小节内的音符
          const abcNotes = [];
          let measureTime = 0;
          
          measureNotes.forEach((note, noteIndex) => {
            // 计算音符在小节内的相对时间
            const noteStartInMeasure = note.ticks % ticksPerMeasure;
            const noteDuration = note.durationTicks;
            
            // 检查是否需要添加休止符
            if (noteStartInMeasure > measureTime) {
              const restDuration = noteStartInMeasure - measureTime;
              abcNotes.push(createRest(restDuration, ticksPerQuarter));
            }
            
            // 添加音符
            const abcNote = convertNoteToAbc(note, ticksPerQuarter);
            abcNotes.push(abcNote);
            
            measureTime = noteStartInMeasure + noteDuration;
          });
          
          // 如果小节末尾还有空余时间，添加休止符
          if (measureTime < ticksPerMeasure) {
            const restDuration = ticksPerMeasure - measureTime;
            abcNotes.push(createRest(restDuration, ticksPerQuarter));
          }
          
          measures.push(abcNotes);
        } else {
          // 空小节添加全小节休止符
          measures.push(['z4']);
        }
      }

      // 生成ABC字符串
      measures.forEach((measure, index) => {
        abcString += measure.join(' ');
        abcString += index < measures.length - 1 ? ' | ' : ' |]\n';
      });
    });

    console.log('生成的 ABC 记谱:', abcString);
    return abcString;
  } catch (error) {
    console.error('创建ABC记谱失败:', error);
    throw error;
  }
};

// 创建休止符
const createRest = (durationTicks, ppq) => {
  const duration = (durationTicks / ppq) * 2; // 转换为以八分音符为单位的时值
  const clampedDuration = Math.max(0.25, Math.min(8, duration));
  
  if (Math.abs(clampedDuration - 1) < 0.01) return 'z';
  if (Math.abs(clampedDuration - 2) < 0.01) return 'z2';
  if (Math.abs(clampedDuration - 4) < 0.01) return 'z4';
  if (Math.abs(clampedDuration - 0.5) < 0.01) return 'z/2';
  if (Math.abs(clampedDuration - 1.5) < 0.01) return 'z3/2';
  
  return `z${Math.round(clampedDuration * 2)}/2`;
};

// 转换单个音符到ABC格式
const convertNoteToAbc = (note, ppq) => {
  const noteNames = ['C', '^C', 'D', '^D', 'E', 'F', '^F', 'G', '^G', 'A', '^A', 'B'];
  const pitch = note.midi % 12;
  const octave = Math.floor(note.midi / 12) - 4;
  let abcNote = noteNames[pitch];

  // 处理八度
  if (octave > 0) {
    abcNote = abcNote.toLowerCase();
    abcNote += "'".repeat(Math.min(octave, 3));
  } else if (octave < 0) {
    abcNote += ",".repeat(Math.min(Math.abs(octave), 3));
  }

  // 计算时值（以八分音符为基准）
  const duration = (note.durationTicks / ppq) * 2;
  const clampedDuration = Math.max(0.25, Math.min(8, duration));
  
  // 处理标准时值
  if (Math.abs(clampedDuration - 1) < 0.01) return abcNote;
  if (Math.abs(clampedDuration - 2) < 0.01) return abcNote + "2";
  if (Math.abs(clampedDuration - 4) < 0.01) return abcNote + "4";
  if (Math.abs(clampedDuration - 0.5) < 0.01) return abcNote + "/2";
  
  // 处理附点音符
  if (Math.abs(clampedDuration - 3) < 0.01) return abcNote + "3";
  if (Math.abs(clampedDuration - 1.5) < 0.01) return abcNote + "3/2";
  if (Math.abs(clampedDuration - 0.75) < 0.01) return abcNote + "3/4";
  
  // 其他时值使用最接近的标准时值
  const standardDurations = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4];
  const closestDuration = standardDurations.reduce((prev, curr) => 
    Math.abs(curr - clampedDuration) < Math.abs(prev - clampedDuration) ? curr : prev
  );
  
  return convertNoteToAbc({ ...note, durationTicks: closestDuration * ppq / 2 }, ppq);
};

// 将小数转换为分数（简化版本，避免无限循环）
const rationalizeNumber = (x) => {
  const tolerance = 1.0E-6;
  const maxIterations = 10;
  let h1 = 1;
  let h2 = 0;
  let k1 = 0;
  let k2 = 1;
  let b = x;
  let iterations = 0;

  do {
    let a = Math.floor(b);
    let aux = h1;
    h1 = a * h1 + h2;
    h2 = aux;
    aux = k1;
    k1 = a * k1 + k2;
    k2 = aux;
    b = 1 / (b - a);
    iterations++;
  } while (Math.abs(x - h1 / k1) > x * tolerance && iterations < maxIterations && b !== Infinity);
  
  // 如果分母过大，返回简化的分数
  if (k1 > 16) {
    return [Math.round(x * 2), 2];
  }
  
  return [h1, k1];
};

// 修改 MIDI 解析逻辑中的时值计算
const calculateDuration = (ticks, division) => {
  const quarters = ticks / division;
  // 检查是否是标准时值
  if (quarters === 1) return 1; // 四分音符
  if (quarters === 2) return 2; // 二分音符
  if (quarters === 0.5) return 1/2; // 八分音符
  if (quarters === 0.25) return 1/4; // 十六分音符
  
  // 检查是否是附点音符
  if (Math.abs(quarters - 1.5) < 0.01) return 1.5; // 附点四分音符
  if (Math.abs(quarters - 0.75) < 0.01) return 0.75; // 附点八分音符
  if (Math.abs(quarters - 0.375) < 0.01) return 0.375; // 附点十六分音符
  
  return quarters;
};

// 渲染乐谱
const renderScore = async () => {
  if (!scoreContent.value || !props.midiData) return;
  
  try {
    // 清除之前的内容
    scoreContent.value.innerHTML = '';
    
    // 转换 MIDI 到 ABC
    const abcString = await convertMidiToAbc(props.midiData);
    console.log('生成的ABC记谱:', abcString);
    
    // 渲染选项
    const options = {
      ...renderOptions,
      staffwidth: 800,
      // 分页设置
      paginate: true,
      pageWidth: 800,
      pageHeight: 1000,
      scale: 1.3,
      // 每行小节数
      wrap: {
        minSpacing: 1.8,
        maxSpacing: 2.7,
        preferredMeasuresPerLine: 4
      },
      // 每页行数
      staffsep: 60,
      maxshrink: 0.6,
      // 添加页码
      header: "T: Page $P",
      // 自动换行
      format: {
        ...renderOptions.format,
        stretchlast: 0.8,
        alignbars: 1,
        aligncomposer: 1,
        systemsep: 80,
        staffsep: 60,
        composerspace: 0,
        titlespace: 0,
        musicspace: 0,
        vocalspace: 0,
        wordsspace: 0
      }
    };
    
    // 渲染乐谱
    ABCJS.renderAbc(scoreContent.value, abcString, options);
    console.log('乐谱渲染成功');
  } catch (error) {
    console.error('渲染乐谱失败:', error);
  }
};

// 组件挂载时渲染乐谱
onMounted(() => {
  renderScore();
});
</script>

<style lang="scss" scoped>
.score-container {
  width: 100%;
  background: #fff;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  
  .score-content {
    width: 100%;
    overflow-x: auto;
    overflow-y: auto;
    max-height: 80vh;
    padding: 20px;
    
    :deep {
      // 页面样式
      .abcjs-page {
        margin-bottom: 40px;
        padding: 20px;
        background: #fff;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
      }
      
      // 谱表样式
      .abcjs-staff {
        fill: none;
        stroke: #000000;
        stroke-width: 1.5;
      }
      
      // 小节线样式
      .abcjs-bar {
        fill: none;
        stroke: #000000;
        stroke-width: 2;
      }
      
      // 音符样式
      .abcjs-note {
        fill: #000000;
        
        .abcjs-note-head {
          fill: #000000;
          stroke: none;
        }
      }
      
      // 符干样式
      .abcjs-stem {
        stroke: #000000;
        stroke-width: 1.5;
      }
      
      // 横梁样式
      .abcjs-beam {
        fill: #000000;
      }
      
      // 谱号样式
      .abcjs-clef {
        fill: #000000;
        stroke: none;
      }
      
      // 调号样式
      .abcjs-key-signature {
        fill: #000000;
        stroke: none;
      }
      
      // 拍号样式
      .abcjs-time-signature {
        fill: #000000;
        stroke: none;
      }
      
      // 标题样式
      .abcjs-title {
        font-family: "Times New Roman", serif;
        font-size: 24px;
        font-weight: bold;
        margin-bottom: 20px;
      }
      
      // 页码样式
      .abcjs-header {
        font-family: "Times New Roman", serif;
        font-size: 14px;
        color: #666;
        margin: 10px 0;
        text-align: right;
      }
      
      // 文本样式
      .abcjs-text {
        font-family: "Times New Roman", serif;
        font-size: 16px;
      }
    }
  }
}
</style> 