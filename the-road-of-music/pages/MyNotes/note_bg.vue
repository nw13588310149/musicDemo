<template>
  <view class="content_note_bg">
    <view class="top">
      <van-icon class="return" name="arrow-left" @click="left" />
      <view class="right" @click="goD">应用</view>
    </view>
    <view class="box">
      <view
        v-for="(item, index) in items"
        :key="index"
        class="item"
        :style="{backgroundImage: 'url(' + item.background + ')'}"
        :class="{ active: index === activeIndex }"
        @click="selectItem(index)"
      >
        <view class="tit">{{ item.title }}</view>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';

const router = useRouter();
const activeIndex = ref(0); // 默认选中第一个
const items = ref([
  { title: '五线谱', background: '/static/assets/bg_wxp2.jpg' },
  { title: '笔记本', background: '/static/assets/bg_bjb2.jpg' },
  { title: '白纸', background: '' },
]);

function left() {
  router.push({ name: 'note' });
}

function selectItem(index) {
  activeIndex.value = index;
}

function goD(){
	router.push({ name: 'noteDetail' ,state:{id:history.state.id,title:history.state.title,type:activeIndex.value}});
}
</script>

<style lang="scss" scoped>
.content_note_bg {
  background: #fff;
  width: 100%;
  height: 100%;
  border-radius: 14px;
  padding: 20px;
}

.top {
  position: relative;
  padding-bottom: 30px;
  border-bottom: 1px solid #eee;
}

.return {
  font-size: 30px;
}

.right {
  width: 100px;
  position: absolute;
  right: 0;
  top: 0;
  height: 30px;
  line-height: 30px;
  text-align: center;
  background: #111;
  color: #fff;
  border-radius: 30px;
  letter-spacing: 2px;
}

.box {
  display: flex;
  justify-content: space-between;
  margin-top: 40px;
}

.item {
	width: calc(33% - 5px);
    border: 1px solid #eee;
    border-radius: 4px;
    background-repeat: no-repeat;
    background-size: cover;
    box-sizing: border-box;
    height: 410px;
}

.tit {
  width: 80px;
  height: 30px;
  line-height: 30px;
  text-align: center;
  margin: 20px;
  border-radius: 20px;
  background: #eeeeee99;
}
.active{
	border-color: #000;
}
</style>
