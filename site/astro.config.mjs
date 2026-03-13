// @ts-check
import { defineConfig, sharpImageService } from "astro/config";

export default defineConfig({
  output: "static",
  site: process.env.ASTRO_SITE || "https://infracost.github.io",
  base: process.env.ASTRO_BASE || "/agent-skills",
  image: {
    service: sharpImageService(),
  },
});
