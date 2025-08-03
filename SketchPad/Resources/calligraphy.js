// Resources/calligraphy.js

(function (window, document) {
  // wait for the DOM so <canvas> exists
  window.addEventListener("load", () => {
    const canvas = document.getElementById("canvas");
    if (!canvas) {
      console.error("No #canvas element found for Calligraphy.js");
      return;
    }

    // size it to the viewport (or customize)
    function resize() {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    }
    resize();
    window.addEventListener("resize", resize);

    const ctx = canvas.getContext("2d");
    // create a brush; tweak size, smoothing, etc.
    const brush = new Calligraphy.Brush(ctx, {
      size: 48,
      smoothing: 0.5,
    });

    // core render function
    function renderText(text) {
      // clear previous drawing
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // draw at x=20, y=60 — adjust as needed
      brush.draw(text, 20, 60);
    }

    // listen for messages from your Swift code:
    window.addEventListener("message", (event) => {
      const msg = event.data || {};
      if (msg.type === "render" && typeof msg.text === "string") {
        renderText(msg.text);
      }
    });

    // if you ever want to expose a JS API:
    window.CalligraphyApp = {
      render: renderText,
    };
  });
})(window, document);
