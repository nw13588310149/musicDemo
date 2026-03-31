<template>
  <view class="class-select" v-if="classAll?.length > 1" @click="showPicker = !showPicker">
    <text>{{activeClass.name}}</text>
    <van-icon :name="showPicker ? 'arrow-up' : 'arrow-down'" />
  </view>
  
  <van-popup v-model:show="showPicker" round position="bottom">
    <van-picker
      :columns="columns"
      @cancel="showPicker = false"
      @confirm="onSelectClass"
      show-toolbar
      title="选择班级"
    />
  </van-popup>
</template>

<script setup>
import { ref, watch } from 'vue';

const props = defineProps({
  classAll: {
    type: Array,
    default: () => []
  },
  activeClass: {
    type: Object,
    default: () => ({})
  }
});

const emit = defineEmits(['update:activeClass']);

const showPicker = ref(false);
const columns = ref([]);

// 监听班级列表变化，更新选择器数据
watch(() => props.classAll, (newVal) => {
  if (newVal) {
    columns.value = newVal.map(item => ({
      text: item.name,
      value: item.id
    }));
  }
}, { immediate: true });

// 选择班级
const onSelectClass = (value) => {
  const selectedClass = props.classAll[value.selectedIndexes[0]];
  emit('update:activeClass', selectedClass);
  uni.setStorageSync('defaultClass', JSON.stringify(selectedClass));
  showPicker.value = false;
};
</script>

<style lang="scss" scoped>
.class-select {
  display: inline-flex;
  align-items: center;
  padding: 6px 12px;
  background: #f6f7fb;
  border-radius: 4px;
  margin-bottom: 12px;
  cursor: pointer;
  transition: all 0.3s;

  text {
    margin-right: 4px;
    font-size: 14px;
  }

  &:hover {
    background: #f0f3f8;
  }
}
</style> 