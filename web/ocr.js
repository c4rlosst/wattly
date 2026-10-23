// Reads the number off a photo of a meter. Runs entirely in the browser: the
// photo is never uploaded. The text-recognition library (tesseract.js) is
// downloaded the first time it's needed, not with the app.
(function () {
  var LIB = 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';
  var loading = null;
  var worker = null;

  function loadLib() {
    if (window.Tesseract) return Promise.resolve();
    if (!loading) {
      loading = new Promise(function (resolve, reject) {
        var s = document.createElement('script');
        s.src = LIB;
        s.onload = resolve;
        s.onerror = function () { loading = null; reject(new Error('library')); };
        document.head.appendChild(s);
      });
    }
    return loading;
  }

  function getWorker() {
    if (!worker) {
      worker = loadLib().then(function () {
        return window.Tesseract.createWorker('eng');
      }).then(function (w) {
        return w.setParameters({
          tessedit_char_whitelist: '0123456789.',
          tessedit_pageseg_mode: '11', // sparse text: find digits anywhere
        }).then(function () { return w; });
      });
      worker.catch(function () { worker = null; });
    }
    return worker;
  }

  // Shrinks the photo and stretches its contrast so digits stand out.
  function prepare(file) {
    return createImageBitmap(file, { imageOrientation: 'from-image' }).then(function (bmp) {
      var scale = Math.min(1, 1600 / Math.max(bmp.width, bmp.height));
      var c = document.createElement('canvas');
      c.width = Math.round(bmp.width * scale);
      c.height = Math.round(bmp.height * scale);
      var ctx = c.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(bmp, 0, 0, c.width, c.height);
      var img = ctx.getImageData(0, 0, c.width, c.height);
      var d = img.data, hist = new Array(256).fill(0), n = d.length / 4, i;
      for (i = 0; i < d.length; i += 4) {
        var g = (d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114) | 0;
        d[i] = g; hist[g]++;
      }
      var lo = 0, hi = 255, acc = 0;
      for (lo = 0; lo < 255 && (acc += hist[lo]) < n * 0.02; lo++);
      acc = 0;
      for (hi = 255; hi > 0 && (acc += hist[hi]) < n * 0.02; hi--);
      var span = Math.max(1, hi - lo);
      for (i = 0; i < d.length; i += 4) {
        var v = Math.max(0, Math.min(255, ((d[i] - lo) * 255 / span) | 0));
        d[i] = d[i + 1] = d[i + 2] = v;
      }
      ctx.putImageData(img, 0, 0);
      return c;
    });
  }

  function pickPhoto() {
    return new Promise(function (resolve) {
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.setAttribute('capture', 'environment');
      input.style.display = 'none';
      input.addEventListener('change', function () {
        resolve((input.files && input.files[0]) || null);
        input.remove();
      });
      input.addEventListener('cancel', function () { resolve(null); input.remove(); });
      document.body.appendChild(input);
      input.click();
    });
  }

  // Recognises the digits in an image, canvas or file. Returns the raw text.
  window.wattlyOcr = function (source) {
    var canvas = source instanceof Blob ? prepare(source) : Promise.resolve(source);
    return Promise.all([canvas, getWorker()]).then(function (r) {
      return r[1].recognize(r[0]);
    }).then(function (res) { return res.data.text || ''; });
  };

  // Opens the camera, then reads the photo. `onPicked` fires when a photo has
  // been taken (reading can take a few seconds). Resolves null if cancelled.
  window.wattlyScan = function (onPicked) {
    return pickPhoto().then(function (file) {
      if (!file) return null;
      if (onPicked) onPicked();
      return window.wattlyOcr(file);
    });
  };
})();
