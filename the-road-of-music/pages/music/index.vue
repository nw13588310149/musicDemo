<template>
  <view class="music-companion">
    <view class="top-nav">
      <view class="title"><van-icon class="right_icon" name="/static/assets/right.png" /></view>
      <view class="nav-items">
        <van-button plain class="btn" type="default" :class="activeTab === 'piano' ? 'active  animate__animated  animate__bounceIn' : ''" @click="selectTab('piano')">虚拟钢琴</van-button>
        <van-button plain class="btn" type="default" :class="activeTab === 'metronome' ? 'active  animate__animated  animate__bounceIn' : ''" @click="selectTab('metronome')">节拍器</van-button>
        <van-button plain class="btn" type="default" :class="activeTab === 'tuner' ? 'active  animate__animated  animate__bounceIn' : ''" @click="selectTab('tuner')">调音器</van-button>
      </view>
    </view>
    <view class="content-area">
      <view v-if="activeTab === 'piano'">
        <!-- 虚拟钢琴组件 -->
        <virtual-piano />
      </view>
      <view v-if="activeTab === 'metronome'">
        <!-- 节拍器组件 -->
        <metronome />
      </view>
      <view v-if="activeTab === 'tuner'">
        <!-- 调音器组件 -->
        <tuner />
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref } from 'vue';
import VirtualPiano from './VirtualPiano.vue';
import Metronome from './Metronome.vue';
import Tuner from './Tuner.vue';
import 'animate.css'
const activeTab = ref('piano');

function selectTab(tab) {
  activeTab.value = tab;
}
</script>

<style scoped>
.music-companion {
	height: 100%;
  .top-nav {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    width: 100%;
    height: 44px;
	background: #fff;
	border-radius: 9px;
	overflow: hidden;
	
  }

  .title {
	  margin-left: 4.5px;
    width: 44px;
    height: 44px;
    line-height: 44px;
  	text-align: center;
  	font-size: 18px;
  	color: #fff;
  	letter-spacing: 4px;
  	display: flex;
  	justify-content: center;
  	align-items: center;
    /* Add title styling */
  	.right_icon{
  			font-size: 29px;
  			}
  }


  .nav-items {
    display: flex;

    /* Add button styling if necessary */
	.btn{
		height: 26px;
		border: none;
		background: #f6f7fb;
		border-radius: 4px;
		margin: 0 6px;
		font-size: 16px;
		color:#fff;

	}
	.active{
		background: #111;
	}
	::v-deep span{
		color: #545454;
	}
	.active ::v-deep span{
		color: #fff;
	}
  }

  .content-area {
    width: 100%;
	margin-top: 10px;
    height: calc(100% - 54px);
	background: #fff;
	border-radius: 9px;
	overflow: hidden;
    /* Add content area styling */
	view{
		height: 100%;
	}
  }
}
</style>
