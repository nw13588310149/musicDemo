<template>
  <div class="smart-singing-container">
    <div class="control-panel">
      <h2>智能视唱评分</h2>
      
      <!-- 曲目选择 -->
      <div class="song-selection">
        <select v-model="selectedSong" class="song-select">
          <option value="">请选择曲目</option>
          <option v-for="song in songList" :key="song.id" :value="song">
            {{ song.name }}
          </option>
        </select>
      </div>

      <!-- 录音控制 -->
      <div class="recording-controls">
        <button 
          @click="startRecording" 
          :disabled="isRecording"
          class="control-btn"
        >
          开始录音
        </button>
        <button 
          @click="stopRecording" 
          :disabled="!isRecording"
          class="control-btn"
        >
          停止录音
        </button>
      </div>

      <!-- 评分展示 -->
      <div v-if="score !== null" class="score-display">
        <h3>演唱得分</h3>
        <div class="score">{{ score }}</div>
        <div class="feedback">{{ getFeedback() }}</div>
      </div>
    </div>

    <!-- 音高可视化 -->
    <div class="visualization">
      <canvas ref="visualizer" width="800" height="200"></canvas>
    </div>
  </div>
</template>

<script>
export default {
  name: 'SmartSinging',
  
  data() {
    return {
      isRecording: false,
      mediaRecorder: null,
      audioChunks: [],
      audioContext: null,
      analyzer: null,
      selectedSong: null,
      score: null,
      songList: [
        { id: 1, name: '小星星', notes: [60, 60, 67, 67, 69, 69, 67] }, // MIDI音符
        { id: 2, name: '生日快乐', notes: [60, 60, 62, 60, 65, 64] },
      ],
      pitchData: []
    }
  },

  methods: {
    async startRecording() {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
        
        // 设置音频分析器
        const source = this.audioContext.createMediaStreamSource(stream)
        this.analyzer = this.audioContext.createAnalyser()
        this.analyzer.fftSize = 2048
        source.connect(this.analyzer)
        
        // 配置录音机
        this.mediaRecorder = new MediaRecorder(stream)
        this.audioChunks = []
        this.pitchData = []
        
        this.mediaRecorder.ondataavailable = (event) => {
          this.audioChunks.push(event.data)
        }

        this.mediaRecorder.onstop = () => {
          this.processRecording()
        }

        this.mediaRecorder.start()
        this.isRecording = true
        this.startVisualization()
        this.startPitchDetection()
      } catch (error) {
        console.error('录音失败:', error)
        alert('无法访问麦克风，请确保已授予权限')
      }
    },

    stopRecording() {
      if (this.mediaRecorder) {
        this.mediaRecorder.stop()
        this.isRecording = false
      }
    },

    startPitchDetection() {
      const bufferLength = this.analyzer.frequencyBinCount
      const dataArray = new Float32Array(bufferLength)
      
      const detectPitch = () => {
        if (!this.isRecording) return
        
        this.analyzer.getFloatFrequencyData(dataArray)
        
        // 找到最强的频率
        let maxValue = -Infinity
        let maxIndex = -1
        
        for (let i = 0; i < bufferLength; i++) {
          if (dataArray[i] > maxValue) {
            maxValue = dataArray[i]
            maxIndex = i
          }
        }
        
        // 计算频率
        const frequency = maxIndex * this.audioContext.sampleRate / (2 * bufferLength)
        if (frequency > 0) {
          this.pitchData.push(frequency)
        }
        
        requestAnimationFrame(detectPitch)
      }
      
      detectPitch()
    },

    async processRecording() {
      if (!this.selectedSong || this.pitchData.length === 0) return
      
      // 计算得分
      this.calculateScore()
    },

    calculateScore() {
      if (!this.selectedSong) return

      let totalScore = 0
      const targetNotes = this.selectedSong.notes
      const sampleInterval = Math.floor(this.pitchData.length / targetNotes.length)
      
      for (let i = 0; i < targetNotes.length; i++) {
        const targetFreq = this.midiToFreq(targetNotes[i])
        const sungFreq = this.pitchData[i * sampleInterval]
        
        if (sungFreq) {
          // 计算音高差异（以半音为单位）
          const cents = 1200 * Math.log2(sungFreq / targetFreq)
          const noteScore = Math.max(0, 100 - Math.abs(cents))
          totalScore += noteScore
        }
      }

      this.score = Math.round(totalScore / targetNotes.length)
    },

    midiToFreq(midi) {
      return 440 * Math.pow(2, (midi - 69) / 12)
    },

    startVisualization() {
      const canvas = this.$refs.visualizer
      const ctx = canvas.getContext('2d')
      const bufferLength = this.analyzer.frequencyBinCount
      const dataArray = new Uint8Array(bufferLength)

      const draw = () => {
        if (!this.isRecording) return

        requestAnimationFrame(draw)
        this.analyzer.getByteTimeDomainData(dataArray)

        ctx.fillStyle = 'rgb(200, 200, 200)'
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        ctx.lineWidth = 2
        ctx.strokeStyle = 'rgb(0, 0, 0)'
        ctx.beginPath()

        const sliceWidth = canvas.width * 1.0 / bufferLength
        let x = 0

        for (let i = 0; i < bufferLength; i++) {
          const v = dataArray[i] / 128.0
          const y = v * canvas.height / 2

          if (i === 0) {
            ctx.moveTo(x, y)
          } else {
            ctx.lineTo(x, y)
          }

          x += sliceWidth
        }

        ctx.lineTo(canvas.width, canvas.height / 2)
        ctx.stroke()
      }

      draw()
    },

    getFeedback() {
      if (this.score >= 90) return '太棒了！你的演唱非常出色！'
      if (this.score >= 80) return '很好！继续加油！'
      if (this.score >= 70) return '不错，还有提升空间！'
      return '请继续练习，你可以做得更好！'
    }
  }
}
</script>

<style scoped>
.smart-singing-container {
  padding: 20px;
  max-width: 1000px;
  margin: 0 auto;
}

.control-panel {
  margin-bottom: 30px;
  text-align: center;
}

.song-selection {
  margin: 20px 0;
}

.song-select {
  padding: 10px;
  font-size: 16px;
  width: 200px;
}

.recording-controls {
  margin: 20px 0;
}

.control-btn {
  padding: 10px 20px;
  margin: 0 10px;
  font-size: 16px;
  background-color: #4CAF50;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.control-btn:disabled {
  background-color: #cccccc;
  cursor: not-allowed;
}

.score-display {
  margin-top: 30px;
}

.score {
  font-size: 48px;
  font-weight: bold;
  color: #4CAF50;
  margin: 20px 0;
}

.feedback {
  font-size: 18px;
  color: #666;
}

.visualization {
  margin-top: 20px;
  border: 1px solid #ddd;
  border-radius: 4px;
  overflow: hidden;
}
</style>
