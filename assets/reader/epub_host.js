(function () {
  'use strict';

  // jellyfin-web 12 builds its location index with generate(1024). Using the
  // same size is what makes a saved percentage point at the same place in
  // both clients.
  var CHARS_PER_LOCATION = 1024;

  var book = null;
  var rendition = null;
  var opts = null;
  var lastCfi = null;
  var anchorCfi = null;
  var locationsReady = null;
  var sectionEnds = null;
  var restyleTimer = null;
  var webkit = /AppleWebKit/.test(navigator.userAgent) &&
    !/Chrome|Chromium|Edg\//.test(navigator.userAgent);

  function send(msg) {
    window.flutter_inappwebview.callHandler('moonfinEpub', msg);
  }

  function fail() {
    send({ type: 'error' });
  }

  function quiet(promise) {
    if (promise && promise.catch) promise.catch(function () {});
  }

  function readBook(size) {
    var bytes = new Uint8Array(size);
    function read(offset) {
      if (offset >= size) return Promise.resolve(bytes.buffer);
      return window.flutter_inappwebview.callHandler('moonfinEpubChunk', offset).then(function (b64) {
        var bin = atob(b64 || '');
        if (!bin.length) throw new Error('Book data ended early');
        for (var i = 0; i < bin.length; i++) bytes[offset + i] = bin.charCodeAt(i);
        return read(offset + bin.length);
      });
    }
    return read(0);
  }

  function rtl() {
    return book.package.metadata.direction === 'rtl';
  }

  function generateLocations() {
    if (!locationsReady) {
      locationsReady = book.locations.generate(CHARS_PER_LOCATION).then(function () {
        sectionEnds = {};
        var all = JSON.parse(book.locations.save());
        for (var i = 0; i < all.length; i++) {
          sectionEnds[new ePub.CFI(all[i]).spinePos] = i;
        }
      });
    }
    return locationsReady;
  }

  function minutesLeft(cfi, index) {
    var end = sectionEnds && sectionEnds[index];
    var here = book.locations.locationFromCfi(cfi);
    if (end == null || here == null || here < 0) return null;
    // A 1024 character location is about 170 words, read at 200 a minute.
    return Math.max(1, Math.ceil((end - here + 1) * 170 / 200));
  }

  function relocated(loc) {
    if (!loc || !loc.start || !loc.start.cfi) return;
    lastCfi = loc.start.cfi;
    var indexed = book.locations.length() > 0;
    send({
      type: 'relocated',
      cfi: lastCfi,
      index: loc.start.index,
      atEnd: !!loc.atEnd,
      percentage: indexed ? book.locations.percentageFromCfi(lastCfi) : null,
      minutesLeft: indexed ? minutesLeft(lastCfi, loc.start.index) : null
    });
  }

  function turn(forward) {
    anchorCfi = null;
    if (opts.scrolled) {
      var box = rendition.manager.container;
      var atEdge = forward
        ? box.scrollTop + box.clientHeight >= box.scrollHeight - 8
        : box.scrollTop <= 8;
      if (!atEdge) {
        box.scrollTop += (forward ? 0.9 : -0.9) * box.clientHeight;
        return;
      }
    }
    if (forward) {
      quiet(rendition.next());
      return;
    }
    var from = rendition.currentLocation();
    var back = rendition.prev();
    if (!back || !back.then) return;
    quiet(back.then(function () {
      var now = rendition.currentLocation();
      if (!from || !now || from.start.index === now.start.index) return;
      // Going back into the previous chapter should land on its end. epub.js
      // jumps there before right to left chapters have laid out their last
      // page, so it stops a page short.
      var box = rendition.manager.container;
      if (opts.scrolled) {
        box.scrollTop = box.scrollHeight;
        return;
      }
      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          var end = box.scrollWidth - box.offsetWidth;
          if (!rtl()) box.scrollLeft = end;
          else box.scrollLeft = rendition.manager.settings.rtlScrollType === 'default' ? 0 : -end;
        });
      });
    }));
  }

  // dir is on screen, -1 for left and 1 for right. Right to left books read
  // leftwards, so their next page is on the left.
  function turnToward(dir) {
    turn(rtl() ? dir < 0 : dir > 0);
  }

  function onKey(e) {
    var k = e.key;
    if (k === 'ArrowRight' || k === 'Right') turnToward(1);
    else if (k === 'ArrowLeft' || k === 'Left') turnToward(-1);
    else if (k === 'PageDown' || (k === ' ' && !e.shiftKey)) turn(true);
    else if (k === 'PageUp' || (k === ' ' && e.shiftKey)) turn(false);
    else return;
    e.preventDefault();
  }

  var lastWheel = 0;
  function onWheel(e) {
    var now = Date.now();
    var burstStart = now - lastWheel > 250;
    lastWheel = now;
    // A wheel flick or trackpad swipe sends a burst of events, so it turns
    // one page per burst.
    if (opts.scrolled || !burstStart) return;
    if (Math.abs(e.deltaX) > Math.abs(e.deltaY)) turnToward(e.deltaX > 0 ? 1 : -1);
    else if (e.deltaY) turn(e.deltaY > 0);
  }

  function hasSelection(win) {
    var sel = win && win.getSelection && win.getSelection();
    return !!(sel && String(sel).length);
  }

  function onClick(e) {
    if (e.target && e.target.closest && e.target.closest('a')) return;
    if (hasSelection(e.view)) return;
    // The click is in the chapter iframe, which in paged mode is far wider
    // than the screen, so move it into screen coordinates first.
    var frame = e.view && e.view.frameElement;
    var x = e.clientX + (frame ? frame.getBoundingClientRect().left : 0);
    var w = window.innerWidth;
    if (x < w * 0.3) turnToward(-1);
    else if (x > w * 0.7) turnToward(1);
    else send({ type: 'toggle' });
  }

  function boxWidth() {
    var range = this.document.createRange();
    range.selectNodeContents(this.content || this.document.body);
    var rects = range.getClientRects();
    var min = Infinity;
    var max = -Infinity;
    for (var i = 0; i < rects.length; i++) {
      if (rects[i].width < 1 || rects[i].height < 1) continue;
      min = Math.min(min, rects[i].left);
      max = Math.max(max, rects[i].right);
    }
    return max > min ? Math.round(max - min) : 0;
  }

  function hookContent(contents) {
    var doc = contents.document;
    var start = null;
    // WebKit measures a right to left chapter as wide as its frame, so
    // epub.js keeps widening the frame to fit and never reaches the last
    // page. Its laid out boxes give the real width.
    if (webkit && rtl()) contents.textWidth = boxWidth;
    doc.addEventListener('click', onClick);
    doc.addEventListener('keydown', onKey);
    doc.addEventListener('wheel', onWheel, { passive: true });
    doc.addEventListener('touchstart', function (e) {
      var t = e.changedTouches[0];
      start = { x: t.clientX, y: t.clientY };
    }, { passive: true });
    doc.addEventListener('touchend', function (e) {
      if (!start || opts.scrolled || hasSelection(contents.window)) return;
      var t = e.changedTouches[0];
      var dx = t.clientX - start.x;
      var dy = t.clientY - start.y;
      start = null;
      if (Math.abs(dx) > 50 && Math.abs(dx) > 1.5 * Math.abs(dy)) {
        turnToward(dx < 0 ? 1 : -1);
      }
    }, { passive: true });
  }

  function themeRules(s) {
    var imp = ' !important';
    return {
      'html, body': { 'background': 'transparent' + imp },
      'body': {
        'font-family': s.font + imp,
        'font-size': s.size + 'px' + imp,
        'line-height': s.lineHeight + imp,
        'font-weight': s.bold ? '600' : 'normal',
        'text-align': s.justify ? 'justify' : 'initial',
        'overflow-wrap': 'anywhere',
        '-webkit-hyphens': 'auto',
        'hyphens': 'auto'
      },
      'body, body *:not(a)': {
        'color': s.fg + imp,
        '-webkit-text-fill-color': s.fg + imp,
        'background-color': 'transparent' + imp,
        'border-color': s.fg + imp
      },
      'a, a *': {
        'color': s.link + imp,
        '-webkit-text-fill-color': s.link + imp
      }
    };
  }

  function applyFrame(s) {
    document.body.style.background = s.bg;
    var frame = document.getElementById('frame');
    frame.style.maxWidth = s.maxWidth + 'px';
    frame.style.padding = '16px ' + s.margin + 'px';
  }

  function render(target) {
    if (rendition) rendition.destroy();
    rendition = book.renderTo('reader', {
      width: '100%',
      height: '100%',
      flow: opts.scrolled ? 'scrolled-doc' : 'paginated',
      spread: 'none',
      // WebKit runs none of this page's listeners in a chapter frame that
      // can't run scripts. The page's CSP nonce still keeps the book's own
      // scripts from running there.
      allowScriptedContent: webkit
    });
    rendition.themes.default(themeRules(opts.style));
    rendition.hooks.content.register(hookContent);
    rendition.on('relocated', relocated);
    return rendition.display(target).then(function () {
      // The first display measures the chapter before the theme, its fonts
      // and its images have reflowed it, which lands pages early.
      if (typeof target !== 'string') return;
      return settled().then(function () {
        return rendition.display(target);
      }).then(function () {
        // A saved page starts a line, and the start of a line can measure as
        // the end of the line before it, a page back.
        var shown = rendition.currentLocation();
        if (!opts.scrolled && shown && shown.end && shown.end.cfi &&
            new ePub.CFI().compare(target, shown.end.cfi) > 0) {
          return rendition.next();
        }
      });
    });
  }

  function settled() {
    var waits = [];
    rendition.getContents().forEach(function (contents) {
      var doc = contents.document;
      if (doc.fonts && doc.fonts.ready) waits.push(doc.fonts.ready);
      Array.prototype.forEach.call(doc.images, function (img) {
        if (img.complete) return;
        waits.push(new Promise(function (done) {
          img.addEventListener('load', done);
          img.addEventListener('error', done);
        }));
      });
    });
    var cap = new Promise(function (done) {
      setTimeout(done, 3000);
    });
    return Promise.race([Promise.all(waits), cap]);
  }

  // Restyling or switching between pages and scrolling reflows the chapter,
  // so the reader is rebuilt where the change started. That place holds until
  // the next page turn, so a run of changes can't creep backwards.
  function rerender() {
    anchorCfi = anchorCfi || lastCfi;
    clearTimeout(restyleTimer);
    restyleTimer = setTimeout(function () {
      render(anchorCfi || undefined).catch(fail);
    }, 250);
  }

  window.__moonfin = {
    open: function (o) {
      // Android can report the same page load twice.
      if (opts) return;
      opts = o;
      applyFrame(o.style);
      readBook(o.size).then(function (buffer) {
        book = ePub(buffer);
        return book.ready;
      }).then(function () {
        // A server position is a percentage, which needs the location index
        // before it can be turned back into a place.
        if (o.fraction > 0) {
          return generateLocations().then(function () {
            // Locations are ranges, and Chromium places a right to left range
            // by its far end, a page late, so start from its first character.
            var cfi = new ePub.CFI(book.locations.cfiFromPercentage(o.fraction));
            cfi.collapse(true);
            return cfi.toString();
          });
        }
        return o.cfi || (o.section > 0 ? o.section : undefined);
      }).then(function (target) {
        return render(target).catch(function () {
          return render(o.section > 0 ? o.section : undefined);
        });
      }).then(function () {
        send({ type: 'ready', sections: book.spine.length, rtl: rtl() });
        return generateLocations();
      }).then(function () {
        relocated(rendition.location);
      }).catch(fail);
    },
    next: function () {
      if (rendition) turn(true);
    },
    prev: function () {
      if (rendition) turn(false);
    },
    display: function (target) {
      if (!rendition) return;
      anchorCfi = null;
      quiet(rendition.display(target));
    },
    style: function (s) {
      if (!opts) return;
      opts.style = s;
      applyFrame(s);
      if (rendition) rerender();
    },
    flow: function (scrolled) {
      if (!opts || opts.scrolled === scrolled) return;
      opts.scrolled = scrolled;
      if (rendition) rerender();
    },
    selectedText: function () {
      var all = rendition ? rendition.getContents() : [];
      for (var i = 0; i < all.length; i++) {
        var text = String(all[i].window.getSelection() || '');
        if (text) return text;
      }
      return '';
    }
  };

  document.addEventListener('keydown', function (e) {
    if (rendition) onKey(e);
  });
  // Taps on the margins around the chapter land on this page instead.
  document.addEventListener('click', function (e) {
    if (rendition) onClick(e);
  });
  document.addEventListener('wheel', function (e) {
    if (rendition) onWheel(e);
  }, { passive: true });
})();
