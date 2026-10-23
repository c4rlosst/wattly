// Reads the number off a meter with the camera. Runs entirely in the browser:
// nothing is uploaded. The text-recognition library (tesseract.js) is
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

  // Greyscales a canvas and stretches its contrast so digits stand out.
  function enhance(c) {
    var ctx = c.getContext('2d', { willReadFrequently: true });
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
  }

  // Shrinks a photo file to a canvas the reader can handle.
  function prepare(file) {
    return createImageBitmap(file, { imageOrientation: 'from-image' }).then(function (bmp) {
      var scale = Math.min(1, 1600 / Math.max(bmp.width, bmp.height));
      var c = document.createElement('canvas');
      c.width = Math.round(bmp.width * scale);
      c.height = Math.round(bmp.height * scale);
      c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
      return enhance(c);
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

  // Recognises the digits in a canvas or photo file. Returns the raw text.
  window.wattlyOcr = function (source) {
    var canvas = source instanceof Blob ? prepare(source) : Promise.resolve(source);
    return Promise.all([canvas, getWorker()]).then(function (r) {
      return r[1].recognize(r[0]);
    }).then(function (res) { return res.data.text || ''; });
  };

  // The number in `text` that looks like a meter reading: 3-9 digits, the one
  // closest to `last` if given, else one with a decimal part, then the longest.
  function bestNumber(text, last) {
    var found = (text || '').match(/\d+(?:\.\d+)?/g) || [];
    var c = found.filter(function (t) {
      var n = t.replace('.', '').length;
      return n >= 3 && n <= 9;
    });
    if (!c.length) return null;
    c.sort(function (a, b) {
      if (typeof last === 'number') return Math.abs(a - last) - Math.abs(b - last);
      var d = (b.indexOf('.') >= 0 ? 1 : 0) - (a.indexOf('.') >= 0 ? 1 : 0);
      return d || b.length - a.length;
    });
    return c[0];
  }

  function el(tag, css, parent, text) {
    var e = document.createElement(tag);
    e.style.cssText = css;
    if (text) e.textContent = text;
    if (parent) parent.appendChild(e);
    return e;
  }

  // A full-screen camera view with a frame to line the digits up in. It reads
  // the area inside the frame about twice a second, shows what it sees, and
  // locks on when the same number comes up twice in a row. Resolves with the
  // number, '' if the shutter was pressed and nothing was read, or null if
  // cancelled. Rejects if the camera can't be used.
  function liveScan(last) {
    var font = '-apple-system,BlinkMacSystemFont,"SF Pro Text",Roboto,sans-serif';
    return navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1080 } },
      audio: false,
    }).then(function (stream) {
      return new Promise(function (resolve) {
        var done = false, busy = false, prev = null;
        var root = el('div', 'position:fixed;left:0;top:0;right:0;bottom:0;z-index:2147483000;background:#000;font-family:' + font, document.body);
        var video = el('video', 'position:absolute;left:0;top:0;width:100%;height:100%;object-fit:cover', root);
        video.setAttribute('playsinline', '');
        video.muted = true;
        video.srcObject = stream;
        video.play();

        var guide = el('div', 'position:absolute;left:7%;right:7%;top:26%;height:11%;border-radius:14px;' +
          'border:3px solid rgba(255,255,255,.9);box-shadow:0 0 0 100vmax rgba(0,0,0,.55);transition:border-color .2s', root);
        var mark = el('div', 'position:absolute;display:none;border:2px solid #34C759;border-radius:6px;background:rgba(52,199,89,.15)', root);
        var seen = el('div', 'position:absolute;left:0;right:0;top:calc(26% + 11% + 18px);text-align:center;color:#fff;' +
          'font-size:34px;font-weight:700;letter-spacing:1px;text-shadow:0 1px 6px rgba(0,0,0,.6);min-height:42px', root);
        var cancel = el('div', 'position:absolute;left:16px;top:calc(env(safe-area-inset-top,0px) + 16px);color:#fff;' +
          'font-size:17px;padding:8px 6px;text-shadow:0 1px 4px rgba(0,0,0,.6);cursor:pointer', root, 'Cancel');
        var track = stream.getVideoTracks()[0];
        var caps = track.getCapabilities ? track.getCapabilities() : {};
        var torchOn = false;
        if (caps.torch) {
          var torch = el('div', 'position:absolute;right:16px;top:calc(env(safe-area-inset-top,0px) + 16px);color:#fff;' +
            'font-size:17px;padding:8px 6px;text-shadow:0 1px 4px rgba(0,0,0,.6);cursor:pointer', root, 'Light');
          torch.onclick = function () {
            torchOn = !torchOn;
            track.applyConstraints({ advanced: [{ torch: torchOn }] });
            torch.style.color = torchOn ? '#FFD60A' : '#fff';
          };
        }
        var panel = el('div', 'position:absolute;left:0;right:0;bottom:0;background:#fff;border-radius:24px 24px 0 0;' +
          'padding:22px 24px calc(env(safe-area-inset-bottom,0px) + 22px);text-align:center;color:#111', root);
        var status = el('div', 'font-size:19px;font-weight:600;margin-bottom:6px', panel, 'Fit the meter digits inside the frame');
        el('div', 'font-size:14px;color:#6b6b70;margin-bottom:16px', panel, 'It reads the number by itself, or tap the button.');
        var shutter = el('div', 'width:68px;height:68px;border-radius:50%;margin:0 auto;border:4px solid #FF9500;' +
          'box-sizing:border-box;padding:4px;cursor:pointer', panel);
        el('div', 'width:100%;height:100%;border-radius:50%;background:#FF9500', shutter);

        function close() {
          done = true;
          stream.getTracks().forEach(function (t) { t.stop(); });
          root.remove();
        }
        function finish(value) {
          if (done) return;
          close();
          resolve(value);
        }
        cancel.onclick = function () { finish(null); };

        // Crops the frame to the guide, in video pixels.
        function grab() {
          var vw = video.videoWidth, vh = video.videoHeight;
          if (!vw || !vh) return null;
          var r = root.getBoundingClientRect(), g = guide.getBoundingClientRect();
          var scale = Math.max(r.width / vw, r.height / vh);
          var ox = (r.width - vw * scale) / 2, oy = (r.height - vh * scale) / 2;
          var sx = Math.max(0, (g.left - r.left - ox) / scale), sy = Math.max(0, (g.top - r.top - oy) / scale);
          var sw = Math.min(vw - sx, g.width / scale), sh = Math.min(vh - sy, g.height / scale);
          var k = Math.min(1, 1000 / sw);
          var c = document.createElement('canvas');
          c.width = Math.round(sw * k); c.height = Math.round(sh * k);
          c.getContext('2d').drawImage(video, sx, sy, sw, sh, 0, 0, c.width, c.height);
          var plain = document.createElement('canvas');
          plain.width = c.width; plain.height = c.height;
          plain.getContext('2d').drawImage(c, 0, 0);
          return { canvas: enhance(c), plain: plain, g: g, r: r };
        }

        // Reads the frame: first as seven-segment digits (most meters), then,
        // if the text reader has loaded, as ordinary text.
        function read(f) {
          var lcd = window.wattlyReadLcd && window.wattlyReadLcd(f.plain);
          var num = lcd && bestNumber(lcd.text, last);
          if (num) return Promise.resolve({ num: num, box: lcd.box });
          if (!workerReady) return Promise.resolve({ num: null });
          return getWorker().then(function (w) { return w.recognize(f.canvas); }).then(function (res) {
            var n = bestNumber(res.data.text, last);
            var word = n && (res.data.words || []).filter(function (w) { return w.text.indexOf(n) >= 0; })[0];
            return { num: n, box: word && word.bbox && { x0: word.bbox.x0, y0: word.bbox.y0, x1: word.bbox.x1, y1: word.bbox.y1 } };
          });
        }

        function recognise(manual) {
          var f = grab();
          if (!f) return Promise.resolve();
          return read(f).then(function (res) {
            if (done) return;
            var num = res.num;
            if (manual) { finish(num || ''); return; }
            seen.textContent = num || '';
            guide.style.borderColor = num ? '#34C759' : 'rgba(255,255,255,.9)';
            mark.style.display = 'none';
            if (!num) {
              status.textContent = 'Fit the meter digits inside the frame';
              prev = null;
              return;
            }
            if (res.box) {
              var b = res.box, g = f.g, r = f.r;
              mark.style.left = (g.left - r.left + b.x0 / f.canvas.width * g.width - 4) + 'px';
              mark.style.top = (g.top - r.top + b.y0 / f.canvas.height * g.height - 4) + 'px';
              mark.style.width = ((b.x1 - b.x0) / f.canvas.width * g.width + 8) + 'px';
              mark.style.height = ((b.y1 - b.y0) / f.canvas.height * g.height + 8) + 'px';
              mark.style.display = 'block';
            }
            if (prev === num) {
              status.textContent = 'Got it';
              setTimeout(function () { finish(num); }, 350);
            } else {
              status.textContent = 'Hold steady…';
              prev = num;
            }
          });
        }

        shutter.onclick = function () {
          if (done) return;
          status.textContent = 'Reading…';
          var go = function () {
            if (done) return;
            if (busy) { setTimeout(go, 150); return; }
            busy = true;
            recognise(true).then(function () { busy = false; }, function () { finish(''); });
          };
          go();
        };

        function loop() {
          if (done) return;
          if (busy) { setTimeout(loop, 150); return; }
          busy = true;
          recognise(false).then(function () {}, function () {}).then(function () {
            busy = false;
            setTimeout(loop, 250);
          });
        }
        var workerReady = false;
        getWorker().then(function () { workerReady = true; }, function () {});
        setTimeout(loop, 400);
      });
    });
  }

  // Opens the live scanner; if the camera isn't available, falls back to
  // taking a photo. `onPicked` fires when a number has been read. Resolves
  // null if cancelled.
  window.wattlyScan = function (last, onPicked) {
    var hasCamera = navigator.mediaDevices && navigator.mediaDevices.getUserMedia;
    var live = hasCamera
      ? liveScan(typeof last === 'number' ? last : undefined)
      : Promise.reject(new Error('no camera'));
    return live.then(function (v) {
      if (v && onPicked) onPicked();
      return v;
    }, function (err) {
      return pickPhoto().then(function (file) {
        if (!file) return null;
        if (onPicked) onPicked();
        return window.wattlyOcr(file);
      });
    });
  };
})();
