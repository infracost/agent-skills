// @ts-check
import { defineConfig, sharpImageService } from "astro/config";

export default defineConfig({
  output: "static",
  site: process.env.ASTRO_SITE || "https://cost.dev",
  base: process.env.ASTRO_BASE || "/",
  image: {
    service: sharpImageService(),
  },
});
