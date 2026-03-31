<template>
	<view class="theory_content">
		<view class="top">
		  <van-icon class="return" name="/static/assets/left1.png" @click="left" />
		  <view class="btn answer" @click="openDa()">查看答案</view>
		  <view class="title">{{item.title}}</view>
		</view>
		<!-- 内容区 -->
		<view class="box">
			<!-- 优先展示PDF文件 -->
			<view v-if="hasPdf" class="pdf-container" :class="{'ios-pdf-container': isIOS}">
				<!-- 错误信息显示 -->
				<view v-if="loadError" class="error-container">
					<view class="error-message">
						<text class="error-title">{{ errorMessage }}</text>
						<view class="error-actions">
							<button @click="retryLoad" class="primary-btn">切换渲染模式</button>
							<button @click="openExternal" class="secondary-btn">在新窗口打开</button>
							<button @click="toggleDebugMode" class="debug-btn">
								{{ showDebug ? '隐藏' : '显示' }}调试信息
							</button>
						</view>
					</view>
					<!-- 调试信息 -->
					<view v-if="showDebug" class="debug-info">
						<text class="debug-title">调试信息</text>
						<textarea readonly :value="debugInfo" class="debug-text"></textarea>
					</view>
				</view>
				
				<!-- 加载中显示 -->
				<view v-if="isLoading" class="loading-container">
					<view class="spinner"></view>
					<text class="loading-text">{{ loadingProgress ? `加载中 ${loadingProgress}%` : '加载中...' }}</text>
				</view>
				
				<!-- PDF.js渲染区域 -->
				<view v-if="pdfDoc && !isLoading && !loadError" class="pdf-viewer" :class="{ 'ios-pdf-viewer': isIOS }">
					<!-- 控制栏 -->
					<view class="pdf-controls" :class="{ 'ios-pdf-controls': isIOS }">
						<view class="page-nav">
							<button @click="prevPage" :disabled="currentPage <= 1" class="nav-btn">上一页</button>
							<text class="page-info">{{ currentPage }} / {{ totalPages }}</text>
							<button @click="nextPage" :disabled="currentPage >= totalPages" class="nav-btn">下一页</button>
						</view>
						<view class="zoom-controls">
							<button @click="zoomOut" class="zoom-btn">缩小</button>
							<text class="zoom-text">{{ Math.round(scale * 100) }}%</text>
							<button @click="zoomIn" class="zoom-btn">放大</button>
						</view>
						<button @click="openExternal" class="action-btn">在新窗口打开</button>
					</view>
					
					<!-- Canvas容器 -->
					<view id="pdf-canvas-container" class="pdf-canvas-container" :class="{ 'ios-pdf-canvas-container': isIOS }">
						<!-- PDF页面将在这里动态渲染 -->
					</view>
				</view>
				
				<!-- iframe备用方案 -->
				<view v-if="useIframe && pdfUrl && !loadError" class="pdf-iframe-container">
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
		<!-- 查看答案 -->
		<van-dialog class="dialog" v-model:show="show1" :showConfirmButton='false'  width="80%">
			<van-icon class="close" @click="show1=false" name="/static/assets/close.jpg" />
			<view class="box">
				<van-image class="icon" :src="item?.img1" />
			</view>
		</van-dialog>
	</view>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { onShow } from '@dcloudio/uni-app';
import { getDetail } from '/api/home.js';
import { showToast } from 'vant';

// 定义组件的props
const props = defineProps({
  pdfUrl: {
    type: String,
    default: ''
  }
});

const router = useRouter();
const showAnswer = ref(true);	
const show = ref(false);
const show1 = ref(false);

const item = ref({});
const hasPdf = ref(false);
const pdfUrl = ref('');

// PDF相关状态
const isLoading = ref(true);
const loadError = ref(false);
const errorMessage = ref('');
const debugInfo = ref('');
const showDebug = ref(false);
const currentPage = ref(1);
const totalPages = ref(0);
const scale = ref(1.2);
const pdfContainer = ref(null);
const pdfDoc = ref(null);
const pdfIframe = ref(null);
const useIframe = ref(true); // 默认使用iframe模式
const useCanvas = ref(false); // 是否使用Canvas渲染，与useIframe相反
const loadingProgress = ref(null); // 加载进度
const pageInfo = ref('');

// 触摸相关状态
const touchStartX = ref(0);
const touchStartY = ref(0);
const touchStartTime = ref(0);

// PDF.js相关变量
let pdfjsLib;
let pdfTask;

const id = history.state.id;
const isIOS = ref(false); // 用于检测iOS设备

onMounted(async () => {
	console.log('PDF查看器组件已挂载');
	
	// 检测设备类型
	detectIOSDevice();
	
	// 从路由参数获取ID
	if (id) {
		console.log('加载课程详情，ID:', id);
		try {
			const res = await getDetail(id);
			item.value = res.data;
			
			// 尝试解析图片JSON
			try {
				if (item.value.img1) {
					item.value.img1 = JSON.parse(item.value.img1)[0];
				}
			} catch (err) {
				console.log('图片解析失败，可能不是JSON格式');
			}
			
			// 检查是否有PDF文件
			checkPdfFile();
			
			// 如果从props收到PDF URL
			if (props.pdfUrl && !pdfUrl.value) {
				pdfUrl.value = props.pdfUrl;
				hasPdf.value = true;
				console.log('从props获取PDF URL:', pdfUrl.value);
				reloadPdf();
			}
		} catch (err) {
			console.error('获取课程详情失败:', err);
			showToast('获取课程详情失败');
		}
	} else if (props.pdfUrl) {
		// 直接从props获取PDF URL
		pdfUrl.value = props.pdfUrl;
		hasPdf.value = true;
		console.log('从props获取PDF URL:', pdfUrl.value);
		reloadPdf();
	} else {
		console.log('未提供ID或PDF URL');
	}
});

// 检测iOS设备
const detectIOSDevice = () => {
	const userAgent = navigator.userAgent.toLowerCase();
	const isIOSDevice = /iphone|ipad|ipod/.test(userAgent);
	isIOS.value = isIOSDevice;
	
	// 在UniApp环境下，iOS设备使用不同的默认渲染模式
	if (isIOSDevice) {
		console.log('检测到iOS设备');
		
		// iOS设备上，由于PDF.js可能有加载问题，先尝试iframe
		useIframe.value = true;
		useCanvas.value = false;
		
		// iOS设备上使用较低初始缩放，避免溢出
		scale.value = 0.9;
	} else {
		// 非iOS设备默认使用PDF.js
		useIframe.value = false;
		useCanvas.value = true;
		scale.value = 1.2;
	}
	
	return isIOSDevice;
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
			
			// 如果是iOS设备，立即加载PDF.js
			if (isIOS.value && !useIframe.value) {
				nextTick(() => {
					reloadPdf();
				});
			}
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
					
					// 尝试回退到PDF.js模式
					useIframe.value = false;
					useCanvas.value = true;
					reloadPdf();
				}
			}
		} catch (err) {
			// 跨域问题可能导致无法读取内容
			console.log('无法读取iframe内容 (可能是跨域限制):', err);
			// 跨域情况下，我们假设加载成功
			isLoading.value = false;
		}
	}, 1000);
};

const handleIframeError = (error) => {
	console.error('PDF iframe加载失败:', error);
	isLoading.value = false;
	loadError.value = true;
	errorMessage.value = '无法加载PDF，请尝试在新窗口打开';
	
	// 记录调试信息
	debugInfo.value = `iframe加载错误 - 可能是由于浏览器安全限制阻止了iframe加载PDF。`;
	showDebug.value = true;
	
	// 自动尝试切换到PDF.js模式
	useIframe.value = false;
	useCanvas.value = true;
	
	// 延迟重试
	setTimeout(() => {
		reloadPdf();
	}, 500);
};

// 调试相关函数
const toggleDebugMode = () => {
	showDebug.value = !showDebug.value;
};

// 重新加载PDF函数
const reloadPdf = () => {
	console.log('重新加载PDF');
	
	// 重置状态
	loadError.value = false;
	errorMessage.value = '';
	isLoading.value = true;
	loadingProgress.value = 0;
	
	// 清除当前PDF文档引用
	if (pdfDoc.value) {
		try {
			pdfDoc.value.destroy();
		} catch (err) {
			console.error('销毁旧PDF文档时出错:', err);
		}
		pdfDoc.value = null;
	}
	
	// 根据当前渲染模式选择加载方式
	if (useIframe.value) {
		console.log('使用iframe模式加载PDF');
		// 直接设置状态，iframe会自动加载
		setTimeout(() => {
			isLoading.value = false;
		}, 1000);
	} else {
		console.log('使用PDF.js模式加载PDF');
		// 使用PDF.js加载
		loadPdf(pdfUrl.value);
	}
};

// 重试加载PDF，可能会切换渲染模式
const retryLoad = () => {
	console.log('尝试重新加载PDF');
	
	// 切换渲染模式
	useIframe.value = !useIframe.value;
	useCanvas.value = !useIframe.value;
	
	console.log(`切换渲染模式: ${useIframe.value ? 'Iframe' : 'PDF.js'}`);
	
	// 如果切换到PDF.js但之前失败过，显示提示
	if (!useIframe.value && loadError.value) {
		showToast('尝试使用PDF.js渲染，如果仍然失败请尝试在新窗口打开');
	}
	
	// 延迟一会再加载，确保UI更新
	setTimeout(() => {
		reloadPdf();
	}, 500);
};

// 监听URL变化
watch(() => props.pdfUrl, (newUrl, oldUrl) => {
	if (newUrl && newUrl !== oldUrl && newUrl !== pdfUrl.value) {
		console.log('PDF URL已更改:', newUrl);
		pdfUrl.value = newUrl;
		hasPdf.value = true;
		// 重新加载PDF
		nextTick(() => {
			reloadPdf();
		});
	}
}, { immediate: true });

// 在新窗口打开PDF
const openExternal = async () => {
	try {
		// 显示加载提示
		showToast('正在打开PDF...');
		
		// 检查是否在UniApp环境中
		const isUniApp = typeof uni !== 'undefined';
		console.log('UniApp环境:', isUniApp, '是否iOS:', isIOS.value);
		
		if (isUniApp) {
			console.log('使用UniApp API打开PDF');
			
			// 显示加载状态
			isLoading.value = true;
			loadingProgress.value = 0;
			
			try {
				// 使用UniApp的下载API
				uni.downloadFile({
					url: pdfUrl.value,
					success: (res) => {
						if (res.statusCode === 200) {
							console.log('PDF下载成功:', res.tempFilePath);
							
							// 使用UniApp的API打开文档
							uni.openDocument({
								filePath: res.tempFilePath,
								fileType: 'pdf',
								success: () => {
									console.log('PDF打开成功');
									showToast('PDF已打开');
								},
								fail: (err) => {
									console.error('打开PDF失败:', err);
									errorMessage.value = '打开PDF失败，请稍后重试';
									// 如果打开失败，尝试使用系统浏览器
									plus.runtime.openURL(pdfUrl.value);
								},
								complete: () => {
									isLoading.value = false;
								}
							});
						} else {
							console.error('PDF下载失败:', res);
							errorMessage.value = `下载PDF失败: 状态码 ${res.statusCode}`;
							isLoading.value = false;
							// 尝试直接用系统浏览器打开
							try {
								plus.runtime.openURL(pdfUrl.value);
							} catch (e) {
								window.open(pdfUrl.value, '_blank');
							}
						}
					},
					fail: (err) => {
						console.error('PDF下载失败:', err);
						errorMessage.value = '下载PDF失败，请检查网络连接';
						isLoading.value = false;
						// 尝试直接用系统浏览器打开
						try {
							plus.runtime.openURL(pdfUrl.value);
						} catch (e) {
							window.open(pdfUrl.value, '_blank');
						}
					}
				});
				
				// 添加下载进度事件
				try {
					uni.onDownloadProgress((res) => {
						loadingProgress.value = Math.floor(res.progress * 100);
						console.log(`下载进度: ${loadingProgress.value}%`);
					});
				} catch (e) {
					console.warn('不支持下载进度事件:', e);
				}
			} catch (uniError) {
				console.error('UniApp API调用失败:', uniError);
				// 降级到普通打开
				window.open(pdfUrl.value, '_blank');
			}
		} else {
			// 非UniApp环境，使用普通的方式打开
			window.open(pdfUrl.value, '_blank');
		}
	} catch (error) {
		console.error('打开外部PDF失败:', error);
		errorMessage.value = `打开外部PDF失败: ${error.message || '未知错误'}`;
		isLoading.value = false;
		
		// 最终降级方案 - 直接尝试打开URL
		try {
			window.location.href = pdfUrl.value;
		} catch (e) {
			console.error('所有打开方式都失败');
		}
	}
};

// 最终组装的PDF处理函数，确保iOS多页显示正常工作
const loadPdf = async (url) => {
	console.log('开始加载PDF文件:', url);
	
	if (!url) {
		errorMessage.value = '没有提供PDF URL';
		loadError.value = true;
		isLoading.value = false;
		return;
	}
	
	try {
		isLoading.value = true;
		loadError.value = false;
		errorMessage.value = '';
		loadingProgress.value = 0;
		
		// 动态导入PDF.js库
		console.log('导入PDF.js库...');
		const pdfjsLib = await import('pdfjs-dist');
		
		// 设置Worker - 尝试多种可能的路径
		console.log('设置PDF.js Worker...');
		
		// 尝试导入worker并设置路径
		try {
			await import('pdfjs-dist/build/pdf.worker.mjs');
		} catch (e) {
			console.warn('Worker模块导入失败，将使用CDN:', e);
		}
		
		// 尝试多个可能的路径
		const possibleWorkerPaths = [
			'./node_modules/pdfjs-dist/build/pdf.worker.mjs',
			'../node_modules/pdfjs-dist/build/pdf.worker.mjs',
			'/node_modules/pdfjs-dist/build/pdf.worker.mjs',
			'https://cdn.jsdelivr.net/npm/pdfjs-dist@4.7.76/build/pdf.worker.min.mjs'
		];
		
		// 选择第一个路径，如果失败后面会有回退处理
		pdfjsLib.GlobalWorkerOptions.workerSrc = possibleWorkerPaths[0];
		console.log('Worker路径设置为:', pdfjsLib.GlobalWorkerOptions.workerSrc);
		
		// 配置加载选项
		const loadingOptions = {
			url: url,
			// 禁用worker，尝试直接加载
			disableWorker: true,
			// 监控加载进度
			onProgress: (progress) => {
				if (progress && progress.total) {
					loadingProgress.value = Math.floor((progress.loaded / progress.total) * 100);
					console.log(`PDF加载进度: ${loadingProgress.value}%`);
				}
			}
		};
		
		// 针对iOS设备的特殊配置
		if (isIOS.value) {
			Object.assign(loadingOptions, {
				disableFontFace: true,           // 禁用字体优化，避免兼容性问题
				nativeImageDecoderSupport: 'none', // 避免使用原生图像解码
				isEvalSupported: false,          // 避免使用eval
				disableRange: true,              // 禁用范围请求，尝试直接下载整个PDF
				disableStream: false,            // 允许流加载
				disableAutoFetch: false,         // 允许自动获取
				cMapUrl: undefined,              // 禁用外部cMap资源
				cMapPacked: false                // 不使用packed模式
			});
		} else {
			// 非iOS设备的配置
			Object.assign(loadingOptions, {
				cMapUrl: './node_modules/pdfjs-dist/cmaps/', // 使用相对路径
				cMapPacked: true
			});
		}
		
		console.log('创建PDF加载任务，配置:', JSON.stringify(loadingOptions));
		const loadingTask = pdfjsLib.getDocument(loadingOptions);
		
		// 确保进度回调被设置
		loadingTask.onProgress = loadingOptions.onProgress;
		
		// 添加超时处理，避免永久加载
		let pdfDocLoaded = false;
		
		// 创建一个带超时的Promise
		const timeoutPromise = new Promise((_, reject) => {
			setTimeout(() => {
				if (!pdfDocLoaded) {
					reject(new Error('PDF加载超时，尝试其他方式查看'));
				}
			}, 15000); // 15秒超时
		});
		
		// 添加尝试其他worker路径的逻辑
		for (let i = 0; i < possibleWorkerPaths.length; i++) {
			if (i > 0) {
				console.log(`尝试使用备选Worker路径 ${i}:`, possibleWorkerPaths[i]);
				pdfjsLib.GlobalWorkerOptions.workerSrc = possibleWorkerPaths[i];
			}
			
			try {
				// 设置超时，防止永久等待
				const loadPromise = loadingTask.promise;
				
				console.log('等待PDF文档加载...');
				pdfDoc.value = await Promise.race([loadPromise, timeoutPromise]);
				pdfDocLoaded = true;
				break; // 如果成功加载，跳出循环
			} catch (err) {
				console.warn(`使用Worker路径${i}加载失败:`, err);
				if (i === possibleWorkerPaths.length - 1) {
					throw err; // 如果是最后一个路径还失败，则抛出错误
				}
				// 否则继续尝试下一个路径
			}
		}
		
		if (!pdfDocLoaded) {
			throw new Error('所有Worker路径都加载失败');
		}
		
		console.log(`PDF文档加载成功，共${pdfDoc.value.numPages}页`);
		
		// 更新页面信息
		totalPages.value = pdfDoc.value.numPages;
		currentPage.value = 1;
		
		// 设置初始缩放比例
		scale.value = isIOS.value ? 1.0 : 1.2;
		
		// 确保使用Canvas渲染
		useIframe.value = false;
		useCanvas.value = true;
		
		// 在下一个微任务中渲染页面，确保DOM已更新
		await nextTick();
		console.log('开始渲染第一页');
		await renderPage();
		
		// 更新加载状态
		isLoading.value = false;
		loadingProgress.value = 100;
		
		// 为iOS设备设置触摸滑动
		if (isIOS.value) {
			setupTouchEvents();
		}
		
		console.log('PDF初始化完成');
	} catch (error) {
		console.error('PDF加载失败:', error);
		isLoading.value = false;
		loadError.value = true;
		errorMessage.value = `PDF加载失败: ${error.message || '未知错误'}`;
		
		// 记录调试信息
		debugInfo.value = `错误类型: ${error.name || '未知'}\n错误信息: ${error.message || '无消息'}\n堆栈: ${error.stack || '无堆栈'}\nURL: ${url}\n环境: ${navigator.userAgent}`;
		showDebug.value = true;
		
		// 尝试使用iframe作为备选方案
		console.log('尝试切换到iframe模式');
		useIframe.value = true;
		useCanvas.value = false;
		// 延迟一会后刷新
		setTimeout(() => {
			isLoading.value = false;
		}, 1000);
	}
};

// PDF.js渲染函数，优化为在iOS上也能正常渲染多页
const renderPage = async () => {
	console.log(`开始渲染页面 ${currentPage.value} / ${totalPages.value}`);
	
	if (!pdfDoc.value) {
		console.error('没有PDF文档可渲染');
		isLoading.value = false; // 确保加载状态结束
		loadError.value = true;
		errorMessage.value = '没有可用的PDF文档';
		return;
	}
	
	try {
		// 获取页面对象 - 检查页码是否有效
		let pageNumber = currentPage.value;
		
		// 验证页码是否在有效范围内
		if (pageNumber < 1) {
			pageNumber = 1;
			currentPage.value = 1;
		} else if (pageNumber > totalPages.value) {
			pageNumber = totalPages.value;
			currentPage.value = totalPages.value;
		}
		
		console.log(`尝试获取第${pageNumber}页，总页数：${totalPages.value}`);
		
		// 设置超时处理
		let pageLoadTimeout;
		const timeoutPromise = new Promise((_, reject) => {
			pageLoadTimeout = setTimeout(() => {
				reject(new Error('获取页面超时'));
			}, 10000); // 10秒超时
		});
		
		// 尝试获取页面，并添加超时处理
		const pagePromise = pdfDoc.value.getPage(pageNumber);
		const page = await Promise.race([pagePromise, timeoutPromise]);
		
		// 清除超时
		clearTimeout(pageLoadTimeout);
		
		console.log('获取页面对象成功，页码:', page.pageNumber);
		
		// 获取Canvas容器
		const canvasContainer = document.getElementById('pdf-canvas-container');
		if (!canvasContainer) {
			console.error('找不到Canvas容器');
			isLoading.value = false; // 确保加载状态结束
			loadError.value = true;
			errorMessage.value = '无法找到PDF容器元素';
			return;
		}
		
		// 清空容器内容
		canvasContainer.innerHTML = '';
		
		// 创建新的Canvas元素
		const canvas = document.createElement('canvas');
		canvasContainer.appendChild(canvas);
		
		// 获取渲染上下文
		const context = canvas.getContext('2d', { alpha: false });
		if (!context) {
			throw new Error('无法获取Canvas 2D上下文');
		}
		
		// 计算适当的缩放比例
		const containerWidth = canvasContainer.clientWidth - (isIOS.value ? 10 : 20);
		console.log('容器宽度:', containerWidth);
		
		// 获取原始视口
		const originalViewport = page.getViewport({ scale: 1.0 });
		
		// 计算适合容器宽度的缩放比例
		const containerScale = containerWidth / originalViewport.width;
		
		// 最终缩放比例 = 用户选择的缩放比例 * 容器自适应缩放比例
		const finalScale = scale.value * containerScale;
		console.log('最终缩放比例:', finalScale);
		
		// 使用计算出的缩放比例创建视口
		const viewport = page.getViewport({ scale: finalScale });
		
		// 设置Canvas尺寸
		canvas.width = Math.floor(viewport.width);
		canvas.height = Math.floor(viewport.height);
		canvas.style.width = `${canvas.width}px`;
		canvas.style.height = `${canvas.height}px`;
		
		console.log(`Canvas尺寸: ${canvas.width} x ${canvas.height}`);
		
		// 渲染页面
		const renderContext = {
			canvasContext: context,
			viewport: viewport,
			enableWebGL: false,
			renderInteractiveForms: false
		};
		
		console.log('开始渲染任务...');
		const renderTask = page.render(renderContext);
		
		// 设置渲染超时
		let renderTimeout;
		const renderTimeoutPromise = new Promise((_, reject) => {
			renderTimeout = setTimeout(() => {
				reject(new Error('页面渲染超时'));
			}, 10000); // 10秒超时
		});
		
		// 等待渲染完成或超时
		await Promise.race([renderTask.promise, renderTimeoutPromise]);
		
		// 清除超时
		clearTimeout(renderTimeout);
		
		console.log('页面渲染完成');
		
		// 更新页码信息
		pageInfo.value = `${pageNumber} / ${totalPages.value}`;
		
		// 如果是iOS设备，滚动到顶部
		if (isIOS.value) {
			canvasContainer.scrollTop = 0;
		}
	} catch (error) {
		console.error('渲染页面失败:', error);
		errorMessage.value = `渲染失败: ${error.message || '未知错误'}`;
		loadError.value = true;
		
		// 尝试备用方案
		console.log('尝试使用iframe作为备用方案');
		useIframe.value = true;
		useCanvas.value = false;
	} finally {
		// 确保始终更新加载状态
		isLoading.value = false;
	}
};

// 设置触摸事件处理，用于iOS设备上的滑动翻页
function setupTouchEvents() {
	const container = document.getElementById('pdf-canvas-container');
	if (!container) {
		console.error('找不到PDF容器，无法设置触摸事件');
		return;
	}
	
	console.log('为iOS设备设置触摸事件');
	
	let startX = 0;
	let startY = 0;
	let startTime = 0;
	
	// 删除可能存在的旧事件监听器
	container.removeEventListener('touchstart', handleTouchStart);
	container.removeEventListener('touchend', handleTouchEnd);
	
	// 触摸开始事件
	function handleTouchStart(e) {
		startX = e.touches[0].clientX;
		startY = e.touches[0].clientY;
		startTime = Date.now();
	}
	
	// 触摸结束事件
	function handleTouchEnd(e) {
		// 如果PDF正在加载，忽略触摸事件
		if (isLoading.value) return;
		
		const endX = e.changedTouches[0].clientX;
		const endY = e.changedTouches[0].clientY;
		const endTime = Date.now();
		
		// 计算滑动距离和方向
		const diffX = startX - endX;
		const diffY = startY - endY;
		const elapsedTime = endTime - startTime;
		
		// 只处理水平滑动，必须是快速且明显的滑动（超过50像素）
		if (Math.abs(diffX) > Math.abs(diffY) && 
			Math.abs(diffX) > 50 && 
			elapsedTime < 300) {
			
			if (diffX > 0) {
				// 向左滑动，下一页
				nextPage();
			} else {
				// 向右滑动，上一页
				prevPage();
			}
			
			// 防止触发其他事件
			e.preventDefault();
		}
	}
	
	// 添加新的事件监听器
	container.addEventListener('touchstart', handleTouchStart, { passive: true });
	container.addEventListener('touchend', handleTouchEnd);
	
	console.log('触摸事件设置完成');
}

// 修改页面变更函数，确保在iOS上也能正常工作
async function changePage(delta) {
	console.log(`更改页面: 当前=${currentPage.value}, 增量=${delta}`);
	
	const newPage = currentPage.value + delta;
	
	if (newPage >= 1 && newPage <= totalPages.value) {
		currentPage.value = newPage;
		await renderPage();
		
		// 如果是iOS设备，滚动到顶部
		if (isIOS.value) {
			const container = document.getElementById('pdf-canvas-container');
			if (container) {
				container.scrollTop = 0;
			}
		}
	}
}

// 修改缩放函数
async function changeZoom(delta) {
	console.log(`更改缩放: 当前=${scale.value}, 增量=${delta}`);
	
	// 计算新的缩放比例，确保在合理范围内
	const newScale = Math.max(0.5, Math.min(3.0, scale.value + delta));
	
	if (newScale !== scale.value) {
		scale.value = newScale;
		await renderPage();
	}
}

// 页面导航函数 - 上一页
const prevPage = async () => {
	if (currentPage.value > 1) {
		currentPage.value -= 1;
		console.log(`切换到上一页: ${currentPage.value}`);
		await renderPage();
	}
};

// 页面导航函数 - 下一页
const nextPage = async () => {
	if (currentPage.value < totalPages.value) {
		currentPage.value += 1;
		console.log(`切换到下一页: ${currentPage.value}`);
		await renderPage();
	}
};

// 缩放函数 - 放大
const zoomIn = async () => {
	// 放大步长，iOS设备使用较小的步长
	const step = isIOS.value ? 0.1 : 0.2;
	// 最大缩放限制
	const maxScale = isIOS.value ? 2.0 : 3.0;
	
	if (scale.value < maxScale) {
		scale.value = Math.min(maxScale, scale.value + step);
		console.log(`放大至: ${scale.value}`);
		await renderPage();
	}
};

// 缩放函数 - 缩小
const zoomOut = async () => {
	// 缩小步长，iOS设备使用较小的步长
	const step = isIOS.value ? 0.1 : 0.2;
	// 最小缩放限制
	const minScale = isIOS.value ? 0.6 : 0.5;
	
	if (scale.value > minScale) {
		scale.value = Math.max(minScale, scale.value - step);
		console.log(`缩小至: ${scale.value}`);
		await renderPage();
	}
};

// 触摸事件处理（增强翻页体验）
const handleTouchStart = (e) => {
	if (!isIOS.value) return;
	
	const touch = e.touches[0];
	touchStartX.value = touch.clientX;
	touchStartY.value = touch.clientY;
	touchStartTime.value = Date.now();
};

const handleTouchMove = (e) => {
	// 可以添加滑动过程中的视觉反馈
};

const handleTouchEnd = (e) => {
	if (!isIOS.value) return;
	
	const touch = e.changedTouches[0];
	const deltaX = touch.clientX - touchStartX.value;
	const deltaY = touch.clientY - touchStartY.value;
	const deltaTime = Date.now() - touchStartTime.value;
	
	// 检查是否是水平滑动
	if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50 && deltaTime < 300) {
		if (deltaX > 0) {
			// 右滑，上一页
			prevPage();
		} else {
			// 左滑，下一页
			nextPage();
		}
	}
};

// 清理资源
onUnmounted(() => {
	console.log('PDF查看器组件已卸载');
	
	// 释放PDF文档资源
	if (pdfDoc.value) {
		try {
			pdfDoc.value.destroy();
		} catch (err) {
			console.error('销毁PDF文档时出错:', err);
		}
		pdfDoc.value = null;
	}
});

function left() {
	uni.setStorageSync('firstMenu', item.value.firstMenu);
	uni.setStorageSync('secondMenu', item.value.secondMenu);
	router.go(-1);
}

function openZy() {
	show.value = true;
}

function openDa() {
	show1.value = true;
}

function toggleAnswer() {
	showAnswer.value = !showAnswer.value;
}
</script>

<style lang="scss">
.theory_content {
	height: 100%;
	position: relative;
	
	.top {
		position: relative;
		background: #fff;
		border-radius: 9px;
		height: 44px;
		display: flex;
		align-items: center;
		padding: 0 10px;
		
		.btn {
			padding: 3px 10px;
			background: #f6f7fb;
			font-weight: 500;
			border-radius: 4px;
			font-size: 14px;
			margin-left: auto;
			position: absolute;
			z-index: 2;
			right: 10px;
		}
		
		.return {
			font-size: 30px;
			position: absolute;
			z-index: 2;
		}
		
		.title {
			position: absolute;
			width: 100%;
			height: 100%;
			text-align: center;
			line-height: 44px;
			z-index: 1;
		}
	}
	
	.box {
		height: calc(100% - 54px);
		background: #fff;
		margin-top: 10px;
		border-radius: 9px;
		padding: 20px;
		
		.content {
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
	
	::v-deep .dialog {
		top: 50%;
		
		.close {
			font-size: 30px;
			position: absolute;
			right: 15px;
			top: 15px;
		}
		
		.van-dialog__content {
			height: 600px;
			padding: 15px;
			padding-top: 40px;
			
			.box {
				overflow-y: auto;
				scrollbar-width: none; /* Firefox */
				-ms-overflow-style: none; /* IE and Edge */
			}
		}
	}
	
	// PDF相关样式
	.pdf-container {
		position: relative;
		height: 100%;
		width: 100%;
		display: flex;
		flex-direction: column;
		
		// iOS专用样式
		&.ios-pdf-container {
			// 确保在iOS上正常显示
			overflow: hidden;
			-webkit-overflow-scrolling: touch;
			display: flex;
			flex-direction: column;
		}
		
		.error-container {
			position: absolute;
			top: 0;
			left: 0;
			width: 100%;
			height: 100%;
			display: flex;
			justify-content: center;
			align-items: center;
			background-color: rgba(255, 255, 255, 0.8);
			z-index: 10;
			
			.error-message {
				padding: 20px;
				background: white;
				border-radius: 8px;
				box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
				max-width: 500px;
				text-align: center;
				
				p {
					margin-bottom: 15px;
					color: #ff4d4f;
					font-weight: bold;
				}
				
				.error-actions {
					display: flex;
					justify-content: center;
					gap: 12px;
					margin-top: 15px;
				}
			}
		}
		
		.loading-container {
			position: absolute;
			top: 0;
			left: 0;
			width: 100%;
			height: 100%;
			display: flex;
			justify-content: center;
			align-items: center;
			background-color: rgba(255, 255, 255, 0.8);
			z-index: 10;
			
			.spinner {
				border: 4px solid rgba(0, 0, 0, 0.1);
				border-left-color: #000;
				border-radius: 50%;
				width: 30px;
				height: 30px;
				animation: spin 1s linear infinite;
			}
			
			@keyframes spin {
				0% {
					transform: rotate(0deg);
				}
				100% {
					transform: rotate(360deg);
				}
			}
			
			.loading-text {
				margin-left: 10px;
				font-size: 14px;
				color: #666;
			}
		}
		
		.pdf-viewer {
			display: flex;
			flex-direction: column;
			flex: 1;
			height: 100%;
			width: 100%;
			overflow: hidden; // 防止溢出
			
			&.ios-pdf-viewer {
				// 在iOS上使用绝对定位容器
				position: relative;
				flex: 1;
				display: flex;
				flex-direction: column;
				background: #f8f8f8;
			}
			
			.pdf-controls {
				display: flex;
				justify-content: space-between;
				align-items: center;
				padding: 8px;
				background: #f0f0f0;
				border-radius: 4px;
				margin-bottom: 8px;
				z-index: 10;
				
				&.ios-pdf-controls {
					// 在iOS上的控制栏样式
					position: sticky;
					top: 0;
					width: 100%;
					z-index: 50;
					background: rgba(240, 240, 240, 0.95);
					backdrop-filter: blur(5px);
					-webkit-backdrop-filter: blur(5px);
				}
				
				.page-nav,
				.zoom-controls {
					display: flex;
					align-items: center;
					gap: 8px;
				}
				
				.page-info,
				.zoom-text {
					font-size: 14px;
					min-width: 60px;
					text-align: center;
				}
			}
			
			.pdf-canvas-container {
				flex: 1;
				overflow: auto;
				background: #f5f5f5;
				display: flex;
				align-items: flex-start; // 始终上对齐
				justify-content: center;
				-webkit-overflow-scrolling: touch; // 所有平台都启用平滑滚动
				padding: 10px;
				
				&.ios-pdf-canvas-container {
					// iOS特殊样式
					padding: 0; // 减少内边距
					width: 100%;
					height: calc(100% - 50px); // 减去控制栏高度
					
					canvas {
						display: block;
						max-width: 100% !important;
						margin: 0 auto;
						box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
						// 确保iOS上可见
						position: relative;
					}
				}
				
				canvas {
					margin: 10px auto;
					box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
				}
			}
		}
	}
}
</style>
