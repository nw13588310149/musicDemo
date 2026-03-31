class AudioPlayer {
    constructor() {
        this.audioContext = null
        this.currentSong = null
        this.initAudioContext()
    }

    initAudioContext() {
        this.audioContext = uni.createInnerAudioContext()
        
        // 监听事件
        this.audioContext.onError((res) => {
            console.error('音频播放错误:', res.errMsg)
            uni.showToast({
                title: '播放失败，请稍后重试',
                icon: 'none'
            })
        })
        
        this.audioContext.onEnded(() => {
            this.onPlayEnd && this.onPlayEnd()
        })
    }

    play(url, title = '') {
        if (!url) return
        
        try {
            this.audioContext.src = url
            this.audioContext.title = title
            this.audioContext.play()
            
            // 显示播放状态
            uni.showToast({
                title: '开始播放',
                icon: 'none'
            })
        } catch (e) {
            console.error('播放失败:', e)
        }
    }

    pause() {
        this.audioContext && this.audioContext.pause()
    }

    stop() {
        this.audioContext && this.audioContext.stop()
    }

    seek(position) {
        this.audioContext && this.audioContext.seek(position)
    }
}

export default new AudioPlayer() 