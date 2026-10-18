declare namespace Cloudflare {
  interface Env {
    ARTEFACTS: R2Bucket;
  }
  interface GlobalProps {
    mainModule: typeof import("./src/index");
  }
}

interface Env extends Cloudflare.Env {}
