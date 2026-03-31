<template>
  <div class="main">
    <div class="cropper" style="position: relative;overflow: hidden; text-align: center;width:100%;height:100%;" :style="obj">
      <van-image v-if="show" :src="img" class="img" style="position: absolute;width: 100%;height:100%;left: 0;top: 0;" />
      <van-loading v-else color="#65abff" style="" />
      <!-- option是配置，格式是对象，getbase64Data是组件的一个方法获取裁剪完的头像 -->
      <h5-cropper @getbase64="getbase64Data" :option="option" @getblob="getBlob" @get-file="getFile"></h5-cropper>
    </div>
  </div>
</template>

<script>
// import { getsign } from "@/api/common";
export default {
  props: {
    fixedNumber: {
      type: Array,
      default: () => [1, 1]
    },
    image: {
      type: String,
      default: "http://erkong.ybc365.com/36bc0202010231838302739.png"
    },
    radius: {
      type: Number,
      default: 0
    }
  },
  data() {
    return {
      show: true,
      obj: {
        borderRadius: `${this.radius}px`
      },
      img: this.image,
      option: {
        ceilbutton: true,//操作按钮是否在顶部    
        fixedNumber: this.fixedNumber,//截图框的宽高比例    
        canMoveBox: true,//截图框能否拖动  
        fixedBox: false,//固定截图框大小 不允许改变 
        centerBox: true,//截图框是否被限制在图片里面 
        fixed: false,//是否开启截图框宽高固定比例    
      }
    }
  },
  methods: {
    getbase64Data(data) {
      this.img = data;
    },
    getBlob(blob) {
      // console.log(blob)
      this.$emit('getBlob')
    },
    getFile(file) {
      // console.log(file)
      // this.$emit('getFile')
      // this.show = false
      // this.uploader = this.tcVod.upload({
      //   mediaFile: file,
      // })
      // // 上传进度
      // this.uploader.on('media_progress', (info) => {
      //   console.log('上传进度' + "=>" + info.percent * 100);
      // })
      // // 上传完成时
      // this.uploader.on('media_upload', (info) => {
      //   console.log('上传完成时' + "=>" + info);
      //   this.$toast.success('上传成功！')
      // })
      // this.uploader.done().then((doneResult) => {
      //   this.img = (doneResult.video.url);
      //   this.show = true
      this.$emit('getImageUrl', file)
      // })
    }
  },
  // created() {
  //   //获取签名
  //   function getSignature() {
  //     return getsign(JSON.stringify({
  //       "Action": "GetUgcUploadSign"
  //     })).then(function(response) {
  //       return response.data.sign
  //     })
  //   };
  //   this.tcVod = new TcVod({
  //     getSignature: getSignature
  //   });
  // },
}
</script>

<style lang="scss" scoped>
.main {
  width: 100%;
  height: 100%;
  ::v-deep .van-loading {
    margin-top: 20%;
  }
}
</style>