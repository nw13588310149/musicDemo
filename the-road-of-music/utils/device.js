const device = {
    /**
     * 判断是否为iPad
     */
    isIPad() {
        const systemInfo = uni.getSystemInfoSync()
        return systemInfo.model.includes('iPad')
    },

    /**
     * 获取设备方向
     */
    getOrientation() {
        return new Promise((resolve) => {
            uni.getSystemInfo({
                success: (res) => {
                    resolve(res.windowWidth > res.windowHeight ? 'landscape' : 'portrait')
                }
            })
        })
    },

    /**
     * 检查网络状态
     */
    checkNetworkStatus() {
        return new Promise((resolve) => {
            uni.getNetworkType({
                success: (res) => {
                    resolve(res.networkType)
                }
            })
        })
    }
}

export default device 