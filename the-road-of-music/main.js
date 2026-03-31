import App from './App'
import Vant from 'vant'
import 'vant/lib/index.css'
import Emoji from 'emoji-box'
import 'emoji-box/dist/style.css'
import router from './router';
import store from './store'
// #ifndef VUE3
import Vue from 'vue'
import './uni.promisify.adaptor'
Vue.config.productionTip = false
App.mpType = 'app'
const app = new Vue({
  ...App
})
app.$mount()
app.use(Vant)
  app.use(Emoji,{cdn:"/static/assets"})
app.use(router)
app.use(store)
// #endif

// #ifdef VUE3
import { createSSRApp } from 'vue'
export function createApp() {
  const app = createSSRApp(App)
  app.use(Vant)
  app.use(Emoji,{cdn:"/static/assets"})
  app.use(router)
  app.use(store)
  return {
    app
  }
}
// #endif
