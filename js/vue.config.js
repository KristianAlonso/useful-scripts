const { defineConfig } = require('@vue/cli-service')

module.exports = defineConfig({
  transpileDependencies: true,
  pwa: {
    workboxOptions: {
      // Mira: https://developer.chrome.com/docs/workbox/reference/workbox-build/#property-GeneratePartial-clientsClaim
      clientsClaim: true,
      // Mira: https://developer.chrome.com/docs/workbox/reference/workbox-build/#property-GeneratePartial-cleanupOutdatedCaches
      cleanupOutdatedCaches: true,
      // Mira: https://developer.chrome.com/docs/workbox/caching-strategies-overview/#stale-while-revalidate
      // Mira: https://developer.chrome.com/docs/workbox/reference/workbox-build/#property-GeneratePartial-runtimeCaching
      runtimeCaching: ['StaleWhileRevalidate'],
      // Mira: https://developer.chrome.com/docs/workbox/reference/workbox-build/#property-GeneratePartial-skipWaiting
      skipWaiting: true
    }
  }
})
