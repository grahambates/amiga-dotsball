const fs = require('fs')

const dotsPerLine = 13
const W = 256
const H = 256
const R = W / 2
const SIN_LEN = 256
const TBL_ITEM = 4
const TBL_SIZE = R * SIN_LEN * 2 * TBL_ITEM

initCode()
initTbl()

function initCode() {
  let count = 0
  const angles = []

  for (let y = 0; y < H; y++) {
    const rowAngles = []
    angles.push(rowAngles)
    for (let i = 0; i < dotsPerLine; i++) {
      rowAngles.push(
        Math.floor(Math.random() * SIN_LEN)
      )
      count++
    }
  }

  let i = 0
  let o = 0

  const doAngle = a => {
    console.log(` movem.w ${a * 4}(a0),d0-d1`)
    console.log(` bset.b d1,${o}(a1,d0)`)
  }

  for (let j = 0; j < R - 1; j++) {
    angles[i++].forEach(doAngle)
    o += 32
    if (o === 128) {
      o = 0
      console.log(` adda.w d3,a1`)
    }
    console.log(` adda.w d2,a0`)
  }

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

function initTbl() {
  const tblBuf = Buffer.alloc(TBL_SIZE)
  let o = 0

  for (let y = 0; y < R; y++) {
    const _y = y - R
    const w = Math.sqrt(R * R - _y * _y)
    for (let i = 0; i < SIN_LEN; i++) {
      const a = i / SIN_LEN * Math.PI * 2
      const v = Math.floor(Math.sin(a) * w + Math.random() / 2) + R
      let shifted = v >> 3
      if (a > Math.PI * 0.5 && a < Math.PI * 1.5) {
        shifted += 256 * 256 / 8
      }
      const not = (~v) & 7
      tblBuf.writeUInt16BE(shifted, o)
      tblBuf.writeUInt16BE(not, o + 2)
      tblBuf.writeUInt16BE(shifted, TBL_SIZE / 2 + o)
      tblBuf.writeUInt16BE(not, TBL_SIZE / 2 + o + 2)
      o += TBL_ITEM
    }
  }
  fs.writeFileSync('table.bin', tblBuf)
}
