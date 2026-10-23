// Reads the number on a seven-segment display (the LCD or LED digits on most
// dorm and household electricity meters). General text recognition is poor at
// these, so this looks at which of the seven bars of each digit are lit.
//
//   wattlyReadLcd(canvas) -> { text: '005359.0', box: {x0, y0, x1, y1} } | null
//
// `box` is in the canvas's own pixels. Runs on the phone, a few milliseconds
// per frame.
(function () {
  var ROWS = 120; // work on a copy this tall

  // Which bars are lit for each digit: a top, b top-right, c bottom-right,
  // d bottom, e bottom-left, f top-left, g middle.
  var DIGITS = {
    abcdef: '0', bc: '1', abdeg: '2', abcdg: '3', bcfg: '4', acdfg: '5',
    acdefg: '6', abc: '7', abcdefg: '8', abcdfg: '9',
  };
  // Where each bar is inside a digit's box (fractions: x0, x1, y0, y1).
  var PROBES = {
    a: [0.2, 0.8, 0.0, 0.18], g: [0.2, 0.8, 0.41, 0.59], d: [0.2, 0.8, 0.82, 1.0],
    f: [0.0, 0.28, 0.1, 0.48], b: [0.72, 1.0, 0.1, 0.48],
    e: [0.0, 0.28, 0.52, 0.9], c: [0.72, 1.0, 0.52, 0.9],
  };

  function gray(canvas) {
    var k = Math.min(1, ROWS / canvas.height);
    var w = Math.max(8, Math.round(canvas.width * k));
    var h = Math.max(8, Math.round(canvas.height * k));
    var c = document.createElement('canvas');
    c.width = w; c.height = h;
    var ctx = c.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(canvas, 0, 0, w, h);
    var d = ctx.getImageData(0, 0, w, h).data, g = new Uint8Array(w * h);
    for (var i = 0; i < w * h; i++) {
      g[i] = (d[i * 4] * 0.299 + d[i * 4 + 1] * 0.587 + d[i * 4 + 2] * 0.114) | 0;
    }
    return { g: g, w: w, h: h, k: k };
  }

  function percentile(g, p) {
    var hist = new Array(256).fill(0), i, acc = 0, target = g.length * p;
    for (i = 0; i < g.length; i++) hist[g[i]]++;
    for (i = 0; i < 256; i++) { acc += hist[i]; if (acc >= target) return i; }
    return 255;
  }

  // Marks the "ink" pixels: those clearly darker than their surroundings (or
  // lighter, if `invert`). Judging each pixel against its neighbourhood keeps
  // big dark areas such as a coloured panel out, and the margin leaves out the
  // faint, switched-off bars that LCDs show.
  function inkMask(img, invert) {
    var g = img.g, w = img.w, h = img.h, n = g.length, m = new Uint8Array(n), x, y, i;
    var lo = percentile(g, 0.03), hi = percentile(g, 0.97);
    if (hi - lo < 30) return m; // flat: nothing to read
    var margin = (hi - lo) * 0.2, R = Math.max(6, Math.round(h * 0.2));
    var integral = new Float64Array((w + 1) * (h + 1));
    for (y = 0; y < h; y++) {
      var row = 0;
      for (x = 0; x < w; x++) {
        row += g[y * w + x];
        integral[(y + 1) * (w + 1) + x + 1] = integral[y * (w + 1) + x + 1] + row;
      }
    }
    for (y = 0; y < h; y++) {
      var y0 = Math.max(0, y - R), y1 = Math.min(h, y + R + 1);
      for (x = 0; x < w; x++) {
        var x0 = Math.max(0, x - R), x1 = Math.min(w, x + R + 1);
        var sum = integral[y1 * (w + 1) + x1] - integral[y0 * (w + 1) + x1] -
          integral[y1 * (w + 1) + x0] + integral[y0 * (w + 1) + x0];
        var mean = sum / ((x1 - x0) * (y1 - y0));
        i = y * w + x;
        m[i] = (invert ? g[i] > mean + margin : g[i] < mean - margin) ? 1 : 0;
      }
    }
    return m;
  }

  // Fills gaps in the ink: up to 2*rx pixels sideways and 2*ry up and down.
  // This joins the bars of one digit (the upper and lower halves of a 0 touch
  // nothing) without joining neighbouring digits.
  function close(m, w, h, rx, ry) {
    function pass(src, horizontal, r, grow) {
      var out = new Uint8Array(src.length), x, y, k, hit, n = horizontal ? w : h;
      for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
        hit = grow ? 0 : 1;
        for (k = -r; k <= r; k++) {
          var i = horizontal ? x + k : y + k;
          if (i < 0 || i >= n) { if (!grow) hit = 0; continue; }
          var v = src[horizontal ? y * w + i : i * w + x];
          if (grow && v) { hit = 1; break; }
          if (!grow && !v) { hit = 0; break; }
        }
        out[y * w + x] = hit;
      }
      return out;
    }
    var t = pass(m, true, rx, true);
    t = pass(t, false, ry, true);
    t = pass(t, false, ry, false);
    return pass(t, true, rx, false);
  }

  // Connected blobs of ink with their bounding boxes.
  function blobs(m, w, h) {
    var seen = new Uint8Array(m.length), out = [], stack = [], i, j, p, x, y, dx, dy, nx, ny;
    for (i = 0; i < m.length; i++) {
      if (!m[i] || seen[i]) continue;
      var b = { x0: w, y0: h, x1: 0, y1: 0, area: 0, pix: [] };
      stack.push(i); seen[i] = 1;
      while (stack.length) {
        p = stack.pop(); x = p % w; y = (p / w) | 0;
        b.area++; b.pix.push(p);
        if (x < b.x0) b.x0 = x; if (x > b.x1) b.x1 = x;
        if (y < b.y0) b.y0 = y; if (y > b.y1) b.y1 = y;
        for (dy = -1; dy <= 1; dy++) for (dx = -1; dx <= 1; dx++) {
          nx = x + dx; ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          j = ny * w + nx;
          if (m[j] && !seen[j]) { seen[j] = 1; stack.push(j); }
        }
      }
      out.push(b);
    }
    return out;
  }

  function median(a) {
    var s = a.slice().sort(function (x, y) { return x - y; });
    return s[s.length >> 1];
  }

  // Slants the ink back upright (most displays lean to the right).
  function deslant(m, w, h, y0, y1) {
    var ymid = (y0 + y1) / 2, best = 0, bestScore = -1, s, x, y, hist, score, i;
    for (s = -0.4; s <= 0.4001; s += 0.04) {
      hist = new Array(w + 80).fill(0);
      for (y = y0; y <= y1; y++) for (x = 0; x < w; x++) {
        if (m[y * w + x]) hist[Math.round(x - s * (y - ymid)) + 40]++;
      }
      score = 0;
      for (i = 0; i < hist.length; i++) score += hist[i] * hist[i];
      if (score > bestScore) { bestScore = score; best = s; }
    }
    var o = new Uint8Array(m.length), nx;
    for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
      if (!m[y * w + x]) continue;
      nx = Math.round(x - best * (y - ymid));
      if (nx >= 0 && nx < w) o[y * w + nx] = 1;
    }
    return o;
  }

  function fraction(m, w, box, p) {
    var bw = box.x1 - box.x0 + 1, bh = box.y1 - box.y0 + 1;
    var x0 = box.x0 + Math.floor(p[0] * bw), x1 = box.x0 + Math.max(Math.floor(p[0] * bw), Math.ceil(p[1] * bw) - 1);
    var y0 = box.y0 + Math.floor(p[2] * bh), y1 = box.y0 + Math.max(Math.floor(p[2] * bh), Math.ceil(p[3] * bh) - 1);
    var on = 0, total = 0, x, y;
    for (y = y0; y <= y1; y++) for (x = x0; x <= x1; x++) { total++; on += m[y * w + x]; }
    return total ? on / total : 0;
  }

  // For development: when window.__lcdDebug is an array, decode() notes why it
  // gave up and keeps the ink picture.
  function note(what, info) {
    if (window.__lcdDebug) window.__lcdDebug.push({ what: what, info: info });
  }

  function decode(img, invert) {
    var w = img.w, h = img.h, ink = inkMask(img, invert), rx = 1, ry = Math.max(2, Math.round(h * 0.06));
    // Drop frame lines and panel edges: ink that runs far wider than any digit
    // or all the way from the top to the bottom of the view.
    blobs(ink, w, h).forEach(function (b) {
      if (b.x1 - b.x0 > h * 1.1 || (b.y0 <= 1 && b.y1 >= h - 2)) {
        b.pix.forEach(function (i) { ink[i] = 0; });
      }
    });
    if (window.__lcdDebug && !invert) window.__lcdDebug.ink = { w: w, h: h, s: Array.from(ink).join('') };

    // The row of digits is somewhere among the tall blobs of ink; try the
    // height of each in turn and keep the reading with the most digits.
    var tall = blobs(close(ink, w, h, rx, ry), w, h).filter(function (b) {
      var bh = b.y1 - b.y0 + 1, bw = b.x1 - b.x0 + 1;
      return bh >= h * 0.28 && bh <= h * 0.98 && bw <= bh * 1.6 && b.area > bh * bw * 0.15;
    }).sort(function (a, b) { return b.area - a.area; });
    var seen = {}, best = null;
    tall.slice(0, 8).forEach(function (b) {
      var key = b.y0 + '-' + b.y1;
      if (seen[key]) return;
      seen[key] = 1;
      var r = readBand(img, ink, b.y0, b.y1);
      if (r && (!best || r.text.length > best.text.length)) best = r;
    });
    return best;
  }

  // Reads the digits in the rows y0..y1 of the ink picture.
  function readBand(img, ink, y0, y1) {
    var w = img.w, h = img.h, mh = y1 - y0 + 1, x, y;
    // Stand the digits up straight, then cut the row into digits wherever a
    // column has no ink.
    var up = deslant(ink, w, h, y0, y1);
    var cols = new Array(w).fill(0);
    for (x = 0; x < w; x++) for (y = y0; y <= y1; y++) cols[x] += up[y * w + x];
    var runs = [], start = -1;
    for (x = 0; x <= w; x++) {
      var on = x < w && cols[x] > 1;
      if (on && start < 0) start = x;
      if (!on && start >= 0) { runs.push({ x0: start, x1: x - 1 }); start = -1; }
    }
    runs.forEach(function (r) {
      var lo = y1, hi = y0;
      for (var xx = r.x0; xx <= r.x1; xx++) for (var yy = y0; yy <= y1; yy++) {
        if (up[yy * w + xx]) { if (yy < lo) lo = yy; if (yy > hi) hi = yy; }
      }
      r.w = r.x1 - r.x0 + 1; r.top = lo; r.bottom = hi;
    });
    note('runs ' + y0 + '-' + y1, runs.map(function (r) { return [r.x0, r.x1, r.top, r.bottom].join(','); }));
    var dots = runs.filter(function (r) { return r.bottom - r.top < mh * 0.25 && r.top > y0 + mh * 0.6 && r.w <= mh * 0.25; });
    var digits = runs.filter(function (r) { return dots.indexOf(r) < 0 && r.w >= mh * 0.1 && r.bottom - r.top > mh * 0.5; });
    var wide = digits.filter(function (r) { return r.w > mh * 0.3; }).map(function (r) { return r.w; });
    if (wide.length < 2) return null;
    var dw = median(wide);
    digits = digits.filter(function (r) { return r.w < dw * 1.6 && (r.w > dw * 0.7 || r.w < dw * 0.5); });
    if (digits.length < 3) return null;

    var left = w, right = 0, tokens = [], bad = 0;
    digits.forEach(function (r) {
      var box = { x0: r.x0, x1: r.x1, y0: y0, y1: y1 }, ch = '?';
      if (r.w < dw * 0.5) {
        ch = '1';
      } else {
        var lit = '';
        for (var k in PROBES) if (fraction(up, w, box, PROBES[k]) > 0.4) lit += k;
        note('lit ' + r.x0, lit);
        ch = DIGITS[lit.split('').sort().join('')] || '?';
      }
      if (ch === '?') bad++;
      tokens.push({ x: (r.x0 + r.x1) / 2, ch: ch });
      left = Math.min(left, r.x0); right = Math.max(right, r.x1);
    });
    // A decimal point sits between two digits, near the bottom.
    dots.forEach(function (d) {
      var cx = (d.x0 + d.x1) / 2;
      if (cx > digits[0].x1 && cx < digits[digits.length - 1].x0) tokens.push({ x: cx, ch: '.' });
    });
    tokens.sort(function (a, b) { return a.x - b.x; });
    var text = tokens.map(function (t) { return t.ch; }).join('');
    note('text ' + y0 + '-' + y1, text);
    // Any unreadable digit means this wasn't a clean read.
    if (bad > 0 || text.replace(/\./g, '').length < 3) return null;
    var k = 1 / img.k, pad = mh * 0.15;
    return {
      text: text,
      box: { x0: (left - pad) * k, y0: (y0 - pad) * k, x1: (right + pad) * k, y1: (y1 + pad) * k },
    };
  }

  window.wattlyReadLcd = function (canvas) {
    var img = gray(canvas);
    var a = decode(img, false), b = decode(img, true);
    if (a && b) return a.text.length >= b.text.length ? a : b;
    return a || b;
  };
})();
