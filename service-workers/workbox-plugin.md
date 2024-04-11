## Service Worker Lifecycle

### Manually triggering update checks
---

See [Manually triggering update checks](https://developer.chrome.com/docs/workbox/service-worker-lifecycle/#manually-triggering-update-checks)

Concerning updates, registration logic generally shouldn't change. Yet, one exception might be if sessions on a website are long-lived. This can happen in single page applications where [navigation requests](https://web.dev/handling-navigation-requests/) are rare, since the application typically encounters one navigation request at the start of the application's lifecycle. In such situations, a manual update can be triggered on the main thread

```javascript
navigator.serviceWorker.ready.then((registration) => {
  registration.update();
});
```
