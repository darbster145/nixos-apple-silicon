final: prev: {
  linux-asahi = final.callPackage ./linux-asahi { };
  linux-asahi-fairydust = final.callPackage ./linux-asahi-fairydust { };
  uboot-asahi = final.callPackage ./uboot-asahi { };
}
