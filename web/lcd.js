// Reads the number on a seven-segment display (the LCD or LED digits on most
// dorm and household electricity meters). General text recognition is poor at
// these, so this looks at which of the seven bars of each digit are lit.
//
//   wattlyReadLcd(canvas) -> { text: '005359.0', box: {x0, y0, x1, y1} } | null
//
// `box` is in the canvas's own pixels. Runs on the phone, a few milliseconds
// per frame. Works for dark digits on a light display (LCD) and for light
// digits on a dark one (LED), leaning or upright.
(function () {
  var ROWS = 120; // work on a copy this tall

  // Which bars are lit for each digit: a top, b top-right, c bottom-right,
  // d bottom, e bottom-left, f top-left, g middle.
  var BARS = {
    '0': 'abcdef', '1': 'bc', '2': 'abdeg', '3': 'abcdg', '4': 'bcfg',
    '5': 'acdfg', '6': 'acdefg', '7': 'abc', '8': 'abcdefg', '9': 'abcdfg',
  };
  // Where each bar is inside a digit's box (fractions: x0, x1, y0, y1).
  var PROBES = {
    a: [0.2, 0.8, 0.0, 0.25], g: [0.2, 0.8, 0.35, 0.65], d: [0.2, 0.8, 0.75, 1.0],
    f: [0.0, 0.35, 0.12, 0.45], b: [0.65, 1.0, 0.12, 0.45],
    e: [0.0, 0.35, 0.55, 0.88], c: [0.65, 1.0, 0.55, 0.88],
  };
  var NAMES = 'abcdefg'.split('');

  function note(what, info) {
    if (window.__lcdDebug) window.__lcdDebug.push({ what: what, info: info });
  }

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
  // faint, switched-off bars that displays show.
  function inkMask(img, invert) {
    var g = img.g, w = img.w, h = img.h, m = new Uint8Array(g.length), x, y;
    var lo = percentile(g, 0.03), hi = percentile(g, 0.97);
    if (hi - lo < 30) return m; // flat: nothing to read
    var margin = (hi - lo) * 0.18, R = Math.max(6, Math.round(h * 0.2));
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
        var mean = sum / ((x1 - x0) * (y1 - y0)), i = y * w + x;
        m[i] = (invert ? g[i] > mean + margin : g[i] < mean - margin) ? 1 : 0;
      }
    }
    return m;
  }

  // Fills gaps in the ink: up to 2*rx pixels sideways and 2*ry up and down.
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

  // Slants the ink back upright (most displays lean to the right): picks the
  // lean that makes the vertical bars line up into the sharpest columns.
  function deslant(m, w, h, y0, y1) {
    var ymid = (y0 + y1) / 2, best = 0, bestScore = -1, s, x, y, hist, score, i;
    for (s = -0.4; s <= 0.4001; s += 0.04) {
      hist = new Array(w + 120).fill(0);
      for (y = y0; y <= y1; y++) for (x = 0; x < w; x++) {
        if (m[y * w + x]) hist[Math.round(x - s * (y - ymid)) + 60]++;
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

  // How fully a bar is inked: the best row (for a horizontal bar) or column
  // (for a vertical one) inside its probe, so thin and thick strokes both
  // count as lit.
  function coverage(m, w, box, p, horizontal) {
    var bw = box.x1 - box.x0 + 1, bh = box.y1 - box.y0 + 1;
    var x0 = box.x0 + Math.floor(p[0] * bw), x1 = box.x0 + Math.max(Math.floor(p[0] * bw), Math.ceil(p[1] * bw) - 1);
    var y0 = box.y0 + Math.floor(p[2] * bh), y1 = box.y0 + Math.max(Math.floor(p[2] * bh), Math.ceil(p[3] * bh) - 1);
    var best = 0, on, x, y;
    if (horizontal) {
      for (y = y0; y <= y1; y++) {
        on = 0;
        for (x = x0; x <= x1; x++) on += m[y * w + x];
        best = Math.max(best, on / (x1 - x0 + 1));
      }
    } else {
      for (x = x0; x <= x1; x++) {
        on = 0;
        for (y = y0; y <= y1; y++) on += m[y * w + x];
        best = Math.max(best, on / (y1 - y0 + 1));
      }
    }
    return best;
  }

  // Picks the digit whose bars best match how much ink each probe found.
  // Returns null unless one digit clearly beats the rest.
  function classify(up, w, box) {
    var f = {}, i, k;
    // How lit each bar looks, from 0 (no ink) to 1 (clearly lit).
    NAMES.forEach(function (n) { f[n] = Math.max(0, Math.min(1, (coverage(up, w, box, PROBES[n], 'agd'.indexOf(n) >= 0) - 0.3) / 0.4)); });
    var best = null, second = 99, bestCost = 99;
    for (k in BARS) {
      var cost = 0;
      for (i = 0; i < 7; i++) cost += BARS[k].indexOf(NAMES[i]) >= 0 ? 1 - f[NAMES[i]] : f[NAMES[i]];
      if (cost < bestCost) { second = bestCost; bestCost = cost; best = k; }
      else if (cost < second) second = cost;
    }
    note('classify', box.x0 + ',' + box.x1 + ' f=' + NAMES.map(function (n) { return n + f[n].toFixed(2); }).join(' ') + ' best ' + best + ' ' + bestCost.toFixed(2) + ' / ' + second.toFixed(2));
    if (bestCost <= 1.6 && second - bestCost >= 0.5) return { ch: best, cost: bestCost };
    return null;
  }

  // Cuts a run of columns that is several digits wide into one run per digit,
  // at the emptiest columns near where the digit edges should fall.
  function split(run, cols, dw, gap) {
    var n = Math.round((run.w + gap) / (dw + gap));
    if (n < 2) return [run];
    var pitch = (run.w + gap) / n, out = [], start = run.x0, c, x;
    for (c = 1; c < n; c++) {
      var around = run.x0 + c * pitch - gap / 2, bx = Math.round(around), bv = 1e9;
      for (x = Math.round(around - pitch * 0.25); x <= Math.round(around + pitch * 0.25); x++) {
        if (x > start + 2 && x < run.x1 - 2 && cols[x] < bv) { bv = cols[x]; bx = x; }
      }
      out.push({ x0: start, x1: bx - 1 });
      start = bx + 1;
    }
    out.push({ x0: start, x1: run.x1 });
    return out;
  }

  // Reads the digits in the rows y0..y1 of the ink picture. `refine` lets it
  // move the top and bottom of the band to where the digit bars really are.
  function readBand(img, ink, y0, y1, refine) {
    var w = img.w, h = img.h, mh = y1 - y0 + 1, x, y, i;
    var up = deslant(ink, w, h, y0, y1);
    var cols = new Array(w).fill(0);
    for (x = 0; x < w; x++) for (y = y0; y <= y1; y++) cols[x] += up[y * w + x];
    // Digits are separated by (nearly) empty columns.
    var empty = Math.max(1, mh * 0.05), runs = [], start = -1;
    for (x = 0; x <= w; x++) {
      var on = x < w && cols[x] > empty;
      if (on && start < 0) start = x;
      if (!on && start >= 0) { runs.push({ x0: start, x1: x - 1 }); start = -1; }
    }
    function measure(r) {
      var lo = y1, hi = y0;
      for (var xx = r.x0; xx <= r.x1; xx++) for (var yy = y0; yy <= y1; yy++) {
        if (up[yy * w + xx]) { if (yy < lo) lo = yy; if (yy > hi) hi = yy; }
      }
      r.w = r.x1 - r.x0 + 1; r.top = lo; r.bottom = hi;
      return r;
    }
    runs.forEach(measure);
    // A decimal point that sits close to a digit ends up in the same run as
    // it. Peel off columns at either end whose ink is only down on the
    // baseline and make them a run of their own.
    var peeled = [];
    function lowOnly(cx) {
      for (var yy = y0; yy <= y1; yy++) if (up[yy * w + cx]) return yy > y0 + mh * 0.68;
      return false;
    }
    runs.forEach(function (r) {
      if (r.bottom - r.top < mh * 0.5) return;
      var rx = r.x1, lx = r.x0;
      while (rx > r.x0 + 2 && lowOnly(rx)) rx--;
      while (lx < r.x1 - 2 && lowOnly(lx)) lx++;
      var right = r.x1 - rx, left = lx - r.x0;
      var x0 = r.x0, x1 = r.x1;
      if (right > 1 && right <= mh * 0.4) { peeled.push(measure({ x0: rx + 1, x1: x1 })); x1 = rx; }
      if (left > 1 && left <= mh * 0.4) { peeled.push(measure({ x0: x0, x1: lx - 1 })); x0 = lx; }
      if (x0 !== r.x0 || x1 !== r.x1) { r.x0 = x0; r.x1 = x1; measure(r); }
    });
    peeled.forEach(function (r) { runs.push(r); });
    runs.sort(function (a, b) { return a.x0 - b.x0; });
    // Decimal points are small runs sitting on the baseline.
    var dots = runs.filter(function (r) {
      return r.bottom - r.top < mh * 0.28 && r.top > y0 + mh * 0.55 && r.w <= mh * 0.3;
    });
    var cand = runs.filter(function (r) {
      return dots.indexOf(r) < 0 && r.w >= mh * 0.08 && r.bottom - r.top > mh * 0.45;
    });
    // A typical digit's width, from the runs that look like one digit. Digits
    // missing their left-hand bars (1, 3, 7) are narrower and sit at the right
    // of their cell, so judge the cell width by the wider digits.
    var sized = cand.filter(function (r) { return r.w > mh * 0.3 && r.w < mh * 0.85; }).map(function (r) { return r.w; });
    if (!sized.length) return null;
    sized.sort(function (a, b) { return a - b; });
    var dw = sized[Math.floor((sized.length - 1) * 0.75)];

    // Where do the top and bottom bars really sit? Look a little beyond the
    // band, at the columns the digits occupy.
    if (refine) {
      var ext0 = Math.max(0, Math.round(y0 - mh * 0.3)), ext1 = Math.min(h - 1, Math.round(y1 + mh * 0.3));
      var rowSum = new Array(h).fill(0), peak = 0;
      cand.forEach(function (r) {
        for (y = ext0; y <= ext1; y++) for (x = r.x0; x <= r.x1; x++) rowSum[y] += up[y * w + x];
      });
      for (y = ext0; y <= ext1; y++) if (rowSum[y] > peak) peak = rowSum[y];
      var ny0 = ext0, ny1 = ext1;
      while (ny0 < ext1 && rowSum[ny0] < peak * 0.62) ny0++;
      while (ny1 > ext0 && rowSum[ny1] < peak * 0.62) ny1--;
      if (ny1 - ny0 > h * 0.2 && (Math.abs(ny0 - y0) > 1 || Math.abs(ny1 - y1) > 1)) {
        return readBand(img, ink, ny0, ny1, false);
      }
    }

    // Spacing between digits: the typical gap between neighbouring runs.
    var gap = 4, gaps = [];
    for (i = 1; i < cand.length; i++) gaps.push(cand[i].x0 - cand[i - 1].x1 - 1);
    if (gaps.length) gap = Math.max(2, median(gaps));
    var digits = [];
    cand.forEach(function (r) {
      if (r.w > dw * 1.45) split(r, cols, dw, gap).forEach(function (p) { digits.push(measure(p)); });
      else digits.push(r);
    });
    digits = digits.filter(function (r) { return r.w >= mh * 0.08 && r.bottom - r.top > mh * 0.45; });
    note('digits ' + y0 + '-' + y1, digits.map(function (r) { return [r.x0, r.x1, r.top, r.bottom].join(','); }));
    if (digits.length < 3 || digits.length > 12) return null;

    var results = digits.map(function (r) {
      var cellX0 = r.w < dw * 0.85 ? r.x1 - dw + 1 : r.x0;
      var c = classify(up, w, { x0: Math.max(0, cellX0), x1: r.x1, y0: y0, y1: y1 });
      return { run: r, c: c };
    });
    // Junk at either end (a panel edge, a label) won't classify: trim it. A
    // digit that can't be told apart in the middle spoils the read.
    while (results.length > 1 && !results[0].c && results[1].run.x0 - results[0].run.x1 > dw * 0.8) results.shift();
    while (results.length > 1 && !results[results.length - 1].c &&
        results[results.length - 1].run.x0 - results[results.length - 2].run.x1 > dw * 0.8) results.pop();
    if (results.length < 3) return null;
    for (i = 0; i < results.length; i++) if (!results[i].c) return null;
    // The right-hand edges of neighbouring digits are a fixed distance apart
    // (the digit pitch). A '1' at either end that doesn't sit on that grid is
    // not a digit (a label, an edge) unless a decimal point explains the gap.
    function dotBetween(a, b) {
      return dots.some(function (d) { return d.x0 > a.x1 && d.x1 < b.x0; });
    }
    var steps = [];
    for (i = 1; i < results.length; i++) {
      if (!dotBetween(results[i - 1].run, results[i].run)) steps.push(results[i].run.x1 - results[i - 1].run.x1);
    }
    if (steps.length >= 2) {
      var pitch = median(steps);
      var onGrid = function (a, b) { return dotBetween(a, b) || Math.abs(b.x1 - a.x1 - pitch) <= pitch * 0.2; };
      while (results.length > 3 && results[0].c.ch === '1' && !onGrid(results[0].run, results[1].run)) results.shift();
      while (results.length > 3 && results[results.length - 1].c.ch === '1' &&
          !onGrid(results[results.length - 2].run, results[results.length - 1].run)) results.pop();
    }

    var left = w, right = 0, tokens = [], cost = 0, first = results[0].run, lastRun = results[results.length - 1].run;
    results.forEach(function (r) {
      tokens.push({ x: (r.run.x0 + r.run.x1) / 2, ch: r.c.ch });
      cost += r.c.cost;
      left = Math.min(left, r.run.x0); right = Math.max(right, r.run.x1);
    });
    dots.forEach(function (d) {
      var cx = (d.x0 + d.x1) / 2;
      if (cx > first.x1 && cx < lastRun.x0) tokens.push({ x: cx, ch: '.' });
    });
    tokens.sort(function (a, b) { return a.x - b.x; });
    var text = tokens.map(function (t) { return t.ch; }).join('');
    if (text.split('.').length > 2) return null;
    var k = 1 / img.k, pad = mh * 0.12;
    return {
      text: text,
      score: results.length - cost * 0.35,
      box: { x0: (left - pad) * k, y0: (y0 - pad) * k, x1: (right + pad) * k, y1: (y1 + pad) * k },
    };
  }

  function decode(img, ink, invert) {
    var w = img.w, h = img.h, ry = Math.max(2, Math.round(h * 0.06));
    // Drop frame lines and panel edges: ink that runs far wider than any digit
    // or all the way from the top to the bottom of the view.
    blobs(ink, w, h).forEach(function (b) {
      if (b.x1 - b.x0 > h * 1.1 || (b.y0 <= 1 && b.y1 >= h - 2)) {
        b.pix.forEach(function (i) { ink[i] = 0; });
      }
    });
    if (window.__lcdDebug && !invert) window.__lcdDebug.ink = { w: w, h: h, s: Array.from(ink).join('') };

    // The row of digits is somewhere among the tall blobs of ink; try the
    // height of each and keep the reading with the most digits.
    var tall = blobs(close(ink, w, h, 1, ry), w, h).filter(function (b) {
      var bh = b.y1 - b.y0 + 1;
      return bh >= h * 0.25 && bh <= h * 0.98 && b.area > 40;
    }).sort(function (a, b) { return b.area - a.area; });
    note('bands' + (invert ? '-inv' : ''), tall.map(function (b) { return [b.y0, b.y1, b.area].join(','); }));
    var tried = {}, best = null;
    function attempt(a, b) {
      var key = a + '-' + b;
      if (tried[key] || b - a < h * 0.25) return;
      tried[key] = 1;
      var r = readBand(img, ink, a, b, true);
      if (r && (!best || r.score > best.score)) best = r;
    }
    // The rows with the most ink are the digits (text above or below is thinner).
    var rowInk = new Array(h).fill(0), peak = 0, x, y;
    for (y = 0; y < h; y++) {
      for (x = 0; x < w; x++) rowInk[y] += ink[y * w + x];
      if (rowInk[y] > peak) peak = rowInk[y];
    }
    var first = 0, last = h - 1;
    while (first < h && rowInk[first] < peak * 0.5) first++;
    while (last > 0 && rowInk[last] < peak * 0.5) last--;
    attempt(first, last);
    tall.slice(0, 6).forEach(function (b) { attempt(b.y0, b.y1); });
    // The union of the biggest blobs covers digits that came apart vertically.
    if (tall.length > 1) {
      var big = tall.filter(function (b) { return b.area > tall[0].area * 0.35; });
      attempt(Math.min.apply(null, big.map(function (b) { return b.y0; })), Math.max.apply(null, big.map(function (b) { return b.y1; })));
    }
    return best;
  }

  function count(m) {
    var n = 0;
    for (var i = 0; i < m.length; i++) n += m[i];
    return n;
  }

  window.wattlyReadLcd = function (canvas) {
    var img = gray(canvas);
    var darkInk = inkMask(img, false), lightInk = inkMask(img, true);
    // Digits cover less of the display than the background around them, so
    // the reading whose "ink" covers less is the likelier one.
    var darkIsDigits = count(darkInk) <= count(lightInk);
    var a = decode(img, darkInk, false), b = decode(img, lightInk, true);
    if (a) a.score *= darkIsDigits ? 1 : 0.8;
    if (b) b.score *= darkIsDigits ? 0.8 : 1;
    if (a && b) return a.score >= b.score ? a : b;
    return a || b;
  };
})();
