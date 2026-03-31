<template>
	<view class="play_content24">
		<view class="top">
		  <van-icon class="return" name="/static/assets/left1.png" @click="left1" />
		  用户协议
		</view>
		<!-- 信息栏 -->
		<view class="my_info">
			<view v-if="type == 1">
				<h1>欢迎您使用音乐之路应用！</h1>
				<p>在您开始使用“音乐之路”之前，请仔细阅读并同意以下用户协议。通过访问和使用我们的服务，您同意受本协议的约束。如果您不同意本协议的条款，请不要使用本应用。</p>
							
				<h2>1. 服务说明</h2>
				<p>“音乐之路”是一个旨在帮助音乐艺考学生学习和练习的平台。我们提供包括但不限于音乐理论教学、乐器演奏教程、考试资料及模拟考试的服务。</p>
							
				<h2>2. 用户资格</h2>
				<p>注册成为“音乐之路”用户时，您确认您具备使用我们服务并形成具有法律约束力的合同的能力。本服务不面向未满13岁的用户。</p>
							
				<h2>3. 账户安全</h2>
				<p>您负责维护您账户的机密性，以及所有使用您账号的活动。如发现任何未经授权使用您账号或其他安全漏洞的情况，您同意立即通知我们。</p>
							
				<h2>4. 用户行为</h2>
				<p>您同意不会使用“音乐之路”进行任何非法或未经授权的活动。您承诺不在应用内上传、发布、分享或以其他方式传播任何侵犯他人权利或违法的内容。</p>
							
				<h2>5. 知识产权</h2>
				<p>本应用中所有的内容，包括但不限于文本、图像、音乐、视频、软件、代码和界面设计，均为“音乐之路”或其授权人所有，受到版权、商标和其他知识产权法的保护。</p>
							
				<h2>6. 隐私政策</h2>
				<p>您的隐私对我们至关重要。我们承诺保护您的个人信息安全，不会未经您的同意向第三方透露。详情请参阅我们的隐私政策。</p>
							
				<h2>7. 服务的变更与终止</h2>
				<p>我们保留随时修改或终止服务（或其任何部分）的权利，且无需事先通知。我们对因任何服务变更、暂停或终止给您或第三方造成的任何损失不承担责任。</p>
							
				<h2>8. 法律适用与争议解决</h2>
				<p>本协议的解释、适用及争议解决均适用中华人民共和国法律。任何因本协议产生的争议应首先通过协商解决，协商不成的，双方同意提交至用户注册住所地有管辖权的人民法院诉讼解决。</p>
							
				<h2>联系我们</h2>
				<p>如果您对本协议或服务有任何疑问，请通过意见反馈与我们联系。</p>
			</view>
				
			<!-- 隐私政策 -->
			<view v-if="type == 2">
				<h2>
									隐私政策
											</h2> <p>
												甘肃艺同学科技教育有限公司开发了该含有内购的应用程序音乐之路。该服务由甘肃艺同学科技教育有限公司提供，旨在安装并使用。
											</p> <p>
												我们对您使用音乐之路的隐私政策做出规定，并解释了我们如何收集，保护和披露您因使用我们的服务而产生的信息。
											</p> <p>
												如果您选择使用我们提供的服务，则表示您同意收集和使用与此政策相关的信息。我们收集的个人信息用于提供和改进服务。除非本隐私政策中另有说明，否则我们不会与任何人一起使用或分享您的信息。
											</p> <p>
												除非本隐私政策另有规定，否则本隐私政策中使用的术语与我们的条款和条件具有相同的含义，可在音乐之路中访问。
											</p> <p><h2>
													信息收集与使用
												</h2></p> <p>
												为了获得更好的体验，在使用我们的服务时，我们可能会要求您向我们提供某些个人身份信息，包括但不限于姓名，手机号，地理位置. 我们请求的信息将由我们保留并按照本隐私政策的规定使用。
											</p> <!----> <p><h2>
													记录数据
												</h2></p> <p>
												当您使用我们的服务时，如果应用程序出现错误，我们会通过第三方数据统计在您的手机上收集数据和信息。该日志数据可能包含以下信息，例如：您的设备Internet协议（
												IP）地址，设备名称，操作系统版本，使用我们的服务时应用的配置，您使用该服务的时间和日期以及其他统计信息。
											</p> <p><h2>
													Cookies
												</h2></p> <p>
												Cookies是具有少量数据的文件，通常用作匿名唯一标识符。 这些信息将从您访问的网站发送到浏览器，并存储在设备的内存中。
											</p> <p>
												本应用未明确使用这些Cookies。但是，该应用程序可能使用第三方代码和使用带有Cookies的库来收集信息并改善其服务。 您可以选择接受还是拒绝这些Cookies，并知道何时将Cookies发送到您的设备。
												如果您选择拒绝我们的Cookies，则可能无法使用本服务的部分功能。
											</p> <p><h2>
													服务供应商
												</h2></p> <p>
												我们可能由于以下原因雇用第三方公司和个人：
											</p> <ul><li>
													促进我们的服务质量；
												</li> <li>
													代表我们提供服务；
												</li> <li>
													提供与服务相关的服务；
												</li> <li>
													帮助我们分析如何使用我们的服务。
												</li></ul> <p>
												我们想通知此服务的用户，这些第三方有权访问您的个人信息。原因是代表我们执行分配给他们的任务。但是，他们有义务不出于任何其他目的披露或使用该信息。
											</p> <p><h2>
													安全
												</h2></p> <p>
												我们很重视您对我们提供您的个人信息的信任，因此我们正在努力使用商业上可接受的方法来保护它。但是请记住，没有一种通过互联网传输的方法，或者说电子存储的方法是100%安全可靠的，我们不能保证它的绝对安全性。
											</p> <p><h2>
													到其他网站的链接
												</h2></p> <p>
												此服务可能包含指向其他网站的链接。如果你点击第三方链接，你将被引导到该网站。注意，这些外部站点不是由我们操作的。因此，我们强烈建议您查看这些网站的隐私策略。我们对任何第三方网站或服务的内容、隐私政策或做法没有控制权，也不承担任何责任。
											</p> <p><h2>
													儿童隐私
												</h2></p> <p>
												这些服务不面向13岁以下的青少年。我们不会有意收集13岁以下儿童的个人身份信息。如果我们发现13岁以下的儿童向我们提供了个人信息，我们会立即从我们的服务器中删除这些信息。 如果您是父母或监护人，并且知道您的孩子向我们提供了个人信息，请与我联系，以便我们能够采取必要的措施。
											</p> <p><h2>
													本隐私政策的变更
												</h2></p> <p>
												我们可能会不时更新我们的隐私政策。因此，建议您定期查看此页以了解更改。如有任何更改，我们会在本页公布新的隐私政策。
											</p> <p>
												该政策自2024-06-22起生效。
											</p> <p><h2>
													联系我们
												</h2></p> <p>
												如果您对我们的隐私政策有任何疑问或建议，请随时通过yyzl654770206@outlook.com与我们联系。
											</p>
			</view>	
		</view>
		
		
		    
		      
		

		
	</view>

</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import {logout} from '/api/home.js';
import { showToast , showLoadingToast} from 'vant';
import { useStore } from 'vuex';  // 引入 useStore

const store = useStore();  // 使用 useStore

const router = useRouter();

const myInfo = ref({});
const type = history.state.id;

function left1() {
  router.go(-1);
}




</script>

<style lang="scss" scoped>
	::v-deep .van-dialog__header{
		background: none;
		font-weight: 400;
	}
	::v-deep .edit_head{
		width: 70%;
		height: 70%;
		.van-dialog__footer{
			position: absolute;
			bottom: 0;
			width: 100%;
		}
		.head{
			text-align: center;
			margin-top:50px;
		}
		.upload{
			width: 100%;
			text-align: center;
			display: flex;
			justify-content: center;
			margin-top: 40px;
			.van-button--normal{
				background: #00c9a4;
				border: none;
			}
		}
	}
	.add_content{
		border: 1px solid #f2f2f4;
	}
	.play_content24{
		height: 100%;
		position: relative;
		.top{
			justify-content: center;
			text-align: center;
			height: 44px;
			border-radius: 9px;
			display: flex;
			align-items: center;
			padding-left: 10px;
			background: #fff;
			position: relative;
		}
		.return {
		  font-size: 30px;
		  position: absolute;
		  left: 10px;
		}
		.my_info{
			height: calc(100% - 54px);
			position: relative;
			padding: 30px;
			border-radius: 9px;
			background: #fff;
			margin-top: 10px;
			overflow-y: auto;
			overflow-x: hidden;
			-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE/Edge */
			  h1 {
			        color: #00c9a4;
					font-size: 20px;
			    }
			    h2 {
					font-size: 17px;
			        color: #00c9a4;
			    }
			    p {
			        margin: 14px 0;
					font-size: 14px;
			    }
			    .container {
			        background-color: #fff;
			        padding: 20px;
			        border-radius: 8px;
			        box-shadow: 0 0 10px rgba(0,0,0,0.1);
			    }
			
		}

	}
</style>
