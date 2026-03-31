<template>
	<view class="camp">
		<view class="banner">
			<van-image
			  class="banner_img"
			  src="/static/assets/banner.jpg"
			/>
		</view>
		<view class="bbox">
			<view class="btn_box">
				<view class="lx" v-for="item in list" @click="go(item)">
					<van-circle
					  v-model:current-rate="item.currentRate"
					  :rate="item.num / item.all *80"
					  :color="item.color"
					  size="187px"
					  :stroke-width="80"
					  speed="40"
					  layer-color="#F8F8F8"
					  start-position="bottom"
					/>
					<view class="center" :style="{'boxShadow':'0 0 20px 0 '+item.color2}">
						<view class="bfb">{{(item.all==0?0:item.num/item.all*100).toFixed(0)}}%</view>
						<view class="title">{{item.title}}</view>
					</view>
					<view class="num">
						<view class="bg">{{item.num}}/{{item.all}}</view>
					</view>
				</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';	
import { getQuestionSummary , questionPracticeCreate} from '../../api/home.js'

const router = useRouter();
const list = ref([]);

async function fetchData() {
    try {
        const res = await getQuestionSummary();
        if (res.code === 0) {
			list.value = [
			    { title: "顺序练习", num: res.data.sequence.doneCount, all: res.data.sequence.allCount, color: "#00c9a4", color2: 'rgba(44, 205, 161,0.3)', currentRate: 0, type: "sequence" ,practiceId:res.data.sequence.practiceId},
			    { title: "随机练习", num: res.data.random.doneCount, all: res.data.random.allCount, color: "#fe83a2", color2: 'rgba(254, 131, 162,0.3)', currentRate: 0, type: "random" ,practiceId:res.data.random.practiceId},
			    { title: "考前密卷", num: res.data.exam.doneCount, all: res.data.exam.allCount, color: "#775dfe", color2: 'rgba(119, 93, 254 ,0.3)', currentRate: 0, type: "exam" ,practiceId:res.data.exam.practiceId},
			    { title: "错题集", num: res.data.error.doneCount, all: res.data.error.allCount, color: "#e61f62", color2: 'rgba(230, 31, 98 ,0.3)', currentRate: 0, type: "error" ,practiceId:res.data.error.practiceId}
			];
			// 如果为null则创建题目----初始化
			if(res.data.sequence.status == null){
				questionPracticeCreate({"practiceType": "sequence","size": '150'}).then(res =>{
					list.value[0] = { title: "顺序练习", num: res.data.doneCount, all: res.data.allCount, color: "#00c9a4", color2: 'rgba(44, 205, 161,0.18)', currentRate: 0, type: 1 ,practiceId:res.dta.practiceId}
				})
			}
			if(res.data.random.status == null){
				questionPracticeCreate({"practiceType": "random","size": '150'}).then(res =>{
					list.value[1] = { title: "随机练习", num: res.data.doneCount, all: res.data.allCount, color: "#fe83a2", color2: 'rgba(254, 131, 162,0.18)', currentRate: 0, type: 2 ,practiceId:res.dta.practiceId}
				})
			}
			if(res.data.sequence.status == null){
				questionPracticeCreate({"practiceType": "exam","size": '150'}).then(res =>{
					list.value[2] = { title: "考前密卷", num: res.data.doneCount, all: res.data.allCount, color: "#775dfe", color2: 'rgba(119, 93, 254 ,0.18)', currentRate: 0, type: 3 ,practiceId:res.dta.practiceId}
				})
			}
			

        }
    } catch (error) {
        console.error("Error fetching data:", error);
    }
}

function go(item){
	router.push({name:'camp_answer',state:{id:JSON.stringify(item)}})
}

fetchData();
</script>

<style lang="scss" scoped>
	::v-deep .van-circle{
		svg{
			path:nth-child(1){
				stroke-width:8px !important;
			}
			path:nth-child(2){
				transform-origin: center;
				transform: rotate(36deg);
			}
		}
	}
	.camp{
		width: 100%;
		height: 100%;
		.banner{
			border-radius: 9px;
			overflow: hidden;
			height: 240px;
			.banner_img{
				width: 100%;
			}
		}
		.bbox{
			padding: 10px;
			background: #fff;
			border-radius: 9px;
			margin-top: 12px;
			height: calc(100% - 256px);
		}
		.btn_box{
			width: calc(100% - 50px);
			margin-left: 25px;
			display: flex;
			height: 188px;
			margin-top: 48px;
			align-items: center;
			justify-content: center;
			.num{
			    font-weight: 400;
			    margin-top: 2px;
			    font-size: 17px;
			    width: 84px;
			    height: 42px;
			    background: #fff;
			    border-radius: 21px;
			    position: absolute;
			    left: 50%;
			    transform: translateX(-42px);
			    bottom: 0px;
			    display: flex;
			    justify-content: center;
			    align-items: center;
				.bg{
					width: 66px;
					height: 22px;
					display: flex;
					justify-content: center;
					align-items: center;
					border-radius: 16px;
					background: #F8F8F8;
					font-size: 11px;
					color: #000;
				}
			}
			.lx{
				width: 25%;
				text-align: center;
				position: relative;
				.center{
					position: absolute;
					left: 50%;
					width: 134px;
					height: 134px;
					border-radius: 50%;
					overflow: hidden;
					transform: translateX(-67px);
					top: 27px;
					box-shadow: 0 0 20px 0 #00c9a426;
					display: flex;
					justify-content: center;
					align-items: center;
					flex-direction: column;
					.bfb{
						font-size: 30px;
						color: #000;
					}
					.title{
						font-weight: 400;
						font-size: 14px;
					}

				}
			}
			
		}
	}
</style>