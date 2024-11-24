const fs = require('fs')

const dotsPerLine = 12
const W = 256
const H = 256
const R = W / 2
const SIN_LEN = 256
const TBL_ITEM = 4
const TBL_SIZE = R * SIN_LEN * 2 * TBL_ITEM

initCode()
initTbl()

// Generate draw code asm to stdout
function initCode() {
  let count = 0
  const angles = []

  // Generate random dot angles per line
  for (let y = 0; y < H; y++) {
    const lineAngles = []
    angles.push(lineAngles)
    for (let i = 0; i < dotsPerLine; i++) {
      lineAngles.push(
        Math.floor(Math.random() * SIN_LEN)
      )
      count++
    }
  }

  let o = 0

  const doAngle = a => {
    console.log(` movem.w ${a * 4}(a0),d0-d1`)
    console.log(` bset.b d1,${o}(a1,d0)`)
  }

  let i = 0
  for (let j = 0; j < R - 1; j++) {
    angles[i++].forEach(doAngle)
    o += 32
    if (o === 128) {
      o = 0
      console.log(` adda.w d3,a1`)
    }
    console.log(` adda.w d2,a0`)
  }

  // Descending order for bottom half of screen
  for (let j = R - 2; j >= 0; j--) {
    console.log(` suba.w d2,a0`)
    angles[i++].forEach(doAngle)
    o += 32
    if (o === 128) {
      o = 0
      console.log(` adda.w d3,a1`)
    }
  }
  console.log('; ' + count)
}

// Write table data to file
function initTbl() {
  const tblBuf = Buffer.alloc(TBL_SIZE)
  let o = 0

  // Generate 128 pre-scaled sin tables(!)
  for (let y = 0; y < R; y++) {
    // Line width of circle at this y
    const _y = y - R
    const lineWidth = Math.sqrt(R * R - _y * _y)

    for (let i = 0; i < SIN_LEN; i++) {
      const angle = i / SIN_LEN * Math.PI * 2
      const v = Math.floor(
        Math.sin(angle) * lineWidth +
        Math.random() / 2 // Hide banding from low res
      ) + R

      // Write a pair of values to go into bset instruction
      let byteOffset = v >> 3
      // Additional offset for back facing dots
      if (angle > Math.PI * 0.5 && angle < Math.PI * 1.5) {
        // Bitplane size
        byteOffset += 256 * 256 / 8
      }
      const bitToSet = (~v) & 7

      tblBuf.writeUInt16BE(byteOffset, o)
      tblBuf.writeUInt16BE(bitToSet, o + 2)
      // Table is repeated to allow angle offset without modulo
      tblBuf.writeUInt16BE(byteOffset, TBL_SIZE / 2 + o)
      tblBuf.writeUInt16BE(bitToSet, TBL_SIZE / 2 + o + 2)

      o += TBL_ITEM
    }
  }
  fs.writeFileSync('table.bin', tblBuf)
}
