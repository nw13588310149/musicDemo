<template>
	<view class="theory_content">
		<view class="top">
		  <van-icon class="return" name="/static/assets/left1.png" @click="left" />
		  <view class="btn zy" v-if="item.firstMenu != 6" @click="openZy()">课程作业</view>
		  <view class="btn answer" @click="openDa()">查看答案</view>
		</view>
		<!-- 内容区 -->
		<view class="box">
			<!-- 分享按钮 -->
			<view class="fenxiang" @click="fenxiang()">
				分享
			</view>
			
			<!-- 如果有PDF文件，优先使用iframe显示 -->
			<view v-if="hasPdf" class="pdf-container">
				<!-- 错误信息显示 -->
				<view v-if="loadError" class="error-container">
					<view class="error-message">
						<text class="error-title">{{ errorMessage }}</text>
						<view class="error-actions">
							<button @click="retryLoad" class="primary-btn">重新加载</button>
							<button @click="openExternal" class="secondary-btn">在新窗口打开</button>
						</view>
						<!-- 直接下载链接 -->
						<div class="direct-link">
							<a :href="pdfUrl" target="_blank" class="download-link">直接下载/查看PDF</a>
						</div>
					</view>
				</view>
				
				<!-- 加载中显示 -->
				<view v-if="isLoading" class="loading-container">
					<view class="spinner"></view>
					<text class="loading-text">加载中...</text>
				</view>
				
				<!-- iframe展示PDF -->
				<view v-if="pdfUrl && !loadError && !isLoading" class="pdf-iframe-container">
					<iframe 
						class="pdf-iframe" 
						:src="pdfUrl" 
						ref="pdfIframe"
						@load="handleIframeLoad" 
						@error="handleIframeError"
						frameborder="0" 
						allowfullscreen
					></iframe>
				</view>
			</view>
			
			<!-- 如果没有PDF，则显示HTML内容 -->
			<view v-else class="content" v-html="item.longText1"></view>
		</view>
		
		<!-- 查看作业 -->
		<van-dialog class="dialog" v-model:show="show" width="80%">
			<van-icon class="close" @click="show=false" name="/static/assets/close.jpg" />
			<view class="box" >
				<img :src="img" v-for="img in item.img1" style="width: 100%;"/>
			</view>
		</van-dialog>
		
		<!-- 查看答案 -->
		<van-dialog class="dialog" v-model:show="show1" :showConfirmButton='false' width="80%">
			<van-icon class="close" @click="show1=false" name="/static/assets/close.jpg" />
			<view class="box">
				<img :src="img" v-for="img in item.img2" style="width: 100%;"/>
			</view>
		</van-dialog>
		
		<!-- 分享课件 -->
		<van-popup class="fxLeftBox" v-model:show="showL" position="left" style="width: 50%;height: 100%;" overlay-class="fxLeftOver">
			<view class="fxLeft">
				<view class="fxLeft_title">
					<view class="flex_return">
						<van-icon
						  class="returnIcon"
						  :name="'/static/assets/qunL.png'"
						/> 
						<view class="text">返回</view>
					</view>
				</view>
				<view class="fxContent">
					<view class="fxTitle">
						您即将分享的课件
						<view class="fxTitleName">{{fxItem.title}}</view>
					</view>
					<view class="fxList">
						您的班级群: 
						<view class="fxLi" v-for="item in classItem" @click="item.isCheck = !item.isCheck">
							<van-icon
							  class="fxLiIcon"
							  :name="'/static/assets/class.png'"
							/> 
							<view class="fxLiname">{{item.name}}</view>
							<van-icon
							  class="fxLiCheck"
							  :name="item.isCheck?'/static/assets/checked.png':'/static/assets/check.png'"
							/> 
						</view>
					</view>
					<view class="fxBtn">
						<view class="fxBBtn" @click="fasong">发送</view>
					</view>
				</view>
			</view>
		</van-popup>
	</view>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { getDetail, textbookRecordSave, classList, sendMsg } from '/api/home.js';
import { showToast } from 'vant';
import { useStore } from 'vuex';

// 核心响应式数据
const router = useRouter();
const store = useStore();
const item = ref({});
const id = history.state.id;
const show = ref(false);
const show1 = ref(false);
const fxItem = ref({});
const classItem = ref([]);
const showL = ref(false);

// PDF相关状态 - 仅保留iframe相关状态
const isLoading = ref(true);
const loadError = ref(false);
const errorMessage = ref('');
const pdfIframe = ref(null);
const isIOS = ref(false);
const pdfUrl = ref(''); 
const hasPdf = ref(false);

// 获取课程详情
onMounted(async () => {
  console.log('组件已挂载');
  
  // 检测设备类型 - 仅用于记录
  detectIOSDevice();
  
  const vipExpireDate = store.getters.getInfo.vipExpireDate;
  
  try {
    // 获取课程详情
    const res = await getDetail(id);
    
    // 检查VIP状态
    if (res.data.vip == 1) {
      if (vipExpireDate == null) {
        showToast("您还未开通会员");
        router.push({name:"personal"});
        return;
      } else if (!isFutureDate(vipExpireDate)) {
        showToast("您的会员已过期，请续费");
        router.push({name:"personal"});
        return;
      }
    }
    
    // 设置课程数据
    item.value = res.data;
    
    // 解析图片数据
    try {
      item.value.img1 = JSON.parse(item.value.img1);
    } catch {}
    
    try {
      item.value.img2 = JSON.parse(item.value.img2);
    } catch {}
    
    // 检查是否有PDF文件
    checkPdfFile();
    
    // 如果有PDF，加载iframe
    if (hasPdf.value) {
      console.log('发现PDF文件，使用iframe加载:', pdfUrl.value);
      loadPdfWithIframe();
    }
  } catch (err) {
    console.error('获取课程详情失败:', err);
    showToast('获取课程详情失败');
  }
});

// iframe处理函数
const handleIframeLoad = () => {
  console.log('PDF iframe加载成功');
  isLoading.value = false;
  
  // 延迟一小段时间检查iframe内容
  setTimeout(() => {
    try {
      const iframe = pdfIframe.value;
      if (iframe && iframe.contentDocument && iframe.contentDocument.body) {
        const bodyText = iframe.contentDocument.body.textContent || '';
        // 检查iframe内容是否包含错误信息
        if (bodyText.includes('404') || bodyText.includes('Not Found') || bodyText.includes('错误')) {
          console.error('PDF文档在iframe中加载失败，页面显示错误');
          loadError.value = true;
          errorMessage.value = 'PDF文件未找到或无法访问';
        }
      }
    } catch (err) {
      // 跨域问题可能导致无法读取内容
      console.log('无法读取iframe内容:', err);
    }
  }, 1000);
};

const handleIframeError = (error) => {
  console.error('PDF iframe加载失败:', error);
  isLoading.value = false;
  loadError.value = true;
  errorMessage.value = '无法加载PDF，请尝试在新窗口打开';
};

// 检测iOS设备 - 仅用于记录
const detectIOSDevice = () => {
  const userAgent = navigator.userAgent.toLowerCase();
  isIOS.value = /iphone|ipad|ipod/.test(userAgent);
  console.log('设备检测完成，是否iOS设备:', isIOS.value);
};

// 使用iframe加载PDF
const loadPdfWithIframe = () => {
  console.log('使用iframe加载PDF');
  
  if (!pdfUrl.value) {
    console.error('没有PDF文件可加载');
    errorMessage.value = '没有可用的PDF文件';
    loadError.value = true;
    isLoading.value = false;
    return;
  }
  
  // 重置状态
  loadError.value = false;
  errorMessage.value = '';
  isLoading.value = true;
  
  console.log('设置PDF URL:', pdfUrl.value);
  
  // iframe会自动加载，只需设置状态
  // 添加一个超时，以防iframe加载失败
  setTimeout(() => {
    if (isLoading.value) {
      isLoading.value = false;
    }
  }, 5000);
};

// 检查是否有PDF文件
const checkPdfFile = () => {
  // 按优先级检查文件字段
  const fileFields = ['file1', 'file2', 'file3'];
  for (const field of fileFields) {
    if (item.value[field] && isPdfUrl(item.value[field])) {
      console.log(`找到PDF文件: ${field} = ${item.value[field]}`);
      pdfUrl.value = item.value[field];
      hasPdf.value = true;
      return;
    }
  }
  
  console.log('没有找到PDF文件');
  hasPdf.value = false;
};

// 判断URL是否为PDF
const isPdfUrl = (url) => {
  if (!url) return false;
  return url.toLowerCase().endsWith('.pdf') || url.toLowerCase().includes('pdf');
};

// 重新加载PDF
const retryLoad = () => {
  console.log('重新尝试加载PDF');
  loadPdfWithIframe();
};

// 在新窗口打开PDF
const openExternal = () => {
  if (pdfUrl.value) {
    console.log('在新窗口打开PDF:', pdfUrl.value);
    window.open(pdfUrl.value, '_blank');
  } else {
    showToast('没有可用的PDF文件');
  }
};

// VIP日期检查
function isFutureDate(dateString) {
  const inputDate = new Date(dateString);
  const currentDate = new Date();
  currentDate.setHours(0, 0, 0, 0);
  
  return inputDate >= currentDate;
}

// 页面导航
function left() {
  uni.setStorageSync('firstMenu', item.value.firstMenu);
  router.go(-1);
}

// 查看作业
function openZy() {
  show.value = true;
}

// 查看答案
function openDa() {
  show1.value = true;
  textbookRecordSave({ textbookId: item.value.id });
}

// 分享功能
function fenxiang() {
  classList().then(res => {
    if (res.code == 0) {
      showL.value = true;
      fxItem.value = item.value;
      classItem.value = res.data;
    } else {
      showToast(res.msg);
    }
  });
}

// 发送分享
function fasong() {
  let arr = [];
  classItem.value.forEach(e => {
    if (e.isCheck) {
      arr.push(e);
    }
  });
  
  if (arr.length == 0) {
    showToast('请先选择要分享的班级群');
    return false;
  }
  
  let num = 0;
  arr.forEach(e => {
    // 发送消息
    let param = {
      "classId": e.id,
      "content": JSON.stringify(fxItem.value),
      "param1": "book",
      "param2": "",
      "param3": "",
      "param4": "",
      "param5": "",
      "type": 3
    };
    
    sendMsg(param).then(res => {
      if (res.code == 0) {
        num += 1;
        showL.value = false;
        if (num == arr.length) {
          showToast('消息已成功发送');
        }
      } else {
        showToast(res.msg);
      }
    });
  });
}
</script>

<style lang="scss" scoped>
.pdf-container {
  position: relative;
  height: 100%;
  min-height: 500px;
  width: 100%;
  
  .pdf-iframe-container {
    width: 100%;
    height: 100%;
    min-height: 500px;
    display: flex;
    justify-content: center;
    align-items: center;
    border: 1px solid #eee;
    border-radius: 4px;
    overflow: hidden;
  }
  
  .pdf-iframe {
    width: 100%;
    height: 100%;
    min-height: 500px;
    border: none;
    background: white;
    display: block;
  }
}

/* 优化错误和加载状态样式 */
.error-container, .loading-container {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  background-color: rgba(255, 255, 255, 0.9);
  z-index: 5;
}

.error-message {
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  max-width: 90%;
  width: 400px;
  text-align: center;
}

.error-title {
  display: block;
  font-size: 16px;
  font-weight: bold;
  margin-bottom: 15px;
  color: #ff4d4f;
}

.error-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 10px;
  margin: 15px 0;
}

.direct-link {
  margin-top: 20px;
  padding-top: 10px;
  border-top: 1px dashed #ddd;
  
  .download-link {
    color: #1890ff;
    text-decoration: underline;
    font-weight: bold;
  }
}

.spinner {
  border: 4px solid rgba(0, 0, 0, 0.1);
  border-left-color: #000;
  border-radius: 50%;
  width: 30px;
  height: 30px;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.loading-text {
  margin-top: 15px;
  font-size: 16px;
  color: #333;
}

/* 按钮样式 */
.primary-btn, .secondary-btn {
  padding: 8px 16px;
  border-radius: 4px;
  border: none;
  font-size: 14px;
  cursor: pointer;
}

.primary-btn {
  background-color: #1890ff;
  color: white;
}

.secondary-btn {
  background-color: #f0f0f0;
  color: #333;
}

.fenxiang{
  position: absolute; 
  padding: 5px 0px 4px 0;
  top: 65px;
  left: 15px;
  z-index: 99;
  width: 65px;
  height: 26px;
  background: #E0F8F1;
  color: #404040;
  font-size: 14px;
  display: flex;
  border-radius: 6px;
  align-items: center;
  justify-content: center;
  background-image: url(/static/assets/musicF.png);
  background-repeat: no-repeat;
  background-size: 18px;
  background-position: left 5px center;
  padding-left: 20px;
}

.theory_content{
  height: 100%;
  position: relative;
  
  .top{
    position: relative;
    background: #fff;
    border-radius: 8px;
    height: 44px;
    display: flex;
    justify-content: flex-end;
    align-items: center;
    padding-right: 10px;
    
    .btn{
      padding: 3px 10px;
      background: #f6f7fb;
      margin-left:15px;
      font-weight: 500;
      border-radius: 8px;
      font-size:14px;
    }
    
    .return {
      position: absolute;
      left: 10px;
      font-size: 30px;
    }
  }
  
  .box{
    height: calc(100% - 54px);
    background: #fff;
    margin-top: 10px;
    border-radius: 9px;
    padding: 20px;
    
    .content{
      width: 100%;
      height: 100%;
      overflow-y: auto;
      overflow-x: hidden;
      scrollbar-width: none; /* Firefox */
      -ms-overflow-style: none; /* IE and Edge */
    }
  }
  
  .scroll::-webkit-scrollbar {
    display: none; /* Chrome, Safari, Opera */
  }
  
  ::v-deep .dialog{
    top: 50%;
    
    .close{
      font-size: 30px;
      position: absolute;
      right: 15px;
      top: 15px;
    }
    
    .van-dialog__content{
      height: 600px;
      padding: 15px;
      padding-top: 40px;
      
      .box{
        overflow-y: auto;
        scrollbar-width: none; /* Firefox */
        -ms-overflow-style: none; /* IE and Edge */
      }
    }
  }
}
</style>
