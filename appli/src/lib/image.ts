/** Recadre au centre en carré et compresse : une photo de 4 Mo devient ~20 Ko. */
export async function toAvatar(file: File, size = 256): Promise<string> {
  const url = URL.createObjectURL(file)
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const i = new Image()
      i.onload = () => resolve(i)
      i.onerror = () => reject(new Error('Image illisible'))
      i.src = url
    })
    const side = Math.min(img.naturalWidth, img.naturalHeight)
    const canvas = document.createElement('canvas')
    canvas.width = size
    canvas.height = size
    const ctx = canvas.getContext('2d')!
    // Sur un portrait, le visage est dans le haut : on recadre un peu au-dessus du centre.
    const sx = (img.naturalWidth - side) / 2
    const sy = (img.naturalHeight - side) * (img.naturalHeight > img.naturalWidth ? 0.4 : 0.5)
    ctx.drawImage(img, sx, sy, side, side, 0, 0, size, size)
    return canvas.toDataURL('image/jpeg', 0.8)
  } finally {
    URL.revokeObjectURL(url)
  }
}
