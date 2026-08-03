const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const size = 1024;
const bytesPerRow = 1 + size * 4;
const raw = Buffer.alloc(bytesPerRow * size);

function mix(a, b, t) {
  return Math.round(a + (b - a) * t);
}

function inRoundedRect(x, y, left, top, right, bottom, radius) {
  const cx = Math.max(left + radius, Math.min(x, right - radius));
  const cy = Math.max(top + radius, Math.min(y, bottom - radius));
  return (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2;
}

const bars = [
  [260, 385, 360, 639],
  [412, 250, 512, 774],
  [564, 330, 664, 694],
  [716, 425, 816, 599],
];

for (let y = 0; y < size; y++) {
  const row = y * bytesPerRow;
  raw[row] = 0;
  for (let x = 0; x < size; x++) {
    const diagonal = (x + y) / (size * 2);
    const glow = Math.max(0, 1 - Math.hypot(x - 320, y - 230) / 900);
    let r = mix(50, 121, diagonal) + Math.round(glow * 15);
    let g = mix(88, 66, diagonal) + Math.round(glow * 24);
    let b = mix(224, 212, diagonal) + Math.round(glow * 10);

    if (bars.some(([left, top, right, bottom]) =>
      inRoundedRect(x, y, left, top, right, bottom, 50))) {
      r = 255;
      g = 255;
      b = 255;
    }

    const offset = row + 1 + x * 4;
    raw[offset] = Math.min(255, r);
    raw[offset + 1] = Math.min(255, g);
    raw[offset + 2] = Math.min(255, b);
    raw[offset + 3] = 255;
  }
}

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const typeBuffer = Buffer.from(type, 'ascii');
  const output = Buffer.alloc(12 + data.length);
  output.writeUInt32BE(data.length, 0);
  typeBuffer.copy(output, 4);
  data.copy(output, 8);
  output.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])), 8 + data.length);
  return output;
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(size, 0);
ihdr.writeUInt32BE(size, 4);
ihdr[8] = 8;
ihdr[9] = 6;

const png = Buffer.concat([
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);

const output = path.resolve(__dirname, '../Resonance/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png');
fs.writeFileSync(output, png);
console.log(`Generated ${output} (${png.length} bytes)`);
