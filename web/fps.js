// A small frame-rate readout for finding slow spots. Hidden unless the page is
// opened with ?fps in the address (e.g. https://c4rlosst.github.io/wattly/?fps).
(function () {
  if (!/[?&]fps(&|=|$)/.test(location.search)) return;
  window.wattlyFps = true;

  var box = document.createElement('div');
  box.style.cssText = 'position:fixed;left:6px;top:6px;z-index:2147483600;pointer-events:none;' +
    'background:rgba(0,0,0,.72);color:#4cff6a;font:11px/1.35 ui-monospace,Menlo,monospace;' +
    'padding:4px 7px;border-radius:7px;white-space:pre';
  box.textContent = 'fps …';
  document.addEventListener('DOMContentLoaded', function () { document.body.appendChild(box); });

  var build = [], raster = [], frames = 0, worst = 0, slow = 0;
  var last = performance.now(), windowStart = last;

  // Fed by the app with how long each frame took to build and to draw.
  window.wattlyFrame = function (buildMs, rasterMs) {
    build.push(buildMs);
    raster.push(rasterMs);
  };

  function avg(a) { return a.length ? a.reduce(function (x, y) { return x + y; }, 0) / a.length : 0; }
  function max(a) { return a.length ? Math.max.apply(null, a) : 0; }

  function tick(t) {
    var d = t - last;
    last = t;
    frames++;
    if (d > worst) worst = d;
    if (d > 34) slow++;
    if (t - windowStart >= 1000) {
      box.textContent =
        'screen ' + Math.round(frames * 1000 / (t - windowStart)) + ' fps' +
        '   slowest ' + Math.round(worst) + ' ms   >34ms: ' + slow + '\n' +
        'build ' + avg(build).toFixed(1) + ' (max ' + max(build).toFixed(0) + ')' +
        '   draw ' + avg(raster).toFixed(1) + ' (max ' + max(raster).toFixed(0) + ') ms\n' +
        'pixel ratio ' + (window.devicePixelRatio || 1);
      frames = 0; worst = 0; slow = 0; build = []; raster = [];
      windowStart = t;
    }
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
})();
