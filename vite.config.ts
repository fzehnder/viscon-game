import { defineConfig } from "vite";

// base "./" makes the build work on GitHub Pages under /<repo-name>/ and on any static host.
export default defineConfig({
  base: "./",
  build: {
    chunkSizeWarningLimit: 2000, // Phaser is large, that is fine
  },
});
