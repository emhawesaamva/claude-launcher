// Apply a PNG as the custom Finder icon of a file/bundle.
// Usage: osascript -l JavaScript scripts/set-icon.js <target> <icon.png>
ObjC.import("AppKit");
function run(argv) {
  var img = $.NSImage.alloc.initWithContentsOfFile(argv[1]);
  if (!img || img.isNil()) throw new Error("cannot read icon: " + argv[1]);
  var ok = $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, argv[0], 0);
  if (!ok) throw new Error("could not set icon on: " + argv[0]);
}
