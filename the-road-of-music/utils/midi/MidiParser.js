export class MidiParser {
  constructor() {
    this.midiData = null;
  }

  // 解析MIDI文件
  async parseMidiFile(arrayBuffer) {
    try {
      const data = new Uint8Array(arrayBuffer);
      
      // 检查MIDI文件头
      if (data.length < 14) {
        throw new Error('MIDI文件太短');
      }
      
      // 检查MIDI文件标识符
      const header = String.fromCharCode(...data.slice(0, 4));
      if (header !== 'MThd') {
        throw new Error('不是有效的MIDI文件');
      }
      
      console.log('开始解析MIDI文件:', {
        fileSize: data.length,
        header: header
      });
      
      const midi = this.parseMidiFormat(data);
      this.midiData = this.processMidiData(midi);
      return this.midiData;
    } catch (error) {
      console.error('MIDI解析错误:', error);
      throw error;
    }
  }

  // 读取MIDI buffer
  readMidiBuffer(arrayBuffer) {
    return new Promise((resolve) => {
      const data = new Uint8Array(arrayBuffer);
      resolve(this.parseMidiFormat(data));
    });
  }

  // 解析MIDI格式
  parseMidiFormat(data) {
    // 检查头部长度
    const headerLength = (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
    if (headerLength !== 6) {
      throw new Error('无效的MIDI头部长度');
    }

    const midi = {
      format: (data[8] << 8) | data[9],
      tracks: (data[10] << 8) | data[11],
      division: (data[12] << 8) | data[13],
      events: []
    };

    console.log('MIDI头部信息:', {
      format: midi.format,
      tracks: midi.tracks,
      division: midi.division
    });

    let position = 14;
    for (let track = 0; track < midi.tracks; track++) {
      // 检查轨道头
      if (position + 8 > data.length) {
        throw new Error('意外的文件结尾');
      }
      
      const trackHeader = String.fromCharCode(...data.slice(position, position + 4));
      if (trackHeader !== 'MTrk') {
        throw new Error('无效的轨道头: ' + trackHeader);
      }
      
      const trackLength = (data[position + 4] << 24) | 
                         (data[position + 5] << 16) | 
                         (data[position + 6] << 8) | 
                         data[position + 7];
      
      console.log(`解析轨道 ${track + 1}/${midi.tracks}:`, {
        header: trackHeader,
        length: trackLength,
        position: position
      });
      
      position += 8;
      const trackEndPosition = position + trackLength;
      
      if (trackEndPosition > data.length) {
        throw new Error('轨道长度超出文件范围');
      }

      const trackEvents = [];
      while (position < trackEndPosition) {
        const event = this.readMidiEvent(data, position);
        if (!event) {
          console.warn('无法读取事件，跳过剩余轨道');
          break;
        }
        trackEvents.push(event);
        position += event.length;
      }
      
      midi.events.push(trackEvents);
      position = trackEndPosition;
    }

    return midi;
  }

  // 读取MIDI事件
  readMidiEvent(data, position) {
    if (position >= data.length) {
      return null;
    }

    try {
      const deltaTime = this.readVariableLength(data, position);
      const deltaLength = this.getVariableLengthSize(data, position);
      position += deltaLength;

      if (position >= data.length) {
        return null;
      }

      const event = {
        deltaTime: deltaTime,
        type: data[position],
        length: deltaLength + 1
      };

      switch (event.type & 0xF0) {
        case 0x80: // Note Off
        case 0x90: // Note On
          if (position + 2 >= data.length) return null;
          event.channel = event.type & 0x0F;
          event.note = data[position + 1];
          event.velocity = data[position + 2];
          event.length += 2;
          break;
        case 0xA0: // Polyphonic Key Pressure
          event.channel = event.type & 0x0F;
          event.note = data[position + 2];
          event.pressure = data[position + 3];
          event.length = 4;
          break;
        case 0xB0: // Control Change
          event.channel = event.type & 0x0F;
          event.controller = data[position + 2];
          event.value = data[position + 3];
          event.length = 4;
          break;
        case 0xC0: // Program Change
          event.channel = event.type & 0x0F;
          event.program = data[position + 2];
          event.length = 3;
          break;
        case 0xD0: // Channel Pressure
          event.channel = event.type & 0x0F;
          event.pressure = data[position + 2];
          event.length = 3;
          break;
        case 0xE0: // Pitch Bend
          event.channel = event.type & 0x0F;
          event.value = (data[position + 2] & 0x7F) | ((data[position + 3] & 0x7F) << 7);
          event.length = 4;
          break;
        case 0xF0: // System Exclusive
          if (event.type === 0xFF) { // Meta Event
            event.metaType = data[position + 2];
            const length = this.readVariableLength(data, position + 3);
            event.data = data.slice(position + 4, position + 4 + length);
            event.length = 4 + length;
            
            // 处理特殊的Meta事件
            switch(event.metaType) {
              case 0x51: // Tempo
                event.tempo = (event.data[0] << 16) | (event.data[1] << 8) | event.data[2];
                break;
              case 0x58: // Time Signature
                event.numerator = event.data[0];
                event.denominator = Math.pow(2, event.data[1]);
                break;
              case 0x59: // Key Signature
                event.key = event.data[0];
                event.scale = event.data[1]; // 0 = major, 1 = minor
                break;
            }
          }
          break;
      }

      return event;
    } catch (error) {
      console.error('读取事件错误:', error);
      return null;
    }
  }

  // 读取可变长度值
  readVariableLength(data, position) {
    let value = 0;
    let currentByte;
    let bytesRead = 0;
    
    do {
      if (position + bytesRead >= data.length) {
        throw new Error('读取可变长度值时超出范围');
      }
      
      currentByte = data[position + bytesRead];
      value = (value << 7) | (currentByte & 0x7F);
      bytesRead++;
      
      if (bytesRead > 4) {
        throw new Error('可变长度值过长');
      }
    } while (currentByte & 0x80);
    
    return value;
  }

  // 获取可变长度值的字节数
  getVariableLengthSize(data, position) {
    let bytesRead = 0;
    while (position + bytesRead < data.length && (data[position + bytesRead] & 0x80)) {
      bytesRead++;
      if (bytesRead > 4) {
        throw new Error('可变长度值过长');
      }
    }
    return bytesRead + 1;
  }

  // 处理MIDI数据，转换为易用格式
  processMidiData(midi) {
    const processedData = {
      title: '',
      tempo: 120, // 默认tempo
      timeSignature: { numerator: 4, denominator: 4 }, // 默认拍号
      key: 'C', // 默认C调
      notes: []
    };

    let currentTime = 0;
    let ticksPerBeat = midi.division;
    let microsecondsPerBeat = 500000; // 默认tempo (120 BPM)

    // 处理所有轨道的事件
    midi.events.forEach(track => {
      track.forEach(event => {
        // 处理tempo事件
        if (event.type === 0xFF && event.metaType === 0x51) {
          microsecondsPerBeat = event.tempo;
          processedData.tempo = Math.round(60000000 / microsecondsPerBeat);
        }
        
        // 处理拍号事件
        if (event.type === 0xFF && event.metaType === 0x58) {
          processedData.timeSignature = {
            numerator: event.numerator,
            denominator: Math.pow(2, event.denominator)
          };
        }
        
        // 处理调号事件
        if (event.type === 0xFF && event.metaType === 0x59) {
          const keySignatures = ['Cb', 'Gb', 'Db', 'Ab', 'Eb', 'Bb', 'F', 'C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#'];
          const index = event.key + 7; // 将-7到7的范围转换为0到14
          if (index >= 0 && index < keySignatures.length) {
            processedData.key = keySignatures[index];
            if (event.scale === 1) { // 1表示小调
              processedData.key = processedData.key.toLowerCase();
            }
          }
        }
        
        // 处理音符事件
        if ((event.type & 0xF0) === 0x90 && event.velocity > 0) { // Note On
          const note = {
            note: event.note,
            startTime: currentTime,
            duration: 0, // 稍后计算
            velocity: event.velocity
          };
          processedData.notes.push(note);
        } else if (
          ((event.type & 0xF0) === 0x80) || // Note Off
          ((event.type & 0xF0) === 0x90 && event.velocity === 0) // Note On with velocity 0
        ) {
          // 查找对应的Note On事件并计算持续时间
          const matchingNote = processedData.notes.find(n => 
            n.note === event.note && !n.duration
          );
          if (matchingNote) {
            matchingNote.duration = (currentTime - matchingNote.startTime) * (60000 / processedData.tempo);
          }
        }
        
        // 更新当前时间
        if (event.deltaTime) {
          currentTime += event.deltaTime;
        }
      });
    });

    // 按开始时间排序音符
    processedData.notes.sort((a, b) => a.startTime - b.startTime);
    
    // 移除没有持续时间的音符（可能是由于没有找到对应的Note Off事件）
    processedData.notes = processedData.notes.filter(note => note.duration > 0);
    
    // 添加标题（如果有）
    const titleEvent = midi.events[0]?.find(event => 
      event.type === 0xFF && event.metaType === 0x03
    );
    if (titleEvent) {
      processedData.title = String.fromCharCode(...titleEvent.data);
    }

    return processedData;
  }

  // 获取音符频率
  getNoteFrequency(midiNote) {
    return 440 * Math.pow(2, (midiNote - 69) / 12);
  }

  // 获取特定时间点的音符
  getNotesAtTime(time) {
    return this.midiData.notes.filter(note => 
      time >= note.startTime && time < note.startTime + note.duration
    );
  }
} 