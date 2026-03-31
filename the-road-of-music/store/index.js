import { createStore } from 'vuex'

const store = createStore({
  state() {
    return {
      keyWidth: 2.857, // 默认宽度为2.857%
	  isCollapsed: false,
	  info:{},
	  msgList:[],
	  msgList2:[],
	  id:'',
	  time:"",
	  audioStream: null,
	  isShow:false,
    }
  },
  mutations: {
    adjustWidth(state) {
      state.keyWidth += 1 // 每次增加1%
      if (state.keyWidth > 10) {
        state.keyWidth = 10 // 超过100%后重新开始
      }
      localStorage.setItem('pianoKeyWidth', state.keyWidth.toString()) // 保存宽度值到 localStorage
    },
	delWidth(state) {
	  state.keyWidth -= 1 // 每次减少1%
	  if (state.keyWidth <= 2.857) {
	    state.keyWidth = 2.857 // 超过100%后重新开始
	  }
	  localStorage.setItem('pianoKeyWidth', state.keyWidth.toString()) // 保存宽度值到 localStorage
	},
    loadWidth(state) {
      const savedWidth = localStorage.getItem('pianoKeyWidth')
      if (savedWidth) {
		  
        state.keyWidth = parseInt(savedWidth)
      }
    },
	 setCollapsed(state, collapsed) {
	      state.isCollapsed = collapsed;
	},
	setIsShow(state, payload) {
		state.isShow = payload;
	},
	SET_INFO(state, payload) {
		state.info = payload;
	},
	SET_ID(state, payload) {
		state.id = payload;
	},
	SET_MSG(state, msgList) {
		state.msgList = msgList;
	},
	SET_MSG2(state, msgList) {
		state.msgList2 = msgList;
	},
	SET_TIME(state, payload) {
		state.time = payload;
	},
	setAudioStream(state, stream) {
	    state.audioStream = stream;
	}
  },
  actions:{
	  updateInfo({commit},info){
		  commit('SET_INFO',info)
	  },
	  updateId({commit},info){
	  		  commit('SET_ID',info)
	  },
	  updateMsg({commit},info){
	  		  commit('SET_MSG',info)
	  },
	  updateMsg2({commit},info){
	  		  commit('SET_MSG2',info)
	  },
	  updateTime({commit},info){
	  		  commit('SET_TIME',info)
	  },
	  updateAudioStream({ commit }, stream) {
	        commit('setAudioStream', stream);
	  },
	  updateIsShow({ commit }, stream) {
	        commit('setIsShow', stream);
	  }
  },
  getters:{
	  getInfo:(state) => state.info,  
	  getMsg:(state) => state.msgList,
	  getMsg2:(state) => state.msgList2,
	  getId:(state) => state.id,
	  getTime:(state) => state.time,
	  getIsShow:(state) => state.isShow
  }
})

export default store
