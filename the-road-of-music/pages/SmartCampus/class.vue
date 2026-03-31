<template>
	<view class="schoolBox">
		<view class="head">
			<van-image
			  class="icon"
			  :src="'/static/assets/noti.png'"
			/> 
			消息通知
			<!-- <van-image
			  class="icon qrcode"
			  :src="'/static/assets/class_qrcode.png'"
			/> -->
		</view>
		<!-- 我的班级 -->
		<view class="my_class">
			<view class="class_li" v-for="item in list" @click="go(item)">
				<van-image
				  class="icon"
				  :src="'/static/assets/class.png'"
				/> 
				<view class="name">
					{{item.name}}
					<view v-if="item.badge" class="badge" :style="{ background: '#e61f62' }">
					  {{ item.badge }}
					</view>
				</view>
				<view class="notice thin">群消息通知</view>
				<view class="time thin">2024.05.14</view>
			</view>
		</view>
	</view>
</template>
<script setup>
import { ref ,onMounted,onBeforeUnmount,computed} from 'vue';
import {useRouter} from 'vue-router';	
import {classList} from '/api/home.js';
import { useStore } from 'vuex';
const store = useStore();

const info =ref({})
const list = ref();
const router = useRouter();
const msgId = ref(0);

function getInfo(){
	syncMsg({"offsetMsgId": msgId.value,"size": 20}).then(res =>{
		if(res.code == 0){
			msgId.value = res.data.offsetMsgId;
		}
	})
}

const interTime = ref(null);
// onMounted(()=>{
// 	interTime.value = setInterval(function(){
// 		getInfo()
// 	},3000)
// })

onBeforeUnmount(()=>{
	if (interTime.value) {
			clearInterval(interTime.value);
			interTime.value = null;
		}
})

function go(item){
	let arr = store.getters.getMsg;
	arr = arr.filter(e => e.classId !== item.id);
	store.dispatch('updateMsg', arr);
	router.push({
		name: 'chat',
		state: { id: item.classId ?? item.id, name: item.name }
	})
}

const classifyByClassId = (array) => {
  return array.reduce((acc, item) => {
    if (!acc[item.classId]) {
      acc[item.classId] = [];
    }
    acc[item.classId].push(item);
    return acc;
  }, {});
};

classList().then(res =>{
	if(res.code == 0){
		// const arr = store.getters.getMsg;
		// let arr1 = classifyByClassId(arr);
		// res.data.forEach(e =>{
		// 	let a = arr1[e.id];
		// 	e.badge = a?.length ;
		// })
		list.value = res.data;
	}
})

</script>

<style lang="scss" scoped>
	.schoolBox{
		height: 100%;
		padding: 12px;
		.my_class{
			.class_li{
				height:56px;
				line-height: 56px;
				display: flex;
				align-items: center;
				position: relative;
				border-bottom: 1px solid #f6f7fb;
				.icon{
					width: 30px;
					height: 30px;
					margin-right: 10px;
				}
				.name{
					margin-right: 40px;
					position: relative;
					top: -8px;
					.badge{
						    min-width: 18px;
						    font-size: 9px;
						    position: absolute;
						    right: -20px;
						    top: 12px;
						    height: 14px;
						    line-height: 14px;
						    justify-content: center;
						    display: flex;
						    align-items: center;
						    text-align: center;
						    padding: 0 4px;
						    border-radius: 14px;
						    color: white;
					}
				}
				.notice{
					    position: absolute;
					    left: 41px;
					    font-size: 10px;
					    color: #6b6b6b;
					    bottom: -10px;
				}
				.time{
					margin-left: auto;
					font-size: 12px;
					color: #d5d5d6;
				}
			}
		}
		.head{
			display: flex;
			align-items: center;
			position: relative;
			height: 50px;
			border-bottom: 1px solid #f8f8f8;
			font-weight: 400;
			padding-bottom: 10px;
			.icon{
				width: 30px;
				height: 30px;
				margin-right: 10px;
			}
			.qrcode{
				margin-left: auto;
				margin-right: 0;
			}
		}
	}
	.info{
		padding: 16px;
		position: relative;
		padding-left: 20px;
		border-bottom: 1px solid  #f8f8f8;
	
	}
</style>