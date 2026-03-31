<template>
  <view class="note">
	  <!-- 头部 -->
	  <view class="top-nav">
	    <view class="title"><van-icon class="right_icon" name="/static/assets/left1.png" @click="router.go(-1)"/></view>
	    <label class="color" for="color">画笔颜色：</label>
	    <input type="color" v-model="color" id="color">
	    <label class="zx" for="thickness">画笔粗细：</label>
		<van-slider v-model="thickness" id="thickness" class="range" min="1" max="20" @change="onChange" />
		<view class="clear" @click="clearCanvas">清空画布</view>
		<view class="bc" @click="bc">保存</view>
	  </view>
	  
	  <view class="box">
		  <!-- 左侧 -->
<!-- 		  <view class="left">
			  <view class="scroll">
				  <view class="li"  :style="{backgroundImage: `url(${item.content || bg})`}" v-for="(item,index) in list" :class="{active: index === selectedItem}"
					@click="selectItem(index)">
				  				  <view class="bg">
				  					  <view class="num">{{index+1}}</view>
				  					  <view class="delB">
				  					  					<van-icon class="del" name="static/assets/bg_close.jpg" @click="del(item)"/>  
				  					  </view>
				  				  </view>
				  </view>
			  </view>
			  <view class="add" @click="add">
				  添加画布
			  </view>
		  </view> -->
		  <!-- 右侧 -->
		  <view class="right">
			  <view class="canvasBox" >
				  <view class="bg">
					  <view class="wxp" v-if="id == 0">
						  <view v-for="item in 19" class="li">
							  <view class="line" v-for="item in 5"></view>
						  </view>
					  </view>
					  <view class="bjb" v-if="id == 1">
					  		<view v-for="item in 26" class="li">
					  		</view>
					  </view>
				  </view>
				 <yl-graffiti
						class="canvas"
				         ref="graffitiRef"
				         canvas-id="myCanvas"
				         width="930"
				         height="1335"
				         :shape="curShape"
				         :lineColor="color"
				         :lineWidth="thickness"
				         :bgImage="detailBg"
				         @stepChanged="stepChanged">
				     </yl-graffiti>
			  </view>
		  </view>
	  </view>
  </view>
</template>
<script setup>
import { ref , onMounted} from 'vue';
import { useRouter } from 'vue-router';
import {noteSave , fileUpload} from '../../api/home.js' 
import ylGraffiti from "/components/yl-graffiti/yl-graffiti.vue";
import { showToast , showConfirmDialog ,showLoadingToast, Toast} from 'vant';

const graffitiRef = ref(null);

const router = useRouter();
const id = history.state.type;

const color = ref("");
const thickness = ref(1);

const items = ref([
  { title: '五线谱', background: '/static/assets/bg_wxp2.jpg' },
  { title: '笔记本', background: '/static/assets/bg_bjb2.jpg' },
  { title: '白纸', background: '' },
]);
const bg = items.value[id].background;

const list = ref([{
	backBg:bg,
	content:history.state.param1 || "",
}]);

const detailBg = history.state.param1;

const selectedItem = ref(0);

const selectItem = (index) => {
	graffitiRef.value.saveCanvas().then(res => {
		list.value[selectedItem.value].content = res;
		selectWritingOption(5)
		selectedItem.value = index;
	})
	
};

const stepInfo = ref({
  curStep: -1,
  len: 0,
});

const saving = ref(false);

const stepChanged = (e) => {
  stepInfo.value = e;
};

function clearCanvas(){
	selectWritingOption(5)
}

function add(){
	list.value.push({
	backBg:bg,
	content:"",
})
}

const savePicture = () => {
  saving.value = true;

};

function bc(){
	saving.value = true;
	graffitiRef.value.saveCanvas().then((res) => {
	  const formData = new FormData();
	  const file = base64ToFile(res, 'example.jpg');
	  formData.append('file', file)
	  let load = showLoadingToast({
	    message: '上传中...',
	    forbidClick: true,
	    loadingType: 'spinner',
	    duration:0,
	  });
	  fileUpload(formData).then(res => {
	    load.close();
	    if(res.code == 0){
			let param = {
				  "categoryId": history.state.id,
				  "paperType": history.state.type,
				  "param1": res.data,
				  "param2": "string",
				  "param3": "string",
				  "param4": "string",
				  "param5": "string",
				  "title": history.state.title
			}
			noteSave(param).then(res =>{
				if(res.code == 0){
					router.push({name:'note'})
				}
			})
			
	    }else{
	  	  showToast(res.msg)
	    }
	  }).catch(error => {
	    console.error(error);
	  });
	});
}

function base64ToFile(base64String, filename) {
  // 将 base64 字符串中的前缀去掉（如果有）
  const base64Data = base64String.split(',')[1];
  
  // 将 base64 字符串转换为字节数组
  const byteString = atob(base64Data);
  const arrayBuffer = new ArrayBuffer(byteString.length);
  const intArray = new Uint8Array(arrayBuffer);
  for (let i = 0; i < byteString.length; i++) {
    intArray[i] = byteString.charCodeAt(i);
  }

  // 创建 Blob 对象并将其转换为 File 对象
  const blob = new Blob([arrayBuffer], { type: 'image/jpeg' }); // 根据具体类型调整 MIME 类型
  return new File([blob], filename, { type: 'image/jpeg' });
}	

function del(item){
  const index = list.value.indexOf(item);
  if (index !== -1) {
    list.value.splice(index, 1);
  }
}

const selectWritingOption = (index) => {
  switch (index) {
    case 0:
    case 1:
    case 2:
      optIndex.value = index;
      break;
    case 3:
      graffitiRef.value.repeal();
      break;
    case 4:
      graffitiRef.value.redo();
      break;
    case 5:
      graffitiRef.value.clearBoard();
      break;
    default:
      break;
  }
};


</script>
<style lang="scss" scoped>
	::v-deep #defCanvas{
		display: none;
	}
	.note{
		width: 100%;
		border-radius: 9px;
		height: 100%;
		
		.top-nav {
		  display: flex;
		  justify-content: flex-end;
		  align-items: center;
		  height: 44px;
			background: #fff;
			border-radius: 9px;
			overflow: hidden;
			position: relative;
			.range{
				width: 160px;
				::v-deep .van-slider__button{
					width: 15px;
					height: 15px;
					background: #00c9a4;
				}
				::v-deep .van-slider__bar{
					background: #00c9a4;
				}
			}
			.title {
				position: absolute;
				left: 4px;
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
			.clear{
				    width: 80px;
				    background: #fff;
					box-shadow: 0 0 8px #f3f3f3;
				    color: #00c9a4;
				    font-size: 14px;
				    height: 26px;
				    border-radius: 5px;
				    line-height: 26px;
				    text-align: center;
				    margin-right: 10px;
					margin-left: 16px;
			}	
			.bc{
				width: 80px;
				background: #00c9a4;
				color: #fff;
				font-size: 14px;
				height: 26px;
				border-radius: 5px;
				line-height: 26px;
				text-align: center;
				margin-right: 10px;
				margin-left: 6px;
			}
			.zx{
				margin-left: 16px;
			}
			#color ::v-deep .uni-input-input{
				    width: 25px;
				    height: 25px;

			}
		}
		.box{
			margin-top: 10px;
			height: calc(100% - 54px);
			background: #fff;
			border-radius: 9px;
			display: flex;
			border-radius: 9px;
			overflow: hidden;
			.scroll::-webkit-scrollbar{
			  display: none; /* Chrome/Safari/Opera */
			}
			.scroll{
				height: calc(100% - 50px);
				overflow-y: auto;
				-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
				  scrollbar-width: none; /* Firefox */
				  -ms-overflow-style: none; /* IE/Edge */
			}
			.left{
				width: 230px;
				height: 100%;
				padding: 15px;
				flex-shrink:0;
				justify-content: center;
				background: #e9e9e9;
				position: relative;

				.li{
					width: 200px;
					height: 286px;
					background-repeat: no-repeat;
					background-size: contain;
					overflow: hidden;
					margin-bottom: 15px;
					.bg{
						width: 100%;
						height: 100%;
						background: #9b9b9b47;
					}
					.num{
						font-size: 40px;
						color: #00c9a4;
						height: 200px;
						line-height: 130px;
						text-align: center;
					}
					.delB{
						text-align: center;
					}
					.del{
						font-size: 40px;
					}
				}
				.li.active{
					border: 1px solid #00c9a4;
				}
				.add{
					position: absolute;
					bottom: 10px;
					background: #fff;
					border-radius: 9px;
					width: 200px;
					height: 50px;
					text-align: center;
					line-height: 50px;
				}
			}
			.right{
				display: flex;
				justify-content: center;
				width: 100%;
				overflow-y: auto;
				.canvasBox{
					background-size: contain;
					background-repeat: no-repeat;
					width: calc(100% - 6px);
					background: #e9e9e9;
					height: 1335px;
					box-shadow: 0 0 8px 0 #f3f3f3;
					position: relative;
					.bg{
						width: 100%;
						height: 100%;
						background: #fff;
						padding: 15px;
						.wxp{
							width: 100%;
							height: 100%;
							.li{
								height: 70px;
								.line{
									border-bottom: 1px solid #d5d5d6;
									height: 10px;
								}
							}
						}
						.bjb{
							width: 100%;
							height: 100%;
							.li{
								height: 50px;
								border-bottom: 1px solid #d5d5d6;
							}
						}
					}
					.canvas{
						position: absolute !important;
						top: 0;
						left: 0;
						width: 100%;
						height: 100%;
						background-size: contain;
					}
				}
			}
		}
	}
</style>