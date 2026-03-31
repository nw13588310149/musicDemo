export class ScoreAnalyzer {
  constructor(midiReference) {
    this.reference = midiReference;
    this.recordings = [];
    this.settings = {
      pitchTolerance: 50,    // 音高容差（音分）
      timingTolerance: 150,  // 时间容差（毫秒）
      minNoteDuration: 100   // 最小音符持续时间（毫秒）
    };
  }

  // 添加录音数据点
  addRecordingPoint(time, pitch) {
    this.recordings.push({
      time,
      pitch,
      matched: false
    });
  }

  // 计算评分
  calculateScore() {
    const pitchScore = this.calculatePitchScore();
    const timingScore = this.calculateTimingScore();
    const overallScore = this.calculateOverallScore(pitchScore, timingScore);

    return {
      total: Math.round(overallScore),
      pitch: Math.round(pitchScore),
      timing: Math.round(timingScore),
      feedback: this.generateFeedback(pitchScore, timingScore)
    };
  }

  // 计算音高得分
  calculatePitchScore() {
    let totalPoints = 0;
    let earnedPoints = 0;

    this.reference.notes.forEach(refNote => {
      const matchingRecordings = this.getMatchingRecordings(refNote);
      
      if (matchingRecordings.length > 0) {
        const avgCentsDiff = this.calculateAverageCentsDifference(matchingRecordings, refNote);
        const noteScore = this.calculateNoteScore(avgCentsDiff);
        earnedPoints += noteScore;
      }
      
      totalPoints += 100;
    });

    return (earnedPoints / totalPoints) * 100;
  }

  // 计算时间得分
  calculateTimingScore() {
    let totalPoints = 0;
    let earnedPoints = 0;

    this.reference.notes.forEach(refNote => {
      const matchingRecordings = this.getMatchingRecordings(refNote);
      
      if (matchingRecordings.length > 0) {
        const timingDiff = this.calculateTimingDifference(matchingRecordings[0], refNote);
        const noteScore = this.calculateTimingScore(timingDiff);
        earnedPoints += noteScore;
      }
      
      totalPoints += 100;
    });

    return (earnedPoints / totalPoints) * 100;
  }

  // 获取匹配的录音点
  getMatchingRecordings(referenceNote) {
    return this.recordings.filter(record => {
      const timeMatch = Math.abs(record.time - referenceNote.startTime) <= this.settings.timingTolerance;
      const pitchMatch = Math.abs(record.pitch - referenceNote.frequency) <= this.settings.pitchTolerance;
      return timeMatch && pitchMatch && !record.matched;
    });
  }

  // 计算音分差的平均��
  calculateAverageCentsDifference(recordings, referenceNote) {
    const centsDiffs = recordings.map(record => {
      return 1200 * Math.log2(record.pitch / referenceNote.frequency);
    });
    
    return centsDiffs.reduce((sum, diff) => sum + Math.abs(diff), 0) / centsDiffs.length;
  }

  // 计算单个音符的得分
  calculateNoteScore(centsDiff) {
    if (centsDiff <= 25) return 100;  // 完美
    if (centsDiff <= 50) return 80;   // 很好
    if (centsDiff <= 100) return 60;  // 一般
    if (centsDiff <= 200) return 40;  // 差
    return 20;                        // 很差
  }

  // 计算时间差异得分
  calculateTimingScore(timingDiff) {
    if (timingDiff <= 50) return 100;   // 完美
    if (timingDiff <= 100) return 80;   // 很好
    if (timingDiff <= 150) return 60;   // 一般
    if (timingDiff <= 200) return 40;   // 差
    return 20;                          // 很差
  }

  // 计算总体得分
  calculateOverallScore(pitchScore, timingScore) {
    return (pitchScore * 0.6) + (timingScore * 0.4);
  }

  // 生成反馈
  generateFeedback(pitchScore, timingScore) {
    const feedback = [];

    // 音准反馈
    if (pitchScore >= 90) {
      feedback.push('音准非常准确！');
    } else if (pitchScore >= 70) {
      feedback.push('音准基本准确，个别音符需要调���。');
    } else if (pitchScore >= 50) {
      feedback.push('音准有待提高，建议多加练习。');
    } else {
      feedback.push('音准需要加强训练。');
    }

    // 节奏反馈
    if (timingScore >= 90) {
      feedback.push('节奏把握得很好！');
    } else if (timingScore >= 70) {
      feedback.push('节奏基本准确，略有不稳。');
    } else if (timingScore >= 50) {
      feedback.push('节奏感需要加强。');
    } else {
      feedback.push('建议使用节拍器练习节奏。');
    }

    // 添加具体建议
    if (pitchScore < timingScore) {
      feedback.push('建议重点练习音准，可以使用唱名练习。');
    } else if (timingScore < pitchScore) {
      feedback.push('建议重点练习节奏，可以先打拍子再唱。');
    }

    return feedback.join(' ');
  }

  // 重置记录
  reset() {
    this.recordings = [];
  }
} 